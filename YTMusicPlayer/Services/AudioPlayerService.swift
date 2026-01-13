import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// Service for managing audio/video playback with AVPlayer
@MainActor
class AudioPlayerService: ObservableObject {
    
    static let shared = AudioPlayerService()
    
    // MARK: - Published Properties
    @Published private(set) var state: PlayerState = .idle
    @Published private(set) var currentTrack: Track?
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var playbackMode: PlaybackMode = .audio
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var cachedDuration: [String: TimeInterval] = [:] // Cache duration by video ID
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    // MARK: - Initialization
    private init() {
        setupAudioSession()
        setupRemoteTransportControls()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Remote Control Setup
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
    
    // MARK: - Now Playing Info
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.author,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: state.isPlaying ? 1.0 : 0.0
        ]
        
        // Load artwork asynchronously
        if let thumbnailURL = track.thumbnailURL {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: thumbnailURL),
                   let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - Playback Control
    
    /// Play a track in the specified mode
    /// - Parameters:
    ///   - track: The track to play
    ///   - mode: The playback mode (audio/video)
    ///   - seekTime: Optional time to seek to after playback starts (useful when switching modes)
    func play(_ track: Track, mode: PlaybackMode, seekTime: TimeInterval? = nil) {
        let streamURL: URL?
        
        // Use video stream for both modes if available (audio-only streams have incorrect duration metadata)
        // AVPlayer will handle the audio extraction automatically
        switch mode {
        case .audio:
            // Prefer video stream for accurate duration, fallback to audio-only
            streamURL = track.videoStreamURL ?? track.audioStreamURL
        case .video:
            streamURL = track.videoStreamURL ?? track.audioStreamURL
        }
        
        guard let url = streamURL else {
            state = .error("No stream available for \(mode.rawValue) mode")
            return
        }
        
        // Cancel existing subscriptions before creating new ones
        cancellables.removeAll()
        removeTimeObserver()
        
        // Reset state for new playback
        state = .loading
        currentTrack = track
        playbackMode = mode
        // Only reset currentTime if not seeking to a specific time
        if seekTime == nil {
            currentTime = 0
        }
        
        // Use cached duration if available (from previous play of same track)
        if let cached = cachedDuration[track.id], cached > 0 {
            duration = cached
        } else {
            duration = 0
        }
        
        // Create player item
        playerItem = AVPlayerItem(url: url)
        
        // Create or reuse player
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        // Load duration from AVAsset asynchronously (more reliable)
        let trackId = track.id
        Task { [weak self] in
            do {
                let asset = AVAsset(url: url)
                let durationValue = try await asset.load(.duration)
                if durationValue.isNumeric {
                    let durationSeconds = CMTimeGetSeconds(durationValue)
                    await MainActor.run {
                        // Only update if we don't have a cached value or this is video mode (more accurate)
                        if self?.cachedDuration[trackId] == nil || mode == .video {
                            self?.duration = durationSeconds
                            self?.cachedDuration[trackId] = durationSeconds
                        }
                    }
                }
            } catch {
                print("Failed to load duration: \(error)")
            }
        }
        
        // Observe status
        playerItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    // Seek to specified time if provided (e.g., when switching modes)
                    if let seekTo = seekTime, seekTo > 0 {
                        let cmTime = CMTime(seconds: seekTo, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                        self?.player?.seek(to: cmTime) { _ in
                            self?.player?.play()
                            self?.state = .playing
                            self?.currentTime = seekTo
                            self?.updateNowPlayingInfo()
                        }
                    } else {
                        self?.player?.play()
                        self?.state = .playing
                        self?.updateNowPlayingInfo()
                    }
                    
                    // Also try to get duration from playerItem when ready (for video mode)
                    if mode == .video, let item = self?.playerItem, item.duration.isNumeric {
                        let itemDuration = CMTimeGetSeconds(item.duration)
                        if itemDuration > 0 {
                            self?.duration = itemDuration
                            self?.cachedDuration[trackId] = itemDuration
                        }
                    }
                case .failed:
                    self?.state = .error(self?.playerItem?.error?.localizedDescription ?? "Playback failed")
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Add time observer
        addTimeObserver()
    }
    
    private func addTimeObserver() {
        removeTimeObserver()
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
            self?.updateNowPlayingInfo()
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    func pause() {
        player?.pause()
        state = .paused
        updateNowPlayingInfo()
    }
    
    func resume() {
        player?.play()
        state = .playing
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        if state.isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        removeTimeObserver()
        cancellables.removeAll()
        
        state = .idle
        currentTrack = nil
        currentTime = 0
        duration = 0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime)
        currentTime = time
        updateNowPlayingInfo()
    }
    
    /// Switch playback mode seamlessly without reloading the player
    /// This works because both audio and video modes use the same video stream
    /// - Parameter mode: The new playback mode
    /// - Returns: true if mode was switched successfully, false if reload is needed
    func switchMode(to mode: PlaybackMode) -> Bool {
        guard let track = currentTrack, mode != playbackMode else { return true }
        
        // Check if we can switch seamlessly (same stream URL for both modes)
        let currentStreamURL: URL?
        let newStreamURL: URL?
        
        switch playbackMode {
        case .audio:
            currentStreamURL = track.videoStreamURL ?? track.audioStreamURL
        case .video:
            currentStreamURL = track.videoStreamURL ?? track.audioStreamURL
        }
        
        switch mode {
        case .audio:
            newStreamURL = track.videoStreamURL ?? track.audioStreamURL
        case .video:
            newStreamURL = track.videoStreamURL ?? track.audioStreamURL
        }
        
        // If using the same stream, just toggle the mode without reloading
        if currentStreamURL == newStreamURL && player != nil && playerItem != nil {
            playbackMode = mode
            updateNowPlayingInfo()
            return true
        }
        
        // Different streams, need to reload
        return false
    }
    
    /// Get the AVPlayer for video display
    func getPlayer() -> AVPlayer? {
        return player
    }
}

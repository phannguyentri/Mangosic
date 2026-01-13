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
    func play(_ track: Track, mode: PlaybackMode) {
        let streamURL: URL?
        
        switch mode {
        case .audio:
            streamURL = track.audioStreamURL
        case .video:
            streamURL = track.videoStreamURL ?? track.audioStreamURL
        }
        
        guard let url = streamURL else {
            state = .error("No stream available for \(mode.rawValue) mode")
            return
        }
        
        state = .loading
        currentTrack = track
        playbackMode = mode
        
        // Create player item
        playerItem = AVPlayerItem(url: url)
        
        // Create or reuse player
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        // Observe duration
        playerItem?.publisher(for: \.duration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cmTime in
                if cmTime.isNumeric {
                    self?.duration = CMTimeGetSeconds(cmTime)
                }
            }
            .store(in: &cancellables)
        
        // Observe status
        playerItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.player?.play()
                    self?.state = .playing
                    self?.updateNowPlayingInfo()
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
    
    /// Get the AVPlayer for video display
    func getPlayer() -> AVPlayer? {
        return player
    }
}

import Foundation
import AVFoundation
import MediaPlayer
import Combine
import UIKit

/// Service for managing audio/video playback with AVPlayer
@MainActor
class AudioPlayerService: ObservableObject {
    
    static let shared = AudioPlayerService()
    
    // MARK: - Published Properties
    @Published private(set) var state: PlayerState = .idle
    @Published private(set) var currentTrack: Track?
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var playbackMode: PlaybackMode = .video
    @Published private(set) var repeatMode: RepeatMode = .off
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var cachedDuration: [String: TimeInterval] = [:] // Cache duration by video ID
    private var cachedArtwork: MPMediaItemArtwork? // Cache artwork to prevent flickering
    private var cachedArtworkTrackId: String? // Track ID for cached artwork
    private var isLoadingArtwork: Bool = false // Prevent multiple concurrent downloads
    
    // Background playback support
    private var wasPlayingBeforeInterruption: Bool = false
    private var backgroundPlayerLayer: AVPlayerLayer?
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    // MARK: - Initialization
    private init() {
        setupAudioSession()
        setupRemoteTransportControls()
        setupEndOfTrackObserver()
        setupBackgroundPlayback()
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
    
    // MARK: - End of Track Observer
    private func setupEndOfTrackObserver() {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleTrackEnded()
            }
        }
    }
    
    private func handleTrackEnded() {
        switch repeatMode {
        case .off:
            // Just stop at the end
            state = .paused
            currentTime = duration
            updateNowPlayingInfo()
        case .one, .all:
            // Replay the current track
            seek(to: 0)
            resume()
        }
    }
    
    // MARK: - Background Playback Setup
    private func setupBackgroundPlayback() {
        // Stage 1: Save playing state BEFORE iOS auto-pauses (willResignActive)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWillResignActive()
            }
        }
        
        // Stage 2: Resume playback AFTER iOS has auto-paused (didEnterBackground)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleDidEnterBackground()
            }
        }
        
        // Handle app returning to foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleEnterForeground()
            }
        }
        
        // Handle audio session interruptions (phone calls, alarms, etc.)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAudioSessionInterruption(notification)
            }
        }
    }
    
    /// Stage 1: Save state before iOS pauses the player
    private func handleWillResignActive() {
        // Capture playing state BEFORE iOS auto-pauses
        wasPlayingBeforeInterruption = state.isPlaying
        print("📱 Will resign active - wasPlaying: \(wasPlayingBeforeInterruption)")
    }
    
    /// Stage 2: Resume playback AFTER iOS has auto-paused (didEnterBackground)
    private func handleDidEnterBackground() {
        print("🔒 App did enter background - checking playback status")
        
        // Note: Do NOT update wasPlayingBeforeInterruption here.
        // iOS might have already paused the player, so we rely on the value
        // captured in handleWillResignActive.
        
        // If playing, we need to override iOS's auto-pause behavior for video
        // iOS automatically pauses AVPlayer with video track when entering background
        // The trick is to call play() AFTER iOS has paused it
        if wasPlayingBeforeInterruption {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setActive(true)
                print("✅ Audio session activated for background")
            } catch {
                print("❌ Failed to activate audio session: \(error)")
            }
            
            // Use multiple delayed attempts to resume playback after iOS pauses
            // iOS pauses the player after app enters background, so we resume it
            for delay in [0.1, 0.3, 0.5, 1.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self = self, self.wasPlayingBeforeInterruption else { return }
                    
                    // Check if iOS paused our player and resume it
                    if self.player?.rate == 0 && self.state.isPlaying {
                        self.player?.play()
                        print("▶️ Resumed playback in background (delay: \(delay)s)")
                    }
                }
            }
        }
    }
    
    /// Handle app returning to foreground
    private func handleEnterForeground() {
        print("👀 App entering foreground")
        
        // If we were playing before background, ensure we're still playing
        if wasPlayingBeforeInterruption {
            if player?.rate == 0 {
                player?.play()
                state = .playing
                print("▶️ Resumed playback after foreground")
            }
            updateNowPlayingInfo()
        }
    }
    
    /// Handle audio session interruptions (phone calls, alarms)
    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio was interrupted (e.g., phone call)
            print("⚠️ Audio session interrupted")
            wasPlayingBeforeInterruption = state.isPlaying
            pause()
            
        case .ended:
            // Interruption ended
            print("✅ Audio interruption ended")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && wasPlayingBeforeInterruption {
                    // Re-activate audio session and resume
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        resume()
                        print("▶️ Resumed playback after interruption")
                    } catch {
                        print("❌ Failed to resume after interruption: \(error)")
                    }
                }
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Now Playing Info
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            cachedArtwork = nil
            cachedArtworkTrackId = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.author,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: state.isPlaying ? 1.0 : 0.0
        ]
        
        // Use cached artwork if available for current track
        if cachedArtworkTrackId == track.id, let artwork = cachedArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        } else {
            // Set info without artwork first (only if no cached artwork)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            
            // Load artwork asynchronously only if not already loading
            if !isLoadingArtwork, let thumbnailURL = track.thumbnailURL {
                isLoadingArtwork = true
                let trackId = track.id
                Task {
                    defer { isLoadingArtwork = false }
                    if let (data, _) = try? await URLSession.shared.data(from: thumbnailURL),
                       let image = UIImage(data: data) {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        // Cache the artwork
                        self.cachedArtwork = artwork
                        self.cachedArtworkTrackId = trackId
                        
                        // Update info with artwork
                        var infoWithArtwork = info
                        infoWithArtwork[MPMediaItemPropertyArtwork] = artwork
                        // Update elapsed time to current value
                        infoWithArtwork[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.currentTime
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = infoWithArtwork
                    }
                }
            }
        }
    }

    
    // MARK: - Playback Control
    
    /// Play a track in the specified mode
    /// - Parameters:
    ///   - track: The track to play
    ///   - mode: The playback mode (audio/video)
    ///   - seekTime: Optional time to seek to after playback starts (useful when switching modes)
    func play(_ track: Track, mode: PlaybackMode, seekTime: TimeInterval? = nil) {
        // Check if we should use adaptive streaming (video-only + audio mixing)
        if mode == .video && track.isAdaptiveStream,
           let videoURL = track.videoOnlyStreamURL,
           let audioURL = track.separateAudioURL {
            print("🎬 Using adaptive streaming for high-res playback")
            playMixedStreams(track: track, videoURL: videoURL, audioURL: audioURL, seekTime: seekTime)
            return
        }
        
        // Standard playback with combined stream
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
        
        playStandardStream(track: track, url: url, mode: mode, seekTime: seekTime)
    }
    
    /// Play standard combined stream (for <=720p)
    private func playStandardStream(track: Track, url: URL, mode: PlaybackMode, seekTime: TimeInterval?) {
        
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
                        self?.player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                            // Always try to play after seek, regardless of seek success
                            self?.player?.playImmediately(atRate: 1.0)
                            self?.state = .playing
                            self?.currentTime = seekTo
                            self?.updateNowPlayingInfo()
                        }
                    } else {
                        self?.player?.playImmediately(atRate: 1.0)
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
            Task { @MainActor [weak self] in
                self?.currentTime = CMTimeGetSeconds(time)
                self?.updateNowPlayingInfo()
            }
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
    
    /// Toggle repeat mode (cycles: off -> one -> all -> off)
    func toggleRepeatMode() {
        repeatMode = repeatMode.next
    }
    
    /// Set repeat mode
    func setRepeatMode(_ mode: RepeatMode) {
        repeatMode = mode
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
    
    // MARK: - Adaptive Stream Mixing (1080p+)
    
    /// Play high-resolution video by mixing video-only and audio-only streams
    private func playMixedStreams(track: Track, videoURL: URL, audioURL: URL, seekTime: TimeInterval?) {
        // Cancel existing subscriptions before creating new ones
        cancellables.removeAll()
        removeTimeObserver()
        
        // Reset state for new playback
        state = .loading
        currentTrack = track
        playbackMode = .video
        if seekTime == nil {
            currentTime = 0
        }
        
        // Use cached duration if available
        if let cached = cachedDuration[track.id], cached > 0 {
            duration = cached
        } else {
            duration = 0
        }
        
        print("🔄 Creating composition for video: \(videoURL)")
        print("🔄 Creating composition for audio: \(audioURL)")
        
        // Create composition asynchronously
        Task { [weak self] in
            do {
                var finalDuration = track.duration
                
                // If no metadata duration, try to get from reference combined stream (always reliable)
                if finalDuration == nil, let referenceURL = track.videoStreamURL {
                    print("ℹ️ Fetching reference duration from combined stream...")
                     // Load reference asset to get true duration (progressive stream duration is reliable)
                    let refAsset = AVURLAsset(url: referenceURL)
                    if let refDuration = try? await refAsset.load(.duration) {
                         let seconds = CMTimeGetSeconds(refDuration)
                         if seconds > 0 {
                             finalDuration = seconds
                             print("✅ Reference duration found: \(seconds)s")
                         }
                    }
                }
                
                let composition = try await self?.createComposition(
                    videoURL: videoURL, 
                    audioURL: audioURL,
                    explicitDuration: finalDuration
                )
                
                guard let composition = composition else {
                    await MainActor.run {
                        self?.state = .error("Failed to create composition")
                    }
                    return
                }
                
                await MainActor.run {
                    self?.playComposition(composition, track: track, seekTime: seekTime)
                }
            } catch {
                print("❌ Composition error: \(error)")
                await MainActor.run {
                    // Fallback to combined stream if composition fails
                    if let fallbackURL = track.videoStreamURL {
                        print("⚠️ Falling back to combined stream")
                        self?.playStandardStream(track: track, url: fallbackURL, mode: .video, seekTime: seekTime)
                    } else {
                        self?.state = .error("Failed to create high-res stream: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// Create AVMutableComposition from video and audio assets
    /// - Parameters:
    ///   - videoURL: URL for video stream
    ///   - audioURL: URL for audio stream
    ///   - explicitDuration: Optional authoritative duration from metadata (to fix adaptive stream duration bugs)
    private func createComposition(videoURL: URL, audioURL: URL, explicitDuration: TimeInterval? = nil) async throws -> AVMutableComposition {
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        
        // Load tracks from both assets
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        
        guard let videoTrack = videoTracks.first else {
            throw NSError(domain: "AudioPlayerService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        
        guard let audioTrack = audioTracks.first else {
            throw NSError(domain: "AudioPlayerService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
        }
        
        // Get track info first (more reliable than asset duration for streams)
        let videoTrackRange = try await videoTrack.load(.timeRange)
        let audioTrackRange = try await audioTrack.load(.timeRange)
        
        print("📊 Track Ranges - Video: \(CMTimeGetSeconds(videoTrackRange.duration))s (start: \(CMTimeGetSeconds(videoTrackRange.start))s)")
        print("                  Audio: \(CMTimeGetSeconds(audioTrackRange.duration))s (start: \(CMTimeGetSeconds(audioTrackRange.start))s)")
        
        // Determine composition duration
        // Priority 1: Explicit metadata duration (most reliable)
        // Priority 2: Intersection of track durations
        var compositionDuration_calc: CMTime
        
        if let explicitSeconds = explicitDuration, explicitSeconds > 0 {
            print("💎 Using explicit metadata duration: \(explicitSeconds)s")
            compositionDuration_calc = CMTime(seconds: explicitSeconds, preferredTimescale: 600)
        } else {
             compositionDuration_calc = CMTimeMinimum(videoTrackRange.duration, audioTrackRange.duration)
        }
        
        let compositionDuration = compositionDuration_calc
        
        print("✂️ Trimming composition to: \(CMTimeGetSeconds(compositionDuration))s")
        
        // Create composition
        let composition = AVMutableComposition()
        
        // Add video track to composition
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "AudioPlayerService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
        }
        
        // Insert exact time range from source track
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: videoTrackRange.start, duration: compositionDuration), 
            of: videoTrack, 
            at: .zero
        )
        
        // Add audio track to composition
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "AudioPlayerService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio track"])
        }
        
        try compositionAudioTrack.insertTimeRange(
            CMTimeRange(start: audioTrackRange.start, duration: compositionDuration), 
            of: audioTrack, 
            at: .zero
        )
        
        print("✅ Composition created.")
        print("   - Video Duration: \(CMTimeGetSeconds(videoTrackRange.duration))s")
        print("   - Audio Duration: \(CMTimeGetSeconds(audioTrackRange.duration))s")
        print("   - Target Duration: \(CMTimeGetSeconds(compositionDuration))s")
        print("   - Final Composition Duration: \(CMTimeGetSeconds(composition.duration))s")
        
        return composition
    }
    
    /// Play the composed asset
    private func playComposition(_ composition: AVMutableComposition, track: Track, seekTime: TimeInterval?) {
        let playerItem = AVPlayerItem(asset: composition)
        self.playerItem = playerItem
        
        // Create or reuse player
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        // Cache duration
        let trackId = track.id
        let compositionDuration = CMTimeGetSeconds(composition.duration)
        
        print("▶️ Play Composition: duration=\(compositionDuration)s")
        
        if compositionDuration > 0 {
            duration = compositionDuration
            cachedDuration[trackId] = compositionDuration
        }
        
        // Observe status
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    switch status {
                    case .readyToPlay:
                        if let seekTo = seekTime, seekTo > 0 {
                            let cmTime = CMTime(seconds: seekTo, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                            self.player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                                self?.player?.playImmediately(atRate: 1.0)
                                self?.state = .playing
                                self?.currentTime = seekTo
                                self?.updateNowPlayingInfo()
                            }
                        } else {
                            self.player?.playImmediately(atRate: 1.0)
                            self.state = .playing
                            self.updateNowPlayingInfo()
                        }
                    case .failed:
                        self.state = .error(self.playerItem?.error?.localizedDescription ?? "Composition playback failed")
                    default:
                        break
                    }
                }
            }
        .store(in: &cancellables)
        
        // Add time observer
        addTimeObserver()
        
        print("▶️ Started playing composition at \(track.resolution ?? "unknown") resolution")
    }
}

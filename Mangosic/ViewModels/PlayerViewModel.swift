import Foundation
import Combine

/// ViewModel for managing player state and user interactions
@MainActor
class PlayerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var urlInput: String = ""
    @Published var selectedMode: PlaybackMode = .video
    @Published var showingPlayer: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published private(set) var isExtracting: Bool = false
    
    // MARK: - Services
    private let youtubeService = YouTubeService.shared
    let playerService = AudioPlayerService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Subscribe to playerService changes to trigger UI updates
        playerService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Subscribe to track ended events for auto-play next
        playerService.trackEndedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handleTrackEnded()
            }
            .store(in: &cancellables)
        
        // Subscribe to remote control commands (Control Center, Lock Screen, Bluetooth)
        NotificationCenter.default.publisher(for: .remoteNextTrackCommand)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.playNextTrack()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .remotePreviousTrackCommand)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.playPreviousTrack()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Auto-Play Next Track
    
    /// Called when current track finishes playing
    private func handleTrackEnded() {
        let queueService = QueueService.shared
        let repeatMode = playerService.repeatMode
        
        // Check if there's a next track in queue
        if queueService.hasNext {
            // Play next track
            queueService.next()
            if let nextItem = queueService.currentItem {
                urlInput = nextItem.videoId
                Task {
                    await loadAndPlay(fromPlaylist: true)
                }
            }
        } else if repeatMode == .all && queueService.count > 0 {
            // Repeat all: loop back to first track
            queueService.setCurrentIndex(0)
            if let firstItem = queueService.currentItem {
                urlInput = firstItem.videoId
                Task {
                    await loadAndPlay(fromPlaylist: true)
                }
            }
        }
        // If repeat mode is .off and no next track, just stay paused (already handled by AudioPlayerService)
    }
    
    /// Play next track in queue (for remote control and UI)
    func playNextTrack() {
        let queueService = QueueService.shared
        guard queueService.hasNext else { return }
        
        queueService.next()
        if let nextItem = queueService.currentItem {
            urlInput = nextItem.videoId
            Task {
                await loadAndPlay(fromPlaylist: true)
            }
        }
    }
    
    /// Play previous track in queue (for remote control and UI)
    func playPreviousTrack() {
        let queueService = QueueService.shared
        guard queueService.hasPrevious else { return }
        
        queueService.previous()
        if let prevItem = queueService.currentItem {
            urlInput = prevItem.videoId
            Task {
                await loadAndPlay(fromPlaylist: true)
            }
        }
    }
    
    // MARK: - Computed Properties
    var currentTrack: Track? { playerService.currentTrack }
    var state: PlayerState { playerService.state }
    var currentTime: TimeInterval { playerService.currentTime }
    var duration: TimeInterval { playerService.duration }
    var progress: Double { playerService.progress }
    var isPlaying: Bool { playerService.state.isPlaying }
    var isLoading: Bool { isExtracting || playerService.state.isLoading }
    var playbackMode: PlaybackMode { playerService.playbackMode }
    var repeatMode: RepeatMode { playerService.repeatMode }
    

    
    // MARK: - Actions
    
    /// Load and play from URL or video ID
    /// - Parameters:
    ///   - searchResult: Optional search result metadata to use instead of extracting from scratch
    ///   - fromPlaylist: If true, keeps the current queue; if false, clears queue for single-track playback
    func loadAndPlay(searchResult: SearchResult? = nil, fromPlaylist: Bool = false) async {
        let input = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            showError(message: "Please enter a YouTube URL or video ID")
            return
        }
        
        // Check if video is already playing to avoid reloading
        if let targetID = YouTubeService.extractVideoID(from: input),
           let currentTrack = currentTrack,
           targetID == currentTrack.id {
            print("▶️ Video \(targetID) is already loaded. Opening player.")
            showingPlayer = true
            urlInput = "" // Clear input to keep UI clean
            return
        }
        
        isExtracting = true
        
        do {
            var track = try await youtubeService.extractTrack(from: input)
            
            // If we have search result metadata, use it to improve the track info
            if let result = searchResult {
                track = Track(
                    id: track.id,
                    title: result.title,
                    author: result.author,
                    thumbnailURL: result.thumbnailURL ?? track.thumbnailURL, // Prefer search thumbnail
                    duration: track.duration,
                    audioStreamURL: track.audioStreamURL,
                    videoStreamURL: track.videoStreamURL,
                    videoOnlyStreamURL: track.videoOnlyStreamURL,
                    separateAudioURL: track.separateAudioURL,
                    resolution: track.resolution
                )
            }
            
            isExtracting = false
            playerService.play(track, mode: selectedMode)
            
            // If playing single track (not from playlist), clear queue and set single item
            if !fromPlaylist {
                let queueItem = track.toQueueItem()
                QueueService.shared.playSingleTrack(queueItem)
            }
            
            // Record to recently played history
            HistoryService.shared.recordPlay(track)
            
            showingPlayer = true
            urlInput = "" // Clear input on successful load
        } catch {
            isExtracting = false
            showError(message: error.localizedDescription)
        }
    }
    

    
    /// Toggle play/pause
    func togglePlayPause() {
        playerService.togglePlayPause()
    }
    
    /// Stop playback
    func stop() {
        playerService.stop()
        showingPlayer = false
    }
    
    /// Seek to position
    func seek(to progress: Double) {
        let time = progress * duration
        playerService.seek(to: time)
    }
    
    /// Toggle repeat mode
    func toggleRepeatMode() {
        playerService.toggleRepeatMode()
    }
    
    /// Switch playback mode while maintaining current playback position
    func switchMode(to mode: PlaybackMode) {
        guard let track = currentTrack, mode != playbackMode else { return }
        selectedMode = mode
        
        // Try seamless switching first (works when both modes use the same stream)
        if playerService.switchMode(to: mode) {
            // Seamless switch succeeded, no reload needed
            return
        }
        
        // Fallback: reload with seekTime if streams are different
        let currentSeekTime = currentTime
        
        // Add a small delay to ensure VideoPlayerView is fully dismantled and doesn't interfere
        // with the new playback request. This prevents the "stop after switch" issue.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.playerService.play(track, mode: mode, seekTime: currentSeekTime)
        }
    }
    
    /// Reload current track with updated quality settings
    func reloadWithQuality(seekTime: TimeInterval) async {
        let input = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        isExtracting = true
        
        do {
            let track = try await youtubeService.extractTrack(from: input)
            isExtracting = false
            playerService.play(track, mode: selectedMode, seekTime: seekTime)
        } catch {
            isExtracting = false
            showError(message: error.localizedDescription)
        }
    }
    
    // MARK: - Error Handling
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
}

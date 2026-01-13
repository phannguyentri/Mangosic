import Foundation
import Combine

/// ViewModel for managing player state and user interactions
@MainActor
class PlayerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var urlInput: String = ""
    @Published var selectedMode: PlaybackMode = .audio
    @Published var showingPlayer: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Services
    private let youtubeService = YouTubeService.shared
    let playerService = AudioPlayerService.shared
    
    // MARK: - Computed Properties
    var currentTrack: Track? { playerService.currentTrack }
    var state: PlayerState { playerService.state }
    var currentTime: TimeInterval { playerService.currentTime }
    var duration: TimeInterval { playerService.duration }
    var progress: Double { playerService.progress }
    var isPlaying: Bool { playerService.state.isPlaying }
    var isLoading: Bool { playerService.state.isLoading }
    var playbackMode: PlaybackMode { playerService.playbackMode }
    
    // MARK: - Sample URLs for testing
    let sampleURLs = [
        ("Lofi Girl", "jfKfPfyJRdk"),
        ("Relaxing Music", "lTRiuFIWV54"),
        ("Nature Sounds", "eKFTSSKCzWA")
    ]
    
    // MARK: - Actions
    
    /// Load and play from URL or video ID
    func loadAndPlay() async {
        let input = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            showError(message: "Please enter a YouTube URL or video ID")
            return
        }
        
        do {
            let track = try await youtubeService.extractTrack(from: input)
            playerService.play(track, mode: selectedMode)
            showingPlayer = true
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    /// Play a sample video
    func playSample(_ videoId: String) async {
        urlInput = videoId
        await loadAndPlay()
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
    
    /// Switch playback mode
    func switchMode(to mode: PlaybackMode) {
        guard let track = currentTrack, mode != playbackMode else { return }
        selectedMode = mode
        playerService.play(track, mode: mode)
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

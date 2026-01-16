import SwiftUI
import SwiftData

@main
struct MangosicApp: App {
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var deepLinkManager = DeepLinkManager()
    @StateObject private var queueService = QueueService.shared
    @StateObject private var playlistService = PlaylistService.shared
    @StateObject private var historyService = HistoryService.shared
    
    /// SwiftData model container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Playlist.self,
            PlaylistTrackItem.self,
            RecentPlay.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(playerViewModel)
                .environmentObject(deepLinkManager)
                .environmentObject(queueService)
                .environmentObject(playlistService)
                .environmentObject(historyService)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    setupServices()
                    checkForSharedVideo()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    /// Configure services with model context
    private func setupServices() {
        let context = sharedModelContainer.mainContext
        PlaylistService.shared.configure(with: context)
        HistoryService.shared.configure(with: context)
    }
    
    /// Handle URL opened from Share Extension
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "mangosic" else { return }
        
        // Parse: mangosic://play?v=VIDEO_ID
        if url.host == "play" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let videoID = components?.queryItems?.first(where: { $0.name == "v" })?.value {
                deepLinkManager.pendingVideoID = videoID
                playVideo(videoID: videoID)
            }
        }
    }
    
    /// Check App Group shared storage for video shared while app was closed
    private func checkForSharedVideo() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.example.Mangosic"),
              let videoID = sharedDefaults.string(forKey: "sharedVideoID"),
              let timestamp = sharedDefaults.object(forKey: "sharedVideoTimestamp") as? Date else {
            return
        }
        
        // Only process if shared within last 30 seconds
        if Date().timeIntervalSince(timestamp) < 30 {
            sharedDefaults.removeObject(forKey: "sharedVideoID")
            sharedDefaults.removeObject(forKey: "sharedVideoTimestamp")
            sharedDefaults.synchronize()
            
            deepLinkManager.pendingVideoID = videoID
            playVideo(videoID: videoID)
        }
    }
    
    /// Play video with given ID
    private func playVideo(videoID: String) {
        Task { @MainActor in
            playerViewModel.urlInput = videoID
            await playerViewModel.loadAndPlay()
        }
    }
}

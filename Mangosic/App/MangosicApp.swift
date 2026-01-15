import SwiftUI

@main
struct MangosicApp: App {
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var deepLinkManager = DeepLinkManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerViewModel)
                .environmentObject(deepLinkManager)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    checkForSharedVideo()
                }
        }
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

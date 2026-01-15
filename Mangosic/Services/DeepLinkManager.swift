import SwiftUI
import Combine

/// Manager to handle deep links from Share Extension
@MainActor
class DeepLinkManager: ObservableObject {
    /// Video ID waiting to be played (from share or URL scheme)
    @Published var pendingVideoID: String?
    
    /// Whether we're currently processing a deep link
    @Published var isProcessingDeepLink: Bool = false
    
    /// Clear the pending video after handling
    func clearPendingVideo() {
        pendingVideoID = nil
        isProcessingDeepLink = false
    }
    
    /// Check if there's a pending video to play
    var hasPendingVideo: Bool {
        pendingVideoID != nil
    }
}

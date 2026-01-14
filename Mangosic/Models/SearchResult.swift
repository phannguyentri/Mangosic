import Foundation

/// Represents a YouTube search result item
struct SearchResult: Identifiable, Equatable {
    let id: String  // YouTube video ID
    let title: String
    let author: String
    let thumbnailURL: URL?
    let duration: String?
    let viewCount: String?
    let publishedTime: String?
    
    /// Convert to Track for playback
    func toTrack() -> Track {
        Track(
            id: id,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: nil,
            audioStreamURL: nil,
            videoStreamURL: nil,
            resolution: nil
        )
    }
}

/// Search state for UI
enum SearchState: Equatable {
    case idle
    case loading
    case loaded([SearchResult])
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var results: [SearchResult] {
        if case .loaded(let results) = self { return results }
        return []
    }
}

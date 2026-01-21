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
            duration: parseDuration(duration),
            audioStreamURL: nil,
            videoStreamURL: nil,
            videoOnlyStreamURL: nil,
            separateAudioURL: nil,
            resolution: nil
        )
    }
    
    private func parseDuration(_ durationString: String?) -> TimeInterval? {
        guard let durationString = durationString else { return nil }
        
        // Remove any non-duration characters if necessary (though usually it's just numbers and colons)
        let cleanString = durationString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanString.isEmpty, cleanString != "--:--" else { return nil }
        
        let components = cleanString.components(separatedBy: ":")
        
        var totalSeconds: TimeInterval = 0
        for (index, component) in components.reversed().enumerated() {
            if let value = Double(component) {
                totalSeconds += value * pow(60, Double(index))
            }
        }
        
        return totalSeconds > 0 ? totalSeconds : nil
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

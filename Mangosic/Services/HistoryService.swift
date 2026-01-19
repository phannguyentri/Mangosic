import Foundation
import SwiftData

/// Service for tracking recently played songs
@MainActor
final class HistoryService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = HistoryService()
    
    // MARK: - Constants
    
    /// Maximum number of recent plays to keep
    private let maxHistoryCount = 100
    
    // MARK: - Properties
    
    private var modelContext: ModelContext?
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Setup
    
    /// Configure with model context (call from App init)
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Clean up any existing duplicates on startup
        Task { @MainActor in
            deduplicateHistory()
        }
    }
    
    // MARK: - Record Play
    
    /// Record a track being played
    func recordPlay(videoId: String, title: String, author: String, thumbnailURL: URL?, duration: String?) {
        guard let context = modelContext else {
            print("⚠️ HistoryService: ModelContext not configured")
            return
        }
        
        // Check if this video is already in history
        let descriptor = FetchDescriptor<RecentPlay>(
            predicate: #Predicate { $0.videoId == videoId }
        )
        
        do {
            let existing = try context.fetch(descriptor)
            
            if let first = existing.first {
                // Update timestamp to bring it to top
                first.playedAt = Date()
                
                // Update details in case they changed
                first.title = title
                first.author = author
                first.thumbnailURL = thumbnailURL
                first.duration = duration
                
                // Remove any other duplicates if they exist (cleanup legacy duplicates)
                if existing.count > 1 {
                    for i in 1..<existing.count {
                        context.delete(existing[i])
                    }
                }
                
                try context.save()
                return
            }
        } catch {
            print("⚠️ HistoryService: Error checking existing plays: \(error)")
        }
        
        // Create new entry
        let recentPlay = RecentPlay(
            videoId: videoId,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: duration
        )
        
        context.insert(recentPlay)
        
        do {
            try context.save()
            
            // Cleanup old entries if over limit
            cleanupOldEntries()
        } catch {
            print("⚠️ HistoryService: Error saving recent play: \(error)")
        }
    }
    
    /// Record play from SearchResult
    func recordPlay(_ searchResult: SearchResult) {
        recordPlay(
            videoId: searchResult.id,
            title: searchResult.title,
            author: searchResult.author,
            thumbnailURL: searchResult.thumbnailURL,
            duration: searchResult.duration
        )
    }
    
    /// Record play from Track
    func recordPlay(_ track: Track) {
        recordPlay(
            videoId: track.id,
            title: track.title,
            author: track.author,
            thumbnailURL: track.thumbnailURL,
            duration: track.formattedDuration
        )
    }
    
    /// Record play from QueueItem
    func recordPlay(_ queueItem: QueueItem) {
        recordPlay(
            videoId: queueItem.videoId,
            title: queueItem.title,
            author: queueItem.author,
            thumbnailURL: queueItem.thumbnailURL,
            duration: queueItem.duration
        )
    }
    
    // MARK: - Fetch History
    
    /// Get recent plays, sorted by most recent first
    func getRecentPlays(limit: Int = 20) -> [RecentPlay] {
        guard let context = modelContext else {
            print("⚠️ HistoryService: ModelContext not configured")
            return []
        }
        
        var descriptor = FetchDescriptor<RecentPlay>(
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("⚠️ HistoryService: Error fetching recent plays: \(error)")
            return []
        }
    }
    
    /// Get all recent plays
    func getAllRecentPlays() -> [RecentPlay] {
        return getRecentPlays(limit: maxHistoryCount)
    }
    
    // MARK: - Delete
    
    /// Remove a specific entry
    func removePlay(_ recentPlay: RecentPlay) {
        guard let context = modelContext else { return }
        
        context.delete(recentPlay)
        
        do {
            try context.save()
        } catch {
            print("⚠️ HistoryService: Error deleting recent play: \(error)")
        }
    }
    
    /// Remove play by video ID
    func removePlay(videoId: String) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<RecentPlay>(
            predicate: #Predicate { $0.videoId == videoId }
        )
        
        do {
            let plays = try context.fetch(descriptor)
            for play in plays {
                context.delete(play)
            }
            try context.save()
        } catch {
            print("⚠️ HistoryService: Error deleting plays by videoId: \(error)")
        }
    }
    
    /// Clear all history
    func clearHistory() {
        guard let context = modelContext else { return }
        
        do {
            try context.delete(model: RecentPlay.self)
            try context.save()
        } catch {
            print("⚠️ HistoryService: Error clearing history: \(error)")
        }
    }
    
    // MARK: - Private Helpers
    
    /// Remove old entries if over limit
    private func cleanupOldEntries() {
        guard let context = modelContext else { return }
        
        var descriptor = FetchDescriptor<RecentPlay>(
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        
        do {
            let allPlays = try context.fetch(descriptor)
            
            if allPlays.count > maxHistoryCount {
                // Delete oldest entries
                let toDelete = allPlays.dropFirst(maxHistoryCount)
                for play in toDelete {
                    context.delete(play)
                }
                try context.save()
            }
        } catch {
            print("⚠️ HistoryService: Error cleaning up old entries: \(error)")
        }
    }
    
    /// Deduplicate history entries
    private func deduplicateHistory() {
        guard let context = modelContext else { return }
        
        var descriptor = FetchDescriptor<RecentPlay>(
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        
        do {
            let allPlays = try context.fetch(descriptor)
            var seenVideoIds = Set<String>()
            
            for play in allPlays {
                if seenVideoIds.contains(play.videoId) {
                    context.delete(play)
                } else {
                    seenVideoIds.insert(play.videoId)
                }
            }
            try context.save()
        } catch {
            print("⚠️ HistoryService: Error deduplicating history: \(error)")
        }
    }
}

// MARK: - Convenience

extension HistoryService {
    
    /// Check if a video was played recently
    func wasPlayedRecently(videoId: String) -> Bool {
        guard let context = modelContext else { return false }
        
        let descriptor = FetchDescriptor<RecentPlay>(
            predicate: #Predicate { $0.videoId == videoId }
        )
        
        do {
            let count = try context.fetchCount(descriptor)
            return count > 0
        } catch {
            return false
        }
    }
    
    /// Get the last played time for a video
    func lastPlayedTime(videoId: String) -> Date? {
        guard let context = modelContext else { return nil }
        
        var descriptor = FetchDescriptor<RecentPlay>(
            predicate: #Predicate { $0.videoId == videoId },
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        
        do {
            return try context.fetch(descriptor).first?.playedAt
        } catch {
            return nil
        }
    }
}

import Foundation
import Combine

/// Service managing the current playback queue (in-memory)
@MainActor
final class QueueService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = QueueService()
    
    // MARK: - Published Properties
    
    /// Current queue items
    @Published private(set) var queue: [QueueItem] = []
    
    /// Index of currently playing item (-1 if nothing playing)
    @Published private(set) var currentIndex: Int = -1
    
    /// Whether shuffle is enabled
    @Published var isShuffleEnabled: Bool = false
    
    /// Original queue order (for unshuffle)
    private var originalQueue: [QueueItem] = []
    
    // MARK: - Computed Properties
    
    /// Currently playing item
    var currentItem: QueueItem? {
        guard currentIndex >= 0 && currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }
    
    /// Items coming up next
    var upNext: [QueueItem] {
        guard currentIndex >= 0 && currentIndex < queue.count - 1 else { return [] }
        return Array(queue[(currentIndex + 1)...])
    }
    
    /// Items already played
    var playedItems: [QueueItem] {
        guard currentIndex > 0 else { return [] }
        return Array(queue[0..<currentIndex])
    }
    
    /// Whether queue has items
    var hasQueue: Bool {
        !queue.isEmpty
    }
    
    /// Whether there's a next track
    var hasNext: Bool {
        currentIndex < queue.count - 1
    }
    
    /// Whether there's a previous track
    var hasPrevious: Bool {
        currentIndex > 0
    }
    
    /// Number of tracks in queue
    var count: Int {
        queue.count
    }
    
    /// Number of tracks remaining (after current)
    var remainingCount: Int {
        max(0, queue.count - currentIndex - 1)
    }
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Queue Management
    
    /// Set a new queue and start playing from beginning
    func setQueue(_ items: [QueueItem], startIndex: Int = 0) {
        originalQueue = items
        queue = items
        currentIndex = min(startIndex, max(0, items.count - 1))
        
        if isShuffleEnabled && !items.isEmpty {
            shuffleQueue(keepCurrent: true)
        }
    }
    
    /// Add item to end of queue
    func addToQueue(_ item: QueueItem) {
        queue.append(item)
        originalQueue.append(item)
    }
    
    /// Add multiple items to end of queue
    func addToQueue(_ items: [QueueItem]) {
        queue.append(contentsOf: items)
        originalQueue.append(contentsOf: items)
    }
    
    /// Insert item to play next (after current)
    func playNext(_ item: QueueItem) {
        let insertIndex = currentIndex + 1
        
        if insertIndex < queue.count {
            queue.insert(item, at: insertIndex)
        } else {
            queue.append(item)
        }
        
        // Also update original queue
        if insertIndex < originalQueue.count {
            originalQueue.insert(item, at: insertIndex)
        } else {
            originalQueue.append(item)
        }
    }
    
    /// Remove item at index
    func removeItem(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        
        let removedItem = queue[index]
        queue.remove(at: index)
        
        // Also remove from original queue
        if let originalIndex = originalQueue.firstIndex(where: { $0.id == removedItem.id }) {
            originalQueue.remove(at: originalIndex)
        }
        
        // Adjust current index if needed
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            // Current item was removed, keep index same (will play next item now)
            currentIndex = min(currentIndex, queue.count - 1)
        }
    }
    
    /// Remove item by ID
    func removeItem(id: UUID) {
        if let index = queue.firstIndex(where: { $0.id == id }) {
            removeItem(at: index)
        }
    }
    
    /// Move item in queue
    func moveItem(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        
        // Update current index if affected
        if let sourceIndex = source.first {
            if sourceIndex == currentIndex {
                // Moving current item
                currentIndex = destination > sourceIndex ? destination - 1 : destination
            } else if sourceIndex < currentIndex && destination > currentIndex {
                // Moving item from before current to after
                currentIndex -= 1
            } else if sourceIndex > currentIndex && destination <= currentIndex {
                // Moving item from after current to before
                currentIndex += 1
            }
        }
    }
    
    /// Clear all items from queue
    func clearQueue() {
        queue.removeAll()
        originalQueue.removeAll()
        currentIndex = -1
    }
    
    /// Clear only upcoming items (keep played and current)
    func clearUpcoming() {
        guard currentIndex >= 0 && currentIndex < queue.count - 1 else { return }
        queue.removeSubrange((currentIndex + 1)...)
    }
    
    // MARK: - Playback Control
    
    /// Move to next track
    /// - Returns: Next QueueItem if available
    @discardableResult
    func next() -> QueueItem? {
        guard hasNext else { return nil }
        currentIndex += 1
        return currentItem
    }
    
    /// Move to previous track
    /// - Returns: Previous QueueItem if available
    @discardableResult
    func previous() -> QueueItem? {
        guard hasPrevious else { return nil }
        currentIndex -= 1
        return currentItem
    }
    
    /// Skip to specific index
    func skipTo(index: Int) {
        guard index >= 0 && index < queue.count else { return }
        currentIndex = index
    }
    
    /// Skip to specific item by ID
    func skipTo(id: UUID) {
        if let index = queue.firstIndex(where: { $0.id == id }) {
            skipTo(index: index)
        }
    }
    
    // MARK: - Shuffle
    
    /// Toggle shuffle mode
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        
        if isShuffleEnabled {
            shuffleQueue(keepCurrent: true)
        } else {
            unshuffleQueue()
        }
    }
    
    /// Shuffle the queue
    private func shuffleQueue(keepCurrent: Bool) {
        guard !queue.isEmpty else { return }
        
        // Save original order before shuffling (only save once)
        if originalQueue.isEmpty || originalQueue.count != queue.count {
            originalQueue = queue
        }
        
        if keepCurrent, let current = currentItem {
            // Remove current, shuffle rest, put current at front
            var remaining = queue.filter { $0.videoId != current.videoId }
            remaining.shuffle()
            queue = [current] + remaining
            currentIndex = 0
        } else {
            queue.shuffle()
            currentIndex = 0
        }
    }
    
    /// Restore original order
    private func unshuffleQueue() {
        guard !originalQueue.isEmpty else { return }
        guard let current = currentItem else {
            queue = originalQueue
            currentIndex = 0
            return
        }
        
        // Create a filtered originalQueue that only contains items currently in queue
        let currentVideoIds = Set(queue.map { $0.videoId })
        let filteredOriginal = originalQueue.filter { currentVideoIds.contains($0.videoId) }
        
        // Restore order from filtered original
        queue = filteredOriginal
        
        // Find current item in restored queue by videoId
        if let newIndex = queue.firstIndex(where: { $0.videoId == current.videoId }) {
            currentIndex = newIndex
        } else {
            currentIndex = 0
        }
    }
    
    /// Shuffle and replace queue
    func shuffleAndPlay(_ items: [QueueItem]) {
        var shuffled = items
        shuffled.shuffle()
        originalQueue = items
        queue = shuffled
        currentIndex = 0
        isShuffleEnabled = true
    }
}

// MARK: - Convenience Methods for Common Types

extension QueueService {
    
    /// Add SearchResult to queue
    func addToQueue(_ searchResult: SearchResult) {
        addToQueue(searchResult.toQueueItem())
    }
    
    /// Play SearchResult next
    func playNext(_ searchResult: SearchResult) {
        playNext(searchResult.toQueueItem())
    }
    
    /// Add Track to queue
    func addToQueue(_ track: Track) {
        addToQueue(track.toQueueItem())
    }
    
    /// Play Track next
    func playNext(_ track: Track) {
        playNext(track.toQueueItem())
    }
    
    /// Set queue from SearchResults
    func setQueue(_ searchResults: [SearchResult], startIndex: Int = 0) {
        setQueue(searchResults.map { $0.toQueueItem() }, startIndex: startIndex)
    }
    
    /// Set queue from playlist items
    func setQueue(_ playlistItems: [PlaylistTrackItem], startIndex: Int = 0) {
        let sortedItems = playlistItems.sorted { $0.orderIndex < $1.orderIndex }
        setQueue(sortedItems.map { QueueItem(from: $0) }, startIndex: startIndex)
    }
}

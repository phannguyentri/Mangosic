import Foundation
import SwiftData

// MARK: - Playlist Model

/// User-created playlist containing tracks
@Model
final class Playlist {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \PlaylistTrackItem.playlist)
    var tracks: [PlaylistTrackItem] = []
    
    /// Cover image URL (from first track)
    var coverURL: URL? {
        tracks.sorted { $0.orderIndex < $1.orderIndex }.first?.thumbnailURL
    }
    
    /// Number of tracks in playlist
    var trackCount: Int {
        tracks.count
    }
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tracks = []
    }
}

// MARK: - PlaylistTrackItem Model

/// A track within a playlist
@Model
final class PlaylistTrackItem {
    var id: UUID = UUID()
    var videoId: String = ""
    var title: String = ""
    var author: String = ""
    var thumbnailURL: URL?
    var duration: String?
    var addedAt: Date = Date()
    var orderIndex: Int = 0
    
    var playlist: Playlist?
    
    init(
        videoId: String,
        title: String,
        author: String,
        thumbnailURL: URL? = nil,
        duration: String? = nil,
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.videoId = videoId
        self.title = title
        self.author = author
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.addedAt = Date()
        self.orderIndex = orderIndex
    }
}

// MARK: - RecentPlay Model

/// Track played recently (for history)
@Model
final class RecentPlay {
    var id: UUID = UUID()
    var videoId: String = ""
    var title: String = ""
    var author: String = ""
    var thumbnailURL: URL?
    var duration: String?
    var playedAt: Date = Date()
    
    init(
        videoId: String,
        title: String,
        author: String,
        thumbnailURL: URL? = nil,
        duration: String? = nil
    ) {
        self.id = UUID()
        self.videoId = videoId
        self.title = title
        self.author = author
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.playedAt = Date()
    }
}

// MARK: - QueueItem (In-Memory)

/// Item in the current playback queue (not persisted)
struct QueueItem: Identifiable, Equatable {
    let id: UUID
    let videoId: String
    let title: String
    let author: String
    let thumbnailURL: URL?
    let duration: String?
    
    init(
        id: UUID = UUID(),
        videoId: String,
        title: String,
        author: String,
        thumbnailURL: URL? = nil,
        duration: String? = nil
    ) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.author = author
        self.thumbnailURL = thumbnailURL
        self.duration = duration
    }
    
    /// Create from SearchResult
    init(from searchResult: SearchResult) {
        self.id = UUID()
        self.videoId = searchResult.id
        self.title = searchResult.title
        self.author = searchResult.author
        self.thumbnailURL = searchResult.thumbnailURL
        self.duration = searchResult.duration
    }
    
    /// Create from Track
    init(from track: Track) {
        self.id = UUID()
        self.videoId = track.id
        self.title = track.title
        self.author = track.author
        self.thumbnailURL = track.thumbnailURL
        self.duration = track.formattedDuration
    }
    
    /// Create from PlaylistTrackItem
    init(from playlistItem: PlaylistTrackItem) {
        self.id = UUID()
        self.videoId = playlistItem.videoId
        self.title = playlistItem.title
        self.author = playlistItem.author
        self.thumbnailURL = playlistItem.thumbnailURL
        self.duration = playlistItem.duration
    }
    
    /// Create from RecentPlay
    init(from recentPlay: RecentPlay) {
        self.id = UUID()
        self.videoId = recentPlay.videoId
        self.title = recentPlay.title
        self.author = recentPlay.author
        self.thumbnailURL = recentPlay.thumbnailURL
        self.duration = recentPlay.duration
    }
}

// MARK: - Extensions for Conversion

extension SearchResult {
    /// Convert to QueueItem
    func toQueueItem() -> QueueItem {
        QueueItem(from: self)
    }
    
    /// Convert to PlaylistTrackItem
    func toPlaylistTrackItem(orderIndex: Int = 0) -> PlaylistTrackItem {
        PlaylistTrackItem(
            videoId: id,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: duration,
            orderIndex: orderIndex
        )
    }
    
    /// Convert to RecentPlay
    func toRecentPlay() -> RecentPlay {
        RecentPlay(
            videoId: id,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: duration
        )
    }
}

extension Track {
    /// Convert to QueueItem
    func toQueueItem() -> QueueItem {
        QueueItem(from: self)
    }
    
    /// Convert to PlaylistTrackItem
    func toPlaylistTrackItem(orderIndex: Int = 0) -> PlaylistTrackItem {
        PlaylistTrackItem(
            videoId: id,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: formattedDuration,
            orderIndex: orderIndex
        )
    }
    
    /// Convert to RecentPlay
    func toRecentPlay() -> RecentPlay {
        RecentPlay(
            videoId: id,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: formattedDuration
        )
    }
}

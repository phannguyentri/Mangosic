import Foundation
import SwiftData

/// Service for managing user playlists (CRUD operations)
@MainActor
final class PlaylistService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PlaylistService()
    
    // MARK: - Published Properties
    
    /// All playlists
    @Published private(set) var playlists: [Playlist] = []
    
    // MARK: - Properties
    
    private var modelContext: ModelContext?
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Setup
    
    /// Configure with model context (call from App init)
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchPlaylists()
    }
    
    // MARK: - Fetch
    
    /// Fetch all playlists from storage
    func fetchPlaylists() {
        guard let context = modelContext else {
            print("⚠️ PlaylistService: ModelContext not configured")
            return
        }
        
        let descriptor = FetchDescriptor<Playlist>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        do {
            playlists = try context.fetch(descriptor)
        } catch {
            print("⚠️ PlaylistService: Error fetching playlists: \(error)")
            playlists = []
        }
    }
    
    /// Get a specific playlist by ID
    func getPlaylist(id: UUID) -> Playlist? {
        guard let context = modelContext else { return nil }
        
        let descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            return try context.fetch(descriptor).first
        } catch {
            print("⚠️ PlaylistService: Error fetching playlist: \(error)")
            return nil
        }
    }
    
    // MARK: - Create
    
    /// Create a new playlist
    @discardableResult
    func createPlaylist(name: String) -> Playlist {
        guard let context = modelContext else {
            fatalError("PlaylistService: ModelContext not configured")
        }
        
        let playlist = Playlist(name: name)
        context.insert(playlist)
        
        do {
            try context.save()
            fetchPlaylists()
        } catch {
            print("⚠️ PlaylistService: Error creating playlist: \(error)")
        }
        
        return playlist
    }
    
    // MARK: - Update
    
    /// Rename a playlist
    func renamePlaylist(_ playlist: Playlist, to newName: String) {
        playlist.name = newName
        playlist.updatedAt = Date()
        
        saveContext()
        fetchPlaylists()
    }
    
    /// Add track to playlist
    func addTrack(
        videoId: String,
        title: String,
        author: String,
        thumbnailURL: URL?,
        duration: String?,
        to playlist: Playlist
    ) {
        // Check if already exists
        if playlist.tracks.contains(where: { $0.videoId == videoId }) {
            print("ℹ️ Track already in playlist")
            return
        }
        
        let orderIndex = playlist.tracks.count
        let trackItem = PlaylistTrackItem(
            videoId: videoId,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: duration,
            orderIndex: orderIndex
        )
        
        playlist.tracks.append(trackItem)
        playlist.updatedAt = Date()
        
        saveContext()
        fetchPlaylists()
    }
    
    /// Add SearchResult to playlist
    func addTrack(_ searchResult: SearchResult, to playlist: Playlist) {
        addTrack(
            videoId: searchResult.id,
            title: searchResult.title,
            author: searchResult.author,
            thumbnailURL: searchResult.thumbnailURL,
            duration: searchResult.duration,
            to: playlist
        )
    }
    
    /// Add Track to playlist
    func addTrack(_ track: Track, to playlist: Playlist) {
        addTrack(
            videoId: track.id,
            title: track.title,
            author: track.author,
            thumbnailURL: track.thumbnailURL,
            duration: track.formattedDuration,
            to: playlist
        )
    }
    
    /// Add QueueItem to playlist
    func addTrack(_ queueItem: QueueItem, to playlist: Playlist) {
        addTrack(
            videoId: queueItem.videoId,
            title: queueItem.title,
            author: queueItem.author,
            thumbnailURL: queueItem.thumbnailURL,
            duration: queueItem.duration,
            to: playlist
        )
    }
    
    /// Remove track from playlist
    func removeTrack(_ trackItem: PlaylistTrackItem, from playlist: Playlist) {
        guard let context = modelContext else { return }
        
        playlist.tracks.removeAll { $0.id == trackItem.id }
        context.delete(trackItem)
        playlist.updatedAt = Date()
        
        // Reorder remaining tracks
        reorderTracks(in: playlist)
        
        saveContext()
        fetchPlaylists()
    }
    
    /// Remove track by video ID from playlist
    func removeTrack(videoId: String, from playlist: Playlist) {
        guard let context = modelContext else { return }
        
        let tracksToRemove = playlist.tracks.filter { $0.videoId == videoId }
        for track in tracksToRemove {
            playlist.tracks.removeAll { $0.id == track.id }
            context.delete(track)
        }
        playlist.updatedAt = Date()
        
        reorderTracks(in: playlist)
        
        saveContext()
        fetchPlaylists()
    }
    
    /// Move track within playlist
    func moveTrack(from source: IndexSet, to destination: Int, in playlist: Playlist) {
        var tracks = playlist.tracks.sorted { $0.orderIndex < $1.orderIndex }
        tracks.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, track) in tracks.enumerated() {
            track.orderIndex = index
        }
        
        playlist.updatedAt = Date()
        
        saveContext()
        fetchPlaylists()
    }
    
    // MARK: - Delete
    
    /// Delete a playlist
    func deletePlaylist(_ playlist: Playlist) {
        guard let context = modelContext else { return }
        
        context.delete(playlist)
        
        do {
            try context.save()
            fetchPlaylists()
        } catch {
            print("⚠️ PlaylistService: Error deleting playlist: \(error)")
        }
    }
    
    /// Delete playlist by ID
    func deletePlaylist(id: UUID) {
        if let playlist = getPlaylist(id: id) {
            deletePlaylist(playlist)
        }
    }
    
    // MARK: - Private Helpers
    
    private func saveContext() {
        guard let context = modelContext else { return }
        
        do {
            try context.save()
        } catch {
            print("⚠️ PlaylistService: Error saving context: \(error)")
        }
    }
    
    private func reorderTracks(in playlist: Playlist) {
        let sortedTracks = playlist.tracks.sorted { $0.orderIndex < $1.orderIndex }
        for (index, track) in sortedTracks.enumerated() {
            track.orderIndex = index
        }
    }
}

// MARK: - Convenience

extension PlaylistService {
    
    /// Get sorted tracks from playlist
    func getSortedTracks(from playlist: Playlist) -> [PlaylistTrackItem] {
        playlist.tracks.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    /// Check if a video is in a playlist
    func isTrackInPlaylist(videoId: String, playlist: Playlist) -> Bool {
        playlist.tracks.contains { $0.videoId == videoId }
    }
    
    /// Get all playlists containing a video
    func playlistsContaining(videoId: String) -> [Playlist] {
        playlists.filter { playlist in
            playlist.tracks.contains { $0.videoId == videoId }
        }
    }
    
    /// Duplicate a playlist
    @discardableResult
    func duplicatePlaylist(_ playlist: Playlist, newName: String? = nil) -> Playlist {
        let name = newName ?? "\(playlist.name) (Copy)"
        let newPlaylist = createPlaylist(name: name)
        
        for track in getSortedTracks(from: playlist) {
            addTrack(
                videoId: track.videoId,
                title: track.title,
                author: track.author,
                thumbnailURL: track.thumbnailURL,
                duration: track.duration,
                to: newPlaylist
            )
        }
        
        return newPlaylist
    }
}

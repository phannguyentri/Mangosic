import SwiftUI

/// Context menu for track actions (add to queue, playlist, etc.)
struct TrackContextMenu: View {
    let track: TrackInfo
    let onPlayNext: () -> Void
    let onAddToQueue: () -> Void
    let onAddToPlaylist: () -> Void
    
    var body: some View {
        Group {
            Button {
                onPlayNext()
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            Button {
                onAddToQueue()
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            
            Divider()
            
            Button {
                onAddToPlaylist()
            } label: {
                Label("Add to Playlist", systemImage: "music.note.list")
            }
            
            Divider()
            
            if let url = URL(string: "https://youtube.com/watch?v=\(track.videoId)") {
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

/// Protocol for items that can be used in context menus
protocol TrackInfo {
    var videoId: String { get }
    var title: String { get }
    var author: String { get }
    var thumbnailURL: URL? { get }
    var displayDuration: String? { get }
}

// MARK: - Conformances

extension SearchResult: TrackInfo {
    var videoId: String { id }
    var displayDuration: String? { duration }
}

extension QueueItem: TrackInfo {
    var displayDuration: String? { duration }
}

extension Track: TrackInfo {
    var videoId: String { id }
    var displayDuration: String? { formattedDuration }
}

// MARK: - Add to Playlist Sheet

struct AddToPlaylistSheet: View {
    let track: TrackInfo
    @ObservedObject var playlistService: PlaylistService
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                MangosicBackground()
                
                if playlistService.playlists.isEmpty {
                    emptyState
                } else {
                    playlistList
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreatePlaylist = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.primaryEnd)
                    }
                }
            }
            .alert("New Playlist", isPresented: $showingCreatePlaylist) {
                TextField("Playlist name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        let playlist = playlistService.createPlaylist(name: newPlaylistName)
                        addToPlaylist(playlist)
                        newPlaylistName = ""
                    }
                }
            } message: {
                Text("Enter a name for your new playlist")
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Playlists Yet")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text("Create your first playlist to save songs")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button {
                showingCreatePlaylist = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Playlist")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.primaryGradient)
                .cornerRadius(25)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Playlist List
    
    private var playlistList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(playlistService.playlists) { playlist in
                    playlistRow(playlist)
                }
            }
            .padding(.top, 16)
        }
    }
    
    private func playlistRow(_ playlist: Playlist) -> some View {
        Button {
            addToPlaylist(playlist)
        } label: {
            HStack(spacing: 12) {
                // Cover image
                if let url = playlist.coverURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            playlistPlaceholder
                        }
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)
                } else {
                    playlistPlaceholder
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Text("\(playlist.trackCount) songs")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Check if already in playlist
                if playlistService.isTrackInPlaylist(videoId: track.videoId, playlist: playlist) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.primaryEnd)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    
    private var playlistPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                LinearGradient(
                    colors: [Theme.primaryStart.opacity(0.3), Theme.primaryEnd.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note.list")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            )
    }
    
    // MARK: - Actions
    
    private func addToPlaylist(_ playlist: Playlist) {
        playlistService.addTrack(
            videoId: track.videoId,
            title: track.title,
            author: track.author,
            thumbnailURL: track.thumbnailURL,
            duration: track.displayDuration,
            to: playlist
        )
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

#Preview {
    AddToPlaylistSheet(
        track: SearchResult(
            id: "test123",
            title: "Test Song",
            author: "Test Artist",
            thumbnailURL: nil,
            duration: "3:45",
            viewCount: nil,
            publishedTime: nil
        ),
        playlistService: PlaylistService.shared
    )
}

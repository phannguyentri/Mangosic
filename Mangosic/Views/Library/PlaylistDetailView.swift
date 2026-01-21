import SwiftUI
import SwiftData

/// Detail view for a playlist showing all tracks
struct PlaylistDetailView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    let playlist: Playlist
    @ObservedObject var playlistService: PlaylistService
    
    @State private var showingRename = false
    @State private var newName = ""
    @State private var showingDeleteConfirmation = false
    @State private var isLoadingPlaylist = false
    @State private var loadingType: LoadingType? = nil
    @Environment(\.dismiss) private var dismiss
    
    enum LoadingType {
        case play
        case shuffle
    }
    
    private var sortedTracks: [PlaylistTrackItem] {
        playlistService.getSortedTracks(from: playlist)
    }
    
    var body: some View {
        ZStack {
            MangosicBackground()
            
            if sortedTracks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header with play controls
                        playlistHeader
                        
                        // Tracks
                        ForEach(sortedTracks) { track in
                            PlaylistTrackRow(track: track) {
                                playTrack(track)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeTrack(track)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                        .onMove(perform: moveTracks)
                    }
                    .padding(.bottom, playerViewModel.currentTrack != nil ? 100 : 20)
                }
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newName = playlist.name
                        showingRename = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    Button {
                        playlistService.duplicatePlaylist(playlist)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Playlist", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.white)
                }
            }
        }
        .alert("Rename Playlist", isPresented: $showingRename) {
            TextField("Playlist name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                if !newName.isEmpty {
                    playlistService.renamePlaylist(playlist, to: newName)
                }
            }
        }
        .confirmationDialog("Delete Playlist?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                playlistService.deletePlaylist(playlist)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete \"\(playlist.name)\" and all its songs.")
        }
    }
    
    // MARK: - Playlist Header
    
    private var playlistHeader: some View {
        VStack(spacing: 16) {
            // Cover image
            if let url = playlist.coverURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        coverPlaceholder
                    }
                }
                .frame(width: 180, height: 180)
                .cornerRadius(12)
                .shadow(color: Theme.primaryEnd.opacity(0.3), radius: 20, y: 10)
            } else {
                coverPlaceholder
                    .frame(width: 180, height: 180)
                    .cornerRadius(12)
            }
            
            // Info
            VStack(spacing: 4) {
                Text("\(playlist.trackCount) songs")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // Play controls
            HStack(spacing: 16) {
                Button {
                    shufflePlay()
                } label: {
                    HStack(spacing: 8) {
                        if loadingType == .shuffle {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "shuffle")
                        }
                        Text(loadingType == .shuffle ? "Loading..." : "Shuffle")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(24)
                }
                .disabled(isLoadingPlaylist)
                
                Button {
                    playAll()
                } label: {
                    HStack(spacing: 8) {
                        if loadingType == .play {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(loadingType == .play ? "Loading..." : "Play")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if isLoadingPlaylist && loadingType == .play {
                                Theme.primaryEnd.opacity(0.7)
                            } else {
                                Theme.primaryGradient
                            }
                        }
                    )
                    .cornerRadius(24)
                }
                .disabled(isLoadingPlaylist)
            }
        }
        .padding(.vertical, 24)
    }
    
    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [Theme.primaryStart.opacity(0.4), Theme.primaryEnd.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note.list")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.5))
            )
            .shimmer()
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No songs yet")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text("Search for songs and add them to this playlist")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Actions
    
    private func playTrack(_ track: PlaylistTrackItem) {
        playerViewModel.urlInput = track.videoId
        
        // Set up queue with all tracks from this playlist
        let tracks = sortedTracks
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            let queueItems = tracks.map { QueueItem(from: $0) }
            QueueService.shared.setQueue(
                queueItems, 
                startIndex: index, 
                playlistName: playlist.name,
                playlistId: playlist.id
            )
        }
        
        Task {
            await playerViewModel.loadAndPlay(fromPlaylist: true)
        }
    }
    
    private func playAll() {
        guard let firstTrack = sortedTracks.first else { return }
        guard !isLoadingPlaylist else { return }
        
        isLoadingPlaylist = true
        loadingType = .play
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let queueItems = sortedTracks.map { QueueItem(from: $0) }
        QueueService.shared.setQueue(
            queueItems, 
            startIndex: 0,
            playlistName: playlist.name,
            playlistId: playlist.id
        )
        
        playerViewModel.urlInput = firstTrack.videoId
        Task {
            await playerViewModel.loadAndPlay(fromPlaylist: true)
            await MainActor.run {
                isLoadingPlaylist = false
                loadingType = nil
            }
        }
    }
    
    private func shufflePlay() {
        guard !sortedTracks.isEmpty else { return }
        guard !isLoadingPlaylist else { return }
        
        isLoadingPlaylist = true
        loadingType = .shuffle
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let queueItems = sortedTracks.map { QueueItem(from: $0) }
        QueueService.shared.shuffleAndPlay(queueItems, playlistName: playlist.name, playlistId: playlist.id)
        
        if let firstItem = QueueService.shared.currentItem {
            playerViewModel.urlInput = firstItem.videoId
            Task {
                await playerViewModel.loadAndPlay(fromPlaylist: true)
                await MainActor.run {
                    isLoadingPlaylist = false
                    loadingType = nil
                }
            }
        }
    }
    
    private func removeTrack(_ track: PlaylistTrackItem) {
        withAnimation {
            playlistService.removeTrack(track, from: playlist)
        }
    }
    
    private func moveTracks(from source: IndexSet, to destination: Int) {
        playlistService.moveTrack(from: source, to: destination, in: playlist)
    }
}

// MARK: - Playlist Track Row

struct PlaylistTrackRow: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    let track: PlaylistTrackItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
                
                // Thumbnail
                ZStack {
                    if let url = track.thumbnailURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                thumbnailPlaceholder
                            }
                        }
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                        .clipped()
                    } else {
                        thumbnailPlaceholder
                            .frame(width: 48, height: 48)
                            .cornerRadius(6)
                    }
                    
                    if playerViewModel.isLoading && playerViewModel.urlInput == track.videoId {
                        ZStack {
                            Color.black.opacity(0.6)
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.6)
                        }
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(track.author)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let duration = track.duration {
                    Text(duration)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.white.opacity(0.1))
            .overlay(
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundColor(.gray)
            )
            .shimmer()
    }
}

#Preview {
    NavigationStack {
        PlaylistDetailView(
            playlist: Playlist(name: "Test Playlist"),
            playlistService: PlaylistService.shared
        )
        .environmentObject(PlayerViewModel())
    }
}

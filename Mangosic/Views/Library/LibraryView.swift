import SwiftUI
import SwiftData

/// Main library tab view with Recently Played and Playlists sections
struct LibraryView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @ObservedObject var playlistService: PlaylistService
    @ObservedObject var historyService: HistoryService
    
    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""
    @State private var recentPlays: [RecentPlay] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MangosicBackground()
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        // Recently Played Section
                        recentlyPlayedSection
                        
                        // Playlists Section
                        playlistsSection
                    }
                    .padding(.top, 16)
                    .padding(.bottom, playerViewModel.currentTrack != nil ? 100 : 20)
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreatePlaylist = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.primaryGradient)
                    }
                }
            }
            .onAppear {
                loadRecentPlays()
            }
            .alert("New Playlist", isPresented: $showingCreatePlaylist) {
                TextField("Playlist name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        playlistService.createPlaylist(name: newPlaylistName)
                        newPlaylistName = ""
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            } message: {
                Text("Enter a name for your new playlist")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Recently Played Section
    
    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recently Played", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !recentPlays.isEmpty {
                    NavigationLink {
                        RecentlyPlayedListView(historyService: historyService)
                            .environmentObject(playerViewModel)
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundColor(Theme.primaryEnd)
                    }
                }
            }
            .padding(.horizontal)
            
            if recentPlays.isEmpty {
                emptyRecentState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(recentPlays) { play in
                            RecentPlayCard(recentPlay: play) {
                                playRecentTrack(play)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var emptyRecentState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No recent plays")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Songs you play will appear here")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Playlists Section
    
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Your Playlists", systemImage: "music.note.list")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal)
            
            if playlistService.playlists.isEmpty {
                emptyPlaylistState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(playlistService.playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist, playlistService: playlistService)
                                .environmentObject(playerViewModel)
                        } label: {
                            PlaylistRow(playlist: playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
    
    private var emptyPlaylistState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No playlists yet")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            
            Text("Create your first playlist to organize your favorite songs")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button {
                showingCreatePlaylist = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Playlist")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.primaryGradient)
                .cornerRadius(20)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    private func loadRecentPlays() {
        recentPlays = historyService.getRecentPlays(limit: 10)
    }
    
    private func playRecentTrack(_ play: RecentPlay) {
        playerViewModel.urlInput = play.videoId
        Task {
            await playerViewModel.loadAndPlay()
            historyService.recordPlay(
                videoId: play.videoId,
                title: play.title,
                author: play.author,
                thumbnailURL: play.thumbnailURL,
                duration: play.duration
            )
        }
    }
}

// MARK: - Recent Play Card

struct RecentPlayCard: View {
    let recentPlay: RecentPlay
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                if let url = recentPlay.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        default:
                            thumbnailPlaceholder
                        }
                    }
                    .frame(width: 140, height: 80)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    thumbnailPlaceholder
                        .frame(width: 140, height: 80)
                        .cornerRadius(8)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(recentPlay.title)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(recentPlay.author)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.1))
            .overlay(
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundColor(.gray.opacity(0.5))
            )
    }
}

// MARK: - Playlist Row

struct PlaylistRow: View {
    let playlist: Playlist
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let url = playlist.coverURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        playlistCoverPlaceholder
                    }
                }
                .frame(width: 56, height: 56)
                .cornerRadius(8)
                .clipped()
            } else {
                playlistCoverPlaceholder
                    .frame(width: 56, height: 56)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(playlist.trackCount) songs")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private var playlistCoverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [Theme.primaryStart.opacity(0.3), Theme.primaryEnd.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note.list")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.5))
            )
    }
}

#Preview {
    LibraryView(
        playlistService: PlaylistService.shared,
        historyService: HistoryService.shared
    )
    .environmentObject(PlayerViewModel())
}

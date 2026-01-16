import SwiftUI
import SwiftData

/// Full list view of recently played tracks
struct RecentlyPlayedListView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @ObservedObject var historyService: HistoryService
    @Environment(\.dismiss) private var dismiss
    
    @State private var recentPlays: [RecentPlay] = []
    @State private var showClearConfirmation = false
    
    var body: some View {
        ZStack {
            MangosicBackground()
            
            if recentPlays.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(recentPlays) { play in
                            RecentPlayRow(recentPlay: play) {
                                playTrack(play)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removePlay(play)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.bottom, playerViewModel.currentTrack != nil ? 100 : 20)
                }
            }
        }
        .navigationTitle("Recently Played")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !recentPlays.isEmpty {
                    Menu {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            loadHistory()
        }
        .confirmationDialog("Clear listening history?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                clearHistory()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all your recently played songs. This action cannot be undone.")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No listening history")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text("Songs you play will appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private func loadHistory() {
        recentPlays = historyService.getAllRecentPlays()
    }
    
    private func playTrack(_ play: RecentPlay) {
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
    
    private func removePlay(_ play: RecentPlay) {
        withAnimation {
            historyService.removePlay(play)
            recentPlays.removeAll { $0.id == play.id }
        }
    }
    
    private func clearHistory() {
        withAnimation {
            historyService.clearHistory()
            recentPlays.removeAll()
        }
    }
}

// MARK: - Recent Play Row

struct RecentPlayRow: View {
    let recentPlay: RecentPlay
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                if let url = recentPlay.thumbnailURL {
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
                    .frame(width: 56, height: 56)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    thumbnailPlaceholder
                        .frame(width: 56, height: 56)
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recentPlay.title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(recentPlay.author)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Text(timeAgo(recentPlay.playedAt))
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                
                Spacer()
                
                if let duration = recentPlay.duration {
                    Text(duration)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
    
    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.1))
            .overlay(
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundColor(.gray)
            )
    }
    
    private func timeAgo(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    NavigationStack {
        RecentlyPlayedListView(historyService: HistoryService.shared)
            .environmentObject(PlayerViewModel())
    }
}

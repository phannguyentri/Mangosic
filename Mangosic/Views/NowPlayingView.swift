import SwiftUI

/// View showing the current playing playlist
struct NowPlayingView: View {
    @ObservedObject var queueService: QueueService
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MangosicBackground()
                
                if queueService.queue.isEmpty {
                    emptyState
                } else {
                    playlistContent
                }
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.primaryEnd)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    // Shuffle button
                    Button {
                        withAnimation {
                            queueService.toggleShuffle()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(queueService.isShuffleEnabled ? Theme.primaryEnd : .white)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No playlist playing")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text("Play a song or playlist to see it here")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Playlist Content
    
    private var playlistContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Header info
                    playlistHeader
                    
                    // All tracks in playlist
                    ForEach(Array(queueService.queue.enumerated()), id: \.element.id) { index, item in
                        playlistItemRow(item, index: index)
                    }
                }
                .padding(.bottom, 100)
            }
            .onAppear {
                // Scroll to current playing track
                if let currentItem = queueService.currentItem {
                    withAnimation {
                        proxy.scrollTo(currentItem.id, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Playlist Header
    
    private var playlistHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(queueService.count) tracks")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if queueService.isShuffleEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "shuffle")
                            .font(.caption)
                        Text("Shuffle On")
                            .font(.caption)
                    }
                    .foregroundColor(Theme.primaryEnd)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    // MARK: - Playlist Item Row
    
    private func playlistItemRow(_ item: QueueItem, index: Int) -> some View {
        let isCurrentTrack = index == queueService.currentIndex
        
        return Button {
            playTrack(at: index)
        } label: {
            HStack(spacing: 12) {
                // Track number or playing indicator
                if isCurrentTrack {
                    NowPlayingBarsView()
                        .frame(width: 24, height: 20)
                } else {
                    Text("\(index + 1)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(width: 24)
                }
                
                // Thumbnail
                thumbnailView(item.thumbnailURL)
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(isCurrentTrack ? .bold : .regular)
                        .foregroundColor(isCurrentTrack ? Theme.primaryEnd : .white)
                        .lineLimit(1)
                    
                    Text(item.author)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let duration = item.duration {
                    Text(duration)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(isCurrentTrack ? Theme.primaryEnd.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(item.id)
    }
    
    // MARK: - Thumbnail View
    
    private func thumbnailView(_ url: URL?) -> some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        thumbnailPlaceholder
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 48, height: 48)
        .clipped()
        .cornerRadius(6)
    }
    
    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundColor(.gray)
            )
    }
    
    // MARK: - Actions
    
    private func playTrack(at index: Int) {
        queueService.skipTo(index: index)
        
        guard let item = queueService.currentItem else { return }
        playerViewModel.urlInput = item.videoId
        Task {
            await playerViewModel.loadAndPlay()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Animated Bars View for Now Playing indicator

struct NowPlayingBarsView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.primaryEnd)
                    .frame(width: 3)
                    .scaleEffect(y: animating ? CGFloat.random(in: 0.3...1.0) : 0.5, anchor: .bottom)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                animating = true
            }
        }
    }
}

#Preview {
    NowPlayingView(queueService: QueueService.shared)
        .environmentObject(PlayerViewModel())
}

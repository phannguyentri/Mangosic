import SwiftUI

/// View showing the current playback queue
struct QueueView: View {
    @ObservedObject var queueService: QueueService
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draggedItem: QueueItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MangosicBackground()
                
                if queueService.queue.isEmpty {
                    emptyState
                } else {
                    queueContent
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.primaryEnd)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            withAnimation {
                                queueService.clearQueue()
                            }
                        } label: {
                            Label("Clear Queue", systemImage: "trash")
                        }
                        
                        Button {
                            withAnimation {
                                queueService.toggleShuffle()
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Label(
                                queueService.isShuffleEnabled ? "Shuffle Off" : "Shuffle",
                                systemImage: "shuffle"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
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
            
            Text("Your queue is empty")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text("Add songs from search results to build your queue")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Queue Content
    
    private var queueContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Now Playing Section
                if let currentItem = queueService.currentItem {
                    Section {
                        nowPlayingRow(currentItem)
                    } header: {
                        sectionHeader(title: "Now Playing")
                    }
                }
                
                // Up Next Section
                if !queueService.upNext.isEmpty {
                    Section {
                        ForEach(Array(queueService.upNext.enumerated()), id: \.element.id) { index, item in
                            queueItemRow(item, index: queueService.currentIndex + 1 + index)
                        }
                        .onMove(perform: moveItems)
                    } header: {
                        HStack {
                            sectionHeader(title: "Up Next")
                            
                            Spacer()
                            
                            // Shuffle indicator
                            if queueService.isShuffleEnabled {
                                HStack(spacing: 4) {
                                    Image(systemName: "shuffle")
                                        .font(.caption)
                                    Text("Shuffle On")
                                        .font(.caption)
                                }
                                .foregroundColor(Theme.primaryEnd)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.primaryEnd.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.trailing)
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.gray)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Now Playing Row
    
    private func nowPlayingRow(_ item: QueueItem) -> some View {
        HStack(spacing: 12) {
            // Animated bars
            AnimatedBarsView()
                .frame(width: 20, height: 20)
            
            // Thumbnail
            thumbnailView(item.thumbnailURL)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.primaryEnd)
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
        .background(Theme.primaryEnd.opacity(0.1))
    }
    
    // MARK: - Queue Item Row
    
    private func queueItemRow(_ item: QueueItem, index: Int) -> some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.6))
            
            // Thumbnail
            thumbnailView(item.thumbnailURL)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
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
            
            // Remove button
            Button {
                withAnimation {
                    queueService.removeItem(id: item.id)
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            queueService.skipTo(index: index)
            playCurrentQueueItem()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                queueService.removeItem(id: item.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
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
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        // Adjust for being in "upNext" section (offset by currentIndex + 1)
        let adjustedSource = IndexSet(source.map { $0 + queueService.currentIndex + 1 })
        let adjustedDestination = destination + queueService.currentIndex + 1
        
        queueService.moveItem(from: adjustedSource, to: adjustedDestination)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func playCurrentQueueItem() {
        guard let item = queueService.currentItem else { return }
        playerViewModel.urlInput = item.videoId
        Task {
            await playerViewModel.loadAndPlay()
        }
    }
}

// MARK: - Animated Bars View

struct AnimatedBarsView: View {
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
    QueueView(queueService: QueueService.shared)
        .environmentObject(PlayerViewModel())
}

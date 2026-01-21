import SwiftUI

/// Button to show now playing playlist from mini player or full player
struct QueueButton: View {
    @ObservedObject var queueService: QueueService
    @State private var showingQueue = false
    
    var compact: Bool = false
    
    var body: some View {
        Button {
            showingQueue = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(compact ? .caption : .body)
                
                // Show total track count badge if there are tracks
                if !compact && queueService.count > 0 {
                    Text("\(queueService.count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.primaryEnd.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(.white)
            .padding(compact ? 8 : 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(compact ? 8 : 12)
        }
        .sheet(isPresented: $showingQueue) {
            NowPlayingView(queueService: queueService)
        }
    }
}

/// Shuffle toggle button
struct ShuffleButton: View {
    @ObservedObject var queueService: QueueService
    
    var body: some View {
        Button {
            queueService.toggleShuffle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: "shuffle")
                .font(.body)
                .foregroundColor(queueService.isShuffleEnabled ? Theme.primaryEnd : .white)
                .padding(12)
                .background(
                    queueService.isShuffleEnabled 
                        ? Theme.primaryEnd.opacity(0.2) 
                        : Color.white.opacity(0.1)
                )
                .cornerRadius(12)
        }
    }
}

#Preview("Queue Button") {
    ZStack {
        Color.black.ignoresSafeArea()
        QueueButton(queueService: QueueService.shared)
    }
}

#Preview("Shuffle Button") {
    ZStack {
        Color.black.ignoresSafeArea()
        ShuffleButton(queueService: QueueService.shared)
    }
}


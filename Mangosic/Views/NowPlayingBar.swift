import SwiftUI

/// Mini player bar shown at bottom of screen
struct NowPlayingBar: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            // Thumbnail
            AsyncImage(url: viewModel.currentTrack?.thumbnailURL, transaction: Transaction(animation: .easeInOut)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    thumbnailPlaceholder
                case .empty:
                    thumbnailPlaceholder
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.gray)
                        )
                @unknown default:
                    thumbnailPlaceholder
                }
            }
            .frame(width: 48, height: 48)
            .cornerRadius(6)
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentTrack?.title ?? "Unknown")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(viewModel.currentTrack?.author ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play/Pause button
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
        )
        .onTapGesture {
            viewModel.showingPlayer = true
        }
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
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        NowPlayingBar(viewModel: PlayerViewModel())
    }
}

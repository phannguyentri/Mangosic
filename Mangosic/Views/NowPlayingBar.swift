import SwiftUI

/// Mini player bar shown at bottom of screen
struct NowPlayingBar: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail - manually loaded for reliability (AsyncImage was unreliable)
            Group {
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                } else if isLoadingThumbnail {
                    thumbnailPlaceholder
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.gray)
                        )
                } else {
                    thumbnailPlaceholder
                }
            }
            .frame(width: 48, height: 48)
            .clipped()
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
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: viewModel.currentTrack?.thumbnailURL) { _, _ in
            loadThumbnail()
        }
    }
    
    /// Load thumbnail image manually using URLSession
    /// This approach is more reliable than AsyncImage which had inconsistent behavior
    private func loadThumbnail() {
        guard let url = viewModel.currentTrack?.thumbnailURL else {
            thumbnailImage = nil
            return
        }
        
        isLoadingThumbnail = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.thumbnailImage = image
                        self.isLoadingThumbnail = false
                    }
                } else {
                    await MainActor.run {
                        self.thumbnailImage = nil
                        self.isLoadingThumbnail = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.thumbnailImage = nil
                    self.isLoadingThumbnail = false
                }
            }
        }
    }
    
    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 48, height: 48)
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

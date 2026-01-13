import SwiftUI
import AVKit

/// Full player view with video/audio playback
struct PlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Video Player or Album Art
                if viewModel.playbackMode == .video {
                    VideoPlayerView(player: viewModel.playerService.getPlayer())
                        .aspectRatio(16/9, contentMode: .fit)
                } else {
                    albumArtView
                }
                
                // Track info and controls
                VStack(spacing: 24) {
                    // Track info
                    trackInfoView
                    
                    // Progress bar
                    progressView
                    
                    // Playback controls
                    controlsView
                    
                    // Mode switcher
                    modeSwitcher
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.stop()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Subviews
    
    private var albumArtView: some View {
        GeometryReader { geometry in
            ZStack {
                // Blurred background
                if let thumbnailURL = viewModel.currentTrack?.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 50)
                            .opacity(0.5)
                    } placeholder: {
                        Color.black
                    }
                }
                
                // Album art
                if let thumbnailURL = viewModel.currentTrack?.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: min(geometry.size.width - 60, 350))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 20)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 280, height: 280)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: 350)
    }
    
    private var trackInfoView: some View {
        VStack(spacing: 8) {
            Text(viewModel.currentTrack?.title ?? "Unknown")
                .font(.title2.bold())
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Text(viewModel.currentTrack?.author ?? "Unknown Artist")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 8) {
            // Slider
            Slider(
                value: Binding(
                    get: { viewModel.progress },
                    set: { viewModel.seek(to: $0) }
                ),
                in: 0...1
            )
            .tint(.red)
            
            // Time labels
            HStack {
                Text(formatTime(viewModel.currentTime))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formatTime(viewModel.duration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var controlsView: some View {
        HStack(spacing: 50) {
            // Rewind 10s
            Button {
                let newTime = max(0, viewModel.currentTime - 10)
                viewModel.playerService.seek(to: newTime)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            // Play/Pause
            Button {
                viewModel.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.black)
                            .offset(x: viewModel.isPlaying ? 0 : 2)
                    }
                }
            }
            .disabled(viewModel.isLoading)
            
            // Forward 10s
            Button {
                let newTime = min(viewModel.duration, viewModel.currentTime + 10)
                viewModel.playerService.seek(to: newTime)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
    }
    
    private var modeSwitcher: some View {
        HStack(spacing: 12) {
            ForEach(PlaybackMode.allCases, id: \.self) { mode in
                Button {
                    viewModel.switchMode(to: mode)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                        Text(mode.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        viewModel.playbackMode == mode
                            ? Color.red
                            : Color.white.opacity(0.1)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        PlayerView(viewModel: PlayerViewModel())
    }
}

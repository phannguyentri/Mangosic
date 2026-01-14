import SwiftUI
import AVKit

/// Full player view with video/audio playback
struct PlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var qualitySettings = QualitySettings.shared
    @State private var isUpgradingQuality = false
    
    var body: some View {
        ZStack {
            // Background
            MangosicBackground()
            
            VStack(spacing: 0) {
                // Top spacer to push content down and center vertically
                Spacer(minLength: 20)
                
                // Video Player or Album Art
                if viewModel.playbackMode == .video {
                    ZStack(alignment: .topTrailing) {
                        VideoPlayerView(player: viewModel.playerService.getPlayer())
                            .aspectRatio(16/9, contentMode: .fit)
                        
                        // HD Toggle Button
                        Button {
                            toggleResolution()
                        } label: {
                            HStack(spacing: 4) {
                                if isUpgradingQuality {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.white)
                                } else {
                                    Image(systemName: qualitySettings.isHighResolution ? "sparkles.tv.fill" : "play.rectangle")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                Text(qualitySettings.isHighResolution ? "HD" : (viewModel.currentTrack?.resolution ?? "SD"))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(qualitySettings.isHighResolution ? Theme.primaryEnd : Color.black.opacity(0.7))
                            .cornerRadius(6)
                        }
                        .padding(12)
                        .disabled(isUpgradingQuality)
                    }
                } else {
                    albumArtView
                }
                
                Spacer(minLength: 16)
                
                // Track info and controls - wrapped in a container with explicit bounds
                VStack(spacing: 20) {
                    // Track info
                    trackInfoView
                    
                    // Progress bar
                    progressView
                        .frame(maxWidth: .infinity)
                    
                    // Playback controls
                    controlsView
                    
                    // Mode switcher
                    modeSwitcher
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 0) // Ensure no extra padding on outer VStack
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.stop()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Subviews
    
    private var albumArtView: some View {
        GeometryReader { geometry in
            ZStack {
                // Blurred background - constrained to geometry
                if let thumbnailURL = viewModel.currentTrack?.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .blur(radius: 50)
                            .opacity(0.5)
                    } placeholder: {
                        Color.black
                    }
                }
                
                // Album art - centered
                if let thumbnailURL = viewModel.currentTrack?.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 280, maxHeight: 280)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.5), radius: 20)
                        case .failure(_):
                            albumArtPlaceholder
                        case .empty:
                            albumArtPlaceholder
                                .overlay {
                                    ProgressView()
                                        .tint(.white)
                                }
                        @unknown default:
                            albumArtPlaceholder
                        }
                    }
                } else {
                    albumArtPlaceholder
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: 320)
        .clipped()
    }
    
    private var albumArtPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 280, height: 280)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
            }
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
            .tint(Theme.primaryEnd)
            
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
        HStack(spacing: 0) {
            // Shuffle button (placeholder - can be implemented later)
            Button {
                // TODO: Implement shuffle
            } label: {
                Image(systemName: "shuffle")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            
            // Rewind 10s
            Button {
                let newTime = max(0, viewModel.currentTime - 10)
                viewModel.playerService.seek(to: newTime)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            // Play/Pause
            Button {
                viewModel.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.primaryGradient)
                        .frame(width: 70, height: 70)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .offset(x: viewModel.isPlaying ? 0 : 2)
                    }
                }
            }
            .disabled(viewModel.isLoading)
            .frame(maxWidth: .infinity)
            
            // Forward 10s
            Button {
                let newTime = min(viewModel.duration, viewModel.currentTime + 10)
                viewModel.playerService.seek(to: newTime)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            // Repeat button
            Button {
                viewModel.toggleRepeatMode()
            } label: {
                Image(systemName: viewModel.repeatMode.icon)
                    .font(.title2)
                    .foregroundColor(viewModel.repeatMode.isActive ? Theme.primaryEnd : .gray)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
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
                            ? Theme.primaryEnd
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
    
    // MARK: - Resolution Toggle
    
    /// Toggle between Normal and HD resolution modes
    private func toggleResolution() {
        guard !isUpgradingQuality else { return }
        guard let track = viewModel.currentTrack else { return }
        
        isUpgradingQuality = true
        qualitySettings.toggleResolution()
        
        Task {
            // Re-extract the video with new resolution mode
            let currentTime = viewModel.currentTime
            viewModel.urlInput = track.id
            await viewModel.reloadWithQuality(seekTime: currentTime)
            isUpgradingQuality = false
        }
    }
}

#Preview {
    NavigationStack {
        PlayerView(viewModel: PlayerViewModel())
    }
}

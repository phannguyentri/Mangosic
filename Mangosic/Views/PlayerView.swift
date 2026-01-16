import SwiftUI
import AVKit

/// Full player view with video/audio playback
struct PlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var qualitySettings = QualitySettings.shared
    @ObservedObject private var sleepTimerService = SleepTimerService.shared
    @ObservedObject private var queueService = QueueService.shared
    @State private var isUpgradingQuality = false
    @State private var showingSleepTimer = false
    @State private var showingAddToPlaylist = false
    @State private var showingQueue = false
    
    // Skip indicator states
    @State private var showSkipBackIndicator = false
    @State private var showSkipForwardIndicator = false
    
    var body: some View {
        ZStack {
            // Background
            MangosicBackground()
            
            VStack(spacing: 0) {
                // Top spacer to push content down and center vertically
                Spacer(minLength: 20)
                
                // Video Player or Album Art with Double-tap to skip
                if viewModel.playbackMode == .video {
                    ZStack {
                        VideoPlayerView(player: viewModel.playerService.getPlayer())
                            .aspectRatio(16/9, contentMode: .fit)
                        
                        // Double-tap zones overlay
                        doubleTapZonesOverlay
                        
                        // HD Toggle Button
                        VStack {
                            HStack {
                                Spacer()
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
                            Spacer()
                        }
                    }
                    .aspectRatio(16/9, contentMode: .fit)
                } else {
                    ZStack {
                        albumArtView
                        
                        // Double-tap zones overlay for audio mode
                        doubleTapZonesOverlay
                    }
                    .frame(height: 320)
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
                HStack(spacing: 8) {
                    // Add to Playlist button
                    Button {
                        showingAddToPlaylist = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.primaryGradient)
                    }
                    
                    // Queue button
                    Button {
                        showingQueue = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    // Close button
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
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showingSleepTimer) {
            SleepTimerSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingQueue) {
            QueueView(queueService: QueueService.shared)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingAddToPlaylist) {
            if let track = viewModel.currentTrack {
                AddToPlaylistSheet(
                    track: track,
                    playlistService: PlaylistService.shared
                )
            }
        }
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
            // Sleep Timer button
            Button {
                showingSleepTimer = true
            } label: {
                ZStack {
                    Image(systemName: "moon.fill")
                        .font(.title2)
                        .foregroundColor(sleepTimerService.isTimerActive ? Theme.primaryEnd : .gray)
                    
                    if sleepTimerService.isTimerActive {
                        // ZZZ indicator
                        Text("z")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Theme.primaryStart)
                            .offset(x: 10, y: -8)
                        
                        Text("z")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(Theme.primaryStart)
                            .offset(x: 14, y: -12)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Previous Track
            Button {
                playPreviousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundColor(hasPreviousTrack ? .white : .gray.opacity(0.4))
            }
            .disabled(!hasPreviousTrack)
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
            
            // Next Track
            Button {
                playNextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundColor(hasNextTrack ? .white : .gray.opacity(0.4))
            }
            .disabled(!hasNextTrack)
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
    
    // MARK: - Queue Navigation
    
    private var hasPreviousTrack: Bool {
        queueService.currentIndex > 0
    }
    
    private var hasNextTrack: Bool {
        queueService.currentIndex < queueService.queue.count - 1
    }
    
    private func playPreviousTrack() {
        guard hasPreviousTrack else { return }
        queueService.previous()
        if let item = queueService.currentItem {
            viewModel.urlInput = item.videoId
            Task {
                await viewModel.loadAndPlay()
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func playNextTrack() {
        guard hasNextTrack else { return }
        queueService.next()
        if let item = queueService.currentItem {
            viewModel.urlInput = item.videoId
            Task {
                await viewModel.loadAndPlay()
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
    
    // MARK: - Double-tap Skip Zones
    
    private var doubleTapZonesOverlay: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left zone - skip backward
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        skipBackward()
                    }
                    .overlay {
                        // Skip indicator
                        if showSkipBackIndicator {
                            SkipIndicatorView(isForward: false)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                
                // Right zone - skip forward
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        skipForward()
                    }
                    .overlay {
                        // Skip indicator
                        if showSkipForwardIndicator {
                            SkipIndicatorView(isForward: true)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
            }
        }
    }
    
    private func skipBackward() {
        let newTime = max(0, viewModel.currentTime - 10)
        viewModel.playerService.seek(to: newTime)
        
        // Show indicator
        withAnimation(.easeOut(duration: 0.2)) {
            showSkipBackIndicator = true
        }
        
        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showSkipBackIndicator = false
            }
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func skipForward() {
        let newTime = min(viewModel.duration, viewModel.currentTime + 10)
        viewModel.playerService.seek(to: newTime)
        
        // Show indicator
        withAnimation(.easeOut(duration: 0.2)) {
            showSkipForwardIndicator = true
        }
        
        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showSkipForwardIndicator = false
            }
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Skip Indicator View

struct SkipIndicatorView: View {
    let isForward: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if !isForward {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 24, weight: .bold))
            }
            
            Text("10s")
                .font(.system(size: 14, weight: .bold))
            
            if isForward {
                Image(systemName: "goforward.10")
                    .font(.system(size: 24, weight: .bold))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
    }
}

#Preview {
    NavigationStack {
        PlayerView(viewModel: PlayerViewModel())
    }
}

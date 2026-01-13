import SwiftUI

/// Main view with URL input and playback controls
struct ContentView: View {
    @StateObject private var viewModel = PlayerViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Logo and title
                    headerView
                    
                    // URL Input
                    urlInputView
                    
                    // Mode selector
                    modeSelector
                    
                    // Play button
                    playButton
                    
                    // Sample videos
                    sampleVideosView
                    
                    Spacer()
                    
                    // Now Playing Bar (shows when track is loaded)
                    if viewModel.currentTrack != nil {
                        NowPlayingBar(viewModel: viewModel)
                    }
                }
                .padding()
            }
            .navigationDestination(isPresented: $viewModel.showingPlayer) {
                PlayerView(viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("YT Music Player")
                .font(.title.bold())
                .foregroundColor(.white)
            
            Text("Play YouTube audio & video")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.top, 20)
    }
    
    private var urlInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YouTube URL or Video ID")
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.gray)
                
                TextField("Paste URL or video ID", text: $viewModel.urlInput)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                if !viewModel.urlInput.isEmpty {
                    Button {
                        viewModel.urlInput = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var modeSelector: some View {
        HStack(spacing: 12) {
            ForEach(PlaybackMode.allCases, id: \.self) { mode in
                Button {
                    viewModel.selectedMode = mode
                } label: {
                    HStack {
                        Image(systemName: mode.icon)
                        Text(mode.rawValue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        viewModel.selectedMode == mode
                            ? Color.red
                            : Color.white.opacity(0.1)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
            }
        }
    }
    
    private var playButton: some View {
        Button {
            Task {
                await viewModel.loadAndPlay()
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "play.fill")
                }
                Text(viewModel.isLoading ? "Loading..." : "Play")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.red, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(viewModel.urlInput.isEmpty || viewModel.isLoading)
        .opacity(viewModel.urlInput.isEmpty ? 0.6 : 1)
    }
    
    private var sampleVideosView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try these samples")
                .font(.caption)
                .foregroundColor(.gray)
            
            ForEach(viewModel.sampleURLs, id: \.1) { sample in
                Button {
                    Task {
                        await viewModel.playSample(sample.1)
                    }
                } label: {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundColor(.red)
                        Text(sample.0)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

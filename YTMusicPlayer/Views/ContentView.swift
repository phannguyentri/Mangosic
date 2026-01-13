import SwiftUI

/// Main view with URL input and playback controls
struct ContentView: View {
    @StateObject private var viewModel = PlayerViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MangosicBackground()
                
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
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .cornerRadius(20)
                .shadow(color: Theme.primaryEnd.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text("Mangosic")
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
                            ? Theme.primaryEnd
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
            HStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.1)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(viewModel.isLoading ? "Loading..." : "Play")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                viewModel.isLoading 
                    ? LinearGradient(colors: [Theme.primaryStart.opacity(0.7), Theme.primaryEnd.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : Theme.primaryGradient
            )
            .cornerRadius(12)
            .shadow(color: viewModel.isLoading ? .clear : Theme.primaryEnd.opacity(0.4), radius: 8, y: 4)
        }
        .disabled(viewModel.urlInput.isEmpty || viewModel.isLoading)
        .opacity(viewModel.urlInput.isEmpty ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }
    
    private var sampleVideosView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try these samples")
                .font(.caption)
                .foregroundColor(.gray)
            
            ForEach(viewModel.sampleURLs, id: \.1) { sample in
                let isLoadingThisSample = viewModel.isLoading && viewModel.urlInput == sample.1
                
                Button {
                    Task {
                        await viewModel.playSample(sample.1)
                    }
                } label: {
                    HStack {
                        if isLoadingThisSample {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryEnd))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "music.note")
                                .foregroundColor(Theme.primaryEnd)
                        }
                        Text(sample.0)
                            .foregroundColor(.white)
                        Spacer()
                        if isLoadingThisSample {
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(
                        isLoadingThisSample 
                            ? Theme.primaryEnd.opacity(0.1) 
                            : Color.white.opacity(0.05)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isLoadingThisSample ? Theme.primaryEnd.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading && !isLoadingThisSample ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.2), value: isLoadingThisSample)
            }
        }
    }
}

#Preview {
    ContentView()
}

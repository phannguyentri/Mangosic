import SwiftUI

/// Main view with URL input and playback controls
struct ContentView: View {
    @StateObject private var viewModel = PlayerViewModel()
    @State private var showingSearch = false
    @FocusState private var isUrlFieldFocused: Bool

    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background
                MangosicBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo and title
                        headerView
                        
                        // Search Button - Featured prominently
                        searchButton
                        
                        // Divider with "or"
                        orDivider
                        
                        // URL Input
                        urlInputView
                        
                        // Mode selector
                        modeSelector
                        
                        // Play button
                        playButton
                        

                    }
                    .padding()
                    .padding(.bottom, viewModel.currentTrack != nil ? 100 : 20)
                }
                .scrollIndicators(.hidden)
                
                // Now Playing Bar (shows when track is loaded)
                if viewModel.currentTrack != nil {
                    NowPlayingBar(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .navigationDestination(isPresented: $viewModel.showingPlayer) {
                PlayerView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showingSearch) {
                SearchView(playerViewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .onTapGesture {
                isUrlFieldFocused = false
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
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
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 20)
    }
    
    private var searchButton: some View {
        Button {
            showingSearch = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                
                Text("Search YouTube")
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.primaryStart, Theme.primaryEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
                    .shadow(color: Theme.primaryEnd.opacity(0.5), radius: 4, x: 0, y: 0)
            )
            .shadow(color: Theme.primaryEnd.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var orDivider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
            
            Text("or paste URL")
                .font(.caption)
                .foregroundColor(.gray)
            
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
        }
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
                    .focused($isUrlFieldFocused)
                
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
    

}

#Preview {
    ContentView()
}

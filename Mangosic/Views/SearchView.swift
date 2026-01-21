import SwiftUI

/// Beautiful search screen with autocomplete suggestions and animated results
struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFieldFocused: Bool
    
    @State private var showResults = false
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background - full screen
            MangosicBackground()
                .ignoresSafeArea()
            
            // Content layout
            VStack(spacing: 0) {
                // Search Header - always at top
                searchHeader
                
                // Content area
                ZStack(alignment: .top) {
                    // Recent Searches (when idle and no search text)
                    if viewModel.searchText.isEmpty && viewModel.searchState == .idle {
                        recentSearchesView
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Suggestions Overlay - ONLY show when no results are being displayed
                    if viewModel.showSuggestions && 
                       !viewModel.suggestions.isEmpty && 
                       viewModel.searchState == .idle {
                        suggestionsView
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .zIndex(10)
                    }
                    
                    // Search Results (takes priority over suggestions)
                    if !viewModel.searchState.results.isEmpty || viewModel.searchState.isLoading {
                        searchResultsView
                            .transition(.opacity)
                            .zIndex(20)
                    }
                    
                    // Error State
                    if case .error(let message) = viewModel.searchState {
                        errorView(message: message)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .zIndex(20)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }

        .navigationBarHidden(true)
        .onAppear {
            isSearchFieldFocused = true
            viewModel.onSearchFocused()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.showSuggestions)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.searchState)
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Back Button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Search Field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    
                    TextField("Search YouTube...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            viewModel.performSearch()
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(24)
                
                // Search Button
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.performSearch()
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Theme.primaryGradient)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.searchText.isEmpty)
            
            Divider()
                .background(Color.white.opacity(0.1))
        }
    }
    
    // MARK: - Recent Searches
    
    private var recentSearchesView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !viewModel.recentSearches.isEmpty {
                    HStack {
                        Text("Recent Searches")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                viewModel.clearRecentSearches()
                            }
                        } label: {
                            Text("Clear All")
                                .font(.caption)
                                .foregroundColor(Theme.primaryEnd)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    
                    ForEach(viewModel.recentSearches, id: \.self) { search in
                        RecentSearchRow(
                            text: search,
                            onTap: {
                                isSearchFieldFocused = false
                                viewModel.search(query: search)
                            },
                            onRemove: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    viewModel.removeRecentSearch(search)
                                }
                            }
                        )
                    }
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("Search for music")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Find videos, artists, and more")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                }
            }
        }
    }
    
    // MARK: - Suggestions
    
    private var suggestionsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(viewModel.suggestions.enumerated()), id: \.element) { index, suggestion in
                    SuggestionRow(
                        text: suggestion,
                        searchText: viewModel.searchText
                    ) {
                        isSearchFieldFocused = false
                        viewModel.selectSuggestion(suggestion)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8).delay(Double(index) * 0.03)),
                            removal: .opacity
                        )
                    )
                }
            }
            .padding(.top, 8)
        }
        // No background - let MangosicBackground gradient show through
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.searchState.isLoading {
                    // Loading shimmer
                    ForEach(0..<5, id: \.self) { index in
                        SearchResultShimmer()
                            .transition(.opacity)
                    }
                } else {
                    ForEach(Array(viewModel.searchState.results.enumerated()), id: \.element.id) { index, result in
                        let isLoadingThis = playerViewModel.isLoading && playerViewModel.urlInput == result.id
                        
                        SearchResultRow(result: result, isLoading: isLoadingThis) {
                            Task {
                                await viewModel.playResult(result, playerViewModel: playerViewModel)
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .scale(scale: 0.95))
                                    .combined(with: .offset(y: 20))
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05)),
                                removal: .opacity
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.primaryGradient)
            
            Text("Oops!")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                viewModel.performSearch()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.primaryGradient)
                .cornerRadius(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Subviews

/// Recent search row with remove action
struct RecentSearchRow: View {
    let text: String
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                
                Text(text)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.001)) // For tap area
    }
}

/// Suggestion row with highlighted matching text
struct SuggestionRow: View {
    let text: String
    let searchText: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                
                highlightedText
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "arrow.up.left")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.001))
    }
    
    private var highlightedText: some View {
        let lowercasedText = text.lowercased()
        let lowercasedSearch = searchText.lowercased()
        
        if let range = lowercasedText.range(of: lowercasedSearch) {
            let startIndex = lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound)
            let endIndex = lowercasedText.distance(from: lowercasedText.startIndex, to: range.upperBound)
            
            let before = String(text.prefix(startIndex))
            let match = String(text.dropFirst(startIndex).prefix(endIndex - startIndex))
            let after = String(text.dropFirst(endIndex))
            
            return Text(before).foregroundColor(.white) +
                   Text(match).foregroundColor(.gray) +
                   Text(after).foregroundColor(.white)
        } else {
            return Text(text).foregroundColor(.white)
        }
    }
}

/// Search result row with thumbnail
struct SearchResultRow: View {
    let result: SearchResult
    let isLoading: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var showAddToPlaylist = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Thumbnail
                AsyncImage(url: result.thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    case .failure:
                        thumbnailPlaceholder
                    case .empty:
                        thumbnailPlaceholder
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
                .frame(width: 110, height: 62)
                .cornerRadius(8)
                .clipped()
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(result.author)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let duration = result.duration {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(duration)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .foregroundColor(.gray.opacity(0.8))
                        }
                        
                        if let viewCount = result.viewCount {
                            HStack(spacing: 3) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 10))
                                Text(viewCount)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .foregroundColor(.gray.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    // Add to playlist button
                    Button {
                        showAddToPlaylist = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.primaryGradient)
                    }
                    .buttonStyle(.plain)
                    
                    // Play indicator
                    ZStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryEnd))
                        } else {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.primaryGradient)
                        }
                    }
                    .frame(width: 30, height: 30)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isPressed ? 0.1 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPressed || isLoading ? Theme.primaryEnd.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .disabled(isLoading)
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            Button {
                QueueService.shared.playNext(result)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            Button {
                QueueService.shared.addToQueue(result)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            
            Divider()
            
            Button {
                showAddToPlaylist = true
            } label: {
                Label("Add to Playlist", systemImage: "music.note.list")
            }
            
            Divider()
            
            if let url = URL(string: "https://youtube.com/watch?v=\(result.id)") {
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(track: result, playlistService: PlaylistService.shared)
        }
    }
    
    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(.gray.opacity(0.5))
            )
            .shimmer()
    }
}

/// Shimmer loading placeholder for search results
struct SearchResultShimmer: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .frame(width: 120, height: 68)
            
            VStack(alignment: .leading, spacing: 8) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 14)
                
                // Author placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 10)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            // Shimmer effect
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: isAnimating ? 200 : -200)
        )
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

/// Custom button style with scale animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        SearchView(playerViewModel: PlayerViewModel())
    }
}

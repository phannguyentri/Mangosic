import Foundation
import Combine
import SwiftUI

/// ViewModel for Search screen with autocomplete and search functionality
@MainActor
class SearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var searchText: String = ""
    @Published var searchState: SearchState = .idle
    @Published var suggestions: [String] = []
    @Published var showSuggestions: Bool = false
    @Published var recentSearches: [String] = []
    @Published var isSearchFocused: Bool = false
    
    // MARK: - Services
    private let searchService = YouTubeSearchService.shared
    private let youtubeService = YouTubeService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Debounce timers
    private var suggestionTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Constants
    private let maxRecentSearches = 10
    private let recentSearchesKey = "recentSearches"
    
    // MARK: - Initialization
    init() {
        loadRecentSearches()
        setupSearchTextObserver()
    }
    
    // MARK: - Setup
    private func setupSearchTextObserver() {
        // Debounced autocomplete suggestions
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.fetchSuggestions(for: query)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Autocomplete
    private func fetchSuggestions(for query: String) {
        suggestionTask?.cancel()
        
        guard !query.isEmpty, isSearchFocused else {
            suggestions = []
            showSuggestions = false
            return
        }
        
        suggestionTask = Task {
            do {
                let results = try await searchService.getAutocompleteSuggestions(query: query)
                
                guard !Task.isCancelled else { return }
                
                withAnimation(.easeOut(duration: 0.2)) {
                    suggestions = results
                    showSuggestions = !results.isEmpty
                }
            } catch {
                // Silently fail for autocomplete
                suggestions = []
                showSuggestions = false
            }
        }
    }
    
    // MARK: - Search
    
    /// Perform search with the current search text
    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        // Save to recent searches
        saveRecentSearch(query)
        
        // Hide suggestions
        withAnimation(.easeOut(duration: 0.2)) {
            showSuggestions = false
        }
        
        // Cancel any pending search
        searchTask?.cancel()
        
        searchTask = Task {
            await executeSearch(query: query)
        }
    }
    
    /// Execute search with a specific query
    func search(query: String) {
        searchText = query
        performSearch()
    }
    
    /// Select a suggestion
    func selectSuggestion(_ suggestion: String) {
        searchText = suggestion
        performSearch()
    }
    
    private func executeSearch(query: String) async {
        // Clear suggestions immediately when search starts
        showSuggestions = false
        suggestions = []
        
        searchState = .loading
        
        do {
            let results = try await searchService.search(query: query)
            
            guard !Task.isCancelled else { return }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if results.isEmpty {
                    searchState = .error("No results found for \"\(query)\"")
                } else {
                    searchState = .loaded(results)
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            
            withAnimation(.easeOut(duration: 0.2)) {
                searchState = .error(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Play Actions
    
    /// Play a search result
    func playResult(_ result: SearchResult, playerViewModel: PlayerViewModel) async {
        // Set URL input and trigger play
        playerViewModel.urlInput = result.id
        await playerViewModel.loadAndPlay()
    }
    
    // MARK: - Recent Searches
    
    private func loadRecentSearches() {
        if let saved = UserDefaults.standard.stringArray(forKey: recentSearchesKey) {
            recentSearches = saved
        }
    }
    
    private func saveRecentSearch(_ query: String) {
        // Remove if exists to avoid duplicates
        recentSearches.removeAll { $0.lowercased() == query.lowercased() }
        
        // Insert at beginning
        recentSearches.insert(query, at: 0)
        
        // Limit size
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
    
    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
    
    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
    }
    
    // MARK: - Focus Management
    
    func onSearchFocused() {
        isSearchFocused = true
        if !searchText.isEmpty {
            fetchSuggestions(for: searchText)
        }
    }
    
    func onSearchUnfocused() {
        isSearchFocused = false
        // Delay hiding suggestions to allow tap on suggestion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            if !(self?.isSearchFocused ?? false) {
                withAnimation(.easeOut(duration: 0.2)) {
                    self?.showSuggestions = false
                }
            }
        }
    }
    
    func clearSearch() {
        withAnimation(.easeOut(duration: 0.2)) {
            searchText = ""
            suggestions = []
            showSuggestions = false
            searchState = .idle
        }
    }
}

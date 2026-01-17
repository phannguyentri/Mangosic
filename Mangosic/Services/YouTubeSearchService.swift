import Foundation

/// Service for YouTube search using InnerTube API (no API key required)
/// 
/// ## Strategy
/// **Primary**: InnerTube API (same approach as yt-search-lib)
/// **Fallback**: If InnerTube fails consistently, consider adding b5i/YouTubeKit package
///              with module aliasing (e.g., `import YouTubeKitSearch` via wrapper package)
///
/// ## API Endpoints Used
/// - Search: `POST https://www.youtube.com/youtubei/v1/search`
/// - Autocomplete: `GET https://suggestqueries-clients6.youtube.com/complete/search`
///
@MainActor
class YouTubeSearchService: ObservableObject {
    
    static let shared = YouTubeSearchService()
    
    // MARK: - Configuration
    private let baseURL = "https://www.youtube.com/youtubei/v1"
    
    /// Public API key embedded in YouTube's client JS (not secret, changes periodically)
    /// If search fails, try updating this key from YouTube's web client source
    private var apiKeys = [
        "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8",  // Common key 1
        "AIzaSyB5BoZcW8y7_Gk",                       // Common key 2 (split in original)
        "AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30"   // Backup key
    ]
    
    private var currentKeyIndex = 0
    
    private let clientContext: [String: Any] = [
        "clientName": "WEB",
        "clientVersion": "2.20240101.00.00",
        "hl": "vi",  // Vietnamese
        "gl": "VN"   // Vietnam
    ]
    
    /// Retry configuration
    private let maxRetries = 3
    private var consecutiveFailures = 0
    
    private init() {}
    
    // MARK: - Search
    
    /// Search for videos on YouTube
    /// - Parameters:
    ///   - query: Search text
    ///   - limit: Maximum number of results (default: 20)
    /// - Returns: Array of search results
    func search(query: String, limit: Int = 20) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        var lastError: Error?
        
        // Retry with different API keys if needed
        for attempt in 0..<maxRetries {
            do {
                let results = try await performSearch(query: query, limit: limit)
                consecutiveFailures = 0 // Reset on success
                return results
            } catch {
                lastError = error
                print("⚠️ Search attempt \(attempt + 1) failed: \(error.localizedDescription)")
                
                // Try next API key
                rotateApiKey()
                
                // Small delay before retry
                if attempt < maxRetries - 1 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                }
            }
        }
        
        consecutiveFailures += 1
        
        // Log suggestion for fallback
        if consecutiveFailures >= 3 {
            print("❌ InnerTube API failing consistently. Consider implementing b5i/YouTubeKit fallback.")
        }
        
        throw lastError ?? YouTubeSearchError.searchFailed("Unknown error after retries")
    }
    
    private func performSearch(query: String, limit: Int) async throws -> [SearchResult] {
        let apiKey = apiKeys[currentKeyIndex]
        guard let url = URL(string: "\(baseURL)/search?key=\(apiKey)") else {
            throw YouTubeSearchError.searchFailed("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        let body: [String: Any] = [
            "context": [
                "client": clientContext
            ],
            "query": query
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeSearchError.searchFailed("Invalid response type")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw YouTubeSearchError.searchFailed("HTTP \(httpResponse.statusCode)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YouTubeSearchError.searchFailed("Invalid JSON response")
        }
        
        // Check for API errors
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw YouTubeSearchError.searchFailed(message)
        }
        
        return parseSearchResults(json, limit: limit)
    }
    
    private func rotateApiKey() {
        currentKeyIndex = (currentKeyIndex + 1) % apiKeys.count
        print("🔄 Rotating to API key index: \(currentKeyIndex)")
    }
    
    // MARK: - Autocomplete
    
    /// Get autocomplete suggestions for a search query
    /// - Parameter query: Partial search text
    /// - Returns: Array of suggestion strings
    func getAutocompleteSuggestions(query: String) async throws -> [String] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        // YouTube's autocomplete endpoint (very stable, rarely fails)
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://suggestqueries-clients6.youtube.com/complete/search?client=youtube&q=\(encodedQuery)&ds=yt&hl=vi"
        
        guard let url = URL(string: urlString) else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let responseString = String(data: data, encoding: .utf8) else {
                return []
            }
            
            return parseAutocompleteSuggestions(responseString)
        } catch {
            // Silently fail for autocomplete - it's not critical
            print("⚠️ Autocomplete failed: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Parsing
    
    private func parseSearchResults(_ json: [String: Any], limit: Int) -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Navigate through the nested structure
        guard let contents = json["contents"] as? [String: Any],
              let twoColumnResults = contents["twoColumnSearchResultsRenderer"] as? [String: Any],
              let primaryContents = twoColumnResults["primaryContents"] as? [String: Any],
              let sectionListRenderer = primaryContents["sectionListRenderer"] as? [String: Any],
              let sections = sectionListRenderer["contents"] as? [[String: Any]] else {
            print("⚠️ Unexpected API response structure")
            return results
        }
        
        for section in sections {
            guard let itemSectionRenderer = section["itemSectionRenderer"] as? [String: Any],
                  let items = itemSectionRenderer["contents"] as? [[String: Any]] else {
                continue
            }
            
            for item in items {
                if results.count >= limit { break }
                
                if let videoRenderer = item["videoRenderer"] as? [String: Any] {
                    if let result = parseVideoRenderer(videoRenderer) {
                        results.append(result)
                    }
                }
            }
        }
        
        return results
    }
    
    private func parseVideoRenderer(_ renderer: [String: Any]) -> SearchResult? {
        guard let videoId = renderer["videoId"] as? String else {
            return nil
        }
        
        let title = extractText(from: renderer["title"])
        let author = extractText(from: renderer["ownerText"])
        let duration = extractText(from: renderer["lengthText"])
        let viewCount = extractText(from: renderer["viewCountText"])
        let publishedTime = extractText(from: renderer["publishedTimeText"])
        
        // Extract thumbnail - prefer higher quality
        var thumbnailURL: URL?
        if let thumbnail = renderer["thumbnail"] as? [String: Any],
           let thumbnails = thumbnail["thumbnails"] as? [[String: Any]],
           let lastThumb = thumbnails.last,
           let urlString = lastThumb["url"] as? String {
            // Clean up URL (remove size parameters to get higher quality)
            let cleanURL = urlString.components(separatedBy: "?").first ?? urlString
            thumbnailURL = URL(string: cleanURL)
        }
        
        // Fallback to standard thumbnail
        if thumbnailURL == nil {
            thumbnailURL = URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")
        }
        
        return SearchResult(
            id: videoId,
            title: title ?? "Unknown Title",
            author: author ?? "Unknown Artist",
            thumbnailURL: thumbnailURL,
            duration: duration,
            viewCount: formatViewCountString(viewCount),
            publishedTime: publishedTime
        )
    }
    
    private func formatViewCountString(_ text: String?) -> String? {
        guard let text = text else { return nil }
        
        // Extract digits only
        let digits = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let number = Double(digits) else { return text }
        
        if number >= 1_000_000_000 {
            let formatted = String(format: "%.1fB", number / 1_000_000_000)
            return formatted.replacingOccurrences(of: ".0B", with: "B")
        } else if number >= 1_000_000 {
            let formatted = String(format: "%.1fM", number / 1_000_000)
            return formatted.replacingOccurrences(of: ".0M", with: "M")
        } else if number >= 1_000 {
            let formatted = String(format: "%.1fK", number / 1_000)
            return formatted.replacingOccurrences(of: ".0K", with: "K")
        } else {
            return String(Int(number))
        }
    }
    
    private func extractText(from data: Any?) -> String? {
        guard let data = data else { return nil }
        
        if let dict = data as? [String: Any] {
            if let simpleText = dict["simpleText"] as? String {
                return simpleText
            }
            if let runs = dict["runs"] as? [[String: Any]] {
                return runs.compactMap { $0["text"] as? String }.joined()
            }
        }
        
        if let string = data as? String {
            return string
        }
        
        return nil
    }
    
    private func parseAutocompleteSuggestions(_ response: String) -> [String] {
        // Response format: window.google.ac.h([query, [[suggestion, 0, [512]], ...], {...}])
        
        guard let startIndex = response.firstIndex(of: "["),
              let endIndex = response.lastIndex(of: "]") else {
            return []
        }
        
        let jsonString = String(response[startIndex...endIndex])
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              json.count >= 2,
              let suggestionsArray = json[1] as? [[Any]] else {
            return []
        }
        
        return suggestionsArray.compactMap { item -> String? in
            guard item.count > 0 else { return nil }
            return item[0] as? String
        }
    }
    
    // MARK: - Fallback Strategy Info
    
    /// Check if fallback to b5i/YouTubeKit is recommended
    var shouldConsiderFallback: Bool {
        consecutiveFailures >= 5
    }
    
    /// Reset failure counter (call after successful operations)
    func resetFailureCounter() {
        consecutiveFailures = 0
    }
}

/// YouTube search errors
enum YouTubeSearchError: LocalizedError {
    case searchFailed(String)
    case noResults
    case fallbackRequired
    
    var errorDescription: String? {
        switch self {
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .noResults:
            return "No results found"
        case .fallbackRequired:
            return "Primary search unavailable. Please try again later."
        }
    }
}

// MARK: - Future Fallback Implementation Notes
/*
 To add b5i/YouTubeKit as fallback:
 
 1. Create a local Swift Package wrapper:
    ```
    // Package.swift in a new folder "YouTubeKitSearchWrapper"
    let package = Package(
        name: "YouTubeKitSearchWrapper",
        products: [
            .library(name: "YouTubeKitSearch", targets: ["YouTubeKitSearch"])
        ],
        dependencies: [
            .package(url: "https://github.com/b5i/YouTubeKit.git", from: "1.0.0")
        ],
        targets: [
            .target(
                name: "YouTubeKitSearch",
                dependencies: [
                    .product(name: "YouTubeKit", package: "YouTubeKit")
                ]
            )
        ]
    )
    ```
 
 2. Add to project and import with different name:
    ```swift
    import YouTubeKitSearch  // This accesses b5i/YouTubeKit
    // vs current
    import YouTubeKit        // This accesses alexeichhorn/YouTubeKit
    ```
 
 3. Add fallback method in this service:
    ```swift
    private func searchWithB5iYouTubeKit(query: String) async throws -> [SearchResult] {
        let model = YouTubeModel()
        let response = try await SearchResponse.sendThrowingRequest(
            youtubeModel: model,
            data: [.query: query]
        )
        // Parse and return...
    }
    ```
*/

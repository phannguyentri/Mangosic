import Foundation
import YouTubeKit

/// Service for extracting YouTube video/audio streams using YouTubeKit
@MainActor
class YouTubeService: ObservableObject {
    
    static let shared = YouTubeService()
    
    private init() {}
    
    /// Extract track information from a YouTube URL or video ID
    /// - Parameter urlOrId: YouTube URL or 11-character video ID
    /// - Returns: Track with stream URLs
    func extractTrack(from urlOrId: String) async throws -> Track {
        let videoID: String
        
        // Check if it's a video ID (11 characters) or URL
        if urlOrId.count == 11 && !urlOrId.contains("/") && !urlOrId.contains(".") {
            videoID = urlOrId
        } else if let extractedID = YouTubeService.extractVideoID(from: urlOrId) {
            videoID = extractedID
        } else {
            throw YouTubeError.invalidURL
        }
        
        let video = YouTube(videoID: videoID)
        
        // Fetch streams, metadata, and oEmbed concurrently for better performance
        async let streamsTask = video.streams
        async let metadataTask = video.metadata
        async let oEmbedTask = fetchOEmbedInfo(videoID: videoID)
        
        let streams = try await streamsTask
        
        guard !streams.isEmpty else {
            throw YouTubeError.noStreamsFound
        }
        
        // Default values
        var title = "YouTube Video"
        var author = "YouTube"
        var thumbnailURL: URL? = URL(string: "https://img.youtube.com/vi/\(videoID)/maxresdefault.jpg")
        
        // Try to get title and thumbnail from YouTubeKit metadata
        do {
            if let metadata = try await metadataTask {
                title = metadata.title
                
                // Use thumbnail from metadata if available
                if let metaThumbnail = metadata.thumbnail {
                    thumbnailURL = metaThumbnail.url
                }
            }
        } catch {
            print("⚠️ Failed to fetch YouTubeKit metadata: \(error.localizedDescription)")
        }
        
        // Try to get author from oEmbed API
        if let oEmbedInfo = await oEmbedTask {
            author = oEmbedInfo.authorName
            // oEmbed also provides title as fallback
            if title == "YouTube Video" {
                title = oEmbedInfo.title
            }
        }
        
        // Get best audio stream (audio only, prefer m4a)
        let bestAudioStream = streams
            .filterAudioOnly()
            .filter { $0.fileExtension == .m4a }
            .highestAudioBitrateStream()
            ?? streams.filterAudioOnly().highestAudioBitrateStream()
        
        // Get best video stream (with audio, natively playable, prefer mp4)
        let bestVideoStream = streams
            .filter { $0.includesVideoAndAudioTrack && $0.isNativelyPlayable }
            .highestResolutionStream()
            ?? streams
                .filter { $0.includesVideoAndAudioTrack }
                .highestResolutionStream()
            ?? streams
                .filter { $0.includesVideoTrack }
                .highestResolutionStream()
        
        return Track(
            id: videoID,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: nil, // Duration not available from YouTubeKit metadata
            audioStreamURL: bestAudioStream?.url,
            videoStreamURL: bestVideoStream?.url,
            resolution: nil
        )
    }
    
    // MARK: - oEmbed API
    
    /// oEmbed response structure
    private struct OEmbedInfo {
        let title: String
        let authorName: String
    }
    
    /// Fetch video info from YouTube oEmbed API (free, no API key required)
    private func fetchOEmbedInfo(videoID: String) async -> OEmbedInfo? {
        let urlString = "https://www.youtube.com/oembed?url=https://youtube.com/watch?v=\(videoID)&format=json"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let title = json["title"] as? String ?? "YouTube Video"
                let authorName = json["author_name"] as? String ?? "YouTube"
                return OEmbedInfo(title: title, authorName: authorName)
            }
        } catch {
            print("⚠️ Failed to fetch oEmbed info: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Extract video ID from various YouTube URL formats
    static func extractVideoID(from urlString: String) -> String? {
        // Already a video ID
        if urlString.count == 11 && !urlString.contains("/") && !urlString.contains(".") {
            return urlString
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        // youtube.com/watch?v=VIDEO_ID
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return videoID
        }
        
        // youtu.be/VIDEO_ID
        if url.host == "youtu.be" || url.host == "www.youtu.be" {
            let path = url.path
            if path.count > 1 {
                return String(path.dropFirst())
            }
        }
        
        // youtube.com/embed/VIDEO_ID or youtube.com/shorts/VIDEO_ID
        let pathComponents = url.pathComponents
        if pathComponents.contains("embed") || pathComponents.contains("shorts") {
            if let lastComponent = pathComponents.last, lastComponent.count == 11 {
                return lastComponent
            }
        }
        
        // Try last path component
        if let lastComponent = pathComponents.last, lastComponent.count == 11 {
            return lastComponent
        }
        
        return nil
    }
}

/// YouTube service errors
enum YouTubeError: LocalizedError {
    case invalidURL
    case noStreamsFound
    case extractionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid YouTube URL or video ID"
        case .noStreamsFound:
            return "No playable streams found"
        case .extractionFailed(let message):
            return "Failed to extract video: \(message)"
        }
    }
}

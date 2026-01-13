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
        
        // Fetch streams
        let streams = try await video.streams
        
        guard !streams.isEmpty else {
            throw YouTubeError.noStreamsFound
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
        
        // Build thumbnail URL from video ID
        let thumbnailURL = URL(string: "https://img.youtube.com/vi/\(videoID)/maxresdefault.jpg")
        
        // We don't have direct access to title/author from streams
        // Use video ID as identifier, the actual title could be fetched separately
        let title = "YouTube Video"
        let author = "YouTube"
        
        return Track(
            id: videoID,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: nil,
            audioStreamURL: bestAudioStream?.url,
            videoStreamURL: bestVideoStream?.url,
            resolution: nil
        )
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

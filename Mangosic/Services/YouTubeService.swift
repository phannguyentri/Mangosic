import Foundation
import YouTubeKit

/// Type alias to resolve ambiguity between YouTubeKit.Stream and Foundation.NSStream
typealias YTStream = YouTubeKit.Stream

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
        
        let streams: [YTStream] = try await streamsTask
        
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
        
        // Get quality settings
        let qualitySettings = QualitySettings.shared
        
        // Get best audio stream based on quality preference
        let bestAudioStream = selectAudioStream(from: streams, preferredQuality: qualitySettings.audioQuality)
        
        // Get best video stream based on quality preference
        let bestVideoStream = selectVideoStream(from: streams, preferredQuality: qualitySettings.videoQuality)
        
        // Convert resolution to string format (e.g., "720p")
        let resolutionString: String? = bestVideoStream?.videoResolution.map { "\($0)p" }
        
        return Track(
            id: videoID,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: nil, // Duration not available from YouTubeKit metadata
            audioStreamURL: bestAudioStream?.url,
            videoStreamURL: bestVideoStream?.url,
            resolution: resolutionString
        )
    }
    
    // MARK: - Quality Selection
    
    /// Select audio stream based on preferred quality
    private func selectAudioStream(from streams: [YTStream], preferredQuality: AudioQuality) -> YTStream? {
        let audioStreams = streams.filterAudioOnly()
        
        // Prefer m4a format
        let m4aStreams = audioStreams.filter { $0.fileExtension == .m4a }
        let targetStreams = m4aStreams.isEmpty ? audioStreams : m4aStreams
        
        switch preferredQuality {
        case .auto:
            return targetStreams.highestAudioBitrateStream()
        case .low:
            return targetStreams.lowestAudioBitrateStream()
        case .medium:
            // Find stream closest to 128kbps
            return findClosestAudioBitrate(in: targetStreams, targetBitrate: 128_000)
                ?? targetStreams.lowestAudioBitrateStream()
        case .high:
            return targetStreams.highestAudioBitrateStream()
        }
    }
    
    /// Select video stream based on preferred quality
    private func selectVideoStream(from streams: [YTStream], preferredQuality: VideoQuality) -> YTStream? {
        // Filter for playable combined streams
        let combinedStreams = streams
            .filter { $0.includesVideoAndAudioTrack && $0.isNativelyPlayable }
        
        // Fallback to any video+audio streams if no natively playable found
        let targetStreams = combinedStreams.isEmpty
            ? streams.filter { $0.includesVideoAndAudioTrack }
            : combinedStreams
        
        switch preferredQuality {
        case .auto:
            return targetStreams.highestResolutionStream()
        case .p360:
            return findClosestResolution(in: targetStreams, targetHeight: 360)
        case .p480:
            return findClosestResolution(in: targetStreams, targetHeight: 480)
        case .p720:
            return findClosestResolution(in: targetStreams, targetHeight: 720)
        case .p1080:
            return findClosestResolution(in: targetStreams, targetHeight: 1080)
        case .p1440:
            return findClosestResolution(in: targetStreams, targetHeight: 1440)
        case .p4K:
            return findClosestResolution(in: targetStreams, targetHeight: 2160)
        }
    }
    
    /// Find stream closest to target resolution (preferring lower if exact not found)
    private func findClosestResolution(in streams: [YTStream], targetHeight: Int) -> YTStream? {
        // First try to find exact match
        if let exact = streams.first(where: { $0.videoResolution == targetHeight }) {
            return exact
        }
        
        // Sort by resolution
        let sorted = streams.sorted(by: { ($0.videoResolution ?? 0) < ($1.videoResolution ?? 0) })
        
        // Find closest resolution <= target
        if let lower = sorted.last(where: { ($0.videoResolution ?? 0) <= targetHeight }) {
            return lower
        }
        
        // If no lower resolution, return lowest available
        return sorted.first
    }
    
    /// Find audio stream closest to target bitrate
    private func findClosestAudioBitrate(in streams: [YTStream], targetBitrate: Int) -> YTStream? {
        let sorted = streams.sorted(by: { ($0.averageBitrate ?? 0) < ($1.averageBitrate ?? 0) })
        
        // Find closest bitrate <= target
        if let lower = sorted.last(where: { ($0.averageBitrate ?? 0) <= targetBitrate }) {
            return lower
        }
        
        return sorted.first
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

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
        // Use hqdefault.jpg as it's always available. maxresdefault.jpg may not exist for all videos.
        var thumbnailURL: URL? = URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")

        
        
        // Try to get title and thumbnail from YouTubeKit metadata
        do {
            if let metadata = try await metadataTask {
                title = metadata.title
                
                // Use thumbnail from metadata if available
                if let metaThumbnail = metadata.thumbnail {
                    thumbnailURL = metaThumbnail.url
                }
                
                // Try to get duration (lengthSeconds is common in YouTube metadata)
                // Note: YouTubeKit metadata might not expose lengthSeconds directly publicly
                // TODO: Find correct property for duration
                /*
                 if let lengthSeconds = metadata.lengthSeconds {
                     videoDuration = TimeInterval(lengthSeconds)
                 }
                 */
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
        
        // Get resolution mode
        let isHighResolution = QualitySettings.shared.isHighResolution
        
        // Get best audio stream (always highest quality m4a)
        let bestAudioStream = selectBestAudioStream(from: streams)
        
        // Get video streams based on mode
        let (videoStream, videoOnlyStream) = selectVideoStream(from: streams, highResMode: isHighResolution)
        
        // Determine resolution string
        let resolution = (videoOnlyStream ?? videoStream)?.videoResolution
        let resolutionString: String? = resolution.map { "\($0)p" }
        
        print("🎯 Mode: \(isHighResolution ? "HIGH" : "NORMAL") | Resolution: \(resolutionString ?? "nil") | Adaptive: \(videoOnlyStream != nil)")
        
        return Track(
            id: videoID,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: nil,
            audioStreamURL: bestAudioStream?.url,
            videoStreamURL: videoStream?.url,
            videoOnlyStreamURL: videoOnlyStream?.url,
            separateAudioURL: videoOnlyStream != nil ? bestAudioStream?.url : nil,
            resolution: resolutionString
        )
    }
    
    // MARK: - Stream Selection (Simplified)
    
    /// Select best audio stream (highest bitrate m4a)
    private func selectBestAudioStream(from streams: [YTStream]) -> YTStream? {
        let audioStreams = streams.filterAudioOnly()
        let m4aStreams = audioStreams.filter { $0.fileExtension == .m4a }
        return m4aStreams.highestAudioBitrateStream() ?? audioStreams.highestAudioBitrateStream()
    }
    
    /// Select video stream based on resolution mode
    /// - Returns: (combinedStream, videoOnlyStream) - videoOnlyStream is nil for Normal mode
    private func selectVideoStream(from streams: [YTStream], highResMode: Bool) -> (combined: YTStream?, videoOnly: YTStream?) {
        // Get combined streams (video + audio)
        let combinedStreams = streams.filter { $0.includesVideoAndAudioTrack && $0.isNativelyPlayable }
        let bestCombined = combinedStreams.highestResolutionStream()
        
        if !highResMode {
            // Normal mode: just use combined stream (fast)
            return (bestCombined, nil)
        }
        
        // High mode: try to find higher resolution video-only stream
        let videoOnlyStreams = streams.filter { 
            $0.includesVideoTrack && !$0.includesAudioTrack && $0.isNativelyPlayable 
        }
        
        // Try resolutions in order of preference: 1080 > 720 > 1440 > 2160
        let targetResolutions = [1080, 720, 1440, 2160]
        
        for targetRes in targetResolutions {
            if let stream = videoOnlyStreams.first(where: { $0.videoResolution == targetRes }) {
                // Only use if it's higher than combined
                if stream.videoResolution ?? 0 > bestCombined?.videoResolution ?? 0 {
                    print("� Found high-res stream: \(stream.videoResolution ?? 0)p (adaptive)")
                    return (bestCombined, stream)
                }
            }
        }
        
        // Fallback: get highest video-only if better than combined
        if let highestVideoOnly = videoOnlyStreams.highestResolutionStream(),
           (highestVideoOnly.videoResolution ?? 0) > (bestCombined?.videoResolution ?? 0) {
            print("📹 Using highest adaptive stream: \(highestVideoOnly.videoResolution ?? 0)p")
            return (bestCombined, highestVideoOnly)
        }
        
        // No better stream found, use combined
        return (bestCombined, nil)
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

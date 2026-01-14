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
        
        // Get video streams - both combined and adaptive
        let (combinedVideoStream, adaptiveVideoStream) = selectVideoStreams(from: streams, preferredQuality: qualitySettings.videoQuality)
        
        // Determine which stream to use
        let useAdaptive = adaptiveVideoStream != nil && 
            (adaptiveVideoStream?.videoResolution ?? 0) > (combinedVideoStream?.videoResolution ?? 0)
        
        // Convert resolution to string format (e.g., "720p")
        let selectedResolution = useAdaptive ? adaptiveVideoStream?.videoResolution : combinedVideoStream?.videoResolution
        let resolutionString: String? = selectedResolution.flatMap { $0 }.map { "\($0)p" }
        
        print("🎯 Stream selection: useAdaptive=\(useAdaptive), resolution=\(resolutionString ?? "nil")")
        
        return Track(
            id: videoID,
            title: title,
            author: author,
            thumbnailURL: thumbnailURL,
            duration: nil, // Duration not available from YouTubeKit metadata
            audioStreamURL: bestAudioStream?.url,
            videoStreamURL: combinedVideoStream?.url,
            videoOnlyStreamURL: useAdaptive ? adaptiveVideoStream?.url : nil,
            separateAudioURL: useAdaptive ? bestAudioStream?.url : nil,
            resolution: resolutionString
        )
    }
    
    // MARK: - Quality Selection
    
    /// Select audio stream based on preferred quality
    private func selectAudioStream(from streams: [YTStream], preferredQuality: AudioQuality) -> YTStream? {
        let audioStreams = streams.filterAudioOnly()
        
        // Debug: Log available audio streams
        print("🎵 Available audio streams: \(audioStreams.count)")
        for stream in audioStreams {
            print("   - \(stream.fileExtension.rawValue) @ \(stream.averageBitrate ?? 0) bps")
        }
        
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
    
    /// Select video streams - returns both combined (progressive) and adaptive (video-only) streams
    /// - Returns: Tuple of (combinedStream, adaptiveStream) - adaptive is for 1080p+
    private func selectVideoStreams(from streams: [YTStream], preferredQuality: VideoQuality) -> (combined: YTStream?, adaptive: YTStream?) {
        // Separate combined (progressive) and video-only (adaptive/DASH) streams
        let allVideoStreams = streams.filter { $0.includesVideoTrack }
        let combinedStreams = allVideoStreams.filter { $0.includesVideoAndAudioTrack && $0.isNativelyPlayable }
        let videoOnlyStreams = allVideoStreams.filter { !$0.includesAudioTrack && $0.isNativelyPlayable }
        
        print("📹 Combined streams: \(combinedStreams.count) | Adaptive streams: \(videoOnlyStreams.count)")
        
        // Get target resolution
        let targetHeight: Int?
        switch preferredQuality {
        case .auto: targetHeight = nil  // Will pick highest
        case .p360: targetHeight = 360
        case .p480: targetHeight = 480
        case .p720: targetHeight = 720
        case .p1080: targetHeight = 1080
        case .p1440: targetHeight = 1440
        case .p4K: targetHeight = 2160
        }
        
        // Select best combined stream (fallback, max ~720p usually)
        let combinedStream: YTStream?
        if let target = targetHeight {
            combinedStream = findClosestResolution(in: combinedStreams, targetHeight: target)
        } else {
            combinedStream = combinedStreams.highestResolutionStream()
        }
        
        // Select adaptive stream if requesting higher resolution (>= 1080p)
        var adaptiveStream: YTStream? = nil
        if let target = targetHeight, target >= 1080 {
            // Try to find exact or closest adaptive stream
            adaptiveStream = findClosestResolution(in: videoOnlyStreams, targetHeight: target)
                ?? videoOnlyStreams.highestResolutionStream()
        } else if targetHeight == nil {
            // Auto mode: pick highest adaptive if > combined
            let highestAdaptive = videoOnlyStreams.highestResolutionStream()
            let combinedRes = combinedStream?.videoResolution ?? 0
            let adaptiveRes = highestAdaptive?.videoResolution ?? 0
            if adaptiveRes > combinedRes {
                adaptiveStream = highestAdaptive
            }
        }
        
        print("📊 Combined: \(combinedStream?.videoResolution ?? 0)p | Adaptive: \(adaptiveStream?.videoResolution ?? 0)p | Requested: \(preferredQuality.rawValue)")
        
        return (combinedStream, adaptiveStream)
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

import Foundation

/// Represents a YouTube track with audio and video stream information
struct Track: Identifiable {
    let id: String  // YouTube video ID
    let title: String
    let author: String
    let thumbnailURL: URL?
    let duration: TimeInterval?
    
    // Stream URLs - Combined (progressive) streams
    let audioStreamURL: URL?
    let videoStreamURL: URL?
    
    // Adaptive streaming (for 1080p+)
    // Video-only stream URL for high resolution (requires mixing with audio)
    let videoOnlyStreamURL: URL?
    // Separate audio stream URL to mix with video-only
    let separateAudioURL: URL?
    // Whether this track uses adaptive (separate video+audio) streaming
    var isAdaptiveStream: Bool {
        videoOnlyStreamURL != nil && separateAudioURL != nil
    }
    
    // Video info
    let resolution: String?
    
    var formattedDuration: String {
        guard let duration = duration else { return "--:--" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var hasAudio: Bool { audioStreamURL != nil || separateAudioURL != nil }
    var hasVideo: Bool { videoStreamURL != nil || videoOnlyStreamURL != nil }
    
    /// Get the best video URL (prefers high-res adaptive stream)
    var bestVideoURL: URL? {
        videoOnlyStreamURL ?? videoStreamURL
    }
    
    /// Get the best audio URL
    var bestAudioURL: URL? {
        separateAudioURL ?? audioStreamURL
    }
}

/// Playback mode
enum PlaybackMode: String, CaseIterable {
    case video = "Video"
    case audio = "Audio Only"
    
    var icon: String {
        switch self {
        case .audio: return "music.note"
        case .video: return "play.rectangle.fill"
        }
    }
}

/// Player state
enum PlayerState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }
}

/// Repeat mode for playback
enum RepeatMode: CaseIterable {
    case off
    case one
    case all
    
    /// Get the next repeat mode in cycle
    var next: RepeatMode {
        switch self {
        case .off: return .one
        case .one: return .all
        case .all: return .off
        }
    }
    
    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }
    
    /// Whether this mode is active (not off)
    var isActive: Bool {
        self != .off
    }
}

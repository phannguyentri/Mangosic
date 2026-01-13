import Foundation

/// Represents a YouTube track with audio and video stream information
struct Track: Identifiable {
    let id: String  // YouTube video ID
    let title: String
    let author: String
    let thumbnailURL: URL?
    let duration: TimeInterval?
    
    // Stream URLs
    let audioStreamURL: URL?
    let videoStreamURL: URL?
    
    // Video info
    let resolution: String?
    
    var formattedDuration: String {
        guard let duration = duration else { return "--:--" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var hasAudio: Bool { audioStreamURL != nil }
    var hasVideo: Bool { videoStreamURL != nil }
}

/// Playback mode
enum PlaybackMode: String, CaseIterable {
    case audio = "Audio Only"
    case video = "Video"
    
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

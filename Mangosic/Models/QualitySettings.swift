import Foundation
import SwiftUI

/// Video resolution quality options
enum VideoQuality: String, CaseIterable, Identifiable {
    case auto = "auto"
    case p360 = "360p"
    case p480 = "480p"
    case p720 = "720p"
    case p1080 = "1080p"
    case p1440 = "1440p"
    case p4K = "4K"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .auto: return "Auto (Highest)"
        case .p360: return "360p (Low)"
        case .p480: return "480p (Medium)"
        case .p720: return "720p (HD)"
        case .p1080: return "1080p (Full HD)"
        case .p1440: return "1440p (2K)"
        case .p4K: return "4K (Ultra HD)"
        }
    }
    
    /// Resolution value in pixels (height)
    var resolution: Int? {
        switch self {
        case .auto: return nil
        case .p360: return 360
        case .p480: return 480
        case .p720: return 720
        case .p1080: return 1080
        case .p1440: return 1440
        case .p4K: return 2160
        }
    }
    
    /// Icon for the quality level
    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .p360, .p480: return "square.and.arrow.down"
        case .p720: return "play.rectangle"
        case .p1080: return "play.rectangle.fill"
        case .p1440, .p4K: return "sparkles.tv"
        }
    }
}

/// Audio bitrate quality options
enum AudioQuality: String, CaseIterable, Identifiable {
    case auto = "auto"
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .auto: return "Auto (Highest)"
        case .low: return "Low (~64 kbps)"
        case .medium: return "Medium (~128 kbps)"
        case .high: return "High (~256 kbps)"
        }
    }
    
    /// Approximate bitrate in kbps
    var bitrate: Int? {
        switch self {
        case .auto: return nil
        case .low: return 64
        case .medium: return 128
        case .high: return 256
        }
    }
    
    /// Icon for the quality level
    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .low: return "speaker.wave.1"
        case .medium: return "speaker.wave.2"
        case .high: return "speaker.wave.3"
        }
    }
}

/// Singleton for managing quality settings with persistence
@MainActor
class QualitySettings: ObservableObject {
    static let shared = QualitySettings()
    
    /// Preferred video quality - persisted in UserDefaults
    @AppStorage("preferredVideoQuality") private var videoQualityRaw: String = VideoQuality.auto.rawValue
    
    /// Preferred audio quality - persisted in UserDefaults
    @AppStorage("preferredAudioQuality") private var audioQualityRaw: String = AudioQuality.auto.rawValue
    
    var videoQuality: VideoQuality {
        get { VideoQuality(rawValue: videoQualityRaw) ?? .auto }
        set { 
            videoQualityRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    var audioQuality: AudioQuality {
        get { AudioQuality(rawValue: audioQualityRaw) ?? .auto }
        set { 
            audioQualityRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    private init() {}
}

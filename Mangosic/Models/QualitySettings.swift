import Foundation
import SwiftUI

/// Resolution mode - simplified to just Normal or High
enum ResolutionMode: String, CaseIterable {
    case normal = "normal"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .high: return "HD"
        }
    }
    
    var icon: String {
        switch self {
        case .normal: return "play.rectangle"
        case .high: return "sparkles.tv"
        }
    }
}

/// Singleton for managing resolution mode with persistence
@MainActor
class QualitySettings: ObservableObject {
    static let shared = QualitySettings()
    
    /// Resolution mode - persisted in UserDefaults
    @AppStorage("resolutionMode") private var resolutionModeRaw: String = ResolutionMode.normal.rawValue
    
    var resolutionMode: ResolutionMode {
        get { ResolutionMode(rawValue: resolutionModeRaw) ?? .normal }
        set { 
            resolutionModeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    /// Toggle between normal and high
    func toggleResolution() {
        resolutionMode = resolutionMode == .normal ? .high : .normal
    }
    
    /// Check if high resolution mode is enabled
    var isHighResolution: Bool {
        resolutionMode == .high
    }
    
    private init() {}
}

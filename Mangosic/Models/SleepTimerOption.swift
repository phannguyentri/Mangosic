//
//  SleepTimerOption.swift
//  Mangosic
//
//  Created on 2026-01-15.
//
//  Model enum định nghĩa các tùy chọn hẹn giờ tắt nhạc (Sleep Timer).
//  Bao gồm tùy chọn kết thúc bài hát và các khoảng thời gian cố định.
//

import Foundation

// MARK: - SleepTimerOption

/// Enum đại diện cho các tùy chọn Sleep Timer
///
/// Sleep Timer cho phép người dùng hẹn giờ để tự động dừng phát nhạc.
/// Có 2 loại tùy chọn chính:
/// - **End of Song**: Dừng khi bài hát hiện tại kết thúc
/// - **Thời gian cố định**: Dừng sau khoảng thời gian nhất định (5-180 phút)
///
/// ## Cách sử dụng:
/// ```swift
/// // Lấy danh sách tùy chọn có thể chọn
/// let options = SleepTimerOption.selectableOptions
///
/// // Kiểm tra thời gian (giây)
/// if let seconds = SleepTimerOption.minutes30.durationInSeconds {
///     print("30 phút = \(seconds) giây")
/// }
/// ```
enum SleepTimerOption: CaseIterable, Identifiable {
    
    // MARK: - Cases
    
    /// Tắt Sleep Timer
    case off
    
    /// Dừng phát nhạc khi bài hát hiện tại kết thúc
    case endOfSong
    
    /// Dừng sau 5 phút
    case minutes5
    
    /// Dừng sau 10 phút
    case minutes10
    
    /// Dừng sau 15 phút
    case minutes15
    
    /// Dừng sau 30 phút
    case minutes30
    
    /// Dừng sau 60 phút (1 giờ)
    case minutes60
    
    /// Dừng sau 120 phút (2 giờ)
    case minutes120
    
    /// Dừng sau 180 phút (3 giờ)
    case minutes180
    
    // MARK: - Identifiable
    
    /// ID unique cho mỗi option, sử dụng display name
    var id: String { displayName }
    
    // MARK: - Display Properties
    
    /// Tên hiển thị cho người dùng (tiếng Anh)
    ///
    /// Ví dụ: "End of Song", "30 Minutes", "Off"
    var displayName: String {
        switch self {
        case .off:         return "Off"
        case .endOfSong:   return "End of Song"
        case .minutes5:    return "5 Minutes"
        case .minutes10:   return "10 Minutes"
        case .minutes15:   return "15 Minutes"
        case .minutes30:   return "30 Minutes"
        case .minutes60:   return "60 Minutes"
        case .minutes120:  return "120 Minutes"
        case .minutes180:  return "180 Minutes"
        }
    }
    
    // MARK: - Duration
    
    /// Thời gian tính bằng giây
    ///
    /// - Returns: Số giây cho option này, hoặc `nil` nếu:
    ///   - `.off`: Không có timer
    ///   - `.endOfSong`: Xử lý đặc biệt (dừng khi track kết thúc)
    var durationInSeconds: TimeInterval? {
        switch self {
        case .off:         return nil       // Không có timer
        case .endOfSong:   return nil       // Xử lý đặc biệt
        case .minutes5:    return 5 * 60    // 300 giây
        case .minutes10:   return 10 * 60   // 600 giây
        case .minutes15:   return 15 * 60   // 900 giây
        case .minutes30:   return 30 * 60   // 1800 giây
        case .minutes60:   return 60 * 60   // 3600 giây
        case .minutes120:  return 120 * 60  // 7200 giây
        case .minutes180:  return 180 * 60  // 10800 giây
        }
    }
    
    // MARK: - State Checks
    
    /// Kiểm tra xem option này có phải "End of Song" không
    ///
    /// "End of Song" cần xử lý đặc biệt: lắng nghe sự kiện track kết thúc
    /// thay vì đếm ngược thời gian.
    var isEndOfSong: Bool {
        self == .endOfSong
    }
    
    /// Kiểm tra timer có đang active không (không phải "Off")
    var isActive: Bool {
        self != .off
    }
    
    // MARK: - Static Properties
    
    /// Danh sách các option có thể chọn (không bao gồm "Off")
    ///
    /// Sử dụng trong UI để hiển thị menu selection.
    /// "Off" không được hiển thị vì người dùng sẽ sử dụng nút "Cancel" thay thế.
    static var selectableOptions: [SleepTimerOption] {
        allCases.filter { $0 != .off }
    }
}

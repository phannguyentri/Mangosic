//
//  SleepTimerService.swift
//  Mangosic
//
//  Created on 2026-01-15.
//
//  Service quản lý chức năng hẹn giờ tắt nhạc (Sleep Timer).
//  Hỗ trợ đếm ngược thời gian và dừng khi bài hát kết thúc.
//

import Foundation
import Combine

// MARK: - SleepTimerService

/// Service singleton quản lý Sleep Timer
///
/// `SleepTimerService` chịu trách nhiệm:
/// - Quản lý trạng thái timer (active/inactive)
/// - Đếm ngược thời gian còn lại
/// - Tự động pause nhạc khi timer kết thúc
/// - Xử lý tùy chọn "End of Song" (dừng khi bài hát hiện tại kết thúc)
///
/// ## Kiến trúc:
/// - **Singleton pattern**: Truy cập qua `SleepTimerService.shared`
/// - **@MainActor**: Đảm bảo thread-safety cho UI updates
/// - **ObservableObject**: Cho phép SwiftUI views subscribe và update
///
/// ## Cách sử dụng:
/// ```swift
/// // Bật timer 30 phút
/// SleepTimerService.shared.setTimer(.minutes30)
///
/// // Bật timer "End of Song"
/// SleepTimerService.shared.setTimer(.endOfSong)
///
/// // Hủy timer
/// SleepTimerService.shared.cancelTimer()
///
/// // Kiểm tra trạng thái
/// if SleepTimerService.shared.isTimerActive {
///     print("Còn lại: \(SleepTimerService.shared.formattedRemainingTime)")
/// }
/// ```
///
/// ## Luồng hoạt động:
/// 1. User chọn thời gian → `setTimer()` được gọi
/// 2. Timer bắt đầu đếm ngược mỗi giây
/// 3. UI update hiển thị thời gian còn lại
/// 4. Khi `remainingTime == 0` → `timerCompleted()` → pause nhạc
/// 5. Timer reset về trạng thái ban đầu
///
@MainActor
class SleepTimerService: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance duy nhất của SleepTimerService
    static let shared = SleepTimerService()
    
    // MARK: - Published Properties
    
    /// Tùy chọn timer đang được chọn
    ///
    /// Giá trị mặc định là `.off` (không có timer).
    /// Khi user chọn một option mới, property này sẽ được update.
    @Published private(set) var selectedOption: SleepTimerOption = .off
    
    /// Thời gian còn lại (giây)
    ///
    /// - Với timer thời gian: Đếm ngược từ duration xuống 0
    /// - Với "End of Song": Luôn là 0 (không đếm ngược)
    @Published private(set) var remainingTime: TimeInterval = 0
    
    /// Trạng thái active của timer
    ///
    /// `true` khi timer đang chạy (bao gồm cả "End of Song").
    /// `false` khi timer tắt hoặc đã hoàn thành.
    @Published private(set) var isTimerActive: Bool = false
    
    // MARK: - Private Properties
    
    /// Timer object thực hiện đếm ngược mỗi giây
    private var timer: Timer?
    
    /// Observer cho notification khi track kết thúc (dùng cho "End of Song")
    private var endOfSongObserver: NSObjectProtocol?
    
    /// Reference đến AudioPlayerService để control playback
    private let playerService = AudioPlayerService.shared
    
    /// Set chứa các Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Thời gian còn lại dạng chuỗi đầy đủ
    ///
    /// Format: `MM:SS` hoặc `H:MM:SS` (khi >= 1 giờ)
    ///
    /// Ví dụ:
    /// - 90 giây → "1:30"
    /// - 3665 giây → "1:01:05"
    /// - 0 giây → "" (chuỗi rỗng)
    var formattedRemainingTime: String {
        guard remainingTime > 0 else { return "" }
        
        let hours = Int(remainingTime) / 3600
        let minutes = (Int(remainingTime) % 3600) / 60
        let seconds = Int(remainingTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Thời gian còn lại dạng ngắn gọn
    ///
    /// Format ngắn gọn để hiển thị trong UI compact.
    ///
    /// Ví dụ:
    /// - 90 phút → "1h 30m"
    /// - 60 phút → "1h"
    /// - 5 phút → "5m"
    /// - 30 giây → "<1m"
    var shortRemainingTime: String {
        guard remainingTime > 0 else { return "" }
        
        let hours = Int(remainingTime) / 3600
        let minutes = (Int(remainingTime) % 3600) / 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
    
    // MARK: - Initialization
    
    /// Private initializer (singleton pattern)
    private init() {
        setupTrackEndObserver()
    }
    
    // MARK: - Public Methods
    
    /// Đặt Sleep Timer với option được chọn
    ///
    /// Method này sẽ:
    /// 1. Hủy timer hiện tại (nếu có)
    /// 2. Đặt option mới
    /// 3. Bắt đầu đếm ngược (nếu là timer thời gian)
    ///
    /// - Parameter option: Tùy chọn timer mới
    ///
    /// ## Các trường hợp:
    /// - `.off`: Tắt timer, reset trạng thái
    /// - `.endOfSong`: Bật chế độ dừng cuối bài, không đếm ngược
    /// - `.minutes*`: Bắt đầu đếm ngược từ số phút tương ứng
    func setTimer(_ option: SleepTimerOption) {
        // Luôn cancel timer cũ trước khi set timer mới
        cancelTimer()
        selectedOption = option
        
        switch option {
        case .off:
            // Reset hoàn toàn
            isTimerActive = false
            remainingTime = 0
            
        case .endOfSong:
            // Không đếm ngược, chỉ đợi track kết thúc
            isTimerActive = true
            remainingTime = 0 // UI sẽ hiển thị "End of Song"
            // Track end observer sẽ xử lý việc dừng nhạc
            
        default:
            // Timer thời gian: bắt đầu đếm ngược
            if let duration = option.durationInSeconds {
                isTimerActive = true
                remainingTime = duration
                startCountdown()
            }
        }
    }
    
    /// Hủy timer hiện tại
    ///
    /// Reset tất cả trạng thái về mặc định:
    /// - Dừng timer đếm ngược
    /// - Đặt `selectedOption` về `.off`
    /// - Đặt `isTimerActive` về `false`
    /// - Đặt `remainingTime` về `0`
    func cancelTimer() {
        timer?.invalidate()
        timer = nil
        selectedOption = .off
        isTimerActive = false
        remainingTime = 0
    }
    
    // MARK: - Private Methods
    
    /// Bắt đầu đếm ngược mỗi giây
    ///
    /// Tạo Timer chạy mỗi 1 giây, giảm `remainingTime` và check
    /// nếu đã đến 0 thì gọi `timerCompleted()`.
    private func startCountdown() {
        // Invalidate timer cũ nếu có
        timer?.invalidate()
        
        // Tạo timer mới, fire mỗi 1 giây
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if self.remainingTime > 0 {
                    self.remainingTime -= 1
                    
                    // Check nếu timer đã hoàn thành
                    if self.remainingTime <= 0 {
                        self.timerCompleted()
                    }
                }
            }
        }
    }
    
    /// Xử lý khi timer hoàn thành
    ///
    /// Được gọi khi:
    /// - `remainingTime` đếm xuống 0
    /// - Track kết thúc (với option "End of Song")
    ///
    /// Actions:
    /// 1. Pause playback
    /// 2. Reset timer state
    /// 3. Log để debug
    private func timerCompleted() {
        // Pause nhạc
        playerService.pause()
        
        // Reset timer state
        cancelTimer()
        
        print("💤 Sleep timer completed - Playback paused")
    }
    
    /// Setup observer cho sự kiện track kết thúc
    ///
    /// Observer này lắng nghe `AVPlayerItemDidPlayToEndTime` notification
    /// để xử lý tùy chọn "End of Song".
    ///
    /// Logic:
    /// - Chỉ kích hoạt khi `selectedOption == .endOfSong`
    /// - Chỉ pause nếu `repeatMode == .off` (tránh conflict với repeat)
    private func setupTrackEndObserver() {
        // Lắng nghe notification khi track chơi xong
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Chỉ xử lý nếu đang ở chế độ "End of Song"
                if self.selectedOption == .endOfSong {
                    // Không pause nếu đang repeat (vì track sẽ chơi lại)
                    if self.playerService.repeatMode == .off {
                        self.playerService.pause()
                        self.cancelTimer()
                        print("💤 Sleep timer (End of Song) - Playback paused")
                    }
                }
            }
        }
    }
}

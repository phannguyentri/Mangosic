//
//  SleepTimerView.swift
//  Mangosic
//
//  Created on 2026-01-15.
//
//  UI components cho Sleep Timer feature.
//  Bao gồm sheet selection và compact indicator.
//

import SwiftUI

// MARK: - SleepTimerSheet

/// Sheet popup để chọn Sleep Timer option
///
/// `SleepTimerSheet` là một modal view hiển thị danh sách các tùy chọn
/// Sleep Timer. Được present từ `PlayerView` khi user tap vào nút moon.
///
/// ## Features:
/// - Header với icon moon và trạng thái timer
/// - Danh sách tất cả các option có thể chọn
/// - Checkmark indicator cho option đang active
/// - Nút "Cancel Timer" khi timer đang chạy
///
/// ## Usage:
/// ```swift
/// .sheet(isPresented: $showingSleepTimer) {
///     SleepTimerSheet()
///         .presentationDetents([.medium])
/// }
/// ```
///
/// ## Design:
/// - Background: Dark blue (#1A1A2E)
/// - Icon: Golden moon với "ZZZ" animation
/// - Active option: Highlighted với Theme.primaryEnd
///
struct SleepTimerSheet: View {
    
    // MARK: - Properties
    
    /// Reference đến SleepTimerService singleton
    @ObservedObject var sleepTimerService = SleepTimerService.shared
    
    /// Environment dismiss action để đóng sheet
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // MARK: Background
            Color(hex: "1A1A2E")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: Header Section
                sleepTimerHeader
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                // MARK: Options List
                ScrollView {
                    VStack(spacing: 0) {
                        // Hiển thị tất cả options (trừ "Off")
                        ForEach(SleepTimerOption.selectableOptions) { option in
                            sleepTimerOptionRow(option)
                            
                            // Divider giữa các options
                            if option != SleepTimerOption.selectableOptions.last {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    // MARK: Cancel Button
                    // Chỉ hiển thị khi timer đang active
                    if sleepTimerService.isTimerActive {
                        Button {
                            sleepTimerService.cancelTimer()
                            dismiss()
                        } label: {
                            Text("Cancel Timer")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                }
            }
        }
    }
    
    // MARK: - Header View
    
    /// Header section với icon moon và thông tin timer
    ///
    /// Hiển thị:
    /// - Icon moon với "ZZZ" decorations
    /// - Title "Sleep Timer"
    /// - Subtitle: trạng thái timer hoặc description
    private var sleepTimerHeader: some View {
        HStack {
            // Moon icon với ZZZ effect
            ZStack {
                // Background circle với gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "2D2D4A"), Color(hex: "1A1A2E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                // Moon icon
                Image(systemName: "moon.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: "C4A35A")) // Golden color
                
                // ZZZ decorations
                Text("z")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "C4A35A"))
                    .offset(x: 12, y: -8)
                
                Text("z")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(hex: "C4A35A"))
                    .offset(x: 16, y: -13)
            }
            
            // Title và subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep Timer")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                // Subtitle thay đổi theo trạng thái
                if sleepTimerService.isTimerActive {
                    if sleepTimerService.selectedOption == .endOfSong {
                        // "End of Song" mode
                        Text("Stops at end of current song")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.primaryEnd)
                    } else {
                        // Timer countdown mode
                        Text("\(sleepTimerService.formattedRemainingTime) remaining")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.primaryEnd)
                    }
                } else {
                    // Timer inactive
                    Text("Set a timer to stop playback")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Option Row
    
    /// Tạo row cho mỗi Sleep Timer option
    ///
    /// - Parameter option: SleepTimerOption để hiển thị
    /// - Returns: View cho row này
    ///
    /// Row bao gồm:
    /// - Text hiển thị tên option
    /// - Checkmark nếu option này đang được chọn
    @ViewBuilder
    private func sleepTimerOptionRow(_ option: SleepTimerOption) -> some View {
        Button {
            sleepTimerService.setTimer(option)
            dismiss()
        } label: {
            HStack {
                // Option name
                Text(option.displayName)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Checkmark cho option đang active
                if sleepTimerService.selectedOption == option {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.primaryEnd, Theme.primaryEnd.opacity(0.3))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle()) // Mở rộng tap area
        }
    }
}

// MARK: - SleepTimerIndicator

/// Compact indicator hiển thị trạng thái Sleep Timer
///
/// `SleepTimerIndicator` là một badge nhỏ hiển thị thời gian còn lại
/// của Sleep Timer. Có thể sử dụng trong control bar hoặc mini player.
///
/// ## Features:
/// - Chỉ hiển thị khi timer active
/// - Icon moon nhỏ
/// - Text hiển thị thời gian compact ("5m", "1h 30m", "EOS")
///
/// ## Usage:
/// ```swift
/// // Trong control bar
/// HStack {
///     SleepTimerIndicator()
///     // ... other controls
/// }
/// ```
///
/// ## Visual:
/// - Background: Theme.primaryEnd.opacity(0.15)
/// - Text/Icon: Theme.primaryEnd
/// - Corner radius: 12
///
struct SleepTimerIndicator: View {
    
    // MARK: - Properties
    
    /// Reference đến SleepTimerService singleton
    @ObservedObject var sleepTimerService = SleepTimerService.shared
    
    // MARK: - Body
    
    var body: some View {
        // Chỉ hiển thị khi timer active
        if sleepTimerService.isTimerActive {
            HStack(spacing: 4) {
                // Moon icon
                Image(systemName: "moon.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.primaryEnd)
                
                // Time remaining hoặc "EOS" cho End of Song
                if sleepTimerService.selectedOption == .endOfSong {
                    Text("EOS") // End Of Song abbreviation
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.primaryEnd)
                } else {
                    Text(sleepTimerService.shortRemainingTime)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.primaryEnd)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.primaryEnd.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview

#Preview("Sleep Timer Sheet") {
    SleepTimerSheet()
}

#Preview("Sleep Timer Indicator") {
    ZStack {
        Color.black
        SleepTimerIndicator()
    }
}

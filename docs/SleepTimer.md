# Sleep Timer

Sleep Timer cho phép người dùng hẹn giờ để tự động dừng phát nhạc. Tính năng này hữu ích khi người dùng muốn nghe nhạc trước khi ngủ.

## Tính năng

### Các tùy chọn thời gian

| Option | Mô tả |
|--------|-------|
| **End of Song** | Dừng khi bài hát hiện tại kết thúc |
| **5 Minutes** | Dừng sau 5 phút |
| **10 Minutes** | Dừng sau 10 phút |
| **15 Minutes** | Dừng sau 15 phút |
| **30 Minutes** | Dừng sau 30 phút |
| **60 Minutes** | Dừng sau 1 giờ |
| **120 Minutes** | Dừng sau 2 giờ |
| **180 Minutes** | Dừng sau 3 giờ |

### Cách sử dụng

1. Mở **Player View** (tap vào mini player)
2. Tap vào **icon mặt trăng** 🌙 (bên trái controls)
3. Chọn thời gian mong muốn từ menu
4. Timer sẽ hiển thị trạng thái active trên icon

### Visual Indicators

- **Icon màu xám**: Timer không active
- **Icon màu cam + ZZZ**: Timer đang active
- **Thời gian còn lại**: Hiển thị trong sheet popup

## Kiến trúc

```
┌──────────────────────────────────────────────────────────────┐
│                      PlayerView                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Sleep Timer Button (moon icon)                          │ │
│  │  → Tap để mở SleepTimerSheet                            │ │
│  └─────────────────────────────────────────────────────────┘ │
│                            │                                  │
│                            ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  SleepTimerSheet (Modal)                                 │ │
│  │  ├── Header with moon icon and status                   │ │
│  │  ├── List of SleepTimerOption options                   │ │
│  │  └── Cancel Timer button (when active)                  │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                   SleepTimerService                           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  @Published selectedOption: SleepTimerOption            │ │
│  │  @Published remainingTime: TimeInterval                 │ │
│  │  @Published isTimerActive: Bool                         │ │
│  ├─────────────────────────────────────────────────────────┤ │
│  │  setTimer(_ option:) → Bắt đầu timer                    │ │
│  │  cancelTimer() → Hủy timer                              │ │
│  │  startCountdown() → Đếm ngược mỗi giây                  │ │
│  │  timerCompleted() → Pause nhạc khi hết giờ              │ │
│  └─────────────────────────────────────────────────────────┘ │
│                            │                                  │
│                            ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  AudioPlayerService.shared.pause()                       │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Components

### 1. SleepTimerOption (Model)

```swift
enum SleepTimerOption: CaseIterable, Identifiable {
    case off
    case endOfSong
    case minutes5
    case minutes10
    case minutes15
    case minutes30
    case minutes60
    case minutes120
    case minutes180
    
    var displayName: String { ... }
    var durationInSeconds: TimeInterval? { ... }
    var isEndOfSong: Bool { ... }
    var isActive: Bool { ... }
    
    static var selectableOptions: [SleepTimerOption] { ... }
}
```

**Vị trí**: `Mangosic/Models/SleepTimerOption.swift`

### 2. SleepTimerService (Service)

```swift
@MainActor
class SleepTimerService: ObservableObject {
    static let shared = SleepTimerService()
    
    // Published Properties
    @Published private(set) var selectedOption: SleepTimerOption
    @Published private(set) var remainingTime: TimeInterval
    @Published private(set) var isTimerActive: Bool
    
    // Computed Properties
    var formattedRemainingTime: String { ... }  // "1:30:00"
    var shortRemainingTime: String { ... }       // "1h 30m"
    
    // Methods
    func setTimer(_ option: SleepTimerOption) { ... }
    func cancelTimer() { ... }
}
```

**Vị trí**: `Mangosic/Services/SleepTimerService.swift`

### 3. SleepTimerSheet (View)

Modal sheet hiển thị khi user tap vào nút Sleep Timer.

**Features**:
- Header với icon moon và trạng thái timer
- Danh sách các options
- Checkmark indicator cho option đang active
- Nút "Cancel Timer" khi timer đang chạy

**Vị trí**: `Mangosic/Views/Components/SleepTimerView.swift`

### 4. SleepTimerIndicator (View)

Compact badge hiển thị trạng thái Sleep Timer trong control bar.

**Features**:
- Chỉ hiển thị khi timer active
- Icon moon nhỏ
- Text hiển thị thời gian compact ("5m", "1h 30m", "EOS")

**Vị trí**: `Mangosic/Views/Components/SleepTimerView.swift`

## Luồng hoạt động

### Timer đếm ngược

```
User chọn "30 Minutes"
        │
        ▼
setTimer(.minutes30)
        │
        ├── cancelTimer() (hủy timer cũ nếu có)
        ├── selectedOption = .minutes30
        ├── isTimerActive = true
        ├── remainingTime = 1800 (30 * 60)
        └── startCountdown()
                │
                ▼
        Timer.scheduledTimer(1 second interval)
                │
                ▼ (mỗi giây)
        remainingTime -= 1
                │
                ▼ (khi remainingTime <= 0)
        timerCompleted()
                │
                ├── playerService.pause()
                └── cancelTimer()
```

### "End of Song" mode

```
User chọn "End of Song"
        │
        ▼
setTimer(.endOfSong)
        │
        ├── selectedOption = .endOfSong
        ├── isTimerActive = true
        └── remainingTime = 0 (không đếm ngược)
                │
                ▼
        NotificationCenter observes AVPlayerItemDidPlayToEndTime
                │
                ▼ (khi track kết thúc)
        if selectedOption == .endOfSong && repeatMode == .off
                │
                ├── playerService.pause()
                └── cancelTimer()
```

## Integration với PlayerView

```swift
// PlayerView.swift

struct PlayerView: View {
    @ObservedObject private var sleepTimerService = SleepTimerService.shared
    @State private var showingSleepTimer = false
    
    var body: some View {
        // ... other content ...
        
        // Sleep Timer Button trong controls
        Button {
            showingSleepTimer = true
        } label: {
            ZStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(sleepTimerService.isTimerActive ? Theme.primaryEnd : .gray)
                
                // ZZZ indicator khi active
                if sleepTimerService.isTimerActive {
                    Text("z").offset(x: 10, y: -8)
                    Text("z").offset(x: 14, y: -12)
                }
            }
        }
        .sheet(isPresented: $showingSleepTimer) {
            SleepTimerSheet()
                .presentationDetents([.medium])
        }
    }
}
```

## Design

### Colors

| Element | Color |
|---------|-------|
| Sheet Background | `#1A1A2E` (Dark Blue) |
| Moon Icon | `#C4A35A` (Golden) |
| Active State | `Theme.primaryEnd` (Orange) |
| Inactive State | Gray |
| Cancel Button | Red |

### Typography

- Header Title: System 20, Bold
- Subtitle: System 13, Regular
- Option Text: System 16, Regular
- Time Display: System 13, Regular

## Testing

### Manual Testing Checklist

- [ ] Tap moon icon mở Sleep Timer sheet
- [ ] Chọn "5 Minutes" → Timer bắt đầu đếm ngược
- [ ] Thời gian còn lại hiển thị đúng trong sheet
- [ ] Moon icon đổi màu khi timer active
- [ ] ZZZ indicator xuất hiện khi timer active
- [ ] Nhạc tự động pause khi timer kết thúc
- [ ] "End of Song" pause khi track kết thúc
- [ ] "Cancel Timer" hủy timer đang chạy
- [ ] Timer hoạt động đúng khi app ở background

# YouTube Share Extension

Tính năng Share Extension cho phép người dùng chia sẻ video YouTube từ các app khác (như YouTube, Safari) trực tiếp vào Mangosic để phát.

## Tổng quan

Khi người dùng đang xem video trên YouTube và bấm nút Share, họ sẽ thấy "Play in Mangosic" trong danh sách các app có thể chia sẻ. Khi chọn, Mangosic sẽ mở và tự động phát video đó.

## Kiến trúc

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   YouTube App   │────▶│  MangosicShareExt    │────▶│   Mangosic App  │
│   (Share URL)   │     │  (Extract Video ID)  │     │  (Play Video)   │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
                                  │
                                  ▼
                        mangosic://play?v=VIDEO_ID
```

## Các file liên quan

### Share Extension
- `MangosicShareExtension/ShareViewController.swift` - Xử lý URL được chia sẻ
- `MangosicShareExtension/Info.plist` - Cấu hình extension
- `MangosicShareExtension/Base.lproj/MainInterface.storyboard` - UI (trong suốt)

### Main App
- `Mangosic/App/MangosicApp.swift` - Nhận URL scheme `mangosic://`
- `Mangosic/Services/DeepLinkManager.swift` - Quản lý deep links
- `Mangosic/Info.plist` - Đăng ký URL scheme

## URL Formats được hỗ trợ

Share Extension có thể xử lý các định dạng URL YouTube sau:

| Format | Ví dụ |
|--------|-------|
| Standard watch | `https://www.youtube.com/watch?v=dQw4w9WgXcQ` |
| Short URL | `https://youtu.be/dQw4w9WgXcQ` |
| Embed | `https://www.youtube.com/embed/dQw4w9WgXcQ` |
| Shorts | `https://www.youtube.com/shorts/dQw4w9WgXcQ` |
| YouTube Music | `https://music.youtube.com/watch?v=dQw4w9WgXcQ` |
| Legacy embed | `https://www.youtube.com/v/dQw4w9WgXcQ` |

## Hướng dẫn thêm Share Extension Target vào Xcode

### Bước 1: Thêm Target mới

1. Mở project trong Xcode
2. Nhấn **File → New → Target...**
3. Chọn **iOS → Share Extension**
4. Đặt tên: `MangosicShareExtension`
5. Chọn **Team**: (team của bạn)
6. Language: **Swift**
7. Nhấn **Finish**
8. Nếu được hỏi "Activate scheme?", chọn **Cancel** (giữ scheme chính)

### Bước 2: Thay thế các file mặc định

Xcode sẽ tạo các file mặc định. Thay thế chúng bằng các file đã chuẩn bị:

1. **Xóa** `ShareViewController.swift` mặc định
2. **Kéo thả** file `MangosicShareExtension/ShareViewController.swift` từ Finder vào project
3. Làm tương tự với `Info.plist` và `MainInterface.storyboard`

### Bước 3: Cấu hình Bundle ID

1. Chọn Target **MangosicShareExtension**
2. Tab **General**
3. Đặt Bundle Identifier: `com.example.Mangosic.ShareExtension`
   - Phải là prefix của Bundle ID app chính!

### Bước 4: (Tùy chọn) Cấu hình App Groups

Nếu muốn share data giữa extension và app khi app đang đóng:

1. Chọn Target **Mangosic** → **Signing & Capabilities**
2. Nhấn **+ Capability** → **App Groups**
3. Thêm group: `group.com.example.Mangosic`
4. Làm tương tự cho Target **MangosicShareExtension**

### Bước 5: Build và Test

1. Chọn scheme **Mangosic** (app chính)
2. Build và chạy trên device hoặc simulator
3. Mở app YouTube
4. Mở một video và nhấn **Share**
5. Tìm **"Play in Mangosic"** trong danh sách
6. Nhấn vào → App Mangosic sẽ mở và phát video

## Lưu ý quan trọng

### Giới hạn của Share Extension

1. **Bộ nhớ giới hạn**: Extension có giới hạn RAM ~120MB
2. **Không thể mở URL trực tiếp**: Extension không thể gọi `UIApplication.shared.open()` trực tiếp
3. **Phải sử dụng workaround**: Sử dụng responder chain hoặc selector

### Debugging

- Để debug extension, chọn scheme **MangosicShareExtension**
- Khi chạy, Xcode sẽ hỏi chọn app host (chọn YouTube hoặc Safari)
- Breakpoints sẽ hoạt động trong extension code

### Testing trên Simulator

- Share Extension hoạt động trên cả Simulator và Device
- Trên Simulator, có thể test bằng Safari với URL YouTube

## Troubleshooting

| Vấn đề | Giải pháp |
|--------|-----------|
| Extension không xuất hiện trong Share Sheet | Kiểm tra `NSExtensionActivationRule` trong Info.plist |
| App không mở khi share | Kiểm tra URL scheme đã đăng ký trong app chính |
| Video không tự động phát | Kiểm tra `onOpenURL` handler trong MangosicApp |
| Crash khi share | Kiểm tra Console log, có thể do memory limit |

## Cấu trúc Code

### ShareViewController.swift

```swift
// Các method chính:
- handleSharedContent()    // Nhận nội dung được share
- processURL(_:)           // Xử lý URL YouTube
- extractVideoID(from:)    // Trích xuất video ID từ URL
- openMainApp(with:)       // Mở app chính với video ID
```

### MangosicApp.swift

```swift
// URL Handler:
.onOpenURL { url in
    handleIncomingURL(url)  // Xử lý mangosic://play?v=VIDEO_ID
}
```

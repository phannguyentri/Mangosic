# MiniPlayer (NowPlayingBar)

## Overview

The MiniPlayer (`NowPlayingBar`) is a compact floating bar displayed at the bottom of the main screen when a track is playing. It provides essential playback controls and track information without taking up the entire screen.

## Features

- 🎨 **Thumbnail Display** - Shows the current track's thumbnail image
- 📝 **Track Info** - Displays title and author
- ▶️ **Play/Pause Control** - Quick toggle button
- 🔗 **Quick Access** - Tap to open full player view
- 🎭 **Glassmorphism Design** - Modern blur effect background

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│ NowPlayingBar                                                   │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────┐  ┌─────────────────────────────┐  ┌────────────────┐ │
│  │      │  │ Title (bold, 1 line)        │  │                │ │
│  │ 48x48│  │ Author (gray, 1 line)       │  │   ▶️ / ⏸️      │ │
│  │      │  │                             │  │                │ │
│  └──────┘  └─────────────────────────────┘  └────────────────┘ │
│  Thumbnail       Track Info                    Play/Pause      │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

## File Location

```
Mangosic/Views/NowPlayingBar.swift
```

## Code Structure

```swift
struct NowPlayingBar: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail: Bool = false
    
    var body: some View { ... }
    
    private func loadThumbnail() { ... }
    private var thumbnailPlaceholder: some View { ... }
}
```

## Data Flow

```
PlayerViewModel
       │
       ├── currentTrack: Track?
       │   ├── title: String
       │   ├── author: String
       │   └── thumbnailURL: URL?
       │
       ├── isPlaying: Bool
       │
       └── showingPlayer: Bool
                │
    ┌───────────┴───────────┐
    │                       │
    ▼                       ▼
NowPlayingBar           PlayerView
(Mini Player)         (Full Player)
```

## Thumbnail Loading

### Problem Fixed (2026-01-15)

**Issue**: Thumbnail không hiển thị ổn định trong mini player, mặc dù luôn load được thành công ở các nơi khác (PlayerView, Search Results).

**Root Cause**: 
- `AsyncImage` của SwiftUI không hoạt động đáng tin cậy trong một số trường hợp:
  - Không refresh khi URL thay đổi nhưng view không re-render
  - Caching behavior không predictable
  - Khó debug vì không có access trực tiếp vào loading process

**Solution**: Thay thế `AsyncImage` bằng manual image loading với `URLSession`:

```swift
// ❌ Trước đây (không ổn định)
AsyncImage(url: viewModel.currentTrack?.thumbnailURL) { phase in
    switch phase {
    case .success(let image): ...
    case .failure: ...
    case .empty: ...
    }
}

// ✅ Bây giờ (ổn định)
@State private var thumbnailImage: UIImage?

private func loadThumbnail() {
    guard let url = viewModel.currentTrack?.thumbnailURL else { return }
    
    Task {
        let (data, _) = try await URLSession.shared.data(from: url)
        if let image = UIImage(data: data) {
            await MainActor.run {
                self.thumbnailImage = image
            }
        }
    }
}

// Trigger reload when URL changes
.onChange(of: viewModel.currentTrack?.thumbnailURL) { _, _ in
    loadThumbnail()
}
```

### Benefits of Manual Loading

| Aspect | AsyncImage | Manual URLSession |
|--------|-----------|-------------------|
| Reliability | ⚠️ Inconsistent | ✅ Consistent |
| Debug | ❌ Black box | ✅ Full visibility |
| Error handling | Limited | ✅ Custom handling |
| Caching control | None | ✅ Full control |
| Performance | Auto-managed | Need manual optimization |

## Usage

The `NowPlayingBar` is conditionally displayed in `ContentView` when a track is loaded:

```swift
// ContentView.swift
ZStack(alignment: .bottom) {
    // Main content...
    
    // Now Playing Bar (shows when track is loaded)
    if viewModel.currentTrack != nil {
        NowPlayingBar(viewModel: viewModel)
            .padding(.horizontal)
            .padding(.bottom)
    }
}
```

## Interactions

### Tap on Bar
Opens the full player view:
```swift
.onTapGesture {
    viewModel.showingPlayer = true
}
```

### Play/Pause Button
Toggles playback state:
```swift
Button {
    viewModel.togglePlayPause()
} label: {
    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
}
```

## Styling

### Background
Glassmorphism effect with blur:
```swift
.background(
    RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(0.1))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
)
```

### Thumbnail
- Size: 48x48 points
- Corner radius: 6 points
- Content mode: Fill with clipping

### Typography
- Title: `.subheadline.bold()`, white color, 1 line max
- Author: `.caption`, gray color, 1 line max

## Debug Logging

The component includes debug logs for troubleshooting:

```
📷 Loading thumbnail from: https://...
✅ Thumbnail loaded successfully
// or
❌ Failed to load thumbnail: [error message]
⚠️ No thumbnail URL available
🔄 Thumbnail URL changed: [old] -> [new]
```

## Potential Improvements

1. **Image Caching**: Implement disk/memory caching for thumbnails
2. **Gesture Controls**: Add swipe gestures for next/previous track
3. **Progress Bar**: Add mini progress indicator
4. **Animation**: Add entry/exit animations
5. **Accessibility**: Improve VoiceOver support

## Related Files

- `PlayerViewModel.swift` - State management
- `PlayerView.swift` - Full player view
- `ContentView.swift` - Parent container
- `AudioPlayerService.swift` - Playback service
- `Track.swift` - Track model with thumbnailURL

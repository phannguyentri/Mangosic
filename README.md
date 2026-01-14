# Mangosic iOS

A native iOS app to play YouTube audio and video using YouTubeKit.

## Features

- 🎵 **Audio Playback** - Extract and play audio from any YouTube video
- 🎬 **Video Playback** - Watch YouTube videos with native player
- 🔊 **Background Audio** - Continue listening with screen off
- 🎛️ **Now Playing** - Lock screen controls and media info
- 📱 **iOS 17+** - Modern SwiftUI interface
- 🔄 **Seamless Mode Switching** - Switch between audio and video instantly without interruption

## Requirements

- Xcode 15+
- iOS 17.0+
- Swift 5.9+

## Dependencies

- [YouTubeKit](https://github.com/alexeichhorn/YouTubeKit) - YouTube stream extraction

## Setup

1. Open `Mangosic.xcodeproj` in Xcode
2. Wait for Swift Package Manager to fetch dependencies
3. Build and run on your device/simulator

## Usage

1. Paste a YouTube URL or video ID
2. Choose "Play Audio" or "Play Video"
3. Enjoy!

### Mode Switching

While playing, you can switch between audio and video modes:
- Tap the **Audio** button to hide video and continue listening
- Tap the **Video** button to show the video player

The switch is **instant** - playback continues from the same position without any loading or buffering.

## Architecture

```
Mangosic/
├── App/
│   └── MangosicApp.swift           # App entry point
├── Views/
│   ├── ContentView.swift           # Main view with URL input
│   ├── PlayerView.swift            # Audio/Video player view
│   ├── VideoPlayerView.swift       # Video player component
│   └── NowPlayingBar.swift         # Mini player bar
├── ViewModels/
│   └── PlayerViewModel.swift       # Player state management
├── Services/
│   ├── YouTubeService.swift        # YouTubeKit wrapper
│   └── AudioPlayerService.swift    # AVPlayer management
└── Models/
    └── Track.swift                 # Track data model
```

## Technical Notes

### Seamless Mode Switching

The app uses a single video stream for both audio and video modes. This enables:

1. **Instant switching** - No need to reload the stream when changing modes
2. **Continuous playback** - Audio never stops during mode transitions
3. **Accurate duration** - Video streams provide correct duration metadata

When switching modes:
- **Same stream available**: Just toggle `playbackMode` property, UI updates instantly
- **Different streams** (fallback): Reload with `seekTime` to preserve playback position

### Stream Selection Strategy

```swift
// Both modes prefer video stream for accurate duration
streamURL = track.videoStreamURL ?? track.audioStreamURL
```

This design choice ensures:
- Duration is always accurate (audio-only streams sometimes have incorrect metadata)
- Mode switching is seamless when video stream is available
- Fallback to audio-only stream if video is unavailable

## License

MIT License

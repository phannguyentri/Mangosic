# YTMusicPlayer iOS

A native iOS app to play YouTube audio and video using YouTubeKit.

## Features

- 🎵 **Audio Playback** - Extract and play audio from any YouTube video
- 🎬 **Video Playback** - Watch YouTube videos with native player
- 🔊 **Background Audio** - Continue listening with screen off
- 🎛️ **Now Playing** - Lock screen controls and media info
- 📱 **iOS 17+** - Modern SwiftUI interface

## Requirements

- Xcode 15+
- iOS 17.0+
- Swift 5.9+

## Dependencies

- [YouTubeKit](https://github.com/alexeichhorn/YouTubeKit) - YouTube stream extraction

## Setup

1. Open `YTMusicPlayer.xcodeproj` in Xcode
2. Wait for Swift Package Manager to fetch dependencies
3. Build and run on your device/simulator

## Usage

1. Paste a YouTube URL or video ID
2. Choose "Play Audio" or "Play Video"
3. Enjoy!

## Architecture

```
YTMusicPlayer/
├── App/
│   └── YTMusicPlayerApp.swift      # App entry point
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

## License

MIT License

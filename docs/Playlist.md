# 🎵 Playlist Feature

## Overview

The Playlist feature provides comprehensive music queue management and saved playlist functionality for Mangosic. Users can create personal playlists, manage a playback queue, and track their listening history.

## Features

### Core Features
- **Queue Management** - Add, remove, and reorder tracks in the current playback queue
- **Saved Playlists** - Create, edit, and delete personal playlists
- **Recently Played** - Automatic tracking of listening history
- **Shuffle** - Randomize queue order

### User Interactions
- **Swipe Actions** - Swipe left to delete, swipe right to add to queue
- **Long Press Menu** - Context menu with options (Add to Queue, Add to Playlist, etc.)
- **Drag to Reorder** - Drag handle to reorder tracks in queue/playlist
- **Haptic Feedback** - Tactile feedback for actions

## Architecture

### Data Models (SwiftData)

```swift
// Playlist - User-created playlist
@Model
final class Playlist {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade)
    var tracks: [PlaylistTrackItem]
}

// PlaylistTrackItem - Track within a playlist
@Model
final class PlaylistTrackItem {
    var id: UUID
    var videoId: String
    var title: String
    var author: String
    var thumbnailURL: URL?
    var duration: String?
    var addedAt: Date
    var orderIndex: Int
}

// RecentPlay - Recently played track
@Model
final class RecentPlay {
    var id: UUID
    var videoId: String
    var title: String
    var author: String
    var thumbnailURL: URL?
    var playedAt: Date
}

// QueueItem - Track in current queue (in-memory)
struct QueueItem: Identifiable {
    let id: UUID
    let videoId: String
    let title: String
    let author: String
    let thumbnailURL: URL?
    let duration: String?
}
```

### Services

| Service | Purpose |
|---------|---------|
| `PlaylistService` | CRUD operations for playlists |
| `QueueService` | Queue management (add, remove, reorder, shuffle) |
| `HistoryService` | Track recently played songs |

### Views

```
Views/
├── Library/
│   ├── LibraryView.swift           # Main library tab
│   ├── RecentlyPlayedView.swift    # Recently played section
│   ├── PlaylistListView.swift      # List of all playlists
│   └── PlaylistDetailView.swift    # Playlist content view
├── Queue/
│   ├── QueueView.swift             # Queue sheet (half-modal)
│   └── QueueItemRow.swift          # Draggable queue item
└── Components/
    ├── TrackRow.swift              # Reusable track row
    ├── PlaylistCard.swift          # Playlist preview card
    ├── AddToPlaylistSheet.swift    # Add track dialog
    └── CreatePlaylistSheet.swift   # Create playlist dialog
```

## User Interface

### Navigation Structure

The app uses a bottom tab bar with two main tabs:

| Tab | Icon | Content |
|-----|------|---------|
| Home | 🏠 | Search, URL input, Now Playing Bar |
| Library | 📚 | Recently Played, Playlists |

### Queue Access

Users can access the queue from:
1. **Mini Player** - Tap queue icon on `NowPlayingBar`
2. **Full Player** - Tap queue icon in `PlayerView`

The queue appears as a **half-sheet modal** that can be:
- Swiped up to expand
- Swiped down to dismiss
- Dragged to reorder items

### Library Tab Layout

```
┌─────────────────────────────────────┐
│  📚 Library                         │
├─────────────────────────────────────┤
│                                     │
│  ⏱️ Recently Played           See All →
│  ┌────┐ ┌────┐ ┌────┐              │
│  │ 🎵 │ │ 🎵 │ │ 🎵 │ ...         │  (Horizontal scroll)
│  └────┘ └────┘ └────┘              │
│                                     │
│  📋 Your Playlists         [+ New] │
│  ┌─────────────────────────────────┐
│  │ 🎵 Workout Mix        12 songs │ │
│  ├─────────────────────────────────┤
│  │ 🎵 Chill Vibes        8 songs  │ │
│  └─────────────────────────────────┘
│                                     │
└─────────────────────────────────────┘
```

## Usage

### Adding to Queue

```swift
// From search results
QueueService.shared.addToQueue(track)

// Play next (insert after current)
QueueService.shared.playNext(track)
```

### Managing Playlists

```swift
// Create new playlist
let playlist = PlaylistService.shared.createPlaylist(name: "My Playlist")

// Add track to playlist
PlaylistService.shared.addTrack(track, to: playlist)

// Remove track
PlaylistService.shared.removeTrack(track, from: playlist)

// Delete playlist
PlaylistService.shared.deletePlaylist(playlist)
```

### Shuffle

```swift
// Enable shuffle
QueueService.shared.shuffle()

// Shuffle and play playlist
QueueService.shared.shuffleAndPlay(playlist)
```

### Recently Played

```swift
// Record play (automatic)
HistoryService.shared.recordPlay(track)

// Get recent plays
let history = HistoryService.shared.getRecentPlays(limit: 20)

// Clear history
HistoryService.shared.clearHistory()
```

## Context Menu Actions

| Action | Description |
|--------|-------------|
| Play Now | Replace queue and play immediately |
| Play Next | Insert after current track |
| Add to Queue | Add to end of queue |
| Add to Playlist | Show playlist picker |
| Share | Share YouTube URL |
| Remove | Remove from queue/playlist |

## Technical Notes

### Storage

- **SwiftData** is used for persistent storage (iOS 17+)
- **Queue** is stored in-memory (resets on app close)
- **Playlists** and **RecentPlay** are persisted

### Data Container Setup

```swift
@main
struct MangosicApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Playlist.self, PlaylistTrackItem.self, RecentPlay.self])
    }
}
```

### Performance Considerations

- Recent plays are limited to 100 items (FIFO)
- Playlists support up to 500 tracks each
- Queue supports unlimited items (in-memory)
- Thumbnail images are loaded lazily

## Implementation Phases

### Phase 1: Foundation ✅
- SwiftData setup
- Data models
- Basic services

### Phase 2: Queue System
- Queue management
- Play next/Add to queue
- Queue view (sheet)
- Shuffle

### Phase 3: Navigation & Library
- TabView navigation
- Library view
- Recently Played tracking

### Phase 4: Saved Playlists
- Playlist CRUD
- Add/remove tracks
- Playlist detail view

### Phase 5: Polish & UX
- Animations
- Haptic feedback
- Empty states
- Error handling

## Future Enhancements

- [ ] Import YouTube playlists
- [ ] Playlist artwork customization
- [ ] Smart playlists (auto-generated)
- [ ] Collaborative playlists
- [ ] Cloud sync (iCloud)
- [ ] Playlist folders/categories

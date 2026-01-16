# 🎵 Playlist & Queue Feature

## Overview

The Playlist feature provides comprehensive music queue management and saved playlist functionality for Mangosic. Users can create personal playlists, manage a playback queue, track listening history, and navigate tracks with Previous/Next controls.

## Features

### Core Features
- **Queue Management** - Add, remove, and reorder tracks in the current playback queue
- **Saved Playlists** - Create, edit, and delete personal playlists
- **Recently Played** - Automatic tracking of listening history
- **Shuffle** - Randomize queue order with proper state management
- **Previous/Next Navigation** - Navigate between tracks in queue

### User Interactions
- **Swipe Actions** - Swipe left to delete, swipe right to add to queue
- **Long Press Menu** - Context menu with options (Add to Queue, Add to Playlist, etc.)
- **Drag to Reorder** - Drag handle to reorder tracks in queue/playlist
- **Double-tap Skip** - Double-tap on video/album art to skip ±10 seconds
- **Haptic Feedback** - Tactile feedback for all actions
- **Add Button (+)** - Quick add to playlist from search results and PlayerView

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
    
    var coverURL: URL?  // From first track
    var trackCount: Int // Computed
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
    var playlist: Playlist?
}

// RecentPlay - Recently played track
@Model
final class RecentPlay {
    var id: UUID
    var videoId: String
    var title: String
    var author: String
    var thumbnailURL: URL?
    var duration: String?
    var playedAt: Date
}

// QueueItem - Track in current queue (in-memory)
struct QueueItem: Identifiable, Equatable {
    let id: UUID
    let videoId: String
    let title: String
    let author: String
    let thumbnailURL: URL?
    let duration: String?
}
```

### Services

| Service | File | Purpose |
|---------|------|---------|
| `PlaylistService` | `Services/PlaylistService.swift` | CRUD operations for playlists |
| `QueueService` | `Services/QueueService.swift` | Queue management (add, remove, reorder, shuffle) |
| `HistoryService` | `Services/HistoryService.swift` | Track recently played songs |

### Views

```
Views/
├── MainTabView.swift               # Tab navigation + fullScreenCover for PlayerView
├── Library/
│   ├── LibraryView.swift           # Main library tab with sections
│   ├── RecentlyPlayedListView.swift# Full history list view
│   └── PlaylistDetailView.swift    # Playlist content with play controls
├── Queue/
│   └── QueueView.swift             # Queue sheet (half-modal)
└── Components/
    ├── QueueComponents.swift       # QueueButton, ShuffleButton
    └── TrackContextMenu.swift      # Context menu + AddToPlaylistSheet
```

## User Interface

### Navigation Structure

The app uses a **TabView** with **fullScreenCover** for PlayerView:

```
┌─────────────────────────────────────┐
│         MainTabView                  │
├─────────────────────────────────────┤
│                                     │
│  ┌──────────┐    ┌──────────┐      │
│  │  Home    │    │  Library │      │
│  │   Tab    │    │   Tab    │      │
│  └──────────┘    └──────────┘      │
│                                     │
├─────────────────────────────────────┤
│      NowPlayingBar (floating)       │
├─────────────────────────────────────┤
│        🏠 Home     📚 Library       │
└─────────────────────────────────────┘
                 ↓
    .fullScreenCover → PlayerView
```

**Why fullScreenCover?**
- PlayerView is independent of tab navigation
- Tap tab once to return (no double-tap needed)
- Consistent behavior from any entry point

### Tab Bar

| Tab | Icon | Content |
|-----|------|---------|
| Home | `house.fill` | Search, URL input, Play button |
| Library | `music.note.list` | Recently Played, Playlists |

### Queue Access

Users can access the queue from:
1. **Mini Player (NowPlayingBar)** - Tap queue icon
2. **Full Player (PlayerView)** - Tap queue icon (≡) in toolbar

The queue appears as a **sheet modal** with:
- "Now Playing" section
- "Up Next" section
- Shuffle toggle button
- Drag-to-reorder
- Swipe-to-delete

### Library Tab Layout

```
┌─────────────────────────────────────┐
│  📚 Library                    [+]  │
├─────────────────────────────────────┤
│                                     │
│  ⏱️ Recently Played       See All → │
│  ┌────┐ ┌────┐ ┌────┐              │
│  │ 🎵 │ │ 🎵 │ │ 🎵 │ ...         │  ← Horizontal scroll
│  └────┘ └────┘ └────┘              │
│                                     │
│  📋 Your Playlists                  │
│  ┌─────────────────────────────────┐
│  │ 🎵 Workout Mix        12 songs │ │
│  ├─────────────────────────────────┤
│  │ 🎵 Chill Vibes        8 songs  │ │
│  └─────────────────────────────────┘
│                                     │
└─────────────────────────────────────┘
```

### Player Controls

```
┌─────────────────────────────────────┐
│   ⌄                    ⊕  ≡   ✕     │  ← Toolbar (collapse, add, queue, close)
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────────┐│
│  │                                 ││
│  │     [Double-tap left: -10s]    ││  ← Video/Album art
│  │     [Double-tap right: +10s]   ││
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │
│         Song Title                  │
│         Artist Name                 │
│                                     │
│  0:00 ═══════════○═════════ 3:45   │  ← Progress bar
│                                     │
│   🌙    ⏮    ▶/⏸    ⏭    🔁      │  ← Controls
│  Sleep  Prev  Play  Next  Repeat   │
│                                     │
│      [Video]    [Audio Only]        │  ← Mode switcher
│                                     │
└─────────────────────────────────────┘
```

## Usage

### Adding to Queue

```swift
// From search results - add to end
QueueService.shared.addToQueue(searchResult)

// Play next (insert after current)
QueueService.shared.playNext(searchResult)

// Set entire queue from playlist
let queueItems = playlistTracks.map { QueueItem(from: $0) }
QueueService.shared.setQueue(queueItems, startIndex: 0)
```

### Queue Navigation

```swift
// Previous track
if queueService.hasPrevious {
    queueService.previous()
    // Load and play current item
}

// Next track
if queueService.hasNext {
    queueService.next()
    // Load and play current item
}
```

### Managing Playlists

```swift
// Create new playlist
PlaylistService.shared.createPlaylist(name: "My Playlist")

// Add track to playlist
PlaylistService.shared.addTrack(searchResult, to: playlist)

// Remove track
PlaylistService.shared.removeTrack(trackItem, from: playlist)

// Rename playlist
PlaylistService.shared.renamePlaylist(playlist, to: "New Name")

// Duplicate playlist
PlaylistService.shared.duplicatePlaylist(playlist)

// Delete playlist
PlaylistService.shared.deletePlaylist(playlist)
```

### Shuffle

```swift
// Toggle shuffle mode
QueueService.shared.toggleShuffle()

// Shuffle and play playlist
let queueItems = playlistTracks.map { QueueItem(from: $0) }
QueueService.shared.shuffleAndPlay(queueItems)
```

**Shuffle Implementation Notes:**
- Uses `videoId` (not UUID) for item identification
- Preserves current playing track at index 0 when shuffling
- Correctly restores original order when unshuffling

### Recently Played

```swift
// Record play (automatic when playing)
HistoryService.shared.recordPlay(
    videoId: track.videoId,
    title: track.title,
    author: track.author,
    thumbnailURL: track.thumbnailURL,
    duration: track.duration
)

// Get recent plays
let history = HistoryService.shared.getRecentPlays(limit: 20)

// Remove single item
HistoryService.shared.removePlay(recentPlay)

// Clear all history
HistoryService.shared.clearHistory()
```

## Context Menu Actions

Available on search results and playlist tracks:

| Action | Icon | Description |
|--------|------|-------------|
| Play Next | `text.line.first.and.arrowtriangle.forward` | Insert after current track |
| Add to Queue | `text.badge.plus` | Add to end of queue |
| Add to Playlist | `music.note.list` | Show playlist picker |
| Share | `square.and.arrow.up` | Share YouTube URL |

## Add to Playlist Flow

```
1. User taps "+" button or "Add to Playlist" in context menu
                 ↓
2. AddToPlaylistSheet appears (half-sheet)
                 ↓
3. Options:
   a. Select existing playlist → Track added
   b. Tap "New Playlist" → Enter name → Create & add track
                 ↓
4. Success haptic feedback + sheet dismisses
```

## Technical Notes

### Storage

| Data | Storage Type | Persistence |
|------|--------------|-------------|
| Playlists | SwiftData | ✅ Persisted |
| PlaylistTrackItem | SwiftData | ✅ Persisted |
| RecentPlay | SwiftData | ✅ Persisted |
| Queue | In-memory | ❌ Resets on app close |

### Data Container Setup (MangosicApp.swift)

```swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Playlist.self,
        PlaylistTrackItem.self,
        RecentPlay.self
    ])
    let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false
    )
    return try! ModelContainer(for: schema, configurations: [modelConfiguration])
}()
```

### Service Initialization

```swift
// Configure services with SwiftData context on app launch
private func setupServices() {
    let context = sharedModelContainer.mainContext
    PlaylistService.shared.configure(with: context)
    HistoryService.shared.configure(with: context)
}
```

### Performance Considerations

- Recent plays are limited to 100 items (FIFO)
- Playlists support up to 500 tracks each
- Queue supports unlimited items (in-memory)
- Thumbnail images are loaded lazily with AsyncImage
- Loading indicators shown during playlist play/shuffle

## Implementation Status

### ✅ Phase 1: Foundation - COMPLETED
- SwiftData setup and configuration
- Data models (Playlist, PlaylistTrackItem, RecentPlay, QueueItem)
- Basic services (PlaylistService, QueueService, HistoryService)

### ✅ Phase 2: Queue System - COMPLETED
- Queue management (add, remove, reorder)
- Play next / Add to queue from search results
- Queue view (half-sheet modal)
- Shuffle functionality with proper state management
- Queue button on mini player and full player

### ✅ Phase 3: Navigation & Library - COMPLETED
- TabView navigation (Home + Library tabs)
- fullScreenCover for PlayerView (consistent navigation)
- Library view with Recently Played + Playlists sections
- Recently Played horizontal scroll + full list view
- Playlist list with navigation to detail

### ✅ Phase 4: Saved Playlists - COMPLETED
- Playlist CRUD (create, read, update, delete)
- Add/remove tracks to/from playlists
- Playlist detail view with track list
- Play entire playlist / Shuffle play with loading indicators
- Rename and duplicate playlist options
- Context menus on search results

### ✅ Phase 5: Player Controls - COMPLETED
- Previous/Next track buttons
- Double-tap on video/album art to skip ±10s
- Visual skip indicator animation
- Proper queue navigation integration
- Haptic feedback on all controls

### ✅ Phase 6: Polish & UX - COMPLETED
- Context menus (long press)
- Swipe actions (delete)
- Haptic feedback on all actions
- Loading indicators for playlist play/shuffle
- Empty states for library sections
- Add button (+) on search results and PlayerView

## File Structure

```
Mangosic/
├── App/
│   └── MangosicApp.swift           # SwiftData container + service setup
├── Models/
│   └── PlaylistModels.swift        # Playlist, PlaylistTrackItem, RecentPlay, QueueItem
├── Services/
│   ├── PlaylistService.swift       # Playlist CRUD operations
│   ├── QueueService.swift          # Queue + shuffle management
│   └── HistoryService.swift        # Recently played tracking
└── Views/
    ├── MainTabView.swift           # Tab navigation + PlayerView cover
    ├── PlayerView.swift            # Full player with prev/next controls
    ├── NowPlayingBar.swift         # Mini player with queue button
    ├── SearchView.swift            # Search with add (+) buttons
    ├── Library/
    │   ├── LibraryView.swift       # Main library tab
    │   ├── RecentlyPlayedListView.swift
    │   └── PlaylistDetailView.swift
    ├── Queue/
    │   └── QueueView.swift         # Queue sheet
    └── Components/
        ├── QueueComponents.swift   # QueueButton, ShuffleButton
        └── TrackContextMenu.swift  # AddToPlaylistSheet
```

# Background Playback & Player Stability

Mangosic implements robust background playback capabilities, ensuring that audio continues uninterrupted when the device is locked, the app enters the background, or when switching between playback modes (Video <-> Audio).

## 1. Overview

By default, iOS pauses `AVPlayer` instances that have an active video track when the application enters the background or the screen is locked. Mangosic overrides this behavior to provide a seamless listening experience, treating video content as audio-first when visual elements are not active.

## 2. Core Architecture

The core logic resides in `AudioPlayerService.swift`, which acts as the central manager for playback state, audio session configuration, and lifecycle events.

### Audio Session Configuration
The app uses the `AVAudioSession` with the `.playback` category, allowing audio to mix with other system sounds or silence them depending on context, and crucially, permitting background execution.

```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, mode: .default, options: [])
try session.setActive(true)
```

## 3. Implementation Strategies

### 3.1. Background Video Playback Fix

To prevent iOS from automatically pausing video playback when the screen locks, we utilize a **2-Stage Lifecycle Handling** strategy:

1.  **Stage 1 (`willResignActiveNotification`)**: 
    - We capture the player's `isPlaying` state *before* iOS intervenes. 
    - This creates a reliable "intent to play" flag (`wasPlayingBeforeInterruption`).

2.  **Stage 2 (`didEnterBackgroundNotification`)**:
    - By this time, iOS has likely paused the player if it contains a video track.
    - We detect this pause and use a **Delayed Resume** technique (dispatching `play()` calls with small delays like 0.1s, 0.3s) to override the system's pause command and resume playback immediately.

```swift
// Pseudo-code logic
if wasPlayingBeforeInterruption {
    // Re-activate session
    session.setActive(true)
    // Force resume after iOS auto-pause
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        player.play()
    }
}
```

### 3.2. Detached Player Pattern (View Layer)

`AVPlayerViewController` is tightly coupled with system behaviors and will aggressively pause playback if it thinks the view is no longer visible (e.g., backgrounding).

We solved this by creating `BackgroundFriendlyAVPlayerViewController` (in `VideoPlayerView.swift`).

- **Mechanism**: When the app enters the background, this controller temporarily **detaches** the `player` instance (sets `self.player = nil`) while keeping a reference to it in `storedPlayer`.
- **Result**: iOS sees a view controller with no player, so it doesn't issue a pause command. The actual `AVPlayer` instance (managed by `AudioPlayerService`) continues playing audio in the background.
- **Restoration**: When returning to the foreground, the player is re-attached to the view.

### 3.3. Robust Mode Switching (Video <-> Audio)

Switching from Video to Audio mode involves destroying the heavy video view and loading a lighter audio interface. This often caused race conditions where the dismantling video view would pause the shared player *after* the new audio mode had started.

**Solutions Applied:**
1.  **Safe Dismantling**: `VideoPlayerView` implements `dismantleUIViewController` to explicitly detach the player before the view is deallocated.
2.  **Decoupled Reload**: In `PlayerViewModel`, we introduced a micro-delay (0.1s) when switching modes. This allows the UI cleanup to finish completely before the commands to load the new stream are sent to the player.

```swift
// PlayerViewModel.swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    self.playerService.play(track, mode: mode, seekTime: currentSeekTime)
}
```

## 4. Key Files

- **`Services/AudioPlayerService.swift`**: Handles lifecycle observation (`didEnterBackground`, `willResignActive`) and audio session management.
- **`Views/VideoPlayerView.swift`**: Implements the `BackgroundFriendlyAVPlayerViewController` subclass for the "Detached Player" pattern.
- **`Views/FullscreenVideoPlayerView.swift`**: Uses the same background-friendly controller for consistent behavior in fullscreen.
- **`ViewModels/PlayerViewModel.swift`**: Manages delay logic for safe mode switching.

## 5. Troubleshooting

**Issue**: Audio stops 10-20 seconds after locking screen.
- **Cause**: Background Modes capability not enabled or AVPlayer buffer ran out.
- **Fix**: Check `Info.plist` for `UIBackgroundModes` -> `audio`.

**Issue**: Audio stops immediately on lock.
- **Cause**: `AVPlayerViewController` paused the player.
- **Fix**: Verify `BackgroundFriendlyAVPlayerViewController` is being used and is correctly detaching the player.

**Issue**: Player UI shows "Playing" but no sound after switching modes.
- **Cause**: Race condition where `seek` completion handler failed or player state desynced.
- **Fix**: Ensure `playImmediately(atRate: 1.0)` is used instead of simple `play()`, and tolerance is set to `.zero`.

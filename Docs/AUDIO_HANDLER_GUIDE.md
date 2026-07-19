---
type: reference
---

# Audio Handler Integration Guide

SwiftProyecto provides a built-in audio player handler for common audio formats on both iOS and macOS.

## Supported Formats

The default audio handler supports 10 common formats:
- MP3 (`.mp3`)
- MPEG-4 Audio / iTunes (`.m4a`)
- Advanced Audio Coding (`.aac`)
- WAV (`.wav`)
- Free Lossless Audio Codec (`.flac`)
- Ogg Vorbis (`.ogg`)
- Opus (`.opus`)
- Windows Media Audio (`.wma`)
- Apple Lossless Audio Codec (`.alac`)
- Audio Interchange File Format (`.aiff`)

## Basic Usage

Register audio handlers when creating a `ProjectWindow`:

```swift
import ProjectBrowser

let projectURL = URL(fileURLWithPath: "/path/to/project")

var handlers = DefaultHandlers.audioHandlers(directoryURL: projectURL)

// Add custom handlers for other file types
handlers["fountain"] = { file in
  AnyView(ScreenplayView(file: file))
}

ProjectWindow(
  directoryURL: projectURL,
  handlers: handlers
)
```

## Combined Usage (Audio + Image)

For projects with both images and audio files:

```swift
// Option 1: Use the combined handler
var handlers = DefaultHandlers.allHandlers(directoryURL: projectURL)

// Option 2: Merge manually
var handlers = DefaultHandlers.imageHandlers(directoryURL: projectURL)
handlers.merge(DefaultHandlers.audioHandlers(directoryURL: projectURL)) { _, new in new }

ProjectWindow(
  directoryURL: projectURL,
  handlers: handlers
)
```

## Features

The audio player provides:
- **Playback controls** — play/pause button with visual feedback
- **Progress seeking** — drag to seek through the audio
- **Duration display** — shows total duration and current time
- **Volume control** — adjustable volume slider
- **Error handling** — displays user-friendly error messages when playback fails
- **iOS/macOS compatibility** — works seamlessly on iOS 26+ and macOS 26+
- **Auto-stop on dismiss** — stops playback when navigating away

## Manual Registration

For selective registration of specific audio extensions:

```swift
let mp3Handler = DefaultHandlers.audioHandler(for: "mp3", directoryURL: projectURL)
handlers["mp3"] = mp3Handler.viewBuilder
```

Or register all at once:

```swift
var handlers: [String: (ProjectFile) -> AnyView] = [:]

// Add audio handlers for all common formats
for ext in DefaultHandlers.audioExtensions {
  let handler = DefaultHandlers.audioHandler(for: ext, directoryURL: projectURL)
  handlers[ext] = handler.viewBuilder
}
```

## Implementation Notes

- Uses `AVFoundation` framework for audio playback (available on iOS and macOS)
- Leverages `AVPlayer` for robust playback handling
- Async duration loading prevents UI blocking
- Proper resource cleanup on view dismiss
- Main actor isolation ensures thread-safe UI updates
- No external audio library dependencies

## Customization

To create a custom audio player with different UI or behavior, build on `AudioPlayerView`:

```swift
struct CustomAudioView: View {
  let file: ProjectFile
  let directoryURL: URL

  var body: some View {
    AudioPlayerView(file: file, directoryURL: directoryURL)
      .navigationTitle("Now Playing: \(file.displayName)")
  }
}
```

## Troubleshooting

### Audio file won't load
- Ensure the file exists at the resolved path
- Check that the file extension matches the actual format
- Verify the file is not corrupted

### No sound output
- Check system volume level
- Verify the slider isn't set to 0
- Ensure audio output device is properly configured

### Seeking doesn't work smoothly
- This is expected during initial load—duration must load first
- Once loaded, seeking should be responsive

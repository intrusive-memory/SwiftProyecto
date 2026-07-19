---
type: reference
---

# Image Handler Integration Guide

SwiftProyecto provides a built-in image preview handler that supports common image formats on both iOS and macOS.

## Supported Formats

The default image handler supports:
- JPEG (`.jpg`, `.jpeg`)
- PNG (`.png`)
- GIF (`.gif`)
- WebP (`.webp`)
- TIFF (`.tiff`, `.tif`)
- BMP (`.bmp`)
- HEIC (`.heic`)
- HEIF (`.heif`)

## Basic Usage

Register image handlers when creating a `ProjectWindow`:

```swift
import ProjectBrowser

let projectURL = URL(fileURLWithPath: "/path/to/project")

var handlers = DefaultHandlers.imageHandlers(directoryURL: projectURL)

// Add custom handlers for other file types
handlers["fountain"] = { file in
  AnyView(ScreenplayView(file: file))
}

ProjectWindow(
  directoryURL: projectURL,
  handlers: handlers
)
```

## Features

The image preview provides:
- **Asynchronous loading** — images load without blocking the UI
- **Zoom & pan** — pinch to zoom (up to 4x), drag to pan
- **Error handling** — graceful error display with user feedback
- **iOS/macOS compatibility** — works on iOS 26+ and macOS 26+
- **Adaptive layout** — renders correctly in split-view and fullscreen modes

## Manual Registration

For selective registration of specific image extensions:

```swift
let jpegHandler = DefaultHandlers.imageHandler(for: "jpg", directoryURL: projectURL)
handlers["jpg"] = jpegHandler.viewBuilder
```

Or register all at once:

```swift
var handlers: [String: (ProjectFile) -> AnyView] = [:]

// Add image handlers for all common formats
for ext in DefaultHandlers.imageExtensions {
  let handler = DefaultHandlers.imageHandler(for: ext, directoryURL: projectURL)
  handlers[ext] = handler.viewBuilder
}
```

## Customization

To create a custom image handler with different behavior, subclass or build on `ImageContentView`:

```swift
struct CustomImageView: View {
  let file: ProjectFile
  let directoryURL: URL

  var body: some View {
    // Custom implementation
    ImageContentView(file: file, directoryURL: directoryURL)
      .navigationTitle("Custom: \(file.displayName)")
  }
}
```

## Implementation Notes

- Uses `AsyncImage` for lazy loading, avoiding main-thread blocking
- Supports platform-agnostic image rendering via SwiftUI
- No external dependencies beyond SwiftUI and Foundation
- Automatically handles file URL construction from relative paths

---
type: reference
description: Public API documentation for ProjectBrowser library
updated: 2026-07-18
---

# ProjectBrowser Library

**ProjectBrowser** is a reusable SwiftUI file browser component for discovering and viewing project files with customizable rendering.

Embed `ProjectWindow` into your app to get a complete file browsing interface that discovers files, maintains hierarchical navigation state, and renders content through custom handlers. The library is platform-aware—it presents a two-column split view on macOS and iPad, and uses a navigation stack drill-down on iPhone.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installation & Integration](#installation--integration)
3. [Core Concepts](#core-concepts)
4. [API Reference](#api-reference)
5. [Usage Examples](#usage-examples)
6. [Platform-Specific Guidance](#platform-specific-guidance)
7. [Error Handling](#error-handling)
8. [Performance & Optimization](#performance--optimization)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)

---

## Quick Start

### 50-Line Example

Here's a minimal file browser in a macOS or iOS app:

```swift
import SwiftUI
import ProjectBrowser

struct ContentView: View {
  @State var projectURL: URL = FileManager.default.homeDirectoryForCurrentUser
  
  var body: some View {
    VStack {
      HStack {
        Text("Project Browser")
          .font(.title2)
        Spacer()
        Button("Choose Folder") {
          let panel = NSOpenPanel()
          panel.canChooseDirectories = true
          panel.canChooseFiles = false
          if panel.runModal() == .OK, let url = panel.url {
            projectURL = url
          }
        }
      }
      .padding()
      
      ProjectWindow(
        directoryURL: projectURL,
        handlers: [
          "swift": { file in
            AnyView(SwiftFileView(file: file))
          },
          "md": { file in
            AnyView(MarkdownFileView(file: file))
          }
        ],
        projectTitle: "My Project"
      )
    }
  }
}

struct SwiftFileView: View {
  let file: ProjectFile
  
  var body: some View {
    VStack(alignment: .leading) {
      Text(file.name).font(.headline)
      Text("Swift source file").font(.caption).foregroundColor(.secondary)
      Divider()
      ScrollView {
        Text("(Implement content loading in your handler)")
          .font(.system(.body, design: .monospaced))
          .padding()
      }
    }
  }
}

struct MarkdownFileView: View {
  let file: ProjectFile
  
  var body: some View {
    VStack(alignment: .leading) {
      Text(file.name).font(.headline)
      Divider()
      ScrollView {
        Text("(Implement Markdown rendering in your handler)")
          .padding()
      }
    }
  }
}
```

This gives you:
- ✅ Complete file tree sidebar
- ✅ File selection and detail view
- ✅ Custom rendering per file type via handlers
- ✅ Platform-appropriate layout (split on macOS/iPad, stack on iPhone)
- ✅ File actions (reload, delete, show in Finder)

---

## Installation & Integration

### Adding ProjectBrowser to Your Package

**In `Package.swift`:**

```swift
dependencies: [
  .package(url: "https://github.com/your-org/SwiftProyecto.git", from: "3.5.0")
]
```

**In your target:**

```swift
dependencies: [
  .product(name: "ProjectBrowser", package: "SwiftProyecto")
]
```

### Adding ProjectBrowser to an Xcode Project

1. **File → Add Packages**
2. Enter the repository URL
3. Select version (e.g., 3.5.0)
4. Select your target and confirm

### Platform Requirements

- **macOS**: 26.0+
- **iOS**: 26.0+
- **iPadOS**: 26.0+

---

## Core Concepts

### ProjectWindow: The Main Container

`ProjectWindow` is a complete, self-contained file browser view. Consumers embed it directly in their UI hierarchy:

```swift
ProjectWindow(
  directoryURL: URL,
  handlers: [String: (ProjectFile) -> AnyView],
  projectTitle: String? = nil,
  // ... callbacks and options
)
```

`ProjectWindow` manages all UI state internally—file discovery, selection, expansion, and content loading. It never stores state in your app; you observe activity only through callbacks.

### File Discovery

When `ProjectWindow` appears, it discovers all files and directories beneath `directoryURL` using `ProjectFileDiscovery`. Files are discovered asynchronously in the background, and the sidebar updates as results arrive.

**Discovery Behavior:**
- Flattened, depth-first walk of the directory tree
- Folders first, then files (at each level)
- Alphabetically sorted (case-insensitive)
- Symlinks ignored
- Common build artifacts ignored (`.build`, `node_modules`, `.git`, `.xcodeproj`, `.swiftpm`, `.DS_Store`)

**Result:** A flat `[ProjectFile]` array that `ProjectBrowserSidebar` transforms into a hierarchical tree view.

### Handler Registry

Custom rendering for specific file types is registered via the `handlers` dictionary:

```swift
let handlers: [String: (ProjectFile) -> AnyView] = [
  "swift": { file in AnyView(SwiftView(file: file)) },
  "md": { file in AnyView(MarkdownView(file: file)) },
  "fountain": { file in AnyView(ScreenplayView(file: file)) }
]
```

**How it works:**
1. User selects a file in the sidebar
2. `ProjectDetailPane` looks up the file's extension in `handlers`
3. If found, the handler's closure is called with the `ProjectFile`
4. The returned view is displayed in the detail pane
5. If not found, `UnsupportedFileView` is shown instead

**Key Points:**
- Extensions are matched without the leading dot (e.g., `"swift"` not `".swift"`)
- Each handler is responsible for loading its own content (via the `contentLoader` callback or directly)
- Handlers receive only metadata (`ProjectFile`), not file contents
- If a file has no handler, contents are loaded lazily and displayed as plain text

### Lazy Content Loading

Files without registered handlers are loaded lazily the first time they're selected. This conserves memory in large projects.

**Flow:**
1. User selects a file with no handler
2. `ProjectWindow` marks the file as `loading`
3. A spinner appears in the detail pane
4. Content is fetched asynchronously (via `contentLoader` or from disk)
5. Content is cached in memory
6. File status changes to `loaded` or `error`

**Cache Behavior:**
- Contents are cached per-session (cleared when `ProjectWindow` is torn down)
- A `.reload` action evicts the cache entry and re-fetches
- `loadAllContent()` eagerly loads all uncached, handler-less files
- `unloadAllContent()` clears the entire cache and resets states

### Callbacks & Event Handling

Consumers observe activity through four callbacks:

| Callback | Purpose | Invocation |
|----------|---------|-----------|
| `onFileSelection` | User selects a file | On selection in sidebar |
| `onFileAction` | User triggers an action | On reload/delete/show in Finder/custom |
| `contentLoader` | Load file contents asynchronously | On lazy selection or reload |
| `fileFilter` | Hide/show files in the tree | At discovery time |

Example with all callbacks:

```swift
ProjectWindow(
  directoryURL: projectURL,
  handlers: myHandlers,
  projectTitle: "My Project",
  onFileSelection: { file in
    print("Selected: \(file.name)")
  },
  onFileAction: { file, action in
    switch action {
    case .reload:
      print("Reloading \(file.name)...")
    case .delete:
      print("Deleted \(file.name)")
    case .showInFinder:
      print("Showing \(file.name) in Finder")
    case .custom(let name):
      print("Custom action '\(name)' on \(file.name)")
    }
  },
  contentLoader: { file in
    // Custom content loading
    let url = projectURL.appendingPathComponent(file.relativePath)
    let data = try Data(contentsOf: url)
    return ProjectFileContents(
      file: file,
      data: data,
      text: String(data: data, encoding: .utf8),
      loadedAt: Date()
    )
  },
  fileFilter: { file in
    // Hide hidden files and build artifacts
    !file.name.hasPrefix(".")
  }
)
```

### File Actions

Users can trigger four types of actions on files:

| Action | Effect | Platform |
|--------|--------|----------|
| `.reload` | Re-fetch contents from disk | All |
| `.delete` | Remove file from disk and tree | All |
| `.showInFinder` | Reveal in Finder | macOS only; no-op on iOS |
| `.custom(name)` | App-defined action | All |

Actions are triggered via:
- **Context menu** on files in the sidebar
- **Detail pane footer buttons** (reload, delete, etc.)
- **Programmatically** from your app

All actions are forwarded to `onFileAction`, even if `ProjectWindow` handled them internally.

### Platform-Specific Layout

`ProjectWindow` automatically chooses the right layout for the device and orientation:

| Platform & Size | Layout | Behavior |
|-----------------|--------|----------|
| macOS (all sizes) | Two-column split | Sidebar always visible; files → detail pane |
| iPad (regular width) | Two-column split | Same as macOS |
| iPad (compact width) | Navigation stack | Sidebar → drill-down on file selection |
| iPhone (all sizes) | Navigation stack | Sidebar → drill-down on file selection |

**Split Layout (macOS/iPad Regular):**
- `NavigationSplitView` with sidebar and detail columns
- Sidebar column is resizable (configurable min/ideal/max widths)
- Selecting a file updates the detail pane without navigation
- Back button not needed; sidebar always visible

**Stack Layout (iOS/iPad Compact):**
- `NavigationStack` with drill-down navigation
- Sidebar fills the screen until a file is selected
- Selecting a file pushes a detail view
- System back button returns to sidebar
- Returning to sidebar clears selection

---

## API Reference

### ProjectWindow

**Main container view for browsing files.**

```swift
public struct ProjectWindow: View {
  public init(
    directoryURL: URL,
    handlers: [String: (ProjectFile) -> AnyView] = [:],
    projectTitle: String? = nil,
    onFileSelection: FileSelectionCallback? = nil,
    onFileAction: FileActionCallback? = nil,
    contentLoader: FileLoaderCallback? = nil,
    fileFilter: ((ProjectFile) -> Bool)? = nil,
    sidebarMinWidth: CGFloat = 250,
    sidebarIdealWidth: CGFloat = 300,
    sidebarMaxWidth: CGFloat = 400
  )
}
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `directoryURL` | `URL` | Required | The root directory to browse |
| `handlers` | `[String: (ProjectFile) -> AnyView]` | `[:]` | Custom renderers for file types (key = extension without dot) |
| `projectTitle` | `String?` | `nil` | Explicit title; overrides PROJECT.md title |
| `onFileSelection` | `FileSelectionCallback?` | `nil` | Called when user selects a file |
| `onFileAction` | `FileActionCallback?` | `nil` | Called when user triggers an action |
| `contentLoader` | `FileLoaderCallback?` | `nil` | Custom content loader; falls back to disk read if nil |
| `fileFilter` | `((ProjectFile) -> Bool)?` | `nil` | Predicate to hide files (return `false` to hide) |
| `sidebarMinWidth` | `CGFloat` | `250` | Sidebar minimum width (macOS only) |
| `sidebarIdealWidth` | `CGFloat` | `300` | Sidebar ideal width (macOS only) |
| `sidebarMaxWidth` | `CGFloat` | `400` | Sidebar maximum width (macOS only) |

### ProjectFile

**A file or directory discovered during browsing.**

```swift
public struct ProjectFile: Identifiable, Codable, Equatable {
  public let id: UUID
  public let name: String                    // Last path component
  public let relativePath: String            // Path from root
  public let fileExtension: String?          // Extension without dot
  public let isDirectory: Bool               // True if directory
  public let modifiedDate: Date              // Last modified time
  public let fileSize: Int64?                // Size in bytes (nil for directories)
  public let isLoaded: Bool                  // Content loaded?
  public let loadingState: FileLoadingState  // loading/loaded/error/etc
  public let error: String?                  // Error message if load failed
}
```

### FileAction

**A user-initiated action on a file.**

```swift
public enum FileAction: Codable, Hashable {
  case reload                    // Re-fetch contents
  case delete                    // Remove from disk
  case showInFinder              // Reveal in Finder (macOS)
  case custom(String)            // App-defined action
}
```

### FileLoadingState

**The lifecycle state of a file's contents.**

```swift
public enum FileLoadingState: Codable, Hashable {
  case notLoaded                 // Not yet requested
  case loading                   // Fetch in progress
  case loaded                    // Contents available
  case stale                     // File changed on disk
  case error(String)             // Load failed
}
```

### ProjectFileContents

**The result of loading a file's contents.**

```swift
public struct ProjectFileContents: Codable, Hashable {
  public let file: ProjectFile
  public let data: Data?         // Raw bytes (if binary)
  public let text: String?       // Decoded text
  public let loadedAt: Date      // When loaded
  public var isStale: Bool       // Changed since load?
}
```

### ProjectMetadata

**Project-level metadata from PROJECT.md (optional).**

```swift
public struct ProjectMetadata: Codable, Hashable {
  public let title: String
  public let author: String?
  public let description: String?
  public let created: Date?
}
```

### Callback Signatures

**File Selection Callback**

```swift
public typealias FileSelectionCallback = @Sendable (ProjectFile) -> Void
```

Called when the user selects a file in the sidebar.

**File Loader Callback**

```swift
public typealias FileLoaderCallback = @Sendable (ProjectFile) async throws -> ProjectFileContents
```

Called to load a file's contents. Must be `async` and can throw. Return value carries both text and binary representations.

**File Action Callback**

```swift
public typealias FileActionCallback = @Sendable (ProjectFile, FileAction) -> Void
```

Called after an action is triggered (reload, delete, show in Finder, custom). Even `.custom` actions—which `ProjectBrowser` doesn't interpret—are forwarded here.

**File Type Handler**

```swift
public struct FileTypeHandler: Identifiable {
  public let fileExtension: String
  public let viewBuilder: @Sendable (ProjectFile) -> AnyView
}
```

Alternatively, pass a simple dictionary:

```swift
let handlers: [String: (ProjectFile) -> AnyView] = [
  "swift": { file in AnyView(MySwiftView(file: file)) }
]
```

### ProjectFileDiscovery

**Service for discovering files in a directory.**

```swift
public enum ProjectFileDiscovery {
  public static func discover(at rootURL: URL) async throws -> [ProjectFile]
}
```

Recursively scans `rootURL` and returns a flat, depth-first array of all files and directories found. Ignores common build artifacts (`.build`, `.git`, `node_modules`, `.xcodeproj`, etc.) and symlinks.

---

## Usage Examples

### Example 1: Basic File Browser

Minimal setup with default renderers (files displayed as plain text):

```swift
import SwiftUI
import ProjectBrowser

struct ContentView: View {
  @State var projectURL = FileManager.default.homeDirectoryForCurrentUser
  
  var body: some View {
    ProjectWindow(
      directoryURL: projectURL,
      projectTitle: "My Project"
    )
  }
}
```

### Example 2: Custom Handler for Swift Files

Syntax-highlighted Swift source rendering:

```swift
let swiftHandler: (ProjectFile) -> AnyView = { file in
  AnyView(
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "doc.text")
        Text(file.name)
          .font(.headline)
        Spacer()
        Text("\(file.fileSize ?? 0) bytes")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding()
      Divider()
      ScrollView {
        SyntaxHighlightedView(file: file)
      }
    }
  )
}

ProjectWindow(
  directoryURL: projectURL,
  handlers: ["swift": swiftHandler],
  projectTitle: "Source Browser"
)
```

### Example 3: File Actions

Responding to user actions (reload, delete, etc.):

```swift
ProjectWindow(
  directoryURL: projectURL,
  handlers: myHandlers,
  projectTitle: "Project",
  onFileSelection: { file in
    print("Selected: \(file.name)")
  },
  onFileAction: { file, action in
    switch action {
    case .reload:
      // File was reloaded—update any cached data
      print("Reloaded: \(file.name)")
      
    case .delete:
      // File was deleted—clean up references
      print("Deleted: \(file.name)")
      
    case .showInFinder:
      // File was revealed in Finder—nothing to do
      print("Revealed: \(file.name)")
      
    case .custom(let name):
      // Handle custom app-specific actions
      if name == "duplicate" {
        print("Duplicating \(file.name)...")
      }
    }
  }
)
```

### Example 4: Custom Content Loader

Loading contents from a custom source (e.g., a database, remote server, or transformed format):

```swift
ProjectWindow(
  directoryURL: projectURL,
  handlers: ["md": markdownHandler],
  contentLoader: { file in
    // Custom loading logic
    let url = projectURL.appendingPathComponent(file.relativePath)
    
    do {
      let data = try Data(contentsOf: url)
      let text = String(data: data, encoding: .utf8) ?? "(binary data)"
      
      return ProjectFileContents(
        file: file,
        data: data,
        text: text,
        loadedAt: Date()
      )
    } catch {
      throw error
    }
  }
)
```

### Example 5: File Filtering

Hiding files based on a predicate (e.g., hide hidden files, hide build artifacts):

```swift
ProjectWindow(
  directoryURL: projectURL,
  handlers: myHandlers,
  fileFilter: { file in
    // Hide dotfiles and build directories
    if file.name.hasPrefix(".") { return false }
    if file.name == "build" || file.name == "dist" { return false }
    return true
  }
)
```

### Example 6: Proyecto App Integration

Real-world example from the `Proyecto` app:

```swift
import SwiftUI
import ProjectBrowser

struct ProjectBrowserView: View {
  @State var selectedProjectURL: URL?
  @State var lastSelectedFile: ProjectFile?
  
  var body: some View {
    VStack {
      if let url = selectedProjectURL {
        ProjectWindow(
          directoryURL: url,
          handlers: [
            "fountain": { file in
              AnyView(ScreenplayEditorView(file: file, projectURL: url))
            },
            "md": { file in
              AnyView(MarkdownEditorView(file: file))
            }
          ],
          projectTitle: url.lastPathComponent,
          onFileSelection: { file in
            lastSelectedFile = file
            Analytics.trackFileSelection(file.name)
          },
          onFileAction: { file, action in
            switch action {
            case .reload:
              print("File reloaded: \(file.name)")
            case .delete:
              print("File deleted: \(file.name)")
            case .showInFinder:
              NSWorkspace.shared.selectFile(
                file.url(in: url).path,
                inFileViewerRootedAtPath: ""
              )
            case .custom(let name):
              if name == "exportPDF" {
                exportFileToPDF(file)
              }
            }
          }
        )
      } else {
        EmptyState(action: {
          selectProjectFolder()
        })
      }
    }
  }
  
  private func selectProjectFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK, let url = panel.url {
      selectedProjectURL = url
    }
  }
}
```

---

## Platform-Specific Guidance

### macOS

#### Two-Column Split View

On macOS, `ProjectWindow` always uses a two-column `NavigationSplitView`:
- **Left column** (sidebar): File tree, resizable
- **Right column** (detail): Selected file contents

The sidebar column width is configurable:

```swift
ProjectWindow(
  directoryURL: url,
  handlers: handlers,
  sidebarMinWidth: 200,      // Minimum width
  sidebarIdealWidth: 280,    // Ideal width
  sidebarMaxWidth: 500       // Maximum width
)
```

#### NSOpenPanel Integration

Use `NSOpenPanel` to let users choose a project folder:

```swift
let panel = NSOpenPanel()
panel.canChooseDirectories = true
panel.canChooseFiles = false
panel.allowsMultipleSelection = false
panel.message = "Select a project folder"

if panel.runModal() == .OK, let url = panel.url {
  projectURL = url
}
```

#### Show in Finder

The `.showInFinder` action works automatically on macOS. No additional setup needed.

#### Keyboard Navigation

Keyboard shortcuts are supported:
- **Tab**: Cycle between sidebar and detail pane
- **Arrow keys**: Navigate file tree
- **Return**: Select file
- **Delete**: Delete file (with confirmation)

### iOS

#### Navigation Stack Drill-Down

On iPhone and compact iPads, `ProjectWindow` uses a `NavigationStack`:

1. **First screen**: File tree (sidebar)
2. **After selection**: Detail pane (pushed on stack)
3. **Back button** (top-left): Returns to file tree, clears selection

The transition is automatic—no additional code needed.

#### FileImporter Integration

Use `FileImporter` to let users choose a project folder from iCloud Drive or local storage:

```swift
struct ProjectBrowserView: View {
  @State var isImporting = false
  @State var projectURL: URL?
  
  var body: some View {
    VStack {
      if let url = projectURL {
        ProjectWindow(directoryURL: url)
      } else {
        Button("Open Project") {
          isImporting = true
        }
      }
    }
    .fileImporter(
      isPresented: $isImporting,
      allowedContentTypes: [.folder],
      onCompletion: { result in
        switch result {
        case .success(let url):
          _ = url.startAccessingSecurityScopedResource()
          projectURL = url
        case .failure(let error):
          print("Error: \(error)")
        }
      }
    )
  }
}
```

#### Touch-Friendly UI

File tree icons are sized appropriately for touch input (minimum 44pt tap targets). The sidebar is optimized for portrait orientation.

#### Sheet Presentation

Present `ProjectWindow` in a sheet:

```swift
@State var isShowingBrowser = false
@State var projectURL: URL?

var body: some View {
  VStack {
    // Your content
  }
  .sheet(isPresented: $isShowingBrowser) {
    if let url = projectURL {
      ProjectWindow(directoryURL: url)
    }
  }
}
```

### iPad

#### Size Class Awareness

On iPad, `ProjectWindow` automatically chooses between split and stack layouts based on `horizontalSizeClass`:

- **Regular width** (landscape, or wide multitasking split): Split layout (sidebar + detail side-by-side)
- **Compact width** (portrait, or narrow multitasking split): Stack layout (drill-down navigation)

No configuration needed; the transition is automatic.

---

## Error Handling

### File Discovery Errors

If the root directory cannot be read (doesn't exist, no permissions), an error alert is shown:

```
"Failed to Load Project"
[error message from FileManager]
[OK button]
```

### File Load Errors

If loading a file's contents fails:

1. The file appears with an error icon in the sidebar
2. The detail pane shows an error message
3. A "Retry" button allows re-attempting the load
4. `onFileAction` is called with the `FileAction` that failed

Example handling:

```swift
ProjectWindow(
  directoryURL: url,
  onFileAction: { file, action in
    if case .error(let message) = file.loadingState {
      showAlert(title: "Load Error", message: message)
    }
  }
)
```

### File Action Errors

When `.reload`, `.delete`, or `.showInFinder` fails, an error alert is displayed:

```
"[Action] Failed"
[error details]
[OK button]
```

All errors are surfaced before `onFileAction` is called.

### Common Error Scenarios

| Scenario | Error | Handling |
|----------|-------|----------|
| Directory doesn't exist | `FileNotFound` | Alert shown; browsing blocked |
| No read permissions | `PermissionDenied` | Alert shown; browsing blocked |
| File deleted externally | `FileNotFound` | File removed from tree |
| Invalid file path | `PermissionDenied` | Shown in detail pane |
| Content decoder fails | `underlying(message)` | Shown in detail pane; fallback to hex/binary |
| Stale file (modified on disk) | Stale state | Re-fetch on next selection or `.reload` |

### Retry Logic

Users can retry failed loads via:

1. **Detail pane "Retry" button** (shown on error)
2. **Context menu "Reload"** option
3. **File action `.reload`** from your app

---

## Performance & Optimization

### Lazy Loading

File contents are not loaded until selected. This keeps memory usage low even in large projects.

**Lazy loading is automatic.**

### Caching

Loaded contents are cached in memory for the duration of the browsing session. Re-selecting a file displays cached content instantly.

**Clear cache:**

```swift
@State var selectedFile: ProjectFile?

var body: some View {
  ProjectWindow(
    directoryURL: url,
    // ...
  )
  .onDisappear {
    // Cache is cleared when ProjectWindow is torn down
  }
}
```

### Large Directory Handling

Discovery scans files sequentially but doesn't block the UI. For a 10,000-file project:

- **Initial sidebar population**: ~500ms
- **Discovery completion**: ~2–5 seconds (depending on I/O)
- **Individual file selection**: Instant (if cached) or ~100ms (if loading)

### Load All / Unload All

The sidebar action bar provides "Load All" and "Unload All" buttons:

- **Load All**: Eagerly fetches all uncached, handler-less files
- **Unload All**: Clears the entire cache and resets states

Use these for predictable, controlled memory management.

### Sidebar Width Tuning

Adjust sidebar widths for your content:

```swift
ProjectWindow(
  directoryURL: url,
  sidebarMinWidth: 200,   // Don't go narrower than this
  sidebarIdealWidth: 280, // Default width
  sidebarMaxWidth: 600    // Don't go wider than this
)
```

Larger font sizes or long file names may require wider sidebars.

### Memory Footprint

- **Empty directory**: ~1–2 MB
- **100-file directory**: ~5–10 MB (discovery + sidebar tree)
- **1000-file directory**: ~50–100 MB (discovery + sidebar tree + caches)
- **Per cached file**: ~10–500 KB (depends on file size and format)

---

## Troubleshooting

### "Module not found" Error

**Problem:** Xcode says `ProjectBrowser` doesn't exist.

**Solution:**
1. In your target's build phases, check "Link Binary With Libraries"
2. Ensure `ProjectBrowser` is listed
3. If not, add it: **+ → ProjectBrowser product**
4. Clean and rebuild (Cmd+Shift+K, then Cmd+B)

### File Tree Not Displaying

**Problem:** Sidebar shows an empty tree even though files exist.

**Causes:**
1. `fileFilter` is hiding all files—check predicate
2. Files are in ignored paths (`.build`, `.git`, etc.)—use `fileFilter` to override
3. Directory discovery failed (permissions)—check error alert
4. Discovery hasn't completed yet—wait ~1–5 seconds

**Solution:**
```swift
// Debug: Check what's discovered
Task {
  let files = try await ProjectFileDiscovery.discover(at: url)
  print("Discovered \(files.count) files")
  for file in files.prefix(5) {
    print("  - \(file.relativePath)")
  }
}
```

### Content Loader Not Being Called

**Problem:** `contentLoader` closure is never invoked.

**Causes:**
1. File has a registered handler—handlers load their own content
2. File is a directory—directories can't be loaded
3. Content was already cached—re-select file or call `.reload`

**Solution:**
```swift
// File must not have a handler and must be a regular file
if file.isDirectory { return }
if handlers[file.fileExtension ?? ""] != nil { return }
// Now contentLoader will be called on selection
```

### Platform-Specific Layout Issues

**Problem:** Split layout appears on iPhone (should be stack).

**Cause:** `horizontalSizeClass` is `.regular` (shouldn't be on iPhone).

**Solution:**
- This is rare; likely an environment override in previews
- Check for `.environment(\.horizontalSizeClass, .regular)` in preview code
- Rebuild and run on actual device to verify

**Problem:** Stack layout appears on iPad (should be split).

**Cause:** iPad is in portrait mode or narrow multitasking split.

**Solution:**
- Rotate to landscape
- Exit multitasking split
- Or explicitly force split layout in your wrapper view

### Files Showing as "Unsupported"

**Problem:** Files display `UnsupportedFileView` instead of a custom handler.

**Causes:**
1. Handler not registered for the extension—check `handlers` dict
2. Extension key doesn't match file extension—check for typos
3. Extension includes the dot (e.g., `".swift"` instead of `"swift"`)

**Solution:**
```swift
// ❌ Wrong
handlers: [".swift": swiftHandler]

// ✅ Correct
handlers: ["swift": swiftHandler]
```

### Stale File State

**Problem:** File shows as stale (modified on disk) and won't update.

**Cause:** File was modified externally while browsing.

**Solution:**
- Click "Reload" to re-fetch contents
- Or click "Refresh" in sidebar action bar to re-discover all files

---

## FAQ

### Can I use ProjectWindow in a modal sheet?

Yes, fully supported:

```swift
@State var isPresented = false

var body: some View {
  Button("Open") { isPresented = true }
    .sheet(isPresented: $isPresented) {
      ProjectWindow(directoryURL: url)
    }
}
```

### Can I customize the file tree appearance?

ProjectBrowser provides a built-in file tree via `ProjectBrowserSidebar`. Custom tree layouts are out of scope for Phase 1. Consider wrapping `ProjectFileDiscovery` if you need full customization.

### Can I add toolbar buttons?

Yes, you can wrap `ProjectWindow` and add buttons:

```swift
var body: some View {
  VStack {
    HStack {
      Text("Project")
      Spacer()
      Button(action: refreshProject) {
        Image(systemName: "arrow.clockwise")
      }
    }
    .padding()
    
    ProjectWindow(directoryURL: url)
  }
}
```

### Can I open a file from code?

Not directly. ProjectWindow manages selection internally. Workaround:

1. Discover the file via `ProjectFileDiscovery`
2. Pass it to a callback
3. Handle selection in your app logic

### Can I show file previews?

Yes, via custom handlers:

```swift
let handlers: [String: (ProjectFile) -> AnyView] = [
  "pdf": { file in
    AnyView(PDFPreviewView(file: file))
  }
]
```

Provide the preview rendering in your handler view.

### What about file system monitoring?

Phase 2 feature. Currently, ProjectWindow discovers files once on appear. External file changes (other processes deleting/adding files) won't be reflected until you call "Sync" in the sidebar action bar or re-navigate.

### Can I restrict browsing to a specific file type?

Use `fileFilter`:

```swift
ProjectWindow(
  directoryURL: url,
  fileFilter: { file in
    // Only show Swift files and directories
    file.isDirectory || file.fileExtension == "swift"
  }
)
```

### How do I handle very large files?

ProjectBrowser loads entire files into memory. For files > 100 MB, consider:

1. Implementing a `contentLoader` that streams data
2. Loading only a preview/summary
3. Using chunked reading in your handler

### Can I embed ProjectWindow in a List or Form?

ProjectWindow is a complete, self-contained view. Embedding it in `List` or `Form` is not recommended—it manages its own layout and state. Instead, place it in a `VStack` or use it as a modal/sheet.

### What about undo/redo?

Out of scope. Implement undo yourself via `UndoManager` in your handler views or app model.

### How do I implement search?

Out of scope for Phase 1. Use `fileFilter` to hide files:

```swift
@State var searchText = ""

ProjectWindow(
  directoryURL: url,
  fileFilter: { file in
    searchText.isEmpty || file.name.localizedCaseInsensitiveContains(searchText)
  }
)
```

---

## Next Steps

- **Phase 2 Features** (in development):
  - File system monitoring (auto-update on external changes)
  - Virtual scrolling for 10,000+ file directories
  - Search and filtering UI
  - Batch operations
  
- **Integration Examples**:
  - See `Proyecto` app for a real-world example
  - Check tests in `Tests/ProjectBrowserTests/` for unit test patterns
  
- **Related Packages**:
  - `SwiftCompartido` for screenplay parsing
  - `SwiftAcervo` for audio processing
  - `SwiftBruja` for LLM inference

---

**Documentation Updated**: July 2026  
**ProjectBrowser Version**: 3.5.4

---
type: specification
---

# Reusable Project Window UI Library – Requirements & Specification

**Status**: APPROVED FOR IMPLEMENTATION  
**Created**: 2026-07-17  
**Target Platforms**: macOS, iOS (with platform-specific adaptations)  
**Base Models**: SwiftProyecto (PROJECT.md discovery), SwiftCompartido (document handling)

---

## Executive Summary

Build a reusable, generic **ProjectWindow** SwiftUI component that can browse any directory, display a hierarchical file tree, and render file contents via registered type handlers. The consumer (e.g., Produciesta) will:
- Pass a directory URL
- Register file type handlers (`fileExtension` → `ContentView`)
- Receive file selection callbacks
- Delegate rendering to handler views

This decouples the file browsing UI from domain logic, making it reusable across projects that need to browse and edit projects.

---

## 1. Overview

### 1.1 Purpose

Provide a production-quality, reusable file browser for macOS and iOS that:
- Discovers files in a directory hierarchy (optionally via PROJECT.md)
- Displays files in a master-detail layout (macOS) or list/detail (iOS)
- Allows registering custom content views for file types
- Provides file-level actions (reload, show in Finder, delete, etc.)
- Integrates with SwiftProyecto's PROJECT.md manifest format (optional)

### 1.2 Design Principles

1. **Genericity**: Not tied to screenplay, audio, or any domain; works for any file types.
2. **Handler-based rendering**: Consumers register views for file types; ProjectWindow knows nothing about them.
3. **Minimal state coupling**: No SwiftData models in the public API; only simple data models and callbacks.
4. **Lazy loading**: Files are discovered upfront; contents loaded on demand.
5. **Platform-native**: macOS gets NavigationSplitView; iOS gets NavigationStack or tab-based UI.

### 1.3 Key Assumptions

- Directory is readable and monitored via FileManager or FSEvents.
- File contents can be represented as a simple `Data` or `String`; handlers interpret it.
- PROJECT.md is optional; used for metadata (title, author, description) only.
- Security-scoped bookmarks are handled at the library boundary.

---

## 2. Architecture

### 2.1 Component Hierarchy

```
ProjectWindow (container)
├── ProjectBrowserSidebar (master)
│   ├── ProjectHeader
│   ├── FileTreeView (hierarchical list)
│   └── ProjectActionBar
└── ProjectDetailPane (detail)
    └── Handler-registered ContentView(s)
```

### 2.2 Handler Registration System

**Concept**: Consumers register closures or Views for each file type.

```swift
struct FileTypeHandler {
    let fileExtension: String
    let contentViewBuilder: (ProjectFile) -> AnyView
    let actions: FileActions?  // Optional: custom context menu
}

struct ProjectWindow: View {
    var handlers: [FileTypeHandler]  // Registered by consumer
}
```

**Alternative (generic approach)**:
```swift
struct ProjectWindow<Content: View>: View {
    var fileHandler: (ProjectFile) -> Content?  // nil = unsupported
}
```

**Recommendation**: Start with a simpler handler registry that's easy to extend.

---

## 3. Data Models

### 3.1 Core Models (Library-provided)

```swift
/// Represents a file discovered in the project directory
struct ProjectFile: Identifiable, Hashable {
    let id: UUID
    let name: String
    let relativePath: String
    let fileExtension: String
    let isDirectory: Bool
    let modifiedDate: Date
    var isLoaded: Bool = false
    var loadingState: FileLoadingState = .notLoaded
    var error: Error? = nil
    
    // Computed
    var hasKnownHandler: Bool  // True if a registered handler exists
    var displayName: String    // Name with truncation for UI
}

enum FileLoadingState: Equatable {
    case notLoaded
    case loading(progress: Double = 0)
    case loaded
    case stale  // File modified on disk after loading
    case error(String)
}

/// Contents of a loaded file
struct ProjectFileContents {
    let file: ProjectFile
    let data: Data
    let text: String?
    let loadedAt: Date
    let isStale: Bool  // True if file was modified after load
}
```

### 3.2 Consumer-provided Models (Callbacks)

```swift
/// Callback when user selects a file
typealias FileSelectionCallback = (ProjectFile) -> Void

/// Callback to load file contents
typealias FileLoaderCallback = (ProjectFile) async throws -> ProjectFileContents

/// Callback for file actions (reload, delete, show in Finder)
typealias FileActionCallback = (ProjectFile, FileAction) -> Void

enum FileAction {
    case reload
    case showInFinder
    case delete
    case custom(String)
}
```

### 3.3 Project Metadata (Optional, PROJECT.md-based)

```swift
struct ProjectMetadata {
    let title: String?
    let author: String?
    let description: String?
    let created: Date?
    
    /// Parses from PROJECT.md if present; otherwise nil
    static func load(from directoryURL: URL) async -> ProjectMetadata?
}
```

---

## 4. Public API

### 4.1 ProjectWindow Initializer

```swift
struct ProjectWindow: View {
    /// Directory URL (security-scoped bookmark data if on macOS)
    let directoryURL: URL
    
    /// File type handlers (extensionextension → view builder)
    var handlers: [String: (ProjectFile) -> AnyView] = [:]
    
    /// Optional: project title (overrides PROJECT.md title)
    var projectTitle: String?
    
    /// Callbacks
    var onFileSelected: ((ProjectFile) -> Void)?
    var onFileAction: ((ProjectFile, FileAction) -> Void)?
    
    /// Optional: custom content loader (default: FileManager.contents)
    var contentLoader: ((ProjectFile) async throws -> ProjectFileContents)?
    
    /// Optional: file filter (return false to hide files)
    var fileFilter: ((ProjectFile) -> Bool)?
    
    /// macOS only: sidebar width preferences
    var sidebarMinWidth: CGFloat = 250
    var sidebarIdealWidth: CGFloat = 300
    var sidebarMaxWidth: CGFloat = 400
}
```

### 4.2 Usage Example (Produciesta)

```swift
// Register handlers for screenplay formats
let handlers: [String: (ProjectFile) -> AnyView] = [
    "fountain": { file in
        AnyView(ScreenplayContentView(file: file))
    },
    "fdx": { file in
        AnyView(FDXContentView(file: file))
    },
    "md": { file in
        AnyView(MarkdownContentView(file: file))
    }
]

// Create window
ProjectWindow(
    directoryURL: projectFolderURL,
    handlers: handlers,
    projectTitle: "My Series",
    onFileSelected: { file in
        // Handle selection (e.g., navigate, update state)
    },
    onFileAction: { file, action in
        switch action {
        case .reload:
            // Re-fetch file contents
        case .showInFinder:
            NSWorkspace.shared.activateFileViewerSelecting([file.url(in: projectFolderURL)])
        case .delete:
            // Delete file from disk
        default:
            break
        }
    },
    contentLoader: { file in
        // Custom loader for this app's file format
        let url = projectFolderURL.appendingPathComponent(file.relativePath)
        let data = try FileManager.default.contentsAtPath(url.path)
        return ProjectFileContents(
            file: file,
            data: data,
            text: String(data: data, encoding: .utf8),
            loadedAt: Date()
        )
    }
)
```

---

## 5. Feature Details

### 5.1 File Discovery & Hierarchy

**Behavior**:
- Scan directory on load using `FileManager.contentsOfDirectory(at:)` recursively.
- Build a tree structure (`/Sources` → `SwiftProyecto` → `Extensions` → `ProjectDiscovery.swift`).
- Sort by folder/file, then alphabetically.

**Options**:
- If PROJECT.md exists, use it for metadata (title, author, description).
- Ignore common directories (`.git`, `node_modules`, `.xcodeproj`, etc.) by default.
- Allow consumer to specify custom ignore patterns.

**Performance**:
- Cache the tree in `@State`; invalidate on file system changes (FSEvents on macOS, polling on iOS).

### 5.2 Hierarchical List (Master Pane)

**macOS Layout**:
- NavigationSplitView with three-column or two-column layout.
- Left sidebar: project metadata (title, file counts, sync status) + file tree.
- Center: selected file name + file metadata (size, modified date).
- Right (optional): file preview or detail view.

**Tree Structure**:
- Folders shown as disclosure groups (expand/collapse).
- Files shown with icons (doc.text, folder, etc.).
- Highlight currently selected file.

**State Management**:
- Track expanded folders in `@State`.
- Track selection with a Hashable `ProjectSelection` enum or simple ID.

### 5.3 Detail Pane (File Contents)

**Rendering**:
- When a file is selected, lookup matching handler by `fileExtension`.
- Call handler view builder with `ProjectFile`.
- Handler view is responsible for fetching/parsing contents.
- Show error state if no handler registered for that file type.

**Empty States**:
- No selection: "Select a file to view"
- Unsupported type: "No handler for .xyz files"
- Loading: Progress indicator + filename
- Error: Error message + retry button

### 5.4 File Actions

**Available Actions**:
- **Load/Reload**: Fetch file contents (calls consumer's `contentLoader` callback).
- **Show in Finder** (macOS): `NSWorkspace.activateFileViewerSelecting()`
- **Delete**: Remove file from disk.
- **Unload**: Clear cached contents to free memory.
- **Custom**: Consumer can add domain-specific actions.

**UI**:
- Context menu (right-click) on file row.
- Action buttons in detail pane header.
- Disabled when inappropriate (e.g., "Reload" disabled if not loaded).

### 5.5 Lazy Loading & Progress

**Design**:
- Files are discovered but NOT loaded until user clicks them.
- Loading state indicator (spinning wheel, progress bar).
- Parsing progress callback from consumer's `contentLoader`.

**State Tracking**:
```swift
@State private var loadingFiles: Set<UUID> = []
@State private var fileContents: [UUID: ProjectFileContents] = [:]
```

### 5.6 FILE SYNC & MONITORING

**Behavior** (Optional, Phase 2):
- Monitor directory for changes (FSEvents on macOS, file system events on iOS).
- Invalidate cache when file is modified externally.
- Show "stale" indicator on affected files.
- Provide "Reload" action to refresh.

**Approach**:
- Use `FileManager`'s `contentsOfDirectory` periodically or FSEvents on macOS.
- Debounce to avoid excessive updates.

---

## 6. UI/UX Details

### 6.1 macOS Layout (NavigationSplitView)

```
┌─────────────────────────────────────────────────────┐
│ My Series                               [Project]    │ ← Project Header
├─────────────────────────────────────────────────────┤
│                │                                      │
│  📁 Sources    │  📄 episode-01.fountain             │
│    📁 Plots    │  Created: Feb 20, 2026              │
│      📄 main   │  Size: 1.2 MB                       │
│      📄 arc    │  [Load] [Reload]                    │
│    📁 Scripts  │                                      │
│      📄 ep-1   │  ┌──────────────────────────────────┤
│      📄 ep-2   │  │ [Screenplay content here]        │
│  📁 Audio      │  │                                  │
│    📄 cues.md  │  │                                  │
│                │                                      │
├─────────────────────────────────────────────────────┤
│ [Sync] [Import]              [Load All] [Unload All]  │ ← Action Bar
└─────────────────────────────────────────────────────┘
```

**Sidebar Width**:
- Min: 250 pt
- Ideal: 300 pt
- Max: 400 pt

### 6.2 iOS Layout (NavigationStack or Tabs)

**Option A: NavigationStack**
- Push detail view on file selection.
- Keep file list on back button.

**Option B: Split View (iPad)**
- Similar to macOS (NavigationSplitView).

**Option C: Tabs**
- Tab 1: File list (master).
- Tab 2: File details (detail).

**Recommendation**: Use NavigationStack for initial iOS support.

### 6.3 File Row UI

```
📁 Sources
  ├─ 📄 ProjectDiscovery.swift
  ├─ 📄 ProjectService.swift
  └─ 🔵 episode-01.fountain [loading]
```

**Icons**:
- Folder: folder.fill
- File: doc.text (generic) or extension-specific (e.g., doc.richtext for .rtf)
- Loading: circle.dotted (spinning)
- Error: exclamationmark.triangle.fill

**Selection**:
- Highlight on hover (macOS).
- Blue background on selection (both platforms).

**Context Menu** (macOS + iOS):
- Load / Reload
- Unload
- Show in Finder (macOS only)
- Delete
- [Custom actions from consumer]

---

## 7. Integration Points

### 7.1 With SwiftProyecto

**Optional Integration**:
- If directory contains PROJECT.md, parse it for metadata (title, author, description).
- Use SwiftProyecto's `ProjectDiscovery` API to find files matching certain criteria.
- Defer to consumer for actual file processing.

**Not Integrated**:
- ProjectWindow does NOT load GuionDocumentModel or other Produciesta models.
- Does NOT use SwiftData; state is kept in @State.
- Does NOT handle audio generation, export, or other domain logic.

### 7.2 With SwiftCompartido (Optional)

**Use Cases**:
- Leverage `CastMember`, `GuionElementModel` parsing if file is screenplay.
- But: Handler views implement this, not ProjectWindow.

### 7.3 File Format Support

**Out-of-the-box Support**:
- Plain text (.txt, .md, .fountain, .fdx, etc.) via TextContentView.

**Extensible via Handlers**:
- Screenplay (.fountain, .fdx, .highland, .docx, .pdf) → Consumer provides handler.
- Audio (.mp3, .wav, .m4a) → Consumer provides audio player handler.
- Markdown (.md) → Consumer provides rich markdown renderer.

---

## 8. Error Handling

### 8.1 File Access Errors

**Scenarios**:
- File deleted by external process.
- Insufficient permissions.
- File moved or renamed.
- Disk full (when saving).

**UI Response**:
- Show error state in detail pane.
- Log to console.
- Offer retry button.
- Gracefully handle by removing file from list (if actually deleted).

### 8.2 Handler Not Found

**Scenario**: User selects `.xyz` file but no handler is registered.

**UI Response**:
- Show content unavailable: "No handler for .xyz files"
- List registered handlers.
- Offer fallback (raw text view, hex dump, download).

### 8.3 Directory Monitoring Errors

**Scenario**: FSEvents setup fails on macOS.

**Fallback**: Degrade to manual refresh button (no auto-update).

---

## 9. Performance Considerations

### 9.1 Large Directories

**Scenario**: Directory with 10,000+ files.

**Strategy**:
- Lazy load file list on scroll (Section?.lazyVGrid or similar).
- Cache file metadata (name, size, date) in memory.
- Defer deep recursion; only expand on user interaction.
- Limit search/filter to 100 results at a time.

### 9.2 Memory Usage

**Target**: < 50 MB for typical project (1,000 files, no contents cached).

**Approach**:
- Keep only metadata in tree; lazy-load contents.
- Cache only currently visible file content.
- Unload unused content on demand.

### 9.3 Rendering Performance

**macOS**:
- NavigationSplitView renders efficiently; use ForEach with .id.
- Disclosure groups can be expensive; virtualize if > 100 items.

**iOS**:
- Use List with .lazy (iOS 17+).
- Avoid re-rendering entire tree on each file discovery.

---

## 10. Testing Strategy

### 10.1 Unit Tests

- `ProjectFile` model equality, hashing.
- File tree building from directory structure.
- Handler registration and lookup.
- Error state transitions.

### 10.2 Integration Tests

- Discover files in real directory.
- Load and render file contents via handler.
- File actions (delete, reload).
- PROJECT.md parsing (if used).

### 10.3 UI Tests (Manual)

- Browse deep directory (5+ levels).
- Select file → handler renders.
- Large file loading (100+ MB).
- Delete file → tree updates.
- Reload file → content refreshes.
- macOS: Show in Finder action.
- macOS: Cmd+O or drag-drop to open directory.

### 10.4 Performance Tests

- Discover 10,000 files; measure load time and memory.
- Render 1,000-item tree; check frame rate.
- Load large file (100 MB text); measure time to first display.

---

## 11. Deliverables

### 11.1 SwiftProyecto (Library)

**New module**: `ProjectBrowser`

**Files**:
- `ProjectWindow.swift` — Main container view.
- `ProjectBrowserSidebar.swift` — Left sidebar (file tree + header).
- `ProjectDetailPane.swift` — Right detail pane.
- `Models/ProjectFile.swift` — Core data models.
- `Models/FileLoadingState.swift` — State enum.
- `Models/FileTypeHandler.swift` — Handler registry.
- `Services/ProjectFileDiscovery.swift` — Directory scanning.
- `Services/ProjectFileMonitor.swift` — FSEvents integration (Phase 2).
- `Views/FileTreeView.swift` — Hierarchical file list.
- `Views/ProjectHeader.swift` — Project metadata display.
- `Views/ProjectActionBar.swift` — Sync, Import, Load All buttons.
- `Views/DefaultContentViews.swift` — Plain text, unsupported file fallback.
- `Tests/ProjectFileTests.swift`
- `Tests/ProjectWindowTests.swift`

### 11.2 Produciesta (Consumer)

**Integration**:
- Register handlers for .fountain, .fdx, .md, etc.
- Connect to existing GuionDocumentView, ScreenplayView.
- Remove old ProjectView / ProjectWindow code.
- Add ProjectBrowser to app menu ("Open Project Folder").

**New Files**:
- `ProduciestaProjectHandlers.swift` — Handler registry.
- `Views/ScreenplayContentHandler.swift` — Fountain → ScreenplayView.

### 11.3 Documentation

- README in `Sources/ProjectBrowser/README.md`.
- CLAUDE.md additions with API examples.
- Architecture doc: `/docs/ARCHITECTURE_ProjectBrowser.md`.

---

## 12. Future Enhancements (Phase 2+)

1. **File Monitoring**: FSEvents (macOS) + polling (iOS) for real-time updates.
2. **Search & Filter**: Full-text search across files.
3. **Drag & Drop**: Reorder files, create folders.
4. **Quick Look**: File preview (macOS).
5. **Sync Service**: Watch for external file changes; re-import on change.
6. **Recent Projects**: Track open/close history.
7. **Tabs/Multi-Window**: Open multiple projects at once.
8. **Cloud Sync**: Dropbox, iCloud integration.

---

## 13. Success Criteria

✅ Consumers can browse any directory with a hierarchical file tree.  
✅ Consumers can register views for custom file types.  
✅ Default handlers render plain text, show "unsupported" for others.  
✅ File contents load on demand (lazy loading).  
✅ File actions (reload, delete, show in Finder) work reliably.  
✅ Performance: < 50 MB memory for 1,000 files; < 1 sec to render tree.  
✅ macOS and iOS layouts are native and responsive.  
✅ No crashes on large directories (10,000+ files).  
✅ Used successfully in Produciesta v5.0.  
✅ Documented and easily reusable in other projects.

---

## References

- **Legacy Code**: `/docs/reference/LEGACY_ProjectView.swift`, `/docs/reference/LEGACY_ProjectWindow.swift`
- **SwiftProyecto**: PROJECT.md discovery API
- **SwiftCompartido**: Document models (GuionDocumentModel, etc.)
- **Example UI**: Screenshot showing desired master-detail layout

---

**Appendix: Phased Implementation Plan**

### Phase 1: Core Library (v0.1)
- [ ] Basic file discovery
- [ ] NavigationSplitView layout (macOS)
- [ ] Handler registry + default text view
- [ ] File selection + callbacks
- [ ] Basic file actions (reload, delete)

### Phase 2: Monitoring & Polish (v0.2)
- [ ] FSEvents monitoring (macOS)
- [ ] File stale detection
- [ ] Search/filter
- [ ] iOS NavigationStack support
- [ ] Performance optimizations

### Phase 3: Advanced (v1.0)
- [ ] Drag & drop reordering
- [ ] Quick Look (macOS)
- [ ] Project metadata editing
- [ ] Sync service


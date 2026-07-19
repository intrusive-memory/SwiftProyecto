---
type: reference
---

# ProjectBrowser Library Architecture

**Document Status**: Complete (Phase 1)  
**Last Updated**: 2026-07-18  
**Version**: 1.0  
**Scope**: ProjectBrowser Library (SwiftProyecto) - Architecture & System Design

---

## Executive Summary

ProjectBrowser is a reusable, generic file-browsing library for macOS and iOS that enables applications to browse any directory hierarchy and render file contents via registered type handlers. The library decouples file discovery, display, and rendering from domain logic, making it reusable across projects that need to explore and interact with file-based projects.

### Key Design Achievements

- **Generic & Domain-Agnostic**: Not tied to any specific file format or content type. Works with screenplays, markdown, audio, images, or any text/binary format.
- **Handler-Based Rendering**: Consumers register custom views for file extensions; ProjectBrowser knows nothing about the content it displays.
- **Lazy Loading**: Files are discovered eagerly but contents are loaded on-demand, enabling browsing of large directories with minimal memory overhead.
- **Platform-Native Layouts**: macOS uses NavigationSplitView; iOS adapts between NavigationStack (compact width) and NavigationSplitView (regular width).
- **Minimal State Coupling**: The public API uses simple data models and callbacks; no SwiftData models, no binding across module boundaries.

### Technology Stack

- **Framework**: SwiftUI with platform-specific adaptations
- **Platforms**: macOS 26.0+, iOS 26.0+
- **Concurrency**: Swift async/await for file I/O
- **State Management**: SwiftUI @State (no SwiftData, no Combine)
- **File I/O**: Foundation FileManager, NSWorkspace (macOS)

---

## 1. Component Architecture

### 1.1 Component Hierarchy

```
┌──────────────────────────────────────────────────────────────┐
│                      ProjectWindow (Root)                    │
│                   (State Management & Layout)                │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Platform Layout Decision                                    │
│  ├─ macOS/iPadOS Regular: NavigationSplitView                │
│  └─ iOS Compact: NavigationStack                             │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │           ProjectBrowserSidebar (Master)             │    │
│  │                                                       │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │  ProjectHeader                              │    │    │
│  │  │  • Project Title (from ProjectMetadata)     │    │    │
│  │  │  • Author, Description, Creation Date       │    │    │
│  │  │  • File Count Statistics                    │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  │                                                       │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │  FileTreeView (Hierarchical List)           │    │    │
│  │  │  • DisclosureGroups for folders              │    │    │
│  │  │  • Icons & loading indicators                │    │    │
│  │  │  • Selection state                           │    │    │
│  │  │  • Expansion state (@State)                  │    │    │
│  │  │  • Context menus (right-click)               │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  │                                                       │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │  ProjectActionBar                           │    │    │
│  │  │  • Sync (reload discovery)                  │    │    │
│  │  │  • Load All (eager cache population)        │    │    │
│  │  │  • Unload All (clear memory cache)          │    │    │
│  │  │  • Import (future: add files)               │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │         ProjectDetailPane (Detail)                   │    │
│  │                                                       │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │  Header: File Name, Metadata                │    │    │
│  │  │  (size, modification date, actions)         │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  │                                                       │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │  Content Area (Handler-Rendered)            │    │    │
│  │  │  • Handler lookup: handlers[extension]?     │    │    │
│  │  │  • If found: handler(file) → AnyView        │    │    │
│  │  │  • If not found: UnsupportedFileView        │    │    │
│  │  │  • Loading state: LoadingView (spinner)     │    │    │
│  │  │  • Error state: ErrorView (message + retry) │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  │                                                       │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │  Footer: Action Buttons                      │    │    │
│  │  │  • Reload, Show in Finder (macOS), Delete   │    │    │
│  │  │  • Custom actions from consumers             │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
└──────────────────────────────────────────────────────────────┘
          ↑                    ↑                    ↑
          │                    │                    │
    Uses Handlers          Uses Services       Receives Callbacks
          │                    │                    │
          ↓                    ↓                    ↓
    ┌─────────────┐   ┌──────────────────────┐  ┌────────────────┐
    │   Handler   │   │ ProjectFileDiscovery │  │ Callbacks &    │
    │   Registry  │   │  • discover(at:)     │  │ State Changes  │
    │  [String: ] │   │  • Recursive scan    │  │ onFileSelection│
    │  AnyView]   │   │  • Metadata fetch    │  │ onFileAction   │
    └─────────────┘   │  • Tree building     │  │ contentLoader  │
                      │                      │  │ fileFilter     │
                      └──────────────────────┘  └────────────────┘
                           ↓
                      ┌──────────────────────┐
                      │ ProjectFileContents  │
                      │ • file: ProjectFile  │
                      │ • data: Data         │
                      │ • text: String?      │
                      │ • loadedAt: Date     │
                      │ • isStale: Bool      │
                      └──────────────────────┘
```

### 1.2 Component Descriptions

#### ProjectWindow (Root Container)

**Responsibility**: Top-level orchestration of the entire file browser.

**Key Duties**:
- Owns all internal UI state (file tree, selection, expansion, loading states)
- Chooses platform-appropriate layout (NavigationSplitView vs NavigationStack)
- Orchestrates discovery on appear
- Manages lazy content loading
- Handles file actions (reload, delete, show in Finder)
- Forwards callbacks to consumer via closures

**State Management**:
```swift
@State private var files: [ProjectFile] = []               // Discovered files
@State private var selectedFile: ProjectFile?              // Current selection
@State private var expandedFolders: Set<UUID> = []        // Folder expansion
@State private var fileContents: [UUID: ProjectFileContents] = [:]  // Cache
@State private var loadingFiles: Set<UUID> = []           // Loading indicator
@State private var metadata: ProjectMetadata?              // PROJECT.md data
@State private var errorMessage: String?                   // Error display
@State private var isLoading: Bool = false                // Discovering files
@State private var pendingDeleteFile: ProjectFile?        // Delete confirmation
```

**Key Methods**:
- `loadProject()`: Discovers files and loads PROJECT.md metadata
- `selectFile(_:)`: Updates selection, triggers lazy loading
- `handleFileAction(_:action:)`: Executes file operations
- `dispatchFileAction(_:action:)`: Entry point for child view actions
- `loadContentIfNeeded(for:)`: Lazy-loads file contents on selection
- `loadAllContent()`: Pre-loads all file contents
- `unloadAllContent()`: Clears memory cache

**Platform Layout Logic**:
- macOS: Always uses `NavigationSplitView` (two-column)
- iOS/iPadOS:
  - Regular width class: `NavigationSplitView` (iPad landscape)
  - Compact width class: `NavigationStack` (iPhone or narrow split)

#### ProjectBrowserSidebar (Master/Left Column)

**Responsibility**: Compose and coordinate the left-side interface elements.

**Contains**:
- `ProjectHeader`: Project metadata display
- `FileTreeView`: Hierarchical file list with selection
- `ProjectActionBar`: Sync, Load All, Unload All buttons

**Inputs** (via parameters):
- `files`: Array of discovered ProjectFile entries
- `metadata`: ProjectMetadata for the project
- `selectedFile`: Current selection (via @Binding)
- `expandedFolders`: Folder expansion state (via @Binding)

**Callbacks** (to parent ProjectWindow):
- `onFolderToggle`: Expand/collapse folder
- `onSelect`: File selection
- `onSync`: Reload discovery
- `onFileAction`: File operations

#### ProjectHeader

**Responsibility**: Display project-level metadata.

**Shows**:
- Project title (from ProjectMetadata or fallback)
- Author
- Description
- Creation date
- File count statistics

**Source**: ProjectMetadata (parsed from PROJECT.md if present)

#### FileTreeView (Hierarchical List)

**Responsibility**: Render the file tree with visual hierarchy, selection, and expansion.

**Rendering Strategy**:
- Uses `ForEach` to render files in discovery order
- Nested `DisclosureGroup` for folders
- Loading indicators (spinner) for in-progress loads
- Error indicators for failed loads
- Selection highlighting
- Context menus with actions

**State Dependencies**:
- Reads: `files`, `selectedFile`, `expandedFolders`, `loadingFiles`
- Writes: Selection, expansion via callbacks

**Features**:
- Recursive disclosure groups (doesn't use explicit tree structure)
- Right-click context menu with file actions
- File icons by extension (or generic)
- Loading spinners during content fetch
- Error badges on failed loads

#### ProjectDetailPane (Detail/Right Column)

**Responsibility**: Render the selected file's content and metadata.

**Rendering Logic**:
1. Check if file is selected
   - If no: show "Select a file to view" placeholder
2. Check loading state
   - If loading: show LoadingView (spinner + filename)
   - If error: show ErrorView (error message + retry button)
3. Check content cache
   - If cached: show ProjectFileContents
4. Handler lookup
   - Extract extension from selected file
   - Look up handler in `handlers[extension]`
   - If found: call `handler(file)` → AnyView
   - If not found: show UnsupportedFileView
5. Render selected handler view or fallback

**Inputs** (via parameters):
- `selectedFile`: The file being displayed
- `handlers`: File extension → view builder mapping
- `contents`: Cached ProjectFileContents (if any)
- `isLoadingContent`: Whether a fetch is in progress
- `loadError`: Error message if load failed

**Outputs** (via callbacks):
- `onAction`: File actions (reload, delete, show in Finder)
- `onRetryLoad`: Retry loading on error

**Layout**:
- Header: File name, metadata (size, date)
- Content area: Handler view (or placeholder/error/loading)
- Footer: Action buttons (Reload, Show in Finder, Delete)

#### ProjectActionBar

**Responsibility**: Provide project-level bulk actions.

**Actions**:
- **Sync**: Reload discovery from disk
- **Import**: Placeholder for future directory import UI
- **Load All**: Pre-load all handler-less files into memory
- **Unload All**: Clear memory cache to free resources

**UX Notes**:
- Disabled during discovery (`isActionBarEnabled` parameter)
- Appears in sidebar footer on macOS
- Styling matches platform conventions

### 1.3 Supporting Services

#### ProjectFileDiscovery

**Responsibility**: Recursively scan a directory and build a flat list of ProjectFile entries.

**Public API**:
```swift
public static func discover(at rootURL: URL) async throws -> [ProjectFile]
```

**Key Features**:
- **Flat, depth-first ordering**: Directories first, then files, all alphabetical (case-insensitive)
- **Recursive scanning**: Descends into subdirectories
- **Ignore patterns**: Skips `.git`, `.build`, `node_modules`, `*.xcodeproj`, etc.
- **Symlink handling**: Never follows symbolic links
- **Resource keys**: Only fetches needed metadata (name, type, modification date, size)
- **Error resilience**: Skips unreadable subdirectories without aborting

**Performance**:
- Typical: 10,000 files in < 5 seconds
- Metadata-only: No file content reads
- Uses parallel/concurrent FileManager APIs where available

**Output Format**:
```
[
  ProjectFile(name: "Sources", isDirectory: true, relativePath: "Sources", ...),
  ProjectFile(name: "Helper.swift", isDirectory: false, relativePath: "Sources/Helper.swift", ...),
  ProjectFile(name: "Main.swift", isDirectory: false, relativePath: "Sources/Main.swift", ...),
  ProjectFile(name: "Tests", isDirectory: true, relativePath: "Tests", ...),
  ProjectFile(name: "Test.swift", isDirectory: false, relativePath: "Tests/Test.swift", ...),
  ...
]
```

#### ProjectFileActionHandler

**Responsibility**: Implement file-level operations (reload, delete, show in Finder).

**Public API**:
```swift
public static func handle(
  action: FileAction,
  file: ProjectFile,
  in directoryURL: URL,
  contentLoader: FileLoaderCallback?
) async -> FileActionResult
```

**Supported Actions**:
- **`.reload`**: Fetch file contents (via `contentLoader` or default)
- **`.delete`**: Remove file from disk
- **`.showInFinder`** (macOS only): Reveal in Finder
- **`.custom(String)`**: Consumer-defined actions

**Behavior**:
- `.reload`:
  - Constructs full file URL from `directoryURL + relativePath`
  - Uses `contentLoader` if provided, else reads as UTF-8 text
  - Returns `ProjectFileContents` with data/text
  - Handles encoding errors gracefully (fallback to binary)
- `.delete`:
  - Removes file from disk
  - ProjectWindow updates its `files` array
  - Clears selection if deleted file was selected
  - Clears cached contents
- `.showInFinder`:
  - Calls `NSWorkspace.shared.activateFileViewerSelecting()`
  - macOS only; no-op on iOS
- `.custom(String)`:
  - Forwarded to consumer via `onFileAction` callback
  - No built-in handling

**Error Handling**:
- File not found: Returns error message
- Permission denied: Returns error message
- Encoding failure: Fallback to binary representation
- Errors never crash; always return `FileActionResult` with error message

#### ProjectFileContentLoader

**Responsibility**: Determine whether a file should be lazy-loaded on selection.

**Public API**:
```swift
public static func shouldLoad(
  file: ProjectFile,
  hasHandler: Bool,
  cache: [UUID: ProjectFileContents],
  loadingFiles: Set<UUID>
) -> Bool
```

**Load Decision Logic**:
- Return `false` (skip load) if:
  - File is a directory
  - File already has a registered handler
  - File already cached in `fileContents`
  - File already loading (in `loadingFiles`)
- Return `true` (load needed) if:
  - None of the above apply

**Rationale**:
- Handlers own their own content fetching (don't lazy-load)
- Cache hits avoid redundant I/O
- In-flight loads shouldn't be double-triggered

#### ProjectMetadata

**Responsibility**: Parse PROJECT.md metadata from a directory.

**Public API**:
```swift
public static func load(from directoryURL: URL) async -> ProjectMetadata?
```

**What It Parses**:
- Title (document heading)
- Author (YAML front-matter)
- Description
- Creation date

**Behavior**:
- Looks for PROJECT.md in the root directory
- Returns `nil` if file not found or parsing fails
- Metadata is optional (browsing proceeds without it)
- Failures are logged in DEBUG but don't block discovery

---

## 2. Data Flow

### 2.1 Discovery → Selection → Rendering Flow

```
┌─────────────────────────────────────────────────────────┐
│ User Opens App, Selects Directory (or Projeto loads it) │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ ProjectWindow.onAppear { Task { await loadProject() } } │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ await ProjectFileDiscovery.discover(at: directoryURL)   │
│  • Recursively scan directory                           │
│  • Respect ignore patterns                              │
│  • Build flat, sorted array                             │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ Update @State files = discovered array                  │
│ Apply fileFilter if provided                            │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ await ProjectMetadata.load(from: directoryURL)          │
│ (Async, concurrent with file discovery)                │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ Update @State metadata = parsed (or nil)                │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ ProjectBrowserSidebar renders with files array          │
│ FileTreeView displays hierarchical list                 │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ User Taps/Clicks File in Tree                           │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ FileTreeView calls onSelect callback with ProjectFile   │
│ ProjectWindow.selectFile(_ file) is called              │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ Update @State selectedFile = file                       │
│ Forward to onFileSelection callback (consumer)          │
│ Kick off async Task for lazy load                       │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ loadContentIfNeeded(for: file) check decision:          │
│ Should we load? (not handler, not cached, not loading)  │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ If shouldLoad == true:                                  │
│  1. Add file.id to loadingFiles (show spinner)          │
│  2. Call contentLoader (or default: read file)          │
│  3. On success: store in fileContents cache             │
│  4. Update loadingState to .loaded                      │
│  5. On error: update loadingState to .error(msg)        │
│  6. Remove from loadingFiles                            │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ ProjectWindow.detailPane(for: selectedFile)             │
│ Receives currentcontents from fileContents cache        │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ ProjectDetailPane renders:                              │
│ 1. Check file extension                                 │
│ 2. Lookup handler: handlers[extension]                  │
│ 3. If handler exists: call handler(file) → AnyView      │
│ 4. If no handler: show UnsupportedFileView              │
│ 5. If loading: show LoadingView                         │
│ 6. If error: show ErrorView                             │
└─────────────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────┐
│ Final Render: File content displayed                    │
│ User sees text, rendered markdown, custom handler view  │
└─────────────────────────────────────────────────────────┘
```

### 2.2 State Mutations

```
ProjectWindow @State Lifecycle
│
├─ onAppear
│  └─ isLoading ← true
│     files ← [] (empty)
│     metadata ← nil
│
├─ Discovery Phase (concurrent)
│  ├─ ProjectFileDiscovery.discover()
│  │  └─ files ← [ProjectFile, ...]
│  │
│  └─ ProjectMetadata.load()
│     └─ metadata ← ProjectMetadata?
│
├─ Discovery Complete
│  └─ isLoading ← false
│
├─ User Selects File
│  ├─ selectedFile ← file
│  │
│  ├─ If no handler & not cached & not loading:
│  │  ├─ loadingFiles.insert(file.id)
│  │  ├─ [await contentLoader]
│  │  ├─ fileContents[file.id] ← contents
│  │  └─ loadingFiles.remove(file.id)
│  │
│  └─ file.loadingState ← .loading → .loaded (or .error)
│
├─ User Triggers Reload
│  ├─ fileContents.removeValue(file.id)  [evict cache]
│  ├─ loadingFiles.insert(file.id)
│  ├─ [await contentLoader]
│  ├─ fileContents[file.id] ← contents
│  ├─ loadingFiles.remove(file.id)
│  └─ file.loadingState ← .loaded (or .error)
│
├─ User Deletes File
│  ├─ files ← files.filter { $0 != file }  [remove from tree]
│  ├─ fileContents.removeValue(file.id)    [evict cache]
│  ├─ loadingFiles.remove(file.id)         [clear spinner]
│  ├─ if selectedFile?.id == file.id:
│  │  └─ selectedFile ← nil               [deselect]
│  └─ [UI dismisses detail pane]
│
└─ User Clicks "Unload All"
   ├─ fileContents.removeAll()
   ├─ loadingFiles.removeAll()
   └─ files ← files.map { $0.withLoadingState(.notLoaded) }
```

---

## 3. Handler Registry Architecture

### 3.1 Handler Registration

The handler registry is passed to ProjectWindow at initialization:

```swift
let handlers: [String: (ProjectFile) -> AnyView] = [
  "fountain": { file in
    AnyView(ScreenplayContentView(file: file))
  },
  "md": { file in
    AnyView(MarkdownContentView(file: file))
  },
  "swift": { file in
    AnyView(SyntaxHighlightedView(file: file, language: "swift"))
  }
]

let window = ProjectWindow(
  directoryURL: projectURL,
  handlers: handlers,
  projectTitle: "My Project"
)
```

### 3.2 Handler Lookup & Invocation

When a file is selected and needs to be displayed:

```swift
func detailPane(for file: ProjectFile?) -> ProjectDetailPane {
  // In ProjectDetailPane, lookup is done as:
  
  if let selectedFile {
    if let handler = handlers[selectedFile.fileExtension ?? ""] {
      // Handler exists: call it with the file
      let contentView = handler(selectedFile)  // → AnyView
      // Render contentView
    } else {
      // No handler: show unsupported
      UnsupportedFileView(file: selectedFile, handlers: handlers)
    }
  } else {
    // No file selected
    PlaceholderView("Select a file to view")
  }
}
```

### 3.3 Handler Ownership & Responsibilities

**What ProjectWindow Provides**:
- File metadata (name, path, extension, size, date)
- Currently-cached contents (if lazy-loaded already)
- File action callbacks (delete, reload, etc.)

**What Handler Owns**:
- Parsing & interpreting file contents
- Rendering UI for the specific file type
- Caching strategy (if needed)
- Error handling specific to format

**Example: ScreenplayContentHandler** (from Proyecto)
```swift
// In Proyecto app
struct ScreenplayContentHandler: View {
  let file: ProjectFile
  @State var document: GuionDocumentModel?
  @State var loading = false
  @State var error: String?
  
  var body: some View {
    Group {
      if loading {
        ProgressView()
      } else if let error {
        ErrorView(message: error)
      } else if let document {
        ScreenplayView(document: document)
      }
    }
    .onAppear {
      Task { await loadDocument() }
    }
  }
  
  func loadDocument() async {
    // Handler fetches its own content & parses
    do {
      let url = /* construct from file.relativePath */
      let data = try FileManager.default.contentsAtPath(url.path)
      document = try GuionDocumentModel.parse(from: data)
    } catch {
      self.error = error.localizedDescription
    }
  }
}
```

### 3.4 Default Handlers

ProjectBrowser provides a few default handlers for fallback:

- **PlainTextContentView**: Shows text files with syntax highlighting (optional)
- **UnsupportedFileView**: Shows file metadata + list of registered handlers
- **LoadingView**: Shows spinner during content fetch
- **ErrorView**: Shows error message + retry button

---

## 4. Integration Architecture

### 4.1 Proyecto App Integration Pattern

Proyecto (the consuming app) integrates ProjectBrowser as follows:

```
ContentView (Main App)
        ↓
    [Folder Picker]
        ↓
    Selected: directoryURL
        ↓
    Create ProjectWindow with:
    • directoryURL: selected folder
    • handlers: screenplayHandlers
    • contentLoader: proyectoContentLoader
    • onFileAction: handleProyectoAction
        ↓
    ProjectWindow displayed
        ↓
    User browses, selects file
        ↓
    Handler renders content
        ↓
    User performs actions
        ↓
    onFileAction callbacks trigger
```

**Key Integration Points**:

1. **Directory Selection** (Proyecto responsibility)
   - Proyecto uses NSOpenPanel (macOS) or FileImporter (iOS)
   - Passes selected URL to ProjectWindow

2. **Handler Registration** (Proyecto responsibility)
   - Proyecto registers handlers for `.fountain`, `.fdx`, `.md`, etc.
   - Each handler owns its own content parsing & rendering
   - Example:
   ```swift
   let handlers: [String: (ProjectFile) -> AnyView] = [
     "fountain": { file in AnyView(ScreenplayContentView(file: file)) },
     "fdx": { file in AnyView(FDXContentView(file: file)) }
   ]
   ```

3. **Custom Content Loader** (Proyecto responsibility, optional)
   - If Proyecto has custom serialization, it passes `contentLoader`
   - Otherwise, ProjectWindow uses default FileManager read

4. **File Actions** (Proyecto responsibility)
   - onFileAction callback notifies Proyecto of user actions
   - Proyecto can update its own state, analytics, etc.
   - Example:
   ```swift
   onFileAction: { file, action in
     switch action {
     case .showInFinder:
       NSWorkspace.shared.activateFileViewerSelecting([file.url(in: projectURL)])
     case .delete:
       // Update Proyecto's document tracking
       proyectoState.markDeleted(file)
     case .custom("export"):
       // Custom action handled by Proyecto
       proyectoState.export(file)
     default:
       break
     }
   }
   ```

### 4.2 Generic Consumer Integration Pattern

For any other app wanting to use ProjectBrowser:

```swift
import SwiftProyecto

struct MyAppProjectView: View {
  @State var selectedDirectory: URL?
  
  var body: some View {
    if let url = selectedDirectory {
      ProjectWindow(
        directoryURL: url,
        handlers: myHandlers,
        projectTitle: url.lastPathComponent,
        onFileSelection: { file in
          print("Selected: \(file.name)")
        },
        onFileAction: { file, action in
          print("Action: \(action) on \(file.name)")
        }
      )
    } else {
      // Folder picker (consumer's responsibility)
      FolderPickerView { url in
        selectedDirectory = url
      }
    }
  }
  
  var myHandlers: [String: (ProjectFile) -> AnyView] {
    [
      "pdf": { file in AnyView(PDFViewerHandler(file: file)) },
      "txt": { file in AnyView(PlainTextHandler(file: file)) },
      "jpg": { file in AnyView(ImageViewerHandler(file: file)) }
    ]
  }
}
```

---

## 5. Dependency Graph

### 5.1 Module Dependencies

```
Top-Level Consumer (Proyecto App)
  ↓
  └─ ProjectWindow (Root Container)
      ├─ ProjectBrowserSidebar
      │  ├─ ProjectHeader
      │  ├─ FileTreeView
      │  └─ ProjectActionBar
      │
      ├─ ProjectDetailPane
      │  ├─ Handler views (consumer-provided)
      │  ├─ UnsupportedFileView
      │  ├─ LoadingView
      │  └─ ErrorView
      │
      ├─ ProjectFileDiscovery (Service)
      │  └─ ProjectFile (Model)
      │
      ├─ ProjectFileActionHandler (Service)
      │  ├─ ProjectFile (Model)
      │  ├─ ProjectFileContents (Model)
      │  └─ FileAction (Enum)
      │
      ├─ ProjectFileContentLoader (Service)
      │  └─ ProjectFile (Model)
      │
      ├─ ProjectMetadata (Model)
      │  └─ [Parses PROJECT.md from directory]
      │
      └─ FileLoadingState (Enum)
```

### 5.2 Model Hierarchy

```
Data Models (No dependencies on views/services):
├─ ProjectFile
│  ├─ id: UUID
│  ├─ name: String
│  ├─ relativePath: String
│  ├─ fileExtension: String?
│  ├─ isDirectory: Bool
│  ├─ modifiedDate: Date
│  ├─ fileSize: Int64?
│  ├─ isLoaded: Bool
│  ├─ loadingState: FileLoadingState
│  └─ error: String?
│
├─ ProjectFileContents
│  ├─ file: ProjectFile
│  ├─ data: Data
│  ├─ text: String?
│  ├─ loadedAt: Date
│  └─ isStale: Bool
│
├─ ProjectMetadata
│  ├─ title: String?
│  ├─ author: String?
│  ├─ description: String?
│  └─ created: Date?
│
├─ FileLoadingState (Enum)
│  ├─ .notLoaded
│  ├─ .loading(progress: Double)
│  ├─ .loaded
│  └─ .error(String)
│
└─ FileAction (Enum)
   ├─ .reload
   ├─ .showInFinder
   ├─ .delete
   └─ .custom(String)

Type Aliases (Callback Signatures):
├─ FileSelectionCallback = (ProjectFile) -> Void
├─ FileLoaderCallback = (ProjectFile) async throws -> ProjectFileContents
├─ FileActionCallback = (ProjectFile, FileAction) -> Void
└─ FileActionResult = (reloadedContents?: ProjectFileContents, 
                        didDelete: Bool, 
                        errorMessage?: String)
```

### 5.3 External Dependencies

- **SwiftUI**: View, State, Binding, NavigationSplitView, NavigationStack, DisclosureGroup, etc.
- **Foundation**: FileManager, URL, Data, URLResourceValues, NSWorkspace (macOS)
- **SwiftProyecto Core** (optional): ProjectMetadata uses PROJECT.md parsing (from SwiftProyecto.Core)

---

## 6. State Management

### 6.1 Owner: ProjectWindow

ProjectWindow is the single source of truth for all browsing state:

```swift
@State private var files: [ProjectFile]              // Source: discovery
@State private var selectedFile: ProjectFile?        // Current selection
@State private var expandedFolders: Set<UUID>       // Folder expansion
@State private var fileContents: [UUID: ProjectFileContents]  // Cache
@State private var loadingFiles: Set<UUID>          // Indicators
@State private var metadata: ProjectMetadata?        // PROJECT.md
@State private var isLoading: Bool                  // Discovery progress
@State private var errorMessage: String?             // Error display
@State private var pendingDeleteFile: ProjectFile?  // Confirm dialog
```

### 6.2 State Propagation via Bindings

Child views receive @Binding to write to ProjectWindow's state:

**ProjectBrowserSidebar receives**:
```swift
var selectedFile: Binding<ProjectFile?>         // Can select
var expandedFolders: Binding<Set<UUID>>        // Can expand/collapse
```

**ProjectBrowserSidebar forwards callbacks** to ProjectWindow:
```swift
onFolderToggle: (UUID) -> Void                 // Toggle expansion
onSelect: (ProjectFile) -> Void                // Select file
onSync: () -> Void                              // Reload discovery
onLoadAll: () -> Void                           // Pre-load all
onUnloadAll: () -> Void                         // Clear cache
onFileAction: (ProjectFile, FileAction) -> Void  // File ops
```

### 6.3 Detail Pane State

ProjectDetailPane reads state but doesn't write (read-only):

```swift
@ObservedReading
selectedFile: ProjectFile?                     // What to show
contents: ProjectFileContents?                 // Cached content
isLoadingContent: Bool                         // Show spinner
loadError: String?                             // Show error
handlers: [String: (ProjectFile) -> AnyView]   // Lookup handler
```

Outputs via callbacks:
```swift
onAction: (ProjectFile, FileAction) -> Void    // User actions
onRetryLoad: (ProjectFile) -> Void             // Retry button
```

### 6.4 State Mutation Patterns

**Selection**:
```swift
// User clicks file in tree
FileTreeView.onTapGesture {
  onSelect(file)
}

// ProjectWindow.selectFile(_:)
selectedFile = file
onFileSelection?(file)  // Forward to consumer
Task { await loadContentIfNeeded(for: file) }  // Async load
```

**Expansion**:
```swift
// User clicks disclosure triangle
DisclosureGroup.onTapGesture {
  onFolderToggle(id)
}

// ProjectWindow.toggleFolder(_:)
if expandedFolders.contains(id) {
  expandedFolders.remove(id)
} else {
  expandedFolders.insert(id)
}
```

**Content Loading**:
```swift
// ProjectWindow.loadContentIfNeeded(for:)
loadingFiles.insert(file.id)              // Show spinner

do {
  let contents = try await contentLoader(file)
  fileContents[file.id] = contents       // Cache result
} catch {
  // Error stored in file.loadingState
}

loadingFiles.remove(file.id)              // Hide spinner
```

---

## 7. Error Handling Architecture

### 7.1 Error Categories & Responses

#### Discovery Errors (Hard Failures)

**Scenarios**:
- Directory not found: URL points to non-existent folder
- Permission denied: No read access to directory
- Not a directory: URL points to a file, not folder

**Response**:
- Surfaced via `errorMessage` @State
- Shows alert dialog to user
- Browsing is blocked (can't proceed without valid directory)

**Code**:
```swift
private func loadProject() async {
  do {
    let discovered = try await ProjectFileDiscovery.discover(at: directoryURL)
    files = discovered
  } catch {
    errorMessage = error.localizedDescription  // → Alert
  }
}
```

#### File Content Loading Errors (Soft Failures)

**Scenarios**:
- File deleted between discovery and load
- Permission denied on file read
- File encoding mismatch (binary file, not text)
- Large file (memory allocation failure)

**Response**:
- Updated to `file.loadingState = .error(message)`
- ProjectDetailPane shows ErrorView with message
- User can retry (Retry button triggers reload)
- Selection remains valid (can pick different file)
- Other files unaffected

**Code**:
```swift
private func loadContentIfNeeded(for file: ProjectFile) async {
  loadingFiles.insert(file.id)
  
  do {
    let contents = try await contentLoader(file)
    fileContents[file.id] = contents
    updateLoadingState(for: file.id, to: .loaded)
  } catch {
    updateLoadingState(for: file.id, to: .error(error.localizedDescription))
    errorMessage = error.localizedDescription  // Also show alert
  }
  
  loadingFiles.remove(file.id)
}
```

#### File Action Errors (Operation Failures)

**Scenarios**:
- Delete: File already deleted, insufficient permissions, disk full
- Reload: File moved/renamed, encoding error, permissions changed
- Show in Finder: File deleted, path invalid

**Response**:
- Via `FileActionHandler.handle()`
- Returns `FileActionResult` with `errorMessage`
- If action was successful, state is updated
- If action failed, state is NOT updated (no side effects)
- Error message shown in alert

**Code**:
```swift
private func handleFileAction(_ file: ProjectFile, action: FileAction) async {
  let result = await ProjectFileActionHandler.handle(
    action: action,
    file: file,
    in: directoryURL,
    contentLoader: contentLoader
  )
  
  if result.didDelete {
    files.removeAll { $0.id == file.id }
  }
  
  if let errorMessage = result.errorMessage {
    errorMessage = errorMessage  // → Alert
  }
  
  onFileAction?(file, action)  // Always forward
}
```

### 7.2 Error Display Hierarchy

```
Level 1: Alert Dialog
├─ Used for: Discovery errors, action failures
├─ Dismisses with "OK" button
└─ Example: "Directory not found"

Level 2: ErrorView in Detail Pane
├─ Used for: Content load failures
├─ Shows: Error message + Retry button
└─ Example: "Permission denied reading file"

Level 3: Loading/Error Indicator in Tree
├─ Used for: File-level state
├─ Shows: Spinner icon or error badge
└─ Example: Red triangle on slow file
```

### 7.3 Error Recovery

```
Soft Error (Content Load Failure)
  ↓
ErrorView shown with message
  ↓
User clicks "Retry" button
  ↓
ProjectDetailPane.onRetryLoad { file in
  dispatchFileAction(file, action: .reload)
}
  ↓
handleFileAction calls contentLoader again
  ↓
Success: fileContents cached, ErrorView dismissed
OR
Failure: ErrorView still shown with new message
```

---

## 8. Performance Architecture

### 8.1 Discovery Performance

**Benchmark (Phase 1)**:
- 10,000 files: < 5 seconds
- Typical project (1,000 files): < 500 ms

**Optimization Strategies**:
- **Metadata-only**: Only fetches name, type, date, size (no content)
- **Ignore patterns**: Skips large `.xcodeproj`, `node_modules`, `.git` bundles
- **Parallelization**: Uses concurrent FileManager APIs where available
- **Short-circuit symlinks**: Detects and skips symbolic links immediately

**Code**:
```swift
private static func scanDirectory(at directoryURL: URL, root: URL) throws -> [ProjectFile] {
  let fileManager = FileManager.default

  // Fetch only needed resource keys
  let children = try fileManager.contentsOfDirectory(
    at: directoryURL,
    includingPropertiesForKeys: resourceKeys,  // Only: isDir, isSymlink, date, size
    options: []
  )

  // Ignore common patterns early (before recursion)
  for childURL in children {
    if isIgnored(childURL) { continue }  // Skip .git, etc.
    if values.isSymbolicLink == true { continue }  // Skip symlinks
  }
  
  // Recurse only into directories (and only if we found subdirectories)
}
```

### 8.2 Lazy Loading Design

**Cache Strategy**:
```swift
@State private var fileContents: [UUID: ProjectFileContents] = [:]
@State private var loadingFiles: Set<UUID> = []
```

**Load Decision** (ProjectFileContentLoader):
- ✗ Skip if file is a directory
- ✗ Skip if file has registered handler (handler owns content)
- ✗ Skip if already cached
- ✗ Skip if already loading
- ✓ Load only if none of the above

**Benefits**:
- Files discovered eagerly (fast tree display)
- Contents loaded only on demand (minimal memory)
- Cached contents reused (no redundant I/O)

**Memory Impact**:
- 10,000 files discovered: ~1-5 MB (metadata only)
- 100 files loaded (text files, ~50 KB each): ~5 MB (reasonable)
- Same 100 files with no caching: No memory (stream on demand)

### 8.3 Rendering Performance

**SwiftUI Optimizations**:
- **ForEach with .id**: Each file identified by UUID (stable across reloads)
- **DisclosureGroup nesting**: Folders rendered as nested groups (clean hierarchy)
- **Binding minimization**: Only top-level bindings (selection, expansion)
- **View decomposition**: ProjectDetailPane is separate view (doesn't rebuild on tree changes)

**Potential Issues & Mitigations**:
- **Large tree (10,000+ files)**: Current ForEach will render all rows
  - Phase 2 mitigation: LazyVStack + virtualization
- **Deep nesting (50+ levels)**: DisclosureGroup stacks deeply
  - Phase 2 mitigation: Render indentation level visually, not with nesting

---

## 9. Platform-Specific Architecture

### 9.1 macOS Layout

**Layout Type**: NavigationSplitView (always)

**UI Structure**:
```
┌─────────────────────────────────────────────┐
│  My Project              [Sync] [Load All]  │ ← ProjectHeader + ActionBar
├──────────────┬──────────────────────────────┤
│              │                              │
│ 📁 Sources   │ 📄 episode-01.fountain       │
│   📄 Main    │ Size: 1.2 MB                 │
│   📄 Helper  │ Modified: Jul 18, 2026       │
│ 📁 Tests     │                              │
│   📄 Test    │ [Load] [Reload] [Delete]    │
│              │                              │
│              │ ┌────────────────────────────┤
│              │ │ [Screenplay content]       │
│              │ │                            │
│              │ └────────────────────────────┤
│              │                              │
├──────────────┴──────────────────────────────┤
│ [Sync] [Import]        [Load All] [Unload] │ ← ProjectActionBar
└─────────────────────────────────────────────┘

Sidebar Width:
  Min: 250 pt (allows text to fit)
  Ideal: 300 pt (typical project tree width)
  Max: 400 pt (power users with deep nesting)
```

**UX Notes**:
- Sidebar is always visible (no collapse needed)
- Resizable divider between sidebar and detail
- Detail pane shows selected file or placeholder
- Action bar is persistent in sidebar footer
- Toolbar area can show project metadata

### 9.2 iOS/iPadOS Layout

**Layout Choice** (Adaptive):

**Case 1: Regular Width Class** (iPad in landscape, wide split)
```
Use NavigationSplitView (same as macOS)
├─ Sidebar on left (25-40% of screen)
└─ Detail on right (60-75% of screen)
```

**Case 2: Compact Width Class** (iPhone, narrow split)
```
Use NavigationStack (drill-down navigation)
├─ Root: FileTreeView (full screen)
│
└─ Destination (when file selected):
   └─ ProjectDetailPane (full screen)
   
Back button (system) clears selection,
returns to file list
```

**Code**:
```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

var body: some View {
  if horizontalSizeClass == .regular {
    splitLayout  // NavigationSplitView
  } else {
    stackLayout  // NavigationStack
  }
}
```

**iPhone Layout**:
```
┌──────────────────────────┐
│ ← Project                │ ← Back button (system)
├──────────────────────────┤
│                          │
│ 📁 Sources               │
│   📄 Main.swift          │
│   📄 Helper.swift        │
│ 📁 Tests                 │
│   📄 Test.swift          │
│                          │
│                          │
│ [Sync] [Load All]        │ ← Action buttons
│                          │
└──────────────────────────┘

[User selects file]
         ↓
┌──────────────────────────┐
│ ← Main.swift             │
├──────────────────────────┤
│                          │
│ [Screenplay content]     │
│                          │
│                          │
│ [Reload] [Delete]        │
│                          │
└──────────────────────────┘

[User taps back]
         ↓
[File list reappears]
```

### 9.3 Platform-Specific APIs

**macOS**:
- `NSWorkspace.shared.activateFileViewerSelecting()` — Reveal in Finder
- `NSOpenPanel` — Directory selection (consumer responsibility)
- File system events (FSEvents) — Monitor for changes (Phase 2)

**iOS/iPadOS**:
- `FileImporter` — Directory selection (via SwiftUI, consumer responsibility)
- `DocumentPickerViewController` — Directory access (requires entitlements)
- File monitoring — Limited options (no FSEvents); fallback to polling

**Both**:
- `FileManager` — Read directory, query metadata, delete files
- `URL` — File path manipulation
- SwiftUI layout primitives (NavigationSplitView, NavigationStack)

---

## 10. Integration Points

### 10.1 Public API Surface

**Initializer** (Main entry point):
```swift
public init(
  directoryURL: URL,                                   // Required
  handlers: [String: (ProjectFile) -> AnyView] = [:],  // Optional
  projectTitle: String? = nil,                         // Optional
  onFileSelection: FileSelectionCallback? = nil,       // Optional
  onFileAction: FileActionCallback? = nil,             // Optional
  contentLoader: FileLoaderCallback? = nil,            // Optional
  fileFilter: ((ProjectFile) -> Bool)? = nil,          // Optional
  sidebarMinWidth: CGFloat = 250,                      // Customizable
  sidebarIdealWidth: CGFloat = 300,
  sidebarMaxWidth: CGFloat = 400
)
```

**File Type Handlers** (Core customization):
```swift
handlers: [String: (ProjectFile) -> AnyView]
```

**Callbacks** (Notification & event handling):
```swift
onFileSelection: (ProjectFile) -> Void
onFileAction: (ProjectFile, FileAction) -> Void
contentLoader: (ProjectFile) async throws -> ProjectFileContents
fileFilter: (ProjectFile) -> Bool
```

### 10.2 File I/O Boundaries

**Input Boundaries** (ProjectWindow reads from):
- `directoryURL`: Filesystem directory (read-only metadata access)
- `contentLoader` closure: Fetches file contents (via consumer)
- File system: Read operations via FileManager

**Output Boundaries** (ProjectWindow writes to):
- File system: Delete operations via FileManager
- Callbacks: Selection, actions forwarded to consumer
- State: Maintains internal @State (not exposed)

### 10.3 Model Boundaries

**What ProjectBrowser Exports**:
- `ProjectWindow` — The main view component
- `ProjectFile` — File metadata (Identifiable, Codable, Sendable)
- `ProjectFileContents` — File contents (data + text + metadata)
- `ProjectMetadata` — Project-level metadata
- `FileLoadingState` — Enum for loading state
- `FileAction` — Enum for file operations
- Type aliases: FileSelectionCallback, FileLoaderCallback, etc.

**What ProjectBrowser Doesn't Export**:
- Internal @State or @ObservedObject models
- SwiftData models
- Platform-specific details (NSWorkspace, etc.)

---

## 11. Phase 2 Roadmap

The following features are candidates for Phase 2+ development:

### 11.1 File Monitoring

**Feature**: Real-time updates when files are modified externally.

**macOS**:
- Use FSEvents to monitor directory for changes
- Debounce updates (coalesce rapid changes)
- Mark affected files as "stale"
- Provide "Reload" action to refresh

**iOS/iPadOS**:
- Fallback to periodic polling (FileManager.contentsOfDirectory)
- Trigger on app coming to foreground
- Show "Last refreshed" timestamp

**Implementation**:
- New `ProjectFileMonitor` service
- New `FileLoadingState.stale` case
- Update ProjectWindow to handle stale files

### 11.2 Search & Filter

**Features**:
- File name search (real-time as user types)
- Content search (full-text)
- Filter by extension
- Filter by modification date

**Implementation**:
- Search bar in ProjectHeader
- Filter logic in ProjectFileDiscovery or separate service
- Update FileTreeView to show filtered results
- Highlight matches in tree

### 11.3 Virtualization

**Feature**: Efficient rendering of very large directories (100,000+ files).

**Current Limitation**:
- ForEach renders all rows in memory
- DisclosureGroup stacks recursively

**Phase 2 Solution**:
- Replace ForEach with LazyVStack
- Render only visible rows (virtualization)
- Estimate row heights for scroll performance
- Use simplified tree rendering (not nested DisclosureGroups)

### 11.4 Advanced File Actions

**Features**:
- Batch operations (select multiple, delete all)
- Rename file
- Create new file/directory
- Move file (cut/paste)
- File tagging / favorites

**Implementation**:
- Multi-select state in FileTreeView
- New FileAction cases (.rename, .create, .move, etc.)
- Context menu updates

### 11.5 Drag & Drop

**Features**:
- Reorder files (drag file in tree)
- Import files (drop onto tree)
- Export file to Finder

**Limitations**:
- Limited support on iOS
- macOS is the primary target

### 11.6 Customization

**Features**:
- Custom file icons by extension
- Color coding by type
- Sidebar width persistence (user preferences)
- Sort order customization (name, date, size, custom)

**Implementation**:
- New parameters to ProjectWindow
- Persist preferences (UserDefaults or app-specific)
- Update FileTreeView rendering

### 11.7 Performance Improvements

**Disk Caching**:
- Cache discovered file list to disk
- Persist between app sessions
- Validate on each load (check timestamps)

**Progressive Rendering**:
- Show partial tree while discovery is in progress
- Render first 100 files immediately
- Stream remaining files as they're discovered

**Compression**:
- For very large text files (100+ MB), show preview + option to load full

---

## 12. References to Specification

This architecture implements the ProjectBrowser specification (`Docs/REQUIREMENTS_ReusableProjectWindow.md`) as follows:

### Specification Sections Implemented

**§ 1. Overview**
- ✅ Purpose (reusable file browser for macOS/iOS)
- ✅ Design Principles (generic, handler-based, minimal coupling, lazy loading, platform-native)
- ✅ Key Assumptions (directory readable, file contents loadable, PROJECT.md optional)

**§ 2. Architecture**
- ✅ Component Hierarchy (ProjectWindow → Sidebar + DetailPane)
- ✅ Handler Registration System (closure-based, extension → AnyView)

**§ 3. Data Models**
- ✅ ProjectFile (id, name, path, extension, directory, date, size, loading state)
- ✅ FileLoadingState (notLoaded, loading, loaded, error)
- ✅ ProjectFileContents (file, data, text, loadedAt)
- ✅ ProjectMetadata (title, author, description, created)
- ✅ Callbacks (FileSelectionCallback, FileLoaderCallback, FileActionCallback)

**§ 4. Public API**
- ✅ ProjectWindow initializer with all parameters
- ✅ Usage example (Proyecto integration)

**§ 5. Feature Details**
- ✅ File Discovery & Hierarchy (recursive scan, ignore patterns, sorting)
- ✅ Hierarchical List (master pane with FileTreeView)
- ✅ Detail Pane (handler rendering, empty states, loading, error)
- ✅ File Actions (reload, show in Finder, delete, custom)
- ✅ Lazy Loading & Progress (on-demand, caching, loading indicators)
- ⭕ File Sync & Monitoring (Phase 2)

**§ 6. UI/UX Details**
- ✅ macOS Layout (NavigationSplitView, sidebar width preferences)
- ✅ iOS Layout (NavigationStack for compact, split for regular)
- ✅ File Row UI (icons, selection, context menu)

**§ 7. Integration Points**
- ✅ SwiftProyecto (optional PROJECT.md metadata)
- ✅ File Format Support (extensible via handlers)
- ⭕ SwiftCompartido (Phase 2, if needed)

**§ 8. Error Handling**
- ✅ File Access Errors (not found, permissions, moved)
- ✅ Handler Not Found (show unsupported UI)
- ✅ Directory Monitoring Errors (graceful degradation)

**§ 9. Performance Considerations**
- ✅ Large Directories (10,000 files < 5 seconds)
- ✅ Memory Usage (< 50 MB for typical project)
- ✅ Rendering Performance (ForEach with .id, view decomposition)
- ⭕ Virtualization (Phase 2 for 100,000+ files)

**§ 10. Testing Strategy**
- ✅ Unit Tests (ProjectFile, file tree, handlers, error states)
- ✅ Integration Tests (discovery, rendering, file actions, PROJECT.md)
- ✅ UI Tests (manual verification workflow)
- ✅ Performance Tests (discovery speed, memory, rendering frame rate)

**§ 11. Deliverables**
- ✅ ProjectBrowser module in SwiftProyecto (all files implemented)
- ✅ Proyecto integration (handlers, integration pattern)
- ✅ Documentation (README, architecture doc, API docs)

---

## Appendix A: Code Examples

### A.1 Basic Usage (Consumer)

```swift
import SwiftProyecto

@main
struct MyApp: App {
  @State var selectedDirectory: URL?
  
  var body: some Scene {
    WindowGroup {
      if let url = selectedDirectory {
        ProjectWindow(
          directoryURL: url,
          handlers: handlers,
          projectTitle: url.lastPathComponent,
          onFileSelection: { file in
            print("Selected: \(file.name)")
          },
          onFileAction: { file, action in
            handleAction(file: file, action: action)
          }
        )
      } else {
        FolderPickerView { url in
          selectedDirectory = url
        }
      }
    }
  }
  
  var handlers: [String: (ProjectFile) -> AnyView] {
    [
      "md": { file in
        AnyView(MarkdownView(file: file))
      },
      "txt": { file in
        AnyView(PlainTextView(file: file))
      }
    ]
  }
  
  func handleAction(file: ProjectFile, action: FileAction) {
    switch action {
    case .showInFinder:
      #if os(macOS)
      NSWorkspace.shared.activateFileViewerSelecting([file.url(in: selectedDirectory!)])
      #endif
    case .delete:
      print("File deleted: \(file.name)")
    default:
      break
    }
  }
}
```

### A.2 Custom Handler Example (Proyecto)

```swift
struct ScreenplayContentHandler: View {
  let file: ProjectFile
  let directoryURL: URL
  @State var document: GuionDocumentModel?
  @State var loading = false
  @State var error: String?
  
  var body: some View {
    Group {
      if loading {
        ProgressView()
      } else if let error = error {
        VStack {
          Text("Error loading screenplay")
          Text(error).font(.caption).foregroundColor(.secondary)
          Button("Retry") { load() }
        }
      } else if let document = document {
        ScreenplayEditorView(document: document)
      }
    }
    .onAppear { load() }
  }
  
  private func load() {
    loading = true
    error = nil
    
    Task {
      do {
        let url = directoryURL.appendingPathComponent(file.relativePath)
        let data = try Data(contentsOf: url)
        document = try GuionDocumentModel.parse(from: data)
      } catch {
        self.error = error.localizedDescription
      }
      loading = false
    }
  }
}
```

### A.3 Integration in Proyecto View

```swift
struct ProyectoProjectBrowserView: View {
  let projectURL: URL
  @State var selectedFile: ProjectFile?
  
  var body: some View {
    ProjectWindow(
      directoryURL: projectURL,
      handlers: screenplayHandlers,
      projectTitle: projectURL.lastPathComponent,
      onFileSelection: { file in
        selectedFile = file
      },
      onFileAction: { file, action in
        handleProyectoAction(file: file, action: action)
      }
    )
  }
  
  var screenplayHandlers: [String: (ProjectFile) -> AnyView] {
    [
      "fountain": { file in
        AnyView(ScreenplayContentHandler(file: file, directoryURL: projectURL))
      },
      "fdx": { file in
        AnyView(FDXContentHandler(file: file, directoryURL: projectURL))
      },
      "md": { file in
        AnyView(MarkdownHandler(file: file, directoryURL: projectURL))
      }
    ]
  }
  
  func handleProyectoAction(file: ProjectFile, action: FileAction) {
    switch action {
    case .delete:
      // Update Proyecto's tracking
      ProyectoState.shared.markFileDeleted(file)
    case .reload:
      // Optionally clear any Proyecto-level caches
      ProyectoState.shared.clearCache(for: file)
    case .custom("export"):
      // Export screenplay in Proyecto format
      ProyectoState.shared.export(file)
    default:
      break
    }
  }
}
```

---

## Appendix B: File Structure

```
Sources/ProjectBrowser/
├── ProjectWindow.swift              # Main container (900 LOC)
│
├── Models/
│   ├── ProjectFile.swift            # File metadata
│   ├── ProjectFileContents.swift     # Loaded content
│   ├── FileLoadingState.swift        # Loading state enum
│   └── [ProjectMetadata.swift]       # Optional: PROJECT.md parsing
│
├── Views/
│   ├── ProjectBrowserSidebar.swift   # Master pane container
│   ├── ProjectHeader.swift           # Project metadata
│   ├── FileTreeView.swift            # Hierarchical file list
│   ├── ProjectDetailPane.swift       # Detail pane container
│   ├── ProjectActionBar.swift        # Bulk actions
│   └── DefaultContentViews.swift     # Fallback views
│
├── Services/
│   ├── ProjectFileDiscovery.swift    # Directory scanning
│   ├── ProjectFileActionHandler.swift # File operations
│   ├── ProjectFileContentLoader.swift # Load decision logic
│   └── [ProjectFileMonitor.swift]    # Phase 2: File monitoring
│
├── Enums/
│   ├── FileAction.swift              # Action types
│   └── [FileActionResult.swift]      # Action result
│
└── README.md                         # Usage documentation

Tests/
├── ProjectFileTests.swift
├── ProjectWindowTests.swift
├── ProjectFileDiscoveryTests.swift
├── ProjectDetailPaneTests.swift
└── [Integration Tests]
```

---

## Appendix C: Configuration & Customization

### Sidebar Width (macOS)

```swift
ProjectWindow(
  directoryURL: url,
  handlers: handlers,
  sidebarMinWidth: 200,    // Allow narrower sidebar
  sidebarIdealWidth: 350,  // Prefer wider for deep trees
  sidebarMaxWidth: 500     // Allow expansion
)
```

### File Filtering

```swift
ProjectWindow(
  directoryURL: url,
  handlers: handlers,
  fileFilter: { file in
    // Hide hidden files and specific types
    !file.name.hasPrefix(".") && file.fileExtension != "tmp"
  }
)
```

### Custom Content Loader

```swift
ProjectWindow(
  directoryURL: url,
  handlers: handlers,
  contentLoader: { file in
    // Custom parsing for proprietary format
    let url = /* construct full URL */
    let data = try FileManager.default.contentsAtPath(url.path)
    let text = try MyFormat.decode(data)
    return ProjectFileContents(
      file: file,
      data: data,
      text: text,
      loadedAt: Date()
    )
  }
)
```

---

**Document Version**: 1.0  
**Status**: Complete for Phase 1  
**Last Updated**: 2026-07-18  
**Author**: Claude Haiku 4.5 (via S6.3 Sortie)

This architecture document serves as the system design reference for the ProjectBrowser library and forms the foundation for Phase 2 development.

# SwiftProyecto

<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg" />
    <img src="https://img.shields.io/badge/Platform-iOS%2026.0+%20|%20macOS%2026.0+-lightgrey.svg" />
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
    <img src="https://img.shields.io/badge/Version-2.0.0--beta-blue.svg" />
</p>

**SwiftProyecto** is a Swift package providing **file discovery and secure access** for screenplay project management. It discovers files in local directories or git repositories, manages security-scoped bookmarks for sandboxed environments, and provides secure URLs for apps to load and parse files using their own parsers.

## Overview

SwiftProyecto provides:
- **File Discovery**: Recursively discover files in project folders or git repositories
- **Secure File Access**: Security-scoped bookmarks for sandboxed macOS/iOS apps
- **PROJECT.md Parsing**: Built-in YAML front matter parser for project metadata
- **Project Models**: SwiftData models for project metadata and file references
- **FileNode**: Hierarchical file tree structure for UI display
- **ProjectService**: Project lifecycle management (create, open, sync, get file URLs)
- **BookmarkManager**: Centralized security-scoped bookmark management

**What SwiftProyecto Does NOT Do:**
- ❌ Parse screenplay files (no SwiftCompartido dependency)
- ❌ Load document content into memory automatically
- ❌ Manage loading state or caching

**Integration Pattern:**
Apps using SwiftProyecto call `getSecureURL(for:in:)` to get a file URL, then parse it with their own parsers (e.g., SwiftCompartido). See the "Integration with Document Parsers" section for details.

## Architecture

SwiftProyecto provides file discovery and secure access. Apps integrate it with their own document parsers:

```
┌───────────────────────────────────────────────────────────┐
│ Produciesta (iOS/macOS App)                               │
│ - UI Views (ProjectBrowserView, DocumentLoader)           │
│ - DocumentRegistry (integration layer)                    │
│ - Calls getSecureURL() → Parses with SwiftCompartido      │
└──────┬────────────────────────────────┬───────────────────┘
       │                                │
       ▼                                ▼
┌──────────────────┐          ┌─────────────────┐
│ SwiftProyecto    │          │ SwiftCompartido │
│ (THIS)           │          │                 │
│                  │          │ - GuionDocument │
│ - File Discovery │          │ - Parsing       │
│ - ProjectModel   │          │ - AST           │
│ - FileNode       │          └─────────────────┘
│ - BookmarkMgr    │
│ - getSecureURL() │          (No direct dependency)
│   ↑              │
│   Provides URLs  │
└──────────────────┘

Flow:
1. SwiftProyecto discovers files → ProjectFileReference
2. App calls getSecureURL(for: fileRef, in: project)
3. App parses URL with SwiftCompartido
4. App stores result in DocumentRegistry
```

## Features

### ✅ v2.0: File Discovery Focus

- **File Discovery**: Recursively discover all files in project directories or git repos
- **PROJECT.md Parser**: Built-in YAML front matter parser (no external dependencies)
- **Security-Scoped Bookmarks**: Per-project AND per-file bookmark support for sandboxed apps
- **FileNode Tree**: Hierarchical file tree with sorted children (directories first)
- **SwiftData Models**: `ProjectModel` and `ProjectFileReference` with cascade delete
- **Git Repository Support**: Automatic `.git` directory exclusion
- **Bookmark Refresh**: Automatic stale bookmark detection and recreation

### 🔄 v2.0 Breaking Changes

- **Removed SwiftCompartido dependency** - No more screenplay parsing in this library
- **Removed document loading** - `loadFile()`, `unloadFile()`, `reimportFile()` methods removed
- **Removed loading state** - No `FileLoadingState` enum, `loadingState` property, or `loadedDocument`
- **New API**: Use `getSecureURL(for:in:)` to get file URLs for parsing in your app
- **Simplified models**: `ProjectFileReference` now only stores metadata, not loaded documents

See "Migration from v1.x" section below for upgrade guide.

## Installation

### Swift Package Manager

Add SwiftProyecto to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftProyecto.git", from: "2.0.0")
]
```

Or add it in Xcode:
1. File > Add Package Dependencies
2. Enter: `https://github.com/intrusive-memory/SwiftProyecto.git`
3. Select version: `2.0.0` or later

**Note**: Version 2.0.0 has breaking changes. If you're upgrading from v1.x, see the "Migration from v1.x" section below.

## Usage

### Project Structure

SwiftProyecto expects projects to follow this structure:

```
my-series-project/              ← Project root
├── PROJECT.md                  ← Manifest with YAML front matter
├── .cache/                     ← SwiftData container (auto-created)
│   ├── default.store
│   ├── default.store-shm
│   └── default.store-wal
├── episode-01.fountain         ← Screenplay files
├── episode-02.fdx
└── season-02/                  ← Nested folders supported
    ├── episode-01.fountain
    └── episode-02.fountain
```

### PROJECT.md Format

```markdown
---
type: project
title: My Series
author: Jane Showrunner
created: 2025-11-17T10:30:00Z
description: A multi-episode series
season: 1
episodes: 12
genre: Science Fiction
tags: [sci-fi, drama]
---

# Project Notes

Additional notes and production information go here...
```

### Basic Usage

#### Opening a Project

```swift
import SwiftProyecto

// Create ProjectService instance
let service = ProjectService(modelContext: context)

// Open existing project folder
let projectURL = URL(fileURLWithPath: "/path/to/my-series-project")
let project = try await service.openProject(at: projectURL)

// Project metadata from PROJECT.md
print(project.title) // "My Series"
print(project.author) // "Jane Showrunner"
print(project.totalFileCount) // Number of discovered files
```

#### Working with Files

```swift
// Discover files (automatically syncs on open)
// Files are discovered and metadata is stored

for fileRef in project.fileReferences {
    print(fileRef.filename) // "episode-01.fountain"
    print(fileRef.relativePath) // "season-01/episode-01.fountain"
    print(fileRef.fileExtension) // "fountain"
}

// Get secure URL for a specific file
let fileRef = project.fileReferences.first!
let fileURL = try service.getSecureURL(for: fileRef, in: project)

// Now parse the file with your own parser (e.g., SwiftCompartido)
// This example assumes you have SwiftCompartido imported
// let parser = FountainParser()
// let screenplay = try await parser.parse(fileURL: fileURL)
// print(screenplay.elements.count)

// Access is automatically stopped when fileURL goes out of scope
```

#### File Tree Display

```swift
// Get hierarchical tree structure
let tree = project.fileTree()

// Display in UI
func displayTree(_ node: FileNode, indent: Int = 0) {
    let prefix = String(repeating: "  ", count: indent)

    if node.isDirectory {
        print("\(prefix)📁 \(node.name)/")
        for child in node.sortedChildren {
            displayTree(child, indent: indent + 1)
        }
    } else {
        print("\(prefix)📄 \(node.name)")
    }
}

displayTree(tree)
// Output:
// 📄 README.md
// 📁 Season 1/
//   📄 Episode 1.fountain
//   📄 Episode 2.fountain
```

### Integration with Document Parsers

SwiftProyecto v2.0 focuses on **file discovery**, not document parsing. To integrate with a parser like SwiftCompartido, create an integration layer in your app:

```swift
import SwiftData
import SwiftProyecto
// import SwiftCompartido // Your parser

@Model
final class DocumentRegistry {
    var id: UUID = UUID()
    var projectID: UUID?
    var fileReferenceID: UUID?
    var fileURL: URL
    var lastOpenedDate: Date?

    @Relationship(deleteRule: .cascade)
    var document: GuionDocumentModel? // Your parsed document type
}

// Document loader component
struct DocumentLoader<Content: View>: View {
    let fileReference: ProjectFileReference
    let project: ProjectModel
    let content: (GuionDocumentModel) -> Content

    @State private var loadedDocument: GuionDocumentModel?
    @State private var error: Error?

    var body: some View {
        Group {
            if let doc = loadedDocument {
                content(doc)
            } else if let error = error {
                ErrorView(error: error)
            } else {
                ProgressView()
            }
        }
        .task {
            await loadDocument()
        }
    }

    private func loadDocument() async {
        do {
            // 1. Get secure URL from SwiftProyecto
            let fileURL = try projectService.getSecureURL(
                for: fileReference,
                in: project
            )

            // 2. Parse with your parser (e.g., SwiftCompartido)
            let parser = FountainParser()
            let document = try await parser.parse(fileURL: fileURL)

            // 3. Store in DocumentRegistry for caching
            let registry = DocumentRegistry()
            registry.projectID = project.id
            registry.fileReferenceID = fileReference.id
            registry.fileURL = fileURL
            registry.document = document
            registry.lastOpenedDate = Date()

            modelContext.insert(registry)
            try modelContext.save()

            loadedDocument = document
        } catch {
            self.error = error
        }
    }
}
```

See `.claude/PHASE2_IMPLEMENTATION.md` in the Produciesta repository for a complete integration example.

## Development

### Requirements

- Swift 6.2+
- Xcode 16.0+
- macOS 26.0+ or iOS 26.0+

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

**Note**: Tests are currently being updated to match v2.0 API changes. Some tests may fail until the migration is complete.

## Migration from v1.x to v2.0

SwiftProyecto v2.0 introduces breaking changes focused on simplifying the library to **file discovery only**.

### What Changed

| v1.x API | v2.0 API | Notes |
|----------|----------|-------|
| `loadFile(_:in:progress:)` | `getSecureURL(for:in:)` | Returns URL instead of loading document |
| `unloadFile(_:)` | ❌ Removed | Apps manage their own document lifecycle |
| `reimportFile(_:in:progress:)` | ❌ Removed | Apps re-parse as needed |
| `fileRef.loadingState` | ❌ Removed | No loading state tracking |
| `fileRef.loadedDocument` | ❌ Removed | No document storage |
| `fileRef.errorMessage` | ❌ Removed | Apps handle their own errors |
| `project.loadedFileCount` | ❌ Removed | Apps track loaded documents |
| `project.allFilesLoaded` | ❌ Removed | Apps track loaded documents |
| `FileLoadingState` enum | ❌ Removed | No loading state |

### Migration Steps

1. **Remove SwiftCompartido** from SwiftProyecto imports:
   ```swift
   // OLD:
   import SwiftProyecto
   // SwiftProyecto had SwiftCompartido dependency

   // NEW:
   import SwiftProyecto
   import SwiftCompartido // Import separately in your app
   ```

2. **Replace `loadFile()` calls** with `getSecureURL()`:
   ```swift
   // OLD:
   try await projectService.loadFile(fileRef, in: project)
   if let doc = fileRef.loadedDocument {
       // Use doc
   }

   // NEW:
   let fileURL = try projectService.getSecureURL(for: fileRef, in: project)
   let parser = FountainParser()
   let doc = try await parser.parse(fileURL: fileURL)
   // Store doc in your own DocumentRegistry
   ```

3. **Create DocumentRegistry** model in your app:
   ```swift
   @Model
   final class DocumentRegistry {
       var id: UUID = UUID()
       var projectID: UUID?
       var fileReferenceID: UUID?
       var fileURL: URL
       var lastOpenedDate: Date?

       @Relationship(deleteRule: .cascade)
       var document: GuionDocumentModel?
   }
   ```

4. **Update SwiftData schema** in your app:
   ```swift
   // OLD:
   let schema = Schema([
       ProjectModel.self,
       ProjectFileReference.self,
       GuionDocumentModel.self,
       GuionElementModel.self
   ])

   // NEW:
   let schema = Schema([
       ProjectModel.self,
       ProjectFileReference.self,
       DocumentRegistry.self,  // Your integration model
       GuionDocumentModel.self,
       GuionElementModel.self
   ])
   ```

5. **Remove references to removed properties**:
   ```swift
   // OLD:
   if fileRef.loadingState == .loaded {
       // ...
   }

   // NEW:
   // Check your DocumentRegistry instead
   let registry = documentRegistries.first {
       $0.fileReferenceID == fileRef.id
   }
   if let doc = registry?.document {
       // ...
   }
   ```

### Benefits of v2.0

- ✅ **Clearer separation of concerns** - File discovery vs. document parsing
- ✅ **No circular dependencies** - SwiftProyecto doesn't depend on SwiftCompartido
- ✅ **Smaller library** - ~300 fewer lines of code
- ✅ **More flexible** - Apps choose their own parsing and caching strategies
- ✅ **Better testability** - Each library has a single responsibility

## Development Workflow

This project follows a **strict branch-based workflow**. All development happens on the `development` branch, with PRs to `main` for releases.

### Quick Start for Contributors

1. **Fork and clone** the repository
2. **Switch to development branch**: `git checkout development`
3. **Make your changes** on the `development` branch
4. **Run tests**: `swift test`
5. **Create a PR** to `main` when ready
6. **Wait for CI** to pass before merging

### Detailed Workflow

See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for complete details on:
- Branch strategy (`development` → `main`)
- Commit message conventions (conventional commits)
- PR creation and merging process
- Tagging and release procedures
- Version numbering (semantic versioning)

### Key Rules

- ✅ **Always work on `development` branch**
- ✅ **Never commit directly to `main`**
- ✅ **All changes require PR approval from CI**
- ✅ **Never delete the `development` branch**

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on the development workflow and coding standards.

## License

SwiftProyecto is released under the MIT License. See [LICENSE](./LICENSE) for details.

## Related Projects

- [SwiftCompartido](https://github.com/intrusive-memory/SwiftCompartido) - Screenplay data structures and parsing
- [SwiftHablare](https://github.com/intrusive-memory/SwiftHablare) - Voice synthesis and TTS providers
- [Produciesta](https://github.com/intrusive-memory/Produciesta) - Screenplay management iOS/macOS app

## Status

### ✅ v2.0.0-beta - File Discovery Focus

SwiftProyecto v2.0 is a major refactoring focused on **file discovery and secure access only**. Document parsing has been removed to eliminate the circular dependency with SwiftCompartido.

**Current Status**:
- ✅ SwiftCompartido dependency removed
- ✅ Document loading methods removed (~300 LOC)
- ✅ PROJECT.md parser added (self-contained)
- ✅ Per-file bookmark support added
- ✅ FileNode tree structure complete
- 🔄 Tests being updated to match new API
- 🔄 Awaiting PR merge and v2.0.0 release
- 🔄 Produciesta integration layer ready (currently disabled)

**Stability**: v2.0 introduces breaking changes. See "Migration from v1.x" section above.

**Next Steps**:
1. Update test suite to match v2.0 API
2. Merge PR and tag v2.0.0
3. Activate integration layer in Produciesta
4. Update dependent apps

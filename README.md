# SwiftProyecto

<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg" />
    <img src="https://img.shields.io/badge/Platform-iOS%2026.0+%20|%20macOS%2026.0+-lightgrey.svg" />
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
    <img src="https://img.shields.io/badge/Version-0.5.0-blue.svg" />
</p>

**SwiftProyecto** is a Swift package providing a file source abstraction layer for screenplay project management. It offers flexible file access through protocols, supporting both local directories and git repositories with security-scoped bookmarks for sandboxed environments.

## Overview

SwiftProyecto provides:
- **FileSource Protocol**: Abstraction for different file storage backends (directories, git repos)
- **DirectoryFileSource**: Local folder access with security-scoped bookmarks
- **GitRepositoryFileSource**: Git repository support with `.git` detection
- **ProjectService**: Project lifecycle management (create, open, sync, load files)
- **BookmarkManager**: Centralized security-scoped bookmark management
- **FileNode**: Hierarchical file tree structure for UI display
- **Project Models**: SwiftData models for project metadata and file references
- **File State Tracking**: Monitor loaded, unloaded, stale, and missing files

## Architecture

SwiftProyecto sits between SwiftCompartido (data structures & parsing) and Produciesta (UI layer):

```
┌─────────────────────────────────────────────────────────┐
│ Produciesta (iOS/macOS App)                             │
│ - UI Views (ProjectView, FileTreeView)                  │
│ - SwiftUI integration                                   │
└─────────────────┬───────────────────────────────────────┘
                  │
        ┌─────────┴──────────┬──────────────────┐
        │                    │                  │
┌───────▼────────┐  ┌────────▼────────┐  ┌─────▼──────┐
│ SwiftProyecto  │  │ SwiftCompartido │  │ SwiftHablare│
│ (THIS)         │  │                 │  │             │
│                │  │ - GuionDocument │  │ - Voice Gen │
│ - FileSource   │  │ - Parsing       │  │ - Providers │
│ - ProjectModel │  │ - PROJECT.md    │  └─────────────┘
│ - FileNode     │  │   Parser        │
│ - Bookmark     │  │                 │
│   Manager      │  │                 │
│ - Project      │  │                 │
│   Service      │  │                 │
└────────────────┘  └─────────────────┘
```

## Features

### ✅ Core Refactoring (Phases 1-5 Complete)

#### Phase 1: BookmarkManager Extraction
- [x] Extract centralized `BookmarkManager` utility
- [x] Remove iOS-specific code (iCloudProjectSupport, SingleFileManager)
- [x] Consolidate bookmark operations
- [x] 21 tests for BookmarkManager (100% passing)

#### Phase 2: FileSource Protocol
- [x] Define `FileSource` protocol for file access abstraction
- [x] Implement `DirectoryFileSource` for local folders
- [x] Security-scoped bookmark integration
- [x] File discovery and content reading
- [x] 20 tests for DirectoryFileSource (100% passing)

#### Phase 3: Git Repository Support
- [x] Implement `GitRepositoryFileSource` with `.git` detection
- [x] Git-aware file filtering (ignore `.git/` directory)
- [x] Full FileSource protocol compliance
- [x] 22 tests for GitRepositoryFileSource (100% passing)

#### Phase 4: Service Layer Refactor
- [x] Rename `ProjectManager` → `ProjectService`
- [x] Remove hard-coded file filtering (.fountain, .fdx)
- [x] Return all discovered files (let consumer filter)
- [x] Update ProjectModel to use FileSource
- [x] 20 tests for ProjectService (100% passing)

#### Phase 5: File Tree Helper
- [x] Create `FileNode` struct for hierarchical display
- [x] Tree building from flat file references
- [x] Navigation methods (findNode, allFiles, allDirectories)
- [x] Add `ProjectModel.fileTree()` convenience method
- [x] Sorted children support (directories first)
- [x] 22 tests for FileNode (100% passing)

### Test Coverage
- **177 total tests** (171 passing, 6 pre-existing failures in ModelContainerFactory)
- **~95% code coverage** for refactored components
- All FileSource, ProjectService, and FileNode tests: 100% passing

## Installation

### Swift Package Manager

Add SwiftProyecto to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftProyecto.git", from: "0.1.0")
]
```

Or add it in Xcode:
1. File > Add Package Dependencies
2. Enter: `https://github.com/intrusive-memory/SwiftProyecto.git`
3. Select version: `0.1.0` or later

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
// Files are discovered but NOT loaded until explicitly requested

for fileRef in project.fileReferences {
    print(fileRef.filename) // "episode-01.fountain"
    print(fileRef.loadingState) // .notLoaded
}

// Load a specific file on demand
let fileRef = project.fileReferences.first!
try await service.loadFile(fileRef, in: project)

// Now the screenplay is loaded
if let screenplay = fileRef.loadedDocument {
    print(screenplay.elements.count) // Access parsed content
}
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

#### Using FileSource Directly

```swift
// Direct directory access
let dirSource = DirectoryFileSource(
    url: projectURL,
    name: "My Project"
)

// Discover all files
let files = try await dirSource.discoverFiles()

// Read a specific file
let content = try await dirSource.readFile(at: "episode-01.fountain")

// Git repository support
if let gitSource = try? GitRepositoryFileSource(url: repoURL, name: "Repo") {
    let files = try await gitSource.discoverFiles() // Excludes .git/
}
```

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

### Test Coverage Target

SwiftProyecto aims for **80%+ test coverage** to ensure reliability and regression safety.

## Documentation

Detailed documentation is available in the `/Docs` directory:

- [Implementation Strategy](./Docs/IMPLEMENTATION_STRATEGY.md) - Phased development plan
- [API Documentation](./Docs/API.md) - (Coming in Phase 1)

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

✅ **Refactoring Complete** - Phases 1-5 Complete

SwiftProyecto has completed its core refactoring to become a focused file source abstraction layer. The library now provides:
- FileSource protocol with DirectoryFileSource and GitRepositoryFileSource implementations
- Centralized BookmarkManager for security-scoped access
- ProjectService for project lifecycle management
- FileNode for hierarchical file tree display
- 171 passing tests (177 total, 6 pre-existing failures)

APIs are stable for 0.5.x releases. Breaking changes may occur before 1.0.0.

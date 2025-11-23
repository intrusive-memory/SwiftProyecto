# SwiftProyecto

<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg" />
    <img src="https://img.shields.io/badge/Platform-iOS%2026.0+%20|%20macOS%2026.0+-lightgrey.svg" />
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
    <img src="https://img.shields.io/badge/Version-0.5.0-blue.svg" />
</p>

**SwiftProyecto** is a Swift package for managing screenplay projects in Produciesta. It provides data models, business logic, and services for folder-based project management with lazy loading and isolated SwiftData containers.

## Overview

SwiftProyecto handles:
- Project metadata management via PROJECT.md manifest files
- File discovery and state tracking (loaded, unloaded, stale, missing)
- Dual SwiftData container strategy (app-wide vs project-local)
- Project lifecycle operations (create, open, sync, load files)
- **iOS iCloud Drive integration** with local storage fallback
- **macOS security-scoped bookmark** management for sandboxed access
- Platform-specific file operations (import, export, copy)

## Architecture

SwiftProyecto sits between SwiftCompartido (data structures & parsing) and Produciesta (UI layer):

```
┌─────────────────────────────────────────────────────────┐
│ Produciesta (iOS/macOS App)                             │
│ - UI Views (ProjectView, SingleFileView)                │
│ - SwiftUI integration                                   │
└─────────────────┬───────────────────────────────────────┘
                  │
        ┌─────────┴──────────┬──────────────────┐
        │                    │                  │
┌───────▼────────┐  ┌────────▼────────┐  ┌─────▼──────┐
│ SwiftProyecto  │  │ SwiftCompartido │  │ SwiftHablare│
│ (THIS)         │  │                 │  │             │
│                │  │ - GuionDocument │  │ - Voice Gen │
│ - ProjectModel │  │ - Parsing       │  │ - Providers │
│ - File State   │  │ - PROJECT.md    │  └─────────────┘
│ - Container    │  │   Parser        │
│   Factory      │  │                 │
│ - Project      │  │                 │
│   Service      │  │                 │
└────────────────┘  └─────────────────┘
```

## Features (Roadmap)

### ✅ Phase 0: Foundation (Complete)
- [x] Package structure and dependencies
- [x] Basic documentation
- [x] GitHub repository published

### ✅ Phase 1: SwiftData Models (Complete)
- [x] `ProjectModel` - Project metadata and relationships
- [x] `ProjectFileReference` - File discovery and state tracking
- [x] `FileLoadingState` enum - File state transitions
- [x] 32 tests, all passing (100%)
- [x] ~95% test coverage

### ✅ Phase 2: Container Strategy (Complete)
- [x] `DocumentContext` enum - Single file vs project context
- [x] `ModelContainerFactory` - Dual container selection logic
- [x] SwiftCompartido dependency integration
- [x] GuionDocumentModel relationship integration
- [x] 55 tests total, all passing (100%)
- [x] ~95% test coverage maintained

### ✅ Phase 3: Service Layer (Complete)
- [x] `ProjectManager` - Project CRUD operations
- [x] Project lifecycle management (create, open, close)
- [x] File discovery and synchronization
- [x] File loading/unloading operations
- [x] Security-scoped bookmark management (iOS/macOS)
- [x] Stale bookmark detection and recreation
- [x] 73 tests total, all passing (100%)
- [x] ~95% test coverage maintained

### ✅ Phase 4: Single File Service Layer (Complete)
- [x] `SingleFileManager` - Single file operations
- [x] File import with security-scoped bookmarks
- [x] File reload/refresh functionality
- [x] Stale file detection (modification date tracking)
- [x] Bookmark resolution with stale handling
- [x] Document deletion (preserves source files)
- [x] 88 tests total, all passing (100%)
- [x] ~95% test coverage maintained

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

### iOS-Specific Features

SwiftProyecto provides iOS-native project management with **iCloud Drive integration** and **local storage** support.

#### iCloud Projects

Projects are automatically synced across devices via iCloud Drive:

```swift
let manager = ProjectManager(modelContext: modelContext)

// Check if iCloud is available
let support = iCloudProjectSupport()
if support.isICloudAvailable {
    // Create project in iCloud Drive
    let project = try await manager.createICloudProject(
        title: "My Series",
        author: "Jane Showrunner",
        description: "A multi-episode series"
    )
}
```

**iCloud Structure:**
```
iCloud Drive/
└── Produciesta/
    └── Documents/
        └── Projects/
            ├── My Series/
            │   ├── PROJECT.md
            │   └── episode-01.fountain
            └── Another Project/
```

#### Local Projects

For offline work or when iCloud is unavailable:

```swift
// Create project in local Documents directory
let project = try await manager.createLocalProject(
    title: "Local Project",
    author: "John Writer"
)
```

**Local Structure:**
```
Documents/
└── Projects/
    └── Local Project/
        ├── PROJECT.md
        └── screenplay.fountain
```

#### Importing Files on iOS

Files are **copied** into the project folder (original preserved):

```swift
// User selects file from document picker
let sourceURL = ... // From UIDocumentPickerViewController

// Copy file into project and load it
let fileRef = try await manager.importFileToProject(
    from: sourceURL,
    into: project,
    replaceExisting: false
)

// File is now part of the project
print(fileRef.filename) // "imported-screenplay.fountain"
```

#### Platform Differences

| Feature | macOS | iOS |
|---------|-------|-----|
| **Project Location** | User-selected folder | iCloud Drive or local Documents |
| **File Access** | Security-scoped bookmarks | Standard bookmarks |
| **Import** | Direct file access | Copy to project folder |
| **Export** | Direct file access | Share sheet / Files app |
| **Sync** | Manual (user manages location) | Automatic (iCloud) or manual (local) |

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

🚧 **In Development** - Phase 4 (Single File Service Layer) Complete

SwiftProyecto is under active development as part of the Produciesta Projects feature. Core functionality (models, containers, project service, and single-file service) is complete with 88 passing tests. APIs may change until version 1.0.0.

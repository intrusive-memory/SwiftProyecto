<p align="center">
  <img src="SwiftProyecto.jpg" alt="SwiftProyecto" width="200" height="200">
</p>

# SwiftProyecto

<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg" />
    <img src="https://img.shields.io/badge/Platform-iOS%2026.0+%20|%20macOS%2026.0+-lightgrey.svg" />
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
    <img src="https://img.shields.io/badge/Version-2.2.0-blue.svg" />
</p>

**SwiftProyecto** is a Swift package providing **file discovery and secure access** for screenplay project management. It discovers files in local directories or git repositories, manages security-scoped bookmarks for sandboxed environments, and provides secure URLs for apps to load and parse files using their own parsers.

## Overview

SwiftProyecto provides:
- **File Discovery**: Recursively discover files in project folders or git repositories via FileSource abstraction
- **Secure File Access**: Security-scoped bookmarks for sandboxed macOS/iOS apps
- **PROJECT.md Parsing**: Lazy-loaded YAML front matter parser using UNIVERSAL library
  - Parse PROJECT.md metadata (title, author, season, episodes, genre, tags)
  - Generate PROJECT.md files from `ProjectFrontMatter` structs
  - Stateless utility with `parse(fileURL:)` and `parse(content:)` methods
- **Project Models**: SwiftData models for project metadata and file references
- **FileNode**: Hierarchical file tree structure for UI display
- **ProjectService**: Project lifecycle management (create, open, sync, get file URLs)
- **BookmarkManager**: Centralized security-scoped bookmark management

**What SwiftProyecto Does NOT Do:**
- ❌ Parse screenplay files (no SwiftCompartido dependency)
- ❌ Load screenplay document content into memory automatically
- ❌ Manage screenplay document loading state or caching

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

### FileSource Abstraction

SwiftProyecto uses a pluggable FileSource abstraction for discovering files:

```
┌─────────────────────────────────────────┐
│ ProjectService                          │
│ - discoverFiles(for: project)           │
│   ↓ delegates to                        │
│ - project.fileSource()                  │
└──────────────┬──────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ FileSource Protocol                      │
│ - discoverFiles() -> [DiscoveredFile]    │
└──────────┬───────────────┬───────────────┘
           │               │
           ▼               ▼
┌──────────────────┐  ┌─────────────────────┐
│ DirectoryFile    │  │ GitRepositoryFile   │
│ Source           │  │ Source              │
│                  │  │                     │
│ - Enumerates     │  │ - Validates .git/   │
│   local files    │  │ - Same discovery    │
│ - Excludes       │  │   as Directory      │
│   system files   │  │                     │
│ - Returns        │  │                     │
│   DiscoveredFile │  │                     │
└──────────────────┘  └─────────────────────┘
```

**Benefits**:
- Clean separation between business logic (ProjectService) and file enumeration (FileSource)
- Easy to add new source types (iCloud, remote servers, archives, etc.)
- Testable with mock FileSource implementations
- ~100 lines of code deduplication

## Features

### ✅ v2.0: File Discovery Focus

- **FileSource Abstraction**: Pluggable file discovery via `DirectoryFileSource` and `GitRepositoryFileSource`
- **File Discovery**: Recursively discover all files in project directories or git repos
- **PROJECT.md Parser**: Lazy-loaded YAML front matter parser using UNIVERSAL library
  - Parse from file URL or string content
  - Generate PROJECT.md with type-safe `ProjectFrontMatter` struct
  - Stateless utility for easy testing and integration
  - Spec-compliant YAML parsing (handles complex arrays, quoted strings, ISO8601 dates)
- **Security-Scoped Bookmarks**: Per-project AND per-file bookmark support for sandboxed apps
- **FileNode Tree**: Hierarchical file tree with sorted children (directories first)
- **SwiftData Models**: `ProjectModel` and `ProjectFileReference` with cascade delete
- **Git Repository Support**: Automatic `.git` directory exclusion and validation
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

PROJECT.md uses YAML front matter delimited by `---` to store project metadata:

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

**Required Fields**:
- `type`: Must be "project"
- `title`: Project title
- `author`: Project author
- `created`: ISO8601 date (e.g., `2025-11-17T10:30:00Z`)

**Optional Fields**:
- `description`: Project description
- `season`: Season number (integer)
- `episodes`: Episode count (integer)
- `genre`: Genre string
- `tags`: Array of tag strings

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

#### Parsing PROJECT.md (Lazy Loading)

SwiftProyecto uses **lazy loading** for PROJECT.md parsing. The file is automatically parsed during `openProject()`, but you can also parse it manually:

```swift
import SwiftProyecto

// Automatic parsing (happens during openProject)
let project = try await service.openProject(at: folderURL)
print(project.title)    // Metadata from PROJECT.md
print(project.author)   // Already parsed
print(project.season)   // Optional field

// Manual parsing (if you need to re-read or parse standalone)
let parser = ProjectMarkdownParser()
let projectMdURL = folderURL.appendingPathComponent("PROJECT.md")

// Parse from file URL
let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)
print(frontMatter.title)       // "My Series"
print(frontMatter.author)      // "Jane Showrunner"
print(frontMatter.season)      // Optional(1)
print(frontMatter.episodes)    // Optional(12)
print(frontMatter.tags)        // Optional(["sci-fi", "drama"])
print(body)                    // "# Project Notes\n..."

// Parse from string content
let content = """
---
type: project
title: My Series
author: Jane Doe
created: 2025-11-17T10:30:00Z
---

# Notes
"""
let (fm, bodyText) = try parser.parse(content: content)

// Generate PROJECT.md content
let newFrontMatter = ProjectFrontMatter(
    title: "New Project",
    author: "John Writer",
    created: Date(),
    season: 2,
    episodes: 10,
    genre: "Drama",
    tags: ["drama", "mystery"]
)
let markdown = parser.generate(frontMatter: newFrontMatter, body: "# Production Notes")
// Write to file or display in UI
```

**Parser Features**:
- **Lazy Loading**: Parse only when needed (not automatically on every file access)
- **Stateless**: ProjectMarkdownParser has no internal state, just pure functions
- **Type-Safe**: Returns strongly-typed `ProjectFrontMatter` struct
- **Error Handling**: Throws descriptive errors for invalid YAML or missing fields
- **Two-Way**: Parse existing PROJECT.md OR generate new ones
- **UNIVERSAL Library**: Uses spec-compliant YAML parser (handles complex arrays, quoted strings, colons in values)

### Integration with Document Parsers

SwiftProyecto v2.0 focuses on **file discovery and PROJECT.md parsing**, not screenplay document parsing. To integrate with a screenplay parser like SwiftCompartido, create an integration layer in your app:

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

### PROJECT.md Processing & Command Arguments

SwiftProyecto provides a complete pipeline for processing PROJECT.md metadata and generating per-file command arguments for audio generation:

```mermaid
classDiagram
    class ProjectMarkdownParser {
        +parse(fileURL: URL) (ProjectFrontMatter, String)
        +parse(content: String) (ProjectFrontMatter, String)
        +generate(frontMatter: ProjectFrontMatter, body: String) String
    }

    class ProjectFrontMatter {
        +title: String
        +author: String
        +created: Date
        +season: Int?
        +episodes: Int?
        +genre: String?
        +tags: [String]?
        +episodesDir: String?
        +audioDir: String?
        +filePattern: FilePattern?
        +exportFormat: String?
        +preGenerateHook: String?
        +postGenerateHook: String?
        +resolvedEpisodesDir: String
        +resolvedAudioDir: String
        +resolvedFilePatterns: [String]
        +resolvedExportFormat: String
    }

    class ParseBatchArguments {
        +projectPath: String
        +output: String?
        +episode: String?
        +format: String
        +skipExisting: Bool
        +resumeFrom: Int?
        +regenerate: Bool
        +skipHooks: Bool
        +useCastList: Bool
        +castListPath: String?
        +dryRun: Bool
        +failFast: Bool
        +verbose: Bool
        +quiet: Bool
        +jsonOutput: Bool
        +validate() void
    }

    class ParseBatchConfig {
        +title: String
        +author: String
        +projectURL: URL
        +episodesDir: String
        +audioDir: String
        +filePatterns: [String]
        +discoveredFiles: [URL]
        +exportFormat: String
        +preGenerateHook: String?
        +postGenerateHook: String?
        +skipExisting: Bool
        +resumeFrom: Int?
        +regenerate: Bool
        +skipHooks: Bool
        +useCastList: Bool
        +castListPath: String?
        +dryRun: Bool
        +verbose: Bool
        +quiet: Bool
        +makeIterator() ParseFileIterator
        +from(projectPath: String, args: ParseBatchArguments?) ParseBatchConfig$
    }

    class ProjectModel {
        +parseBatchConfig(with: ParseBatchArguments?) ParseBatchConfig
    }

    class ParseFileIterator {
        -batchConfig: ParseBatchConfig
        -currentIndex: Int
        -filesToProcess: [URL]
        +next() ParseCommandArguments?
        +collect() [ParseCommandArguments]
        +totalCount: Int
        +currentFileIndex: Int
    }

    class ParseCommandArguments {
        +episodeFileURL: URL
        +outputURL: URL
        +exportFormat: String
        +castListURL: URL?
        +useCastList: Bool
        +verbose: Bool
        +quiet: Bool
        +dryRun: Bool
        +validate() void
        +expectedOutputFilename: String
        +outputExists: Bool
    }

    %% Parsing relationships
    ProjectMarkdownParser --> ProjectFrontMatter : parse() returns
    ProjectMarkdownParser --> ProjectFrontMatter : generate() consumes

    %% Configuration relationships
    ParseBatchArguments --> ParseBatchConfig : from() merges into
    ProjectFrontMatter --> ParseBatchConfig : from() merges into
    ProjectModel --> ParseBatchConfig : parseBatchConfig() creates

    %% Internal usage
    ParseBatchConfig ..> ProjectMarkdownParser : from() uses parse()
    ParseBatchConfig ..> ProjectFrontMatter : from() reads via parser

    %% Iterator relationships
    ParseBatchConfig --> ParseFileIterator : makeIterator() creates
    ParseFileIterator --> ParseCommandArguments : next() yields
    ParseFileIterator ..> ParseBatchConfig : reads config

    note for ParseBatchConfig "Static factory method:\nfrom(projectPath:args:)\n1. Parses PROJECT.md via ProjectMarkdownParser\n2. Merges ProjectFrontMatter + ParseBatchArguments\n3. Discovers files matching filePatterns\n4. Returns configured ParseBatchConfig"

    note for ParseFileIterator "Iterator applies filters:\n- resumeFrom (skip first N files)\n- skipExisting (skip if output exists)\n- regenerate (ignore skipExisting)\nYields one ParseCommandArguments per file"

    note for ParseCommandArguments "Single-file generation args\nConsumed by 'generate' command\nContains all info for one audio file"
```

**Flow**:
1. **CLI** reads `ParseBatchArguments` from command-line flags
2. **ParseBatchConfig.from(projectPath:args:)** creates batch configuration:
   - Calls `ProjectMarkdownParser.parse(fileURL:)` to read PROJECT.md
   - Returns `ProjectFrontMatter` with metadata
   - Merges front matter defaults with CLI overrides (output dir, format, etc.)
   - Discovers episode files matching `filePattern` glob patterns
3. **ParseBatchConfig.makeIterator()** creates `ParseFileIterator`
4. **ParseFileIterator.next()** yields `ParseCommandArguments` for each file:
   - Applies `resumeFrom` filter (skip first N files)
   - Applies `skipExisting` filter (skip if output exists, unless `regenerate`)
   - Constructs output URL, resolves cast list, inherits flags
5. **Generate command** receives single `ParseCommandArguments` for audio generation

**Alternative**: Use `ProjectModel.parseBatchConfig(with:)` extension method to create config from an existing SwiftData project instance.

## proyecto CLI

SwiftProyecto includes a command-line tool (`proyecto`) that uses local LLM inference to analyze directories and generate PROJECT.md files with appropriate metadata.

### Installation

#### Homebrew (Recommended)

```bash
# Add the tap
brew tap intrusive-memory/tap

# Install proyecto
brew install proyecto

# Verify installation
proyecto --version
```

#### Build from Source

```bash
# Clone the repository
git clone https://github.com/intrusive-memory/SwiftProyecto.git
cd SwiftProyecto

# Build and install to ./bin (Debug)
make install

# Or for release build
make release

# Run from local build
./bin/proyecto --version
```

**Requirements for building from source:**
- macOS 26.0+ (Apple Silicon only)
- Xcode 16.0+
- Swift 6.2+

### Commands

#### `proyecto init` (default)

Analyzes a directory and generates PROJECT.md using local LLM inference.

```bash
# Analyze current directory
proyecto init

# Analyze specific directory
proyecto init /path/to/podcast

# Override author field
proyecto init --author "Jane Doe"

# Update existing PROJECT.md (preserves created date, body, hooks)
proyecto init --update

# Force overwrite existing PROJECT.md
proyecto init --force
```

**Options:**
- `directory` (argument): Directory to analyze (default: current directory)
- `--model`: Model path or HuggingFace ID (default: mlx-community/Phi-3-mini-4k-instruct-4bit)
- `--author`: Override the author field
- `--update`: Update existing PROJECT.md, preserving created date, body content, and hooks
- `--force`: Completely overwrite existing PROJECT.md
- `--quiet, -q`: Suppress progress output

**Behavior with existing PROJECT.md:**
- Default: Error if PROJECT.md exists (prevents accidental overwrites)
- `--force`: Completely replace existing PROJECT.md
- `--update`: Preserve created date, body content, and hooks; update other fields

#### `proyecto download`

Downloads an LLM model from HuggingFace.

```bash
# Download default model
proyecto download

# Download specific model
proyecto download --model "mlx-community/Llama-3-8B"
```

### LLM Analysis

The `init` command analyzes:
- Folder name and structure
- README.md content (if present)
- File patterns (*.fountain, *.mp3, etc.)

And generates PROJECT.md frontmatter with:
- title, author, description, genre, tags
- episodesDir, audioDir, filePattern, exportFormat

## Development

### Requirements

- **macOS 26.0+** or **iOS 26.0+**
- **Apple Silicon only** (M1/M2/M3/M4) - NO Intel support
- **Swift 6.2+**
- Xcode 16.0+

### Building

```bash
# Library only (swift build)
swift build

# CLI with Metal shaders (xcodebuild)
make install
```

### Testing

```bash
swift test
```

**Status**: All 184 tests passing with v2.0 API. Test suite includes:
- FileSource abstraction tests (DirectoryFileSource, GitRepositoryFileSource)
- ProjectMarkdownParser tests with UNIVERSAL library
- ProjectService tests for async file discovery
- BookmarkManager tests for security-scoped access
- ProjectModel and ProjectFileReference tests

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

### ✅ v2.0.0 - File Discovery Focus

SwiftProyecto v2.0 is a major refactoring focused on **file discovery, PROJECT.md parsing, and secure access**. Screenplay document parsing has been removed to eliminate circular dependency with SwiftCompartido.

**Current Status**:
- ✅ SwiftCompartido dependency removed
- ✅ Document loading methods removed (~300 LOC)
- ✅ FileSource abstraction implemented (DirectoryFileSource, GitRepositoryFileSource)
- ✅ PROJECT.md parser using UNIVERSAL library (spec-compliant YAML, lazy loading)
- ✅ Per-file bookmark support added
- ✅ FileNode tree structure complete
- ✅ All 184 tests passing with v2.0 API
- ✅ v2.0.0 released

**Stability**: v2.0 introduces breaking changes. See "Migration from v1.x" section above for upgrade guide.

**Integration**: Apps integrate SwiftProyecto with their own screenplay parsers (e.g., SwiftCompartido) via DocumentRegistry pattern.

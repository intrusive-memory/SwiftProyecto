# Changelog

All notable changes to SwiftProyecto will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Cast List Support**: Inline character-to-voice mappings for audio generation
  - `CastMember` model: Maps characters to actors and voice URIs (provider://voice_id format)
  - `cast: [CastMember]?` field in `ProjectFrontMatter` for storing cast list inline
  - `discoverCastList(for:)` in `ProjectService`: Automatically extracts CHARACTER elements from .fountain files
  - `mergeCastLists()` helper: Merges discovered characters with existing cast, preserving user edits
  - Voice URI format: `<provider>://<voice_id>` (e.g., `apple://en-US/Aaron`, `elevenlabs://en/wise-elder`)
  - Comprehensive tests for CastMember model, parsing, generation, and discovery

### Changed

- `ProjectMarkdownParser.generate()` now outputs inline cast list in YAML format
- `ProjectFrontMatter` initializer includes new optional `cast` parameter
- Cast list stored directly in PROJECT.md instead of separate custom-pages.json file

---

## [2.1.2] - 2026-01-27

### Changed

- **Shared Models Directory** - Updated help text to reference shared model cache at `~/Library/Caches/intrusive-memory/Models/LLM/`

---

## [2.1.1] - 2026-01-27

### Fixed

- **Release Workflow** - Include `mlx-swift_Cmlx.bundle` (Metal shader library) in release tarball
- **Version Numbers** - Fixed library and CLI version strings to match release tag

---

## [2.1.0] - 2026-01-26

### Fixed

- **SwiftBruja Dependency** - Use version tag instead of branch reference for stability

### Changed

- **CI/CD Updates** - Removed performance tests, only macOS tests run on PRs
- **Homebrew Distribution** - Added release workflow with Metal bundle packaging
- **proyecto CLI** - Added command-line tool for PROJECT.md generation

---

## [2.0.0] - 2026-01-20

### Added

- **proyecto CLI** - Command-line tool for PROJECT.md generation using local LLM inference
  - `proyecto init` - Analyze directory and generate PROJECT.md with AI
  - `proyecto download` - Download LLM models from HuggingFace
  - Uses SwiftBruja for on-device LLM inference (no cloud API)

- **Metal Shader Support** - Proper Metal shader bundle copying for LLM inference

- **LLM Model Caching** - CI caches LLM models for faster integration tests

### Changed

- **Major Refactoring** - Library redesigned as file source abstraction layer
  - Removed iOS-specific code
  - Removed file format filtering
  - Focus on file discovery and PROJECT.md management

---

## [0.6.0] - 2025-11-26

### Core Refactoring: File Source Abstraction Layer (Phases 1-5)

This release completes a major refactoring that transforms SwiftProyecto into a focused file source abstraction layer. The library now provides flexible file access through protocols while removing iOS-specific code and file format filtering.

####Added

**Phase 1: BookmarkManager Extraction**
- **BookmarkManager** utility for centralized security-scoped bookmark management
  - `createBookmark(for:)`: Create security-scoped bookmarks for URLs
  - `resolveBookmark(_:)`: Resolve bookmarks to URLs
  - `withAccess(_:bookmarkData:operation:)`: Execute operations with security-scoped access
  - `refreshIfNeeded(_:url:)`: Refresh stale bookmarks
  - Proper error handling with `BookmarkError` enum
  - 21 comprehensive tests (100% passing)

**Phase 2: FileSource Protocol**
- **FileSource** protocol for file access abstraction
  - `discoverFiles()`: Discover files in source
  - `readFile(at:)`: Read file content
  - `modificationDate(for:)`: Get file modification date
  - Properties: `rootURL`, `name`, `bookmarkData`, `type`
- **DirectoryFileSource** implementation for local folders
  - Security-scoped bookmark integration
  - Automatic hidden and system file filtering
  - Support for nested directory structures
  - 20 comprehensive tests (100% passing)
- **DiscoveredFile** model for file discovery results
  - Relative path tracking
  - Modification date
  - File size
  - Equatable and Hashable conformance

**Phase 3: Git Repository Support**
- **GitRepositoryFileSource** implementation
  - Automatic `.git` directory detection
  - Git-aware file filtering (excludes `.git/`)
  - Support for git worktrees and submodules
  - Initialization throws if not a git repository
  - 22 comprehensive tests (100% passing)
- **FileSourceType** enum for source type tracking
  - `.directory`: Local folder
  - `.gitRepository`: Git repository
  - `.packageBundle`: Package bundle (future)

**Phase 4: Service Layer Refactor**
- **ProjectService** (renamed from ProjectManager)
  - Removed hard-coded file filtering (.fountain, .fdx)
  - Returns all discovered files (consumer filters)
  - Updated to use FileSource protocol
  - ProjectModel integration with FileSource
  - 20 comprehensive tests (100% passing)

**Phase 5: File Tree Helper**
- **FileNode** struct for hierarchical file display
  - Sendable, Identifiable, Hashable conformance
  - Tree building from flat file references
  - Navigation methods: `findNode(atPath:)`, `allFiles`, `allDirectories`
  - `sortedChildren`: Directories first, then alphabetical
  - Computed properties: `fileCount`, `totalNodeCount`, `childCount`
  - `fileReference(in:)` extension for ProjectModel integration
  - 22 comprehensive tests (100% passing)
- **ProjectModel.fileTree()** convenience method
  - Easy tree generation: `project.fileTree()`
  - Returns root FileNode with full hierarchy

#### Changed
- **BREAKING**: Renamed `ProjectManager` to `ProjectService`
- **BREAKING**: `ProjectService.discoverFiles()` now returns ALL files (no format filtering)
- **BREAKING**: ProjectModel now uses FileSource protocol instead of direct URLs
  - Added `sourceType`, `sourceName`, `sourceRootURL` properties
  - Added `fileSource()` method to reconstruct FileSource instance
- **BREAKING**: FileNode stores `fileReferenceID: UUID?` instead of `ProjectFileReference?` for Sendable conformance

#### Removed
- **BREAKING**: Removed iOS-specific code
  - Removed `iCloudProjectSupport` class
  - Removed `SingleFileManager` service
  - Removed iOS-specific ProjectManager methods
  - Out of scope for this library (moved to app layer)
- **BREAKING**: Removed hard-coded file format filtering
  - Consumers now responsible for filtering

#### Tests
- 177 total tests (171 passing, 6 pre-existing ModelContainerFactory failures)
- All refactored components: 105/105 tests passing (100%)
  - BookmarkManager: 21 tests
  - DirectoryFileSource: 20 tests
  - GitRepositoryFileSource: 22 tests
  - ProjectService: 20 tests
  - FileNode: 22 tests
- Test coverage: ~95% for refactored components

#### Documentation
- Updated README with new architecture
- Updated usage examples for FileSource protocol
- Updated feature roadmap (Phases 1-5 complete)
- Comprehensive REFACTORING_DESIGN.md document

---


#### Added
- **iCloudProjectSupport** class for iOS-specific project management
  - iCloud Drive integration with automatic synchronization
  - Local (on-device) project support
  - `isICloudAvailable` property for feature detection
  - `iCloudContainerURL` property for accessing iCloud container
  - `iCloudProjectsFolder()` and `localProjectsFolder()` methods
  - `createICloudProjectFolder()` and `createLocalProjectFolder()` methods
  - `copyFileToProject()` for file import workflow
  - `copyFileFromProject()` for file export workflow
  - `discoverICloudProjects()` and `discoverLocalProjects()` methods
- **ProjectManager iOS methods** (iOS-only, conditional compilation)
  - `createICloudProject()` - Creates projects in iCloud Drive
  - `createLocalProject()` - Creates projects in local Documents
  - `importFileToProject()` - Imports files by copying to project folder
- **Platform-specific security-scoped bookmark handling**
  - macOS: Uses `.withSecurityScope` for sandboxed file access
  - iOS: Uses standard bookmarks (security handled by document picker)
  - Conditional compilation with `#if os(macOS)` / `#if os(iOS)`

#### Changed
- ProjectManager and SingleFileManager now use platform-specific bookmark options
- Security-scoped resource access only on macOS (iOS handles automatically)

---

## [0.5.0] - 2025-11-17

### Phase 4: Single File Service Layer (Complete)

#### Added
- **SingleFileManager** service for single screenplay file management
  - `importFile()`: Imports screenplay files into app-wide SwiftData container
  - `reloadFile()`: Refreshes document from source file (re-parsing)
  - `needsReload()`: Detects if source file has been modified
  - `resolveBookmark()`: Resolves security-scoped bookmarks with stale handling
  - `deleteDocument()`: Removes document from SwiftData (preserves source file)
- **Security-scoped resource access** for single files
  - Bookmark creation and resolution for file persistence
  - Automatic stale bookmark detection and recreation
  - Proper security scope lifecycle management
- **File modification tracking**
  - Compare modification dates to detect stale documents
  - `lastImportDate` tracking on GuionDocumentModel
  - Smart reload detection
- **Comprehensive error handling**
  - `SingleFileError` enum with 9 error cases
  - Descriptive error messages for all failure scenarios
  - Proper error propagation and categorization

#### Tests
- 88 tests total, all passing (100%)
- SingleFileManagerTests: 15 comprehensive tests
  - File import (success, not found, multiple files)
  - File reload (success, not found, no bookmark)
  - Stale detection (new document, not modified, modified, not found)
  - Bookmark resolution (success, no data)
  - Document deletion (with cascade verification)
  - Full lifecycle integration test
- Test coverage maintained at ~95%

#### Development
- Zero compiler warnings
- Full iOS 26.0+ and macOS 26.0+ platform support
- Proper MainActor isolation for SwiftData operations
- Security-scoped access tested on both platforms

---

## [0.4.0] - 2025-11-17

### Phase 3: Service Layer (Complete)

#### Added
- **ProjectManager** service for project lifecycle management
  - `createProject()`: Creates new project folder with PROJECT.md manifest
  - `openProject()`: Opens existing projects and syncs with SwiftData
  - `discoverFiles()`: Scans project folder for screenplay files
  - `loadFile()`: Parses and imports screenplay files to SwiftData
  - `unloadFile()`: Removes loaded files from SwiftData
  - `syncProject()`: Synchronizes filesystem with SwiftData state
- **Security-scoped resource access** (iOS/macOS sandboxing)
  - Bookmark resolution with stale detection
  - Automatic bookmark recreation when stale
  - Helper methods for secure file access: `withSecurityScopedAccess()`
  - Proper `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` patterns
- **Enhanced error handling**
  - New `ProjectError` cases: `bookmarkResolutionFailed`, `securityScopedAccessFailed`, `noBookmarkData`
  - Tiered error handling for file operations (missing vs error states)
- **File state management**
  - Automatic state transitions: notLoaded → loading → loaded
  - Missing file detection during sync operations
  - Error state tracking with messages

#### Tests
- 73 tests total, all passing (100%)
- ProjectManagerTests: 18 comprehensive tests
  - Project creation (minimal and full metadata)
  - Project opening (new and existing)
  - File discovery (empty, with files, missing files, hidden/cache exclusion)
  - File loading (success, not found, already loaded)
  - File unloading (success, already unloaded)
  - Project synchronization
- Test coverage maintained at ~95%

#### Development
- Zero compiler warnings
- Full iOS 26.0+ and macOS 26.0+ platform support
- Security-scoped access tested on both platforms
- Proper MainActor isolation for SwiftData operations

---

## [0.3.0] - 2025-11-17

### Phase 2: Container Strategy (Complete)

#### Added
- **DocumentContext** enum
  - Single file vs project context representation
  - Convenience properties (url, isProject, cacheDirectoryURL, storeURL)
  - Full Equatable and Sendable support
- **ModelContainerFactory** service
  - Dual container creation strategy
  - Single file: App-wide container in ~/Library/Application Support
  - Project: Project-local container in `<project>/.cache/`
  - Container lifecycle methods (create, delete, exists)
  - Comprehensive error handling
- **SwiftCompartido dependency** integration
  - ProjectFileReference.loadedDocument relationship to GuionDocumentModel
  - Full schema integration with all SwiftCompartido models
  - Proper @Relationship with .nullify delete rule

#### Tests
- 55 tests total, all passing (100%)
- DocumentContextTests: 11 tests
- ModelContainerFactoryTests: 12 tests
- All Phase 1 tests updated for GuionDocumentModel relationship
- Test coverage maintained at ~95%

#### Development
- Zero compiler warnings
- Comprehensive integration tests for dual container strategy
- Proper MainActor isolation for SwiftData operations

---

## [0.2.0] - 2025-11-17

### Phase 1: SwiftData Models (Complete)

#### Added
- **FileLoadingState** enum with 6 states (notLoaded, loading, loaded, stale, missing, error)
  - Display properties (displayName, systemIconName)
  - Capability flags (canOpen, canLoad, showsWarning)
  - Full Codable support
- **ProjectFileReference** SwiftData model
  - File discovery and state tracking
  - Bidirectional relationship to ProjectModel
  - Convenience properties for querying
  - Display name with path context
- **ProjectModel** SwiftData model
  - Complete project metadata (title, author, created, description, etc.)
  - Optional fields (season, episodes, genre, tags)
  - Security-scoped folder bookmark storage
  - Cascade delete for file references
  - Query methods (file counts, filtering, sorting)
  - Sync detection logic

#### Tests
- 32 tests total, all passing (100%)
- FileLoadingStateTests: 8 tests
- ProjectFileReferenceTests: 10 tests
- ProjectModelTests: 12 tests
- Test coverage: ~95%

#### Development
- Swift 6.2 compatibility
- iOS 26.0+ and macOS 26.0+ support
- Full SwiftData persistence
- Zero compiler warnings

---

## [0.1.0] - 2025-11-17

### Phase 0: Foundation (Complete)

#### Added
- Initial package structure with Package.swift
- MIT license
- README.md with project overview
- CONTRIBUTING.md guidelines
- .gitignore for Swift projects
- Placeholder source files and tests
- GitHub repository at intrusive-memory/SwiftProyecto
- Documentation directory with implementation strategy

#### Development
- Package builds successfully with Swift 6.2
- Basic tests pass (version check, placeholder test)
- Repository published to GitHub

[Unreleased]: https://github.com/intrusive-memory/SwiftProyecto/compare/v2.1.2...HEAD
[2.1.2]: https://github.com/intrusive-memory/SwiftProyecto/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/intrusive-memory/SwiftProyecto/compare/v2.1.0...v2.1.1
[0.5.0]: https://github.com/intrusive-memory/SwiftProyecto/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/intrusive-memory/SwiftProyecto/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/intrusive-memory/SwiftProyecto/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/intrusive-memory/SwiftProyecto/releases/tag/v0.2.0
[0.1.0]: https://github.com/intrusive-memory/SwiftProyecto/releases/tag/v0.1.0

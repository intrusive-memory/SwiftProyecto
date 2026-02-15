# SwiftProyecto Refactoring Design

**Version:** 2.0
**Date:** 2025-11-26
**Status:** Finalized - Ready for Implementation

---

## Executive Summary

This document proposes a refactoring of SwiftProyecto to establish clear library boundaries, abstract file source handling, and create a more maintainable architecture. The core principle is: **SwiftProyecto should be a file source abstraction layer that discovers and loads files from various sources, without knowing about platform-specific storage locations or parsing implementations.**

### Current State
- 2,647 lines of code
- Tight coupling to iOS folder structures
- Platform-specific code mixed into core services
- Direct dependency on SwiftCompartido types
- Duplicate bookmark management logic

### Proposed State
- Clear separation: File Source → Discovery → Loading → Storage
- Platform-agnostic file source protocol
- Direct integration with SwiftCompartido (no parser abstraction)
- Single bookmark management utility
- App layer controls storage locations
- No single-file workflow (out of scope)

---

## Design Principles

### 1. Library Boundary Definition

**SwiftProyecto SHOULD:**
- ✅ Define abstract file source types (directory, git repo, etc.)
- ✅ Provide hierarchical file list from any source
- ✅ Load file contents on demand
- ✅ Track file loading state (loaded, stale, missing)
- ✅ Manage security-scoped bookmarks
- ✅ Provide SwiftData models for persistence
- ✅ Detect file modifications and staleness

**SwiftProyecto SHOULD NOT:**
- ❌ Know about iOS vs macOS folder structures
- ❌ Define where projects are stored (iCloud/local)
- ❌ Parse screenplay files (delegates to parser)
- ❌ Handle document pickers or import workflows
- ❌ Define UI display properties
- ❌ Know about specific app names ("Produciesta")

### 2. Separation of Concerns

```
┌─────────────────────────────────────────────────────┐
│ Application Layer (Produciesta)                     │
│ - Folder structure (iCloud/local)                   │
│ - Document picker integration                       │
│ - UI/SwiftUI views                                  │
│ - Platform-specific workflows                       │
└───────────────────┬─────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────┐
│ SwiftProyecto (File Source Management)              │
│ - File source protocol                              │
│ - File discovery and state tracking                 │
│ - Loading orchestration                             │
│ - SwiftData persistence                             │
│ - Bookmark management                               │
└───────────────────┬─────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────┐
│ SwiftCompartido (Screenplay Parsing)                │
│ - Screenplay format parsers                         │
│ - Document/element models                           │
│ - Title page handling                               │
└─────────────────────────────────────────────────────┘
```

---

## Proposed Architecture

### 1. File Source Protocol

The core abstraction that defines what a "file source" is:

```swift
/// Represents a source of files (directory, git repo, etc.)
public protocol FileSource {
    /// Unique identifier for this source
    var id: UUID { get }

    /// Human-readable name
    var name: String { get }

    /// Type of source
    var sourceType: FileSourceType { get }

    /// Root URL for file operations
    var rootURL: URL { get }

    /// Security-scoped bookmark data (for sandboxed access)
    var bookmarkData: Data? { get set }

    /// Discover all files in this source
    func discoverFiles() async throws -> [DiscoveredFile]

    /// Read contents of a specific file
    func readFile(at relativePath: String) async throws -> Data

    /// Check if file has been modified since date
    func modificationDate(for relativePath: String) throws -> Date?
}

public enum FileSourceType: String, Codable {
    case directory          // Simple folder
    case gitRepository      // Git repo root
    case packageBundle      // .textbundle, etc.
    // Future: .remote, .iCloud, .dropbox
}
```

### 2. Concrete File Source Implementations

```swift
/// Directory-based file source
public final class DirectoryFileSource: FileSource {
    public let id: UUID
    public let name: String
    public let sourceType: FileSourceType = .directory
    public let rootURL: URL
    public var bookmarkData: Data?

    public init(url: URL, name: String? = nil) {
        self.id = UUID()
        self.rootURL = url
        self.name = name ?? url.lastPathComponent
    }

    public func discoverFiles() async throws -> [DiscoveredFile] {
        // Walk directory tree
        // Skip .cache/, .git/, hidden files
        // Return relative paths
    }

    public func readFile(at relativePath: String) async throws -> Data {
        let fileURL = rootURL.appendingPathComponent(relativePath)
        return try BookmarkManager.withAccess(rootURL) { _ in
            try Data(contentsOf: fileURL)
        }
    }

    public func modificationDate(for relativePath: String) throws -> Date? {
        let fileURL = rootURL.appendingPathComponent(relativePath)
        return try BookmarkManager.withAccess(rootURL) { _ in
            try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date
        }
    }
}

/// Git repository file source
public final class GitRepositoryFileSource: FileSource {
    public let id: UUID
    public let name: String
    public let sourceType: FileSourceType = .gitRepository
    public let rootURL: URL
    public var bookmarkData: Data?

    // Additional git-specific properties
    public var currentBranch: String?
    public var remoteURL: String?

    public init(url: URL, name: String? = nil) throws {
        self.id = UUID()
        self.rootURL = url

        // Verify .git exists
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path) else {
            throw FileSourceError.notGitRepository
        }

        self.name = name ?? url.lastPathComponent
    }

    public func discoverFiles() async throws -> [DiscoveredFile] {
        // Walk git tree
        // Skip .git/, tracked vs untracked files
        // Could integrate git status
    }

    // Implementations similar to DirectoryFileSource
}
```

### 3. Discovered File Model

```swift
/// Represents a file discovered in a source
public struct DiscoveredFile: Identifiable, Hashable {
    public let id: UUID
    public let relativePath: String
    public let filename: String
    public let modificationDate: Date?
    public let fileSize: Int64?

    /// Computed from relativePath
    public var pathComponents: [String] {
        relativePath.split(separator: "/").map(String.init)
    }

    public var directory: String? {
        let components = pathComponents
        return components.count > 1 ? components.dropLast().joined(separator: "/") : nil
    }
}
```

### 4. Project Service (Orchestration)

Replaces current `ProjectManager` with clearer responsibilities:

```swift
public final class ProjectService {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Project Management

    /// Create new project with given file source
    public func createProject(
        source: FileSource,
        title: String,
        author: String?,
        metadata: ProjectMetadata
    ) async throws -> ProjectModel {
        // Create PROJECT.md manifest
        // Store bookmark
        // Create ProjectModel
    }

    /// Open existing project from file source
    public func openProject(source: FileSource) async throws -> ProjectModel {
        // Resolve bookmark
        // Read PROJECT.md
        // Create or update ProjectModel
    }

    // MARK: - File Discovery

    /// Discover all files in project's source
    /// By default, returns ALL files (no format filtering)
    /// Use optional filter parameter to restrict to specific file types
    public func discoverFiles(
        for project: ProjectModel,
        filter: ((URL) -> Bool)? = nil
    ) async throws {
        let source = try project.fileSource()

        let discovered = try await source.discoverFiles()

        // Apply optional filter
        let filteredFiles = if let filter = filter {
            discovered.filter { file in
                let url = source.rootURL.appendingPathComponent(file.relativePath)
                return filter(url)
            }
        } else {
            discovered
        }

        // Update file references
        // Mark stale/missing files
        // Add new files
    }

    // MARK: - File Loading

    /// Load a file's content and parse it
    public func loadFile(
        _ reference: ProjectFileReference,
        in project: ProjectModel
    ) async throws {
        let source = try project.fileSource()

        reference.loadingState = .loading

        do {
            // Read file data
            let data = try await source.readFile(at: reference.relativePath)

            // Parse using SwiftCompartido directly (no abstraction)
            let parsedCollection = try await GuionParsedElementCollection(
                data: data,
                filename: reference.filename,
                progress: nil
            )

            // Create GuionDocumentModel
            let document = GuionDocumentModel(
                filename: reference.filename,
                rawContent: nil,
                suppressSceneNumbers: false
            )

            for (index, element) in parsedCollection.elements.enumerated() {
                let elementModel = GuionElementModel(
                    from: element,
                    chapterIndex: 0,
                    orderIndex: index
                )
                document.elements.append(elementModel)
            }

            reference.loadedDocument = document
            reference.loadingState = .loaded
            reference.lastLoadedModificationDate = reference.lastKnownModificationDate

        } catch {
            reference.loadingState = .error(error.localizedDescription)
            throw error
        }
    }

    /// Intelligently reload file preserving user data
    public func reloadFile(
        _ reference: ProjectFileReference,
        in project: ProjectModel
    ) async throws {
        // Implementation of intelligent element matching
        // Preserves audio, custom elements, etc.
    }

    /// Unload file from memory/SwiftData
    public func unloadFile(_ reference: ProjectFileReference) throws {
        reference.loadedDocument = nil
        reference.loadingState = .notLoaded
    }
}
```

### 5. Updated Project Model

```swift
@Model
public final class ProjectModel {
    @Attribute(.unique) public var id: UUID

    // Metadata
    public var title: String
    public var author: String?
    public var created: Date
    public var projectDescription: String?

    // Series metadata
    public var season: Int?
    public var episodes: Int?
    public var genre: String?
    public var tags: [String]

    // File Source (replaces folderBookmark + folderPath)
    public var sourceType: FileSourceType
    public var sourceRootURL: String  // String representation
    public var sourceBookmarkData: Data?
    public var sourceName: String

    // Note: No sourceMetadata field - git library handles all git queries

    // Timestamps
    public var lastSyncDate: Date?
    public var lastOpenedDate: Date?

    // Relationships
    @Relationship(deleteRule: .cascade)
    public var fileReferences: [ProjectFileReference]

    // PROJECT.md content
    public var projectMarkdownContent: String?

    // MARK: - Computed Properties

    public func fileSource() throws -> FileSource {
        guard let url = URL(string: sourceRootURL) else {
            throw ProjectError.invalidURL
        }

        switch sourceType {
        case .directory:
            let source = DirectoryFileSource(url: url, name: sourceName)
            source.bookmarkData = sourceBookmarkData
            return source

        case .gitRepository:
            let source = try GitRepositoryFileSource(url: url, name: sourceName)
            source.bookmarkData = sourceBookmarkData
            return source

        case .packageBundle:
            throw ProjectError.unsupportedSourceType
        }
    }

    public func fileTree() -> FileNode {
        // Build hierarchical tree from flat fileReferences array
        // Implementation in Phase 5
    }
}
```

### 6. Bookmark Management Utility

Extract duplicated bookmark logic:

```swift
public enum BookmarkManager {
    public enum BookmarkError: Error {
        case staleBookmark
        case accessDenied
        case invalidBookmarkData
    }

    /// Create security-scoped bookmark for URL
    public static func createBookmark(for url: URL) throws -> Data {
        #if os(macOS)
        return try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #else
        return try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #endif
    }

    /// Resolve bookmark, handling stale bookmarks
    public static func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false

        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = .withSecurityScope
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif

        let url = try URL(
            resolvingBookmarkData: data,
            options: options,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        return (url, isStale)
    }

    /// Recreate bookmark if stale
    public static func refreshIfNeeded(_ bookmarkData: inout Data?) throws -> URL? {
        guard let data = bookmarkData else { return nil }

        let (url, isStale) = try resolveBookmark(data)

        if isStale {
            bookmarkData = try createBookmark(for: url)
        }

        return url
    }

    /// Execute operation with security-scoped access
    public static func withAccess<T>(
        _ url: URL,
        bookmarkData: Data? = nil,
        operation: (URL) throws -> T
    ) throws -> T {
        // Resolve bookmark if provided
        let resolvedURL: URL
        if let data = bookmarkData {
            let (url, _) = try resolveBookmark(data)
            resolvedURL = url
        } else {
            resolvedURL = url
        }

        // Access resource
        #if os(macOS)
        guard resolvedURL.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied
        }
        defer { resolvedURL.stopAccessingSecurityScopedResource() }
        #endif

        return try operation(resolvedURL)
    }
}
```

### 7. Direct SwiftCompartido Integration (No Abstraction)

**Decision:** Keep direct integration with SwiftCompartido types. No parser protocol abstraction.

```swift
// ProjectService uses SwiftCompartido directly
public final class ProjectService {
    // ...

    public func loadFile(
        _ reference: ProjectFileReference,
        in project: ProjectModel
    ) async throws {
        // Read file data from source
        let data = try await source.readFile(at: reference.relativePath)

        // Parse using SwiftCompartido directly
        let parsedCollection = try await GuionParsedElementCollection(
            file: fileURL.path,
            progress: nil
        )

        // Create GuionDocumentModel
        let document = GuionDocumentModel(...)
        for element in parsedCollection.elements {
            let elementModel = GuionElementModel(from: element, ...)
            document.elements.append(elementModel)
        }

        reference.loadedDocument = document
        reference.loadingState = .loaded
    }
}
```

**Rationale:** We control both libraries. No need for abstraction layer complexity.

---

## Migration Strategy

### Phase 1: Extract BookmarkManager Utility (Low Risk)
**Goal:** Reduce duplication without changing APIs

**Tasks:**
1. Create `Sources/SwiftProyecto/Utilities/BookmarkManager.swift`
2. Implement static methods: `createBookmark()`, `resolveBookmark()`, `refreshIfNeeded()`, `withAccess()`
3. Add platform-specific logic (`#if os(macOS)`)
4. Update `ProjectManager` to use `BookmarkManager`
5. Remove `SingleFileManager` entirely (out of scope decision)
6. Remove iOS-specific methods: `createICloudProject()`, `createLocalProject()`, `importFileToProject()`
7. Remove `iCloudProjectSupport.swift` entirely (app layer responsibility)
8. Run all tests

**Effort:** 4-6 hours
**Risk:** Low (internal refactor + scope reduction)
**Status:** ✅ Finalized

### Phase 2: Introduce FileSource Protocol (Medium Risk)
**Goal:** Abstract file sources with protocol

**Tasks:**
1. Create `Sources/SwiftProyecto/FileSource/FileSource.swift` protocol
2. Define `FileSourceType` enum (directory, gitRepository, packageBundle)
3. Create `DiscoveredFile` struct
4. Implement `DirectoryFileSource` concrete type
5. Update `ProjectModel`:
   - Replace `folderBookmark`/`folderPath` with `sourceType`/`sourceRootURL`/`sourceBookmarkData`
   - Add `fileSource()` computed property
   - Remove `sourceMetadata` field (git library handles metadata)
6. No migration code (clean break decision)
7. Update tests
8. Update documentation

**Effort:** 10-16 hours
**Risk:** Medium (SwiftData model changes, no backward compatibility)
**Status:** ✅ Finalized

### Phase 3: Implement GitRepositoryFileSource (Low Risk)
**Goal:** Add git repository support

**Tasks:**
1. Create `Sources/SwiftProyecto/FileSource/GitRepositoryFileSource.swift`
2. Detect `.git/` directory in initializer
3. File discovery respects existing patterns (skip `.git/`, `.cache/`, etc.)
4. No git metadata storage (use git library for queries)
5. Add integration tests with mock git repo
6. Update documentation

**Effort:** 6-10 hours
**Risk:** Low (additive feature, git library handles operations)
**Status:** ✅ Finalized

### Phase 4: Refactor ProjectManager → ProjectService (Medium Risk)
**Goal:** Rename and clarify responsibilities

**Tasks:**
1. Rename `ProjectManager` → `ProjectService`
2. Update method signatures to use `FileSource`
3. Update `discoverFiles()` to return all files (remove format filtering by default)
4. Add optional filtering parameter
5. Keep direct `GuionDocumentModel` usage (no parser abstraction)
6. Remove all iOS-specific code (already done in Phase 1)
7. Update all tests
8. Update documentation and examples

**Effort:** 8-12 hours
**Risk:** Medium (major API change)
**Status:** ✅ Finalized

### Phase 5: Add File Tree Helper (Low Risk)
**Goal:** Provide hierarchical file list convenience

**Tasks:**
1. Create `FileNode` struct for tree representation
2. Add `ProjectModel.fileTree()` method
3. Build tree from flat `fileReferences` array
4. Add tests for nested directory structures
5. Update documentation with examples

**Effort:** 4-6 hours
**Risk:** Low (additive feature)
**Status:** ✅ Finalized

### Phase 6: Update Produciesta App and Documentation (External)
**Goal:** Move iOS/platform-specific logic to app and update documentation

**Tasks:**
1. Create `ProjectStorageService` in Produciesta
2. Move iCloud/local folder logic from removed `iCloudProjectSupport`
3. Update app to create `DirectoryFileSource` or `GitRepositoryFileSource`
4. Update UI to use new `ProjectService` API
5. Update app to handle document picker → file source creation
6. Test on iOS and macOS
7. **Update CLAUDE.md** with current architecture and removed features
8. **Update README.md** with accurate API examples and usage
9. **Review and remove obsolete tests** that no longer align with library focus

**Effort:** 12-16 hours (in Produciesta repo) + 2-4 hours (documentation)
**Risk:** Medium (cross-repo coordination)
**Status:** ✅ Finalized (external task)

---

## Finalized Design Decisions

After interactive review, the following decisions have been finalized:

| Question | Decision | Rationale |
|----------|----------|-----------|
| 1. File Source Persistence | **Protocol + Value Types** | Lightweight, flexible, easy to extend |
| 2. Git Integration Scope | **Minimal detection only** | Use existing git library for operations |
| 3. Parser Abstraction | **Never - always use SwiftCompartido** | We control both libraries, no need for abstraction |
| 4. Backward Compatibility | **No - clean break** | Pre-1.0, all code under our control |
| 5. Hierarchical File List | **Provide tree structure helper** | Convenience for library consumers |
| 6. Single File Workflow | **Remove entirely** | Out of scope for this library |
| 7. File Type Filtering | **Return all files, optional filtering** | Format-agnostic, exclude system files only |
| 8. Error Handling | **Standard throwing errors** | Idiomatic Swift, store errors in model state |
| 9. Discovery Strategy | **Eager - all files upfront** | Simple, sufficient for typical projects |
| 10. Git Metadata | **None - use git library** | Don't duplicate git library functionality |

---

## Open Questions (ARCHIVE - For Reference Only)

### 1. File Source Persistence Strategy

**Question:** Should `FileSource` implementations be SwiftData models or value types?

**Option A: Protocol + Value Types (Proposed)**
```swift
protocol FileSource { ... }
struct DirectoryFileSource: FileSource { ... }

// ProjectModel stores serialized representation
public var sourceType: FileSourceType
public var sourceBookmarkData: Data?
public var sourceMetadata: Data?  // JSON for git branch, etc.
```

**Pros:**
- Flexible: Easy to add new source types
- Simple: No SwiftData schema for each source type
- Lightweight: Sources created on-demand

**Cons:**
- Manual serialization of metadata
- Can't query sources directly via SwiftData

**Option B: SwiftData Models**
```swift
@Model class FileSourceModel { ... }
@Model class DirectorySourceModel: FileSourceModel { ... }
@Model class GitSourceModel: FileSourceModel { ... }
```

**Pros:**
- Native SwiftData relationships
- Rich queries possible

**Cons:**
- Schema complexity increases
- Harder to extend with new types
- Migration challenges

**Recommendation:** Option A (Protocol + Value Types). File sources are transient - they're recreated from bookmarks each time a project opens.

---

### 2. Git Integration Scope

**Question:** How deep should git integration go?

**Option A: Minimal (Proposed)**
- Detect if directory is git repo
- Store current branch name
- File discovery respects .gitignore
- No git operations (commit, push, etc.)

**Option B: Full Integration**
- Git status integration (modified, staged, etc.)
- Commit/branch operations
- Conflict detection
- History viewing

**Recommendation:** Option A (Minimal). Git operations belong in the app or a separate library. SwiftProyecto should only care about "files in a git repo" vs "files in a directory."

---

### 3. Parser Abstraction Timing

**Question:** When should we abstract the parser?

**Option A: Phase 5 (After File Sources)**
- Pros: Logical progression, file sources first
- Cons: Delays full decoupling

**Option B: Never**
- Pros: Simpler, SwiftCompartido is our parser
- Cons: Tight coupling, hard to test, limits extensibility

**Option C: Phase 0 (Before File Sources)**
- Pros: Clean slate for refactoring
- Cons: Big bang change, high risk

**Recommendation:** Option A (Phase 5). File sources are more urgent, parser abstraction is future-proofing.

---

### 4. Backward Compatibility

**Question:** Must we maintain backward compatibility during refactoring?

**Requirements:**
- Existing projects must open without migration
- Existing SwiftData stores must be readable
- API changes can break Produciesta (we control it)

**Proposed Strategy:**
1. **Phase 3:** Add new `sourceType`/`sourceBookmarkData` fields, keep old `folderBookmark`
2. **Migration:** Convert `folderBookmark` → `sourceBookmarkData` on first open
3. **Deprecation:** Mark old methods as deprecated, maintain for 1-2 releases
4. **Removal:** Delete old code after Produciesta fully migrated

**Question for Review:** Do we need to support old projects indefinitely, or can we require one-time migration?

---

### 5. Hierarchical File List Representation

**Question:** Should SwiftProyecto provide a hierarchical (tree) file structure, or flat list?

**Option A: Flat List (Current)**
```swift
project.fileReferences  // Array of ProjectFileReference
// UI builds tree structure
```

**Pros:**
- Simple SwiftData model
- UI has full control over grouping

**Cons:**
- UI must reconstruct hierarchy
- No shared tree logic

**Option B: Tree Structure**
```swift
public struct FileTree {
    public var name: String
    public var children: [FileTree]
    public var file: ProjectFileReference?
}

extension ProjectModel {
    public func fileTree() -> FileTree
}
```

**Pros:**
- Single source of truth
- Reusable across UIs

**Cons:**
- More complex to maintain
- Computed property (performance?)

**Recommendation:** Option B (Tree Structure). The library should provide convenient access patterns, including hierarchical views.

---

### 6. Single File Workflow

**Question:** Does `SingleFileManager` still make sense, or merge into `ProjectService`?

**Current Design:**
- `SingleFileManager`: Handles one-off files
- `ProjectManager`: Handles projects with multiple files

**Option A: Keep Separate**
```swift
let singleFile = try await singleFileManager.importFile(from: url)
let project = try await projectService.openProject(source: source)
```

**Pros:**
- Clear separation of workflows
- Different container strategies

**Cons:**
- Duplicate loading logic
- Two services to maintain

**Option B: Unified Service**
```swift
// Single file is just a project with one file
let source = DirectoryFileSource(url: fileURL.deletingLastPathComponent())
let project = try await projectService.openProject(source: source)
// Load only the one file
```

**Pros:**
- Single code path
- Simplified API

**Cons:**
- Container strategy complexity (app-wide vs project-local)
- Conceptual mismatch (is a single file a "project"?)

**Recommendation:** Option A (Keep Separate). Single-file and project workflows have different lifecycle semantics. Single files use app-wide container, projects use local containers.

---

### 7. File Type Filtering

**Question:** Should SwiftProyecto filter file types, or return everything?

**Current:** ProjectManager filters to screenplay formats (.fountain, .fdx, etc.)

**Option A: Library Filters (Current)**
```swift
public func discoverFiles() async throws -> [DiscoveredFile] {
    // Only return .fountain, .fdx, .highland, etc.
}
```

**Pros:**
- Library knows what it can handle
- Cleaner file lists

**Cons:**
- Hard-coded file types
- Can't discover other files (README, assets)

**Option B: App Filters**
```swift
public func discoverFiles(filter: ((URL) -> Bool)? = nil) async throws -> [DiscoveredFile]

// App decides
let files = try await source.discoverFiles { url in
    [".fountain", ".fdx"].contains(url.pathExtension)
}
```

**Pros:**
- Flexible filtering
- Library is format-agnostic

**Cons:**
- More complex API

**Option C: Return Everything, Filter in Query**
```swift
let allFiles = try await source.discoverFiles()
let screenplays = allFiles.filter { $0.filename.hasSuffix(".fountain") }
```

**Recommendation:** Option A (Library Filters), but make file extensions configurable:

```swift
public struct FileSourceConfiguration {
    public var fileExtensions: Set<String>
    public var excludePatterns: [String]  // .cache, .git, etc.

    public static var screenplayDefaults: FileSourceConfiguration {
        FileSourceConfiguration(
            fileExtensions: [".fountain", ".fdx", ".highland", ".md"],
            excludePatterns: [".cache", ".git", ".DS_Store"]
        )
    }
}

public func discoverFiles(configuration: FileSourceConfiguration = .screenplayDefaults) async throws
```

---

### 8. Error Handling Strategy

**Question:** How should file source errors be handled?

**Scenarios:**
- Stale bookmark (can't resolve)
- File deleted since discovery
- Permission denied
- Network unavailable (future: remote sources)

**Option A: Throw Errors**
```swift
try await source.readFile(at: path)  // throws
```

**Pros:**
- Standard Swift error handling
- Forces explicit error handling

**Cons:**
- Requires try/catch everywhere
- Interrupts batch operations

**Option B: Result Type**
```swift
await source.readFile(at: path)  // -> Result<Data, Error>
```

**Pros:**
- Non-throwing
- Batch operations can collect failures

**Cons:**
- Not idiomatic Swift

**Option C: Optional + Error State**
```swift
reference.loadingState = .error(String)  // Store error in model
let data = try? await source.readFile(at: path)
```

**Recommendation:** Option A (Throw Errors) for file source operations, Option C (Error State) for ProjectFileReference. This allows UI to show errors without crashing.

---

### 9. Performance: Lazy vs Eager Loading

**Question:** Should file discovery be lazy or eager?

**Current:** Discovery is eager (all files found immediately), loading is lazy.

**Option A: Eager Discovery (Current)**
```swift
try await projectService.discoverFiles(for: project)
// All files found and stored in ProjectFileReference
// Loading happens on-demand
```

**Option B: Lazy Discovery**
```swift
// Discover directories, not files
let directories = try await source.discoverDirectories()
// User expands directory in UI
let files = try await source.discoverFiles(in: directory)
```

**Recommendation:** Option A (Eager Discovery). Most screenplay projects have <100 files. Discovery is fast (filesystem metadata only). Lazy discovery adds complexity without clear benefit.

---

### 10. Git-Specific Metadata

**Question:** What git metadata should we track?

**Proposed Fields:**
- Current branch name
- Remote URL (if exists)
- HEAD commit hash

**Not Included:**
- Modified/staged file status (too dynamic)
- Commit history (belongs in git UI)
- Uncommitted changes (performance concern)

**Storage:**
```swift
public struct GitMetadata: Codable {
    public var currentBranch: String?
    public var remoteURL: String?
    public var headCommit: String?
}

// In ProjectModel
public var sourceMetadata: Data?  // Encoded GitMetadata

// In GitRepositoryFileSource
public var metadata: GitMetadata?
```

**Recommendation:** Store minimal git metadata. This is informational only, not for git operations.

---

## Summary of Implementation Changes

Based on finalized decisions, here are the key changes from current implementation:

| Area | Current | After Refactoring |
|------|---------|-------------------|
| **File Sources** | Hard-coded folder access | `FileSource` protocol with `DirectoryFileSource` and `GitRepositoryFileSource` |
| **Single Files** | `SingleFileManager` service | Removed - out of scope |
| **iOS Support** | `iCloudProjectSupport` service | Removed - moved to app layer |
| **Bookmarks** | Duplicated in two services | Centralized `BookmarkManager` utility |
| **Parser** | Direct SwiftCompartido | Still direct (no abstraction) |
| **Git** | Not supported | Basic detection, git library for operations |
| **File Filtering** | Hard-coded screenplay formats | Return all files, optional filter parameter |
| **Compatibility** | N/A | Clean break, no migration code |
| **Tree View** | None | `ProjectModel.fileTree()` helper |
| **Service Name** | `ProjectManager` | `ProjectService` |

---

## Next Steps

1. **Review this document** - Discuss open questions and recommendations
2. **Finalize architecture decisions** - Lock in design before coding
3. **Create implementation plan** - Break down phases into specific tasks
4. **Start with Phase 1** - Extract `BookmarkManager` utility
5. **Incremental implementation** - One phase at a time with full test coverage
6. **Update documentation** - Keep CLAUDE.md in sync with changes

---

## Appendix: API Comparison

### Current API (ProjectManager)

```swift
// Project creation
let project = try await projectManager.createProject(
    at: folderURL,
    title: "My Screenplay"
)

// iOS-specific
let project = try await projectManager.createICloudProject(
    title: "My Screenplay"
)

// File discovery
try projectManager.syncProject(project)

// File loading
try await projectManager.loadFile(fileRef, in: project)
```

### Proposed API (ProjectService)

```swift
// Project creation (platform-agnostic)
let source = DirectoryFileSource(url: folderURL, name: "My Screenplay")
let project = try await projectService.createProject(
    source: source,
    title: "My Screenplay",
    metadata: .default
)

// File discovery
try await projectService.discoverFiles(for: project)

// File loading
try await projectService.loadFile(fileRef, in: project)

// Git project (new capability)
let gitSource = try GitRepositoryFileSource(url: repoURL)
let project = try await projectService.createProject(
    source: gitSource,
    title: "Screenplay Repo",
    metadata: .default
)
```

### App Layer Responsibility (Moved from Library)

```swift
// In Produciesta app (not SwiftProyecto)
final class ProjectStorageService {
    func iCloudProjectsFolder() throws -> URL {
        // App defines folder structure
    }

    func createNewProject(title: String, location: StorageLocation) async throws -> ProjectModel {
        let folderURL: URL
        switch location {
        case .iCloud:
            folderURL = try iCloudProjectsFolder().appendingPathComponent(title)
        case .local:
            folderURL = try localProjectsFolder().appendingPathComponent(title)
        }

        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let source = DirectoryFileSource(url: folderURL, name: title)
        return try await projectService.createProject(source: source, title: title, metadata: .default)
    }
}
```

---

## Document Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-26 | 1.0 | Initial draft with open questions |
| 2025-11-26 | 2.0 | Finalized after interactive review - all 10 questions resolved |


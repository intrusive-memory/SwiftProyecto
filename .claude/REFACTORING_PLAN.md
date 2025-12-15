# SwiftProyecto Refactoring Plan

**Goal**: Transform SwiftProyecto from a document-loading library into a focused file discovery and project metadata library.

**Date**: 2025-12-14
**Status**: Planning Phase

---

## Executive Summary

SwiftProyecto currently has a confused responsibility: it tries to both discover files AND load them into SwiftData (GuionDocumentModel). This creates a circular dependency with SwiftCompartido and makes the library difficult to use.

**New Vision**: SwiftProyecto should be a **file manager** that:
- Discovers `.fountain`, `.fdx`, etc. files in folders/git repos
- Manages PROJECT.md metadata
- Provides security-scoped bookmarks for file access
- **Does NOT parse or store document content**

This refactoring enables Produciesta to use SwiftProyecto for file discovery while using SwiftCompartido for parsing/display, with clean separation of concerns.

---

## Phase 1: SwiftProyecto Refactoring (This PR)

**Objective**: Remove GuionDocumentModel dependency and simplify to file discovery only.

### 1.1. Remove SwiftCompartido Dependency

**Files to Modify**:
- `Package.swift` - Remove SwiftCompartido from dependencies

**Impact**:
- ✅ Eliminates circular dependency
- ✅ Reduces package size
- ✅ Makes SwiftProyecto standalone

**Breaking Change**: YES - Removes `loadFile()` API

---

### 1.2. Simplify ProjectFileReference Model

**File**: `Sources/SwiftProyecto/Models/ProjectFileReference.swift`

**Changes**:

```swift
// BEFORE
@Model
class ProjectFileReference {
    var relativePath: String
    var filename: String
    var fileExtension: String
    var lastKnownModificationDate: Date?
    var lastLoadedModificationDate: Date?
    var loadingState: FileLoadingState  // ❌ Remove
    var errorMessage: String?           // ❌ Remove

    @Relationship(deleteRule: .nullify)
    var loadedDocument: GuionDocumentModel?  // ❌ Remove

    @Relationship(inverse: \ProjectModel.fileReferences)
    var project: ProjectModel?
}

// AFTER
@Model
class ProjectFileReference {
    var relativePath: String
    var filename: String
    var fileExtension: String
    var lastKnownModificationDate: Date?
    var bookmarkData: Data?  // ✅ Add - store file-level bookmark

    @Relationship(inverse: \ProjectModel.fileReferences)
    var project: ProjectModel?
}
```

**Rationale**:
- `loadingState` is no longer needed (not loading documents)
- `loadedDocument` creates dependency on SwiftCompartido
- `bookmarkData` enables file-level security-scoped access
- `errorMessage` was only used for loading errors

**Migration Path**:
- Projects created with old version will have unused fields (ignored)
- No data loss - just unused properties

---

### 1.3. Remove FileLoadingState Enum

**File**: `Sources/SwiftProyecto/Models/FileLoadingState.swift`

**Action**: DELETE file entirely

**Rationale**: No longer needed without document loading

---

### 1.4. Refactor ProjectService

**File**: `Sources/SwiftProyecto/Services/ProjectService.swift`

**Methods to REMOVE**:
```swift
// ❌ Remove - document loading responsibility
func loadFile(_ fileRef: ProjectFileReference,
              in project: ProjectModel,
              progress: Progress? = nil) async throws

// ❌ Remove - document unloading responsibility
func unloadFile(_ fileRef: ProjectFileReference)

// ❌ Remove - document reimport responsibility
func reimportFile(_ fileRef: ProjectFileReference,
                  in project: ProjectModel,
                  progress: Progress? = nil) async throws
```

**Methods to ADD**:
```swift
// ✅ Add - get security-scoped URL for a file reference
func getSecureURL(for fileRef: ProjectFileReference,
                  in project: ProjectModel) throws -> URL

// ✅ Add - refresh bookmark if stale
func refreshBookmark(for fileRef: ProjectFileReference,
                    in project: ProjectModel) async throws

// ✅ Add - create file-level bookmark
func createFileBookmark(for fileRef: ProjectFileReference,
                       in project: ProjectModel) throws
```

**Methods to KEEP** (no changes):
```swift
// ✅ Keep - project creation
func createProject(at folderURL: URL,
                  title: String,
                  author: String? = nil,
                  season: Int? = nil,
                  episodes: Int? = nil) async throws -> ProjectModel

// ✅ Keep - project opening
func openProject(at folderURL: URL) async throws -> ProjectModel

// ✅ Keep - file discovery
func discoverFiles(for project: ProjectModel,
                  allowedExtensions: Set<String>? = nil) async throws
```

**New Responsibilities**:
1. **Bookmark Management**: Create and refresh bookmarks for individual files
2. **PROJECT.md Sync**: Keep PROJECT.md in sync with ProjectModel
3. **File Discovery**: Find screenplay files in project folder

---

### 1.5. Update FileSource Protocol

**File**: `Sources/SwiftProyecto/FileSource/FileSource.swift`

**Current Protocol**:
```swift
protocol FileSource {
    var sourceType: SourceType { get }
    var sourceName: String { get }
    var rootURL: URL { get }
    var bookmarkData: Data? { get }

    func discoverFiles(allowedExtensions: Set<String>?) throws -> [DiscoveredFile]
    func readFile(at relativePath: String) throws -> Data
    func modificationDate(for relativePath: String) throws -> Date?
}
```

**Changes**: NONE NEEDED

**Rationale**: FileSource is already focused on file discovery, not document loading

---

### 1.6. Enhance PROJECT.md Management

**File**: `Sources/SwiftProyecto/Services/ProjectService.swift`

**New Methods**:
```swift
extension ProjectService {
    /// Reads PROJECT.md and updates ProjectModel with latest metadata
    func syncProjectMetadata(_ project: ProjectModel) async throws {
        let fileSource = try project.fileSource()
        let data = try fileSource.readFile(at: "PROJECT.md")
        let content = String(data: data, encoding: .utf8)

        // Parse markdown front matter
        // Update project.title, project.author, project.season, etc.
        // Update project.projectMarkdownContent
    }

    /// Writes ProjectModel metadata back to PROJECT.md
    func saveProjectMetadata(_ project: ProjectModel) async throws {
        let fileSource = try project.fileSource()

        // Generate markdown with front matter
        let markdown = generateProjectMarkdown(project)

        // Write to PROJECT.md (requires writable FileSource)
        try await writeProjectFile(markdown, to: project)
    }

    /// Updates specific metadata fields
    func updateProjectMetadata(_ project: ProjectModel,
                              title: String? = nil,
                              author: String? = nil,
                              season: Int? = nil,
                              episodes: Int? = nil) async throws {
        if let title { project.title = title }
        if let author { project.author = author }
        if let season { project.season = season }
        if let episodes { project.episodes = episodes }

        try await saveProjectMetadata(project)
    }
}
```

**Rationale**: PROJECT.md is the single source of truth for project metadata

---

### 1.7. Add File-Level Bookmark Support

**File**: `Sources/SwiftProyecto/Services/ProjectService.swift`

**Implementation**:
```swift
extension ProjectService {
    /// Creates a security-scoped bookmark for a specific file
    func createFileBookmark(for fileRef: ProjectFileReference,
                           in project: ProjectModel) throws {
        // Get project folder bookmark
        guard let projectBookmark = project.sourceBookmarkData else {
            throw ProjectError.noBookmarkData
        }

        // Resolve project folder URL
        let projectURL = try BookmarkManager.resolveBookmark(projectBookmark)

        // Create file URL
        let fileURL = projectURL.appendingPathComponent(fileRef.relativePath)

        // Create file-specific bookmark
        let fileBookmark = try BookmarkManager.createBookmark(for: fileURL)

        // Store in ProjectFileReference
        fileRef.bookmarkData = fileBookmark

        try modelContext.save()
    }

    /// Gets a security-scoped URL for a file reference
    func getSecureURL(for fileRef: ProjectFileReference,
                     in project: ProjectModel) throws -> URL {
        // Try file-level bookmark first
        if let fileBookmark = fileRef.bookmarkData {
            do {
                return try BookmarkManager.resolveBookmark(fileBookmark)
            } catch {
                // File bookmark stale, try project bookmark
            }
        }

        // Fall back to project bookmark + relative path
        guard let projectBookmark = project.sourceBookmarkData else {
            throw ProjectError.noBookmarkData
        }

        let projectURL = try BookmarkManager.resolveBookmark(projectBookmark)
        return projectURL.appendingPathComponent(fileRef.relativePath)
    }

    /// Refreshes a stale file bookmark
    func refreshBookmark(for fileRef: ProjectFileReference,
                        in project: ProjectModel) async throws {
        let url = try getSecureURL(for: fileRef, in: project)
        let newBookmark = try BookmarkManager.createBookmark(for: url)
        fileRef.bookmarkData = newBookmark
        try modelContext.save()
    }
}
```

**Rationale**:
- File-level bookmarks provide direct access without resolving project bookmark
- Falls back to project bookmark + relative path if file bookmark stale
- Supports both folder-level and file-level security scoping

---

### 1.8. Update Tests

**Files to Modify**:
- `Tests/SwiftProyectoTests/ProjectServiceTests.swift`
- `Tests/SwiftProyectoTests/ProjectModelTests.swift`

**Tests to REMOVE**:
- `testLoadFile()`
- `testUnloadFile()`
- `testReimportFile()`
- `testLoadingStates()`
- Any tests that verify GuionDocumentModel creation

**Tests to ADD**:
```swift
func testCreateFileBookmark() async throws
func testGetSecureURL() async throws
func testRefreshBookmark() async throws
func testSyncProjectMetadata() async throws
func testSaveProjectMetadata() async throws
func testUpdateProjectMetadata() async throws
```

**Tests to UPDATE**:
- `testDiscoverFiles()` - Verify bookmarkData is created
- `testOpenProject()` - Verify PROJECT.md parsing
- `testCreateProject()` - Verify PROJECT.md creation

---

### 1.9. Update Documentation

**Files to Modify**:
- `README.md` - Update API examples
- `CLAUDE.md` - Update architecture description
- `.claude/WORKFLOW.md` - No changes needed

**Key Documentation Changes**:
```markdown
# BEFORE
SwiftProyecto loads screenplay files into SwiftData models.

# AFTER
SwiftProyecto discovers screenplay files and provides security-scoped access.
Apps use SwiftCompartido to parse and display the files.
```

**New Usage Example**:
```swift
// 1. Open project
let project = try await projectService.openProject(at: folderURL)

// 2. Discover files
try await projectService.discoverFiles(for: project)

// 3. Get file URL for parsing
for fileRef in project.fileReferences {
    let url = try projectService.getSecureURL(for: fileRef, in: project)

    // 4. App parses with SwiftCompartido
    let document = try await GuionParsedElementCollection(file: url)
}
```

---

### 1.10. Update Package Metadata

**Files to Modify**:
- `Package.swift` - Version, dependencies, description

**Changes**:
```swift
// BEFORE
let package = Package(
    name: "SwiftProyecto",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SwiftProyecto", targets: ["SwiftProyecto"]),
    ],
    dependencies: [
        .package(url: "SwiftCompartido", from: "6.0.0"),  // ❌ Remove
        .package(url: "https://github.com/groue/GRMustache.swift", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftProyecto",
            dependencies: [
                .product(name: "SwiftCompartido", package: "SwiftCompartido"),
                "GRMustache",
            ]
        ),
    ]
)

// AFTER
let package = Package(
    name: "SwiftProyecto",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SwiftProyecto", targets: ["SwiftProyecto"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRMustache.swift", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftProyecto",
            dependencies: ["GRMustache"]
        ),
    ]
)
```

---

## Phase 2: Produciesta Integration (Future PR)

**Objective**: Integrate refactored SwiftProyecto with Produciesta using new API.

### 2.1. Create DocumentRegistry Model

**File**: `Produciesta/Models/DocumentRegistry.swift` (NEW)

```swift
import SwiftData
import SwiftCompartido
import Foundation

@Model
class DocumentRegistry {
    /// Unique identifier
    var id: UUID = UUID()

    /// Link to ProjectModel (if file is part of a project)
    var projectID: UUID?

    /// Link to ProjectFileReference (if file is part of a project)
    var fileReferenceID: UUID?

    /// File URL (always present)
    var fileURL: URL

    /// Last time this document was opened
    var lastOpenedDate: Date?

    /// The parsed document (from SwiftCompartido)
    @Relationship(deleteRule: .cascade)
    var document: GuionDocumentModel?

    init(fileURL: URL,
         projectID: UUID? = nil,
         fileReferenceID: UUID? = nil,
         document: GuionDocumentModel? = nil) {
        self.fileURL = fileURL
        self.projectID = projectID
        self.fileReferenceID = fileReferenceID
        self.document = document
    }
}
```

**Rationale**:
- Links ProjectFileReference (SwiftProyecto) → GuionDocumentModel (SwiftCompartido)
- Supports both project files and standalone files
- Cascade delete ensures GuionDocumentModel is deleted with registry entry

---

### 2.2. Add DocumentRegistry to Schema

**File**: `Produciesta/ProduciestaApp.swift`

```swift
// BEFORE
let schema = Schema([
    GuionDocumentModel.self,
    GuionElementModel.self,
    TitlePageEntryModel.self,
    TypedDataStorage.self,
    CustomOutlineElement.self,
    VoiceCacheModel.self,
    CharacterVoiceMapping.self,
    CustomPageModel.self,
    ProjectModel.self,  // ✅ Keep from SwiftProyecto
])

// AFTER
let schema = Schema([
    GuionDocumentModel.self,
    GuionElementModel.self,
    TitlePageEntryModel.self,
    TypedDataStorage.self,
    CustomOutlineElement.self,
    VoiceCacheModel.self,
    CharacterVoiceMapping.self,
    CustomPageModel.self,
    ProjectModel.self,        // ✅ From SwiftProyecto
    ProjectFileReference.self, // ✅ From SwiftProyecto
    DocumentRegistry.self,     // ✅ NEW - links them together
])
```

---

### 2.3. Create DocumentLoader Component

**File**: `Produciesta/Views/DocumentLoader.swift` (NEW)

```swift
import SwiftUI
import SwiftData
import SwiftProyecto
import SwiftCompartido

/// Loads a document from a ProjectFileReference and displays it
struct DocumentLoader<Content: View>: View {
    let fileReference: ProjectFileReference
    let project: ProjectModel
    let content: (GuionDocumentModel) -> Content

    @Environment(\.modelContext) private var modelContext
    @State private var document: GuionDocumentModel?
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        Group {
            if let document {
                content(document)
            } else if isLoading {
                ProgressView("Loading \(fileReference.filename)...")
            } else if let error {
                ErrorView(error: error) {
                    Task { await loadDocument() }
                }
            } else {
                Color.clear
                    .task { await loadDocument() }
            }
        }
    }

    private func loadDocument() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Check if already loaded in DocumentRegistry
            let predicate = #Predicate<DocumentRegistry> { registry in
                registry.fileReferenceID == fileReference.id
            }
            let descriptor = FetchDescriptor(predicate: predicate)
            if let existing = try modelContext.fetch(descriptor).first,
               let doc = existing.document {
                self.document = doc
                existing.lastOpenedDate = Date()
                try modelContext.save()
                return
            }

            // 2. Get secure URL from SwiftProyecto
            let projectService = ProjectService(modelContext: modelContext)
            let url = try projectService.getSecureURL(for: fileReference, in: project)

            // 3. Parse with SwiftCompartido
            let progress = Progress(totalUnitCount: 100)
            let parsed = try await GuionParsedElementCollection(
                file: url,
                progress: progress
            )

            // 4. Convert to SwiftData
            let doc = await GuionDocumentModel.from(
                parsed,
                in: modelContext,
                generateSummaries: false,
                progress: progress
            )

            // 5. Create DocumentRegistry entry
            let registry = DocumentRegistry(
                fileURL: url,
                projectID: project.id,
                fileReferenceID: fileReference.id,
                document: doc
            )
            registry.lastOpenedDate = Date()
            modelContext.insert(registry)
            try modelContext.save()

            self.document = doc

        } catch {
            self.error = error
        }
    }
}
```

**Rationale**:
- Reusable component for loading any ProjectFileReference
- Caches loaded documents in DocumentRegistry
- Updates lastOpenedDate for recent items
- Handles loading states and errors

---

### 2.4. Create ProjectBrowserView

**File**: `Produciesta/Views/ProjectBrowserView.swift` (NEW)

```swift
import SwiftUI
import SwiftData
import SwiftProyecto
import SwiftCompartido

struct ProjectBrowserView: View {
    let project: ProjectModel

    @State private var selectedFile: ProjectFileReference?
    @State private var sidebarWidth: CGFloat = 250

    var body: some View {
        NavigationSplitView {
            ProjectFileTreeView(
                project: project,
                selection: $selectedFile
            )
            .navigationTitle(project.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sync Files") {
                        Task { await syncFiles() }
                    }
                }
            }
        } detail: {
            if let file = selectedFile {
                DocumentLoader(
                    fileReference: file,
                    project: project
                ) { document in
                    GuionDocumentView(document: document)
                }
            } else {
                ContentUnavailableView(
                    "No File Selected",
                    systemImage: "doc.text",
                    description: Text("Select a screenplay file from the sidebar")
                )
            }
        }
    }

    private func syncFiles() async {
        // Sync project files via SwiftProyecto
    }
}
```

---

### 2.5. Create ProjectFileTreeView

**File**: `Produciesta/Views/ProjectFileTreeView.swift` (NEW)

```swift
import SwiftUI
import SwiftData
import SwiftProyecto

struct ProjectFileTreeView: View {
    let project: ProjectModel
    @Binding var selection: ProjectFileReference?

    var body: some View {
        List(selection: $selection) {
            // Build tree from project.fileTree()
            ForEach(project.fileTree().children, id: \.id) { node in
                FileNodeRow(node: node, project: project, selection: $selection)
            }
        }
    }
}

struct FileNodeRow: View {
    let node: FileNode
    let project: ProjectModel
    @Binding var selection: ProjectFileReference?

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                ForEach(node.children, id: \.id) { child in
                    FileNodeRow(
                        node: child,
                        project: project,
                        selection: $selection
                    )
                }
            } label: {
                Label(node.name, systemImage: "folder")
            }
        } else {
            Button {
                selectFile(node)
            } label: {
                Label(node.name, systemImage: fileIcon(for: node.name))
            }
            .tag(fileReferenceID: node.fileReferenceID)
        }
    }

    private func selectFile(_ node: FileNode) {
        guard let refID = node.fileReferenceID else { return }

        // Fetch ProjectFileReference by ID
        let predicate = #Predicate<ProjectFileReference> { $0.id == refID }
        let descriptor = FetchDescriptor(predicate: predicate)

        if let fileRef = try? modelContext.fetch(descriptor).first {
            selection = fileRef
        }
    }

    private func fileIcon(for filename: String) -> String {
        if filename.hasSuffix(".fountain") { return "doc.text" }
        if filename.hasSuffix(".fdx") { return "doc.richtext" }
        return "doc"
    }
}
```

---

### 2.6. Update WelcomeView for Projects

**File**: `Produciesta/WelcomeView.swift`

**Add "Open Folder" Button**:
```swift
Section {
    Button {
        Task { await openFolder() }
    } label: {
        Label("Open Folder...", systemImage: "folder.badge.plus")
    }

    Button {
        isFileImporterPresented = true
    } label: {
        Label("Open File...", systemImage: "doc.badge.plus")
    }
}
```

**Add Folder Picker**:
```swift
@State private var isFolderPickerPresented = false

private func openFolder() async {
    #if os(macOS)
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false

    if panel.runModal() == .OK, let url = panel.url {
        await openProject(at: url)
    }
    #else
    isFolderPickerPresented = true
    #endif
}

private func openProject(at url: URL) async {
    let projectService = ProjectService(modelContext: modelContext)

    do {
        let project = try await projectService.openProject(at: url)
        try await projectService.discoverFiles(for: project)

        // Navigate to ProjectBrowserView
        // (Implementation depends on navigation pattern)

    } catch {
        // Handle error
    }
}
```

---

### 2.7. Migrate Existing Documents to DocumentRegistry

**File**: `Produciesta/Services/MigrationService.swift` (NEW)

```swift
import SwiftData
import SwiftCompartido

@MainActor
class MigrationService {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Migrates existing GuionDocumentModels to DocumentRegistry
    func migrateToDocumentRegistry() throws {
        // Fetch all documents that don't have a registry entry
        let documents = try modelContext.fetch(FetchDescriptor<GuionDocumentModel>())

        for document in documents {
            // Check if already has registry entry
            let predicate = #Predicate<DocumentRegistry> {
                $0.document?.id == document.id
            }
            let existing = try modelContext.fetch(
                FetchDescriptor(predicate: predicate)
            )

            if existing.isEmpty {
                // Create registry entry for existing document
                // Use sourceFileBookmark if available, otherwise create placeholder URL
                let url = document.sourceFileBookmark != nil
                    ? try? resolveBookmark(document.sourceFileBookmark!)
                    : URL(fileURLWithPath: "/unknown/\(document.id).fountain")

                let registry = DocumentRegistry(
                    fileURL: url ?? URL(fileURLWithPath: "/unknown"),
                    document: document
                )
                registry.lastOpenedDate = document.lastOpenedDate
                modelContext.insert(registry)
            }
        }

        try modelContext.save()
    }

    private func resolveBookmark(_ data: Data) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            bookmarkDataIsStale: &isStale
        )
        return url
    }
}
```

**Call from App Initialization**:
```swift
// ProduciestaApp.swift
.task {
    let migration = MigrationService(modelContext: modelContext)
    try? migration.migrateToDocumentRegistry()
}
```

---

### 2.8. Update Navigation for Projects

**File**: `Produciesta/IOSNavigationRoot.swift` and `MacOSNavigationRoot.swift`

**Add Route for Project View**:
```swift
enum AppRoute: Hashable {
    case welcome
    case documentList
    case project(ProjectModel)  // ✅ NEW
    case document(GuionDocumentModel)
}

// In body
switch route {
case .project(let project):
    ProjectBrowserView(project: project)
}
```

---

## Phase 3: Feature Enablement (Future PR)

**Objective**: Enable project features in Produciesta production builds.

### 3.1. Enable Feature Flag

**File**: `Produciesta/FeatureFlags.swift`

```swift
enum FeatureFlags {
    static let projectsEnabled = true  // Changed from false
}
```

### 3.2. Update UI for Projects

- Show/hide "Open Folder" based on feature flag
- Add project list view
- Add project metadata editing UI

### 3.3. Documentation Updates

- Update user documentation
- Add tutorial for project workflow
- Document project vs single-file workflows

---

## Testing Strategy

### Unit Tests (SwiftProyecto)

**Test Coverage**:
- ✅ Project creation and opening
- ✅ File discovery (local folder and git)
- ✅ PROJECT.md parsing and serialization
- ✅ Bookmark creation and refresh
- ✅ Security-scoped URL resolution
- ✅ File tree building

**Test Files**:
- `ProjectServiceTests.swift`
- `BookmarkManagerTests.swift`
- `FileSourceTests.swift`
- `FileNodeTests.swift`

### Integration Tests (Produciesta)

**Test Coverage**:
- ✅ DocumentRegistry creation
- ✅ DocumentLoader component
- ✅ ProjectBrowserView navigation
- ✅ File tree display
- ✅ Document loading and caching

**Test Files**:
- `DocumentRegistryTests.swift`
- `DocumentLoaderTests.swift`
- `ProjectBrowserViewTests.swift`

### UI Tests (Produciesta)

**Test Scenarios**:
- ✅ Open folder → Browse files → Load document
- ✅ Sync project → Detect new files
- ✅ Navigate between files in project
- ✅ Recent items for project files

---

## Migration Risks & Mitigation

### Risk 1: Breaking Changes to SwiftProyecto API

**Impact**: Produciesta currently doesn't use SwiftProyecto, so LOW risk

**Mitigation**:
- SwiftProyecto version bump to 2.0.0 (semantic versioning)
- Clear migration guide in CHANGELOG
- Deprecation warnings in 1.x (if needed)

### Risk 2: SwiftData Schema Changes

**Impact**: ProjectFileReference loses fields, could break existing projects

**Mitigation**:
- Unused fields are simply ignored (no migration needed)
- SwiftData handles schema evolution automatically
- Test with existing project files

### Risk 3: DocumentRegistry Migration

**Impact**: Existing GuionDocumentModels need registry entries

**Mitigation**:
- MigrationService creates registry entries on first launch
- Falls back gracefully if bookmark resolution fails
- No data loss - just creates new relationships

---

## Success Criteria

### Phase 1 (SwiftProyecto Refactoring)
- ✅ SwiftCompartido dependency removed
- ✅ All tests passing
- ✅ Documentation updated
- ✅ No circular dependencies
- ✅ Package builds on iOS and macOS
- ✅ CI/CD pipeline green

### Phase 2 (Produciesta Integration)
- ✅ DocumentRegistry working
- ✅ DocumentLoader can load project files
- ✅ ProjectBrowserView displays file tree
- ✅ Navigation between files works
- ✅ Recent items show project files
- ✅ All existing features still work

### Phase 3 (Feature Enablement)
- ✅ Users can open folders
- ✅ Users can browse multi-file projects
- ✅ PROJECT.md syncs correctly
- ✅ Git repositories work
- ✅ User documentation complete

---

## Timeline Estimate

### Phase 1 (This PR)
- **Effort**: 4-6 hours
- **Complexity**: Medium
- **Files Changed**: ~10 files
- **Tests**: ~15 test methods to update

### Phase 2 (Future PR)
- **Effort**: 8-12 hours
- **Complexity**: High
- **Files Changed**: ~15 new files, ~5 modified
- **Tests**: ~25 new test methods

### Phase 3 (Future PR)
- **Effort**: 4-6 hours
- **Complexity**: Low
- **Files Changed**: ~5 files
- **Tests**: ~10 UI tests

**Total**: 16-24 hours across 3 PRs

---

## Open Questions

1. **Should SwiftProyecto support file writing?**
   - Currently read-only via FileSource
   - PROJECT.md updates would need write support
   - **Decision**: Add in Phase 1 if needed

2. **Should file-level bookmarks be created eagerly or lazily?**
   - Eager: Create during file discovery
   - Lazy: Create on first access
   - **Decision**: Lazy (better performance for large projects)

3. **Should DocumentRegistry track parse errors?**
   - Could store last parse error for debugging
   - **Decision**: Add in Phase 2 if needed

4. **Should projects support nested folders?**
   - FileNode already supports hierarchy
   - **Decision**: Yes, fully supported

---

## Appendix: File Changes Summary

### Phase 1: SwiftProyecto Refactoring

| File | Action | LOC Changed |
|------|--------|-------------|
| `Package.swift` | Modify | -5 |
| `ProjectFileReference.swift` | Modify | -15, +5 |
| `FileLoadingState.swift` | Delete | -20 |
| `ProjectService.swift` | Modify | -200, +100 |
| `ProjectServiceTests.swift` | Modify | -100, +80 |
| `README.md` | Modify | ~50 |
| `CLAUDE.md` | Modify | ~30 |
| **TOTAL** | | **~-150 LOC** |

### Phase 2: Produciesta Integration

| File | Action | LOC Changed |
|------|--------|-------------|
| `DocumentRegistry.swift` | Create | +60 |
| `DocumentLoader.swift` | Create | +150 |
| `ProjectBrowserView.swift` | Create | +80 |
| `ProjectFileTreeView.swift` | Create | +120 |
| `MigrationService.swift` | Create | +80 |
| `ProduciestaApp.swift` | Modify | +10 |
| `WelcomeView.swift` | Modify | +80 |
| `IOSNavigationRoot.swift` | Modify | +30 |
| `MacOSNavigationRoot.swift` | Modify | +30 |
| Tests | Create | +300 |
| **TOTAL** | | **~+940 LOC** |

---

## Conclusion

This refactoring transforms SwiftProyecto from a confused "file loader" into a focused "file manager". By removing the GuionDocumentModel dependency, we create clean separation:

- **SwiftProyecto**: Discovers files, manages PROJECT.md
- **SwiftCompartido**: Parses files, displays documents
- **Produciesta**: Integrates both libraries

Phase 1 (this PR) is a **net deletion** of ~150 lines of code while improving clarity. Phase 2 adds ~940 lines to Produciesta to enable the full project browsing experience.

The key insight: **Stop fighting SwiftData**. Let each library own its models, and use Produciesta as the integration layer with DocumentRegistry linking them together.

# Project Feature - Implementation Strategy

## Architectural Decisions

### Library Boundaries

After analyzing the "Project" concept, here's the recommended architecture:

```
┌─────────────────────────────────────────────────────────┐
│ Produciesta (iOS/macOS App)                             │
│ - UI Views (ProjectView, SingleFileView)                │
│ - SwiftUI integration                                   │
│ - App-level coordination                                │
└─────────────────┬───────────────────────────────────────┘
                  │
        ┌─────────┴──────────┬──────────────────┐
        │                    │                  │
┌───────▼────────┐  ┌────────▼────────┐  ┌─────▼──────┐
│ SwiftProyecto  │  │ SwiftCompartido │  │ SwiftHablare│
│ (NEW)          │  │ (EXISTING)      │  │ (EXISTING)  │
│                │  │                 │  │             │
│ - ProjectModel │  │ - GuionDocument │  │ - Voice Gen │
│ - File State   │  │ - Parsing       │  │ - Providers │
│ - Container    │  │ - PROJECT.md    │  └─────────────┘
│   Factory      │  │   Parser        │
│ - Project      │  │ - Folder Scan   │
│   Service      │  │   Utils         │
└────────────────┘  └─────────────────┘
```

### Decision: Create SwiftProyecto Library

**Rationale**:
1. **Separation of Concerns**: Project management is distinct from screenplay data structures (SwiftCompartido's domain)
2. **Testability**: Can test project logic in isolation without UI dependencies
3. **Reusability**: Could be used by other apps (future Produciesta iPad-specific version, CLI tools, etc.)
4. **Regression Safety**: Changes to project code won't affect screenplay parsing/rendering

**What Goes Where**:

#### SwiftCompartido (Extend Existing)
- ✅ **PROJECT.md parsing** - Leverage existing markdown + YAML front matter parser
- ✅ **ProjectFrontMatter struct** - Codable model for PROJECT.md metadata
- ✅ **File scanning utilities** - Generic folder enumeration (no SwiftData dependency)
- ❌ **No SwiftData models** - Keep SwiftCompartido data-agnostic

**New Types**:
```swift
// SwiftCompartido/Models/ProjectFrontMatter.swift
public struct ProjectFrontMatter: Codable {
    public let type: String  // Must be "project"
    public let title: String
    public let author: String
    public let created: Date
    public let description: String?
    public let season: Int?
    public let episodes: Int?
    public let genre: String?
    public let tags: [String]?
}

// SwiftCompartido/Services/ProjectMarkdownParser.swift
public struct ProjectMarkdownParser {
    public static func parse(fileURL: URL) throws -> (frontMatter: ProjectFrontMatter, body: String)
    public static func generate(frontMatter: ProjectFrontMatter, body: String) -> String
}

// SwiftCompartido/Services/FileScanner.swift
public struct FileScanner {
    public static func scanForFiles(
        in directory: URL,
        extensions: [String],
        recursive: Bool = true
    ) async throws -> [DiscoveredFile]
}

public struct DiscoveredFile {
    public let relativePath: String
    public let filename: String
    public let fileExtension: String
    public let modificationDate: Date
}
```

#### SwiftProyecto (New Library)
- ✅ **SwiftData models**: ProjectModel, ProjectFileReference
- ✅ **Business logic**: Project lifecycle, file state management
- ✅ **Container strategy**: Dual container selection
- ✅ **Service layer**: ProjectManager, project CRUD operations
- ❌ **No UI components** - Keep library UI-agnostic

**Core Types**:
```swift
// SwiftProyecto/Models/ProjectModel.swift
@Model
public final class ProjectModel {
    public var id: UUID
    public var title: String
    public var author: String
    // ... (from PROJECT_ENTITY.md)
}

// SwiftProyecto/Models/ProjectFileReference.swift
@Model
public final class ProjectFileReference {
    public var id: UUID
    public var relativePath: String
    public var loadingState: FileLoadingState
    // ... (from PROJECT_ENTITY.md)
}

// SwiftProyecto/Models/FileLoadingState.swift
public enum FileLoadingState: String, Codable {
    case notLoaded, loading, loaded, stale, missing, error
}

// SwiftProyecto/Services/ModelContainerFactory.swift
public enum DocumentContext {
    case singleFile
    case project(URL)
}

public class ModelContainerFactory {
    public static func createContainer(for context: DocumentContext) throws -> ModelContainer
}

// SwiftProyecto/Services/ProjectManager.swift
@MainActor
public class ProjectManager {
    public func createProject(at url: URL, title: String, author: String) async throws -> ProjectModel
    public func openProject(at url: URL) async throws -> ProjectModel
    public func syncProject(_ project: ProjectModel) async throws
    public func loadFile(_ fileRef: ProjectFileReference, in project: ProjectModel) async throws
}
```

#### Produciesta (App Layer)
- ✅ **UI Views**: All SwiftUI views
- ✅ **View Models**: @Observable classes for view state
- ✅ **App Integration**: Window management, menu items, file pickers
- ✅ **Feature coordination**: Tie together libraries

---

## Incremental Implementation Plan

### Principle: Each Phase is Independently Testable & Deployable

Every phase should:
1. Have **unit tests** that verify functionality
2. Have **regression tests** ensuring existing features work
3. Be **deployable** (even if feature-flagged or hidden)
4. Add **measurable value** (even if internal/architectural)

---

### Phase 0: Foundation (No Behavior Changes)

**Goal**: Set up SwiftProyecto library, add PROJECT.md parsing to SwiftCompartido

**Deliverables**:
- [ ] Create `SwiftProyecto` Swift package
- [ ] Add `ProjectFrontMatter` struct to SwiftCompartido
- [ ] Add `ProjectMarkdownParser` to SwiftCompartido
- [ ] Add `FileScanner` to SwiftCompartido
- [ ] Unit tests for all new SwiftCompartido types
- [ ] Link SwiftProyecto to Produciesta project

**Success Criteria**:
- ✅ All existing tests pass (regression)
- ✅ Can parse PROJECT.md file and extract front matter
- ✅ Can generate PROJECT.md from struct
- ✅ Can scan folder for screenplay files
- ✅ No changes to app UI or behavior

**Estimated Effort**: 1-2 days

---

### Phase 1: SwiftData Models (No UI Changes)

**Goal**: Define project data models in SwiftProyecto

**Deliverables**:
- [ ] `ProjectModel` SwiftData model
- [ ] `ProjectFileReference` SwiftData model
- [ ] `FileLoadingState` enum
- [ ] Extend `GuionDocumentModel` with optional project relationships
- [ ] Unit tests for model creation, relationships, and queries
- [ ] Test fixture projects for testing

**Success Criteria**:
- ✅ Can create ProjectModel in SwiftData
- ✅ Can create ProjectFileReference linked to ProjectModel
- ✅ Can query projects by various criteria
- ✅ Relationships cascade correctly on delete
- ✅ All existing tests pass (regression)
- ✅ No changes to app UI or behavior

**Estimated Effort**: 2-3 days

---

### Phase 2: Container Strategy (No UI Changes)

**Goal**: Implement dual SwiftData container selection

**Deliverables**:
- [ ] `DocumentContext` enum
- [ ] `ModelContainerFactory` with container selection logic
- [ ] Update `ProduciestaApp.swift` to support dual containers
- [ ] Unit tests for container creation (app-wide vs project-local)
- [ ] Integration tests: Create container, insert data, query data

**Success Criteria**:
- ✅ Can create app-wide container (existing behavior)
- ✅ Can create project-local container at `.cache/` path
- ✅ Containers are isolated (data doesn't leak between them)
- ✅ All existing tests pass (regression)
- ✅ No changes to app UI or behavior (containers created but not used yet)

**Estimated Effort**: 2-3 days

---

### Phase 3: Project Service Layer (No UI Changes)

**Goal**: Implement ProjectManager for project CRUD operations

**Deliverables**:
- [ ] `ProjectManager` service class
- [ ] `createProject(at:title:author:)` - Create PROJECT.md + .cache + ProjectModel
- [ ] `openProject(at:)` - Load existing project
- [ ] `syncProject(_:)` - Scan folder, update file references
- [ ] `loadFile(_:in:)` - Parse file, create GuionDocumentModel in project container
- [ ] `unloadFile(_:in:)` - Remove from SwiftData, keep file on disk
- [ ] Unit tests for all operations
- [ ] Integration tests: Full project lifecycle (create → add files → load → unload → sync)

**Success Criteria**:
- ✅ Can create new project with PROJECT.md and .cache/
- ✅ Can open existing project and load ProjectModel from .cache/
- ✅ Can scan folder and create ProjectFileReference records
- ✅ Can load individual file into project SwiftData
- ✅ Can detect stale/missing files during sync
- ✅ All existing tests pass (regression)
- ✅ No changes to app UI or behavior (services exist but not called)

**Estimated Effort**: 3-5 days

---

### Phase 4: Single File View Refactor (UI Changes, Backward Compatible)

**Goal**: Extract existing document view into "Single File Mode" without breaking anything

**Deliverables**:
- [ ] Create `SingleFileView.swift` - Wrapper around existing `GuionDocumentView`
- [ ] Simplified layout: No sidebar, full-width screenplay view
- [ ] Update app entry point to route single file opens to `SingleFileView`
- [ ] Regression tests: Verify all existing single-file workflows work identically

**Success Criteria**:
- ✅ Opening a single file shows simplified view (no sidebar)
- ✅ All existing features work: Outline, Characters, Locations, Library tabs
- ✅ Audio generation works identically
- ✅ Export works identically
- ✅ Existing single-file documents load correctly
- ✅ All existing tests pass (regression)
- ✅ **User sees no functional difference** (just cleaner layout)

**Estimated Effort**: 2-3 days

---

### Phase 5: Project View Skeleton (New UI)

**Goal**: Create ProjectView UI without lazy loading (auto-load all files initially)

**Deliverables**:
- [ ] `ProjectView.swift` - Rename/refactor DocumentListView
- [ ] `ProjectSidebarView.swift` - Project info + file list (all files loaded)
- [ ] `ProjectFileRowView.swift` - Basic file row (no state indicators yet)
- [ ] `CreateProjectSheet.swift` - New project creation dialog
- [ ] "Open Folder" menu item → Shows folder picker → Creates/opens project
- [ ] Integration test: Create project, verify files auto-load

**Success Criteria**:
- ✅ Can create project from folder via UI
- ✅ Can open existing project via UI
- ✅ Files in project folder are discovered and auto-loaded
- ✅ Can click file in sidebar to view screenplay
- ✅ All existing tests pass (regression)
- ✅ Single file mode still works identically

**Estimated Effort**: 4-5 days

---

### Phase 6: Lazy Loading (File State Indicators)

**Goal**: Implement lazy loading with visual state indicators

**Deliverables**:
- [ ] Update `ProjectFileRowView` with 4 states: loaded, notLoaded, stale, missing
- [ ] "Load File" button for notLoaded files
- [ ] "Reload File" button for stale files
- [ ] Grey out unloaded files
- [ ] Update `ProjectManager.syncProject` to NOT auto-load, just discover
- [ ] Integration tests: Verify lazy loading behavior
- [ ] Performance test: 100-file project (should load instantly, only parse on demand)

**Success Criteria**:
- ✅ Opening project shows files greyed out (not loaded)
- ✅ Clicking "Load File" parses and loads screenplay
- ✅ File state updates correctly (notLoaded → loading → loaded)
- ✅ Stale detection works (modified file shows reload indicator)
- ✅ Missing files shown with error state
- ✅ Large projects (100+ files) open quickly
- ✅ All existing tests pass (regression)

**Estimated Effort**: 3-4 days

---

### Phase 7: Advanced Project Features

**Goal**: Polish and additional features

**Deliverables**:
- [ ] "Load All Files" button
- [ ] "Unload File" action (remove from cache, keep on disk)
- [ ] "Delete File" action (remove from disk + cache)
- [ ] Project settings sheet (edit PROJECT.md metadata)
- [ ] .gitignore auto-generation
- [ ] Nested folder UI (folder grouping in file list)
- [ ] Sync button with progress indicator
- [ ] "Locate..." button for missing files

**Success Criteria**:
- ✅ All workflows from PROJECT_ENTITY.md work
- ✅ Can manage project metadata via UI
- ✅ Can handle all edge cases gracefully
- ✅ All 27 success criteria from requirements met
- ✅ All existing tests pass (regression)

**Estimated Effort**: 5-7 days

**Note**: After Phase 7 is complete and all tests pass, we ship the complete Projects feature to all users.

---

## Testing Strategy

### Unit Tests (Per Phase)

**SwiftCompartido**:
- PROJECT.md parsing (valid front matter, invalid YAML, missing fields)
- PROJECT.md generation (roundtrip: parse → generate → parse)
- File scanning (flat folders, nested folders, exclude .cache, exclude PROJECT.md)

**SwiftProyecto**:
- ProjectModel CRUD
- ProjectFileReference relationships
- FileLoadingState transitions
- ModelContainerFactory (app-wide vs project-local paths)
- ProjectManager operations (create, open, sync, load, unload)

**Produciesta**:
- View model logic
- UI state transitions
- Error handling (missing files, corrupted .cache, stale bookmarks)

### Integration Tests (Per Phase)

**End-to-End Workflows**:
1. Create project → Scan files → Load file → Generate audio → Export
2. Open existing project → Detect stale files → Reload → Verify changes
3. Move project folder → Detect stale bookmark → Relocate → Continue working
4. Large project (100+ files) → Open quickly → Load selectively → No performance degradation

### Regression Tests (Every Phase)

**Critical Existing Functionality**:
- Single file import (all 11 formats)
- Audio generation (individual + batch)
- Character voice mapping
- Library export (concatenate audio)
- Custom outline elements
- Lyrics handling

**Automated Regression Suite**:
- Run all existing tests after each phase
- Manual smoke test: Import fountain → Generate audio → Export library
- Performance baseline: Track startup time, import time, generation time

---

## Risk Mitigation

### Risk 1: SwiftData Container Corruption

**Mitigation**:
- Backup .cache/ before destructive operations
- Validate container health on open (detect corruption early)
- Provide "Reset Cache" escape hatch

### Risk 2: Performance Degradation (Large Projects)

**Mitigation**:
- Lazy loading reduces startup time
- Virtualized lists prevent UI slowdown
- Background parsing prevents main thread blocking
- Performance tests in CI pipeline

### Risk 3: Breaking Existing Single-File Workflow

**Mitigation**:
- Phase 4 refactor is backward-compatible
- Regression tests run after every phase
- Feature flags allow rollback if needed

### Risk 4: Complexity in Container Selection Logic

**Mitigation**:
- DocumentContext enum makes decision explicit
- Unit tests cover all container selection paths
- Factory pattern isolates complexity

---

## Deployment Strategy

### Development Approach

Since we don't have a large user base, we'll develop all phases in sequence and ship the complete feature when Phase 7 is done.

**Timeline**:
1. **Phase 0-3**: Foundation work (no UI changes, no user impact)
2. **Phase 4-7**: UI implementation and polish
3. **Single Release**: Ship all phases together when Phase 7 is complete

**Benefits of This Approach**:
- No complexity of feature flags
- Users get complete, polished experience
- Easier to test as cohesive whole
- Simpler documentation (one set of instructions)

### Migration Strategy

**Existing Users**:
- Single-file documents continue working identically (backward compatible)
- No data migration required
- Users can continue using single-file workflow indefinitely
- Projects are opt-in: Only created when user opens a folder

**New Capabilities**:
- "Open File" menu item → Single File View (existing behavior, cleaner UI)
- "Open Folder" menu item → Project View (new feature)
- File > Recent shows both files and folders

### Rollback Plan

Since SwiftData migrations are additive:
- New `ProjectModel` and `ProjectFileReference` don't affect existing data
- Can revert to previous version if critical bug found
- Users' existing single-file documents remain intact

---

## Decisions

1. **Library Naming**: ✅ **SwiftProyecto** (approved)
2. **Test Coverage Target**: ✅ **80%+ for SwiftProyecto** (approved)
3. **Feature Flags**: ✅ **No feature flags** - Ship complete feature to all users at once
4. **CI Integration**: Run tests on every commit (fast + slow test suites)
5. **Documentation**: Generate API docs for SwiftProyecto using DocC

---

## Next Steps

1. **Review & Approve** this implementation strategy
2. **Create SwiftProyecto** package (Phase 0)
3. **Set up CI pipeline** for new library
4. **Begin Phase 0 implementation**

---

**Estimated Total Effort**: 20-30 days (4-6 weeks with testing)

**First Shippable Increment**: Phase 4 (Single File View refactor) - ~1.5 weeks

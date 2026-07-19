---
state: completed
mission: projectbrowser-library-01
updated: 2026-07-18
type: execution-plan
feature_name: ProjectBrowser Library (Reusable Project Window UI)
starting_point_commit: 013a67f
mission_branch: mission/projectbrowser-library/01
iteration: 1
created_date: 2026-07-17
completed_date: 2026-07-18
target_platforms: macOS 26.0+, iOS 26.0+
base_dependencies:
  - SwiftProyecto (PROJECT.md discovery)
  - SwiftCompartido (document models)
---

# ProjectBrowser Library – Execution Plan

**Mission Summary**: Build a reusable, generic **ProjectWindow** SwiftUI component that enables consumers to browse any directory, register custom file type handlers, and render file contents. Demonstrate integration in standalone **Proyecto** app. Decouples file browsing UI from domain logic, making it reusable across projects.

**Scope**: Phase 1 (Core Library + App Integration) – Basic file discovery, master-detail layout, handler registry, file actions, lazy loading, and working Proyecto app integration.

---

## Terminology

**Mission** — The definable scope of work that decomposes into multiple sorties. This mission builds the ProjectBrowser library and integrates it into Produciesta.

**Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. Each sortie has entry/exit criteria and bounded scope.

**Work Unit** — A grouping of related sorties. This plan organizes sorties into 6 work units, each representing a major component or integration step.

---

## Work Unit Dependencies

```
┌──────────────────────────┐
│ WU1: Core Data Models    │  ← Everything depends on this
└────────────┬─────────────┘
             │
    ┌────────┼────────┬────────────────────┐
    ▼        ▼        ▼                    ▼
  WU2:   WU3:     WU4:              WU6:
  File   Views    Container         Tests
  Disc.  Layer    & Actions         & Docs
    │        │        │                │
    └────────┼────────┴────────────────┘
             ▼
        ┌─────────────┐
        │ WU5: Prod.  │  ← Integration (last)
        │ Integration │
        └─────────────┘
```

---

## Work Units

### WU1: Core Data Models
**Goal**: Define all data structures that components will use.
**Sorties**: 4
**Duration**: ~1 day

#### S1.1 – Create ProjectFile & Supporting Models
**Entry Criteria**:
- Repository at `013a67f` with SwiftProyecto v4.4.0
- No production code changes yet

**Goal**: Implement `ProjectFile`, `FileLoadingState`, `ProjectFileContents`, and `ProjectMetadata` models in `Sources/ProjectBrowser/Models/`.

**Exit Criteria**:
- ✅ `Models/ProjectFile.swift` compiles with all properties from spec § 3.1 (id, name, relativePath, fileExtension, isDirectory, modifiedDate, isLoaded, loadingState, error)
- ✅ `Models/FileLoadingState.swift` defines all enum cases (notLoaded, loading, loaded, stale, error)
- ✅ `Models/ProjectFileContents.swift` compiles with `file`, `data`, `text`, `loadedAt`, `isStale` properties
- ✅ `Models/ProjectMetadata.swift` compiles with `title`, `author`, `description`, `created` properties
- ✅ All models conform to `Codable`, `Hashable`, `Equatable` as appropriate
- ✅ `ProjectFile.hasKnownHandler` property stub (handler lookup deferred to WU3)
- ✅ `ProjectFile.displayName` property stub (truncation deferred to WU3)
- ✅ No compilation errors
- ✅ Runs `swift_package_build` successfully on macOS target

**Subtasks**:
1. Create `ProjectBrowser` target in Package.swift if not present
2. Create Models directory and all model files
3. Define `ProjectFile: Identifiable, Hashable` with all required properties
4. Define `FileLoadingState` enum with all cases
5. Define `ProjectFileContents` struct
6. Define `ProjectMetadata` struct
7. Build and verify no errors

---

#### S1.2 – Create FileTypeHandler & Callback Models
**Entry Criteria**:
- S1.1 complete (ProjectFile model available)

**Goal**: Implement `FileTypeHandler`, `FileSelectionCallback`, `FileLoaderCallback`, `FileActionCallback`, and `FileAction` enum.

**Exit Criteria**:
- ✅ `Models/FileTypeHandler.swift` compiles
- ✅ `Models/FileAction.swift` defines all cases (reload, showInFinder, delete, custom)
- ✅ Callback typealiases compile and reference correct signatures
- ✅ Handler view builder closure has signature `(ProjectFile) -> AnyView`
- ✅ FileLoaderCallback has signature `(ProjectFile) async throws -> ProjectFileContents`
- ✅ FileActionCallback has signature `(ProjectFile, FileAction) -> Void`
- ✅ No compilation errors

---

#### S1.3 – Add Model Unit Tests
**Entry Criteria**:
- S1.1 & S1.2 complete (all models defined)

**Goal**: Write unit tests for all data models to verify equality, hashing, and state transitions.

**Exit Criteria**:
- ✅ `Tests/ProjectFileTests.swift` created with comprehensive model tests
- ✅ ProjectFile equality and hashing tests
- ✅ FileLoadingState enum coverage
- ✅ All tests pass when run via `swift_package_test`
- ✅ Test coverage > 80% for model code

---

#### S1.4 – Verify Models in Package
**Entry Criteria**:
- S1.1, S1.2, S1.3 complete

**Goal**: Confirm all models are exported in package public API and no circular dependencies.

**Exit Criteria**:
- ✅ All model types are public and documented
- ✅ Package builds cleanly: `swift_package_build --scheme SwiftProyecto`
- ✅ No unused imports or circular dependencies
- ✅ XcodeBuild integration successful

---

### WU2: File Discovery Service
**Goal**: Implement directory scanning, file tree building, and optional PROJECT.md integration.
**Sorties**: 3
**Duration**: ~2 days

#### S2.1 – Create ProjectFileDiscovery Service
**Entry Criteria**:
- WU1 complete (ProjectFile model available)

**Goal**: Implement `ProjectFileDiscovery` service that recursively scans a directory and builds a file tree.

**Exit Criteria**:
- ✅ `Services/ProjectFileDiscovery.swift` created with static `discover(at:)` method
- ✅ Returns flat array of ProjectFile sorted by: folders first, then alphabetically
- ✅ relativePath computed correctly relative to root directory
- ✅ fileExtension extracted correctly
- ✅ isDirectory property set correctly
- ✅ modifiedDate retrieved from file attributes
- ✅ Respects default ignore patterns (.git, node_modules, .xcodeproj, etc.)
- ✅ Handles symlinks gracefully (doesn't follow)
- ✅ Async/await compatible; no blocking calls
- ✅ Unit tests pass for various directory structures

---

#### S2.2 – Add PROJECT.md Metadata Loading
**Entry Criteria**:
- S2.1 complete (ProjectFileDiscovery service)

**Goal**: Extend `ProjectMetadata.load(from:)` to parse PROJECT.md if present in directory.

**Exit Criteria**:
- ✅ `ProjectMetadata.load(from:)` implemented as async
- ✅ Returns `ProjectMetadata?` (nil if no PROJECT.md)
- ✅ Extracts title, author, description from PROJECT.md if present
- ✅ Falls back to nil gracefully if PROJECT.md doesn't exist
- ✅ Handles parsing errors (malformed YAML, missing keys)
- ✅ Unit tests verify metadata extraction

---

#### S2.3 – Test Discovery with Real Directories
**Entry Criteria**:
- S2.1 & S2.2 complete

**Goal**: Integration test that discovers files in SwiftProyecto's own source tree and deeply nested directories.

**Exit Criteria**:
- ✅ Test creates temp directory with files
- ✅ Discovers all files and folders correctly
- ✅ Builds file tree with correct paths
- ✅ Handles deeply nested directories (5+ levels)
- ✅ Ignores .git, .build, .xcodeproj
- ✅ Loads PROJECT.md metadata if present
- ✅ Test runs successfully with `swift_package_test`

---

### WU3: View Layer – Components
**Goal**: Implement all SwiftUI view components (file tree, headers, detail pane, etc.).
**Sorties**: 6
**Duration**: ~3-4 days

#### S3.1 – Create FileTreeView (Hierarchical List)
**Entry Criteria**:
- WU1 complete (ProjectFile model)
- S2.1 complete (ProjectFileDiscovery)

**Goal**: Implement `FileTreeView` that displays files in a hierarchical list with disclosure groups.

**Exit Criteria**:
- ✅ `Views/FileTreeView.swift` created
- ✅ Accepts `@Binding<Set<UUID>>` for expanded folders
- ✅ Accepts `@Binding<ProjectFile?>` for selection
- ✅ Displays folders as DisclosureGroups with expand/collapse
- ✅ Shows files with system icons (doc.text, folder.fill, etc.)
- ✅ Highlights selected file with blue background
- ✅ Loading state shows spinner icon
- ✅ Error state shows warning icon
- ✅ Compiles and renders without crashes
- ✅ Context menu available (basic structure for S3.5)

---

#### S3.2 – Create ProjectHeader View
**Entry Criteria**:
- WU1 complete (ProjectFile model)
- S2.2 complete (ProjectMetadata)

**Goal**: Implement `ProjectHeader` that displays project metadata (title, file count, author).

**Exit Criteria**:
- ✅ `Views/ProjectHeader.swift` created
- ✅ Displays project title (from param or PROJECT.md)
- ✅ Shows file count and folder count
- ✅ Shows author and description if available
- ✅ Responsive layout for macOS and iOS
- ✅ Compiles and previews without errors

---

#### S3.3 – Create ProjectActionBar View
**Entry Criteria**:
- WU1 complete (ProjectFile model)

**Goal**: Implement `ProjectActionBar` with action buttons (Sync, Import, Load All, Unload All).

**Exit Criteria**:
- ✅ `Views/ProjectActionBar.swift` created
- ✅ Accepts callback closures for each action
- ✅ Shows buttons: Sync, Import, Load All, Unload All
- ✅ Buttons are platform-aware (macOS has toolbar, iOS has button group)
- ✅ Buttons disabled/enabled based on state
- ✅ Compiles and previews

---

#### S3.4 – Create DefaultContentViews (Fallbacks)
**Entry Criteria**:
- WU1 complete (ProjectFile model)

**Goal**: Implement default content views for unsupported files and loading/error states.

**Exit Criteria**:
- ✅ `Views/DefaultContentViews.swift` created
- ✅ `PlainTextContentView` renders text files
- ✅ `UnsupportedFileView` shows "No handler" message
- ✅ `LoadingView` shows spinner with filename
- ✅ `ErrorView` shows error message and retry button
- ✅ All views handle empty states gracefully
- ✅ Compiles and previews

---

#### S3.5 – Create ProjectBrowserSidebar
**Entry Criteria**:
- S3.1 complete (FileTreeView)
- S3.2 complete (ProjectHeader)
- S3.3 complete (ProjectActionBar)

**Goal**: Assemble sidebar combining header, file tree, and action bar.

**Exit Criteria**:
- ✅ `Views/ProjectBrowserSidebar.swift` created
- ✅ Composes ProjectHeader, FileTreeView, ProjectActionBar vertically
- ✅ Passes selection and expansion state to child views
- ✅ Handles callbacks from action bar
- ✅ Responsive for macOS and iOS
- ✅ Compiles and previews without errors

---

#### S3.6 – Create ProjectDetailPane
**Entry Criteria**:
- S3.4 complete (DefaultContentViews)
- WU1 complete (ProjectFile model)

**Goal**: Implement `ProjectDetailPane` that displays file contents via handler or fallback.

**Exit Criteria**:
- ✅ `Views/ProjectDetailPane.swift` created
- ✅ Accepts selected ProjectFile (or nil)
- ✅ Accepts handler registry `[String: (ProjectFile) -> AnyView]`
- ✅ Shows "Select a file" when nil
- ✅ Looks up handler by fileExtension and calls view builder
- ✅ Shows UnsupportedFileView if no handler
- ✅ Shows file metadata (size, modified date)
- ✅ Compiles and previews

---

### WU4: Main Container & Platform Layout
**Goal**: Build ProjectWindow container with NavigationSplitView (macOS) and NavigationStack (iOS).
**Sorties**: 4
**Duration**: ~3 days

#### S4.1 – Create ProjectWindow Container (macOS Layout)
**Entry Criteria**:
- S3.5 complete (ProjectBrowserSidebar)
- S3.6 complete (ProjectDetailPane)
- WU2 complete (file discovery)

**Goal**: Implement `ProjectWindow` main view with NavigationSplitView for macOS.

**Exit Criteria**:
- ✅ `ProjectWindow.swift` created with public API from spec § 4.1
- ✅ Accepts directoryURL, handlers dict, projectTitle, callbacks
- ✅ Uses NavigationSplitView with two columns (sidebar + detail)
- ✅ Left sidebar is ProjectBrowserSidebar
- ✅ Right detail is ProjectDetailPane
- ✅ Stores file tree in @State
- ✅ Stores selection in @State
- ✅ Stores expanded folders in @State
- ✅ Compiles and renders without crashes
- ✅ File discovery triggered on view appear

---

#### S4.2 – Implement File Actions (Reload, Delete, Show in Finder)
**Entry Criteria**:
- S4.1 complete (ProjectWindow)
- WU1 complete (FileAction enum)

**Goal**: Implement file action handling in ProjectWindow (reload, delete, showInFinder, custom).

**Exit Criteria**:
- ✅ File actions dispatch correctly from detail pane
- ✅ Reload action updates file contents
- ✅ Delete action removes file from tree and disk
- ✅ Show in Finder opens file in macOS Finder (macOS only)
- ✅ Custom actions pass through to onFileAction callback
- ✅ Errors handled gracefully (file not found, permissions)
- ✅ Tree updates after delete
- ✅ Unit tests verify all actions

---

#### S4.3 – Implement Lazy Loading & Progress
**Entry Criteria**:
- S4.1 complete (ProjectWindow)
- S4.2 complete (file actions)

**Goal**: Implement lazy file content loading with progress tracking.

**Exit Criteria**:
- ✅ Files are discovered but NOT loaded until user selects
- ✅ Loading state shown in detail pane (spinner)
- ✅ @State tracks `loadingFiles: Set<UUID>` and `fileContents: [UUID: ProjectFileContents]`
- ✅ Calls consumer's contentLoader callback when file selected
- ✅ Shows error if loading fails
- ✅ Reload action re-fetches without showing stale indicator (Phase 1)
- ✅ File contents cached in memory while view is open

---

#### S4.4 – Platform-Specific Layouts (iOS Support)
**Entry Criteria**:
- S4.1 complete (macOS NavigationSplitView)
- S3.5, S3.6 complete (sidebar, detail)

**Goal**: Adapt ProjectWindow for iOS using NavigationStack.

**Exit Criteria**:
- ✅ iOS version uses NavigationStack instead of NavigationSplitView
- ✅ File list shown first; tapping file pushes detail view
- ✅ Back button returns to file list
- ✅ All file actions work on iOS
- ✅ Responsive layout for iPad (supports split view on large screens)
- ✅ Compiles for iOS 26.0+ target

---

### WU5: Integration with Proyecto App
**Goal**: Connect ProjectBrowser library to standalone Proyecto app for file browsing.
**Sorties**: 3
**Duration**: ~2 days

#### S5.1 – Add SwiftProyecto Package Dependency to Proyecto
**Entry Criteria**:
- WU4 complete (ProjectWindow library fully functional)
- Proyecto app Xcode project exists at ~/Projects/apps/Proyecto

**Goal**: Wire SwiftProyecto package as a dependency in the Proyecto Xcode project.

**Exit Criteria**:
- ✅ Proyecto.xcodeproj links SwiftProyecto package
- ✅ Proyecto app target can import ProjectBrowser
- ✅ Build succeeds with no linking errors
- ✅ No circular dependencies
- ✅ Platform compatibility verified (macOS 26.0+, iOS 26.0+)

---

#### S5.2 – Create Project Launcher UI in Proyecto
**Entry Criteria**:
- S5.1 complete (SwiftProyecto dependency wired)
- S4.1 complete (ProjectWindow implemented)

**Goal**: Replace ContentView in Proyecto with UI that opens a folder picker and launches ProjectWindow.

**Exit Criteria**:
- ✅ Proyecto/ContentView.swift updated with folder picker button
- ✅ Clicking button opens FileImporter (iOS) or NSOpenPanel (macOS)
- ✅ Selected directory passed to ProjectWindow
- ✅ ProjectWindow presented as sheet/modal
- ✅ File list displays correctly
- ✅ Can select and view files
- ✅ Compiles and runs on macOS and iOS simulators

---

#### S5.3 – Verify End-to-End Workflow
**Entry Criteria**:
- S5.2 complete (UI wired)

**Goal**: Test the complete flow: launch app → open folder → browse files → view content.

**Exit Criteria**:
- ✅ App launches without crashes
- ✅ Folder picker dialog appears
- ✅ Can select a real directory (e.g., SwiftProyecto source tree)
- ✅ File tree loads and displays
- ✅ Clicking file shows content in detail pane
- ✅ File content renders correctly (plain text for fallback)
- ✅ No compilation errors
- ✅ Tested on both macOS and iOS (simulator)

---

### WU6: Testing, Verification & Documentation
**Goal**: End-to-end verification, unit/integration tests, and architecture documentation.
**Sorties**: 3
**Duration**: ~2 days

#### S6.1 – Integration Tests for ProjectWindow
**Entry Criteria**:
- All WU1–WU5 sorties complete
- Proyecto app successfully displays ProjectWindow

**Goal**: Write integration tests that exercise the full flow: discover → select → render.

**Exit Criteria**:
- ✅ `Tests/ProjectWindowIntegrationTests.swift` created
- ✅ Tests discover files in temp directory
- ✅ Tests select file and verify callback fired
- ✅ Tests render file with default handler
- ✅ Tests file actions (reload) work end-to-end
- ✅ All tests pass with `swift_package_test`
- ✅ Test coverage > 75% for public API

---

#### S6.2 – Public API Documentation
**Entry Criteria**:
- All components complete (WU1–WU5)

**Goal**: Write comprehensive API documentation for ProjectWindow and integration guide.

**Exit Criteria**:
- ✅ `Sources/ProjectBrowser/README.md` created
- ✅ API reference for ProjectWindow initializer
- ✅ Examples of handler registration
- ✅ Platform-specific usage notes
- ✅ Error handling guide
- ✅ Callback signature reference
- ✅ Integration example showing Proyecto app usage
- ✅ All public types documented with doc comments

---

#### S6.3 – Architecture & Integration Documentation
**Entry Criteria**:
- All components complete

**Goal**: Write architecture document explaining component interactions and integration points.

**Exit Criteria**:
- ✅ `Docs/ARCHITECTURE_ProjectBrowser.md` created
- ✅ Component diagram showing ProjectWindow, sidebar, detail, services
- ✅ Data flow diagram showing file discovery → selection → rendering
- ✅ Handler registry flow explained
- ✅ Integration points with SwiftProyecto documented
- ✅ Proyecto app integration described
- ✅ Future enhancements (Phase 2) listed
- ✅ Document references spec and requirements

---

## Open Questions & Decisions

### Q1: Handler Registry Implementation
**Question**: Should handlers be a dictionary `[String: (ProjectFile) -> AnyView]` or a struct array `[FileTypeHandler]`?

**Current Resolution**: Use dictionary for simplicity (matches spec § 4.1). Consumers build dict and pass directly.

**Status**: ✅ RESOLVED (no blocker)

---

### Q2: Platform-Specific Code Organization
**Question**: How to organize iOS vs macOS code? Separate files with `#if os(macOS)` or different view variants?

**Current Resolution**: Use conditional compilation within components. Views like ProjectWindow have separate NavigationSplitView (macOS) and NavigationStack (iOS) in same file.

**Status**: ✅ RESOLVED (no blocker)

---

### Q3: File Monitoring (Phase 2)
**Question**: Should Phase 1 include FSEvents monitoring, or defer to Phase 2?

**Current Resolution**: **DEFER TO PHASE 2**. Phase 1 focuses on core browsing. File monitoring adds complexity.

**Impact**: Phase 1 will not auto-refresh when files change externally. Reload action is manual.

**Status**: ✅ DECISION MADE (no blocker)

---

### Q4: Large Directory Virtualization
**Question**: For directories with 10,000+ files, should we virtualize the file tree?

**Current Resolution**: **PHASE 1**: Use standard ForEach. **PHASE 2**: Implement virtualization if needed.

**Status**: ✅ DEFERRED TO PHASE 2 (acceptable for MVP)

---

### Q5: Standalone Proyecto App Integration
**Question**: Should ProjectBrowser be integrated into Proyecto as a complete file browser, or just demonstrate capability?

**Current Resolution**: **Phase 1**: Build Proyecto as a standalone file browser demonstrating ProjectWindow functionality. Future versions can integrate into other apps (Produciesta, etc.) as needed.

**Status**: ✅ RESOLVED (no blocker) — Integration now targets Proyecto instead of Produciesta

---

## Success Criteria (Phase 1)

✅ Consumers can browse any directory with a hierarchical file tree.  
✅ Consumers can register views for custom file types.  
✅ Default handlers render plain text, show "unsupported" for unknown types.  
✅ File contents load on demand (lazy loading).  
✅ File actions (reload, delete, show in Finder) work reliably.  
✅ Performance: < 50 MB memory for 1,000 files; < 1 sec to render tree.  
✅ macOS layout (NavigationSplitView) fully functional.  
✅ iOS layout (NavigationStack) fully functional.  
✅ No crashes on large directories (tested to 10,000 files).  
✅ Proyecto standalone app demonstrates full file browsing workflow.  
✅ Documented API and architecture.  

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| ProjectFileDiscovery too slow on large dirs | Medium | High | Profile early in S2.3; Phase 2 virtualization |
| Platform-specific bugs (iOS vs macOS) | Medium | Medium | Cross-platform testing on simulators (S4.4) |
| Handler performance with many handlers | Low | Low | Cache handler lookups (Phase 2 optimization) |
| File deletion race (deleted while loading) | Low | Low | Catch FileNotFound errors gracefully (S4.2) |
| Memory pressure with large files | Low | Medium | Implement content streaming (Phase 2) |

---

## Sortie Ordering & Parallelism

**Critical Path** (blockers only):
1. S1.1 → S1.2 → S1.3 → S1.4 (models must be first)
2. S2.1 → S2.2 → S2.3 (discovery depends on models)
3. S3.1, S3.2, S3.3, S3.4 can run in parallel (all depend on models)
4. S3.5 depends on S3.1, S3.2, S3.3
5. S3.6 depends on S3.4
6. S4.1 depends on S3.5, S3.6, S2.1
7. S4.2 depends on S4.1
8. S4.3 depends on S4.2
9. S4.4 depends on S4.1
10. S5.1, S5.2, S5.3 (sequential within WU5)
11. S6.1, S6.2 can start after S4.1; S6.3, S6.4 after all components

**Parallel opportunities**:
- S1.1 and S1.2 can be parallel (share final coordination in S1.3)
- S2.1, S2.2, S2.3 are sequential but can overlap
- S3.1–S3.4 can be dispatched in parallel
- S4.2 and S4.3 sequential within WU4
- S4.4 can be parallel with S4.2, S4.3

---

## Next Steps

1. **Review Plan**: Confirm no changes needed to this EXECUTION_PLAN.md
2. **Refine** (optional): Run `/mission-supervisor refine` for deeper analysis
3. **Start Mission**: Run `/mission-supervisor start` to initialize and dispatch first sorties

---

**Status**: READY FOR APPROVAL  
**Plan Created**: 2026-07-17  
**Target Start**: 2026-07-17

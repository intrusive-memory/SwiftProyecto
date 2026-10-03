---
type: execution-plan
title: SwiftProyecto ProjectBrowser Enhancements
mission: Add Personaje-required features to ProjectBrowser and ProjectFrontMatter (PY-P1 through PY-P4 in v5.1.0; PY-P5 deferred to v5.2.0)
origin: REQUIREMENTS-personaje.md (Personaje docs/REQUIREMENTS-APP-UI.md, recon verified)
work-unit-count: 1
sortie-count: 6 (5 for v5.1.0, 1 deferred to v5.2.0)
sequencing: Serial; sorties 1–5 ordered by dependency, ship v5.1.0. Sortie 6 deferred to v5.2.0.
open-questions: 3 (all resolved)
updated: 2026-10-03
---

# Terminology

**Mission**: Complete PY-P1, PY-P2, PY-P3, PY-P4, and optionally PY-P5 to unblock Personaje app shell and Vinetas scene integration.

**Work Unit**: A logical grouping of sorties that deliver a coherent feature. *One work unit here:* ProjectBrowser Enhancements (all sorties address ProjectBrowser, ProjectFrontMatter, and associated models).

**Sortie**: A focused, deliverable block of tasks with clear entry/exit criteria. Each sortie has 2–4 tasks; sorties are ordered by dependency (foundations first).

**Task**: An atomic code change or verification. Tasks within a sortie may be executed in any order unless explicitly sequenced.

---

# Work Unit 1: ProjectBrowser Enhancements

| Sortie | Requirement | Tasks | Layer | Dependency |
|--------|-------------|-------|-------|------------|
| 1 | PY-P1 (foundational) | 3 | ProjectWindow | None |
| 2 | PY-P1 (visual + interaction) | 3 | ProjectWindow | Sortie 1 |
| 3 | PY-P2 | 3 | ProjectFileDiscovery + ProjectWindow | None |
| 4 | PY-P3 (foundational) | 4 | ProjectFrontMatter | None |
| 5 | PY-P4 | 4 | ProjectFrontMatter + File I/O | Sortie 4 |
| 6 (optional) | PY-P5 | 5 | ProjectBrowser + new public API | None |

---

# Sortie 1: Add Expected Files Foundation

**Requirement**: PY-P1 (first half). `ProjectWindow` accepts an `expectedFiles: [String]?` parameter. Expected file paths (e.g., `"CAST.md"`) appear in the file tree whether or not they exist on disk. `ProjectFileDiscovery` continues to list only existing files; expected entries are merged in after discovery.

**Entry Criteria**:
- `ProjectWindow` defined at `Sources/SwiftProyecto/ProjectBrowser/ProjectWindow.swift`
- `ProjectFileDiscovery` defined at `Sources/SwiftProyecto/ProjectBrowser/ProjectFileDiscovery.swift`
- Recon confirmed both exist and that ProjectWindow takes `fileFilter` parameter

**Tasks**:

1. **Task 1.1: Add `expectedFiles` parameter to `ProjectWindow` initializer**
   - Signature: `expectedFiles: [String]? = nil` (default empty/nil for backward compatibility)
   - Document: optional paths to include in tree whether or not they exist
   - Constraint: Must not break Escribir's existing calls (all parameters default)

2. **Task 1.2: Merge expected files with discovered files in tree view**
   - After `ProjectFileDiscovery` returns discovered files, insert missing expected files into the list
   - Expected files should appear *below* existing files in the tree (or as a separate "expected" section if UI requires)
   - Store expected file information (path, existence status) for use in Sortie 2

3. **Task 1.3: Verify backward compatibility**
   - Call `ProjectWindow()` without `expectedFiles` → behavior identical to v5.0.0
   - Call `ProjectWindow(expectedFiles: [])` → behavior identical to v5.0.0
   - No change to Escribir's ProjectWindow usage

**Exit Criteria**:
- ✓ `ProjectWindow` accepts `expectedFiles: [String]?` parameter
- ✓ When `expectedFiles: ["CAST.md"]` on a folder without CAST.md, the tree includes a CAST.md row
- ✓ When `expectedFiles` is nil or empty, behavior is identical to before
- ✓ Calling `ProjectWindow()` with no expectedFiles argument compiles and runs in Escribir without change
- Machine-verifiable: `ProjectWindow.init(expectedFiles:)` exists with default `nil`; test: build Escribir against release candidate with no source changes

---

# Sortie 2: Missing File Visual State and Selection Callback

**Requirement**: PY-P1 (second half). Missing expected files are shown in a visually distinct state (grey text, "missing" label or badge). Selecting a missing file fires a callback.

**Entry Criteria**:
- Sortie 1 complete (expected files merged into tree)
- `ProjectFile` model defined (recon verified)
- ProjectWindow tree view renders files (recon verified NavigationSplitView at line 286–298)

**Tasks**:

1. **Task 2.1: Define missing file visual state**
   - Add property to `ProjectFile` or tree row model: `isExpectedButMissing: Bool`
   - Update ProjectWindow tree row rendering: if `isExpectedButMissing`, apply grey text color + "missing" label
   - Ensure existing files (expected or not) render normally

2. **Task 2.2: Implement missing file selection callback**
   - Add optional callback parameter: `onMissingFileSelected: ((String) -> Void)?` to ProjectWindow (or via state binding)
   - When a tree row with `isExpectedButMissing: true` is tapped/selected, invoke callback with file path
   - Selecting an existing file does NOT invoke this callback

3. **Task 2.3: Verify callback fires only for missing files**
   - Test: Select a missing expected file → callback fires with correct path
   - Test: Select an existing file → callback does not fire
   - Test: Select missing file with no callback provided → no crash

**Exit Criteria**:
- ✓ Missing expected file rows render in grey with "missing" indicator
- ✓ Selecting a missing file fires the callback with the file path
- ✓ Selecting an existing file does not fire the missing callback
- ✓ Acceptance criterion met: "A `ProjectWindow` given `expectedFiles: ["CAST.md"]` on a folder without one shows the row as missing, and selecting it fires the callback"
- Machine-verifiable: Unit test creates ProjectWindow with expectedFiles and callback; selects missing file; verifies callback called with path

---

# Sortie 3: Per-File Handler Disambiguation

**Requirement**: PY-P2. `handlers:` in ProjectFrontMatter can be keyed by exact filename (e.g., `PROJECT.md`, `CAST.md`) in addition to file extension. A filename match takes precedence over an extension match. Today's lookup (`handlers[file.fileExtension ?? ""]`) causes `PROJECT.md` and `CAST.md` to collide on the `"md"` extension.

**Entry Criteria**:
- `ProjectFrontMatter` model has `handlers: [String: String]?` (recon verified as working)
- ProjectWindow applies handlers to route file selection to detail views (recon verified)
- Recon confirmed handler lookup is currently `handlers[file.fileExtension ?? ""]`

**Tasks**:

1. **Task 3.1: Update handler lookup logic to check filename first**
   - Change lookup from: `handlers[file.fileExtension ?? ""]`
   - To: `handlers[file.name] ?? handlers[file.fileExtension ?? ""]`
   - File name is the basename (e.g., `"PROJECT.md"`, `"CAST.md"`)

2. **Task 3.2: Verify name-based routing**
   - Test: `handlers: {"PROJECT.md": "detailProjectView", "CAST.md": "detailCastView", "md": "detailMarkdownView"}`
   - PROJECT.md → detailProjectView
   - CAST.md → detailCastView
   - Other .md files → detailMarkdownView

3. **Task 3.3: Verify extension-only handlers still work**
   - Test: `handlers: {"fountain": "detailScreenplayView"}`
   - script.fountain → detailScreenplayView (no name match, extension match succeeds)

**Exit Criteria**:
- ✓ Handler lookup checks filename first, then extension
- ✓ handlers["PROJECT.md"] routes PROJECT.md to its specific handler only
- ✓ handlers["CAST.md"] routes CAST.md to its specific handler only
- ✓ handlers["md"] still routes other .md files to the markdown handler
- ✓ Acceptance criterion met: "Handlers for `PROJECT.md` and `CAST.md` by name each receive only their file; an `md` extension handler still receives every other `.md`"
- Machine-verifiable: Unit test with handlers dict; verify lookup returns correct handler for PROJECT.md, CAST.md, and other.md

---

# Sortie 4: Add `style:` Block to ProjectFrontMatter

**Requirement**: PY-P3 (foundational). Add a top-level `style:` block to ProjectFrontMatter front matter with three optional fields: `artStyle`, `palette`, `wardrobe`. Each is a string choice from a short list (palette and wardrobe lists TBD; artStyle values TBD in Personaje design). Personaje reads and writes `artStyle` only; Vinetas reads all three.

**Entry Criteria**:
- ProjectFrontMatter defined at `Sources/SwiftProyecto/Models/ProjectFrontMatter.swift`
- YAML parsing already in place for front matter (recon verified)
- Recon confirmed no `style` field exists today

**Tasks**:

1. **Task 4.1: Define `style` data model**
   - Create struct: `Style { artStyle: String?, palette: String?, wardrobe: String? }`
   - Add to ProjectFrontMatter: `var style: Style?`
   - Add Codable conformance for YAML serialization

2. **Task 4.2: Implement YAML parsing for `style:` block**
   - Extend ProjectFrontMatter YAML decoder to parse `style:` key as `Style` object
   - Handle missing `style:` block gracefully (nil)
   - Parse individual fields within `style:` (some may be missing)

3. **Task 4.3: Implement YAML writing for `style:` block**
   - When writing ProjectFrontMatter to YAML, emit `style:` block if present
   - If `style:` is nil, do not emit the key
   - If `style:` exists but all fields are nil, emit empty `style:` or omit (TBD)

4. **Task 4.4: Test round-trip (with and without `style:` block)**
   - Test A: PROJECT.md with `style: { artStyle: "watercolor" }` → parse → write → original bytes match
   - Test B: PROJECT.md without `style:` key → parse → write → no `style:` added, file unchanged
   - Test C: `style: {}` (empty) → parse → write → behavior defined (empty or omitted)

**Exit Criteria**:
- ✓ ProjectFrontMatter has `style: Style?` field
- ✓ YAML parser reads `style:` block and maps to `Style` object
- ✓ YAML writer emits `style:` block when present
- ✓ Acceptance criterion met: "A PROJECT.md with `style:` round-trips; one without it is unchanged on write"
- Machine-verifiable: Unit test with PROJECT.md sample; parse + write + byte-compare; verify no mutation when `style:` absent

---

# Sortie 5: Implement Coordinated Writes with NSFileCoordinator

**Requirement**: PY-P4. Two apps (Personaje and Vinetas) write PROJECT.md concurrently or sequentially. Writes must preserve sections the writer doesn't own (e.g., Personaje preserves Vinetas' projects and sequences; Vinetas preserves Personaje's personaje: section and style.artStyle). Implement via NSFileCoordinator to serialize writes and prevent data loss.

**Entry Criteria**:
- Sortie 4 complete (`style:` block defined in ProjectFrontMatter)
- ProjectFrontMatter.write() or similar method exists (recon verified write flow exists)
- AppFrontMatterSettings protocol exists with `settings(for:)`, `setSettings(_:)`, `hasSettings(for:)` (recon verified)

**Tasks**:

1. **Task 5.1: Create FileCoordinationManager**
   - New utility: `FileCoordinationManager` wrapping NSFileCoordinator
   - Method: `coordinatedWrite(fileURL:block:)` that acquires write lock and calls block
   - Ensures only one write at a time to PROJECT.md
   - Coordinate across Personaje and Vinetas processes

2. **Task 5.2: Implement selective field preservation**
   - Design: each app declares which top-level keys it "owns" (e.g., Personaje: `personaje:`, `style.artStyle`; Vinetas: `projects:`, `sequences:`, `style.palette`, `style.wardrobe`)
   - When Personaje writes, preserve all Vinetas keys
   - When Vinetas writes, preserve all Personaje keys
   - Implement as merge operation: read existing, update only owned keys, write back

3. **Task 5.3: Integrate with ProjectFrontMatter write path**
   - Wrap ProjectFrontMatter.write() (or create new `coordinatedWrite()` method) with FileCoordinationManager
   - Method signature: `coordinatedWrite(fileURL:block:)` where block receives mutable ProjectFrontMatter and writes it
   - Block reads current PROJECT.md, calls `setSettings()` or updates owned fields, writes back via coordinator

4. **Task 5.4: Verify concurrent write safety**
   - Test: Simulate Personaje writing `personaje:` section while Vinetas writes `projects:` section
   - Verify both sections coexist after writes
   - Test: Write cycles (W_P → W_V → W_P) preserve all data
   - No data loss in concurrent scenario

**Exit Criteria**:
- ✓ FileCoordinationManager exists and wraps NSFileCoordinator
- ✓ coordinatedWrite() serializes writes and prevents concurrent access
- ✓ Writes preserve non-owned sections (field-level merge)
- ✓ Acceptance criterion met: "Escribir builds against the release with no source change" (write path doesn't break Escribir)
- ✓ Requirement met: "Neither app overwriting the other"
- Machine-verifiable: Unit test creates two ProjectFrontMatter instances with different owned fields, coordinates writes, verifies merge result includes all fields

---

# Sortie 6 (Optional): Move Recents Infrastructure to SwiftProyecto

**Requirement**: PY-P5 (optional). Extract Escribir's recents management infrastructure (`RecentProjectEntry`, `RecentProjectList`, `RecentProjectsStore`, `RecentProjects`, `ProjectFolderBookmarkStore`, `ProjectFolderBookmark`) into SwiftProyecto's public API. If deferred, Personaje and other apps will duplicate these types locally.

**Inclusion Decision**: This sortie is **optional** and depends on project priorities. Include if:
- Personaje integration requires launch-window recents at v5.1.0
- Code sharing across 3+ apps justifies public API maintenance burden

Defer if:
- Personaje can ship with internal recents copy
- Revisit at v5.2.0 when ecosystem stabilizes

**Entry Criteria** (if included):
- Escribir source code accessible (or types documented)
- No breaking change to Escribir's existing recents usage
- ProjectBrowser target confirms `dependencies: []` (no new transitive deps)

**Tasks** (if included):

1. **Task 6.1: Identify and extract bookmark types**
   - Locate `ProjectFolderBookmark`, `ProjectFolderBookmarkStore` in Escribir/Shared/ProjectFolderBookmark.swift
   - Extract to: `Sources/SwiftProyecto/Models/ProjectFolderBookmark.swift`
   - Verify Codable conformance, no app-specific logic

2. **Task 6.2: Identify and extract recents types**
   - Locate `RecentProjectEntry`, `RecentProjectList`, `RecentProjectsStore`, `RecentProjects` in Escribir/Shared/RecentProjectFolders.swift
   - Extract to: `Sources/SwiftProyecto/Models/RecentProjects.swift`
   - Verify no dependency on Escribir-specific models (e.g., AppState)

3. **Task 6.3: Expose via SwiftProyecto public API**
   - Add to package public exports (e.g., `Sources/SwiftProyecto/SwiftProyecto.swift`)
   - Document: "Available for apps managing recent project lists"
   - Maintain backward compatibility in Escribir (no breaking changes)

4. **Task 6.4: Update Escribir to import from SwiftProyecto**
   - Replace local imports with `import SwiftProyecto`
   - Remove duplicated types from Escribir
   - Verify Escribir builds and recents feature works unchanged

5. **Task 6.5: Verify Personaje can use shared types**
   - Personaje's launch window imports `RecentProjects` from SwiftProyecto
   - Recents list populated and persisted via shared API
   - No duplication between Escribir and Personaje

**Exit Criteria** (if included):
- ✓ All recents types moved from Escribir to SwiftProyecto
- ✓ Escribir imports from SwiftProyecto with no behavioral change
- ✓ Personaje's launch window can use shared recents API
- ✓ No code duplication between Escribir and Personaje
- Machine-verifiable: Escribir builds against v5.1.0 with recents feature intact; Personaje imports recents types from SwiftProyecto

---

# Dependency Graph

**External Dependencies**: None. (Requirements state "Nothing in this effort"; SwiftProyecto already links SwiftCompartido, SwiftAcervo, etc.)

**Internal Dependencies**:

```
┌─────────────────────┐
│    Sortie 1: expectedFiles foundation    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Sortie 2: missing state │
└─────────────────────┘

┌─────────────────────┐
│ Sortie 3: per-file handlers (independent) │
└─────────────────────┘

┌─────────────────────┐
│ Sortie 4: style: block │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Sortie 5: NSFileCoordinator wrapper │
└─────────────────────────────────────┘

┌──────────────────────────┐
│ Sortie 6 (optional): recents infrastructure (independent) │
└──────────────────────────┘
```

**Execution Order**:
1. Sorties 1, 3, 4 can run in parallel (no interdependencies)
2. Sortie 2 waits for Sortie 1 exit criteria
3. Sortie 5 waits for Sortie 4 exit criteria
4. Sortie 6 runs independently (if included)

---

# Parallel Execution Layers

The dependency graph enables efficient parallelization across two layers, reducing total execution time from sequential (2.75 + 1.5 + 0.5 + 0.75 + 1 = ~6 dev-days) to parallel (~2 dev-days if all agents run concurrently).

**Layer 1** (dispatch first, run concurrently):
- **Sortie 1**: Add Expected Files Foundation (0.5 dev-days)
- **Sortie 3**: Per-File Handler Disambiguation (0.5 dev-days)
- **Sortie 4**: Add `style:` Block (0.75 dev-days)
- **No interdependencies**: These three sorties can run side-by-side in parallel agents

**Barrier**: Wait for all Layer 1 sorties to meet exit criteria before dispatching Layer 2

**Layer 2** (dispatch after Layer 1 complete, run concurrently):
- **Sortie 2**: Missing File Visual State (depends on Sortie 1 ✓) — 0.5 dev-days
- **Sortie 5**: NSFileCoordinator Wrapper (depends on Sortie 4 ✓) — 1 dev-day
- **No interdependencies**: These two can run side-by-side once their dependencies complete

**Layer 3** (optional):
- **Sortie 6**: Move Recents Infrastructure (deferred to v5.2.0, no dependencies)

**Optimal Strategy**:
1. Dispatch Layer 1 agents concurrently with `/mission-supervisor start layer:1`
2. Wait for all three sorties to exit successfully (max ~0.75 dev-days)
3. Dispatch Layer 2 agents concurrently with `/mission-supervisor start layer:2`
4. Wait for both sorties to exit (max ~1 dev-day)
5. **Total time: ~1.75 dev-days parallel vs. ~2.75 sequential for v5.1.0 delivery**

---

# Open Questions

**✅ OQ-1: Release Sequencing for PY-P1, PY-P2, PY-P3, PY-P4 — RESOLVED**

**Decision**: Option B — Ship v5.1.0 with Sorties 1–5 (all of PY-P1 through PY-P4) together.

**Rationale**: Unblocks both Personaje app shell (PY-P1, PY-P2) and Vinetas scene integration (PY-P3, PY-P4) in a single release. Couples write coordination to file discovery as a single coherent feature set.

**Impact on plan**: Sorties 1–5 target v5.1.0 (~2.75 dev-days). All acceptance criteria ship together.

---

**✅ OQ-2: Palette and Wardrobe Option Lists — RESOLVED**

**Decision**: Yes, Sortie 4 ships with all three `style:` fields as optional strings (no enum validation).

**Rationale**: Personaje and Vinetas write arbitrary strings; Vinetas validates on read. Simpler initial implementation; validation responsibility lives in consuming apps.

**Impact on plan**: Sortie 4 ships as specified; no enum constraints block v5.1.0.

---

**✅ OQ-3: Include Sortie 6 (Recents Infrastructure) in This Release? — RESOLVED**

**Decision**: Defer Sortie 6 to v5.2.0. Personaje uses internal recents copy in v5.1.0.

**Rationale**: Saves ~1 dev-day for v5.1.0; allows ecosystem to stabilize before committing to a shared public API. Revisit at v5.2.0 when recents requirements are clearer across Escribir, Personaje, and other apps.

**Impact on plan**: v5.1.0 includes Sorties 1–5 only (~2.75 dev-days). Sortie 6 deferred; no blocking open questions remain.

---

# Summary Table

| Phase | Sortie | Requirement | Tasks | Est. Effort | Prerequisite | Target Release |
|-------|--------|-------------|-------|-------------|--------------|-----------------|
| 1 | 1 | PY-P1 (foundation) | 3 | 0.5 dev-day | None | v5.1.0 |
| 1 | 2 | PY-P1 (UI) | 3 | 0.5 dev-day | Sortie 1 | v5.1.0 |
| 1 | 3 | PY-P2 | 3 | 0.5 dev-day | None | v5.1.0 |
| 1 | 4 | PY-P3 (foundational) | 4 | 0.75 dev-day | None | v5.1.0 |
| 1 | 5 | PY-P4 | 4 | 1 dev-day | Sortie 4 | v5.1.0 |
| — | 6 | PY-P5 (optional) | 5 | 1.5 dev-days | None | v5.2.0 (deferred) |
| | | **Total for v5.1.0** | **17** | **~2.75 dev-days** | | |
| | | **Total with v5.2.0** | **22** | **~4.25 dev-days** | | |

---

# Acceptance Criteria (Requirement-Level)

From REQUIREMENTS-personaje.md, all four acceptance criteria must be met before release:

1. ✓ A `ProjectWindow` given `expectedFiles: ["CAST.md"]` on a folder without one shows the row as missing, and selecting it fires the callback. — **Sorties 1, 2**

2. ✓ Handlers for `PROJECT.md` and `CAST.md` by name each receive only their file; an `md` extension handler still receives every other `.md`. — **Sortie 3**

3. ✓ A PROJECT.md with `style:` round-trips; one without it is unchanged on write. — **Sortie 4**

4. ✓ Escribir builds against the release with no source change. — **All sorties (backward compatibility)**

---

# Notes

- **Recon CLEAR**: All 10 assumptions from RECON_REPORT.md confirmed. No blocking unknowns.
- **Escribir Constraint**: "Escribir must not change behavior." All sorties are additive (default parameters); no breaking changes to existing signatures.
- **ProjectBrowser stays lean**: "ProjectBrowser keeps `dependencies: []`." No new external package dependencies added.
- **Backward Compatibility**: Default parameters (`expectedFiles: nil`, `style: nil`) ensure v5.0.x code runs unchanged on v5.1.0+.

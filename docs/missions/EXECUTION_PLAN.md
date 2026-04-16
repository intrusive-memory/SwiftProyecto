# SwiftProyecto Execution Plan - PROJECT.md Foundation (Phase 0)

**Repository**: SwiftProyecto
**Source**: package-collection/CUSTOM_PAGES_REMOVAL_REQUIREMENTS.md (Phase 0)
**Status**: BLOCKING - Must complete before custom-pages removal begins
**Timeline**: Week 1

---

## Executive Summary

Establish SwiftProyecto as the **single source of truth** for PROJECT.md operations. This foundation work enables the removal of custom-pages.json code across all dependent projects.

**Critical Issues to Fix**:
1. Episodes folder not detected (PROJECT.md written to wrong location)
2. Cast export overwrites other providers (data loss bug)
3. No cast reading API (incomplete read/write support)

**Provides**:
- SwiftProyecto v3.1.0+ API (required by Produciesta Phase 1, SwiftCompartido Phase 2, Produciesta Phase 3)
- `ProjectDiscovery` service for locating PROJECT.md from any file path
- `readCast(from:filterByProvider:)` for reading cast with provider filtering
- `ProjectMarkdownParser.write(frontMatter:body:to:)` for atomic file writes
- `ProjectFrontMatter.mergingCast(_:forProvider:)` for safe, additive cast updates

**External Dependencies**: None (foundation layer)

---

## Work Units

| Work Unit | Directory | Sprints | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| SwiftProyecto Foundation | `/Users/stovak/Projects/SwiftProyecto` | 5 | 0 | none |

---

## Work Unit: SwiftProyecto Foundation

**Directory**: `/Users/stovak/Projects/SwiftProyecto`
**Sprints**: 5
**Layer**: 0 (foundation - no dependencies)

---

## Agent Guidelines

### Build Error Escalation Strategy

**CRITICAL**: If you encounter build errors during any sprint:

1. **First attempt**: Try to resolve simple, obvious build errors (missing imports, typos, syntax errors)
2. **If build errors persist**: Dispatch a higher-order reasoning agent (opus model) to solve the build problem
3. **Wait for resolution**: Continue your sprint work once the build problem is resolved
4. **Do NOT**: Get stuck repeatedly trying the same failed build approach

**Escalation pattern**:
```
If build fails after fixing obvious issues:
  → Use Task tool with subagent_type="general-purpose", model="opus"
  → Prompt: "Build is failing with errors: <paste errors>. Fix the build issues in <files>."
  → Wait for completion, then resume your sprint work
```

This ensures build problems don't block sprint progress and get appropriate expert attention.

---

### Sprint 1: ProjectDiscovery Service Implementation

**Priority**: 14 -- Foundation service that all subsequent sprints depend on. Highest dependency depth (4 sprints blocked). Establishes the discovery pattern used throughout the API.

**Estimated turns**: 12 / 50 (24% of budget)

**Entry criteria**:
- [ ] First sprint -- no prerequisites

**Tasks**:
1. Create `Sources/SwiftProyecto/Services/ProjectDiscovery.swift`
2. Implement `ProjectDiscovery` struct with `public init() {}`
3. Implement `findProjectMd(from: URL) -> URL?` with episodes detection (case-insensitive)
4. Implement `checkDirectory(_ directory: URL) -> URL?` helper
5. Add doc comments with `///` on all public methods including parameter descriptions and usage examples

**Implementation Details**:
```swift
public struct ProjectDiscovery: Sendable {
    public init() {}

    /// Find PROJECT.md file starting from a given file or directory.
    ///
    /// ## Search Order
    ///
    /// 1. If `startingFrom` is in "episodes" folder (case-insensitive):
    ///    - Check parent directory first
    ///    - Example: `/project/episodes/script.fountain` -> `/project/PROJECT.md`
    ///
    /// 2. Check current directory:
    ///    - `/project/script.fountain` -> `/project/PROJECT.md`
    ///
    /// 3. Check parent directory (fallback):
    ///    - `/project/subdirectory/script.fountain` -> `/project/PROJECT.md`
    public func findProjectMd(from startingFrom: URL) -> URL? {
        // Implementation from requirements
    }

    private func checkDirectory(_ directory: URL) -> URL? {
        // Implementation from requirements
    }
}
```

**Exit criteria**:
- [ ] File exists: `Sources/SwiftProyecto/Services/ProjectDiscovery.swift`
- [ ] `findProjectMd(from:)` method has `public` access and returns `URL?`
- [ ] Episodes folder detection is case-insensitive (lowercased comparison against "episodes")
- [ ] Parent directory fallback implemented (checks parent when current directory has no PROJECT.md)
- [ ] All public methods have `///` doc comments with parameter descriptions
- [ ] Build succeeds: `xcodebuild build -scheme SwiftProyecto -destination 'platform=macOS'`

---

### Sprint 2: ProjectDiscovery Read Cast API

**Priority**: 11 -- Provides read API consumed by Sprint 3 (write/merge) and Sprint 4 (tests). Medium dependency depth.

**Estimated turns**: 13 / 50 (26% of budget)

**Entry criteria**:
- [ ] Sprint 1 complete -- `ProjectDiscovery.swift` exists and builds
- [ ] `findProjectMd(from:)` method is available

**Tasks**:
1. Add `readCast(from:filterByProvider:)` method to ProjectDiscovery (as extension or directly in struct)
2. Implement provider filtering logic: if `providerID` is non-nil, filter `CastMember` array to only members whose `voices` dictionary contains that provider key
3. Handle empty cast scenarios: return `[]` when `frontMatter.cast` is nil or empty
4. Add `///` doc comments with usage examples showing both filtered and unfiltered calls

**Implementation Details**:
```swift
extension ProjectDiscovery {
    /// Read cast list from PROJECT.md
    ///
    /// - Parameters:
    ///   - projectMdURL: URL to PROJECT.md file
    ///   - providerID: Optional provider to filter by (e.g., "apple", "elevenlabs")
    /// - Returns: Array of CastMember objects
    /// - Throws: Parsing errors
    public func readCast(
        from projectMdURL: URL,
        filterByProvider providerID: String? = nil
    ) throws -> [CastMember] {
        // Implementation from requirements
    }
}
```

**Exit criteria**:
- [ ] `readCast(from:filterByProvider:)` method exists with `public` access
- [ ] Method parses PROJECT.md using `ProjectMarkdownParser` and returns `[CastMember]`
- [ ] When `providerID` is non-nil, only returns cast members with a voice for that provider
- [ ] Returns empty array `[]` when PROJECT.md has no cast section
- [ ] All public methods have `///` doc comments
- [ ] Build succeeds: `xcodebuild build -scheme SwiftProyecto -destination 'platform=macOS'`

---

### Sprint 3: ProjectMarkdownParser Write Method & ProjectFrontMatter Helpers

**Priority**: 13 -- Critical data-loss fix (cast merging). Foundation for safe PROJECT.md writes across all dependent projects. High risk (data integrity).

**Estimated turns**: 16 / 50 (32% of budget)

**Entry criteria**:
- [ ] Sprint 2 complete -- `readCast()` method exists and builds
- [ ] `ProjectMarkdownParser.generate(frontMatter:body:)` method already exists (confirmed in codebase)

**Tasks**:
1. Add `write(frontMatter:body:to:)` method to `ProjectMarkdownParser` (extension or directly in struct)
2. Add `withCast(_:)` method to `ProjectFrontMatter` -- creates a new instance with the cast replaced
3. Add `mergingCast(_:forProvider:)` method to `ProjectFrontMatter` -- merges voice for specified provider while preserving all other provider voices
4. Implement provider-specific voice merging logic: for each character in `newCast`, find or create matching character in existing cast, set voice for `providerID`, preserve all other voice keys
5. Add `///` doc comments for all new methods

**Implementation Details**:
```swift
// ProjectMarkdownParser extension
extension ProjectMarkdownParser {
    /// Write PROJECT.md file to disk
    public func write(
        frontMatter: ProjectFrontMatter,
        body: String,
        to url: URL
    ) throws {
        let content = generate(frontMatter: frontMatter, body: body)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}

// ProjectFrontMatter extensions
extension ProjectFrontMatter {
    /// Create a copy with updated cast list
    public func withCast(_ cast: [CastMember]?) -> ProjectFrontMatter {
        // Implementation from requirements
    }

    /// Merge cast member voices for a specific provider
    ///
    /// Preserves voices for other providers while updating voices for the specified provider.
    public func mergingCast(_ newCast: [CastMember], forProvider providerID: String) -> ProjectFrontMatter {
        // Implementation from requirements - preserves other provider voices
    }
}
```

**Exit criteria**:
- [ ] `ProjectMarkdownParser.write(frontMatter:body:to:)` method exists with `public` access
- [ ] `write()` calls `generate()` then writes atomically to disk
- [ ] `ProjectFrontMatter.withCast(_:)` method exists, returns new `ProjectFrontMatter` with replaced cast
- [ ] `ProjectFrontMatter.mergingCast(_:forProvider:)` method exists, returns new `ProjectFrontMatter`
- [ ] `mergingCast` preserves voices for providers OTHER than the specified `providerID` (additive merge, not replace)
- [ ] `mergingCast` updates/adds voices for the specified `providerID` only
- [ ] All new methods have `///` doc comments
- [ ] Build succeeds: `xcodebuild build -scheme SwiftProyecto -destination 'platform=macOS'`

---

### Sprint 4: Comprehensive Unit Tests

**Priority**: 8 -- Validates all prior work. No sprints depend on tests directly, but required for release confidence.

**Estimated turns**: 19 / 50 (38% of budget)

**Entry criteria**:
- [ ] Sprint 3 complete -- All API methods (`findProjectMd`, `readCast`, `write`, `withCast`, `mergingCast`) exist and build
- [ ] Existing test infrastructure works: `Tests/SwiftProyectoTests/` directory exists with other test files

**Tasks**:
1. Create `Tests/SwiftProyectoTests/ProjectDiscoveryTests.swift`
2. Implement episodes folder detection tests (all case variations)
3. Implement current/parent directory fallback tests
4. Implement edge case tests (directory vs file, not found, etc.)
5. Implement cast reading tests (all cast, filtered, empty)
6. Implement cast merging tests (verify voice preservation)
7. Run tests and verify all pass

**Test Coverage Required**:

**Episodes Folder Tests**:
- [ ] Find PROJECT.md from episodes folder (parent location)
- [ ] Episodes folder case-insensitive -- "EPISODES"
- [ ] Episodes folder case-insensitive -- "Episodes"
- [ ] Prefers episodes parent over current directory

**Directory Tests**:
- [ ] Find PROJECT.md in current directory
- [ ] Find PROJECT.md in parent directory
- [ ] Return nil when PROJECT.md not found
- [ ] Starting from directory instead of file

**Cast Reading Tests**:
- [ ] Read cast from PROJECT.md (all members)
- [ ] Read cast filtered by provider
- [ ] Read cast returns empty array when no cast
- [ ] Read cast handles PROJECT.md with no cast key in YAML

**Cast Merging Tests** (critical for data loss prevention):
- [ ] Merge cast preserves existing provider voices (e.g., elevenlabs voice survives apple merge)
- [ ] Merge cast updates voices for specified provider
- [ ] Merge cast adds new characters not in existing cast
- [ ] Merge cast preserves character metadata (actor, gender, voiceDescription) from existing cast

**Exit criteria**:
- [ ] File exists: `Tests/SwiftProyectoTests/ProjectDiscoveryTests.swift`
- [ ] Minimum 15 test methods implemented (count with `grep -c 'func test' Tests/SwiftProyectoTests/ProjectDiscoveryTests.swift`)
- [ ] All tests pass: `xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'` exits with code 0
- [ ] Cast merging voice preservation verified: at least one test creates a CastMember with provider A voice, merges with provider B, and asserts provider A voice is still present
- [ ] Edge case: `findProjectMd` returns `nil` for a directory with no PROJECT.md (test asserts `XCTAssertNil`)

---

### Sprint 5: Documentation Updates & Release Preparation

**Priority**: 3 -- Terminal sprint. No dependents. Low risk (documentation and release mechanics).

**Estimated turns**: 20 / 50 (40% of budget)

**Entry criteria**:
- [ ] Sprint 4 complete -- All tests pass: `xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'` exits with code 0
- [ ] All API methods exist: `findProjectMd`, `readCast`, `write`, `withCast`, `mergingCast`

**Tasks**:
1. Update `AGENTS.md` with PROJECT.md Modification Rules section
2. Document API boundaries (what SwiftProyecto owns vs client projects)
3. Document ownership clarification (SwiftProyecto vs client projects)
4. Add usage examples for ProjectDiscovery
5. Add usage examples for cast merging with voice preservation
6. Update CHANGELOG.md with v3.1.0 changes
7. Bump version to 3.1.0 in Package.swift (update comment or doc, since Package.swift has no explicit version constant -- verify if version is tracked elsewhere)
8. **Verify CI/CD testing infrastructure**:
   - Check for `.github/workflows/tests.yml` or `.github/workflows/unit-tests.yml`
   - Verify unit tests trigger on `pull_request` from development → main
   - Check for `.github/workflows/performance-tests.yml` with `workflow_dispatch` (manual trigger)
   - If missing, create workflows following the standard pattern
9. Create git tag v3.1.0
10. Create GitHub release with release notes via `gh release create`

**AGENTS.md Content** (append new section):

Add new section: **"PROJECT.md Modification Rules"**

```markdown
## PROJECT.md Modification Rules

### Single Source of Truth

**SwiftProyecto is the ONLY package that should modify PROJECT.md files.**

Other projects (Produciesta, podcast generators, etc.) must use SwiftProyecto's API for all PROJECT.md operations.

### Finding PROJECT.md

Use `ProjectDiscovery` service:

```swift
import SwiftProyecto

let discovery = ProjectDiscovery()
if let projectMdURL = discovery.findProjectMd(from: screenplayURL) {
    // Found PROJECT.md
}
```

**Search Logic**:
1. If screenplay is in "episodes" folder -> check parent directory first
2. Check current directory
3. Check parent directory (fallback)

### Reading PROJECT.md

```swift
let parser = ProjectMarkdownParser()
let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)

// Access data
let title = frontMatter.title
let cast = frontMatter.cast
```

### Reading Cast from PROJECT.md

```swift
let discovery = ProjectDiscovery()
if let projectMd = discovery.findProjectMd(from: screenplayURL) {
    // Read all cast members
    let allCast = try discovery.readCast(from: projectMd)

    // Read only Apple voices
    let appleCast = try discovery.readCast(from: projectMd, filterByProvider: "apple")
}
```

### Writing PROJECT.md

**CORRECT (Use SwiftProyecto API)**:

```swift
// Modify front matter (in-memory)
let updatedFrontMatter = frontMatter.mergingCast(newCast, forProvider: "apple")

// Write using SwiftProyecto
let parser = ProjectMarkdownParser()
try parser.write(frontMatter: updatedFrontMatter, body: body, to: projectMdURL)
```

**WRONG (Direct File I/O)**:

```swift
// NEVER DO THIS
let content = parser.generate(frontMatter: updatedFrontMatter, body: body)
try content.write(to: projectMdURL, atomically: true, encoding: .utf8)
```

### Cast Merging - Preserving Other Providers

**CRITICAL**: When updating cast voices for a specific provider, you MUST preserve voices for other providers.

```swift
// CORRECT: Merge cast for current provider only
let updatedFrontMatter = frontMatter.mergingCast(newCast, forProvider: "apple")

// WRONG: Replaces entire cast (loses other provider voices)
let updatedFrontMatter = frontMatter.withCast(newCast)
```

**Example**:
```yaml
# Before: Has ElevenLabs voice
cast:
  - character: NARRATOR
    voices:
      elevenlabs: 21m00Tcm4TlvDq8ikWAM

# After mergingCast with Apple provider: Preserves ElevenLabs, adds Apple
cast:
  - character: NARRATOR
    voices:
      apple: com.apple.voice.premium.en-US.Aaron
      elevenlabs: 21m00Tcm4TlvDq8ikWAM
```

### Why These Rules Matter

1. **Format consistency** - YAML serialization handled uniformly
2. **Validation** - SwiftProyecto validates before writing
3. **Atomic writes** - Prevents file corruption
4. **Future evolution** - Format can change without breaking clients
5. **Data loss prevention** - Cast merging preserves all provider voices

### Ownership Clarification

**SwiftProyecto owns**:
- PROJECT.md file format specification
- Parsing and serialization logic
- File I/O operations (read, write, atomic writes)
- Discovery and location logic (findProjectMd)

**Client projects (Produciesta, etc.) own**:
- When to read/write PROJECT.md (business logic)
- What data to store (cast assignments, preferences)
- UI for editing metadata
- Integration with their own data models (SwiftData, etc.)

**Services like ProjectMdSyncService**: These are **allowed** in client projects - they coordinate WHEN to call SwiftProyecto's API based on business logic (e.g., "sync cast when voice assignment changes").
```

**Exit criteria**:
- [ ] `AGENTS.md` contains section header "## PROJECT.md Modification Rules" (verify: `grep -c '## PROJECT.md Modification Rules' AGENTS.md` returns 1)
- [ ] `AGENTS.md` contains "Ownership Clarification" subsection
- [ ] `AGENTS.md` contains `mergingCast` code example
- [ ] `CHANGELOG.md` contains "3.1.0" version header
- [ ] **CI/CD testing infrastructure verified**:
  - [ ] Unit tests workflow exists: `test -f .github/workflows/tests.yml` OR `test -f .github/workflows/unit-tests.yml`
  - [ ] Unit tests trigger on pull_request: `grep -q 'pull_request' .github/workflows/tests.yml` OR `grep -q 'pull_request' .github/workflows/unit-tests.yml`
  - [ ] Performance tests workflow exists: `test -f .github/workflows/performance-tests.yml`
  - [ ] Performance tests use manual trigger: `grep -q 'workflow_dispatch' .github/workflows/performance-tests.yml`
  - [ ] Workflows target correct branches: unit tests run on development → main PRs
- [ ] Git commit created with message starting with "feat:"
- [ ] Git tag `v3.1.0` exists: `git tag -l 'v3.1.0'` returns `v3.1.0`
- [ ] GitHub release `v3.1.0` exists: `gh release view v3.1.0` exits with code 0
- [ ] Build still succeeds after all changes: `xcodebuild build -scheme SwiftProyecto -destination 'platform=macOS'`

---

## Parallelism Structure

**Critical Path**: Sprint 1 -> Sprint 2 -> Sprint 3 -> Sprint 4 -> Sprint 5 (length: 5 sprints, sequential)

**Parallel Execution Groups**: None. This is a single work unit with sequential sprints. Each sprint depends on the prior sprint's artifacts.

**Agent Constraints**:
- **Supervising agent**: Handles all sprints (single work unit, all sprints have build steps)
- **Sub-agents**: Not applicable (no independent work units)

---

## Open Questions & Missing Documentation

### Resolved Items (auto-fixed during refinement)

| Sprint | Issue Type | Original | Fix Applied |
|--------|-----------|----------|-------------|
| Sprint 1 | Vague criterion | "All public methods have documentation" | Replaced with: "All public methods have `///` doc comments with parameter descriptions" |
| Sprint 4 | Vague criterion | "100% coverage on ProjectDiscovery methods" | Replaced with: "Minimum 15 test methods implemented" + specific voice preservation test assertion |
| Sprint 4 | Vague criterion | "100% coverage on cast merging logic (voice preservation verified)" | Replaced with: specific test assertion requirement for provider voice survival |
| Sprint 4 | Vague criterion | "Edge cases handled gracefully" | Replaced with: specific `XCTAssertNil` test for not-found case |
| Sprint 5 | Vague criterion | "All documentation reviewed for clarity" | Removed (not machine-verifiable). Replaced with specific content checks via grep. |
| Sprint 5 | Vague criterion | "Version bumped to 3.1.0 in Package.swift" | Clarified: Package.swift has no version constant. Version is tracked via git tag. Updated task to verify. |

### Remaining Items (no blocking issues)

None. All criteria are machine-verifiable.

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 1 |
| Total sprints | 5 |
| Dependency structure | Sequential (single work unit) |
| Estimated timeline | 1 week |
| Average sprint size | 16 turns (budget: 50) |
| Critical path length | 5 sprints |
| Parallelism | 1 supervising agent, 0 sub-agents (single sequential work unit) |

**Sprint Priority Ranking**:

| Sprint | Name | Priority Score | Rationale |
|--------|------|---------------|-----------|
| 1 | ProjectDiscovery Service | 14 | Foundation (dep_depth=4, foundation=1, risk=2, complexity=1) |
| 3 | Write Method & Cast Merging | 13 | Data-loss fix (dep_depth=2, foundation=1, risk=3, complexity=1.5) |
| 2 | Read Cast API | 11 | Intermediate API (dep_depth=3, foundation=0, risk=2, complexity=1) |
| 4 | Comprehensive Unit Tests | 8 | Validation (dep_depth=1, foundation=0, risk=1, complexity=3) |
| 5 | Documentation & Release | 3 | Terminal (dep_depth=0, foundation=0, risk=1, complexity=2) |

**Note**: Sprints remain in sequential order (1-2-3-4-5) because each depends on prior sprint artifacts. Priority scores inform model selection, not execution order.

**Critical Success Criteria**:
- Episodes folder detection works (case-insensitive)
- Cast merging preserves other provider voices (additive, not replace)
- Complete read/write API (findProjectMd, readCast, write, mergingCast)
- Minimum 15 test cases with all passing
- AGENTS.md documented with clear API boundaries
- v3.1.0 tagged and released

**Provides (Dependency for Downstream)**:
- SwiftProyecto v3.1.0+ API
- Required by: Produciesta Phase 1 (update dependencies)
- Required by: SwiftCompartido Phase 2 (custom-pages removal)
- Required by: Produciesta Phase 3 (UI cleanup and integration)

---

**Document Version**: 2.0 (refined)
**Created**: 2026-02-15
**Refined**: 2026-02-15
**Status**: Ready for execution

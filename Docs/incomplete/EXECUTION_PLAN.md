---
type: execution-plan
name: compartido-cast-extraction
description: Multi-phase refactoring of cast extraction to support .fdx, .highland, and .fountain via SwiftCompartido
feature_name: Compartido-Based Cast Extraction
starting_point_commit: 9ec2732e8879b1b3aad628629f1d3a4a8bdf993a
state: in_progress
---

# EXECUTION PLAN: Multi-Format Cast List Extraction

## Terminology

**Mission** — A definable, testable scope of work that decomposes into atomic sorties. In this case: Refactor SwiftProyecto's cast extraction from regex-only Fountain parsing to format-agnostic screenplay parsing via SwiftCompartido.

**Sortie** — One autonomous agent's focused task with clear entry/exit criteria. For this mission: dependency setup, API investigation, core refactoring, integration, testing, and documentation updates.

**Work Unit** — A grouping of related sorties (e.g., all sorties within "Dependency Setup" form one work unit).

---

## Mission Overview

**Objective**: Enable SwiftProyecto's cast extraction to transparently support `.fountain`, `.fdx`, and `.highland` screenplay formats by delegating parsing to SwiftCompartido's robust, format-agnostic parsers.

**Current State**: CastExtractor only works with Fountain text via regex pattern matching for UPPERCASE character names. RolesCommand discovers `.fdx` and `.highland` files but can't parse them.

**Target State**:
- CastExtractor delegates to SwiftCompartido parsers (format-transparent)
- RolesCommand discovers and processes all three formats without modification
- All formats extract cast lists into PROJECT.md front matter
- Existing Fountain tests pass unchanged; new tests verify `.fdx` and `.highland`
- No breaking changes to public API

**Success Criteria**:
- ✅ CastExtractor supports `.fountain`, `.fdx`, `.highland` transparently
- ✅ RolesCommand discovers and processes all three formats
- ✅ PROJECT.md cast lists populated from any format
- ✅ Existing Fountain tests pass; new format tests added
- ✅ Error messages distinguish parse failures from unsupported formats
- ✅ Documentation updated (AGENTS.md, inline docs)
- ✅ No public API breakage

---

## Open Questions (Blocking)

These must be resolved **before execution starts**:

1. **SwiftCompartido version pin**: What is the current stable release? Check GitHub tags and compatibility with this branch.
   - **Recommendation**: Pin to `upToNextMajor(from: "X.Y.Z")` pattern (matches SwiftAcervo precedent).

2. **Error handling policy**: On parse failure, should the system:
   - **Option A (Recommended)**: Fail soft — regex fallback + warning log
   - **Option B**: Fail loud — throw error, user must fix screenplay
   - **Option C**: Config-driven per screenplay
   - **Recommendation**: Option A (graceful degradation, matching current behavior).

3. **Test fixture strategy**: For `.fdx` and `.highland` tests:
   - **Option A**: Create minimal valid FDX XML and Highland JSON files by hand
   - **Option B**: Use compartido's existing test fixtures if available
   - **Option C**: Mock the parsers (not recommended — test real parsing)
   - **Recommendation**: Option A (hand-crafted fixtures, small enough to maintain).

4. **Existing test compatibility**: Will existing tests in `ProjectGenerationIntegrationTest` and `RolesCommandTests` require updates after refactoring?
   - **Recommendation**: Audit these tests early (Sortie 1b) to surface breakage before core refactoring.

---

## Work Units & Sorties

### Work Unit 1: API Investigation & Dependency Setup

**Objective**: Resolve blocking questions, investigate SwiftCompartido API, and add dependency.

**Dependencies**: None (parallel-ready).

---

#### Sortie 1a: Investigate SwiftCompartido API & Version
**Objective**: Determine SwiftCompartido's version, API surface, and character extraction method.

**Entry Criteria**:
- SwiftCompartido source code accessible at `/Users/stovak/Projects/package-collection/pkg/SwiftCompartido`
- Read permission on AGENTS.md (project docs)

**Tasks**:
1. Read SwiftCompartido Package.swift to find current version
2. Examine `GuionParsedElementCollection` API (file: `Sources/SwiftCompartido/Sendable/GuionDocumentSnapshot.swift`)
   - Verify `characters: [String]` property exists
   - Verify it's stable and returns deduplicated, sorted names
3. Examine parser routing logic (`GuionDocumentParserSwiftData.loadAndParse()`)
   - Verify it auto-detects file types by extension
   - Verify it throws clear errors for unsupported formats
4. Review error handling patterns (what exceptions do parsers throw?)
5. Check if SwiftCompartido has existing tests for all three formats

**Exit Criteria**:
- ✅ Version identified and documented (e.g., "1.5.0" or "2.0.0-beta")
- ✅ Confirmed: `GuionParsedElementCollection.characters` extracts character names
- ✅ Confirmed: Parser routing works for `.fountain`, `.fdx`, `.highland`
- ✅ Documented: Error types thrown by parsers
- ✅ Documented: Whether compartido tests exist for all formats

**Output**: `SORTIE_1a_API_INVESTIGATION.md` with findings and version recommendation.

---

#### Sortie 1b: Audit Existing Tests for Refactoring Impact
**Objective**: Identify tests that will break or require updates due to refactoring.

**Entry Criteria**:
- SwiftProyecto source code readable
- Test files identified: `CastExtractorTests.swift`, `ProjectGenerationIntegrationTest.swift`, `RolesCommandTests.swift`

**Tasks**:
1. Read all three test files above
2. Identify tests that:
   - Mock or directly call `extractCast(from fountainText: String)` (text-only method)
   - Hardcode `.fountain` file paths or extensions
   - Test regex-specific behavior (parenthetical removal, isLikelyCharacterName logic)
3. For each test, document:
   - Test name
   - Current behavior
   - Expected change after refactoring
   - Mitigation (update test, delete test, or mark deprecated)

**Exit Criteria**:
- ✅ List of tests requiring updates (with reason for each)
- ✅ List of tests that should be deleted (if regex-only)
- ✅ Confidence assessment: "No surprises expected" or "High-impact refactoring"

**Output**: `SORTIE_1b_TEST_AUDIT.md` with detailed breakdown.

---

#### Sortie 1c: Add SwiftCompartido Dependency to Package.swift
**Objective**: Integrate SwiftCompartido as a dependency following the sibling pattern.

**Entry Criteria**:
- Version identified from Sortie 1a
- SwiftProyecto Package.swift readable
- Git working tree clean

**Tasks**:
1. Open `Package.swift`
2. Add SwiftCompartido dependency using sibling pattern:
   ```swift
   sibling(
     "SwiftCompartido",
     remote: "https://github.com/intrusive-memory/SwiftCompartido.git",
     from: "X.Y.Z")  // from Sortie 1a
   ```
3. Add `.product(name: "SwiftCompartido", package: "SwiftCompartido")` to:
   - `SwiftProyecto` target
   - `proyecto` executable target
4. Do **not** add to test target (not needed for tests)
5. Run `swift build` or XcodeBuildMCP to verify no conflicts

**Exit Criteria**:
- ✅ Dependency added to Package.swift
- ✅ Products added to both targets
- ✅ `swift build` succeeds (or XcodeBuildMCP swift_package_build passes)
- ✅ No compilation errors or module conflicts

**Output**: Modified Package.swift (committed as part of this sortie).

---

### Work Unit 2: Core Refactoring

**Objective**: Refactor CastExtractor to use SwiftCompartido parsers, keeping public API unchanged.

**Dependencies**: Work Unit 1 (all three sorties must complete first).

---

#### Sortie 2a: Refactor CastExtractor (Option A: Full Replacement)
**Objective**: Replace CastExtractor internals to delegate to SwiftCompartido, keeping public API stable.

**Entry Criteria**:
- SwiftCompartido added to Package.swift (Sortie 1c)
- Version and API surface confirmed (Sortie 1a)
- Test audit complete (Sortie 1b)
- CastExtractor.swift is readable and modifiable

**Tasks**:
1. Add `import SwiftCompartido` to CastExtractor.swift
2. Deprecate (but keep) private methods:
   - `removeParentheticals(from:)` — no longer used internally
   - `isLikelyCharacterName(_:)` — replaced by compartido parsing
   - Annotate: `@available(*, deprecated, message: "Replaced by SwiftCompartido parsing")`
3. Refactor `extractCast(from fountainText: String) -> [String]`:
   - Create a temporary `.fountain` file in memory (or use `FountainParser(string:)` directly)
   - Parse via compartido
   - Extract `.characters` property
   - Return sorted array (compartido may already sort; verify)
   - On error: Fall back to regex extraction with warning (Option A: fail soft)
4. Update `extractCast(from fileURL: URL) -> [String]`:
   - Detect file type by extension
   - Route to appropriate compartido parser (auto-detection via `GuionDocumentParserSwiftData.loadAndParse()` or manual routing)
   - Extract characters via `.characters`
   - On parse error: Fallback to regex (Fountain only) + warning
   - On unsupported format: Throw `UnsupportedScreenplayFormat` error (new error type)
5. Update inline documentation:
   - Remove Fountain-specific examples
   - Add examples showing `.fountain`, `.fdx`, `.highland` support
   - Document fallback behavior

**Exit Criteria**:
- ✅ CastExtractor compiles with no errors
- ✅ Public API unchanged (`extractCast(from fileURL:)` and `extractCast(from fountainText:)` signatures identical)
- ✅ Private methods deprecated (annotations present)
- ✅ Error handling implemented (fallback on parse failure, clear error on unsupported format)
- ✅ Inline docs updated with multi-format examples
- ✅ No warnings in build

**Output**: Modified CastExtractor.swift (prepared for commit).

---

#### Sortie 2b: Error Handling & Fallback Testing (Unit Tests for CastExtractor)
**Objective**: Create or update unit tests to verify error handling and fallback behavior.

**Entry Criteria**:
- Sortie 2a complete (refactored CastExtractor)
- Test audit complete (Sortie 1b) showing which tests need updates

**Tasks**:
1. Update `CastExtractorTests.swift`:
   - Update existing tests to work with new implementation
   - Add `test_extractCast_from_fountain_file()` — verify text-based method still works
   - Add `test_extractCast_from_fdx_file()` — requires FDX fixture (from Sortie 4a)
   - Add `test_extractCast_from_highland_file()` — requires Highland fixture (from Sortie 4a)
   - Add `test_extractCast_handles_unsupported_extension()` — throws `UnsupportedScreenplayFormat`
   - Add `test_extractCast_fallback_on_parse_error()` — parser fails, regex fallback succeeds with warning
   - Add `test_extractCast_deduplicates_and_sorts()` — verify output format matches old behavior
2. Mark deprecated tests with `@available(*, deprecated)` if they tested regex-only behavior

**Exit Criteria**:
- ✅ All tests pass (use `swift_package_test` via XcodeBuildMCP)
- ✅ Coverage: All three formats tested (fountain, fdx, highland)
- ✅ Coverage: Error handling tested (unsupported, parse failure, fallback)
- ✅ Coverage: Deduplication and sorting verified
- ✅ No test warnings

**Output**: Modified CastExtractorTests.swift (prepared for commit).

---

### Work Unit 3: Integration

**Objective**: Update RolesCommand to use format-agnostic cast extraction.

**Dependencies**: Work Unit 2 (Sortie 2a must complete first).

---

#### Sortie 3a: Update RolesCommand for Multi-Format Support
**Objective**: Modify RolesCommand to discover and process `.fountain`, `.fdx`, and `.highland` files transparently.

**Entry Criteria**:
- Sortie 2a complete (refactored CastExtractor)
- RolesCommand.swift is readable and modifiable
- DirectoryContext.swift shows screenplay discovery logic

**Tasks**:
1. Update `RolesCommand.resolveScripts()` method (line 128-134):
   - Current: only discovers `*.fountain`
   - New: discover `*.fountain`, `*.fdx`, `*.highland` (use `DirectoryContext.screenplayExtensions` if available, or hardcode same list)
   - Update help text: "Screenplay file (.fountain, .fdx, .highland), directory, or glob to scan"
2. Update screenplay processing loop (line 150-195):
   - Change line 161: `extractor.extractCast(from: text)` → `try extractor.extractCast(from: script)`
   - This routes to file-based method (auto-detects format)
   - Add try/catch for potential `UnsupportedScreenplayFormat` errors
3. Update progress messages:
   - "Fountain script" → "screenplay" (generic)
   - "Could not parse screenplay format; using Fountain pattern matching as fallback" → use when fallback occurs
4. Verify that existing error handling still works:
   - `SystemLanguageModel.default.isAvailable` check
   - Model failure → fallback to regex
5. No changes to the guided generation logic (it's fine as-is)

**Exit Criteria**:
- ✅ RolesCommand compiles with no errors
- ✅ Screenplay discovery includes all three formats
- ✅ Help text updated to list all formats
- ✅ File-based extraction called (format auto-detection)
- ✅ Error handling for unsupported formats
- ✅ Fallback behavior preserved
- ✅ No warnings in build

**Output**: Modified RolesCommand.swift (prepared for commit).

---

### Work Unit 4: Testing & Fixtures

**Objective**: Create test fixtures and comprehensive test coverage for all screenplay formats.

**Dependencies**: Work Unit 3 (Sortie 3a should complete first, but Sorties 4a & 4b can start in parallel with Sortie 2b).

---

#### Sortie 4a: Create Test Fixtures (`.fdx` and `.highland`)
**Objective**: Create minimal but valid test screenplay files in `.fdx` and `.highland` formats for testing.

**Entry Criteria**:
- Test audit complete (Sortie 1b)
- SwiftCompartido source code available (reference its test fixtures if needed)

**Tasks**:
1. Create `Tests/SwiftProyectoTests/Fixtures/sample.fdx`:
   - Minimal valid FDX XML structure
   - Include 2–3 character names (e.g., "ALICE", "BOB", "NARRATOR")
   - Can copy from SwiftCompartido's test fixtures if available, or create manually
2. Create `Tests/SwiftProyectoTests/Fixtures/sample.highland`:
   - Minimal valid Highland format (likely JSON-based)
   - Include 2–3 character names
   - Reference SwiftCompartido's Highland parser or docs for format details
3. Verify both files parse correctly using SwiftCompartido directly (quick sanity test)
4. Document expected output: "sample.fdx should parse to [ALICE, BOB, NARRATOR]" etc.

**Exit Criteria**:
- ✅ sample.fdx created and valid (compartido parser accepts it)
- ✅ sample.highland created and valid
- ✅ Both files contain expected character names
- ✅ Fixture documentation complete (expected outputs documented)

**Output**: Test fixtures in place; documented expected outputs.

---

#### Sortie 4b: Integration Tests for RolesCommand
**Objective**: Verify RolesCommand works end-to-end with all screenplay formats.

**Entry Criteria**:
- Sortie 3a complete (RolesCommand updated)
- Test fixtures created (Sortie 4a)
- Existing RolesCommandTests identified

**Tasks**:
1. Audit existing RolesCommandTests (if any) and update for multi-format support
2. Add new integration tests (if RolesCommandTests doesn't exist, create it):
   - `test_roles_command_discovers_fountain_files()` — verify .fountain discovery
   - `test_roles_command_discovers_fdx_files()` — verify .fdx discovery
   - `test_roles_command_discovers_highland_files()` — verify .highland discovery
   - `test_roles_command_processes_mixed_formats()` — directory with all three formats, deduplicates across all
   - `test_roles_command_deduplicates_case_insensitive()` — "ALICE" in .fountain, "alice" in .fdx → one entry
   - `test_roles_command_fallback_on_parse_error()` — bad FDX file, fallback succeeds
3. Each test should:
   - Create a temporary PROJECT.md in test directory
   - Run RolesCommand with `--dry-run` to inspect output (no write)
   - Verify cast list is correct and deduplicated
4. Use mocking or test fixtures; do not depend on actual screenplay files outside of Fixtures/

**Exit Criteria**:
- ✅ All integration tests pass
- ✅ Coverage: all three formats individually tested
- ✅ Coverage: mixed-format directory tested
- ✅ Coverage: deduplication across formats tested
- ✅ Coverage: fallback behavior tested
- ✅ No external file dependencies (use fixtures or mocks)

**Output**: New or updated RolesCommandTests.swift; all tests pass.

---

#### Sortie 4c: Existing Test Compatibility Check
**Objective**: Verify that existing non-role-extraction tests still pass after refactoring.

**Entry Criteria**:
- All previous sorties in this work unit complete
- Audit from Sortie 1b complete (showing which tests might break)

**Tasks**:
1. Run full test suite: `swift_package_test` (XcodeBuildMCP)
2. For each test that was flagged in Sortie 1b audit:
   - Confirm it passes or identify the specific failure
   - If failure is expected, verify the fix (from Sortie 4b) addresses it
   - If failure is unexpected, document and flag for investigation
3. Check `ProjectGenerationIntegrationTest` specifically:
   - Verify generation still works with refactored CastExtractor
   - If it hardcodes `.fountain`, update it to work with new API

**Exit Criteria**:
- ✅ All tests pass (0 failures, 0 errors)
- ✅ Sorties 2b and 4b tests all passing
- ✅ Existing tests (ProjectGenerationIntegrationTest, etc.) all passing
- ✅ No warnings in test output
- ✅ Test count preserved or increased (no tests deleted without reason)

**Output**: Clean test run; all tests passing.

---

### Work Unit 5: Documentation

**Objective**: Update project documentation to reflect multi-format support.

**Dependencies**: Work Unit 3 (Sortie 3a should complete first for context).

---

#### Sortie 5a: Update Inline Documentation & Code Comments
**Objective**: Update CastExtractor and RolesCommand inline docs to reflect new capabilities.

**Entry Criteria**:
- Sortie 2a complete (refactored CastExtractor)
- Sortie 3a complete (updated RolesCommand)

**Tasks**:
1. Update CastExtractor.swift:
   - Remove Fountain-specific examples from class docstring
   - Add multi-format example: "Supports .fountain, .fdx, .highland files"
   - Document error handling: "Falls back to regex pattern matching on parse failure"
   - Document unsupported formats: "Throws UnsupportedScreenplayFormat for unrecognized extensions"
2. Update RolesCommand.swift:
   - Update discussion: list all supported formats
   - Update example commands to include .fdx and .highland:
     ```
     proyecto roles episode.fountain
     proyecto roles episode.fdx
     proyecto roles episode.highland
     ```
   - Update help text for `input` argument
3. Add deprecation notices to regex-only methods (if still present)

**Exit Criteria**:
- ✅ CastExtractor docs updated with multi-format examples
- ✅ RolesCommand docs updated with multi-format examples
- ✅ Error handling documented
- ✅ No outdated references to Fountain-only support
- ✅ Code compiles with no documentation warnings

**Output**: Updated source file docstrings.

---

#### Sortie 5b: Update AGENTS.md Documentation
**Objective**: Update project documentation with multi-format cast extraction information.

**Entry Criteria**:
- Sortie 5a complete (inline docs updated)
- AGENTS.md readable and modifiable

**Tasks**:
1. Find § Building or § Cast List section in AGENTS.md
2. Add or update subsection: "Screenplay Format Support"
   - List all supported formats: `.fountain`, `.fdx`, `.highland`
   - Explain: CastExtractor now uses SwiftCompartido for format-agnostic parsing
   - Note fallback behavior: "On parse error, falls back to Fountain regex pattern matching"
3. Add reference to SwiftCompartido (dependency) if there's a § Dependencies section
4. Update any hardcoded `.fountain` references to "screenplay format(s)"
5. Verify no contradictions with existing cast list documentation

**Exit Criteria**:
- ✅ AGENTS.md updated with new subsection
- ✅ All supported formats listed and explained
- ✅ SwiftCompartido mentioned as parsing engine
- ✅ Fallback behavior documented
- ✅ No contradictions with other sections
- ✅ Examples use generic "screenplay" terminology

**Output**: Updated AGENTS.md.

---

## Execution Dependencies

### Dependency Graph

```
Work Unit 1 (API Investigation & Dependency Setup)
├── Sortie 1a (API Investigation) — parallel with 1b, 1c
├── Sortie 1b (Test Audit) — parallel with 1a, 1c
└── Sortie 1c (Add Dependency) — parallel with 1a, 1b; blocks Unit 2
    ↓
Work Unit 2 (Core Refactoring)
├── Sortie 2a (Refactor CastExtractor) — blocks Unit 3
└── Sortie 2b (Unit Tests) — parallel with 2a; blocks Unit 4b
    ↓
Work Unit 3 (Integration)
└── Sortie 3a (Update RolesCommand) — blocks Unit 4b, Unit 5a
    ↓
Work Unit 4 (Testing & Fixtures)
├── Sortie 4a (Create Fixtures) — parallel with 4b; blocks 4b
├── Sortie 4b (Integration Tests) — depends on 3a, 4a; blocks 4c
└── Sortie 4c (Compatibility Check) — last gate; blocks finalization
    ↓
Work Unit 5 (Documentation)
├── Sortie 5a (Inline Docs) — depends on 2a, 3a
└── Sortie 5b (AGENTS.md) — depends on 5a
```

### Critical Path

1. Work Unit 1 (all sorties must complete; 1a, 1b, 1c can be parallel)
2. Sortie 1c completion blocks: Sortie 2a start
3. Sortie 2a completion blocks: Sortie 3a start
4. Sortie 3a completion blocks: Sortie 4b start
5. Sortie 4a completion blocks: Sortie 4b start
6. Sortie 4b completion blocks: Sortie 4c start
7. Sortie 4c completion blocks: PR finalization
8. Work Unit 5 can start after Sortie 3a, finalize after 4c

### Parallel Opportunities

- **Sorties 1a, 1b, 1c**: Can all be dispatched in parallel (no dependencies)
- **Sorties 2a, 2b**: Slightly sequential (2a must finish first, but can overlap)
- **Sorties 4a, 4b**: Parallel dispatch possible (4a output ready by time 4b needs it)
- **Sorties 5a, 5b**: Sequential (5b depends on 5a completeness)

**Recommended parallelization**:
- Dispatch Sorties 1a, 1b, 1c immediately (three agents in parallel)
- After 1c completes: Dispatch Sorties 2a, 2b (two agents; 2b waits for 2a insights)
- After 2a, 3a complete: Dispatch Sorties 4a, 4b (two agents in parallel)
- After 4a, 4b complete: Dispatch Sortie 4c
- After 4c complete: Dispatch Sorties 5a, 5b sequentially

---

## Rollback & Recovery Plan

**Rollback scenarios**:

1. **If Sortie 1a reveals compartido API incompatibility**:
   - STOP. Do not proceed past Work Unit 1.
   - Alternative: Use Option B (wrapper layer) instead of full replacement.
   - Re-scope: Work Unit 2 becomes smaller (less refactoring).

2. **If Sortie 2a reveals incompatible API changes**:
   - Rollback changes to CastExtractor
   - Escalate to ask for version pin clarification or API docs
   - Option: Pin to older compartido version

3. **If Sortie 4c tests fail**:
   - Investigate which test is failing
   - If it's a test audit miss: Fix and re-run 4c
   - If it's integration issue: Debug and patch the affected sortie
   - No rollback needed; fix forward

4. **If parse errors are frequent (Sortie 4b/4c)**:
   - Review fallback policy decision
   - Consider whether "fail soft" (regex fallback) is appropriate
   - May need to switch to "fail loud" (throw error) if fallback masks real problems

---

## Notes & Assumptions

- **SwiftCompartido stability**: Assuming `GuionParsedElementCollection.characters` property is stable. If it changes, error will surface early in Sortie 1a.
- **FDX and Highland fixtures**: Assuming compartido can parse hand-crafted minimal fixtures. If not, will escalate to use compartido's own test fixtures or mocks.
- **Test count**: Expecting test count to increase (new format tests) or stay same (if regex-only tests are removed). No net loss expected.
- **Backwards compatibility**: Public API unchanged; only internals and error messages updated. Existing code depending on CastExtractor should work unchanged.
- **Feature branch**: Will be created by `start` command as `mission/compartido-cast-extraction/<NN>`.

---

## Next Steps

1. **Refine this plan**: Run `/mission-supervisor refine EXECUTION_PLAN.md` to:
   - Identify any blocking open questions (Pass 1 = hard stop)
   - Check sortie atomicity (can each sortie fit in one agent context?)
   - Verify parallelism is sound
   - Find any vague exit criteria

2. **Start execution**: Run `/mission-supervisor start EXECUTION_PLAN.md` to:
   - Record the starting commit
   - Create a mission branch
   - Dispatch the first sorties (1a, 1b, 1c in parallel)
   - Begin iterating

3. **Monitor progress**: Run `/mission-supervisor status` or `/mission-supervisor resume` to:
   - Check sortie status
   - Dispatch next sorties as dependencies clear
   - Collect results

---

**Prepared by**: Mission Supervisor (breakdown)  
**Plan Version**: 1.0  
**Status**: Ready for Refinement  
**Estimated Sorties**: 11 (5 work units; distributed across sorties)

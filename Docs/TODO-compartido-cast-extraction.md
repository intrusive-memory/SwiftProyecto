---
type: project
name: compartido-cast-extraction
description: Refactor cast list extraction to use SwiftCompartido for multi-format screenplay parsing
---

# TODO: Refactor Cast List Extraction to Use SwiftCompartido

**Status**: Planning  
**Priority**: Medium  
**Scope**: Multi-format screenplay parsing for cast list discovery  
**Related**: RolesCommand, CastExtractor, PROJECT.md generation  

## Overview

Currently, SwiftProyecto's `CastExtractor` is tightly coupled to Fountain format and uses regex patterns to scan for UPPERCASE character names. This approach is brittle and cannot support `.fdx` (Final Draft) or `.highland` files, which the CLI already recognizes as valid screenplay formats.

SwiftCompartido already provides robust, format-agnostic screenplay parsing via:
- `FountainParser` for `.fountain` files
- `FDXParser` for `.fdx` files  
- Highland support via `GuionParsedElementCollection`
- Auto-detection and routing via `GuionDocumentParserSwiftData.loadAndParse()`

**Goal**: Refactor cast extraction to use SwiftCompartido's parsers, enabling format-transparent character discovery.

---

## Changes Required

### 1. Add SwiftCompartido Dependency

**File**: `Package.swift`

- [ ] Add SwiftCompartido to dependencies using the sibling pattern (matches SwiftAcervo precedent)
  - Remote: `https://github.com/intrusive-memory/SwiftCompartido.git`
  - Use `upToNextMajor(from:)` version constraint
  - Support local sibling checkout via `useLocalSiblings` pattern

**Code pattern**:
```swift
sibling(
  "SwiftCompartido",
  remote: "https://github.com/intrusive-memory/SwiftCompartido.git",
  from: "X.Y.Z")  // pinned version TBD
```

- [ ] Add SwiftCompartido product to SwiftProyecto target dependencies
- [ ] Add SwiftCompartido product to proyecto executable dependencies

---

### 2. Refactor CastExtractor

**File**: `Sources/SwiftProyecto/LLMBackend/CastExtractor.swift`

The existing `CastExtractor` is Fountain-only. Three refactoring options:

#### Option A: Replace entirely (recommended)
- [ ] Deprecate the regex-based `isLikelyCharacterName()` and `removeParentheticals()` private methods
- [ ] Replace `extractCast(from fountainText: String)` → use compartido parsing internally
- [ ] Keep `extractCast(from fileURL: URL)` public API unchanged (auto-detects format via file extension)
- [ ] Update internals to:
  1. Detect file type by extension (`.fountain`, `.fdx`, `.highland`, etc.)
  2. Route to appropriate compartido parser
  3. Extract characters via `GuionParsedElementCollection.characters` property
  4. Return sorted [String] as before

**Benefits**: Single responsibility, reuses battle-tested parsing logic, transparent format support

#### Option B: Wrapper layer
- [ ] Keep regex extractor as fallback for pure-text streams (no file path)
- [ ] Add `extractCast(from fileURL:)` override that delegates to compartido
- [ ] Document: "Use file-based method for .fdx/.highland; text-based method only supports Fountain pattern matching"

---

### 3. Create ScreenplayParser Service (if Option A insufficient)

**File**: `Sources/SwiftProyecto/Services/ScreenplayParser.swift` (new)

If compartido integration becomes complex, isolate in a dedicated service:

```swift
public struct ScreenplayParser {
  /// Parse a screenplay file (any supported format) and extract character names
  public static func extractCharacters(from fileURL: URL) throws -> [String]
  
  /// Underlying GuionParsedElementCollection for advanced queries
  public static func parse(fileURL: URL) throws -> GuionParsedElementCollection
}
```

---

### 4. Update RolesCommand

**File**: `Sources/proyecto/RolesCommand.swift`

- [ ] Line 128-161: Update screenplay file resolution to support all formats
  - Current: only discovers `*.fountain` by default
  - New: discover `*.fountain`, `*.fdx`, `*.highland` (see DirectoryContext.screenplayExtensions)
  - Update help text to list all supported formats

- [ ] Line 156-161: Replace text-only parsing with format-agnostic extraction
  ```swift
  // OLD (Fountain-only regex):
  let candidates = extractor.extractCast(from: text)
  
  // NEW (all formats):
  let candidates = try extractor.extractCast(from: script)  // fileURL, not text
  ```

- [ ] Preserve fallback behavior:
  - If compartido parsing fails, fall back to old regex extraction (Fountain-only)
  - Log warning: "⚠ Could not parse screenplay format; using Fountain pattern matching as fallback"

- [ ] Update progress/error messages to reference "screenplay" instead of "Fountain script"

---

### 5. Tests

**File**: `Tests/SwiftProyectoTests/CastExtractorTests.swift` (may need updates)

- [ ] Add test fixtures:
  - Sample `.fdx` file (minimal FDX XML structure)
  - Sample `.highland` file
  - Existing `.fountain` files continue to work

- [ ] Test suite:
  - [ ] `test_extractCast_from_fountain_file()` — preserve existing behavior
  - [ ] `test_extractCast_from_fdx_file()` — new, verify character extraction
  - [ ] `test_extractCast_from_highland_file()` — new, verify character extraction
  - [ ] `test_extractCast_handles_unsupported_extension()` — throws appropriate error
  - [ ] `test_extractCast_fallback_to_regex_on_parse_failure()` — error resilience
  - [ ] `test_extractCast_deduplicates_and_sorts()` — verify output format

**Existing tests that may need updates**:
  - `ProjectGenerationIntegrationTest` — may have hardcoded `.fountain` patterns
  - `RolesCommandTests` — verify with new multi-format support

---

### 6. Documentation

**Files**: `AGENTS.md`, `CLAUDE.md`

- [ ] Update AGENTS.md § Building:
  - List all supported screenplay formats (`.fountain`, `.fdx`, `.highland`)
  - Document compartido dependency relationship
  - Note: CastExtractor now format-transparent

- [ ] Update CLAUDE.md (if present):
  - Note SwiftCompartido as internal parsing engine
  - Reference compartido docs for advanced screenplay access

- [ ] Update inline doc in CastExtractor:
  - Remove Fountain-specific examples
  - Add multi-format examples
  - Document fallback behavior

---

## Implementation Order

1. **Phase 1 (Dependency Setup)**
   - [ ] Add SwiftCompartido to Package.swift
   - [ ] Verify builds locally with sibling checkout (or pin release)
   - [ ] Build SwiftProyecto to ensure no conflicts

2. **Phase 2 (Core Refactoring)**
   - [ ] Refactor CastExtractor (Option A or B)
   - [ ] Add comprehensive error handling for unsupported formats
   - [ ] Implement fallback to regex for parse failures

3. **Phase 3 (Integration)**
   - [ ] Update RolesCommand screenplay discovery
   - [ ] Test with all screenplay formats
   - [ ] Verify existing Fountain workflows unaffected

4. **Phase 4 (Testing & Docs)**
   - [ ] Add test fixtures and unit tests
   - [ ] Update inline documentation
   - [ ] Update AGENTS.md

5. **Phase 5 (Optional Cleanup)**
   - [ ] Remove or deprecate regex-only helper methods if appropriate
   - [ ] Consider adding `ScreenplayParser` service if interface becomes public

---

## Open Questions

1. **Version pin for SwiftCompartido**: Check current release version and compatibility
2. **FDX test fixture**: Create minimal valid FDX XML for tests, or mock?
3. **Highland test fixture**: Verify Highland format parser requirements
4. **Fallback policy**: On parse error, should we:
   - Fail loud (throw error, user must fix screenplay)?
   - Fail soft (regex fallback with warning)?
   - Config-driven?
5. **API stability**: Will compartido `GuionParsedElementCollection.characters` remain stable? (Likely yes for internal use)

---

## Success Criteria

- ✅ CastExtractor supports `.fountain`, `.fdx`, `.highland` transparently
- ✅ RolesCommand discovers and processes all three formats
- ✅ PROJECT.md cast list populated from any screenplay format
- ✅ Existing Fountain-based tests pass unchanged
- ✅ New format-specific tests verify `.fdx` and `.highland` extraction
- ✅ Error messages distinguish parse failures from format-unsupported errors
- ✅ Documentation updated with supported formats and compartido integration notes
- ✅ No breaking changes to public CastExtractor API

---

## Related Issues / PRs

- Blocks: Multi-format screenplay support in SwiftProyecto
- Enables: Future FDX workflow improvements
- Depends: SwiftCompartido availability and API stability

---

## Notes

- This refactoring decouples format parsing from character discovery, improving maintainability.
- SwiftCompartido's parsers are more comprehensive than regex-based extraction (handles edge cases, malformed scripts, etc.).
- Fallback to regex ensures graceful degradation if compartido parsing fails (rare but possible for corrupted files).
- Consider this a stepping stone toward broader screenplay manipulation capabilities (scene breakdown, character relationships, etc.) once compartido integration is stable.

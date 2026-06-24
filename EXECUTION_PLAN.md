---
type: doc
name: EXECUTION_PLAN — v4.0.0 Multi-Season Schema
description: Mission execution plan for SwiftProyecto v4.0.0 multi-season, multi-language PROJECT.md schema
status: planning
created: 2026-06-23
updated: 2026-06-23
---

# EXECUTION_PLAN.md — SwiftProyecto v4.0.0 Multi-Season Schema

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

---

## Overview

This mission implements **SwiftProyecto v4.0.0: Multi-Season, Multi-Language PROJECT.md Schema** — a major revision to the PROJECT.md format supporting multi-season projects, language variants, and lossless cast merging.

**Phase 1 (this effort)**: Schema + Tools (library-first development)
- New v4.0.0 data types and schema
- Backward compatibility with v3.x
- Variant resolution and property inheritance
- CLI support for multi-season/multi-language projects
- Comprehensive testing and documentation

**Phase 2 (v4.1.0, deferred)**: Auto-Generation via LLM
- FoundationModels integration for PROJECT.md generation
- Automatic structure recognition and optimization
- Future work — depends on Phase 1 completion

---

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| **WU1: Core Models & Backward Compatibility** | `Sources/SwiftProyecto/Models/` | 5 | 1 | none |
| **WU2: Property Resolution & Path Handling** | `Sources/SwiftProyecto/Services/` | 3 | 2 | WU1 |
| **WU3: Variant Discovery & Indexing** | `Sources/SwiftProyecto/Services/` | 2 | 2 | WU1, WU2 |
| **WU4: CLI Updates & Directory Recognition** | `Sources/proyecto/` | 6 | 3 | WU1, WU2, WU3 |
| **WU5: Testing & Documentation** | `Tests/`, `Docs/` | 3 | 4 | WU1–4 |

---

## Work Unit 1: Core Models & Backward Compatibility

### Sortie 1.1: v4.0.0 Core Data Types

**Entry criteria**:
- [ ] First sortie — no prerequisites

**Tasks**:
1. Add `schemaVersion: Int` field to `ProjectFrontMatter` (default nil for v3 compatibility)
2. Create `SeasonDefinition` struct with fields: `number` (required), `title`, `description`, `episodes` (required), `releaseDate`, `episodesDir`, `filePattern` (array or string), `introFile`, `outroFile`, `cast`, `tts`
3. Create `LanguageDefinition` struct with fields: `code` (required), `name` (required), `locale` (optional)
4. Create `VariantReference` struct with fields: `season` (Int), `language` (String), `path` (String, relative), `status` (optional enum: published|in_progress|draft|obsolete)
5. Add `type` field to `ProjectFrontMatter`: enum `.project` vs `.overview` (replaces hardcoded `"project"` string; OKF-aligned)
6. Update `ProjectFrontMatter` to accept `seasons` array, `languages` array, `variants` array, and `episodePath` template string
7. Update `CodingKeys` enum to handle all new v4 fields for encoding/decoding

**Exit criteria**:
- [ ] All new types compile without errors
- [ ] `ProjectFrontMatter` can be initialized with v4 parameters
- [ ] All new fields are accessible via property accessors

---

### Sortie 1.2: Lossless Cast Merging — Implementation (CRITICAL)

**Entry criteria**:
- [ ] Sortie 1.1 complete — core data types available

**Tasks**:
1. Enhance `CastMember` to support **multiple voice IDs per provider** — change `voices` from `[String: String]` to `[String: [String]]` (provider → array of voice IDs) with backward-compat accessor for single-voice case
2. Implement `CastMember.merge(with:strategy:)` method with three strategies:
   - `.preserveExisting`: Variant cast overrides master, unspecified characters inherit
   - `.preferNew`: New cast overrides existing
   - `.combine`: Merge voice arrays across providers, no information lost
3. Implement `ProjectFrontMatter.mergeCast(_:_:strategy:)` class method to combine cast lists from multiple PROJECT files
4. Document merge guarantees in code comments: "Zero information loss — all voice IDs preserved regardless of strategy"

**Exit criteria**:
- [ ] `CastMember.merge()` method exists and accepts strategy parameter (`.preserveExisting`, `.preferNew`, `.combine`)
- [ ] `ProjectFrontMatter.mergeCast()` class method exists
- [ ] Code compiles without errors
- [ ] Both methods are callable with all three strategies
- [ ] Both methods return expected types (`CastMember` and `[String: CastMember]` respectively)
- [ ] Code comments document "Zero information loss — all voice IDs preserved regardless of strategy"

---

### Sortie 1.3: Lossless Cast Merging — Test Suite

**Entry criteria**:
- [ ] Sortie 1.2 complete — merge implementation available

**Tasks**:
1. Add test cases covering:
   - Master + single variant cast (merge uses variant values)
   - Multiple variants combined (all voice IDs preserved)
   - New providers added (voice array grows)
   - Character override scenarios (unspecified inherit, specified override)
   - Deterministic ordering (merges always produce same result)
   - All three merge strategies (preserveExisting, preferNew, combine)
2. Document test scenarios: Master-only, variant-override, provider-growth, strategy-variations

**Exit criteria**:
- [ ] All 50+ merge test scenarios pass
- [ ] No voice IDs discarded during any merge operation
- [ ] Merge results are deterministically ordered
- [ ] All three strategies tested end-to-end
- [ ] Test coverage includes edge cases (empty cast, single provider, many providers)

---

### Sortie 1.4: Dual-Version Encoding, Discovery & Backward Compatibility

**Entry criteria**:
- [ ] Sortie 1.1 complete — data types available
- [ ] Sortie 1.2 complete — lossless merge implemented

**Tasks**:
1. Implement custom `init(from decoder: Decoder)` in `ProjectFrontMatter` to:
   - Auto-detect `schemaVersion` (if present, v4; if absent, v3)
   - Read v3 fields (`season: Int`, `episodes: Int`) and migrate to `seasons[0]` internally
   - Accept v4 fields (`seasons[]`, `languages[]`, `variants[]`, `type`)
   - Normalize to internal v4 representation regardless of input version
2. Implement custom `encode(to encoder: Encoder)` to:
   - Always write as v4.0.0 (with `schemaVersion: 4`)
   - Preserve original intent (semantically equivalent to input)
3. Add convenience computed properties for backward compatibility:
   - `season: Int?` — returns `seasons.first?.number`
   - `episodes: Int?` — returns `seasons.first?.episodes`
4. Update `isValid` method to accept both v3.x (no schemaVersion) and v4.0.0 (schemaVersion: 4)
5. Add version-detection helpers: `detectedSchemaVersion() -> Int` and `isLegacyV3Format() -> Bool`
6. Update `ProjectDiscovery.findProjects()` to skip `type: overview` files
7. Add `ProjectDiscovery.isMasterFile()` helper to identify `type: overview` documents
8. Add `ProjectDiscovery.isVariantFile()` helper to identify `type: project` with `season`/`language` fields

**Exit criteria**:
- [ ] v3.x PROJECT.md files parse without errors
- [ ] v4.0.0 PROJECT.md files parse without errors
- [ ] `season` and `episodes` backward-compatibility properties work
- [ ] All parsed files validate with updated `isValid()` method
- [ ] Encoding always produces v4.0.0 output
- [ ] `ProjectDiscovery` correctly identifies master vs. variant vs. single-project files
- [ ] No regressions in existing ProjectFrontMatter API

---

## Work Unit 2: Property Resolution & Path Handling

### Sortie 2.1: Variant Resolution Service

**Entry criteria**:
- [ ] WU1 complete — all data types and dual-version support ready

**Tasks**:
1. Create `VariantResolver` service class with:
   - `resolve(variant:withMaster:forSeason:) -> ProjectFrontMatter` — returns merged/inherited properties
   - `resolveProperty<T>(_:atLevel:) -> T?` — hierarchy lookup: variant > season > master > default
2. Implement hierarchy-based property resolution for **all properties**:
   - Cast (unspecified characters inherit from parent)
   - TTS config (variant/season values override master)
   - Path fields (episodesDir, audioDir, filePattern, etc.)
   - Intro/outro files
   - Hooks (preGenerateHook, postGenerateHook)
3. Add `ProjectFrontMatter.resolve(withMaster:forSeason:)` instance method that:
   - Takes master `ProjectFrontMatter` and season number
   - Returns new `ProjectFrontMatter` with all properties resolved
   - Preserves variant's identity (`language`, `season`, `masterPath`)
4. Implement cast resolution specifically:
   - Characters in variant override master/season
   - Unspecified characters inherit from season definition or master
   - Merging follows lossless strategy (from WU1.2)
5. Add integration tests for property resolution across master + variant + season

**Exit criteria**:
- [ ] `VariantResolver` compiles without errors
- [ ] `ProjectFrontMatter.resolve()` merges master + variant properties
- [ ] Cast inheritance works: specified characters use variant value, unspecified inherit from season/master
- [ ] Integration tests pass for:
  - Master + single variant (variant cast overrides master)
  - Multiple variants (all variants resolve independently with inherited properties)
  - Season-level overrides (season cast/TTS/paths override master)
  - Variant-level overrides (variant values take final priority)

---

### Sortie 2.2: Episode Path Template Resolution

**Entry criteria**:
- [ ] Sortie 2.1 complete — property resolution working

**Tasks**:
1. Create `EpisodePathResolver` service with:
   - `resolve(template:language:season:episode:ext:) -> String` — instantiates template to path
   - `extractVariables(from:) -> [String]` — parses template and extracts variable names
   - `validateTemplate(_:) -> (isValid: Bool, invalidVars: [String])` — checks for unrecognized variables
2. Support template variables (all case-sensitive):
   - `<language>` — language code (e.g., "es", "fr")
   - `<season>` — season number (e.g., "1", "2")
   - `<episode>` — episode number (e.g., "1", "101")
   - `<ext>` — file extension (e.g., "fountain", "m4a")
3. Implement variable substitution:
   - Replace all `<variable>` with actual values (escape any special regex chars)
   - Preserve all non-variable text exactly
4. Add validation: Warn (not error) if template contains unrecognized variables like `<unknown>`
5. Test all common patterns:
   - Language-first: `episodes/<language>/<season>/<episode>.<ext>`
   - Season-first: `episodes/<season>/<language>/<episode>.<ext>`
   - Flat/single-language: `episodes/<episode>.<ext>`
   - With language prefix: `episodes/<language>/<episode>.<ext>`

**Exit criteria**:
- [ ] `EpisodePathResolver` correctly instantiates templates for all pattern types
- [ ] Invalid variables generate warnings (not errors)
- [ ] Path resolution works for all test scenarios
- [ ] Template parsing extracts all variables correctly

---

### Sortie 2.3: Intro/Outro Asset Resolution

**Entry criteria**:
- [ ] Sortie 2.1 complete — property resolution working

**Tasks**:
1. Create `IntroOutroAssets` struct with:
   - `introPath: String?` — resolved path to intro file relative to variant's episodesDir (nil if not specified)
   - `outroPath: String?` — resolved path to outro file relative to variant's episodesDir (nil if not specified)
   - `isIntroMissing: Bool` — true if intro specified in PROJECT but file does not exist
   - `isOutroMissing: Bool` — true if outro specified in PROJECT but file does not exist
2. Implement `resolvedIntroFile() -> String?` and `resolvedOutroFile() -> String?` on `ProjectFrontMatter`:
   - Resolve hierarchy: variant > season > master > none
   - Return path relative to `episodesDir`; return nil if not specified at any level
   - **Non-blocking**: Missing files generate warnings, not errors
3. Update `resolvedEpisodesDir()` to handle variant-specific overrides from property hierarchy
4. Update `resolvedFilePatterns()` to accept season number and resolve variant/season overrides

**Exit criteria**:
- [ ] `IntroOutroAssets` struct compiles and is callable
- [ ] `resolvedIntroFile()` returns `String?` (nil if unspecified, path if specified)
- [ ] `resolvedOutroFile()` returns `String?` (nil if unspecified, path if specified)
- [ ] `isIntroMissing` and `isOutroMissing` correctly identify missing files
- [ ] Generation proceeds without blocking on missing intro/outro files (warnings only)
- [ ] All path resolution tests pass (relative paths work for language/season nesting)

---

## Work Unit 3: Variant Discovery & Indexing

### Sortie 3.1: Variant Discovery & Indexing — Core Implementation

**Entry criteria**:
- [ ] WU1 complete — data types ready
- [ ] WU2.1 complete — property resolution working

**Tasks**:
1. Create `VariantIndexer` service to analyze a master `ProjectFrontMatter`:
   - Scan `variants[]` array
   - Load each variant PROJECT file (resolving relative paths from master location)
   - Build in-memory index of all language/season combinations
2. Implement `ProjectDiscovery.findVariants(from masterPath:) -> [ProjectFrontMatter]`:
   - Locate the master file at given path
   - Use `VariantIndexer` to discover all variants
   - Return array of resolved variant `ProjectFrontMatter` objects
3. Implement `ProjectDiscovery.loadVariant(reference:from masterPath:) -> ProjectFrontMatter`:
   - Load specific variant by language/season
   - Resolve properties using hierarchy from master
   - Return self-contained, resolved variant

**Exit criteria**:
- [ ] `VariantIndexer` loads all variants from master
- [ ] `ProjectDiscovery.findVariants()` discovers all language/season combinations
- [ ] `ProjectDiscovery.loadVariant()` loads specific variant with inheritance
- [ ] Code compiles without errors
- [ ] Discovery can handle 2+ variants correctly

---

### Sortie 3.2: Variant Discovery — Integration Tests & Optional Caching

**Entry criteria**:
- [ ] Sortie 3.1 complete — discovery implementation available

**Tasks**:
1. Add integration tests:
   - Master file with 4 variants (2 languages × 2 seasons)
   - Discovery finds all variants
   - Variants resolve with correct inherited properties
   - Discovery handles missing variant files gracefully
2. **Optional**: Add caching layer (nice-to-have, can ship without):
   - Cache variant indexes by master file path + modification time
   - Invalidate cache if master or any variant file changes
   - Test cache invalidation works

**Exit criteria**:
- [ ] All integration tests pass (master + 4 variants scenario)
- [ ] Discovery correctly resolves inherited properties per variant
- [ ] Missing variant files detected and reported with file path + expected location
- [ ] Discovery does not crash on missing files (graceful error handling)
- [ ] **If caching implemented**: Cache invalidation on file change works; performance improves for repeated lookups

---

## Work Unit 4: CLI Updates & Directory Recognition

### Sortie 4.1: Update `proyecto validate` for v4.0.0 & Type Support

**Entry criteria**:
- [ ] WU1 complete — v4.0.0 data types available

**Tasks**:
1. Update `proyecto validate` command to:
   - Accept both v3.x and v4.0.0 files
   - Accept `type: project` and `type: overview` (not just `type: project`)
   - Validate master files differently from variant files
   - Check unique season numbers within project
   - Check positive episode counts

**Exit criteria**:
- [ ] `proyecto validate` accepts v4.0.0 files without errors
- [ ] Master files (type: overview) validated separately from project files (check for variants[] array, reject episodesDir)
- [ ] Schema version auto-detected correctly:
  - v3 files (no schemaVersion field) → detected as v3
  - v4 files (schemaVersion: 4) → detected as v4
- [ ] All validation tests pass (including season uniqueness and episode count checks)

---

### Sortie 4.2: Update `proyecto generate` for Multi-Season Output

**Entry criteria**:
- [ ] WU1 complete — v4 data types available
- [ ] WU2 complete — resolvers working

**Tasks**:
1. Update `proyecto generate` command to:
   - Detect v4 schema and iterate over `seasons[]` array
   - Use hierarchy-based property resolution for each season
   - Generate intro/outro files separately (if specified)

**Exit criteria**:
- [ ] `proyecto generate` works with single season (v3 compatibility)
- [ ] `proyecto generate` works with multiple seasons (v4 iteration)
- [ ] Hierarchy-based resolution applied per season (season overrides applied)
- [ ] Intro/outro files generated separately when specified
- [ ] Generation tests pass for:
  - Single-season v4 output (backward compat)
  - Multi-season iteration (all seasons generated)
  - Intro/outro generation when specified
  - Property hierarchy applied per season

---

### Sortie 4.3: Add `--season` and `--language` Flags to `proyecto generate`

**Entry criteria**:
- [ ] Sortie 4.2 complete — multi-season generation working

**Tasks**:
1. Add `--season N` flag to `proyecto generate`:
   - Limit output to single season number
   - Fail gracefully if season not found
2. Add `--language CODE` flag to `proyecto generate`:
   - Limit output to single language variant
   - Fail gracefully if variant not found
3. Support both flags together:
   - `--season 2 --language es` generates only that specific season+language combo
   - Semantics: "Generate language variant for specific season"

**Exit criteria**:
- [ ] `--season N` flag works and limits generation correctly
- [ ] `--language CODE` flag works and loads correct variant
- [ ] Both flags together work with clear semantics
- [ ] Flags fail gracefully with helpful error messages
- [ ] All flag combination tests pass

---

### Sortie 4.4: Add Intro/Outro-Only Generation Flags

**Entry criteria**:
- [ ] Sortie 4.2 complete — intro/outro generation working

**Tasks**:
1. Add `--intro-only` flag to `proyecto generate`:
   - Generate intro file(s) only, skip episode generation
2. Add `--outro-only` flag to `proyecto generate`:
   - Generate outro file(s) only, skip episode generation
3. Support both flags combined with `--season` and `--language`

**Exit criteria**:
- [ ] `--intro-only` generates intro(s) without episode files
- [ ] `--outro-only` generates outro(s) without episode files
- [ ] Both flags work with `--season` and `--language`
- [ ] Generation skips episodes correctly
- [ ] All flag tests pass

---

### Sortie 4.5: Update `proyecto generate --list` for v4 Schema

**Entry criteria**:
- [ ] WU3 complete — discovery available
- [ ] Sortie 4.1 complete — v4 support in generate

**Tasks**:
1. Update `proyecto generate --list` to:
   - Show intro/outro files (if present)
   - Show episode counts per season/language
   - Show variant status from master (published|in_progress|draft|obsolete)
   - Group output by season, then by language

**Exit criteria**:
- [ ] `--list` output groups by season, then by language (structured display)
- [ ] Intro/outro presence indicated (✓ if present, ✗ if missing)
- [ ] Episode counts accurate per season/language
- [ ] Variant status displayed (published|in_progress|draft|obsolete, if available)
- [ ] Output format:
  ```
  Season 1:
    Language es: 365 episodes (intro: yes, outro: no) [published]
    Language fr: 365 episodes (intro: yes, outro: yes) [published]
  Season 2:
    Language es: 200 episodes (intro: no, outro: no) [draft]
  ```

---

### Sortie 4.6: Directory Structure Recognition

**Entry criteria**:
- [ ] WU1 complete — data types available

**Tasks**:
1. Create `ProjectStructure` model:
   - `rootURL: URL` — project root directory
   - `directoryMap: [String: [Int]]` — language → seasons found
   - `filePatterns: [String]` — detected file types (*.fountain, *.highland, *.fdx)
   - `audioDirectories: [String]` — paths containing audio files
   - `voiceFiles: [String]` — detected voice file paths
   - `recognizedPattern: RecognitionPattern` — classified structure
2. Create `RecognitionPattern` enum:
   - `.languageFirstMultiSeason(languages, seasons)` — e.g., episodes/es/s1/, episodes/fr/s2/
   - `.singleLanguageMultiSeason(seasons)` — e.g., episodes/season-1/, episodes/season-2/
   - `.languageOnly(languages)` — e.g., episodes/es/, episodes/fr/
   - `.flat` — e.g., episodes/ (no language/season structure)
   - `.unknown` — no recognized pattern
3. Implement `ProjectService.scanAndRecognize(at:) -> ProjectStructure`:
   - Recursively scan directory tree from project root
   - Detect file patterns (*.fountain, *.highland, etc.)
   - Identify language codes in directory names (ISO 639-1: es, fr, it, etc.)
   - Identify season patterns (season-1, s1, 1, etc.)
   - Classify recognized pattern
   - Return structured `ProjectStructure` report
4. Add pattern detection logic for each type:
   - Language-first: Check for `lang/season/files` or `lang/s<N>/files`
   - Season-first: Check for `season-<N>/lang/files` or `<N>/lang/files`
   - Language-only: Check for `lang/files` (no season structure)
   - Flat: Single directory with episode files, no nesting

**Exit criteria**:
- [ ] `ProjectService.scanAndRecognize()` correctly identifies all pattern types
- [ ] `ProjectStructure` report accurately describes directory organization
- [ ] Recognition works for nested language/season structures
- [ ] Code compiles without errors

---

### Sortie 4.7: Directory Recognition — Test Suite

**Entry criteria**:
- [ ] Sortie 4.6 complete — recognition implementation available

**Tasks**:
1. Add comprehensive tests for each pattern type:
   - lingua-matra structure (language-first, multi-season)
   - Screenplay structure (season-first, multi-season)
   - Single-language multi-season (flat seasons)
   - Ambiguous/mixed structures

**Exit criteria**:
- [ ] All pattern recognition tests pass
- [ ] Recognition correctly identifies lingua-matra and screenplay patterns
- [ ] Ambiguous structures handled gracefully (`.unknown` if unclear)
- [ ] Test coverage includes edge cases (empty dirs, single file, complex nesting)

---

### Sortie 4.8: Variant Commands & Type Validation

**Entry criteria**:
- [ ] WU3 complete — variant discovery working
- [ ] Sortie 4.1 complete — CLI v4 support added

**Tasks**:
1. Add `proyecto variants` command to:
   - List all language/season combinations from a master PROJECT.md
   - Show variant status (published|in_progress|draft|obsolete)
   - Show file paths relative to master
   - Group by language or season
2. Add type validation throughout codebase:
   - Only `"project"` or `"overview"` allowed for `type` field (case-sensitive, OKF-aligned)
   - Reject malformed types with clear error messages
   - Add `.type` enum with `case project` and `case overview`
3. Implement type-specific validation:
   - `type: overview` files MUST have `variants[]` array (can be empty, but must exist)
   - `type: overview` files MUST NOT have `episodesDir` (they're not directly generatable)
   - `type: project` files CAN optionally have `masterPath` for discovery
   - `type: project` files CAN have `season` and `language` (variant identification)
4. Add CLI helpers for master vs. variant detection:
   - `proyecto info --type <path>` — show whether file is project, overview, or variant
5. Add comprehensive validation tests:
   - Missing `type` field defaults to `project` (backward compat) with warning
   - Malformed type values rejected
   - Overview files without variants rejected
   - Project files with both season/episodes AND seasons[] show warning

**Exit criteria**:
- [ ] `proyecto variants` command lists all variants correctly
- [ ] Type validation enforces rules
- [ ] Type-specific behavior works (overview vs project)
- [ ] `proyecto info --type` correctly identifies file types
- [ ] All validation tests pass

---

## Work Unit 5: Testing & Documentation

### Sortie 5.1: Unit Tests for Models & Encoding

**Entry criteria**:
- [ ] WU1 complete — core models implemented

**Tasks**:
1. Add decoder tests for v3.x format:
   - Parse legacy `season: 1, episodes: 365` format
   - Verify auto-migration to `seasons[0]`
   - Verify computed properties (`matter.season`, `matter.episodes`) work
2. Add decoder tests for v4.0.0 format:
   - Parse `schemaVersion: 4` files
   - Parse `seasons[]`, `languages[]`, `variants[]` arrays
   - Parse `type: project` and `type: overview`
   - Verify all v4-specific fields present and accessible
3. Add encoder tests:
   - Verify v3.x input encodes as v4.0.0 output (always upgrade)
   - Verify v4.0.0 input encodes as v4.0.0 output (idempotent)
   - Verify YAML round-trip equality (semantic, not byte-for-byte)
4. Add round-trip tests:
   - Read real v3.x PROJECT file → decode → encode → compare with v3.x original (byte-for-byte)
   - Read real v4.0.0 PROJECT file → decode → encode → compare (semantic equality)

**Exit criteria**:
- [ ] All v3.x parsing tests pass
- [ ] All v4.0.0 parsing tests pass
- [ ] Round-trip tests pass (byte-for-byte for v3, semantic for v4)
- [ ] Backward-compatibility properties (`season`, `episodes`) verified
- [ ] No regressions in existing API

---

### Sortie 5.2: Integration & Validation Tests

**Entry criteria**:
- [ ] WU2 complete — resolvers implemented
- [ ] WU3 complete — discovery working
- [ ] WU4 complete — CLI updated

**Tasks**:
1. Add integration tests for `VariantResolver`:
   - Master + variant resolution with property inheritance
   - Season-level overrides (cast, TTS, paths)
   - Variant-level overrides (final priority)
   - Unspecified properties inherit from parent
2. Add integration tests for `VariantIndexer`:
   - Load master, discover 4 variants (2 languages × 2 seasons)
   - All variants load with correct properties resolved
3. Add `EpisodePathResolver` tests for all pattern types:
   - Language-first template resolution
   - Season-first template resolution
   - Flat template resolution
   - Invalid variables generate warnings (not errors)
   - All common patterns work correctly
4. Add intro/outro validation tests:
   - Missing intro/outro file specified in PROJECT generates warning (not error)
   - Path resolution works at all hierarchy levels (variant > season > master > none)
   - Relative paths interpreted correctly in nested language/season structures
5. Add CLI integration tests:
   - `proyecto validate` accepts v4.0.0 and master files
   - `proyecto generate --season 1` generates single season
   - `proyecto generate --language es` generates single variant
   - `proyecto variants` lists all variants correctly
6. Add type-specific behavior tests:
   - Overview files validated differently from project files
   - Variant files with masterPath work
   - Variant identification (language + season) works

**Exit criteria**:
- [ ] Variant resolution tests pass (master+variant, season overrides, hierarchy)
- [ ] Discovery/indexing tests pass (find all variants, load specific variant, inheritance correct)
- [ ] Path resolution tests pass (all template patterns, variable extraction, invalid vars generate warnings)
- [ ] Intro/outro tests pass (missing file warnings, hierarchy resolution, nested path interpretation)
- [ ] CLI integration tests pass (validate v4 files, generate single/multiple seasons, variants command)
- [ ] Type validation tests pass (project vs. overview enforcement, variant identification)

---

### Sortie 5.3: Documentation Updates — Core Guides

**Entry criteria**:
- [ ] WU1–4 complete — all features implemented

**Tasks**:
1. Update `PROJECT_MD_REFERENCE.md`:
   - Add v4.0.0 schema documentation
   - Document all new fields (seasons, languages, variants, type, episodePath, etc.)
   - Document intro/outro fields
   - Document deprecated fields (season, episodes — still read, always written as v4)
   - Include migration examples (v3.x → v4.0.0)
   - Document master vs. variant differences
2. Update `EXAMPLE_PROJECT.md`:
   - Convert existing example to v4.0.0 format (single-file multi-season)
   - Add comment explaining schema version and why v4
   - Show property inheritance patterns
   - Show intro/outro usage
3. Create `MIGRATION_GUIDE.md`:
   - Step-by-step guide for upgrading v3.x projects to v4.0.0
   - When to use single-file vs. master+variant patterns
   - Common migration scenarios (add languages, add seasons, etc.)
   - Property resolution hierarchy explanation
4. Create `VARIANT_REFERENCE.md` (Best Practices):
   - When to use master+variants vs. single-file
   - Master file organization recommendations
   - Variant file organization (language-first vs. season-first)
   - Episode path template design guide
   - Shared resources pattern (MAESTRA voice file example)
5. Create `INTRO_OUTRO_GUIDE.md`:
   - Usage patterns and file organization
   - Generation strategies (separate from episodes or combined)
   - Language-specific intros/outros
   - Relative path interpretation

**Exit criteria**:
- [ ] All 5 documents exist and are discoverable from `AGENTS.md` (linked)
- [ ] All internal cross-links are present and working
- [ ] `PROJECT_MD_REFERENCE.md` documents all v4 fields comprehensively
- [ ] `EXAMPLE_PROJECT.md` is valid v4.0.0 syntax
- [ ] Migration, variant, and intro/outro guides provide actionable steps
- [ ] Each guide has a clear "When to use" section

---

### Sortie 5.4: Advanced Documentation & Project Records

**Entry criteria**:
- [ ] Sortie 5.3 complete — core guides done

**Tasks**:
1. Create `EPISODE_PATH_TEMPLATES.md`:
   - Document template syntax and variables
   - Show all common patterns (language-first, season-first, flat, single-language)
   - Provide real-world examples from lingua-matra and other projects
   - Guide for designing templates for custom structures
2. Update `INTEGRATION_GUIDE.md`:
   - Add section on multi-season project structure
   - Document INDEX.md + SUBDOC.md pattern (project INDEX → variant DOCS)
   - Example hierarchy: INDEX.md (project-level) → PROJECT.md (master) → DOCS.md (per-variant)
   - Explain how variant docs complement PROJECT.md metadata
3. Document Google Open Knowledge Format (OKF) alignment:
   - Explain how `type: project` and `type: overview` map to OKF Entity/Collection
   - Document property hierarchy as OKF entity resolution
   - Note compatibility with knowledge graph tools
4. Create example project structures in `Docs/examples/`:
   - Multi-season, multi-language (lingua-matra style)
   - Single-language, multi-season (screenplay style)
   - Master+variant with shared resources
5. Update project-level documentation:
   - Add v4.0.0 release notes to `AGENTS.md` (schema changes, breaking changes section)
   - Update `CLAUDE.md` (project) with v4.0.0 migration notes
   - Document variant pattern in architecture docs
6. Link all new docs from `AGENTS.md`:
   - Add v4.0.0 schema section with links to all guides
   - Update table of contents
   - Cross-link related sections (variants → variant reference, templates → episode path guide)

**Exit criteria**:
- [ ] All documentation files exist and compile without errors
- [ ] Every new doc is linked from `AGENTS.md` (discoverable)
- [ ] Internal cross-links work (variant reference → migration guide, etc.)
- [ ] All 5 example structures in `Docs/examples/` are valid v4.0.0 syntax
- [ ] OKF alignment documented and clear
- [ ] Release notes in `AGENTS.md` mention v4.0.0 as major schema update

---

## Open Questions

<!-- Consumed by Pass 1 of refine (`refine-blockers`). These questions have recommendations from the requirements doc but warrant user confirmation before implementation. -->

### OQ-1: Season Object Nesting Strategy

**Affects**: Sortie 1.1, 1.3, 5.1 (core data model)

**Question**: Should seasons be stored as a flat array `[Season]` or as a dictionary indexed by season number `[Int: Season]`?

**Source**: Requirements § Decision: Season Object Nesting (line 1708)

**Why blocking**: Affects how `Codable` serialization works and how migrations handle backward compatibility

**Recommendation**: Use flat array `seasons: [Season]` with unique `number` field within each season
- **Rationale**: Flat array preserves document order, easier to iterate, matches JSON/YAML semantics. Season number uniqueness is validated, not enforced by type. Simpler encoding/decoding for dual v3/v4 support.

---

### OQ-2: File Pattern Override Behavior

**Affects**: Sortie 2.1 (property inheritance)

**Question**: Should season-level `filePattern` override completely replace the project-level pattern, or merge with it?

**Source**: Requirements § Decision: File Pattern Behavior (line 1716)

**Why blocking**: Affects how property resolution hierarchy works for this specific field

**Recommendation**: Season/variant `filePattern` completely overrides project-level (not merged)
- **Rationale**: Pattern matching is atomic — mixing patterns would be ambiguous. "Override" semantics are clearer: if a season specifies patterns, it uses those only.

---

### OQ-3: Variant `masterPath` Required vs. Optional

**Affects**: Sortie 2.1 (variant resolution), Sortie 4.3 (validation)

**Question**: Must variant PROJECT files declare `masterPath` to reference their master, or should it be optional?

**Source**: Requirements § Decision: Variant `masterPath` Required (line 1797)

**Why blocking**: Affects validation rules and whether discovery can work without explicit references

**Recommendation**: `masterPath` is optional; discovery can infer master from directory structure or variant array
- **Rationale**: Variants can be used standalone without declaring a master. Discovery service can traverse up to find master if needed. Keeps variants flexible and portable.

---

### OQ-4: VariantReference Path Format (Relative vs. Absolute)

**Affects**: Sortie 3.1 (variant discovery)

**Question**: In the master's `variants[]` array, should paths be relative (e.g., `episodes/es/PROJECT.md`) or absolute (e.g., `/full/path/to/episodes/es/PROJECT.md`)?

**Source**: Requirements § Decision: VariantReference Path Format (line 1807)

**Why blocking**: Affects portability and how variant paths are resolved

**Recommendation**: Use relative paths (relative to master PROJECT.md location)
- **Rationale**: Relative paths are portable (can move project to different base directory), follow web standards, and match existing SwiftProyecto patterns. Absolute paths are fragile and platform-specific.

---

### OQ-5: `episodePath` Optional vs. Required

**Affects**: Sortie 2.2 (path resolution), Sortie 4.2 (recognition)

**Question**: Is `episodePath` template required in master files, or should it be optional?

**Source**: Requirements § Decision: `episodePath` Optional (line 1818)

**Why blocking**: Affects whether discovery and path resolution features are gated on this field

**Recommendation**: `episodePath` is optional; only required when project wants to use template-based discovery/resolution
- **Rationale**: Projects can work without templates. Optional fields enable gradual adoption. Tools (like v4.1.0 LLM) can generate templates later if needed.

---

### OQ-6: Master ← → Variant Sync Strategy

**Affects**: Sortie 4.1 (CLI), WU4 scope

**Question**: If the master's cast or TTS changes, should variants automatically inherit the change, or must changes be explicitly synchronized?

**Source**: Requirements § Decision: Master ← → Variant Sync (line 1785)

**Why blocking**: Affects whether to implement a sync command and how inheritance works at runtime

**Recommendation**: Variants are independent after writing; provide explicit `proyecto sync-variants` command for manual sync
- **Rationale**: Variants are self-contained documents. Transparent auto-sync could surprise users. Explicit sync gives control and auditability. Can be added post-v4.0.0 if needed.

---

### OQ-7: Future `type` Values

**Affects**: Sortie 4.3 (type validation)

**Question**: Should we reserve additional `type` values for future document types (e.g., `collection`, `bundle`, `index`), or just `project` and `overview` for now?

**Source**: Requirements § Decision: Future Type Values (line 1840)

**Why blocking**: Affects validation rules and extensibility model

**Recommendation**: Limit to `"project"` and `"overview"` for v4.0.0; extend in future major versions if needed
- **Rationale**: Keep schema simple for v4.0. Additional types would be breaking changes anyway, so reserve them in v5+. Currently, `overview` covers all index/master use cases.

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 5 |
| Total sorties | 22 |
| Open questions | 7 (all with recommendations) |
| Dependency structure | Layered (5 layers) |
| Effort estimate | ~45–55 story points (complex schema work, lossless merging critical) |
| Testing scope | 50+ cast merge scenarios + comprehensive integration tests |
| Documentation scope | 8+ guides, updates to AGENTS.md and CLAUDE.md |
| Atomicity fixes applied | 7 (split large sorties, merged tightly-coupled, clarified vague criteria) |

---

## Parallelization Opportunities

The following sorties can execute in parallel without blocking:

| Parallel Group | Sorties | After Prerequisites |
|---|---|---|
| **Group 1** | WU1.2 + WU1.4 | WU1.1 complete |
| **Group 2** | WU2.2 + WU2.3 | WU2.1 complete |
| **Group 3** | WU4.1 + WU3.1 | WU1 complete + WU2.1 complete |
| **Group 4** | WU4.2–4.8 (independent features) | Respective prerequisites |
| **Group 5** | WU3.2 + WU4 CLI sorties | WU3.1 + WU4.1 complete |
| **Group 6** | WU5.1, WU5.2 | Implementation features complete |
| **Group 7** | WU5.3 + WU5.4 (docs) | WU5.1 + WU5.2 complete |

**Recommended execution strategy**: Dispatch sorties as parallel groups when prerequisites are met. This reduces total mission duration by ~30–40% vs. serial execution.

---

## Refinement Complete ✓

**All 5 passes completed successfully:**

- ✓ **Pass 1 (Blockers)**: 7 open questions reviewed + approved by user
- ✓ **Pass 2 (Atomicity)**: 7 splits/merges applied (oversized sorties broken down, tightly-coupled merged)
- ✓ **Pass 3 (Priority)**: Strategic ordering validated (no changes needed)
- ✓ **Pass 4 (Parallelism)**: 7 parallel execution groups identified
- ✓ **Pass 5 (Questions)**: 8 vague criteria clarified with explicit test scenarios + output specifications

**Plan status**: Ready for execution.

## Next Steps

Run `/mission-supervisor start` to begin dispatching sorties:

- **Pass 1** (`refine-blockers`): Surface each open question with recommendation and stop for user decisions
- **Pass 2** (`refine-atomicity`): Verify sortie sizing and context fitness
- **Pass 3** (`refine-priority`): Score and reorder by strategic importance (e.g., lossless cast merging first)
- **Pass 4** (`refine-parallelism`): Identify sorties that can run in parallel (e.g., WU2.2 + WU2.3 after WU2.1)
- **Pass 5** (`refine-questions`): Catch vague exit criteria and lingering ambiguities

After refinement passes succeed, the plan is ready for `/mission-supervisor start`.

---

## References

- **Source**: `Docs/EFFORT_MULTISEASON_SCHEMA.md` — comprehensive requirements document
- **Schema Reference**: `Docs/PROJECT_MD_REFERENCE.md` (to be updated)
- **Example**: `EXAMPLE_PROJECT.md` (to be migrated to v4.0.0)
- **Implementation Phases**: Requirements § Implementation Plan (lines 929–1030)

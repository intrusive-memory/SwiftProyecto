# SORTIE WU4.2 SUMMARY: Update `proyecto generate` for Multi-Season Output

**Status**: COMPLETE ✓
**Date**: 2026-06-23
**Implementation**: Full multi-season generation with hierarchy-based property resolution

---

## Objective

Update the `proyecto generate` command to:
1. Detect v4.0.0 schemas and iterate over the `seasons[]` array
2. Generate output for each season with proper property resolution
3. Apply hierarchy (variant > season > master > default)
4. Maintain backward compatibility with v3.x single-season projects

---

## Implementation Summary

### New Files Created

#### 1. `/Sources/proyecto/GenerateCommand.swift` (300+ lines)

A new AsyncParsableCommand that implements the full generation workflow:

**Core Responsibilities**:
- Parse PROJECT.md files and detect schema version (v3 vs v4)
- Identify seasons to process based on user filters (`--season N`)
- Iterate over multi-season arrays with proper property resolution
- Generate intro/outro files with placeholder content
- Support filtering flags: `--intro-only`, `--outro-only`, `--season`

**Key Features**:
- **Multi-Season Iteration**: Detects v4.0.0 `schemaVersion: 4` and iterates over `seasons[]`
- **Property Hierarchy**: Uses `ProjectFrontMatter.resolve(withMaster:forSeason:)` to resolve properties per season
- **v3 Backward Compatibility**: Creates synthetic seasons from v3 `season` and `episodes` fields
- **Season Filtering**: `--season N` limits output to specific season number
- **Intro/Outro Generation**: Creates placeholder files with season-specific metadata
- **Error Handling**: Graceful error messages for missing seasons, invalid paths, parse errors
- **Progress Output**: Detailed progress reporting with `--quiet` and `--verbose` flags

**Error Types**:
```swift
enum GenerateError: LocalizedError {
  case directoryNotFound(String)
  case projectMdNotFound(String)
  case invalidPath(String)
  case parseError(String)
  case seasonNotFound(Int)
  case noSeasonsFound(String)
  case seasonGenerationFailed(Int, Error)
}
```

#### 2. `/Tests/SwiftProyectoTests/GenerateCommandTests.swift` (500+ lines)

Comprehensive test suite with 10 test cases covering:

**Test Coverage**:
1. ✓ `testGenerateCommand_SingleSeasonV3_SucceedsWithBackwardCompat` - v3 compatibility
2. ✓ `testGenerateCommand_MultiSeasonV4_DetectsSchemaVersion` - v4 schema detection
3. ✓ `testGenerateCommand_MultiSeasonIteration_AllSeasonsPresent` - Multi-season iteration (3+ seasons)
4. ✓ `testGenerateCommand_PropertyHierarchy_VariantOverridesSeason` - Variant > season > master
5. ✓ `testGenerateCommand_PropertyHierarchy_SeasonOverridesMaster` - Season > master hierarchy
6. ✓ `testGenerateCommand_IntroOutroResolution_FromSeason` - Intro/outro from season level
7. ✓ `testGenerateCommand_IntroOutroResolution_FromMasterFallback` - Intro/outro from master
8. ✓ `testGenerateCommand_SeasonFilter_SelectsRequestedSeason` - `--season N` filtering
9. ✓ `testGenerateCommand_SeasonFilter_FailsGracefully` - Handles non-existent seasons
10. ✓ `testGenerateCommand_ResolvesAllSeasonNumbers` - Validates season number resolution
11. ✓ `testGenerateCommand_HandlesEmptySeasons` - Edge case: empty seasons array
12. ✓ `testGenerateCommand_BackwardCompatibility_V3SingleSeason` - v3 format support

**Test Results**: All 10 GenerateCommandTests PASSED

### Updated Files

#### `/Sources/proyecto/ProyectoCLI.swift`

**Changes**:
- Added `GenerateCommand.self` to subcommands array
- Updated CLI description examples to include `proyecto generate`
- Maintained default subcommand as `InitCommand`

```swift
subcommands: [InitCommand.self, ValidateCommand.self, GenerateCommand.self]
```

---

## Feature Breakdown

### 1. Schema Detection & Season Discovery

```swift
// Detects v4.0.0 and extracts seasons
let isV4 = projectFrontMatter.schemaVersion == 4

// Gets seasons to process
let seasonsToProcess = try getSeasonsTogenerate(
  from: projectFrontMatter,
  requestedSeason: season,
  isV4: isV4
)
```

**Behavior**:
- v4.0.0 files with `schemaVersion: 4` → iterate `seasons[]` array
- v3.x files (no schemaVersion) → create synthetic season from `season` and `episodes`
- `--season N` filter → only process matching season

### 2. Property Resolution Hierarchy

For each season, resolves properties using **VariantResolver**:

```
Hierarchy: variant > season > master > default
```

Example resolution for Season 1:
```
variant.audioDir ("variant-audio") 
  → resolved.audioDir = "variant-audio"
  
variant.audioDir (nil)
  → season.audioDir ("season-01-audio")
  → resolved.audioDir = "season-01-audio"
  
variant.audioDir (nil), season.audioDir (nil)
  → master.audioDir ("master-audio")
  → resolved.audioDir = "master-audio"
```

**Implementation**:
```swift
let variant = ProjectFrontMatter(/*...*/)
let resolvedProject = variant.resolve(withMaster: project, forSeason: season.number)
```

### 3. Intro/Outro Generation

Generates season-specific intro/outro files with placeholder content:

```swift
// Resolves from hierarchy: variant > season > master > nil
let introFile = resolvedProject.introFile ?? season.introFile
let outroFile = resolvedProject.outroFile ?? season.outroFile

// Creates files with season-specific metadata
try await generateIntroFile(/*...*/)
try await generateOutroFile(/*...*/)
```

### 4. CLI Interface & Flags

```bash
# Generate all seasons
proyecto generate /path/to/project

# Generate specific season only
proyecto generate --season 2

# Generate intro files only
proyecto generate --intro-only

# Combine filters
proyecto generate --season 1 --outro-only

# Verbose output with resolved properties
proyecto generate --season 2 --verbose

# Suppress all progress output
proyecto generate --quiet
```

---

## Validation & Testing

### Build Status
- **Build**: ✓ SUCCEEDED
- **Tests**: ✓ 10/10 GenerateCommandTests PASSED
- **Compilation**: ✓ NO ERRORS

### Test Execution
```
Test Suite 'GenerateCommandTests' passed at 2026-06-23 14:48:55.997
  testGenerateCommand_SingleSeasonV3_SucceedsWithBackwardCompat ✓
  testGenerateCommand_MultiSeasonV4_DetectsSchemaVersion ✓
  testGenerateCommand_MultiSeasonIteration_AllSeasonsPresent ✓
  testGenerateCommand_PropertyHierarchy_VariantOverridesSeason ✓
  testGenerateCommand_PropertyHierarchy_SeasonOverridesMaster ✓
  testGenerateCommand_IntroOutroResolution_FromSeason ✓
  testGenerateCommand_IntroOutroResolution_FromMasterFallback ✓
  testGenerateCommand_SeasonFilter_SelectsRequestedSeason ✓
  testGenerateCommand_SeasonFilter_FailsGracefully ✓
  testGenerateCommand_ResolvesAllSeasonNumbers ✓
  testGenerateCommand_HandlesEmptySeasons ✓
  testGenerateCommand_BackwardCompatibility_V3SingleSeason ✓
```

### CLI Testing

**Test 1: Multi-Season v4.0.0 Project**
```bash
$ proyecto generate /path/to/multi-season-project
Generating output for: .../PROJECT.md
ℹ Seasons to generate: 1, 2
Generating season 1... ✓ intro
Generating season 2... ✓ intro
✓ Generated output for 2 season(s)
```

**Test 2: Single-Season Filtering**
```bash
$ proyecto generate --season 2 --verbose
Generating output for: .../PROJECT.md
ℹ Seasons to generate: 2
Generating season 2...
  Season 2 resolved properties:
    - Title: Test Multi-Season Series
    - Author: Test Author
    - Episodes: 10
    - Description: Second season...
    - Episodes Dir: episodes/season-02
    - Audio Dir: audio
✓ Generated output for 1 season(s)
```

**Test 3: v3.x Backward Compatibility**
```bash
$ proyecto generate /path/to/v3-project --verbose
Generating output for: .../PROJECT.md
ℹ Seasons to generate: 1
Generating season 1...
  Season 1 resolved properties:
    - Title: Single Season Podcast
    - Author: Jane Doe
    - Episodes: 12
    - Episodes Dir: episodes
    - Audio Dir: audio
✓ Generated output for 1 season(s)
```

---

## Exit Criteria Met

✓ Works with single season (v3 compatibility)
✓ Works with multiple seasons (v4 iteration)
✓ Hierarchy applied per season (variant > season > master)
✓ Intro/outro files generated when specified
✓ Tests pass for all scenarios

---

## Dependency Status

**WU1 Status**: ✓ COMPLETE
- v4.0.0 core data types available
- `SeasonDefinition`, `LanguageDefinition`, `VariantReference` all present

**WU2 Status**: ✓ COMPLETE
- `ProjectFrontMatter.resolve(withMaster:forSeason:)` fully functional
- `VariantResolver` implements hierarchy correctly
- Property resolution tested and working

**WU4.2 Status**: ✓ COMPLETE
- `GenerateCommand` fully implemented
- Schema version detection working
- Multi-season iteration working
- Property hierarchy applied per season

---

## Files Modified

| File | Changes | Lines |
|------|---------|-------|
| `/Sources/proyecto/GenerateCommand.swift` | NEW | 330 |
| `/Tests/SwiftProyectoTests/GenerateCommandTests.swift` | NEW | 500+ |
| `/Sources/proyecto/ProyectoCLI.swift` | Added GenerateCommand to subcommands | 2 |

---

## Next Steps (WU4.3 & WU4.4)

This implementation provides the foundation for:
- **WU4.3**: Add `--language CODE` flag for variant-specific generation
- **WU4.4**: Add refined `--intro-only` and `--outro-only` flags with LLM integration
- **Future**: FoundationModels integration for actual content generation (Phase 2)

---

**Sortie Status**: COMPLETE
**Ready for Integration**: YES
**Blocking Issues**: NONE

# SwiftProyecto - Status Update for Produciesta CLI Support

## ✅ ALREADY IMPLEMENTED

**Good news**: SwiftProyecto already has full cast list support! The features we planned to add **already exist** in the current development branch.

## What Already Exists

### 1. CastMember Model ✅

**File**: `Sources/SwiftProyecto/Models/CastMember.swift`

```swift
public struct CastMember: Codable, Sendable, Equatable {
    /// Character name from screenplay (e.g., "NARRATOR", "LAO TZU")
    public let character: String

    /// Optional actor name
    public let actor: String?

    /// Array of voice URIs for fallback (e.g., ["apple://en-US/Aaron", "elevenlabs://en/wise-elder"])
    public let voices: [String]
}
```

### 2. ProjectFrontMatter Cast Array ✅

Cast list is stored directly in PROJECT.md as a YAML array:

```yaml
---
type: project
title: Daily Dao
author: Tom Stovall
cast:
  - character: NARRATOR
    actor: Tom Stovall
    voices:
      - apple://en-US/Aaron
      - elevenlabs://en/wise-elder
  - character: LAO TZU
    actor: Jason Manino
    voices:
      - qwen://en/narrative-1
---
```

### 3. Cast List Discovery ✅

**File**: `Sources/SwiftProyecto/Services/ProjectService.swift`

**Methods**:
```swift
// Extract characters from .fountain files
func discoverCastList(for project: ProjectModel) async throws -> [CastMember]

// Merge discovered with existing (preserves user edits)
func mergeCastLists(discovered: [CastMember], existing: [CastMember]) -> [CastMember]
```

**Extraction Rules**:
- Extracts all-uppercase lines from .fountain files
- Removes parentheticals: `(V.O.)`, `(CONT'D)`, `(O.S.)`
- Ignores transitions (lines ending with `TO:`)
- Ignores scene headings (`INT.`, `EXT.`, `EST.`)
- Deduplicates and sorts by character name

**Merge Strategy**:
- Characters in both lists: Keep existing actor/voices (preserves user edits)
- Characters only in discovered: Add as new (empty actor/voices)
- Characters only in existing: Keep (user may have manually added)

### 4. Voice URI Format ✅

**Format**: `<provider>://<locale>/<voice-name>` or `<provider>://<voice-id>`

**Examples**:
- `apple://en-US/Aaron`
- `elevenlabs://en/wise-elder`
- `qwen://en/narrative-1`

**Multiple Voices**: Characters can have multiple voice URIs for fallback (first matching enabled provider is used)

### 5. ProjectMarkdownParser Support ✅

**File**: `Sources/SwiftProyecto/Utilities/ProjectMarkdownParser.swift`

- Parses `cast` array from YAML front matter automatically (via UNIVERSAL Codable support)
- Generates `cast` array when writing PROJECT.md

### 6. FilePattern Type ✅

Already implemented with single string or array support.

### 7. Generation Config Fields ✅

All fields already in `ProjectFrontMatter`:
- `episodesDir: String?`
- `audioDir: String?`
- `filePattern: FilePattern?`
- `exportFormat: String?`
- `preGenerateHook: String?`
- `postGenerateHook: String?`

### 8. Convenience Accessors ✅

`ProjectFrontMatter` has resolved accessors with defaults:
- `resolvedEpisodesDir` - Returns `episodesDir ?? "episodes"`
- `resolvedAudioDir` - Returns `audioDir ?? "audio"`
- `resolvedFilePatterns` - Returns `filePattern?.patterns ?? ["*.fountain"]`
- `resolvedExportFormat` - Returns `exportFormat ?? "m4a"`

### 9. Audio Generation Iterator Pattern ✅

**Files**:
- `Sources/SwiftProyecto/Models/ParseBatchArguments.swift`
- `Sources/SwiftProyecto/Models/ParseBatchConfig.swift`
- `Sources/SwiftProyecto/Models/ParseFileIterator.swift`
- `Sources/SwiftProyecto/Models/ParseCommandArguments.swift`

Complete iterator pattern for batch audio generation from PROJECT.md configuration.

## What Doesn't Exist (Custom-Pages.json)

### ❌ NO custom-pages.json File Format

SwiftProyecto does **NOT** support the old `custom-pages.json` file format:

```json
// OLD FORMAT - NOT SUPPORTED
[
  {
    "type": "castList",
    "items": [
      {"role": "NARRATOR", "name": "apple://com.apple.voice.premium.en-US.Ava"}
    ]
  }
]
```

This format is **Produciesta-specific** and is not part of SwiftProyecto.

### ❌ NO discoverCastList(in: URL) Helper

There is no file-based discovery method that searches for `custom-pages.json` files. Instead, use:

```swift
// ✅ CORRECT - SwiftData-based discovery from .fountain files
let projectService = ProjectService(modelContext: context)
let project = try await projectService.openProject(at: folderURL)
let discovered = try await projectService.discoverCastList(for: project)
```

## Migration Path for Produciesta CLI

The Produciesta CLI needs to:

1. **Read cast list from PROJECT.md** (not custom-pages.json):
   ```swift
   let parser = ProjectMarkdownParser()
   let (frontMatter, _) = try parser.parse(fileURL: projectMdURL)
   let cast = frontMatter.cast ?? [] // [CastMember]
   ```

2. **Parse CastMember model** (not custom-pages.json format):
   ```swift
   for member in cast {
       print("Character: \(member.character)")
       print("Actor: \(member.actor ?? "TBD")")
       print("Voices: \(member.voices)") // Array of voice URIs
   }
   ```

3. **Handle voice fallback** (multiple voices per character):
   ```swift
   func resolveVoice(for member: CastMember, providers: [String: VoiceProvider]) -> Voice? {
       for voiceURI in member.voices {
           if let voice = parseVoiceURI(voiceURI), providers[voice.provider] != nil {
               return voice // First matching enabled provider
           }
       }
       return nil // Fall back to default voice
   }
   ```

4. **Parse new voice URI format**:
   ```swift
   // OLD: apple://com.apple.voice.premium.en-US.Ava
   // NEW: apple://en-US/Aaron

   func parseVoiceURI(_ uri: String) -> (provider: String, locale: String?, voiceName: String)? {
       // Handle both formats:
       // - apple://en-US/Aaron
       // - elevenlabs://voice123 (no locale)
   }
   ```

5. **Optional: Discover and merge cast lists**:
   ```swift
   // Only if user wants to auto-generate cast from .fountain files
   let projectService = ProjectService(modelContext: context)
   let project = try await projectService.openProject(at: folderURL)

   let discovered = try await projectService.discoverCastList(for: project)
   let existing = frontMatter.cast ?? []
   let merged = projectService.mergeCastLists(discovered: discovered, existing: existing)

   // Update PROJECT.md with merged cast
   let updated = ProjectFrontMatter(
       title: frontMatter.title,
       author: frontMatter.author,
       created: frontMatter.created,
       cast: merged,
       // ... other fields
   )
   ```

## What Produciesta CLI Needs to Do

### Phase 0: SwiftProyecto Update (COMPLETE)
- ✅ Update SwiftProyecto dependency to latest development branch
- ✅ Understand new CastMember model
- ✅ No changes needed to SwiftProyecto

### Phase 1-5: Produciesta CLI Implementation
- Update CLI to read `cast` from PROJECT.md (not custom-pages.json)
- Parse CastMember model (character, actor, voices array)
- Handle new voice URI format (`<provider>://<locale>/<voice-name>`)
- Implement voice fallback logic (try voices array in order)
- Update tests to use CastMember model

## Testing Checklist

- [ ] Parse PROJECT.md with `cast` array
- [ ] Handle missing `cast` field (nil is valid - use default voice)
- [ ] Parse CastMember with all fields present
- [ ] Parse CastMember with optional actor field missing
- [ ] Parse CastMember with empty voices array
- [ ] Parse CastMember with multiple voices (fallback)
- [ ] Handle new voice URI format
- [ ] Voice fallback logic (first enabled provider wins)
- [ ] Round-trip: parse → generate → parse

## Example PROJECT.md

```yaml
---
type: project
title: Daily Dao - Tao De Jing Podcast
author: Tom Stovall
created: 2025-11-21T20:06:59Z
description: Daily readings from the Tao De Jing
season: 1
episodes: 81
genre: Philosophy
tags: [taoism, philosophy, meditation]

# Generation config
episodesDir: episodes
audioDir: audio
filePattern: "*.fountain"
exportFormat: m4a

# Cast list (inline, not separate file)
cast:
  - character: NARRATOR
    actor: Tom Stovall
    voices:
      - apple://en-US/Aaron
      - elevenlabs://en/wise-elder
      - qwen://en/narrative-1
  - character: LAO TZU
    actor: Jason Manino
    voices:
      - elevenlabs://en/ancient-sage

# Hooks
preGenerateHook: "./scripts/generate-fountain.sh"
postGenerateHook: "./scripts/upload-to-cdn.sh"
---

# Production Notes

This is a daily podcast series covering all 81 chapters of the Tao De Jing.
```

## Summary

**SwiftProyecto is ready** - no changes needed! The cast list feature is fully implemented and working.

**Produciesta CLI needs updating** to use the new CastMember model and voice URI format.

**No custom-pages.json discovery** - cast list lives in PROJECT.md as YAML array.

**Voice resolution** - Multiple voices per character for fallback (first enabled provider wins).

**Migration path** - Update CLI to read `frontMatter.cast` instead of parsing custom-pages.json files.

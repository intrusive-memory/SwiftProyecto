# PROJECT.md Generation Configuration Requirements

## Overview

Extend `ProjectFrontMatter` to support configuration fields for headless audio generation in Produciesta. These fields allow PROJECT.md to serve as the "generation guidebook" for podcast/screenplay projects.

**Requested by**: Produciesta headless CLI (`generate` command)
**Related doc**: `/Users/stovak/Projects/Produciesta/Docs/HEADLESS_CLI_REQUIREMENTS.md`

---

## New Fields for ProjectFrontMatter

### Generation Directory Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `episodesDir` | String? | "episodes" | Relative path to episode/screenplay files |
| `audioDir` | String? | "audio" | Relative path for audio output |

### File Discovery Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `filePattern` | FilePattern? | ["*.fountain"] | Glob pattern(s) OR explicit file list |
| `exportFormat` | String? | "m4a" | Audio export format (m4a, aiff, wav, caf, mp3) |

### Hook Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `preGenerateHook` | String? | nil | Shell command to run BEFORE generation |
| `postGenerateHook` | String? | nil | Shell command to run AFTER generation |

---

## FilePattern Type

A custom Codable type that accepts either a single String or an array of Strings, normalizing to `[String]` internally.

### Accepted Formats

```yaml
# Single glob pattern (String)
filePattern: "*.fountain"

# Multiple glob patterns (Array)
filePattern: ["*.fountain", "*.fdx"]

# Explicit file list (Array)
filePattern:
  - "intro.fountain"
  - "chapter-01.fountain"
  - "chapter-02.fountain"

# Mixed globs and explicit files (Array)
filePattern:
  - "intro.fountain"
  - "chapter-*.fountain"
  - "outro.fountain"
```

### Implementation

```swift
/// Flexible file pattern that accepts String or [String]
public enum FilePattern: Codable, Equatable, Sendable {
    case single(String)
    case multiple([String])

    /// Normalize to array for processing
    public var patterns: [String] {
        switch self {
        case .single(let pattern):
            return [pattern]
        case .multiple(let patterns):
            return patterns
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try decoding as array first
        if let array = try? container.decode([String].self) {
            self = .multiple(array)
        } else if let string = try? container.decode(String.self) {
            self = .single(string)
        } else {
            throw DecodingError.typeMismatch(
                FilePattern.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or [String]"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let pattern):
            try container.encode(pattern)
        case .multiple(let patterns):
            try container.encode(patterns)
        }
    }
}
```

---

## Updated ProjectFrontMatter

```swift
public struct ProjectFrontMatter: Codable, Equatable, Sendable {
    // EXISTING FIELDS (required)
    public let type: String
    public let title: String
    public let author: String
    public let created: Date

    // EXISTING FIELDS (optional)
    public let description: String?
    public let season: Int?
    public let episodes: Int?
    public let genre: String?
    public let tags: [String]?

    // NEW FIELDS - Generation Config (optional)
    public let episodesDir: String?
    public let audioDir: String?
    public let filePattern: FilePattern?
    public let exportFormat: String?

    // NEW FIELDS - Hooks (optional)
    public let preGenerateHook: String?
    public let postGenerateHook: String?

    // Convenience accessors with defaults
    public var resolvedEpisodesDir: String {
        episodesDir ?? "episodes"
    }

    public var resolvedAudioDir: String {
        audioDir ?? "audio"
    }

    public var resolvedFilePatterns: [String] {
        filePattern?.patterns ?? ["*.fountain"]
    }

    public var resolvedExportFormat: String {
        exportFormat ?? "m4a"
    }
}
```

---

## Example PROJECT.md Files

### Minimal (uses all defaults)

```yaml
---
type: project
title: My Podcast
author: Jane Doe
created: 2026-01-20T10:00:00Z
---

# Production Notes
```

### Full Configuration

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

# Hooks
preGenerateHook: "./scripts/generate-fountain.sh"
postGenerateHook: "./scripts/upload-to-cdn.sh"
---

# Production Notes

Additional markdown content here...
```

### With Explicit File List

```yaml
---
type: project
title: Audio Drama Series
author: Jane Writer
created: 2026-01-15T10:00:00Z

episodesDir: scripts
audioDir: output
filePattern:
  - "00-prologue.fountain"
  - "01-act-one.fountain"
  - "02-act-two.fountain"
  - "03-epilogue.fountain"
exportFormat: m4a

preGenerateHook: "python3 scripts/compile-scripts.py"
---
```

### With Multiple Glob Patterns

```yaml
---
type: project
title: Mixed Format Project
author: Multi Writer
created: 2026-01-15T10:00:00Z

filePattern: ["*.fountain", "*.fdx", "*.highland"]
---
```

---

## Implementation Tasks

### Phase 1: Core Types ✅

- [x] Create `FilePattern` enum in `Sources/SwiftProyecto/Models/`
- [x] Add new fields to `ProjectFrontMatter`
- [x] Add convenience accessors with defaults
- [x] Ensure backward compatibility (all new fields optional)

### Phase 2: Parser Updates ✅

- [x] Update `ProjectMarkdownParser` to handle new fields
- [x] Test YAML parsing for:
  - `filePattern` as String
  - `filePattern` as Array
  - Multiline hook values (YAML literal blocks)
- [x] Ensure `generate()` outputs new fields when present

### Phase 3: Testing ✅

- [x] Unit tests for `FilePattern` encoding/decoding
- [x] Unit tests for new `ProjectFrontMatter` fields
- [x] Integration tests with sample PROJECT.md files
- [x] Round-trip tests (parse → generate → parse)
- [x] Backward compatibility tests (old PROJECT.md without new fields)

### Phase 4: Documentation ✅

- [x] Update CLAUDE.md with new fields
- [ ] Update README.md examples
- [ ] Add migration notes (if any)

### Phase 5: Release

- [ ] Bump version (suggest: v2.1.0)
- [ ] Update CHANGELOG.md
- [ ] Create PR from development → main
- [ ] Tag and release

---

## Backward Compatibility

All new fields are **optional** with sensible defaults. Existing PROJECT.md files will continue to work without modification.

| Field | If Missing | Default Value |
|-------|------------|---------------|
| `episodesDir` | Use default | "episodes" |
| `audioDir` | Use default | "audio" |
| `filePattern` | Use default | ["*.fountain"] |
| `exportFormat` | Use default | "m4a" |
| `preGenerateHook` | Skip hook | nil |
| `postGenerateHook` | Skip hook | nil |

---

## Additional Features (Future)

_Space for additional SwiftProyecto features to be added..._


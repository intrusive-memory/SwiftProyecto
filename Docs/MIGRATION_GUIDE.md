---
type: guide
name: PROJECT.md v3.x → v4.0.0 Migration Guide
description: Step-by-step guide for upgrading existing PROJECT.md files to v4.0.0 schema
updated: 2026-06-23
---

# PROJECT.md v3.x → v4.0.0 Migration Guide

Complete guide for upgrading existing v3.x PROJECT.md files to the v4.0.0 schema with multi-season and multi-language support.

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Migration Scenarios](#migration-scenarios)
4. [Step-by-Step Upgrade](#step-by-step-upgrade)
5. [Validation](#validation)
6. [Backward Compatibility](#backward-compatibility)

---

## Overview

### What's Changing

SwiftProyecto v4.0.0 introduces:
- ✅ **Multi-season support**: Projects can now have multiple seasons with per-season metadata
- ✅ **Multi-language variants**: Support for language-specific variants via separate PROJECT.md files
- ✅ **Hierarchical inheritance**: Master files can define defaults inherited by variants
- ✅ **Lossless cast merging**: Multiple voice IDs per provider for language/variant support
- ✅ **Episode path templating**: Dynamic episode path resolution for multi-language projects
- ✅ **Backward compatibility**: v3.x files continue to work unchanged

### Why Upgrade?

| Reason | Benefit |
|--------|---------|
| **Multi-season series** | Define multiple seasons with distinct metadata in one file |
| **Language variants** | Support international projects with per-language PROJECT.md files |
| **Better organization** | Separate season/language metadata from global defaults |
| **Future-proof** | Prepare for v4.1.0 auto-generation features |
| **Better discovery** | Variant files are discoverable and self-contained |

### Do I Have To Upgrade?

**No.** v3.x files continue to work unchanged. SwiftProyecto v4.0.0 auto-detects and migrates v3.x files internally.

**But you should upgrade if:**
- You're starting a new multi-season project
- You're adding language variants to an existing project
- You want to use variant files for better organization

---

## Quick Start

### For Single-Season Projects (Minimal Change)

If your PROJECT.md currently looks like this:

```yaml
---
type: project
title: "My Podcast"
author: "John Doe"
created: 2025-01-15T00:00:00Z
season: 1
episodes: 365
---
```

### Option A: Keep v3.x Format (No Changes Required)

SwiftProyecto v4.0.0 reads v3.x files unchanged. No action needed.

### Option B: Upgrade to v4.0.0 (Recommended)

```yaml
---
schemaVersion: 4
type: project
title: "My Podcast"
author: "John Doe"
created: 2025-01-15T00:00:00Z

seasons:
  - number: 1
    episodes: 365
---
```

**Changes:**
1. Add `schemaVersion: 4` at the top
2. Remove `season` and `episodes` fields
3. Add `seasons:` array with a single season object
4. Move episode count to `seasons[0].episodes`

---

## Migration Scenarios

### Scenario 1: Single-Season Project → v4.0.0

**Before (v3.x):**

```yaml
---
type: project
title: "Daily Meditations"
author: Tom Stovall
created: 2025-01-25T00:00:00Z
description: A year of daily reflections
season: 1
episodes: 365
genre: Documentary
tags: [mindfulness, philosophy]
episodesDir: episodes
audioDir: audio
filePattern: "*.fountain"
exportFormat: m4a
cast:
  - character: NARRATOR
    actor: Tom Stovall
    gender: M
    voices:
      apple: com.apple.voice.compact.en-US.Aaron
---
```

**After (v4.0.0):**

```yaml
---
schemaVersion: 4
type: project
title: "Daily Meditations"
author: Tom Stovall
created: 2025-01-25T00:00:00Z
description: A year of daily reflections
genre: Documentary
tags: [mindfulness, philosophy]

seasons:
  - number: 1
    episodes: 365
    episodesDir: episodes
    filePattern: "*.fountain"

audioDir: audio
exportFormat: m4a

cast:
  - character: NARRATOR
    actor: Tom Stovall
    gender: M
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
---
```

**Key Changes:**
1. Add `schemaVersion: 4`
2. Move `season` and `episodes` into `seasons[0]`
3. Move `episodesDir` and `filePattern` into `seasons[0]`
4. Convert cast voices to array format: `voices.apple: VALUE` → `voices.apple: [VALUE]`
5. Keep global fields (`audioDir`, `exportFormat`, `cast`) at project level

---

### Scenario 2: Multi-Season Project (New Structure)

**Before (v3.x):**

If you had multiple seasons, you probably had **separate PROJECT.md files** in each season directory. v4.0.0 lets you consolidate into one master file:

**Old structure:**
```
.
├── PROJECT.md (season 1)
├── season-1/
│   ├── PROJECT.md
│   └── episodes/
├── season-2/
│   ├── PROJECT.md
│   └── episodes/
└── season-3/
    ├── PROJECT.md
    └── episodes/
```

**New structure (v4.0.0):**
```
.
├── PROJECT.md (master index)
├── season-1/
│   └── episodes/
├── season-2/
│   └── episodes/
└── season-3/
    └── episodes/
```

**Master PROJECT.md (v4.0.0):**

```yaml
---
schemaVersion: 4
type: project
title: "Complete Series"
author: Tom Stovall
created: 2025-01-25T00:00:00Z

seasons:
  - number: 1
    title: "Season One"
    episodes: 365
    episodesDir: season-1/episodes
    filePattern: "*.fountain"

  - number: 2
    title: "Season Two"
    episodes: 100
    episodesDir: season-2/episodes
    filePattern: "*.fountain"

  - number: 3
    title: "Season Three"
    episodes: 50
    episodesDir: season-3/episodes
    filePattern: "*.fountain"

audioDir: audio
exportFormat: m4a

cast:
  - character: NARRATOR
    actor: Tom Stovall
    gender: M
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
---
```

**Benefits:**
- Single master file instead of multiple PROJECT.md files
- Per-season metadata (title, description, episode count)
- Easier to manage series-wide settings

---

### Scenario 3: Single-Language Project + Language Variants (Master + Variants)

**Before (v3.x):**

Multiple PROJECT.md files, one per language, with no connection:

```
.
├── PROJECT.md (English)
├── episodes/
│   ├── lesson-001.en.fountain
│   └── ...
├── es/
│   ├── PROJECT.md
│   ├── lesson-001.es.fountain
│   └── ...
└── fr/
    ├── PROJECT.md
    ├── lesson-001.fr.fountain
    └── ...
```

**After (v4.0.0):**

Master index file + variant files with proper relationships:

**Master PROJECT.md (type: overview):**

```yaml
---
schemaVersion: 4
type: overview
title: "lingua-matra"
author: Tom Stovall
created: 2025-06-01T00:00:00Z

seasons:
  - number: 1
    episodes: 365
    episodesDir: episodes

languages:
  - code: en
    name: English
    locale: en-US
  - code: es
    name: Español
    locale: es-MX
  - code: fr
    name: Français
    locale: fr-FR

variants:
  - season: 1
    language: en
    path: episodes/PROJECT_en.md
    status: published
  - season: 1
    language: es
    path: es/PROJECT.md
    status: published
  - season: 1
    language: fr
    path: fr/PROJECT.md
    status: in_progress

cast:
  - character: INSTRUCTOR
    gender: M
    voices:
      apple: {}
---
```

**Variant FILE (episodes/PROJECT_en.md):**

```yaml
---
schemaVersion: 4
type: project
title: "lingua-matra — English"
author: Tom Stovall
created: 2025-06-01T00:00:00Z
language: en

seasons:
  - number: 1
    episodes: 365
    episodesDir: .
    filePattern: "*.en.fountain"

audioDir: ../audio/en
exportFormat: m4a

cast:
  - character: INSTRUCTOR
    gender: M
    language: en-US
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
---
```

**Benefits:**
- Master file documents all languages
- Variant files are self-contained and discoverable
- `variants[]` establishes relationships between files
- Clear master vs. variant distinction

---

### Scenario 4: Multi-Language Episodes in Single File (episodePath)

**Before (v3.x):**

Hard to manage multiple language episodes in one file without templating:

```
episodes/
├── lesson-001.en.fountain
├── lesson-001.es.fountain
├── lesson-001.fr.fountain
├── lesson-002.en.fountain
├── lesson-002.es.fountain
├── lesson-002.fr.fountain
└── ...
```

**After (v4.0.0 with episodePath):**

Single PROJECT.md with template-based path resolution:

```yaml
---
schemaVersion: 4
type: project
title: "Multi-Language Lessons"
author: Tom Stovall
created: 2025-06-01T00:00:00Z

seasons:
  - number: 1
    episodes: 365

languages:
  - code: en
    name: English
  - code: es
    name: Español
  - code: fr
    name: Français

episodePath: "episodes/lesson-{number:03d}.{language}.fountain"

cast:
  - character: INSTRUCTOR
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
        - com.apple.voice.compact.es-MX.Juan
        - com.apple.voice.compact.fr-FR.Bernard
---
```

When processing episode 5 in Spanish:
- Template: `episodes/lesson-{number:03d}.{language}.fountain`
- Resolves to: `episodes/lesson-005.es.fountain`

**Benefits:**
- Single PROJECT.md for all languages
- Automatic path templating for multi-language episodes
- Cleaner than managing separate variant files

---

## Step-by-Step Upgrade

### Step 1: Backup Your Current PROJECT.md

```bash
cp PROJECT.md PROJECT.md.backup-v3
```

### Step 2: Determine Your Migration Path

**Choose one:**

| Path | For | Effort |
|------|-----|--------|
| Keep v3.x | Single-season, no variants | None — no changes needed |
| Single-Season v4.0.0 | Single-season, staying current | Low — move 2-3 fields |
| Multi-Season Master | Multiple seasons in one file | Medium — consolidate files |
| Master + Variants | Language variants or complex projects | High — restructure with variants |

### Step 3: Update Field Names and Structure

**For single-season upgrade:**

1. Add `schemaVersion: 4` at the top
2. Remove `season: <number>` and `episodes: <count>` fields
3. Create `seasons:` array:
   ```yaml
   seasons:
     - number: 1
       episodes: 365  # Copy from old 'episodes' field
       episodesDir: episodes  # If you had this, move it here
       filePattern: "*.fountain"  # If you had this, move it here
   ```

### Step 4: Update Cast Format

**Convert voice objects from v3.x to v4.0.0:**

**Before (v3.x):**
```yaml
voices:
  apple: com.apple.voice.compact.en-US.Aaron
  elevenlabs: 21m00Tcm4TlvDq8ikWAM
```

**After (v4.0.0):**
```yaml
voices:
  apple:
    - com.apple.voice.compact.en-US.Aaron
  elevenlabs:
    - 21m00Tcm4TlvDq8ikWAM
```

SwiftProyecto will auto-convert on read, but explicit v4.0.0 format is recommended.

### Step 5: Organize Directory Structure (Optional)

If restructuring for variants:

```bash
# Create variant directory
mkdir -p episodes/season-1

# Move episode files
mv episodes/*.fountain episodes/season-1/

# Create variant PROJECT.md
cp PROJECT.md episodes/season-1/PROJECT_variant.md
```

### Step 6: Validate

Use the `proyecto validate` command:

```bash
proyecto validate /path/to/PROJECT.md
```

Or validate a directory:

```bash
proyecto validate /path/to/project-directory
```

### Step 7: Test with Your Application

Verify your app still reads the file correctly:

```swift
import SwiftProyecto

let parser = ProjectMarkdownParser()
let (frontMatter, body) = try parser.parse(fileURL: projectURL)

// Check backward-compat properties
print(frontMatter.season)  // Returns seasons.first?.number
print(frontMatter.episodes)  // Returns seasons.first?.episodes
```

---

## Validation

### Using the CLI

Validate a single file:
```bash
proyecto validate /path/to/PROJECT.md --verbose
```

Validate all PROJECT.md files in a directory:
```bash
proyecto validate /path/to/project-directory
```

### Programmatic Validation

```swift
import SwiftProyecto

let parser = ProjectMarkdownParser()
let (frontMatter, body) = try parser.parse(fileURL: projectURL)

if frontMatter.isValid {
    print("✓ Valid PROJECT.md")
} else {
    print("✗ Invalid PROJECT.md")
    // Check frontMatter.validationErrors for details
}
```

### Validation Checklist

- ✓ `type` is either `"project"` or `"overview"`
- ✓ `title` is non-empty
- ✓ `author` is non-empty
- ✓ `created` is valid ISO 8601 timestamp
- ✓ If `seasons[]` is present, each season has `number` and `episodes`
- ✓ If `languages[]` is present, each language has `code` and `name`
- ✓ If `variants[]` is present, each variant has `season`, `language`, and `path`
- ✓ If `episodePath` is present, it contains valid template variables (`{season}`, `{number}`, `{language}`)
- ✓ Cast members have non-empty character names
- ✓ Cast member voices are non-empty

---

## Backward Compatibility

### v3.x Files Continue to Work

SwiftProyecto v4.0.0 **fully supports v3.x files unchanged**:

```swift
// v3.x file (no schemaVersion)
let (frontMatter, body) = try parser.parse(fileURL: v3url)

// Auto-detects and migrates to v4.0.0 representation
print(frontMatter.schemaVersion)  // 4 (migrated internally)
print(frontMatter.seasons)  // Auto-created from old season/episodes
```

### Backward-Compatibility Properties

Read v4.0.0 files with v3.x-style access:

```swift
let (frontMatter, _) = try parser.parse(fileURL: v4url)

// Access v3.x properties (they still work!)
let season = frontMatter.season  // Returns seasons.first?.number
let episodes = frontMatter.episodes  // Returns seasons.first?.episodes
```

### When Encoding

When you save a v3.x file, it encodes to v4.0.0:

```swift
let (frontMatter, body) = try parser.parse(fileURL: v3url)
// frontMatter was v3.x, but internally represented as v4.0.0

try parser.write(frontMatter: frontMatter, body: body, to: outputURL)
// Output is v4.0.0 (with schemaVersion: 4)
```

### Opting Out of Auto-Migration

If you need to keep a file in v3.x format, you must:
1. Not call `parser.write()` (which always outputs v4.0.0)
2. Manage the file manually outside SwiftProyecto

**Recommendation**: Keep v3.x files as-is. Upgrade only when restructuring the project.

---

## Troubleshooting

### "Unknown schema version"

**Problem**: File has `schemaVersion: 5` or other unexpected value

**Solution**: v4.0.0 only supports v4.0.0 (schemaVersion: 4) or v3.x (no schemaVersion). Update or downgrade the file.

### "Missing required field"

**Problem**: Validation fails with missing field errors

**Solution**: Check the [Validation](#validation-checklist) checklist. Common issues:
- Missing `type` field (should be "project" or "overview")
- `seasons[]` present but season has no `number` or `episodes`
- `variants[]` present but variant has no `season`, `language`, or `path`

### "Cast merge conflict"

**Problem**: Error when merging cast from multiple variants

**Solution**: Ensure character names match exactly. Cast merging is case-sensitive and requires exact character name matches.

### "Invalid episodePath template"

**Problem**: `episodePath` doesn't resolve correctly

**Solution**: Check template variables:
- Use `{season}` for season number
- Use `{number}` for episode number
- Use `{language}` for language code
- Use `{number:03d}` for zero-padded episode numbers

**Example**: `episodes/season-{season}/episode-{number:03d}.{language}.fountain`

---

## See Also

- [PROJECT_MD_REFERENCE_v4.md](PROJECT_MD_REFERENCE_v4.md) — Complete schema reference
- [EXAMPLE_PROJECT_v4.md](EXAMPLE_PROJECT_v4.md) — Working examples
- [VARIANT_REFERENCE.md](VARIANT_REFERENCE.md) — Variant patterns and best practices
- [AGENTS.md](../AGENTS.md) § PROJECT.md Modification Rules — Safe ways to update files

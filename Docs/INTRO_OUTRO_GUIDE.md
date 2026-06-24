---
type: guide
name: Intro and Outro File Patterns — v4.0.0
description: Guide to using introFile and outroFile fields for text directions and segment files
updated: 2026-06-23
---

# Intro and Outro File Patterns — v4.0.0

Comprehensive guide to using `introFile` and `outroFile` fields in PROJECT.md to reference text directions, segment files, and audio files.

---

## Table of Contents

1. [Overview](#overview)
2. [Field Definitions](#field-definitions)
3. [Path Resolution](#path-resolution)
4. [Usage Patterns](#usage-patterns)
5. [Hierarchy and Inheritance](#hierarchy-and-inheritance)
6. [Real-World Examples](#real-world-examples)
7. [Best Practices](#best-practices)

---

## Overview

### What Are Intro/Outro Files?

`introFile` and `outroFile` are optional fields that reference **text direction files** to be used at the beginning and end of seasons or episodes.

**Use Cases:**

| Use Case | Field | Example |
|----------|-------|---------|
| Season introduction narration | `seasons[].introFile` | `season-1/intro.fountain` |
| Season closing remarks | `seasons[].outroFile` | `season-1/outro.fountain` |
| Global project intro | `introFile` (project-level) | `intro.md` |
| Global project outro | `outroFile` (project-level) | `outro.md` |
| Language-specific intro | `seasons[].introFile` (variant) | `intro.es.fountain` |

### File Types

Intro/outro files are typically:
- **Fountain screenplay files** (`.fountain`) — For dialogue/narration to be recorded
- **Markdown files** (`.md`) — For documentation or notes
- **Text files** (`.txt`) — For plain-text scripts
- **Audio files** (`.m4a`, `.mp3`, `.wav`) — For pre-recorded segments

---

## Field Definitions

### Project-Level (Global Default)

```yaml
---
type: project
title: "My Podcast"
author: "John Doe"
created: 2025-01-15T00:00:00Z

introFile: intro.md
outroFile: outro.md
---
```

| Field | Type | Description |
|-------|------|-------------|
| `introFile` | String | Path to global intro file (relative to project root) |
| `outroFile` | String | Path to global outro file (relative to project root) |

### Season-Level (Override Global)

```yaml
seasons:
  - number: 1
    title: "Year One"
    episodes: 365
    introFile: season-1/intro.fountain
    outroFile: season-1/outro.fountain
```

| Field | Type | Description |
|-------|------|-------------|
| `introFile` | String | Path to season intro file (relative to project root or season directory) |
| `outroFile` | String | Path to season outro file (relative to project root or season directory) |

### Resolution Hierarchy

When resolving intro/outro files for a specific season:

1. **Season level** (highest priority)
   - Use `seasons[N].introFile` if present
2. **Project/Master level**
   - Use project-level `introFile` if season doesn't specify
3. **Defaults** (lowest priority)
   - `null` if neither season nor project level specifies

**Example:**

```yaml
introFile: intro.md  # Project-level default

seasons:
  - number: 1
    introFile: season-1/intro.fountain  # Overrides project default
  
  - number: 2
    # No introFile specified → uses project default (intro.md)
```

---

## Path Resolution

### Absolute vs. Relative Paths

Intro/outro paths are always **relative**, never absolute:

```yaml
# ✅ CORRECT (relative)
introFile: intro.md
introFile: season-1/intro.fountain
introFile: ../shared/intro.md

# ❌ INCORRECT (absolute)
introFile: /Users/tom/Projects/podcast/intro.md
introFile: ~/intro.md
introFile: /absolute/path/intro.fountain
```

### Relative Path Base

The interpretation of relative paths depends on the file's location:

#### For Master File (PROJECT.md at root)

Paths are relative to **project root**:

```
project-root/
├── PROJECT.md
├── intro.md                  # Referenced as "intro.md"
└── season-1/
    └── intro.fountain        # Referenced as "season-1/intro.fountain"
```

#### For Variant File (PROJECT.md in season directory)

Paths are relative to **variant directory**:

```
project-root/
└── episodes/season-1/
    ├── PROJECT.md
    ├── intro.fountain        # Referenced as "intro.fountain"
    ├── outro.fountain        # Referenced as "outro.fountain"
    └── scripts/
        └── episode-001.fountain
```

To reference files in parent directory from variant:

```yaml
introFile: ../intro.md  # Goes up one level to project root
```

### Path Templates (Future)

In future versions, intro/outro paths may support templating (currently not supported):

```yaml
# Not yet supported — use explicit paths for now
episodePath: "episodes/season-{season}/intro.{language}.fountain"
```

For now, use separate intro/outro fields per variant.

---

## Usage Patterns

### Pattern 1: Single Global Intro/Outro

**Use Case**: Same intro/outro for all episodes across all seasons.

```yaml
---
type: project
title: "Daily Podcast"
author: Tom Stovall
created: 2025-01-15T00:00:00Z

seasons:
  - number: 1
    episodes: 365
    episodesDir: episodes

introFile: intro.md
outroFile: outro.md
---
```

**Files:**
```
.
├── PROJECT.md
├── intro.md         # Used for all episodes
├── outro.md         # Used for all episodes
└── episodes/
    ├── episode-001.fountain
    └── ...
```

---

### Pattern 2: Per-Season Intro/Outro

**Use Case**: Different intro/outro for each season.

```yaml
---
type: project
title: "Complete Series"
author: Tom Stovall
created: 2025-01-15T00:00:00Z

seasons:
  - number: 1
    episodes: 365
    episodesDir: season-1/episodes
    introFile: season-1/intro.fountain
    outroFile: season-1/outro.fountain

  - number: 2
    episodes: 100
    episodesDir: season-2/episodes
    introFile: season-2/intro.fountain
    outroFile: season-2/outro.fountain
---
```

**Files:**
```
.
├── PROJECT.md
├── season-1/
│   ├── intro.fountain
│   ├── outro.fountain
│   └── episodes/
├── season-2/
│   ├── intro.fountain
│   ├── outro.fountain
│   └── episodes/
```

---

### Pattern 3: Per-Language Intro/Outro (Variants)

**Use Case**: Different intros/outros for different language variants.

**Master (PROJECT.md):**
```yaml
---
type: overview
title: "lingua-matra"

seasons:
  - number: 1
    episodes: 365

languages:
  - code: en
    name: English
  - code: es
    name: Español

variants:
  - season: 1
    language: en
    path: episodes/season-1/PROJECT_en.md
  - season: 1
    language: es
    path: episodes/season-1/PROJECT_es.md
---
```

**English Variant (episodes/season-1/PROJECT_en.md):**
```yaml
---
type: project
title: "lingua-matra — English"
language: en

seasons:
  - number: 1
    episodes: 365
    episodesDir: .
    introFile: intro.en.fountain
    outroFile: outro.en.fountain
---
```

**Spanish Variant (episodes/season-1/PROJECT_es.md):**
```yaml
---
type: project
title: "lingua-matra — Español"
language: es

seasons:
  - number: 1
    episodes: 365
    episodesDir: .
    introFile: intro.es.fountain
    outroFile: outro.es.fountain
---
```

**Files:**
```
episodes/season-1/
├── PROJECT_en.md
├── PROJECT_es.md
├── intro.en.fountain
├── intro.es.fountain
├── outro.en.fountain
├── outro.es.fountain
└── scripts/
    ├── lesson-001.en.fountain
    ├── lesson-001.es.fountain
    └── ...
```

---

### Pattern 4: Pre-Recorded Audio Intros (Fallback)

**Use Case**: Use pre-recorded intro/outro instead of text for generation.

```yaml
---
type: project
title: "Podcast"

seasons:
  - number: 1
    episodes: 365
    introFile: audio/intro.m4a
    outroFile: audio/outro.m4a
---
```

**When rendering:**
- If file is `.fountain` or `.md` → Generate TTS from text
- If file is `.m4a`, `.mp3`, or `.wav` → Use pre-recorded audio directly

---

### Pattern 5: Fallback Hierarchy (Master + Season + Variant)

**Use Case**: Use specific intro for a variant, fall back to season default, then project default.

**Master (PROJECT.md):**
```yaml
introFile: intro.md  # Global default

seasons:
  - number: 1
    episodesDir: season-1/episodes
    introFile: season-1/intro.fountain  # Season override
---
```

**Variant (season-1/PROJECT_en.md):**
```yaml
seasons:
  - number: 1
    introFile: intro.en.fountain  # Variant override
---
```

**Resolution for English Season 1:**
1. Check variant: `intro.en.fountain` ← **Used**
2. Check season: `season-1/intro.fountain`
3. Check master: `intro.md`

---

## Hierarchy and Inheritance

### Resolution Rules

For a specific season/language combination, SwiftProyecto resolves intro/outro files in this order:

1. **Variant file** (if this is a language variant)
   - `seasons[].introFile` in variant PROJECT.md
2. **Season level** (in master or current file)
   - `seasons[].introFile` in master or multi-season file
3. **Project level** (global default)
   - `introFile` at project level
4. **None** (if not specified anywhere)
   - `null`

### Inheritance Example

**Setup:**

```yaml
# Master file
introFile: global-intro.md

seasons:
  - number: 1
    introFile: season-1-intro.fountain
  - number: 2
    # No introFile → inherits global
```

**Variant file for Season 1, Spanish:**

```yaml
seasons:
  - number: 1
    introFile: intro.es.fountain
```

**Resolutions:**

| Context | Resolved File | Source |
|---------|---------------|--------|
| Season 1, English | `season-1-intro.fountain` | Master season level |
| Season 1, Spanish | `intro.es.fountain` | Variant level |
| Season 2, English | `global-intro.md` | Master project level |
| Season 2, Spanish | `global-intro.md` | Master project level (variant inherits) |

---

## Real-World Examples

### Example 1: Daily Meditation Podcast

Single global intro/outro for all episodes.

**Structure:**
```
meditation-podcast/
├── PROJECT.md
├── intro.md
├── outro.md
├── daily-affirmations.txt
└── episodes/
    ├── meditation-001.fountain
    ├── meditation-002.fountain
    └── ...
```

**PROJECT.md:**
```yaml
---
schemaVersion: 4
type: project
title: "Daily Meditations"
author: Tom Stovall
created: 2025-01-15T00:00:00Z

seasons:
  - number: 1
    episodes: 365
    episodesDir: episodes
    filePattern: "*.fountain"

introFile: intro.md
outroFile: outro.md

cast:
  - character: NARRATOR
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
---
```

**intro.md:**
```markdown
# Welcome to Daily Meditations

[Optional intro narration]

---

**NARRATOR**

Welcome to today's meditation...
```

---

### Example 2: Multi-Season Documentary

Different intro/outro per season.

**Structure:**
```
complete-meditations/
├── PROJECT.md
├── season-1/
│   ├── intro.fountain
│   ├── outro.fountain
│   └── episodes/
├── season-2/
│   ├── intro.fountain
│   ├── outro.fountain
│   └── episodes/
└── season-3/
    ├── intro.fountain
    ├── outro.fountain
    └── episodes/
```

**PROJECT.md:**
```yaml
---
schemaVersion: 4
type: project
title: "Complete Meditations"
author: Tom Stovall
created: 2025-01-15T00:00:00Z

seasons:
  - number: 1
    title: "Year One: Books I-IV"
    episodes: 365
    episodesDir: season-1/episodes
    introFile: season-1/intro.fountain
    outroFile: season-1/outro.fountain

  - number: 2
    title: "Year Two: Books V-VIII"
    episodes: 365
    episodesDir: season-2/episodes
    introFile: season-2/intro.fountain
    outroFile: season-2/outro.fountain

  - number: 3
    title: "Year Three: Books IX-X"
    episodes: 365
    episodesDir: season-3/episodes
    introFile: season-3/intro.fountain
    outroFile: season-3/outro.fountain
---
```

**season-1/intro.fountain:**
```fountain
NARRATOR
Welcome to Year One of Complete Meditations. 
In these 365 reflections, we'll explore Books 
One through Four...
```

---

### Example 3: Multi-Language Podcast with Per-Language Intros

**Structure:**
```
lingua-matra/
├── PROJECT.md (master)
└── episodes/season-1/
    ├── PROJECT_en.md
    ├── PROJECT_es.md
    ├── intro.en.fountain
    ├── intro.es.fountain
    ├── outro.en.fountain
    ├── outro.es.fountain
    └── scripts/
        ├── lesson-001.en.fountain
        ├── lesson-001.es.fountain
        └── ...
```

**Master (PROJECT.md):**
```yaml
---
schemaVersion: 4
type: overview
title: "lingua-matra"

seasons:
  - number: 1
    episodes: 365

languages:
  - code: en
    name: English
  - code: es
    name: Español

variants:
  - season: 1
    language: en
    path: episodes/season-1/PROJECT_en.md
  - season: 1
    language: es
    path: episodes/season-1/PROJECT_es.md
---
```

**English Variant (episodes/season-1/PROJECT_en.md):**
```yaml
---
schemaVersion: 4
type: project
title: "lingua-matra — English"
language: en

seasons:
  - number: 1
    episodes: 365
    episodesDir: .
    introFile: intro.en.fountain
    outroFile: outro.en.fountain

cast:
  - character: INSTRUCTOR
    language: en-US
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
---
```

**Spanish Variant (episodes/season-1/PROJECT_es.md):**
```yaml
---
schemaVersion: 4
type: project
title: "lingua-matra — Español"
language: es

seasons:
  - number: 1
    episodes: 365
    episodesDir: .
    introFile: intro.es.fountain
    outroFile: outro.es.fountain

cast:
  - character: INSTRUCTOR
    language: es-MX
    voices:
      apple:
        - com.apple.voice.compact.es-MX.Juan
---
```

**intro.en.fountain:**
```fountain
INSTRUCTOR
(bright, welcoming tone)

Welcome to lingua-matra, where we explore 
language and culture through engaging lessons...
```

**intro.es.fountain:**
```fountain
INSTRUCTOR (Spanish)
(tono cálido, invitador)

Bienvenidos a lingua-matra, donde exploramos 
idiomas y culturas a través de lecciones atractivas...
```

---

## Best Practices

### 1. Use Consistent Naming

Keep intro/outro file names consistent:

```yaml
# ✅ GOOD (consistent, clear naming)
introFile: season-1/intro.fountain
outroFile: season-1/outro.fountain

# ❌ INCONSISTENT (confusing)
introFile: season-1/opening.fountain
outroFile: season-1/closing.txt
```

### 2. Keep Files in Season Directories

For multi-season projects, store intro/outro files in season directories:

```
.
├── season-1/
│   ├── intro.fountain
│   ├── outro.fountain
│   └── episodes/
├── season-2/
│   ├── intro.fountain
│   ├── outro.fountain
│   └── episodes/
```

### 3. Use Language Suffixes for Variants

Include language code in intro/outro filenames:

```yaml
# English variant
introFile: intro.en.fountain
outroFile: outro.en.fountain

# Spanish variant
introFile: intro.es.fountain
outroFile: outro.es.fountain
```

### 4. Consider Empty Intros

If a season has no intro, use `null` or omit the field:

```yaml
seasons:
  - number: 1
    introFile: season-1/intro.fountain  # Has intro
  - number: 2
    # No introFile specified → null (no intro for season 2)
```

### 5. Coordinate with Cast

Ensure intro/outro characters match cast list:

```yaml
cast:
  - character: NARRATOR
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron

introFile: intro.fountain  # Should have NARRATOR dialogue
```

### 6. Document Path Conventions

In your project README, document your intro/outro structure:

```markdown
## Project Structure

- `intro.md` — Global introduction for all episodes
- `season-N/intro.fountain` — Season-specific introduction
- `season-N/outro.fountain` — Season-specific closing
```

---

## See Also

- [PROJECT_MD_REFERENCE_v4.md](PROJECT_MD_REFERENCE_v4.md) — Complete schema reference
- [EXAMPLE_PROJECT_v4.md](EXAMPLE_PROJECT_v4.md) — Working examples
- [VARIANT_REFERENCE.md](VARIANT_REFERENCE.md) — Variant patterns
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) — Upgrading from v3.x

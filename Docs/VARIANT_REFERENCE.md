---
type: reference
name: Variant Patterns and Best Practices — v4.0.0
description: Comprehensive guide to using variant files for multi-season and multi-language projects
updated: 2026-06-23
---

# Variant Patterns and Best Practices — v4.0.0

Comprehensive guide to designing and organizing variant files for multi-season and multi-language projects in SwiftProyecto v4.0.0.

---

## Table of Contents

1. [Overview](#overview)
2. [Master vs. Variant Files](#master-vs-variant-files)
3. [Pattern Types](#pattern-types)
4. [Directory Organization](#directory-organization)
5. [Property Inheritance](#property-inheritance)
6. [Cast Merging](#cast-merging)
7. [Decision Tree](#decision-tree)
8. [Real-World Examples](#real-world-examples)

---

## Overview

### What Are Variants?

**Variant files** are self-contained PROJECT.md files that represent a specific combination of:
- Season number
- Language/locale
- Or both

Variants allow you to:
- ✅ Define per-language metadata (voices, locales, descriptions)
- ✅ Store language-specific episode files in organized directories
- ✅ Maintain separate cast lists for different languages/regions
- ✅ Create hierarchical relationships (master → variant inheritance)
- ✅ Keep projects discoverable at multiple levels

### When to Use Variants

| Use Case | Solution |
|----------|----------|
| Single season, one language | Single PROJECT.md (no variants needed) |
| Single season, multiple languages | Master + language variants |
| Multiple seasons, one language | Master + season variants, OR multi-season single file |
| Multiple seasons, multiple languages | Master + season/language variants |
| Same episodes, different voice casting | Language variants (different cast per language) |
| Regional distribution (same language, different regions) | Regional variants (e.g., en-US vs. en-UK) |

---

## Master vs. Variant Files

### Master File (type: overview)

**Purpose**: Index file that references all variants and provides shared defaults.

**Characteristics**:
- Located at **project root**: `PROJECT.md`
- **type**: `"overview"`
- Contains **seasons[]**, **languages[]**, **variants[]** arrays
- Provides **defaults** for inherited properties
- Can be **minimal** (variants can be self-contained)
- **Discoverable** by ProjectDiscovery but skipped when looking for individual projects

**Example**:

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

languages:
  - code: en
    name: English
  - code: es
    name: Español

variants:
  - season: 1
    language: en
    path: episodes/PROJECT_en.md
  - season: 1
    language: es
    path: episodes/PROJECT_es.md
---
```

### Variant File (type: project)

**Purpose**: Self-contained PROJECT.md for a specific season/language combination.

**Characteristics**:
- Located in **content directory**: `episodes/season-1/PROJECT_es.md`
- **type**: `"project"`
- Contains season-specific and language-specific metadata
- Can **reference master** for inherited properties (optional)
- **Self-contained**: Can exist and be parsed independently
- **Discoverable** by ProjectDiscovery as a normal project file

**Example**:

```yaml
---
schemaVersion: 4
type: project
title: "lingua-matra — Español"
author: Tom Stovall
created: 2025-06-01T00:00:00Z
language: es

seasons:
  - number: 1
    episodes: 365
    episodesDir: .
    filePattern: "*.es.fountain"

cast:
  - character: INSTRUCTOR
    language: es-MX
    voices:
      apple:
        - com.apple.voice.compact.es-MX.Juan
---
```

---

## Pattern Types

### Pattern 1: Master + Single Language Variant

**Structure**: Master file indexes one language variant per season.

```
.
├── PROJECT.md (master, type: overview)
└── episodes/season-1/
    └── PROJECT_es.md (variant, type: project)
```

**Use Case**: Starting with one language variant but expecting more languages later.

**Master (PROJECT.md)**:
```yaml
---
schemaVersion: 4
type: overview
title: "lingua-matra"
author: Tom Stovall

seasons:
  - number: 1
    episodes: 365

languages:
  - code: es
    name: Español

variants:
  - season: 1
    language: es
    path: episodes/season-1/PROJECT_es.md
---
```

**Variant (episodes/season-1/PROJECT_es.md)**:
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

cast:
  - character: NARRATOR
    language: es-MX
    voices:
      apple:
        - com.apple.voice.compact.es-MX.Juan
---
```

---

### Pattern 2: Master + Multiple Language Variants

**Structure**: Master file with variants for each language.

```
.
├── PROJECT.md (master, type: overview)
├── episodes/season-1/
│   ├── PROJECT_en.md
│   ├── PROJECT_es.md
│   └── PROJECT_fr.md
└── episodes/season-2/
    ├── PROJECT_en.md
    ├── PROJECT_es.md
    └── PROJECT_fr.md
```

**Use Case**: Multilingual project (e.g., podcast in 3+ languages).

**Master (PROJECT.md)**:
```yaml
---
schemaVersion: 4
type: overview
title: "lingua-matra"

seasons:
  - number: 1
    episodes: 365
  - number: 2
    episodes: 365

languages:
  - code: en
    name: English
  - code: es
    name: Español
  - code: fr
    name: Français

variants:
  - season: 1
    language: en
    path: episodes/season-1/PROJECT_en.md
  - season: 1
    language: es
    path: episodes/season-1/PROJECT_es.md
  - season: 1
    language: fr
    path: episodes/season-1/PROJECT_fr.md
  - season: 2
    language: en
    path: episodes/season-2/PROJECT_en.md
  - season: 2
    language: es
    path: episodes/season-2/PROJECT_es.md
  - season: 2
    language: fr
    path: episodes/season-2/PROJECT_fr.md
---
```

**Benefits**:
- Clear relationship structure (master indexes all variants)
- Each variant is independent and discoverable
- Easy to add new languages (just add variant references)
- Per-language voice selection and casting

---

### Pattern 3: Master + Season Variants (Single Language)

**Structure**: Master file with variants for each season (single language).

```
.
├── PROJECT.md (master, type: overview)
├── season-1/
│   └── PROJECT.md (variant for season 1)
├── season-2/
│   └── PROJECT.md (variant for season 2)
└── season-3/
    └── PROJECT.md (variant for season 3)
```

**Use Case**: Multi-season series with per-season metadata but single language.

**Master (PROJECT.md)**:
```yaml
---
schemaVersion: 4
type: overview
title: "Complete Meditations"

seasons:
  - number: 1
    title: "Year One"
    episodes: 365
  - number: 2
    title: "Year Two"
    episodes: 365
  - number: 3
    title: "Year Three"
    episodes: 365

variants:
  - season: 1
    language: null
    path: season-1/PROJECT.md
  - season: 2
    language: null
    path: season-2/PROJECT.md
  - season: 3
    language: null
    path: season-3/PROJECT.md
---
```

**Variant (season-1/PROJECT.md)**:
```yaml
---
schemaVersion: 4
type: project
title: "Complete Meditations — Year One"

seasons:
  - number: 1
    title: "Year One"
    episodes: 365
    episodesDir: episodes

cast:
  - character: NARRATOR
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
---
```

**Benefits**:
- Master file documents all seasons
- Each season is independently navigable
- Per-season customization (cast, TTS, descriptions)

---

### Pattern 4: Single File with episodePath (No Variants)

**Structure**: Single PROJECT.md using `episodePath` template for multi-language episodes.

```
.
├── PROJECT.md (single file, multi-language support)
└── episodes/
    ├── lesson-001.en.fountain
    ├── lesson-001.es.fountain
    ├── lesson-001.fr.fountain
    ├── lesson-002.en.fountain
    └── ...
```

**Use Case**: Multi-language episodes in same directory; no per-language metadata differences needed.

**PROJECT.md**:
```yaml
---
schemaVersion: 4
type: project
title: "Daily Languages"

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

**Benefits**:
- Simple structure (single file)
- Automatic path templating
- Compact cast list (all languages in one character entry)

**Limitations**:
- No per-language metadata differences (no separate cast per language)
- All episode counts must be identical across languages
- Harder to add regional variants (e.g., en-US vs. en-UK)

---

## Directory Organization

### Recommended Structure: Master + Variants

**Multi-language, multi-season project:**

```
lingua-matra/
├── PROJECT.md                          # Master (type: overview)
├── README.md                           # Project documentation
├── episodes/
│   ├── season-1/
│   │   ├── PROJECT_en.md              # Variant: Season 1, English
│   │   ├── PROJECT_es.md              # Variant: Season 1, Spanish
│   │   ├── PROJECT_fr.md              # Variant: Season 1, French
│   │   ├── audio/
│   │   │   ├── en/
│   │   │   ├── es/
│   │   │   └── fr/
│   │   └── scripts/
│   │       ├── lesson-001.en.fountain
│   │       ├── lesson-001.es.fountain
│   │       ├── lesson-001.fr.fountain
│   │       └── ...
│   └── season-2/
│       ├── PROJECT_en.md
│       ├── PROJECT_es.md
│       ├── PROJECT_fr.md
│       ├── audio/
│       └── scripts/
└── .gitignore
```

**Key Principles:**

1. **Master at root**: `PROJECT.md` (type: overview)
2. **Variants in content directories**: `episodes/season-N/PROJECT_<lang>.md`
3. **Episode files with variants**: `episodes/season-N/scripts/lesson-NNN.<lang>.fountain`
4. **Audio organized by language**: `episodes/season-N/audio/<lang>/`
5. **Master references all variants**: `variants[]` array lists all combinations

---

### Alternative: Hybrid (Master + Single File)

For projects transitioning to multi-language, use both patterns:

```
lingua-matra/
├── PROJECT.md                    # Master (type: overview)
├── episodes/
│   └── season-1/
│       ├── PROJECT.md           # Single file with episodePath
│       └── scripts/
│           ├── lesson-001.en.fountain
│           ├── lesson-001.es.fountain
│           └── ...
└── archive/
    └── season-0/
        └── PROJECT_es.md        # Legacy variant
```

Master file documents structure:

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
    language: null  # null means "single file supports all languages"
    path: episodes/season-1/PROJECT.md
---
```

---

## Property Inheritance

### Resolution Hierarchy

When resolving a property for a variant, SwiftProyecto checks in order:

1. **Variant level**: Does the variant define this property?
2. **Season level**: Does the season definition include this property?
3. **Master level**: Does the master file define this property?
4. **Defaults**: Use built-in defaults

### Example: Cast Resolution

**Master file:**
```yaml
cast:
  - character: NARRATOR
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
  - character: GUEST
    voices:
      apple:
        - com.apple.voice.compact.en-US.Victoria
```

**Variant file (Spanish):**
```yaml
cast:
  - character: NARRATOR  # Override
    language: es-MX
    voices:
      apple:
        - com.apple.voice.compact.es-MX.Juan
  # GUEST not specified → inherits from master
```

**Resolved cast (after merge):**
```yaml
cast:
  - character: NARRATOR
    language: es-MX
    voices:
      apple:
        - com.apple.voice.compact.es-MX.Juan  # From variant
  - character: GUEST
    voices:
      apple:
        - com.apple.voice.compact.en-US.Victoria  # Inherited from master
```

### Example: Path Resolution

**Master file:**
```yaml
audioDir: audio
episodesDir: episodes
```

**Variant (Season 1, English):**
```yaml
seasons:
  - number: 1
    episodesDir: .  # Relative to variant directory
```

**Resolved paths**:
- Audio output: `audio/` (inherited from master)
- Episode input: `episodes/season-1/.` (season override, relative to season directory)

---

## Cast Merging

### Lossless Merge Guarantee

SwiftProyecto v4.0.0 supports **multiple voice IDs per provider**, enabling lossless cast merging:

**Master cast:**
```yaml
cast:
  - character: NARRATOR
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
```

**Variant 1 (Spanish):**
```yaml
cast:
  - character: NARRATOR
    voices:
      apple:
        - com.apple.voice.compact.es-MX.Juan
```

**Variant 2 (French):**
```yaml
cast:
  - character: NARRATOR
    voices:
      apple:
        - com.apple.voice.compact.fr-FR.Bernard
```

**Combined cast (all voices preserved):**
```yaml
cast:
  - character: NARRATOR
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron   # From master
        - com.apple.voice.compact.es-MX.Juan    # From variant 1
        - com.apple.voice.compact.fr-FR.Bernard # From variant 2
```

### Merge Strategies

SwiftProyecto supports three merge strategies:

#### 1. Preserve Existing (Default)

- Variant cast **overrides** master for specified characters
- Unspecified characters **inherit** from master
- **Use case**: Language variants with different voices for some characters

```swift
let merged = CastMember.merge(variantCast, with: masterCast, strategy: .preserveExisting)
```

#### 2. Prefer New

- New cast completely **replaces** old cast
- No inheritance — variant is independent
- **Use case**: Completely different casting for a region

```swift
let merged = CastMember.merge(variantCast, with: masterCast, strategy: .preferNew)
```

#### 3. Combine

- **All voice IDs preserved** across providers
- Both variant and master voices are retained
- **Use case**: Building a cast pool with all available voices

```swift
let merged = CastMember.merge(variantCast, with: masterCast, strategy: .combine)
```

---

## Decision Tree

Use this tree to choose your variant pattern:

```
Is this a single-season project?
├─ YES: Single language?
│  ├─ YES → Use single PROJECT.md (no variants needed)
│  └─ NO → Master + language variants
├─ NO: Will you have language variants?
│  ├─ YES → Master + season/language variants (Matrix pattern)
│  └─ NO → Master + season variants OR multi-season single file
```

### Quick Decision Table

| Seasons | Languages | Pattern | Master Type | Variants |
|---------|-----------|---------|-------------|----------|
| 1 | 1 | Single file | project | None |
| 1 | 2+ | Master + variants | overview | language variants |
| 2+ | 1 | Master + variants | overview | season variants |
| 2+ | 2+ | Master + matrix | overview | season × language variants |
| N/A | 2+ | Single file + episodePath | project | None (uses template) |

---

## Real-World Examples

### Example 1: lingua-matra (Multi-Season, Multi-Language)

Project structure:
```
lingua-matra/
├── PROJECT.md (master)
├── episodes/season-1/
│   ├── PROJECT_en.md
│   ├── PROJECT_es.md
│   └── PROJECT_fr.md
└── episodes/season-2/
    ├── PROJECT_en.md
    ├── PROJECT_es.md
    └── PROJECT_fr.md
```

**Master (PROJECT.md)**:
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
  - number: 2
    episodes: 365

languages:
  - code: en
    name: English
  - code: es
    name: Español
  - code: fr
    name: Français

variants:
  - season: 1
    language: en
    path: episodes/season-1/PROJECT_en.md
    status: published
  - season: 1
    language: es
    path: episodes/season-1/PROJECT_es.md
    status: published
  - season: 1
    language: fr
    path: episodes/season-1/PROJECT_fr.md
    status: published
  - season: 2
    language: en
    path: episodes/season-2/PROJECT_en.md
    status: in_progress
  - season: 2
    language: es
    path: episodes/season-2/PROJECT_es.md
    status: in_progress
  - season: 2
    language: fr
    path: episodes/season-2/PROJECT_fr.md
    status: draft
---
```

Each variant file contains language-specific voices and episode references.

---

### Example 2: Complete Meditations (Multi-Season, Single Language)

```
complete-meditations/
├── PROJECT.md (master)
├── season-1/PROJECT.md (variant)
├── season-2/PROJECT.md (variant)
├── season-3/PROJECT.md (variant)
└── season-4/PROJECT.md (variant)
```

**Master (PROJECT.md)**:
```yaml
---
schemaVersion: 4
type: overview
title: "Complete Meditations"

seasons:
  - number: 1
    title: "Year One: Books I-IV"
    episodes: 365
  - number: 2
    title: "Year Two: Books V-VIII"
    episodes: 365
  - number: 3
    title: "Year Three: Books IX-X"
    episodes: 365
  - number: 4
    title: "Year Four: Books XI-XII"
    episodes: 365

variants:
  - season: 1
    language: null
    path: season-1/PROJECT.md
  - season: 2
    language: null
    path: season-2/PROJECT.md
  - season: 3
    language: null
    path: season-3/PROJECT.md
  - season: 4
    language: null
    path: season-4/PROJECT.md
---
```

Each season variant contains per-season casting and descriptions.

---

## See Also

- [PROJECT_MD_REFERENCE_v4.md](PROJECT_MD_REFERENCE_v4.md) — Complete schema reference
- [EXAMPLE_PROJECT_v4.md](EXAMPLE_PROJECT_v4.md) — Working examples
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) — Upgrading from v3.x
- [AGENTS.md](../AGENTS.md) — Library documentation

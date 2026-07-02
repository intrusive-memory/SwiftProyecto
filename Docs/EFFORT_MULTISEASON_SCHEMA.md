---
type: doc
name: Multi-Season PROJECT.md Schema v4.0.0
description: Requirements and design document for multi-season support in PROJECT.md files
effort_status: planning
created: 2026-06-23
updated: 2026-06-23
version: 4.0.0
related_issue: null
---

# Multi-Season, Multi-Language PROJECT.md Schema (v4.0.0)

## Overview

SwiftProyecto v4.0.0 is a **two-phase release cycle** focused on **library-first development**: build the tools first, then use LLM-based generation.

### Phase 1: v4.0.0 — Schema & Tools (This Effort)

**What v4.0.0 provides**:
- Multi-season and multi-language PROJECT.md schema
- Libraries for reading/writing/merging PROJECT.md files
- Directory structure recognition and validation
- Cast list merging from multiple files (with lossless merge guarantees)
- Property resolution hierarchy
- Support for all variants and inheritance patterns

**What v4.0.0 does NOT provide**:
- Auto-generation of PROJECT.md files (deferred to v4.1.0)
- LLM-based schema optimization (deferred to v4.1.0)

### Phase 2: v4.1.0 — Auto-Generation (Future)

**What v4.1.0 will add**:
- FoundationModels/LLM integration to analyze directory structure
- Automatic generation of optimal PROJECT.md files
- LLM-assisted migration of v3.x → v4.0.0
- Interactive prompting for ambiguous structure decisions

**Why separate releases?**:
- v4.0.0 focuses on **correctness** (library tools are rock-solid)
- v4.1.0 focuses on **ease-of-use** (LLM reduces manual effort)
- v4.0.0 is stable before LLM complexity is added
- Cast merging & schema support must be perfect before LLM uses them

---

## Schema Support (v4.0.0)

This effort defines support for:
1. **Multi-season projects** with per-season metadata, episode counts, and file organization
2. **Multi-language variants** where each season/language combination references a distinct PROJECT.md in its content directory
3. **Hierarchical metadata inheritance** where master PROJECT.md properties serve as defaults for referenced variant files

**Architecture**: 
- **Master PROJECT.md** (`type: overview`) at project root acts as index and template
- **Variant PROJECT.md** files (one per season/language) in content directories inherit and override master properties
- Properties in master form the basis for variant properties; variants are self-contained but reference the master for shared context

**Real-world example**: [`lingua-matra`](~/Projects/podcasts/lingua-matra) — multi-language podcast where each language has its own PROJECT.md, all referenced from a master index.

**Breaking Change**: This is a major schema revision. Projects must either:
1. Be migrated to the new schema, or
2. Remain on v3.x with frozen support

**Target Release**: SwiftProyecto 4.0.0 (schema + tools)

---

## Current State (v3.x)

### Project-Level Metadata

```yaml
---
type: project
title: "Podcast Meditations"
author: Tom Stovall
created: 2025-01-25T00:00:00Z
description: "..."
season: 1
episodes: 365
genre: Documentary
tags: [mindfulness]
episodesDir: episodes
audioDir: audio
filePattern: "*.fountain"
exportFormat: m4a
---
```

**Limitations:**
- Single season per file
- Episode count is project-wide (not per-season)
- No per-season file organization (e.g., `episodes/season-1`, `episodes/season-2`)
- No per-season cast variants (same cast for all seasons)
- Hard to express multi-season series in a single file

---

## Target State (v4.0.0)

### New Schema Structure

```yaml
---
schemaVersion: 4
type: project
title: "Podcast Meditations"
author: Tom Stovall
created: 2025-01-25T00:00:00Z
description: "A year-long journey through Marcus Aurelius wisdom"
genre: Documentary
tags: [mindfulness, self-care]

# New in v4: Seasons array replaces single season/episodes fields
seasons:
  - number: 1
    title: "Year One"
    description: "Books I-IV"
    episodes: 365
    releaseDate: 2025-01-25T00:00:00Z
    episodesDir: episodes/season-1
    filePattern: "*.fountain"
  
  - number: 2
    title: "Year Two"
    description: "Books V-VIII"
    episodes: 365
    releaseDate: 2026-01-25T00:00:00Z
    episodesDir: episodes/season-2
    filePattern: "*.fountain"

# Global generation defaults (applied to all seasons unless overridden)
audioDir: audio
exportFormat: m4a
preGenerateHook: "make validate"
postGenerateHook: "make publish"

# Global cast (optional, can be overridden per-season)
cast:
  - character: MARCUS AURELIUS
    actor: Tom Stovall
    gender: M
    voices:
      apple: com.apple.voice.compact.en-US.Aaron

# TTS configuration
tts:
  provider: apple
  voiceLanguage: en-US
---
```

---

## Critical Feature: Lossless Cast Merging

**v4.0.0 Requirement**: Cast list merging from multiple PROJECT.md files must be **lossless** — no information lost during merges.

### Cast Merging Use Cases

**Case 1: Master + Variant Cast**
```
Master cast: [NARRATOR, MAESTRA, GUEST_HOST]
Variant cast: [NARRATOR (language: es-MX)]

Merged result: [NARRATOR (variant), MAESTRA, GUEST_HOST]
→ Variant's NARRATOR overrides, others inherited
→ Zero information loss
```

**Case 2: Combining Multiple Variants**
```
es variant: [NARRATOR (apple: es-voice), MAESTRA (apple: es-maestra)]
fr variant: [NARRATOR (apple: fr-voice), MAESTRA (apple: fr-maestra)]

Combined: [NARRATOR (apple: {es-voice, fr-voice}), MAESTRA (apple: {es-maestra, fr-maestra})]
→ All voice IDs preserved
→ Zero information loss
```

**Case 3: Merging New Information**
```
Old variant: [NARRATOR (apple: narrator-v1)]
New variant: [NARRATOR (elevenlabs: narrator-v2)]

Merged: [NARRATOR (apple: narrator-v1, elevenlabs: narrator-v2)]
→ Both voice providers preserved
→ Zero information loss
```

### Merge Guarantees (v4.0.0 Must Deliver)

- ✅ **No voice IDs discarded** — all provider voices preserved during merges
- ✅ **No character information lost** — actors, gender, prompts preserved
- ✅ **Deterministic ordering** — merges always produce same result
- ✅ **Conflict resolution clear** — documented how ties are broken
- ✅ **Comprehensive tests** — merge tested with 50+ scenarios

### Implementation

**CastMember.merge()** method:
```swift
let merged = existingCast.merge(with: newCast, strategy: .preserveExisting)
// strategy: .preserveExisting | .preferNew | .combine
// Result: zero information loss regardless of strategy
```

**Related API**:
- `ProjectFrontMatter.mergingCast(_:forProvider:)` — already exists, enhance for v4.0
- `ProjectFrontMatter.mergeCast(_:_:)` — new, for combining multiple PROJECT files
- Tests: 50+ scenarios covering all merge paths

---

## Episode Path Template

### Overview

The `episodePath` field at the master level defines a **path template** that describes how episodes are organized across all variants in the project. It serves three purposes:

1. **Documentation**: Shows the structure at a glance
2. **Discovery**: Tools can resolve episode locations from variant metadata
3. **Validation**: Variants should align with the declared structure

### Template Variables

The template uses `<variable>` placeholders:

| Variable | Type | Description |
|----------|------|-------------|
| `<language>` | String | Language code (e.g., `es`, `fr`) |
| `<season>` | Integer | Season number (e.g., `1`, `2`) |
| `<episode>` | Integer | Episode number (e.g., `1`, `101`) |
| `<ext>` | String | File extension (e.g., `fountain`, `highland`, `fdx`) |

### Common Patterns

**Language-first with seasons**:
```yaml
episodePath: "episodes/<language>/<season>/<episode>.<ext>"
# Resolves to: episodes/es/1/episode_1.fountain
# Variants at: episodes/es/s1/PROJECT.md
```

**Single-language projects**:
```yaml
episodePath: "episodes/<episode>.<ext>"
# Resolves to: episodes/episode_1.fountain
# Variants at: episodes/PROJECT.md
```

**Season-first (less common)**:
```yaml
episodePath: "episodes/<season>/<language>/<episode>.<ext>"
# Resolves to: episodes/1/es/episode_1.fountain
# Variants at: episodes/1/es/PROJECT.md
```

**Flat (no season organization)**:
```yaml
episodePath: "episodes/<language>/<episode>.<ext>"
# Resolves to: episodes/es/episode_1.fountain
# Variants at: episodes/es/PROJECT.md
```

### Resolution

When generating or discovering episodes, tools resolve the template:

```swift
// Given:
// - episodePath: "episodes/<language>/<season>/<episode>.<ext>"
// - language: "es"
// - season: 1
// - episode: 5
// - ext: "fountain"

// Resolved path:
// episodes/es/1/episode_5.fountain
```

### Variant Alignment

Variants should organize files according to the master's `episodePath`:

```yaml
# Master PROJECT.md
episodePath: "episodes/<language>/<season>/<episode>.<ext>"

# Variant: episodes/es/s1/PROJECT.md
episodesDir: "."  # Files are in episodes/es/s1/
filePattern: "episode_*.fountain"  # Matches episode_1.fountain, episode_2.fountain, etc.
```

The variant's `episodesDir` points to the directory where episode files live, which should align with the master's `episodePath` when the template is instantiated.

---

## Multi-Language Variant System

### Overview

Projects can have language variants where each language (or season/language combination) has its own PROJECT.md file in the directory where content is generated. The master PROJECT.md acts as an index and template; each variant inherits properties from the master and adds language-specific overrides.

**Example structure** (lingua-matra pattern):

```
lingua-matra/
├── PROJECT.md                    # Master (type: overview)
├── episodes/
│   ├── es/
│   │   ├── PROJECT.md           # Spanish variant (language: es-MX)
│   │   └── episode_*.fountain
│   ├── fr/
│   │   ├── PROJECT.md           # French variant (language: fr-FR)
│   │   └── episode_*.fountain
│   └── ...
└── audio/
    ├── es/
    │   └── episode_*.m4a        # Spanish audio
    ├── fr/
    │   └── episode_*.m4a        # French audio
    └── ...
```

**Multi-season variant structure** (proposed):

```
project/
├── PROJECT.md                    # Master (type: overview)
├── episodes/
│   ├── es/
│   │   ├── s1/
│   │   │   ├── PROJECT.md       # Spanish, Season 1
│   │   │   └── episode_*.fountain
│   │   ├── s2/
│   │   │   ├── PROJECT.md       # Spanish, Season 2
│   │   │   └── episode_*.fountain
│   │   └── ...
│   ├── fr/
│   │   ├── s1/
│   │   │   ├── PROJECT.md       # French, Season 1
│   │   │   └── episode_*.fountain
│   │   ├── s2/
│   │   │   ├── PROJECT.md       # French, Season 2
│   │   │   └── episode_*.fountain
│   │   └── ...
│   └── ...
└── audio/
    ├── es/
    │   ├── s1/
    │   │   └── episode_*.m4a
    │   ├── s2/
    │   │   └── episode_*.m4a
    │   └── ...
    ├── fr/
    │   ├── s1/
    │   │   └── episode_*.m4a
    │   └── ...
    └── ...
```

### Master PROJECT.md (`type: overview`)

The master file serves three purposes:
1. **Index**: Lists all seasons, languages, and their variants
2. **Template**: Defines shared properties (cast, TTS config, genre, tags)
3. **Authority**: Central location for project-wide metadata

```yaml
---
schemaVersion: 4
type: overview
title: "Multi-Season, Multi-Language Project"
author: Tom Stovall
created: 2026-01-01T00:00:00Z
description: "A global language-learning podcast across multiple seasons"
genre: Education
tags: [podcast, multilingual, language-learning]

# Season definitions
seasons:
  - number: 1
    title: "Season One"
    description: "Beginner level"
  - number: 2
    title: "Season Two"
    description: "Intermediate level"

# Language definitions
languages:
  - code: es
    name: "Español (México)"
    locale: es-MX
  - code: fr
    name: "Français"
    locale: fr-FR
  - code: it
    name: "Italiano"
    locale: it-IT

# Variant references (season × language combinations)
# Path is relative to master PROJECT.md location
variants:
  - season: 1
    language: es
    path: episodes/s1/es/PROJECT.md
    status: published
  
  - season: 1
    language: fr
    path: episodes/s1/fr/PROJECT.md
    status: published
  
  - season: 2
    language: es
    path: episodes/s2/es/PROJECT.md
    status: in_progress

# Shared cast (inherited by all variants unless overridden)
cast:
  - character: MAESTRA
    voicePrompt: "Female teaching voice, patient and clear"
    language: neutral
    voices:
      voxalta: voices/MAESTRA.vox

# Shared TTS config
tts:
  provider: voxalta
  model: "1.7b"

---
```

### Variant PROJECT.md (`type: project`)

Each variant file is a complete, self-contained PROJECT.md that:
- References its master (optionally, for discovery)
- Overrides inherited properties (language, cast, paths)
- Declares season and language membership
- Includes variant-specific metadata (episode count, episode index)

```yaml
---
schemaVersion: 4
type: project
title: "Lingua Matra — Español"
author: Tom Stovall
created: 2026-01-01T00:00:00Z

# Variant metadata (references back to master)
masterPath: "../../PROJECT.md"
season: 1
language: es-MX

description: "Learn Spanish one verb tense at a time"
episodes: 110
genre: Education
tags: [spanish, language-learning, vocabulary]

# Variant-specific paths (relative to this file's directory)
episodesDir: "."
audioDir: "../../audio/s1/es"
filePattern: ["*.fountain", "*.highland"]
exportFormat: m4a

# Variant-specific cast (overrides master cast)
cast:
  - character: MAESTRA
    voicePrompt: "Native Spanish-Mexican teacher, clear and patient"
    language: es-MX
    voices:
      voxalta: ../../voices/MAESTRA.vox
  
  - character: NARRADOR
    voicePrompt: "English narrator for intro/outro"
    language: en
    voices:
      voxalta: ../../voices/NARRADOR.vox

# Variant-specific TTS config (overrides master)
tts:
  provider: voxalta
  model: "1.7b"

# Episode index (variant-specific)
episodes_index:
  - number: 1
    title: "Present Tense, Level 1"
    summary: "Simple present-tense sentences"
  - number: 2
    title: "Present Tense, Level 2"
    summary: "Compound present-tense sentences"
  # ... more episodes

---
```

---

## Schema Changes

### New Top-Level Fields (All Projects)

| Field | Type | Required | Values | Description |
|-------|------|----------|--------|-------------|
| `schemaVersion` | Integer | ✅ Yes (v4+) | `4` | Pinned schema version. **Required for v4.0.0+**, absent in v3.x |
| `type` | String | ✅ Yes | `"project"`, `"overview"` | **Document type**. See [Type Values](#type-values-okf-alignment) below. |

#### Type Values (OKF Alignment)

| Value | Description | Google OKF Alignment | Usage |
|-------|-------------|---------------------|-------|
| `project` | **Standalone project file** — describes a single project, season/language variant, or content collection | Entity/Document type | Individual project files, variant PROJECT.md files at language/season level |
| `overview` | **Index or parent document** — references multiple child projects/variants and defines shared metadata | Index/Collection type | Master PROJECT.md at project root; aggregates all seasons/languages |

**Open Knowledge Format Alignment**:
- SwiftProyecto uses `type` as the document classification, matching OKF's entity-type system
- `project` ≈ OKF Entity (specific project instance)
- `overview` ≈ OKF Collection/Index (aggregates multiple entities)
- Properties flow from overview → project (inheritance), mirroring OKF's entity resolution chain

**Why two types?**:
- **`type: project`** — Actionable by generators (can render audio, discover episodes)
- **`type: overview`** — Structural/informational (indexes variants, doesn't generate directly)
- Clear distinction allows tools to handle differently without ambiguity

### Master-Specific Fields (`type: overview`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `episodePath` | String | — | Path template describing episode file organization (see below) |
| `seasons` | Array of SeasonDefinition | — | Array of season metadata (number, title, description) |
| `languages` | Array of LanguageDefinition | — | Array of language metadata (code, name, locale) |
| `variants` | Array of VariantReference | — | Array of variant references (season, language, path, status) |
| `cast` | Array of CastMember | — | Global/shared cast inherited by variants |
| `tts` | TTSConfig | — | Global/shared TTS config inherited by variants |

### Variant-Specific Fields (`type: project`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `masterPath` | String | — | Relative path to master PROJECT.md (for discovery) |
| `season` | Integer | — | Season number this variant belongs to |
| `language` | String | — | BCP-47 language code or locale (e.g., `es-MX`, `fr-FR`) |

### Audio Generation Fields (Optional)

These optional fields specify intro/outro audio files to be generated separately and optionally prepended/appended to episode audio:

| Field | Type | Description |
|-------|------|-------------|
| `introFile` | String | Relative path to intro script file (e.g., `intro.fountain`). Generated separately from episodes. |
| `outroFile` | String | Relative path to outro script file (e.g., `outro.fountain`). Generated separately from episodes. |

**Behavior**:
- If specified, intro/outro are generated as distinct audio assets (not combined with episodes by default)
- `introFile`/`outroFile` are project-resolved: interpreted relative to the project root (the PROJECT.md location), NOT relative to `episodesDir`
- Apps can choose to prepend intro / append outro during post-production combining
- Useful for shared intro/outro across all episodes in a season/language (e.g., branding, credits)

### Type Definitions

#### SeasonDefinition

```yaml
seasons:
  - number: 1          # (required) Season number
    title: "..."       # (optional) Season title
    description: "..." # (optional) Season description
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `number` | Integer | ✅ Yes | Season number (must be unique) |
| `title` | String | — | Season title |
| `description` | String | — | Season description |

#### LanguageDefinition

```yaml
languages:
  - code: es           # (required) BCP-47 language code
    name: "Español"    # (required) Display name
    locale: es-MX      # (optional) Full locale identifier
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `code` | String | ✅ Yes | BCP-47 language code (e.g., `es`, `fr`) |
| `name` | String | ✅ Yes | Display name (e.g., "Español", "Français") |
| `locale` | String | — | Full BCP-47 locale (e.g., `es-MX`, `fr-FR`) |

#### VariantReference

```yaml
variants:
  - season: 1          # (required) Season number
    language: es       # (required) Language code
    path: "..."        # (required) Path to variant PROJECT.md
    status: published  # (optional) Status: published|in_progress|draft|obsolete
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `season` | Integer | ✅ Yes | Season number |
| `language` | String | ✅ Yes | Language code from `languages` array |
| `path` | String | ✅ Yes | Relative path to variant PROJECT.md |
| `status` | String | — | Variant status: `published`, `in_progress`, `draft`, `obsolete` |

### Deprecated Fields (v3.x → v4.0.0)

The following fields are **deprecated** in v4.0.0 but MUST be supported for backward compatibility:

| Old Field | Migration Strategy |
|-----------|-------------------|
| `season` (Int) | Move to `seasons[0].number` |
| `episodes` (Int) | Move to `seasons[0].episodes` |

### Season Object Structure

```yaml
seasons:
  - number: 1                               # Season number (required)
    title: "Season One"                     # Season title (optional)
    description: "First season overview"    # Season description (optional)
    episodes: 12                            # Episode count for this season (required)
    releaseDate: 2025-01-25T00:00:00Z       # Season release date (optional)
    episodesDir: episodes/season-1          # Season-specific episode directory (optional)
    filePattern: "*.fountain"                # Season-specific file pattern (optional)
    introFile: "intro.fountain"             # Intro file (optional)
    outroFile: "outro.fountain"             # Outro file (optional)
    cast:                                    # Season-specific cast (optional)
      - character: NARRATOR
        actor: Jane Doe
        voices:
          apple: com.apple.voice.compact.en-US.Samantha
    tts:                                     # Season-specific TTS config (optional)
      provider: elevenlabs
```

### Season Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `number` | Integer | ✅ Yes | Season number (e.g., 1, 2, 3). Must be unique within project |
| `title` | String | — | Season title (e.g., "The First Year") |
| `description` | String | — | Season-specific description |
| `episodes` | Integer | ✅ Yes | Episode count for this season |
| `releaseDate` | ISO 8601 Timestamp | — | Season release or air date |
| `episodesDir` | String | — | Season-specific episode directory (relative to PROJECT.md) |
| `filePattern` | String or Array | — | Season-specific file pattern override |
| `introFile` | String | — | Intro script file path (project-resolved: relative to the project root) |
| `outroFile` | String | — | Outro script file path (project-resolved: relative to the project root) |
| `cast` | Array of CastMember | — | Season-specific cast (overrides global `cast`) |
| `tts` | TTSConfig | — | Season-specific TTS configuration override |

### Property Inheritance & Resolution

#### Property Resolution Hierarchy (File Path Based)

**Core Principle**: Properties resolve by **file hierarchy level**. The deeper/more-specific the file, the higher its priority. File path determines property resolution order.

**In Single-File Mode** (one PROJECT.md with multiple seasons):
1. Season-specific value (e.g., `seasons[0].audioDir`) — **highest priority**
2. Project-level value (e.g., top-level `audioDir`)
3. Hardcoded default (e.g., `"audio"`)

**In Master + Variant Mode** (separate PROJECT.md files):
1. **Variant PROJECT.md** — **highest priority** (deepest file: `episodes/<lang>/<season>/`)
2. **Season definition in master** — medium priority (in master's `seasons:` array)
3. **Master PROJECT.md** — **lowest priority** (shallowest file: project root)
4. **Hardcoded default**

**Example hierarchy** (reading variant at `episodes/es/s2/PROJECT.md`):
```
Hardcoded default: "m4a"
  ↑ overridden by
Master audioDir: "audio"
  ↑ overridden by
Master season 2 audioDir: "audio/premium"
  ↑ overridden by
Variant audioDir: "../../audio/es/s2"  ← Final resolved value
```

**How ProjectDiscovery resolves**:
```swift
// When reading variant for language=es, season=2:
// 1. Load master PROJECT.md (root)
// 2. Find season 2 definition in master
// 3. Load variant PROJECT.md (episodes/es/s2/)
// 4. Resolve: variant > season > master > default
```

#### Within a Single Project File (v4 Single-File Mode)

Fields at the project level (not in `seasons`) function as **defaults** for all seasons. Season-specific values override:

| Field | Behavior |
|-------|-----------|
| `audioDir` | Project-level default; season value overrides if present |
| `exportFormat` | Project-level default; season value overrides if present |
| `introFile` | Project-level default; season value overrides if present |
| `outroFile` | Project-level default; season value overrides if present |
| `preGenerateHook` | Project-level hook; runs once before all seasons (not overridable per-season) |
| `postGenerateHook` | Project-level hook; runs once after all seasons (not overridable per-season) |
| `cast` | Project-level default; season value overrides if present |
| `tts` | Project-level default; season value overrides if present |

#### Master → Variant Inheritance (Multi-Language Model)

When a variant references a master, property resolution follows the hierarchy: variant overrides season overrides master overrides default:

1. **Variant's own value** — **highest priority** (most specific)
2. **Master's season definition** (if applicable)
3. **Master's project-level value** — **lowest priority** (most general)
4. **Hardcoded default**

**Property Resolution by File Hierarchy** (all properties follow the same pattern):

All properties resolve: **Variant > Season > Master > Default**

| Property | Resolution | Notes |
|----------|------------|-------|
| `cast` | Variant overrides season overrides master | Unspecified characters inherit from parent |
| `tts` | Variant overrides season overrides master | Deepest level wins |
| `genre`, `tags` | Variant overrides if specified; otherwise inherited | Variant specializes or inherits |
| `audioDir`, `exportFormat` | Variant overrides season overrides master | Per-variant output configuration |
| `introFile`, `outroFile` | Variant overrides season overrides master | Per-variant audio assets |
| `episodesDir`, `filePattern` | Variant overrides season overrides master | Per-variant directory structure |
| `preGenerateHook`, `postGenerateHook` | Variant overrides season overrides master | No automatic chaining; explicit override |

**Override semantics**: If a property is present at a level, it **completely overrides** that property from parent levels (except for `cast` where unspecified characters inherit).

**Non-inherited properties** (variant must declare):
- `language` — Required to identify variant
- `season` — Required to identify season membership
- `episodesDir` — Must be variant-specific (points to variant's content)
- `audioDir` — Must be variant-specific (points to variant's audio output)
- `episodes` — Variant's specific episode count
- `introFile`, `outroFile` — Variant's intro/outro files (if used)

**Example inheritance**:

```yaml
# Master PROJECT.md
cast:
  - character: MAESTRA
    voices:
      voxalta: voices/MAESTRA.vox  # Shared file across all variants
  - character: NARRATOR
    voices:
      voxalta: voices/NARRATOR.vox

# Variant PROJECT.md (es-MX)
# Inherits MAESTRA and NARRATOR from master, but adds language-specific voice prompt
cast:
  - character: MAESTRA
    language: es-MX
    voicePrompt: "Native Spanish-Mexican teacher..."
    voices:
      voxalta: ../../voices/MAESTRA.vox  # Same file as master
  
  - character: NARRATOR
    language: en
    voicePrompt: "English narrator..."
    voices:
      voxalta: ../../voices/NARRATOR.vox
```

---

## Backward Compatibility (v3.x → v4.0.0)

### Migration Path

**Option 1: Implicit Migration** (ProjectFrontMatter auto-migration on read)

When reading a v3.x file without `schemaVersion`:

```swift
// Input (v3.x):
// season: 1
// episodes: 365

// Auto-migrated to v4 internal representation:
ProjectFrontMatter(
  schemaVersion: 3,  // Marked as v3 for compatibility
  seasons: [Season(number: 1, episodes: 365, ...)],
  // ...
)
```

**Option 2: Explicit Migration** (CLI command)

```bash
proyecto migrate --file PROJECT.md --target-version 4
```

Produces v4.0.0 output:

```yaml
schemaVersion: 4
seasons:
  - number: 1
    episodes: 365
```

### Reading v3.x in v4+ Code

```swift
// ProjectFrontMatter should expose both APIs:
let matter = try ProjectMarkdownParser.parse(...)

// New API (v4+):
let seasons = matter.seasons  // [Season]

// Legacy API (v3 compatibility):
let season = matter.season     // Int? (extracted from seasons[0].number)
let episodes = matter.episodes // Int? (extracted from seasons[0].episodes)
```

### Writing Behavior

- **v3.x projects**: Written back as v3.x (no migration unless explicit)
- **v4.0.0 projects**: Written with `schemaVersion: 4` and `seasons` array
- **Mixed reads**: No automatic upgrade on write (unless explicitly flagged)

---

## Directory Structure Recognition (v4.0.0)

**v4.0.0 Capability**: ProjectService can scan a directory and **recognize** the project structure (but not yet generate PROJECT.md files).

### Recognition Patterns

ProjectService should detect and describe:

**Pattern 1: Language-First Multi-Season**
```
episodes/
├── es/
│   ├── s1/episode_*.fountain
│   └── s2/episode_*.fountain
└── fr/
    ├── s1/episode_*.fountain
    └── s2/episode_*.fountain

Recognized as: "multi-language, multi-season, language-first"
Suitable schema: Master + variants (episode/es/s1/, episodes/fr/s1/, etc.)
```

**Pattern 2: Single-Language Multi-Season**
```
episodes/
├── season-1/episode_*.fountain
└── season-2/episode_*.fountain

Recognized as: "single-language, multi-season"
Suitable schema: Single-file v4 with seasons array
```

**Pattern 3: Language-Only (No Seasons)**
```
episodes/
├── es/episode_*.fountain
└── fr/episode_*.fountain

Recognized as: "multi-language, single-season"
Suitable schema: Master + variants (episodes/es/, episodes/fr/)
```

**Pattern 4: Flat**
```
episodes/episode_*.fountain

Recognized as: "single-language, single-season"
Suitable schema: Simple v3.x or flat v4 (single PROJECT.md)
```

### Recognition Implementation (v4.0.0)

```swift
struct ProjectStructure {
  let rootURL: URL
  let directoryMap: [String: [String]]  // language → seasons
  let filePatterns: [String]             // *.fountain, *.highland, etc.
  let audioDirectories: [String]
  let voiceFiles: [String]
  let recognizedPattern: RecognitionPattern
  
  enum RecognitionPattern {
    case languageFirstMultiSeason(languages: [String], seasons: [Int])
    case singleLanguageMultiSeason(seasons: [Int])
    case languageOnly(languages: [String])
    case flat
    case unknown
  }
}

// Usage
let structure = try projectService.scanAndRecognize(at: projectURL)
print("Detected pattern: \(structure.recognizedPattern)")
// Output: "multi-language, multi-season, language-first"
// → Ready for v4.1.0 LLM to generate optimal PROJECT.md
```

### Recognition Only (Not Generation)

v4.0.0 provides:
- ✅ Directory scanning
- ✅ Pattern recognition
- ✅ Structure analysis
- ❌ PROJECT.md generation (v4.1.0)
- ❌ LLM suggestions (v4.1.0)

v4.1.0 will:
- ✅ Take the recognized structure
- ✅ Pass it to FoundationModels/LLM
- ✅ Generate optimal PROJECT.md files
- ✅ Update existing PROJECT.md files to v4.0.0

---

## Implementation Plan

### Phase 1: Core Models & Lossless Cast Merging

**Priority**: Cast merging must be perfect before v4.0.0 ships

- [ ] Add `schemaVersion` field to `ProjectFrontMatter`
- [ ] Create `Season` struct with all fields (number, title, description, episodes, paths, intro/outro)
- [ ] Create `SeasonDefinition`, `LanguageDefinition`, `VariantReference` types
- [ ] Update `ProjectFrontMatter.init()` to accept `seasons`, `languages`, `variants` parameters
- [ ] Add `type` enum: `.project` vs `.overview` (OKF-aligned)
- [ ] Update `CodingKeys` enum to handle all new fields and `schemaVersion`
- [ ] Implement custom `encode(to:)` and `init(from:)` for dual v3/v4 support
- [ ] **CRITICAL: Enhance `CastMember` to safely store multiple voices per provider**
- [ ] **CRITICAL: Implement `CastMember.merge()` with lossless guarantees (50+ test cases)**
- [ ] **CRITICAL: Add `ProjectFrontMatter.mergeCast(_:_:strategy:)` for combining multiple cast lists**

### Phase 2: Multi-Version Read Support

- [ ] Implement version-agnostic decoder: accept v3.x and v4.0.0 (and future) in `init(from:)`
- [ ] Detect version during decoding; normalize to internal v4 representation
- [ ] Add convenience properties: `season` and `episodes` that map to `seasons[0]` (for v3 compatibility)
- [ ] Update `isValid` to accept all supported versions
- [ ] Implement v4.0.0 encoding only (always write latest version)
- [ ] Update `ProjectDiscovery` to skip master files (`type: overview`) when searching for projects
- [ ] Add version detection helpers to identify which version is being read

### Phase 3: Variant Resolution & Property Inheritance

- [ ] Create `VariantResolver` service for resolving variant files from a master
- [ ] Implement hierarchy-based property resolution: variant > season > master > default
- [ ] Add `ProjectFrontMatter.resolve(withMaster:forSeason:)` to resolve all properties
- [ ] Create helpers for path resolution in variant context (relative paths → absolute)
- [ ] Implement cast resolution for variants (unspecified characters inherit from parent)

### Phase 4: Discovery & Index Management

- [ ] Create `VariantIndexer` to scan master and find all referenced variants
- [ ] Add `ProjectDiscovery.findVariants(from:)` to discover all language/season variants
- [ ] Add `ProjectDiscovery.loadVariant(reference:)` to load a specific variant with inheritance
- [ ] Implement caching for variant indexes (avoid re-scanning)

### Phase 5: Path & Asset Resolvers

- [ ] Update `resolvedEpisodesDir` to handle variant-specific overrides (from hierarchy)
- [ ] Update `resolvedFilePatterns` to handle variant/season overrides
- [ ] Add `resolvedIntroFile` and `resolvedOutroFile` helpers (resolve relative paths)
- [ ] Create `IntroOutroAssets` struct to hold resolved intro/outro file paths and metadata
- [ ] Create `EpisodePathResolver` service to resolve `episodePath` templates
- [ ] Add `EpisodePathResolver.resolve(template:language:season:episode:ext:)` to instantiate paths
- [ ] Add `EpisodePathResolver.extractVariables(from:)` to parse template and validate variables

### Phase 6: CLI Updates

- [ ] Update `proyecto validate` to accept v3.x and v4.0.0 (both `type: project` and `type: overview`)
- [ ] Update `proyecto generate` to iterate over seasons and use hierarchy resolution
- [ ] Add `proyecto generate --season N` for single-season generation
- [ ] Add `proyecto generate --language <code>` for single-language variant generation
- [ ] Add `proyecto generate --intro-only` / `--outro-only` to generate intro/outro separately
- [ ] Add `proyecto variants` command to list all variants in a master file
- [ ] Update `proyecto generate --list` to show intro/outro files (if present)

### Phase 7: Testing & Documentation

- [ ] Add decoder/encoder tests for v3.x and v4.0.0 files
- [ ] Add decoder/encoder tests for master and variant files
- [ ] Add round-trip tests (read v3 → write v3, read v4 → write v4)
- [ ] Add variant resolution tests (master + variant inheritance)
- [ ] Add integration tests for `VariantResolver` and `VariantIndexer`
- [ ] Add tests for `resolvedIntroFile` and `resolvedOutroFile` path resolution
- [ ] Add tests for intro/outro validation (file existence warnings, path resolution)
- [ ] Add tests for `EpisodePathResolver` (template parsing, variable substitution)
- [ ] Add tests for all `episodePath` template patterns (language-first, season-first, flat, single-language)
- [ ] Add tests for invalid template variables (should warn, not error)
- [ ] Add type validation tests: only `"project"` or `"overview"` allowed
- [ ] Add tests for type-specific behavior (overview must have variants, project can have masterPath)
- [ ] Update `PROJECT_MD_REFERENCE.md` with v4 schema (including intro/outro fields)
- [ ] Add migration guide for v3.x users
- [ ] Update `EXAMPLE_PROJECT.md` to v4 format (both single-file and master/variant examples)
- [ ] Add **Variant Reference Guide** with best practices for master/variant patterns
- [ ] Add **Intro/Outro Guide**: usage patterns, file organization, generation strategies
- [ ] Add **Episode Path Template Guide**: common patterns, how to design templates for your project
- [ ] Document INDEX.md + SUBDOC.md pattern in integration guide
- [ ] Add guidelines for adopting Google Open Knowledge Format alignment
- [ ] Create example master/variant project structure in docs/ (with episodePath examples)

### Phase 8: Directory Structure Recognition (v4.0.0 Foundation for v4.1.0)

**Purpose**: Scan and recognize project structure so v4.1.0 LLM can generate PROJECT.md files

- [ ] Create `ProjectStructure` model (directory map, file patterns, recognized pattern)
- [ ] Add `ProjectService.scanAndRecognize(at:)` to analyze directory recursively
- [ ] Implement pattern detection:
  - Language-first multi-season (e.g., `episodes/es/s1/`, `episodes/fr/s2/`)
  - Single-language multi-season (e.g., `episodes/season-1/`, `episodes/season-2/`)
  - Language-only (e.g., `episodes/es/`, `episodes/fr/`)
  - Flat structure (e.g., `episodes/episode_*.fountain`)
  - Unknown/ambiguous patterns
- [ ] Detect file types and counts (`*.fountain`, `*.highland`, `*.fdx`)
- [ ] Locate voice files (`voices/`, `audio/` directories)
- [ ] Generate `ProjectStructure` report (pattern, directories, files)
- [ ] Add tests for each pattern type (lingua-matra style, screenplay style, mixed)

**Output for v4.1.0**: Recognition data that LLM uses to generate optimal PROJECT.md

---

## Example Files

### v4.0.0 Single-File: Minimal Single Season

```yaml
---
schemaVersion: 4
type: project
title: "My Series"
author: "John Doe"
created: 2026-01-15T10:30:00Z
seasons:
  - number: 1
    episodes: 12
---
```

### v4.0.0 Single-File: Multi-Season (All in One File)

```yaml
---
schemaVersion: 4
type: project
title: "The Complete Chronicles"
author: "Jane Showrunner"
created: 2024-06-01T00:00:00Z
description: "A five-season epic spanning 50 episodes"
genre: Science Fiction
tags: [sci-fi, drama, space]

seasons:
  - number: 1
    title: "The Beginning"
    episodes: 10
    releaseDate: 2024-06-01T00:00:00Z
    episodesDir: episodes/season-1
    introFile: intro.fountain
    outroFile: outro.fountain
  
  - number: 2
    title: "Escalation"
    episodes: 12
    releaseDate: 2025-06-01T00:00:00Z
    episodesDir: episodes/season-2
    introFile: intro.fountain
    outroFile: outro.fountain
    cast:
      - character: PROTAGONIST
        voices:
          apple: com.apple.voice.compact.en-US.Aaron
  
  - number: 3
    title: "Revelation"
    episodes: 10
    releaseDate: 2026-06-01T00:00:00Z
    episodesDir: episodes/season-3
    introFile: intro.fountain
    outroFile: outro.fountain

audioDir: audio
exportFormat: m4a

cast:
  - character: PROTAGONIST
    actor: Alex Turner
    gender: M
    voices:
      apple: com.apple.voice.compact.en-US.Aaron
  
  - character: ANTAGONIST
    actor: Sam Rivers
    gender: F
    voices:
      apple: com.apple.voice.compact.en-US.Samantha
---
```

### v4.0.0 Master + Variants: Multi-Language

**Master PROJECT.md** (project root):

```yaml
---
schemaVersion: 4
type: overview
title: "Lingua Matra — Multi-Language Index"
author: Tom Stovall
created: 2026-01-01T00:00:00Z
description: "Learn languages one verb tense at a time"
genre: Education
tags: [podcast, language-learning, multilingual]

# Episode path template: language first, then season
episodePath: "episodes/<language>/s<season>/<episode>.<ext>"

# Single season for this example
seasons:
  - number: 1
    title: "Beginner Level"

languages:
  - code: es
    name: "Español"
    locale: es-MX
  - code: fr
    name: "Français"
    locale: fr-FR
  - code: it
    name: "Italiano"
    locale: it-IT

# All language/season combinations point to variant files
# Organization: language first, then season
variants:
  - language: es
    season: 1
    path: episodes/es/s1/PROJECT.md
    status: published
  
  - language: fr
    season: 1
    path: episodes/fr/s1/PROJECT.md
    status: published
  
  - language: it
    season: 1
    path: episodes/it/s1/PROJECT.md
    status: published

# Shared cast (inherited by all variants)
cast:
  - character: MAESTRA
    voicePrompt: "Patient language teacher, clear articulation"
    voices:
      voxalta: voices/MAESTRA.vox
  
  - character: NARRATOR
    voicePrompt: "English narrator for intros/outros"
    voices:
      voxalta: voices/NARRATOR.vox

tts:
  provider: voxalta
  model: "1.7b"

---

# Lingua Matra Family Overview

## About This Project

One show, five languages. Each language drills the same 50 core verbs and nouns in the same order...

```

**Variant PROJECT.md** (`episodes/es/s1/PROJECT.md`):

```yaml
---
schemaVersion: 4
type: project
title: "Lingua Matra — Español"
author: Tom Stovall
created: 2026-01-01T00:00:00Z

# Variant membership (language/season path structure)
masterPath: "../../../PROJECT.md"
season: 1
language: es-MX

description: "Learn Spanish one verb tense at a time"
episodes: 110
genre: Education
tags: [spanish, language-learning, vocabulary]

# Variant-specific paths (one level deeper: language/season/)
episodesDir: "."
audioDir: "../../../audio/es/s1"
filePattern: ["*.fountain", "*.highland"]
exportFormat: m4a

# Optional intro/outro files (project-resolved: relative to the project root)
introFile: episodes/intro.fountain
outroFile: episodes/outro.fountain

# Variant cast (overrides master's prompts with language-specific guidance)
cast:
  - character: MAESTRA
    language: es-MX
    voicePrompt: "Voz de profesor mexicano, clara y paciente"
    voices:
      voxalta: ../../../voices/MAESTRA.vox
  
  - character: NARRATOR
    language: en
    voicePrompt: "English narrator for intros/outros"
    voices:
      voxalta: ../../../voices/NARRATOR.vox

tts:
  provider: voxalta
  model: "1.7b"

episodes_index:
  - number: 1
    title: "Present Tense, Level 1"
    summary: "Simple present-tense sentences"
  - number: 2
    title: "Present Tense, Level 2"
    summary: "Compound present-tense sentences"
  # ... 110 episodes total

---

# Española — Gramática del Presente

Learn Spanish by drilling the 50 core verbs in present tense...
```

### v4.0.0 Master + Variants: Multi-Season, Multi-Language

**Master PROJECT.md** (for a project with 2 seasons × 3 languages):

```yaml
---
schemaVersion: 4
type: overview
title: "Global Language Podcast"
author: Tom Stovall
created: 2026-01-01T00:00:00Z

# Episode path template: language first, then season
episodePath: "episodes/<language>/s<season>/episode_<episode>.<ext>"

seasons:
  - number: 1
    title: "Beginner"
  - number: 2
    title: "Intermediate"

languages:
  - code: es
    name: "Español"
    locale: es-MX
  - code: fr
    name: "Français"
    locale: fr-FR

variants:
  # Spanish variants (both seasons)
  - language: es
    season: 1
    path: episodes/es/s1/PROJECT.md
  - language: es
    season: 2
    path: episodes/es/s2/PROJECT.md
  
  # French variants (both seasons)
  - language: fr
    season: 1
    path: episodes/fr/s1/PROJECT.md
  - language: fr
    season: 2
    path: episodes/fr/s2/PROJECT.md

cast:
  - character: TEACHER
    voices:
      voxalta: voices/TEACHER.vox

---
```

**Variant structure** (language first, season second):
```
episodes/
├── es/
│   ├── s1/PROJECT.md (language: es, season: 1)
│   └── s2/PROJECT.md (language: es, season: 2)
└── fr/
    ├── s1/PROJECT.md (language: fr, season: 1)
    └── s2/PROJECT.md (language: fr, season: 2)
```

### v3.x Compatibility (Still Supported in v4+ Parser)

```yaml
---
type: project
title: "Podcast Meditations"
author: "Tom Stovall"
created: 2025-01-25T00:00:00Z
season: 1
episodes: 365
genre: Documentary
---
```

When read by v4+ parser, internally migrates to:

```swift
ProjectFrontMatter(
  schemaVersion: 3,
  seasons: [Season(number: 1, episodes: 365)],
  // ...
)
```

---

## Breaking Changes & Deprecations

### Breaking Changes (v4.0.0)

1. **`season` and `episodes` fields deprecated**: Replaced by `seasons` array
   - Old code using `matter.season` and `matter.episodes` continues to work via computed properties
   - New code should use `matter.seasons`

2. **Generation CLI interface changes**:
   - `proyecto generate --season 1 --episodes 365` → `proyecto generate --season 1`
   - Episode count now read from season definition, not CLI

### Deprecation Timeline

- **v4.0.0 - v4.x**: Dual-mode support (v3 legacy API + v4 new API)
- **v5.0.0+**: v3.x format support may be removed (TBD)

---

## Validation Rules (v4.0.0)

### Required Validations

- [ ] `schemaVersion` must be 4 if present; if absent, treat as v3.x
- [ ] `type` must be exactly `"project"` or `"overview"` (case-sensitive, OKF-aligned)
- [ ] If `type: overview`: must have `variants` array (even if empty); cannot have `episodesDir`
- [ ] If `type: project`: optional `masterPath` field; if present, can have `season` and `language` (variant metadata)
- [ ] `title` and `author` required
- [ ] If `seasons` present: each season must have `number` and `episodes`
- [ ] Season numbers must be unique within project
- [ ] Episode counts must be positive integers
- [ ] `episodesDir` and file patterns must be relative paths (no leading `/` or `~`)
- [ ] `introFile` and `outroFile` must be relative paths (if specified)

### Optional Validations

- [ ] Warn if both `season`/`episodes` (v3) AND `seasons` (v4) present (ambiguous intent)
- [ ] Warn if `season`/`episodes` without `schemaVersion: 3` (implicit v3.x)
- [ ] Validate date formats (ISO 8601)
- [ ] Warn if `introFile`/`outroFile` reference files that don't exist (soft warning, not error)
- [ ] For variants: validate that `introFile`/`outroFile` paths resolve relative to the project root (project-resolved)
- [ ] Warn if `episodePath` template contains invalid variables (only `<language>`, `<season>`, `<episode>`, `<ext>` allowed)
- [ ] For variants: verify that variant's file organization aligns with master's `episodePath` template

---

## Testing Strategy

### Unit Tests

- [ ] Decoder: v3.x YAML → ProjectFrontMatter
- [ ] Decoder: v4.0.0 YAML → ProjectFrontMatter
- [ ] Encoder: ProjectFrontMatter → YAML (preserves original schema version)
- [ ] Round-trip: Read v3 → write v3, verify bit-for-bit equality
- [ ] Round-trip: Read v4 → write v4, verify equality
- [ ] Migration: Read v3 → extract `season`/`episodes` via computed properties
- [ ] Override resolution: Season-level `cast` overrides global `cast`

### Integration Tests

- [ ] `proyecto validate` accepts v4.0.0 files
- [ ] `proyecto validate` rejects malformed v4 (e.g., duplicate season numbers)
- [ ] `proyecto migrate` converts v3.x → v4.0.0
- [ ] `proyecto generate --season 2` generates only season 2
- [ ] `proyecto generate` (no --season) generates all seasons

### Regression Tests

- [ ] Existing v3.x projects parse and generate identically
- [ ] Apps consuming ProjectFrontMatter via v3 API (season/episodes) still work
- [ ] Cast merging (`mergingCast()`) works with season-specific cast

---

## Documentation Updates

### In-Tree Docs

- [ ] **AGENTS.md**: Add v4.0.0 release notes and breaking changes section
- [ ] **PROJECT_MD_REFERENCE.md**: Document v4 schema, deprecations, migration
- [ ] **EXAMPLE_PROJECT.md**: Upgrade to v4.0.0, add comment explaining schema version
- [ ] **INTEGRATION_GUIDE.md**: Add section on reading multi-season projects
- [ ] **CLAUDE.md (project)**: Document breaking change and upgrade path

### External Docs (if applicable)

- [ ] GitHub Release notes for v4.0.0
- [ ] Blog post or announcement (if marketing-relevant)

---

## Alignment with Industry Standards

### Google Open Knowledge Format

SwiftProyecto v4.0.0 aligns with [Google's Open Knowledge Format](https://developers.google.com/knowledge-format) principles:

1. **Document Type Classification**: `type` field (project | overview) classifies documents as Entity or Collection, matching OKF standards
2. **Structured Metadata**: Front matter (YAML) separates machine-readable metadata from human-readable content
3. **Hierarchical Organization**: Master/variant pattern mirrors index → subdocument relationships in knowledge graphs
4. **Property Inheritance**: Variant-inherits-from-master pattern matches Google's entity-property resolution
5. **Extensibility**: App-specific settings (v2.6.0+) support custom namespaced fields
6. **Content + Metadata**: PROJECT.md keeps documentation alongside metadata (not separate files)
7. **Entity Resolution**: Property hierarchy (variant > season > master > default) mirrors OKF's entity resolver

**Specifics**:
- **`schemaVersion`** → OKF version pinning
- **`type: project`** → OKF Entity document
- **`type: overview`** → OKF Collection/Index document
- **Property inheritance** → OKF's default-resolution chain
- **Cast, TTS, metadata** → OKF properties on entities

**No breaking alignment required** — our schema is already compatible with knowledge format expectations. This effort formalizes the pattern and makes it discoverable by OKF tools.

### INDEX.md + SUBDOC.md Pattern

SwiftProyecto projects can adopt a two-tier documentation pattern:

**Tier 1: Project-level INDEX.md**
- Entry point for the project
- Links to all seasons and languages
- Shared methodology, cast, and production notes
- Mirrors `type: overview` PROJECT.md structure

**Tier 2: Variant-level SUBDOC.md** (e.g., `episodes/es/s1/DOCS.md`)
- Language/season-specific documentation
- Episode guides, vocabulary lists, pronunciation notes
- Linked from variant's PROJECT.md
- Complements the variant's PROJECT.md metadata

**Implementation pattern** (language first, season second):

```
project/
├── INDEX.md                    # Project overview, links to variants
├── PROJECT.md                  # Master PROJECT.md (type: overview)
├── episodes/
│   ├── es/
│   │   ├── s1/
│   │   │   ├── PROJECT.md     # Spanish, Season 1 variant
│   │   │   ├── DOCS.md        # S1 Spanish docs (optional)
│   │   │   └── episode_*.fountain
│   │   ├── s2/
│   │   │   ├── PROJECT.md     # Spanish, Season 2 variant
│   │   │   ├── DOCS.md        # S2 Spanish docs (optional)
│   │   │   └── episode_*.fountain
│   │   └── ...
│   ├── fr/
│   │   ├── s1/
│   │   │   ├── PROJECT.md
│   │   │   ├── DOCS.md
│   │   │   └── episode_*.fountain
│   │   └── ...
│   └── ...
└── AGENTS.md                  # Development methodology
```

**Why this pattern**:
- **Discoverable**: INDEX.md is the human-readable entry point
- **Hierarchical**: Docs mirror the season/language structure
- **Self-contained**: Each variant has its own documentation
- **Crawlable**: Search engines and knowledge graph builders can traverse the hierarchy

---

## Best Practices: Master + Variant Pattern

### When to Use Master + Variants

**Use master + variants when**:
- Project has **multiple languages** (lingua-matra pattern)
- Each language/season has **distinct file locations** (separate `episodesDir`, `audioDir`)
- You want **centralized management** of shared properties (cast, TTS config)
- Generation happens **per-variant** (e.g., `proyecto generate --language es`)

**Use single-file v4 when**:
- Project is **single-language** or all content is in one directory
- Seasons are **organizational only** (not reflected in file paths)
- You want **all metadata in one file** for portability

### Episode Path Template (The "Blueprint" Pattern)

The `episodePath` template documents and enforces the project's episode organization. It's especially powerful for multi-language, multi-season projects:

**Example usage**:

```yaml
# Master declares the structure once
episodePath: "episodes/<language>/<season>/<episode>.<ext>"

# Tools can now:
# 1. Discover where Spanish season 2 episode 5 lives:
#    episodes/es/2/episode_5.fountain
# 
# 2. Validate that variants follow the pattern
# 
# 3. Generate episode lists from discovery (no manual indexing)
# 
# 4. Help agents understand project structure at a glance
```

**Benefits**:
- **Self-documenting**: Anyone reading the PROJECT.md understands the file layout
- **Consistent**: All variants follow the same organization
- **Discoverable**: Tools can find episodes programmatically
- **Flexible**: Different projects can use different structures (language-first vs season-first)

### Intro/Outro Audio Files

Intro and outro files are optional separate script files that are generated as distinct audio assets:

```yaml
# In variant PROJECT.md
introFile: episodes/intro.fountain    # Generates audio/es/s1/intro.m4a
outroFile: episodes/outro.fountain    # Generates audio/es/s1/outro.m4a
filePattern: episode_*.fountain  # Regular episodes: episode_1.m4a, episode_2.m4a, ...
```

**File locations**:
- `introFile`/`outroFile` paths are project-resolved: relative to the project root (the PROJECT.md location), NOT relative to `episodesDir`
- Generated audio placed in `audioDir` with same filename (but in target format, e.g., `.m4a`)
- Separate from episode generation (apps can choose when/how to combine)

**Use cases**:
- **Branding**: Shared intro/outro across all episodes in a season
- **Credits**: Language-specific credits or production notes
- **Localized intros**: Different intro per language (same episode, different intro)
- **Optional sections**: Generate but don't combine by default (leave combining to post-production)

**Example from lingua-matra**:
```
episodes/es/s1/
├── intro.fountain         # "Welcome to Spanish 101" (in English)
├── outro.fountain         # "Credits and resources" (in English)
├── episode_01.fountain
├── episode_02.fountain
└── ...

audio/es/s1/
├── intro.m4a             # Generated from intro.fountain
├── outro.m4a             # Generated from outro.fountain
├── episode_01.m4a
├── episode_02.m4a
└── ...
```

### Shared Voice Files (The "MAESTRA" Pattern)

Lingua Matra uses a single `voices/MAESTRA.vox` file across all language variants. Each variant references it with a relative path:

```yaml
# Master
cast:
  - character: MAESTRA
    voices:
      voxalta: voices/MAESTRA.vox

# Variant (episodes/es/PROJECT.md)
cast:
  - character: MAESTRA
    language: es-MX
    voicePrompt: "Spanish teacher..."
    voices:
      voxalta: ../../voices/MAESTRA.vox  # Same file as master
```

**Benefits**:
- One voice file supports multiple languages (via language embeddings in vox format v0.4.0+)
- Reduces storage and maintenance
- Central place to update a character's voice across all languages

### Property Override Patterns

**Pattern 1: Global cast + language-specific prompts**
- Master defines cast character list
- Variant adds `language` field and `voicePrompt` specific to that language

**Pattern 2: Global TTS config + language-specific model**
- Master specifies default TTS provider
- Variant overrides `tts.model` for language-specific tuning

**Pattern 3: Global hooks + variant-specific hooks**
- Master defines `preGenerateHook` (validation, common setup)
- Variant chains with its own pre-generate step (language-specific preprocessing)

### File Path Strategy

**Relative paths in variants**:
- `episodesDir: "."` — Content is in the same directory as PROJECT.md
- `audioDir: "../../audio/es"` — Audio output relative to PROJECT.md location
- `voices:` references use `../../voices/SHARED.vox` to reach shared files

**Why not absolute paths**:
- Keeps projects portable (can move to different base directory)
- Variants are self-contained but reference shared resources relatively

### Cross-Language Operations (The `/loop` Pattern)

When updating all language variants, use `/loop` in self-paced mode:

```
/loop Update episode 5 in current language variant
```

On each iteration:
1. Load the next language's PROJECT.md (via master index)
2. Perform the operation (edit script, regenerate audio)
3. Validate the result
4. Advance to the next language

This keeps context clean, makes work resumable, and validates incrementally — especially important for audio generation.

---

## Resolved Decisions

### ✅ Migration Strategy
**Decided**: Read any version, always write latest
- Read v3.x, v4.0.0, future versions without modification
- Always export/save as v4.0.0 (latest)
- Graceful degradation: software understands what's available in each version
- No explicit migration command needed

### ✅ Property Resolution & Cast Merging
**Decided**: File hierarchy determines priority (variant > season > master > default)
- Deeper/more-specific files override shallower/general ones
- Cast merging: variant cast overrides season cast overrides master cast
- Unspecified characters inherit from parent level
- All properties follow the same hierarchy (not special cases)

---

## Open Questions & Decisions

### Decision: Implicit vs. Explicit Migration (v3.x → v4.0.0)

**Status**: ✅ **RESOLVED**

**Approach: Read Any Version, Write Latest**

- **Read**: Accept all versions (v3.x, v4.0.0, future) — software understands what it can from each
- **Write**: Always export as latest version (v4.0.0)
- **Graceful degradation**: If v3.x file lacks v4 fields (e.g., `seasons`, `language`), software works with what's available
- **Forward-compatible**: As PROJECT.md evolves, new fields are additive — existing parsers don't break

**Implementation**:
```swift
// Read: decoder handles all versions
let matter = try ProjectMarkdownParser.parse(data)
// Internally: detects schemaVersion, migrates to internal model if needed

// Write: always latest
let yaml = try ProjectMarkdownParser.encode(matter, schemaVersion: 4)
```

**Benefits**:
- v3.x files continue working without migration
- Gradual adoption of v4 features (projects upgrade when ready)
- No explicit migration command needed (but CLI can still support one for validation)
- Future versions handled the same way

### Decision: Season Object Nesting

**Status**: TBD

**Options**:
1. **Flat seasons array** (current proposal): `seasons: [{number: 1, ...}, {number: 2, ...}]`
2. **Nested by season number**: `seasons: { "1": {...}, "2": {...} }`

**Recommendation**: Flat array preserves order, easier to iterate

### Decision: File Pattern Behavior (Single-File Mode)

**Status**: TBD

**Options**:
1. **Season `episodesDir` + Season `filePattern`**: Most granular, most flexibility
2. **Season `episodesDir` only, share global `filePattern`**: Simpler, still powerful
3. **Auto-glob per season**: `episodes/season-*/` pattern, no explicit override needed

**Recommendation**: Option 1 (season-level override) for maximum flexibility

### Decision: Cast Merging & Property Resolution Hierarchy

**Status**: ✅ **RESOLVED**

**Approach: Hierarchy-Based Override (File Path Determines Priority)**

Cast (and all properties) resolve by **file hierarchy level**, not by field count:

**Resolution Order** (highest to lowest priority):
1. **Variant PROJECT.md** (`episodes/<lang>/<season>/PROJECT.md`) — lowest level, most specific
2. **Season definition** (in master's `seasons:` array) — medium level
3. **Master PROJECT.md** (root `type: overview`) — highest level, most general
4. **Hardcoded default** — fallback

**Example: Cast Resolution**
```yaml
# Master (lowest priority)
cast:
  - character: NARRATOR
    voices: {apple: narrator-voice-1}
  - character: MAESTRA
    voices: {apple: maestra-voice-1}

# Master season definition (overrides some)
seasons:
  - number: 2
    cast:
      - character: NARRATOR
        voices: {apple: narrator-voice-2}  # Overrides master

# Variant (highest priority, wins)
cast:
  - character: NARRATOR
    voices: {apple: narrator-voice-3}  # Wins!
  # MAESTRA inherits from season, which inherits from master
```

**Resolution result for Variant at season 2**:
- **NARRATOR**: `narrator-voice-3` (from variant)
- **MAESTRA**: `maestra-voice-1` (from master, since variant doesn't override)

**Not a merge operation**: Variant completely replaces parent if specified. Unspecified characters inherit from parent.

**Implementation**:
```swift
// Resolver follows the file hierarchy
let resolved = projectFrontMatter
  .resolve(withMaster: masterMatter, forSeason: 2)
  
// Result: variant cast + inherited cast from master/season
```

**Why this approach**:
- Predictable: file path determines priority
- Explicit: no "magic merging" behavior
- Intuitive: deeper/more-specific files override shallower/general ones
- Works for all properties (not just cast)

### Decision: Master ← → Variant Sync

**Status**: TBD

**Question**: If the master's cast changes (e.g., new voice ID for MAESTRA), should:
- A) Variants automatically inherit the change on next read (transparent, but surprises)?
- B) Variants are independent once written (requires manual sync, but explicit)?
- C) Provide a `proyecto sync-variants` command to explicitly update all variants from master?

**Recommendation**: Option B + C — variants are independent, explicit sync command available

### Decision: Variant `masterPath` Required vs. Optional

**Status**: TBD

**Question**: Is `masterPath` in variants:
- A) **Required**: Variants always point back to master (enforces hierarchy, aids discovery)?
- B) **Optional**: Variants can stand alone (decouples from master, increases flexibility)?
- C) **Inferred**: Discovery service infers master from directory structure?

**Recommendation**: Optional with inference — variants work standalone, but discovery can find masters

### Decision: VariantReference Path Format

**Status**: TBD

**Question**: In master's `variants` array, should path be:
- A) **Relative to master**: `path: episodes/es/PROJECT.md` (portable, standard)
- B) **Absolute**: `path: /Users/tom/projects/lingua/episodes/es/PROJECT.md` (explicit, but fragile)
- C) **URL-style**: `path: file://episodes/es/PROJECT.md` (consistent with URI schemes)?

**Recommendation**: Option A (relative paths) — portable and follows web standards

### Decision: `episodePath` Optional vs. Required

**Status**: TBD

**Question**: Should `episodePath` be:
- A) **Required in master**: Forces explicit documentation of project structure
- B) **Optional**: Only when project wants to use discovery/resolution features
- C) **Inferred**: Auto-generate from variants if not specified (implicit)?

**Recommendation**: Optional with inference — variants can be used standalone, but `episodePath` enables powerful discovery when provided

### Decision: `episodePath` Per-Season Overrides

**Status**: TBD

**Question**: Should season definitions allow `episodePath` overrides?
- A) **No**: Use master's `episodePath` for all seasons (enforces consistency)
- B) **Yes, optional**: Seasons can override if structure changes mid-project
- C) **Yes, required**: Each season declares its own path pattern

**Recommendation**: Option A — keep global, one pattern for entire project. If structure changes, that's a major refactor, not a per-season override

### Decision: Future Type Values

**Status**: TBD

**Question**: Should we reserve other `type` values for future content structures?
- A) **No**: Only `project` and `overview` for now; other types added when needed
- B) **Yes**: Define extended types like `collection`, `index`, `bundle` (future-proofing)
- C) **Registry**: Maintain a registry of allowed types (OKF-like)

**Recommendation**: Option A for v4.0 — keep simple. If future content models emerge (bundles, collections), add them as breaking changes in v5+

---

## Related Efforts

### v4.0.0 (This Effort)
- [ ] [[CastMember Language Support]] - Per-character language variant in voice selection
- [ ] [[Voice Prompt Customization]] - Per-character, per-language prompt tuning
- [ ] [[Cast Merging]] - Lossless merge from multiple PROJECT.md files (CRITICAL)

### v4.1.0 (Next Release — Auto-Generation)
- [ ] [[Project Structure Recognition]] - Detect language-first, season-first patterns
- [ ] [[LLM-Based PROJECT.md Generation]] - Use FoundationModels to generate optimal schema
- [ ] [[Schema Version Migration]] - Auto-migrate v3.x → v4.0.0 using LLM analysis

---

## Timeline & Milestones

| Milestone | Target Date | Notes |
|-----------|-------------|-------|
| Requirements finalization | 2026-06-30 | Stakeholder sign-off on schema |
| Phase 1-2 implementation | 2026-07-15 | Core models + backward compat |
| Phase 3-4 implementation | 2026-08-15 | Resolvers + CLI updates |
| Phase 5 testing & docs | 2026-08-31 | Full test coverage + docs |
| v4.0.0 RC release | 2026-09-15 | Release candidate for feedback |
| v4.0.0 stable | 2026-09-30 | Final release |

---

## References

- **Current Schema**: [PROJECT_MD_REFERENCE.md](../Docs/PROJECT_MD_REFERENCE.md)
- **Example File**: [EXAMPLE_PROJECT.md](../EXAMPLE_PROJECT.md)
- **Integration Guide**: [INTEGRATION_GUIDE.md](../Docs/INTEGRATION_GUIDE.md)
- **Code**: [ProjectFrontMatter.swift](../Sources/SwiftProyecto/Models/ProjectFrontMatter.swift)

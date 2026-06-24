---
type: reference
name: PROJECT.md Front Matter Schema Reference — v4.0.0
description: Comprehensive reference for YAML front matter syntax in PROJECT.md files (v4.0.0)
updated: 2026-06-23
---

# PROJECT.md Front Matter Schema Reference — v4.0.0

Comprehensive reference for the YAML front matter syntax used in PROJECT.md files, including v4.0.0 multi-season and multi-language support.

**See Also**: 
- [AGENTS.md](../AGENTS.md) for comprehensive library documentation
- [EXAMPLE_PROJECT_v4.md](EXAMPLE_PROJECT_v4.md) for working examples
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for upgrading from v3.x
- [VARIANT_REFERENCE.md](VARIANT_REFERENCE.md) for variant patterns

---

## Structure

PROJECT.md files consist of two parts:

```markdown
---
# YAML Front Matter (metadata)
schemaVersion: 4
type: project
title: "..."
author: "..."
seasons:
  - number: 1
    episodes: 10
    ...
---

# Markdown Body
# Project Description

Content below the front matter separator...
```

The front matter is delimited by `---` markers and contains YAML key-value pairs.

---

## Front Matter Fields — v4.0.0

### Schema Versioning

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schemaVersion` | Integer | Optional* | Schema version (`4` for v4.0.0, omit for v3.x compatibility) |

*If omitted, SwiftProyecto auto-detects v3.x format and migrates internally. Recommended: always explicit in new files.

### Core Metadata (Required)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | String | ✅ Yes | File type: `"project"` (single project or variant) or `"overview"` (master index) |
| `title` | String | ✅ Yes | Project title (e.g., "Podcast Meditations") |
| `author` | String | ✅ Yes | Project creator/author name |
| `created` | ISO 8601 Timestamp | ✅ Yes | Project creation date (e.g., `2025-01-25T00:00:00Z`) |

### Project Metadata (Optional)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `description` | String | — | Long-form project description (2-3 sentences) |
| `genre` | String | — | Content genre (e.g., "Documentary", "Screenplay", "Podcast") |
| `tags` | Array of Strings | — | Project tags (e.g., `[mindfulness, self-care, meditation]`) |

### Season Definitions (Optional, v4.0.0+)

Multi-season projects use the `seasons` array to define per-season metadata:

```yaml
seasons:
  - number: 1
    title: "Year One"
    description: "Books I-IV of Meditations"
    episodes: 365
    releaseDate: 2025-01-25T00:00:00Z
    episodesDir: episodes/season-1
    filePattern: "*.fountain"
    introFile: intro.md
    outroFile: outro.md
    cast: [...]  # Optional: override master cast for this season
    tts: {...}   # Optional: override master TTS config for this season
```

**Season Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `number` | Integer | ✅ Yes | Season number (unique per project) |
| `title` | String | — | Season title (e.g., "Year One", "Act I") |
| `description` | String | — | Season summary |
| `episodes` | Integer | ✅ Yes | Episode count for this season |
| `releaseDate` | ISO 8601 Timestamp | — | Season release date |
| `episodesDir` | String | — | Directory containing this season's episode files (relative to project root) |
| `filePattern` | String or Array | — | Glob pattern(s) matching episode files (e.g., `"*.fountain"` or `["*.fountain", "*.md"]`) |
| `introFile` | String | — | Path to season intro file (relative to project root) |
| `outroFile` | String | — | Path to season outro file (relative to project root) |
| `cast` | Array | — | Season-specific cast (overrides master for this season) |
| `tts` | Object | — | Season-specific TTS config (overrides master for this season) |

### Language Definitions (Optional, v4.0.0+)

Multi-language projects use the `languages` array to define supported languages:

```yaml
languages:
  - code: en
    name: English
    locale: en-US
  - code: es
    name: Español
    locale: es-MX
```

**Language Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `code` | String | ✅ Yes | Language code (e.g., "en", "es", "fr") |
| `name` | String | ✅ Yes | Language name (e.g., "English", "Español") |
| `locale` | String | — | IETF locale tag (e.g., "en-US", "es-MX") |

### Variant References (Optional, v4.0.0+)

Master files use `variants` to reference variant PROJECT.md files:

```yaml
variants:
  - season: 1
    language: es
    path: episodes/season-1/PROJECT_es.md
    status: published
  - season: 1
    language: fr
    path: episodes/season-1/PROJECT_fr.md
    status: in_progress
```

**Variant Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `season` | Integer | ✅ Yes | Season number this variant covers |
| `language` | String | ✅ Yes | Language code (must match a `languages[]` entry) |
| `path` | String | ✅ Yes | Relative path to variant PROJECT.md file |
| `status` | String | — | Variant status: `published`, `in_progress`, `draft`, `obsolete` |

### Path Template (Optional, v4.0.0+)

Single files supporting multi-language episodes use `episodePath` to template episode file paths:

```yaml
episodePath: "episodes/season-{season}/episode-{number:03d}.{language}.fountain"
```

**Template Variables:**
- `{season}` — Season number from context
- `{number}` — Episode number (0-padded if specified: `{number:03d}`)
- `{language}` — Language code (e.g., "en", "es")

**Example Resolution:**
- Template: `"episodes/season-{season}/episode-{number:03d}.{language}.fountain"`
- Season 1, Episode 3, Language "en" → `"episodes/season-1/episode-003.en.fountain"`
- Season 2, Episode 15, Language "es" → `"episodes/season-2/episode-015.es.fountain"`

### Generation Config (Optional)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `episodesDir` | String | `"episodes"` | Default directory containing episode files (overridden by `seasons[].episodesDir` if present) |
| `audioDir` | String | `"audio"` | Output directory for generated audio |
| `filePattern` | String or Array | `"*.fountain"` | Default glob pattern(s) to match episodes (overridden by `seasons[].filePattern` if present) |
| `exportFormat` | String | `"m4a"` | Audio export format (e.g., `"m4a"`, `"mp3"`, `"wav"`) |

### Text Directions (Optional, v4.0.0+)

| Field | Type | Description |
|-------|------|-------------|
| `introFile` | String | Path to project-wide intro file (overridden by `seasons[].introFile`) |
| `outroFile` | String | Path to project-wide outro file (overridden by `seasons[].outroFile`) |

### Workflow Hooks (Optional)

| Field | Type | Description |
|-------|------|-------------|
| `preGenerateHook` | String | Shell command to run before generation |
| `postGenerateHook` | String | Shell command to run after generation |

### Text-to-Speech Config (Optional)

| Field | Type | Description |
|-------|------|-------------|
| `tts` | Object | TTS provider configuration |

**TTS Object Fields:**

```yaml
tts:
  provider: apple          # TTS provider: "apple", "elevenlabs", "voxalta"
  voiceLanguage: en-US     # Language for voice selection (e.g., "en-US", "es-MX")
  actionLineVoice: null    # Optional: separate voice for action/stage directions
```

### Cast List (Optional)

| Field | Type | Description |
|-------|------|-------------|
| `cast` | Array | Array of [CastMember](#castmember-structure) objects |

---

## CastMember Structure

Each entry in the `cast` array is a character-to-voice mapping:

```yaml
cast:
  - character: MARCUS AURELIUS
    actor: Tom Stovall
    gender: M
    language: en-US
    voiceDescription: Deep, warm baritone with measured pacing
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
        - com.apple.voice.compact.en-US.Moira  # Multiple voices per provider (v4.0+)
      elevenlabs:
        - 21m00Tcm4TlvDq8ikWAM
      voxalta:
        - male-voice-1
```

### CastMember Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `character` | String | ✅ Yes | Character name (screenplay role) |
| `actor` | String | — | Actor/performer name |
| `gender` | String | — | Gender specification: `M` (Male), `F` (Female), `NB` (Non-Binary), `NS` (Not Specified) |
| `language` | String | — | Language code for this character variant (e.g., "en-US", "es-MX") |
| `voiceDescription` | String | — | Descriptive guidance for voice selection (e.g., "warm baritone", "youthful female") |
| `voices` | Object | — | Provider-keyed mapping of voice identifiers (v4.0+: provider values are arrays, supporting multiple voices per provider) |

### Voice Providers

The `voices` object uses provider names as keys. In v4.0.0, provider values are **arrays** to support multiple voices:

| Provider | Key | Example Voice IDs | Notes |
|----------|-----|------------------|-------|
| Apple TTS | `apple` | `["com.apple.voice.compact.en-US.Aaron", "..."]` | System voices; multiple IDs supported |
| ElevenLabs | `elevenlabs` | `["21m00Tcm4TlvDq8ikWAM", "..."]` | ElevenLabs voice IDs; multiple IDs supported |
| VoxAlta | `voxalta` | `["female-voice-1", "..."]` | VoxAlta voice IDs; multiple IDs supported |

### Backward Compatibility: v3.x Cast Format

v3.x used single voices per provider. SwiftProyecto v4.0.0 reads and upgrades v3.x cast automatically:

```yaml
# v3.x format (still readable)
voices:
  apple: com.apple.voice.compact.en-US.Aaron
  elevenlabs: 21m00Tcm4TlvDq8ikWAM

# v4.0.0 format (written on save)
voices:
  apple:
    - com.apple.voice.compact.en-US.Aaron
  elevenlabs:
    - 21m00Tcm4TlvDq8ikWAM
```

---

## Schema Detection & Migration

### v3.x → v4.0.0 Auto-Migration

SwiftProyecto auto-detects file version and migrates v3.x to v4.0.0 representation:

```yaml
# v3.x file (no schemaVersion)
---
type: project
title: "Podcast Meditations"
author: Tom Stovall
created: 2025-01-25T00:00:00Z
season: 1
episodes: 365
---

# Automatically migrated to v4.0.0 representation internally:
# - schemaVersion: 4
# - season/episodes → seasons[0]
# - type: project (unchanged)
```

**Detection Rules:**
- If `schemaVersion: 4` is present → v4.0.0 format
- If `schemaVersion` is absent AND `seasons[]` is present → v4.0.0 format
- If `schemaVersion` is absent AND `season: <number>` is present → v3.x format (auto-migrated)
- If `schemaVersion` is absent AND neither `season`/`episodes` nor `seasons[]` → v4.0.0 default

### Backward-Compatibility Properties

Parsed files expose backward-compatibility properties for v3.x code:

```swift
let frontMatter = try parser.parse(...)
let season = frontMatter.season  // Returns seasons.first?.number
let episodes = frontMatter.episodes  // Returns seasons.first?.episodes
```

---

## YAML Syntax Examples

### Minimal Project (v4.0.0)

```yaml
---
schemaVersion: 4
type: project
title: "My Screenplay"
author: "John Doe"
created: 2026-01-15T10:30:00Z
---
```

### Single-Season Project with Cast (v4.0.0)

```yaml
---
schemaVersion: 4
type: project
title: "Podcast Meditations"
author: Tom Stovall
created: 2025-01-25T00:00:00Z
description: A year-long journey through Marcus Aurelius wisdom
genre: Documentary
tags: [mindfulness, self-care, mental health, meditation]

seasons:
  - number: 1
    episodes: 365
    episodesDir: episodes/season-1
    filePattern: "*.fountain"

audioDir: audio
exportFormat: m4a

cast:
  - character: MARCUS AURELIUS
    actor: Tom Stovall
    gender: M
    voiceDescription: Deep, measured baritone with gravitas
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron

tts:
  provider: apple
  voiceLanguage: en-US
---
```

### Multi-Season Project (v4.0.0)

```yaml
---
schemaVersion: 4
type: project
title: "Complete Meditations"
author: Tom Stovall
created: 2025-01-25T00:00:00Z
description: Stoic philosophy for modern life

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

audioDir: audio
exportFormat: m4a

cast:
  - character: NARRATOR
    actor: Tom Stovall
    gender: M
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron

tts:
  provider: apple
  voiceLanguage: en-US
---
```

### Master File with Variants (v4.0.0)

```yaml
---
schemaVersion: 4
type: overview
title: "lingua-matra — Polyglot Podcast"
author: Tom Stovall
created: 2025-06-01T00:00:00Z
description: Daily language lessons in English, Spanish, and French

seasons:
  - number: 1
    episodes: 365
    episodesDir: episodes/season-1

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
    path: episodes/season-1/PROJECT_en.md
    status: published
  - season: 1
    language: es
    path: episodes/season-1/PROJECT_es.md
    status: published
  - season: 1
    language: fr
    path: episodes/season-1/PROJECT_fr.md
    status: in_progress

cast:
  - character: NARRATOR
    actor: Tom Stovall
    voiceDescription: Native speaker, engaging tone
    voices:
      apple: {}  # Language-specific voices in variants

tts:
  provider: apple
  voiceLanguage: en-US
---

# lingua-matra: A Polyglot Podcast

Daily lessons in multiple languages...
```

### Multi-Language Variant (Single File with episodePath)

```yaml
---
schemaVersion: 4
type: project
title: "lingua-matra — English Lessons"
author: Tom Stovall
created: 2025-06-01T00:00:00Z
language: en

seasons:
  - number: 1
    episodes: 365
    episodesDir: episodes/season-1

episodePath: "episodes/season-{season}/episode-{number:03d}.{language}.fountain"

cast:
  - character: NARRATOR
    actor: Tom Stovall
    language: en-US
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron

tts:
  provider: apple
  voiceLanguage: en-US
---
```

---

## Property Resolution & Inheritance

When working with multi-season/variant projects, properties are resolved hierarchically:

### Resolution Hierarchy

1. **Variant Level** (highest priority)
   - Properties specific to a variant override everything
   - Example: Variant cast overrides season and master cast

2. **Season Level**
   - Season-specific properties override master defaults
   - Example: `seasons[0].episodesDir` overrides project-level `episodesDir`

3. **Master Level**
   - Project-wide defaults
   - Example: project-level `tts.provider` applies to all seasons unless overridden

4. **Defaults** (lowest priority)
   - Built-in defaults (e.g., `episodesDir: "episodes"`)

### Example: Cast Merging

```
Master cast:     [NARRATOR, GUEST]
Season 1 cast:   [NARRATOR (voice: es-voice)]
Variant cast:    []  (empty - inherits)

Result:
- NARRATOR uses variant's es-voice, GUEST inherits from master
```

---

## Master vs. Variant File Structure

### Master FILE (type: overview)

- Located at project root: `PROJECT.md`
- **Purpose**: Index all seasons and language variants
- **Can be empty**: Master provides defaults, variants are self-contained
- **type** field: `"overview"`
- **Contains**: `seasons[]`, `languages[]`, `variants[]` references

### Variant File (type: project)

- Located in content directory: `episodes/season-1/PROJECT_es.md`
- **Purpose**: Self-contained metadata for a specific season/language
- **Can be standalone**: Variant can exist without master
- **type** field: `"project"`
- **Contains**: Can reference master via `masterPath` property (not in spec yet — future enhancement)

---

## Validation Rules

### Required Fields
- `type` must be `"project"` or `"overview"`
- `title` must be non-empty
- `author` must be non-empty
- `created` must be valid ISO 8601 timestamp

### Conditional Requirements
- If `seasons[]` is present, each season must have `number` and `episodes`
- If `languages[]` is present, each language must have `code` and `name`
- If `variants[]` is present, each variant must have `season`, `language`, and `path`
- If `episodePath` is used, it must contain valid template variables

### Cast Validation
- Character names must be non-empty
- If `voices` object is present, it must not be empty (at least one provider)
- Provider values (in v4.0+) must be non-empty arrays

---

## See Also

- [EXAMPLE_PROJECT_v4.md](EXAMPLE_PROJECT_v4.md) — Complete working examples
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) — Upgrading from v3.x
- [VARIANT_REFERENCE.md](VARIANT_REFERENCE.md) — Variant patterns and best practices
- [AGENTS.md](../AGENTS.md) § PROJECT.md Modification Rules — Safe ways to update PROJECT.md files

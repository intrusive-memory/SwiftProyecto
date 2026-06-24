---
type: example
name: Example PROJECT.md Files — v4.0.0
description: Complete working examples of PROJECT.md files in v4.0.0 schema
updated: 2026-06-23
---

# Example PROJECT.md Files — v4.0.0

Complete, working examples of PROJECT.md files demonstrating various v4.0.0 schema patterns.

---

## Table of Contents

1. [Single-Season Project](#single-season-project)
2. [Multi-Season Project](#multi-season-project)
3. [Multi-Language Master File](#multi-language-master-file)
4. [Variant File (Season/Language)](#variant-file-seasonlanguage)
5. [Single File with episodePath](#single-file-with-episodepath)

---

## Single-Season Project

**Use Case**: Standalone podcast or screenplay project with one season.

**File**: `PROJECT.md` (project root)

```yaml
---
schemaVersion: 4
type: project
title: "Podcast Meditations"
author: Tom Stovall
created: 2025-01-25T00:00:00Z
description: A year-long daily journey through Marcus Aurelius' Meditations, exploring Stoic philosophy for modern life.
genre: Documentary
tags: [mindfulness, philosophy, stoicism, meditation]

seasons:
  - number: 1
    title: "Year One"
    description: "Books I-IV of Meditations"
    episodes: 365
    releaseDate: 2025-01-25T00:00:00Z
    episodesDir: episodes
    filePattern: "*.fountain"

audioDir: audio
exportFormat: m4a
preGenerateHook: "make validate"
postGenerateHook: "make publish"

cast:
  - character: NARRATOR
    actor: Tom Stovall
    gender: M
    voiceDescription: Warm, measured baritone with philosophical gravitas
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
      elevenlabs:
        - 21m00Tcm4TlvDq8ikWAM

  - character: MARCUS AURELIUS
    voiceDescription: Ancient Roman emperor, introspective and wise
    voices:
      apple:
        - com.apple.voice.compact.en-US.Moira

tts:
  provider: apple
  voiceLanguage: en-US
  actionLineVoice: null
---

# Podcast Meditations

A daily exploration of Marcus Aurelius' timeless wisdom...

## Project Structure

```
.
├── PROJECT.md
├── episodes/
│   ├── meditation-001.fountain
│   ├── meditation-002.fountain
│   └── ...
└── audio/
    └── (generated audio files)
```

## Recording Notes

Episodes are recorded in a quiet studio with professional audio equipment. Each episode is approximately 10-15 minutes.
```

---

## Multi-Season Project

**Use Case**: Long-running series with multiple seasons, each with distinct episodes.

**File**: `PROJECT.md` (project root)

```yaml
---
schemaVersion: 4
type: project
title: "Complete Meditations"
author: Tom Stovall
created: 2025-01-25T00:00:00Z
description: Four-year exploration of all twelve books of Marcus Aurelius' Meditations, released seasonally with new perspectives each year.
genre: Documentary
tags: [philosophy, stoicism, education]

seasons:
  - number: 1
    title: "Year One: Books I-IV"
    description: "Foundation and virtue"
    episodes: 365
    releaseDate: 2025-01-25T00:00:00Z
    episodesDir: episodes/season-1
    filePattern: "*.fountain"

  - number: 2
    title: "Year Two: Books V-VIII"
    description: "Mind and action"
    episodes: 365
    releaseDate: 2026-01-25T00:00:00Z
    episodesDir: episodes/season-2
    filePattern: "*.fountain"

  - number: 3
    title: "Year Three: Books IX-X"
    description: "Adversity and wisdom"
    episodes: 365
    releaseDate: 2027-01-25T00:00:00Z
    episodesDir: episodes/season-3
    filePattern: "*.fountain"

  - number: 4
    title: "Year Four: Books XI-XII"
    description: "Legacy and acceptance"
    episodes: 365
    releaseDate: 2028-01-25T00:00:00Z
    episodesDir: episodes/season-4
    filePattern: "*.fountain"

audioDir: audio
exportFormat: m4a

cast:
  - character: NARRATOR
    actor: Tom Stovall
    gender: M
    voiceDescription: Primary narrator, warm and thoughtful
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron

  - character: MARCUS AURELIUS
    voiceDescription: Roman emperor, introspective
    voices:
      apple:
        - com.apple.voice.compact.en-US.Moira

  - character: HISTORIAN
    voiceDescription: Classical scholar, authoritative
    voices:
      apple:
        - com.apple.voice.compact.en-US.Victoria

tts:
  provider: apple
  voiceLanguage: en-US
---

# Complete Meditations

A comprehensive four-year journey through Marcus Aurelius' teachings...

## Directory Structure

Each season is organized in its own directory:

```
.
├── PROJECT.md
├── episodes/
│   ├── season-1/
│   │   ├── day-001.fountain
│   │   ├── day-002.fountain
│   │   └── ...
│   ├── season-2/
│   │   ├── day-001.fountain
│   │   └── ...
│   ├── season-3/
│   │   └── ...
│   └── season-4/
│       └── ...
└── audio/
    ├── season-1/
    ├── season-2/
    ├── season-3/
    └── season-4/
```

## Season Themes

- **Season 1**: The foundation of virtue and character
- **Season 2**: The power of mind and intentional action
- **Season 3**: Facing adversity with wisdom and strength
- **Season 4**: Legacy, acceptance, and the circle of life
```

---

## Multi-Language Master File

**Use Case**: International project with content in multiple languages. Master file indexes all language variants.

**File**: `PROJECT.md` (project root, `type: overview`)

```yaml
---
schemaVersion: 4
type: overview
title: "lingua-matra — Polyglot Language Lessons"
author: Tom Stovall
created: 2025-06-01T00:00:00Z
description: Daily language lessons teaching English, Spanish, and French through immersive storytelling and cultural context.
genre: Educational
tags: [language, learning, education, culture]

seasons:
  - number: 1
    title: "Beginner's Journey"
    description: "Foundation vocabulary and phrase patterns"
    episodes: 365
    releaseDate: 2025-06-01T00:00:00Z
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

audioDir: audio
exportFormat: m4a

cast:
  - character: INSTRUCTOR
    gender: M
    voiceDescription: Native speaker, patient teaching voice
    voices:
      apple: {}  # Language-specific voices defined in variants

  - character: STUDENT
    gender: F
    voiceDescription: Learner voice, asking questions
    voices:
      apple: {}  # Language-specific voices defined in variants

tts:
  provider: apple
  voiceLanguage: en-US
---

# lingua-matra — Polyglot Lessons

Learn languages through engaging, culturally-rich stories.

## Master File Overview

This is the **master index** file. Each language version has its own `PROJECT.md`:

- **English**: `episodes/season-1/PROJECT_en.md`
- **Spanish**: `episodes/season-1/PROJECT_es.md`
- **French**: `episodes/season-1/PROJECT_fr.md`

Each variant file contains language-specific metadata, voice selections, and episode paths.
```

---

## Variant File (Season/Language)

**Use Case**: Language-specific variant referenced by master file. Self-contained with language-specific voices and metadata.

**File**: `episodes/season-1/PROJECT_en.md` (referenced by master)

```yaml
---
schemaVersion: 4
type: project
title: "lingua-matra — English Lessons"
author: Tom Stovall
created: 2025-06-01T00:00:00Z
description: Daily English language lessons with cultural context and engaging characters.
language: en

seasons:
  - number: 1
    title: "Beginner's Journey"
    description: "Foundation vocabulary and phrase patterns"
    episodes: 365
    releaseDate: 2025-06-01T00:00:00Z
    episodesDir: .
    filePattern: "*.en.fountain"

audioDir: ../audio/en
exportFormat: m4a

cast:
  - character: INSTRUCTOR
    actor: Tom Stovall
    gender: M
    language: en-US
    voiceDescription: Native English speaker, patient teaching voice
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron

  - character: STUDENT
    gender: F
    language: en-US
    voiceDescription: English learner, asking clarifying questions
    voices:
      apple:
        - com.apple.voice.compact.en-US.Victoria

tts:
  provider: apple
  voiceLanguage: en-US
---

# lingua-matra — English Lessons

## Episode Files

Episodes in this directory follow the naming pattern: `lesson-NNN.en.fountain`

```
episodes/season-1/
├── lesson-001.en.fountain
├── lesson-002.en.fountain
├── lesson-003.en.fountain
└── ...
```

## Character Guide

### INSTRUCTOR
Tom Stovall as the primary English instructor. Speaks slowly and clearly for language learners.

### STUDENT
A character asking questions and practicing dialogue with the instructor.
```

---

## Variant File (Alternative Language)

**File**: `episodes/season-1/PROJECT_es.md` (Spanish variant)

```yaml
---
schemaVersion: 4
type: project
title: "lingua-matra — Lecciones de Español"
author: Tom Stovall
created: 2025-06-01T00:00:00Z
description: Lecciones diarias de español con contexto cultural y personajes atractivos.
language: es

seasons:
  - number: 1
    title: "Viaje del Principiante"
    description: "Vocabulario fundamental y patrones de frases"
    episodes: 365
    releaseDate: 2025-06-01T00:00:00Z
    episodesDir: .
    filePattern: "*.es.fountain"

audioDir: ../audio/es
exportFormat: m4a

cast:
  - character: INSTRUCTOR
    actor: Tom Stovall
    gender: M
    language: es-MX
    voiceDescription: Hablante nativo de español mexicano
    voices:
      apple:
        - com.apple.voice.compact.es-MX.Juan

  - character: STUDENT
    gender: F
    language: es-MX
    voiceDescription: Estudiante de español
    voices:
      apple:
        - com.apple.voice.compact.es-MX.Paulina

tts:
  provider: apple
  voiceLanguage: es-MX
---

# lingua-matra — Lecciones de Español

## Estructura de Archivos

Los episodios siguen el patrón: `lesson-NNN.es.fountain`

```
episodes/season-1/
├── lesson-001.es.fountain
├── lesson-002.es.fountain
├── lesson-003.es.fountain
└── ...
```
```

---

## Single File with episodePath

**Use Case**: Multi-language episodes stored in a single PROJECT.md using `episodePath` template for dynamic path resolution.

**File**: `PROJECT.md` (project root)

```yaml
---
schemaVersion: 4
type: project
title: "Daily Languages"
author: Tom Stovall
created: 2025-06-01T00:00:00Z
description: Single PROJECT.md supporting multiple languages via episode path templating.
language: null  # Multi-language support

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

# Template for episode file paths with language variable
episodePath: "episodes/season-{season}/lesson-{number:03d}.{language}.fountain"

cast:
  - character: INSTRUCTOR
    gender: M
    voiceDescription: Native speaker
    voices:
      apple:
        - com.apple.voice.compact.en-US.Aaron
        - com.apple.voice.compact.es-MX.Juan
        - com.apple.voice.compact.fr-FR.Bernard

  - character: STUDENT
    gender: F
    voices:
      apple:
        - com.apple.voice.compact.en-US.Victoria
        - com.apple.voice.compact.es-MX.Paulina
        - com.apple.voice.compact.fr-FR.Chloe

tts:
  provider: apple
  voiceLanguage: en-US
---

# Daily Languages

## Episode Path Resolution

The `episodePath` template dynamically resolves episode paths based on season and language:

### Template: `episodes/season-{season}/lesson-{number:03d}.{language}.fountain`

### Examples:

| Season | Episode | Language | Resolved Path |
|--------|---------|----------|---------------|
| 1 | 1 | en | `episodes/season-1/lesson-001.en.fountain` |
| 1 | 15 | en | `episodes/season-1/lesson-015.en.fountain` |
| 1 | 1 | es | `episodes/season-1/lesson-001.es.fountain` |
| 1 | 365 | fr | `episodes/season-1/lesson-365.fr.fountain` |

## Directory Structure

```
.
├── PROJECT.md
├── episodes/
│   └── season-1/
│       ├── lesson-001.en.fountain
│       ├── lesson-001.es.fountain
│       ├── lesson-001.fr.fountain
│       ├── lesson-002.en.fountain
│       ├── lesson-002.es.fountain
│       ├── lesson-002.fr.fountain
│       └── ... (365 lessons × 3 languages = 1095 total files)
└── audio/
    ├── en/
    ├── es/
    └── fr/
```

## When to Use episodePath

Use `episodePath` when:
- ✅ Episodes for multiple languages are stored in the same directory
- ✅ You want a single PROJECT.md for all languages
- ✅ Episode numbering is consistent across languages
- ✅ You don't need per-language metadata differences

Use variant files instead when:
- ✅ Each language needs different metadata (cast, voice, TTS config)
- ✅ Release dates differ by language
- ✅ Episode counts differ by language
- ✅ You want to keep master + variant structure
```

---

## Notes

### Schema Version Detection

All examples use `schemaVersion: 4` explicitly. SwiftProyecto v4.0.0 also reads v3.x files (without `schemaVersion`) and auto-migrates them.

### File Validation

All examples are valid according to the v4.0.0 schema. You can validate a PROJECT.md file using:

```bash
proyecto validate /path/to/PROJECT.md
proyecto validate /path/to/project-directory
```

### Cast Language Support

The `language` field on `CastMember` is optional but recommended when creating language-specific variants. It clarifies which language variant a character voice is for.

### See Also

- [PROJECT_MD_REFERENCE_v4.md](PROJECT_MD_REFERENCE_v4.md) — Complete field reference
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) — Upgrading from v3.x
- [VARIANT_REFERENCE.md](VARIANT_REFERENCE.md) — Variant patterns and best practices

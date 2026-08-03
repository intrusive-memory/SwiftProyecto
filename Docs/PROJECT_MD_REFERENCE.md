---
type: reference
---

# PROJECT.md Front Matter Schema Reference

Quick-reference guide for the YAML front matter syntax used in PROJECT.md files.

**See Also**: [AGENTS.md](../AGENTS.md) for comprehensive documentation, [EXAMPLE_PROJECT.md](../EXAMPLE_PROJECT.md) for a complete working example.

---

## Structure

PROJECT.md files consist of two parts:

```markdown
---
# YAML Front Matter (metadata)
type: project
title: "..."
author: "..."
...
---

# Markdown Body
# Project Description

Content below the front matter separator...
```

The front matter is delimited by `---` markers and contains YAML key-value pairs.

---

## Front Matter Fields

### Core Metadata (Required)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | String | ✅ Yes | Always set to `"project"` |
| `title` | String | ✅ Yes | Project title (e.g., "Podcast Meditations") |
| `author` | String | ✅ Yes | Project creator/author name |
| `created` | ISO 8601 Timestamp | ✅ Yes | Project creation date (e.g., `2025-01-25T00:00:00Z`) |

### Project Metadata (Optional)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `description` | String | — | Long-form project description (2-3 sentences) |
| `season` | Integer | — | Season number (e.g., `1`) |
| `episodes` | Integer | — | Total episode count (e.g., `365`) |
| `genre` | String | — | Content genre (e.g., "Documentary", "Screenplay") |
| `tags` | Array of Strings | — | Project tags (e.g., `[mindfulness, self-care, meditation]`) |

### Generation Config (Optional)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `episodesDir` | String | `"episodes"` | Directory containing episode files |
| `audioDir` | String | `"audio"` | Output directory for generated audio |
| `filePattern` | String or Array | `["*.fountain", "*.fdx", "*.highland"]` | File pattern(s) to match screenplay files (default matches all SwiftCompartido-readable formats: Fountain, Final Draft, Highland) |
| `exportFormat` | String | `"m4a"` | Audio export format (e.g., `"m4a"`, `"mp3"`, `"wav"`) |

### Workflow Hooks (Optional)

| Field | Type | Description |
|-------|------|-------------|
| `preGenerateHook` | String | Shell command to run before generation |
| `postGenerateHook` | String | Shell command to run after generation |

### Schema Version

| Field | Type | Description |
|-------|------|-------------|
| `schemaVersion` | Integer | Stamped automatically on every write (`5` is current). Absent = v3 legacy; `4` = multi-season schema, with `cast:`; `5` = current, no `cast:` key. |

### Cast (Removed in Schema v5)

PROJECT.md declares **no `cast:` key**. A production's cast — characters, actors, voice prompts, and provider voice mappings — lives in `CAST.md`, owned by [SwiftReparto](https://github.com/intrusive-memory/SwiftReparto) (`reparto` CLI). A legacy `cast:` block in an older file is preserved verbatim as an unknown key; move it into `CAST.md` with `proyecto migrate`.

---

## YAML Syntax Examples

### Minimal Project

```yaml
---
type: project
title: "My Screenplay"
author: "John Doe"
created: 2026-01-15T10:30:00Z
---
```

### Project with Metadata

```yaml
---
type: project
title: "Podcast Meditations"
author: Tom Stovall
created: 2025-01-25T00:00:00Z
description: A year-long journey through Marcus Aurelius wisdom
season: 1
episodes: 365
genre: Documentary
tags: [mindfulness, self-care, mental health, meditation]
episodesDir: episodes
audioDir: audio
filePattern: "*.fountain"
exportFormat: m4a
---
```

(The roster for such a project lives in a sibling `CAST.md` — see [SwiftReparto](https://github.com/intrusive-memory/SwiftReparto).)

### Project with Multiple File Patterns

```yaml
---
type: project
title: "Mixed Media Project"
author: "Designer"
created: 2026-03-01T00:00:00Z
filePattern:
  - "*.fountain"
  - "*.md"
  - "*.txt"
---
```

### Project with Workflow Hooks

```yaml
---
type: project
title: "Automated Project"
author: "Engineer"
created: 2026-02-10T00:00:00Z
preGenerateHook: "make validate"
postGenerateHook: "make publish"
---
```

---

## App-Specific Settings (v2.6.0+)

SwiftProyecto allows apps to store custom settings in the same PROJECT.md file using namespaced keys:

```yaml
---
type: project
title: "My Project"
author: "Author Name"
created: 2026-01-01T00:00:00Z

# Your app's settings (namespaced under your app key)
myapp:
  theme: "dark"
  exportFormat: "pdf"
  autoSave: true
  advancedOptions:
    compressionLevel: 9
    metadata: true
---
```

**Rules for App Settings:**
- Each app uses a unique section key (e.g., `myapp`, `produciesta`, `screenwriter`)
- Settings are stored as arbitrary YAML under that key
- Multiple apps can have settings in the same PROJECT.md
- Apps read/write settings via `AppFrontMatterSettings` protocol
- SwiftProyecto handles type-safe serialization automatically

**See [Docs/EXTENDING_PROJECT_MD.md](EXTENDING_PROJECT_MD.md) for complete app extension guide.**

---

## Validation Rules

### Required Fields
- `type` must be `"project"`
- `title`, `author`, `created` must be non-empty
- `created` must be valid ISO 8601 timestamp (e.g., `2025-01-25T00:00:00Z`)

### Optional Fields
- `season`, `episodes` must be positive integers if specified
- `filePattern` can be a single string or array of strings

### Legacy `cast:` Block
- A `cast:` block in an older file is **not** an error: `proyecto validate` warns (pointing at `proyecto migrate`) but never mutates, and still exits 0

---

## Common Patterns

### Screenplay with Multiple File Types

```yaml
filePattern:
  - "*.fountain"
  - "*.md"
  - "*.notes"
```

### Project with Season/Episode Metadata

```yaml
season: 2
episodes: 10
episodesDir: season-2/episodes
audioDir: season-2/audio
```

---

## Tips for Agents

1. **Always validate required fields** before parsing: `type`, `title`, `author`, `created`
2. **Cast lives in CAST.md** — read it via SwiftReparto, never from PROJECT.md front matter
3. **Use resolved accessors** in code: `frontMatter.resolvedEpisodesDir`, `resolvedFilePatterns` (handle defaults)
4. **File patterns**: Normalize to array with `.patterns` property for consistent handling
5. **App settings**: Use `frontMatter.settings(for: MySettings.self)` for type-safe access

---

## See Also

- **[AGENTS.md](../AGENTS.md)** — Comprehensive documentation for AI agents
- **[EXAMPLE_PROJECT.md](../EXAMPLE_PROJECT.md)** — Complete working example
- **[Docs/EXTENDING_PROJECT_MD.md](EXTENDING_PROJECT_MD.md)** — How to add app-specific settings
- **[Swift API Reference](../Sources/SwiftProyecto/Models/ProjectFrontMatter.swift)** — Source code definitions


# AGENTS Property in PROJECT.md Front Matter

## Summary

Add an `agents` property to `ProjectFrontMatter` that contains freeform instructions for AI agents processing the project. When an agent parses a `PROJECT.md` file, the `agents` content must be surfaced prominently — it is the project author's direct communication channel to any AI agent that encounters the project.

## Problem

Project authors have no way to embed agent-specific instructions in their `PROJECT.md`. Important context — generation preferences, naming conventions, content warnings, workflow constraints — must be communicated out-of-band. Since SwiftProyecto's core purpose is enabling AI agents to understand projects in a single pass, this is a gap.

## Requirements

### Front Matter Schema

Add an `agents` property to `ProjectFrontMatter`:

```yaml
---
type: project
title: Therapist GPT
author: Tom Stovall
created: 2026-02-10T13:35:06Z
agents: |
  This podcast deals with sensitive mental health topics. Exercise care
  with tone and wording when generating episode descriptions or summaries.

  Episodes should always be generated in order. Do not parallelize episode
  generation — each episode may reference events from prior episodes.

  The NARRATOR voice is the podcast's signature. Never reassign it.
---
```

### Property Definition

In `ProjectFrontMatter`:

```swift
/// Freeform instructions for AI agents processing this project.
/// When present, agents MUST read and follow these instructions
/// before performing any operations on the project.
public let agents: String?
```

- **Type**: `String?` (optional)
- **Format**: Freeform text. Supports YAML multiline scalars (`|` for literal block, `>` for folded).
- **Default**: `nil` (no agent instructions)

### Parsing Behavior

- Parsed as part of normal YAML front matter decoding — no special handling needed beyond adding the property to the `CodingKeys` enum and the `init(from:)` decoder.
- Must survive round-trip: `parse → write` must preserve the `agents` content exactly (including newlines in block scalars).

### Agent Contract

When any tool or agent reads a `PROJECT.md` via SwiftProyecto:

1. If `agents` is non-nil and non-empty, the content **MUST** be presented to the agent before any other processing occurs.
2. The content should be treated with the same authority as a `CLAUDE.md` or `AGENTS.md` file — it is the project author's instructions.
3. Agents should not silently ignore the `agents` field. If an agent cannot comply with an instruction, it should flag it rather than skip it.

### API Surface

```swift
// ProjectFrontMatter
public let agents: String?

// Convenience
extension ProjectFrontMatter {
    /// Whether this project has agent instructions
    public var hasAgentInstructions: Bool {
        guard let agents else { return false }
        return !agents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

### ProjectModel Persistence

Add an `agentInstructions` field to `ProjectModel` (SwiftData) so persisted projects retain the agent instructions:

```swift
// In ProjectModel
var agentInstructions: String?
```

Map from `ProjectFrontMatter.agents` during project import/sync.

### Serialization (Write-Back)

When `ProjectMarkdownParser.write(frontMatter:body:to:)` serializes back to YAML:

- If `agents` is non-nil, emit it as a YAML literal block scalar (`|`) to preserve newlines.
- Position it after the standard metadata fields and before generation config fields.

### Validation

- No validation on content — it is freeform.
- Empty string or whitespace-only string treated as absent (`hasAgentInstructions` returns `false`).

## Example PROJECT.md

```yaml
---
type: project
title: Daily Dao
author: Tom Stovall
created: 2026-01-15T00:00:00Z
description: Daily readings from the Tao Te Ching
agents: |
  Each chapter is a self-contained reading. Do not merge or split chapters.

  The translation used is Stephen Mitchell's — do not substitute alternate
  translations or paraphrase the source text.

  When generating audio, insert a 3-second pause between the chapter number
  announcement and the body reading.
episodes: 81
genre: Philosophy
episodesDir: episodes
audioDir: audio
filePattern: ["*.fountain"]
exportFormat: m4a
cast:
  - character: NARRATOR
    voices:
      voxalta: zoe
---
```

## Non-Goals

- Structured/typed agent instructions (e.g., key-value constraints). Keep it freeform text for maximum flexibility.
- Per-agent targeting (e.g., "only for Claude" vs "only for Gemini"). All agents see the same instructions. Agents can self-select which instructions apply to them.
- Agent response/acknowledgment protocol. This is one-way communication from author to agent.

## Implementation Notes

- This is a small, additive change to `ProjectFrontMatter` — one new optional property, one `CodingKeys` entry, one line in `init(from:)`, one line in serialization.
- The `appSections` extensibility mechanism is not appropriate here because `agents` is a core concern of SwiftProyecto's mission (agentic project discovery), not an app-specific extension.
- Downstream consumers (Produciesta CLI, Produciesta app) should log or print the `agents` content when processing a project so it appears in agent context.

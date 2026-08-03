---
type: reference
---

# Upgrading SwiftProyecto

# Upgrading from SwiftProyecto 4.x to 5.0.0

SwiftProyecto v5.0.0 removes the **entire cast surface** from the library and the PROJECT.md schema. A production's cast now lives in `CAST.md`, owned by [SwiftReparto](https://github.com/intrusive-memory/SwiftReparto).

## What Breaks at Compile Time

If your code touches any of these, it will not compile against 5.0.0:

| Removed in 5.0.0 | Use instead |
|------------------|-------------|
| `CastMember` (and `Gender`, `MergeStrategy`) | SwiftReparto's `CastMember` (`voicePrompt`, `voices`, `extraKeys`) |
| `ProjectFrontMatter.cast` | Read `CAST.md` via SwiftReparto |
| `ProjectFrontMatter.withCast(_:)` / `mergingCast(_:forProvider:)` / `mergeCast(...)` | SwiftReparto's gap-filling `[CastMember].merging(_:)` |
| `SeasonDefinition.cast` | — (seasons no longer carry a roster) |
| `VariantResolver` cast resolution | — |
| `ProjectService.discoverCastList(for:)` / `mergeCastLists(discovered:existing:)` | Roster maintenance against `CAST.md` (SwiftReparto) |
| `ProjectDiscovery.readCast(from:filterByProvider:)` | SwiftReparto's parser |
| `ProjectMarkdownParser.renderCast(_:)` / `replacingCastBlock(in:with:)` | Only SwiftReparto serializes cast (`CastMarkdownParser.generate`/`write`) |
| `proyecto roles` command | `reparto` CLI + `proyecto migrate` |

Still present and unchanged: the generation-time types `CastMemberData` (LLM backend protocol), `GeneratedProjectMetadata.cast`, `DirectoryAnalysis.extractedCast`, and `CastExtractor` — these describe what a backend extracted from a directory, not the PROJECT.md schema.

## The PROJECT.md File-Format Change

- **Schema v5** (`ProjectSchemaVersion.current == 5`). History: no `schemaVersion:` key = v3 legacy; `4` = multi-season schema, with `cast:`; `5` = current, **no `cast:` key**.
- Every write stamps `schemaVersion: 5`.
- **v3 and v4 files still parse fine.** They normalize to `schemaVersion: 5` on their first write. A legacy `cast:` block is *not* lost or rejected — it parses into the unknown-key store, round-trips verbatim, and `proyecto validate` warns about it (without mutating anything, exit code still 0) until you migrate it out.

## Migrating a Legacy `cast:` Block: `proyecto migrate`

```bash
# One-time: install reparto, CAST.md's owner
brew install intrusive-memory/tap/reparto

# Preview — verifies everything, writes nothing
proyecto migrate /path/to/project --dry-run

# Migrate
proyecto migrate /path/to/project
```

`proyecto migrate` moves the top-level `cast:` block into `CAST.md` via `reparto import` and rewrites PROJECT.md without it, stamped `schemaVersion: 5`. PROJECT.md is only rewritten **after the transfer is verified**: `reparto import` exits 0, `reparto validate` passes on the produced `CAST.md`, and every `character:` name from the legacy block is present in it. A `PROJECT.md.bak` backup is written first, and the rewrite is byte-surgical — only the `cast:` span and the `schemaVersion:` line change.

Refusal cases (each leaves PROJECT.md byte-for-byte untouched):

- `reparto` is not installed.
- `CAST.md` already exists — auto-migration never overwrites it; run `proyecto migrate --force` to let `reparto import` overwrite it deliberately.
- A season-level `cast:` block is present — `reparto import` reads only the top-level key; migrate the season cast by hand, then re-run.

`proyecto init --update` and `proyecto generate-project` auto-migrate first and **abort their rewrite** if migration can't complete — their full re-emit cannot preserve a legacy block, so they refuse to run until the cast is safely in `CAST.md`.

Note: the `reparto` **binary** is a runtime dependency of the migration path only. SwiftProyecto declares no package dependency on SwiftReparto, in either direction.

## Reading Cast After 5.0.0 (Consumers)

Read the roster from `CAST.md` with SwiftReparto's parser, mutate the `CastDocument` value, and hand it back through SwiftReparto's `write` — never serialize `CAST.md` yourself (SwiftReparto's one-writer rule). This is the same contract SwiftEchada (writes back `voices.voxalta`) and Produciesta (writes back voice assignments) follow. SwiftProyecto itself is **not** a CAST.md consumer — it declares no dependency and retains no cast surface.

## 4.x → 5.0.0 Checklist

- [ ] Remove/replace uses of the compile-time-removed API above
- [ ] `brew install intrusive-memory/tap/reparto`
- [ ] `proyecto migrate` each project with a legacy `cast:` block (`--dry-run` first)
- [ ] Point cast-reading code at `CAST.md` via SwiftReparto

---

# Upgrading from SwiftProyecto 3.x to 4.0

SwiftProyecto v4.0 introduces **multi-season and per-character language support**, with full backward compatibility for v3.x projects.

> **Note (v5.0.0)**: the `cast:` examples in this historical v4 guide predate schema v5, which removed `cast:` from PROJECT.md — see the 4.x → 5.0.0 section above.

## What's New in 4.0

| Feature | v3.x | v4.0 |
|---------|------|------|
| **Seasons** | Single `season` field | Multiple `seasons[]` array |
| **Language per Character** | Global language selection | Per-character `language` field on CastMember |
| **Property Hierarchy** | Two-level (project → character) | Four-level (variant > season > master > default) |
| **Backward Compatibility** | N/A | v3.x files auto-convert to synthetic seasons |
| **CLI Generation** | Single output | Per-season output via `--season` flag |

## Backward Compatibility

**Good news**: v3.x PROJECT.md files continue to work without modification.

When SwiftProyecto encounters a v3.x PROJECT.md (with a single `season` field), it automatically:
1. Creates a synthetic `seasons` array with one element
2. Copies the v3 season data into `seasons[0]`
3. Treats all operations as single-season
4. The rest of the API behaves identically to v3

**You do NOT need to migrate existing v3.x files unless you want multi-season features.**

## Migrating to v4.0 Schema (Optional)

If you want to use v4.0 features (multiple seasons, per-character language):

### Step 1: Update PROJECT.md Schema

Replace single `season` with `seasons[]` array:

```yaml
# OLD (v3.x)
---
type: project
title: My Series
season: 1
episodes: 12
cast:
  - character: NARRATOR
    language: en
    voices:
      apple: com.apple.voice.premium.en-US.Aaron
---

# NEW (v4.0)
---
type: project
title: My Series
seasons:
  - seasonNumber: 1
    episodeCount: 12
    episodeDir: season-01
cast:
  - character: NARRATOR
    language: en
    voices:
      apple: com.apple.voice.premium.en-US.Aaron
---
```

### Step 2: Per-Character Language (Optional)

Assign `language` field to each CastMember for language-specific voice selection:

```yaml
cast:
  - character: NARRATOR
    actor: Tom Stovall
    language: en
    voices:
      apple: com.apple.voice.premium.en-US.Aaron
  - character: FRANCESCA
    actor: Maria Rossi
    language: it
    voices:
      apple: com.apple.voice.premium.it-IT.Francesca
```

**Benefits**:
- ✅ Distinct voice selection per language
- ✅ Supports multilingual cast
- ✅ Foundation Models respects language during generation

### Step 3: Update Code (If Needed)

If you're reading `season` / `episodes` properties from `ProjectFrontMatter`:

```swift
// OLD (v3.x)
let season = frontMatter.season      // Optional<Int>
let episodes = frontMatter.episodes  // Optional<Int>

// NEW (v4.0) - backward compatible
let season = frontMatter.season      // Still works for v3.x files
let episodes = frontMatter.episodes  // Still works for v3.x files

// NEW (v4.0) - multi-season
let seasons = frontMatter.seasons    // [Season] array
for season in seasons {
    print("\(season.seasonNumber): \(season.episodeCount) episodes")
}
```

## API Changes

### ProjectFrontMatter

**Added (v4.0)**:
- `seasons: [Season]?` — Array of season objects
- Each `Season` has: `seasonNumber`, `episodeCount`, `episodeDir`

**Unchanged (backward compatible)**:
- `season: Int?` — Still present, synthesized from `seasons[0]` if v4.0
- `episodes: Int?` — Still present, synthesized from `seasons[0]` if v4.0
- All other fields work identically

### CastMember

**Added (v4.0)**:
- `language: String?` — ISO 639-1 language code (e.g., "en", "es", "it")

**Unchanged**:
- `character`, `actor`, `gender`, `voices` work identically
- `language` is optional; defaults to project language if absent

## CLI Changes

### `proyecto generate` Command

v4.0 adds season-specific generation:

```bash
# Generate for all seasons (new in v4.0)
proyecto generate /path/to/project

# Generate specific season only
proyecto generate /path/to/project --season 2

# Generate intro/outro for season 1
proyecto generate /path/to/project --season 1 --intro-only

# Generate outro only for season 3
proyecto generate /path/to/project --season 3 --outro-only
```

**What changed**:
- v3.x: Generates single output for project
- v4.0: Iterates over all `seasons[]`, generates per-season output
- v3.x projects: Automatically treated as single-season (synthetic `seasons[0]`)

## Migration Checklist

- [ ] **For v3.x users**: No action required. Your PROJECT.md files work as-is.
- [ ] **To use v4.0 features**: Update PROJECT.md to use `seasons[]` instead of `season`
- [ ] **Per-language cast**: Add `language: ISO639-1` field to each CastMember
- [ ] **Update CLI calls**: Use `--season N` flag if managing multiple seasons
- [ ] **Verify v4.0 schema**: Run `proyecto init --update` (coming in v4.1)

## Known Limitations in v4.0

- **`proyecto init` does not yet generate v4.0 schema** — It still produces v3.x compatible output. Full v4.0 generation support arrives in v4.1.
- **Language-aware generation requires manual setup** — Language field must be added to CastMember manually (or via `--update` in v4.1).

## Questions?

For detailed API documentation, see:
- **[AGENTS.md](AGENTS.md)** — API reference for developers
- **[Docs/PROJECT_MD_REFERENCE.md](Docs/PROJECT_MD_REFERENCE.md)** — Complete PROJECT.md schema
- **[EXAMPLE_PROJECT.md](Docs/EXAMPLE_PROJECT.md)** — Working v4.0 example

## Quick Reference: v3.x → v4.0 Changes

| Component | v3.x | v4.0 |
|-----------|------|------|
| Season storage | `season: 1` | `seasons: [{seasonNumber: 1, episodeCount: 12, episodeDir: season-01}]` |
| Language | Project-level | Per-character: `language: en` |
| CLI `generate` | Single project output | Per-season output (iterate with `--season`) |
| Backward compat | N/A | ✅ v3.x files auto-convert to synthetic seasons |
| `proyecto init` | Generates v3.x | Coming in v4.1 |

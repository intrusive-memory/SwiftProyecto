---
type: specification
---

# PLAYLIST.jspf Generation — Requirements

**Status**: DRAFT — NOT APPROVED. Open questions in §12 must be resolved first.
**Created**: 2026-09-06
**Target**: SwiftProyecto 5.1.0 (additive; new `EpisodeFrontMatter` model, new `proyecto playlist` subcommand)
**Consumers affected**: `Sonido` (player), `Produciesta` (audio generation), every `podcasts/*` project
**Related**: [Sonido REQUIREMENTS.md](https://github.com/intrusive-memory/Sonido/blob/development/REQUIREMENTS.md) §4

---

## 1. Overview

Sonido plays an audio library described by a single playlist file: **`PLAYLIST.jspf`**, JSPF (the JSON serialization of XSPF), at the root of the project, with every track location expressed as a path **relative to the playlist file itself**.

Nothing generates that file today. It was hand-written for `granville` to prove the round trip, which is exactly the failure mode this document exists to prevent: **a playlist maintained separately from the audio drifts the first time an episode is renamed, reordered, or re-exported.**

The rule this specification implements:

> The tool that generates the audio must generate the playlist, in the same run, from the same inputs.

SwiftProyecto is the correct home because it already owns both inputs — the `PROJECT.md` schema (`ProjectFrontMatter`) and project file discovery (`ProjectDiscovery`, `ProjectFileReference`, `EpisodePathResolver`). Produciesta invokes generation; it does not own the format.

### 1.1 Why this is not a new package

SwiftProyecto 5.0.0 moved cast out to SwiftReparto, so "does this belong elsewhere?" is a live question. It does not, on three grounds:

- A playlist is **project metadata**, the thing this package exists to model. Cast moved out because a cast is a production concern with its own editing surface (`CAST.md`, `reparto`); a playlist has no editing surface — it is derived output, never hand-authored.
- Both inputs are already here. A separate package would depend on SwiftProyecto for all of them and contribute only a serializer.
- Generation must not require parsing screenplays (§3), which is what would have forced it elsewhere.

---

## 2. Consumer contract (normative, from Sonido REQUIREMENTS §4)

These are Sonido's requirements, restated because generation must satisfy them exactly. Violating any one produces a playlist that resolves in the repository and 404s at the origin, or vice versa.

1. **Format is JSPF.** A JSON object with a top-level `playlist` key. `track` is an array. `track.location` is an **array** of strings. `duration` is an **integer in milliseconds**.
2. **The file is named `PLAYLIST.jspf`, exactly**, and lives at the **project root** — a sibling of `PROJECT.md`, never inside `audioDir`.
3. **Every `location` is relative to the playlist file.** Resolution is RFC 3986 against the playlist's own URL. Absolute URLs are a defect.
4. **JSPF has no `xml:base`.** The resolution rule is a contract between generator and player, not something the format declares. It cannot be inferred by a reader; it must be honored by the writer.
5. **The playlist is authoritative.** A file present in `audioDir` but absent from the playlist is not in the library. This is deliberate — it lets a project hold work-in-progress, alternate cuts, and superseded takes without them reaching listeners.

### 2.1 The layout consequence

Because locations are relative and resolved against the playlist, **the publish layout must mirror the project layout**. A publishing step that flattens `audio/*.m4a` to the origin root breaks every location that resolved locally.

This is not hypothetical: it is why `granville`'s CDN prefix and its `deploy-to-cdn.yml` were restructured on 2026-09-06. Any pipeline consuming this output inherits the constraint. Generation cannot enforce it, but `proyecto validate` must warn about it (§9.2).

---

## 3. Scope boundary

**In scope**: reading YAML front matter from episode files; reading `PROJECT.md`; discovering audio in `audioDir`; probing audio duration; serializing JSPF.

**Out of scope — and this is the boundary that keeps the feature here**: parsing screenplay content. SwiftProyecto does not parse Fountain/FDX/Highland bodies and must not start. Generation reads **only** the YAML front matter block delimited by the leading `---` / `---`, and never a byte below the closing delimiter.

Concretely, this rules out deriving titles from Fountain title pages (`Title:` / `Credit:` / `Author:`) or from centered-text act headings (`>"HUNTING DILFS"<`). Both conventions exist in the fleet today (§10). Neither is a valid input here; projects using them must migrate.

Also out of scope: uploading, publishing, or knowing about any CDN or origin.

---

## 4. Input: episode front matter

### 4.1 Titles are front matter properties

**Every playlist field that cannot be derived comes from the episode file's own YAML front matter.** The title travels with the file it describes, so it cannot fall out of alignment with a list maintained elsewhere, it survives reordering and renaming, and it works identically for projects whose `filePattern` is an explicit ordered list (`granville`) and for projects whose `filePattern` is a glob (`daily-dao`: `chapter-*.fountain`).

Rejected alternative: a title map in `PROJECT.md` keyed by filename stem. It reintroduces exactly the two-lists-that-must-agree problem this feature exists to eliminate.

### 4.2 Existing precedent

83 episode files already carry conforming front matter. `daily-dao/episodes/chapter-01.fountain`:

```yaml
---
type: episode
title: Tao De Jing - Chapter 1
album: Tao De Jing Podcast
artist: Tao De Jing
track: 1
description: Chapter One introduces us to the fundamental paradox of the Tao…
source: [ … ]
---
```

This is not a new convention. It is an existing one being specified, and it is already nearly a JSPF track.

### 4.3 `EpisodeFrontMatter` (new public model)

A new `Codable, Sendable, Equatable` model parallel to `ProjectFrontMatter`, parsed by the existing `ProjectMarkdownParser` machinery.

| Field | Type | Required | Purpose |
|---|---|---|---|
| `type` | `String` | yes | Must be `episode`. A file whose front matter declares any other type is not a playlist track. |
| `title` | `String` | yes | Track title. The one field with no acceptable derivation. |
| `artist` | `String?` | no | Track creator. Falls back to `PROJECT.md` `author`. |
| `album` | `String?` | no | Album grouping. Falls back to `PROJECT.md` `title`. |
| `track` | `Int?` | no | Explicit ordering key (§6). |
| `description` | `String?` | no | Track annotation. |
| `kind` | `String?` | no | Editorial role — `scene`, `bumper`, `intro`, `outro`. Defaults to `scene`. |
| `image` | `String?` | no | Artwork path relative to the project root, overriding the `<stem>.jpg` convention (§4.5). |
| `excludeFromPlaylist` | `Bool?` | no | When true, the episode is skipped even though its audio exists. Defaults to false. |

Unknown keys must round-trip unchanged, matching `ProjectFrontMatter`'s existing `extraKeys` behavior. `daily-dao`'s `source:` block (per-character Chinese glosses) is unknown to this model and must survive a parse/serialize cycle untouched.

### 4.4 Audio resolution

For each episode file, the audio is `<audioDir>/<stem>.<exportFormat>` — the existing `resolvedAudioDir` / `resolvedExportFormat` convention, with `EpisodePathResolver` doing the work. An episode whose audio is missing is **omitted from the playlist and reported as a warning**, never a hard failure: partially-generated projects are a normal working state. This is the only condition under which an episode is silently absent from the output — a missing *title* stops the run instead (§8.2).

A WebVTT sidecar at `<audioDir>/<stem>.vtt`, when present, becomes the track's `transcript` extension (§5.2).

### 4.5 Artwork resolution

Artwork is a sidecar on the same stem, exactly like the transcript:

| Asset | Path | Becomes |
|---|---|---|
| Track artwork | `<audioDir>/<stem>.jpg` (then `.png`) | `track.image` |
| Show artwork | `<audioDir>/cover.jpg` (then `.png`) | `playlist.image` |

An episode's `image` front-matter key overrides the convention with an explicit path relative to the project root; `PROJECT.md` may carry the same key for the show. Convention first, override only where needed.

**Generation does not create or composite artwork.** It references files that already exist, exactly as it does for audio and transcripts. Producing the art — and compositing any title treatment onto it — belongs to whatever tool made it, on the same reasoning that keeps screenplay parsing out of this package (§3). A missing image is a warning, never a failure (§8.2).

---

## 5. Output: `PLAYLIST.jspf`

### 5.1 Field mapping

Playlist level, from `ProjectFrontMatter`:

| JSPF | Source |
|---|---|
| `playlist.title` | `title` |
| `playlist.creator` | `author` |
| `playlist.annotation` | `description` |
| `playlist.image` | `<audioDir>/cover.jpg` when present (§5.3) |
| `playlist.date` | `created` (ISO 8601) |
| `playlist.meta` | `genre`, and the project slug (directory name) under the Sonido namespace |

Track level, from `EpisodeFrontMatter` with `ProjectFrontMatter` fallbacks:

| JSPF | Source |
|---|---|
| `track.location` | `["<audioDir>/<stem>.<exportFormat>"]` — **relative, single element** |
| `track.title` | `title` |
| `track.creator` | `artist` ?? project `author` |
| `track.album` | `album` ?? project `title` |
| `track.image` | `<audioDir>/<stem>.jpg` when present — **omitted when absent** (§5.3) |
| `track.trackNum` | 1-based position in final playlist order (§6) |
| `track.annotation` | `description` |
| `track.duration` | Probed audio duration in **milliseconds** (§7) |
| `track.extension` | Sonido namespace (§5.2) |

### 5.2 Sonido extension namespace

Per-track data JSPF has no field for goes under `https://sonido.intrusive-memory.productions/ns/1`, whose value is an array of objects:

```json
"extension": {
  "https://sonido.intrusive-memory.productions/ns/1": [
    { "transcript": "audio/episode_1_01_cold_open.vtt", "kind": "scene" }
  ]
}
```

`transcript` is a relative path resolved by the same §2 rule. Omitted when no sidecar exists. Consumers ignore unrecognized keys and namespaces.

### 5.3 Artwork — use the standard, and know where it stops

`image` is a standard XSPF/JSPF element at both levels. Nothing here is invented; the only local rules are the two the standard explicitly leaves open.

**What XSPF v1 defines** (quoted normatively):

- Playlist level: *"URI of an image to display in the absence of a `//playlist/trackList/image` element. `xspf:playlist` elements MAY contain exactly one."*
- Track level: *"URI of an image to display for the duration of the track. `xspf:track` elements MAY contain exactly one."*

Three consequences, all of them the standard's and not ours:

1. **Cardinality is zero-or-one.** In JSPF `image` is a plain **string**, not an array — unlike `location` and `identifier`, which are arrays at track level. Emitting an array is malformed.
2. **Fallback is specified.** The playlist image exists precisely to be shown *in the absence of* a track image. Consumers inherit; generators do not duplicate.
3. **Therefore: never emit a `track.image` identical to `playlist.image`.** A track with no artwork of its own omits the key entirely and the standard supplies the show image. Writing it on every track would be redundant, would inflate the file, and would defeat the one piece of behaviour the format actually specifies.

**What XSPF does not define**, and is therefore ours to state:

| Concern | Standard | This project |
|---|---|---|
| Format | unspecified | JPEG preferred; PNG accepted. Progressive JPEG for anything shipped. |
| Dimensions | unspecified | Square, ≥ 1400 px (Apple Podcasts' floor; 3000 px recommended for submission) |
| Relative URIs | §6.2 defers to XML Base / RFC 2396 — **and JSPF has no XML Base** | Resolved against the playlist's own URL, per §2 |

That last row is the load-bearing one: `image` is a URI and inherits §2's resolution rule exactly as `location` does. A relative `audio/cover.jpg` beside the playlist resolves correctly in the repository and at the origin; an absolute URL is the same defect there as anywhere else.

### 5.4 Serialization

- Pretty-printed with sorted keys, LF endings, trailing newline. The output is committed to git; a stable byte-for-byte serialization is required so that regenerating an unchanged project produces an empty diff.
- UTF-8, unescaped non-ASCII. Titles legitimately contain em dashes and typographic quotes.
- Written atomically.

---

## 6. Ordering

Resolved in this order, first rule that applies to **all** included episodes wins:

1. **Explicit `track` numbers.** If every included episode declares `track`, sort by it. Duplicates are a hard error naming both files — silently picking one produces a wrong playlist.
2. **`filePattern` order.** When `filePattern` is an explicit array (`granville`), that array is the order. Episodes absent from it sort after, by rule 3.
3. **Natural filename sort** of the stems — digit runs compared numerically, so `chapter-2` precedes `chapter-10`.

`trackNum` in the output is always the 1-based position in the final order, regardless of which rule produced it. It is a rendering convenience, never the sort key a reader must apply.

---

## 7. Durations

- Probed from the exported audio via `AVURLAsset.load(.duration)`, converted to integer milliseconds, rounded to nearest.
- An asset that cannot be read yields a track with **no** `duration` key rather than a zero or a failed run. `duration` is optional in JSPF and Sonido treats it as a display hint that `AVAsset` overrides once loaded.
- This is the one place generation touches AVFoundation. It is available on both supported platforms and adds no new package dependency.
- Probing is concurrent across tracks, bounded, and must not dominate runtime for an 81-episode project.

---

## 8. `proyecto playlist`

New subcommand registered in `ProyectoCLI.subcommands`.

```
proyecto playlist [<path>] [--dry-run] [--check] [--quiet]
```

| Flag | Behavior |
|---|---|
| *(none)* | Regenerate `PLAYLIST.jspf` at the project root |
| `--dry-run` | Write nothing; print the JSPF to stdout |
| `--check` | Write nothing; exit non-zero if the on-disk file differs from what would be generated. For CI. |
| `--quiet` | Suppress the per-track summary; warnings and errors still print |

### 8.1 Regeneration is total

**The whole file is rewritten from scratch on every run.** Incremental upsert is prohibited: it accumulates entries for files that no longer exist, which is precisely how the `granville` CDN prefix acquired `episode_1_04_shrinkage` and `episode_1_05_the_apartment` objects for episodes deleted from the repository months earlier.

A run therefore cannot preserve hand edits to `PLAYLIST.jspf`. That is intended — the file is derived output. Anything that needs to survive belongs in front matter.

### 8.2 Failure behavior

**A missing title blocks generation.** Getting titles into the playlist is the
substantive work this command does — everything else is derivable. An episode
that would be a track and has no title is missing authoring input, and no
playlist is written until it is supplied.

Hard failure (non-zero exit, **no file written**):

- No `PROJECT.md`, or it fails to parse
- An episode matching `filePattern` has **no YAML front matter block**
- An episode has front matter but no `title`
- An episode's front matter declares a `type` other than `episode` while still
  matching `filePattern` — ambiguous, and silently guessing is worse than stopping
- Duplicate `track` numbers among included episodes
- Zero tracks would be emitted

Every hard failure names **every** offending file in one report, not just the
first. Authoring titles for nine episodes should take one run to discover, not
nine.

Warning (exit zero, file written):

- An episode's audio is missing → track omitted
- No `.vtt` sidecar → `transcript` omitted
- No artwork sidecar → `image` omitted; the standard's playlist fallback covers it (§5.3)
- An `image` override naming a file that does not exist → warning, key omitted
- A duration could not be probed → `duration` omitted

The line between the two is whether the missing thing can be **authored** or
merely **produced**. A title is authored: no later step supplies it, so
proceeding would silently ship a playlist that is wrong — either missing
episodes or carrying a machine-guessed title. Audio is produced: its absence
means generation has not finished yet, which is a normal working state that
must still yield a usable playlist for the episodes that are ready.

Explicitly rejected: deriving a title from the filename stem. A stem yields
`Bumper Donnie And Arnie 1` and `Hunting Dilfs`, which are wrong in a way no
one would notice until a listener saw them.

---

## 9. Validation

### 9.1 `proyecto validate` additions

- Every episode matching `filePattern` has front matter with `type: episode` and a `title`.
- No duplicate `track` numbers.
- Every included episode has corresponding audio in `audioDir`.
- `PLAYLIST.jspf`, if present, matches what would be generated — the `--check` comparison, surfaced as a validation warning.
- Artwork that is present is square and at least 1400 px on a side (§5.3); anything smaller is a warning naming the file, since it cannot be submitted to Apple Podcasts.
- No `track.image` duplicates `playlist.image` — a redundant write that defeats the standard's fallback.

### 9.2 Layout warning

`validate` warns when a project's publish configuration would break §2.1 — specifically, a `.github/workflows/*.yml` whose S3 sync sets a `DEST_DIR` that does not preserve `audioDir`. This is heuristic and advisory; it cannot be authoritative, and it must never fail the run. It exists because the failure it catches is silent, remote, and only observable as 404s in a player.

---

## 10. Migration

Three conventions exist across `podcasts/*` today. Only the first conforms.

| Convention | Projects | Migration |
|---|---|---|
| YAML front matter | `daily-dao` (83 files) | None. Add `kind` where an episode is a bumper or intro. |
| Fountain title page (`Title:`, `Credit:`, `Author:`) | `confessions`, `meditations` | Mechanical: `Title:` → `title`, `Author:` → `artist`. The title page is **left in place** — it is screenplay content and out of scope (§3). |
| Centered text only (`>"HUNTING DILFS"<`) | `granville` | Not mechanical, and **generation is blocked until it is done** (§8.2). The centered heading is inconsistently formatted — quoted and unquoted, ALL CAPS and Title Case, `Bone-N-Brew` where the intended title is `Bone 'n' Brew`. Titles must be authored by a human, not extracted. |

`proyecto migrate` gains an `--episodes` mode covering the mechanical case and reporting the rest for human authoring. It must be idempotent and must never overwrite an existing `title`.

`granville`'s hand-written `PLAYLIST.jspf` is the reference output for acceptance (§11.1) and must be reproduced exactly by generation once its episode front matter is authored — otherwise the specification and the working example disagree.

---

## 11. Acceptance criteria

1. Running `proyecto playlist` in `granville`, after its episode front matter is authored, byte-for-byte reproduces the hand-written `PLAYLIST.jspf` that Sonido was verified against on 2026-09-06.
2. Running it twice produces no diff on the second run.
3. `daily-dao` (81 chapters, glob `filePattern`, existing front matter) generates a correctly ordered 81-track playlist with no schema changes to its episode files.
4. Every `track.location` **and every `image`** is relative; no absolute URL appears in any output.
5. `image` is emitted as a JSPF **string**, never an array, at both playlist and track level.
6. An episode with no artwork sidecar omits `track.image` entirely rather than repeating `playlist.image`, and a consumer rendering that track falls back to the show image per XSPF.
7. `granville`, whose nine tracks each have their own artwork plus a show cover, round-trips to exactly nine `track.image` values and one `playlist.image`.
8. `daily-dao`'s `source:` front matter block survives a parse/serialize cycle byte-identical.
9. An episode whose audio is missing is omitted with a warning and exit code 0; the remaining tracks are correct.
10. An episode with `type: episode` and no `title` fails the run with a message naming the file, and no file is written.
11. An episode matching `filePattern` with **no front matter block at all** fails the run identically — it is not skipped, and no partial playlist is produced.
12. A project with several untitled episodes reports **all** of them in a single run.
13. `granville` in its current state (centered-text headings, no front matter) fails generation — proving the block is real and not merely documented.
14. Duplicate `track` numbers fail the run naming both files.
15. `--check` exits non-zero on a stale `PLAYLIST.jspf` and zero on a current one.
16. Generation reads no byte of any episode file below its closing front matter delimiter — asserted by a test whose fixture contains a screenplay body that would produce a different playlist if parsed.
17. `proyecto validate` warns on a workflow whose `DEST_DIR` would flatten `audioDir`.

---

## 12. Open questions

1. **Does Produciesta call this automatically?** `produciesta export` is per-episode and cannot know project-wide order, so it cannot write the playlist itself — it would have to shell out to `proyecto playlist` after each export, which is N invocations for N episodes. The alternative is an explicit step in the generation skill. **Recommendation**: explicit step, with `proyecto validate` catching staleness, because per-export invocation does redundant work and still cannot guarantee currency if the last export fails.
2. **Does `granville` need `kind` on its bumpers?** The four `*_bumper_donnie_and_arnie_*` tracks are animated interstitials, not scenes. Sonido does not yet use `kind` for anything. Authoring it now costs nothing; deciding what a player does with it is a Sonido question.
3. **Multi-season and multi-language projects.** `ProjectFrontMatter` has `seasons` and `languages`, and Sonido's §4.2 permits exactly one `PLAYLIST.jspf` per source root. Does a multi-season project emit one playlist with album grouping, or one root per season? Not blocking for `granville` or `daily-dao`; blocking before `lingua-matra`, which is per-language.
4. **Does `excludeFromPlaylist` earn its place** (§4.3), or is absence from `filePattern` sufficient to exclude an episode? The flag is only meaningful for glob-pattern projects, where there is no list to omit a file from.

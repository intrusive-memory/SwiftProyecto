# REQUIREMENTS — Per-language voice prompts on CastMember

**Repo:** SwiftProyecto · **Status:** ITERATION 2 (re-attempt) · **Target version:** v3.8.0 (additive, from current `3.8.0-dev`)

Self-contained, single-repo requirement. Everything here is buildable and
**fully testable inside SwiftProyecto** with no dependency on SwiftEchada or any
voice/TTS runtime. Downstream consumption (echada's Phase A selection + `--accent`)
is a separate REQUIREMENTS.md in SwiftEchada and is **out of scope here**.

## Iteration 2 status (2026-06-12)

Iteration 1 (mission BABEL BROADCAST 01) completed the feature code — `voicePrompts`
field, `voicePrompt(forLanguage:)` selection, Codable, parser write/read, and 10 tests
(commit `e1a0af8`) — but was **rolled back** (verdict in `bda46d27`) solely because CI
could not pass: a pre-existing Swift 6 incompatibility in the transitive
`swift-tokenizers-mlx` dependency (`TokenizerBridge.swift: call can throw, but it is not
marked with 'try'`) blocked `make test`. The feature itself was orthogonal and never the
cause.

**That blocker is now gone.** The Foundation Models migration that shipped in v3.7.0
removed the SwiftBruja/MLX-tokenizer chain — current `Package.swift`/`Package.resolved`
have no `swift-tokenizers-mlx`. On a clean tree (post `/dependency-purge`, SwiftAcervo
floor bumped 0.16.0 → 0.19.2) `make test` builds and runs the suite (33 tests, 6 suites);
the only red is a stale `testVersion()` assertion (`== "3.6.0"` vs the `3.8.0-dev`
constant) — pre-existing bookkeeping the release bump fixes, unrelated to this feature.

**Targets corrected:** v3.6.0 and v3.7.0 are already cut and do NOT contain this feature
(the v3.7.0 tag has no `voicePrompts`); the misleading release titles refer to the FM
migration. The live line is `3.8.0-dev`, so this ships in **v3.8.0**.

**Iteration 2 plan:** recover the feature code from commit `e1a0af8` / the mission branch,
rebase onto current `development`, re-run the 10 acceptance tests (now executable), fix the
`testVersion()` assertion as part of the version bump, ship v3.8.0. When work begins, move
this file out of `docs/incomplete/` back to root `REQUIREMENTS.md`.

## Precondition (gate) — ✅ PASSED (2026-06-12)

Spike confirmed: a Spanish voice *prompt* (`--language es`) is dramatically better than
an English prompt for Spanish output — verdict "MUCH, MUCH better" on the A/B clips
(English-prompt arm vs Spanish-prompt arm, same character concept). The reference-audio
fallback is **not** needed for this case. This work is greenlit.

## Problem

`CastMember` carries a single `voiceDescription` (aka `voicePrompt`) string used to
condition voice generation. When a character is cast in a non-English language, that
single English prompt conditions the TTS model toward English phonology — producing a
"gringo" accent. The data model has no way to hold a per-language prompt, even though a
single character can be cast into multiple languages.

## Goal

Let a `CastMember` optionally carry a **per-language voice prompt**, keyed by BCP-47
language, with the existing single prompt as the fallback. Read and write it losslessly
through the PROJECT.md front-matter round-trip. No behavior change for existing files.

## Scope

### In scope
- New optional field on `CastMember`: `voicePrompts: [String: String]?`.
- A pure selection helper: `voicePrompt(forLanguage:)`.
- `Codable` read support (decode) + back-compat with files lacking the field.
- `ProjectMarkdownParser` **write** support (the hand-rolled `generate()` emitter at
  `Sources/SwiftProyecto/Utilities/ProjectMarkdownParser.swift:162`) and confirmation of
  the **read** path (`parseYAML` → `ProjectFrontMatter(json:)` Decodable).
- Tests for every unit below.

### Out of scope (do NOT do here)
- Any audio generation, accent directive, or `--accent` flag (SwiftEchada's REQUIREMENTS).
- `TTSConfig` changes / project-level prompt defaults.
- Prompt translation or content generation. Authors write the prompts by hand.
- Changing `voiceDescription`/`voicePrompt` semantics or the legacy dual-key behavior.

## Data model

```yaml
cast:
  - character: BERNARD
    gender: M
    voicePrompt: "weary older man, gravelly low baritone"   # unchanged base/fallback
    voicePrompts:                                            # NEW, optional
      es: "hombre mayor y cansado, voz grave y áspera"
      en: "weary older man, gravelly low baritone"
```

- Field: `public var voicePrompts: [String: String]?` (nil when absent — no behavior change).
- Keys are BCP-47 language codes. Lookup is by **base language** (region subtag stripped):
  `es-MX` and `es-419` both resolve via `es`. Keys are matched case-insensitively.
- `init` gains `voicePrompts: [String: String]? = nil` (back-compat default).

## Selection helper (pure, the core testable unit)

```swift
/// Resolve the voice prompt for a language. Tries the exact (normalized) key,
/// then the base-language key, then falls back to `voiceDescription`.
/// - Parameter language: BCP-47 code (e.g. "es", "es-MX"). Case-insensitive.
/// - Returns: The best-matching prompt, or nil if none and no voiceDescription.
public func voicePrompt(forLanguage language: String) -> String?
```

Resolution order (first non-nil wins):
1. `voicePrompts[normalized(language)]`
2. `voicePrompts[baseLanguage(language)]`  (split on `-`, take first, lowercase)
3. `voiceDescription`

`normalized(x)` = `x.trimmed.lowercased()`. Empty/whitespace language → treat as base lookup miss, fall through to `voiceDescription`.

## Codable

- Add `voicePrompts` to `CodingKeys`.
- `init(from:)`: `decodeIfPresent([String:String].self, forKey: .voicePrompts)`.
- `encode(to:)`: `encodeIfPresent(voicePrompts, forKey: .voicePrompts)`.
- Absent field decodes to `nil`; existing `voicePrompt`/`voiceDescription` dual-key logic
  is untouched.

## Parser

- **Write** (`generate()`): when `member.voicePrompts` is non-nil/non-empty, emit a nested
  `voicePrompts:` block under that member, keys sorted for deterministic output. Match the
  existing indentation style in the hand-rolled emitter.
- **Read** (`parseYAML` → Decodable): nested map must survive YAML→JSON→`CastMember` decode.
  Verify; no code change expected, but it is a required test.

## Related architectural debt (DO NOT fix here — separate requirement)

PROJECT.md serialization is **asymmetric**: reads go through `Universal` (YAML →
JSON → `Decodable`), but writes are a hand-rolled string emitter in
`generate()`. Two sources of truth (CodingKeys vs the emitter) that can silently
drift — this feature needing edits in *both* `Codable` and `generate()` is the
symptom. `Universal` provides YAML parsing but not a clean Encodable-model→YAML
encoder, which is why the write side was hand-rolled (also to control key order and
formatting).

This is real debt but **must not be bundled into this feature** — rewriting
`generate()` re-serializes every existing PROJECT.md across all projects (noisy,
potentially destructive diffs) and would violate testable-piece-by-piece. Track it
as its own SwiftProyecto requirement: *"Unify PROJECT.md serialization on a single
round-trip."* Acceptance for that separate effort: every fixture PROJECT.md survives
`parse → generate → parse` semantically unchanged, plus golden-file formatting
stability. Until then, this feature follows the established hand-emit pattern
(consistent with `voices:`/`tts:`).

## Acceptance criteria — testable piece by piece

Each is an independent unit test (XCTest, mirroring `Tests/SwiftProyectoTests/CastMemberTests.swift`).

1. **Init/default** — `CastMember(character:)` → `voicePrompts == nil`; init with a map stores it.
2. **Selection: exact key** — `voicePrompts["es"]` present → `voicePrompt(forLanguage:"es")` returns it.
3. **Selection: base fallback** — only `"es"` present → `voicePrompt(forLanguage:"es-MX")` returns the `"es"` value.
4. **Selection: case-insensitive** — `voicePrompt(forLanguage:"ES")` matches `"es"`.
5. **Selection: fallback to voiceDescription** — language absent from map → returns `voiceDescription`.
6. **Selection: nil** — no map and no `voiceDescription` → returns nil.
7. **Codable round-trip (full)** — encode→decode a member with `voicePrompts` yields an equal map.
8. **Codable back-compat** — decoding payload WITHOUT `voicePrompts` → `voicePrompts == nil`, `voiceDescription` intact (extends existing `testCodable_EncodeAndDecode_Minimal`).
9. **Parser write** — `generate()` output for a member with `voicePrompts` contains the nested block with sorted keys.
10. **Parser round-trip** — `parse(generate(frontMatter))` reproduces `voicePrompts` exactly (mirror `ProjectGenerationIntegrationTest`).

> Note: `Equatable`/`Hashable` on `CastMember` are character-name-only by design
> (`CastMember.swift:202-209`); equality tests for criteria 7/10 must compare the
> `voicePrompts` field directly, not via `==` on the struct.

## Test plan / gates

- `make test` green (scheme/targets per the SwiftProyecto Makefile — never `swift test`).
- `make lint` clean.
- New tests added to `Tests/SwiftProyectoTests/CastMemberTests.swift` (units 1–8) and the
  parser/integration test file (units 9–10).

## Release

- Additive, non-breaking → **minor bump to v3.8.0** (from current `3.8.0-dev`).
- Update the `testVersion()` assertion to the released version as part of the bump.
- Ship via the `ship-swift-library` flow. SwiftEchada bumps its dependency floor to
  v3.8.0 in its own REQUIREMENTS once this is tagged (also reconciling its stale
  `from: "0.13.0"` SwiftProyecto pin).

## Sequencing (informational — not a cross-repo requirement)

SwiftEchada consumes this after release. For parallel local dev, the consumer uses the
`sibling()` pattern against a local checkout; that lives entirely in SwiftEchada's
Package.swift and is not this repo's concern. This REQUIREMENTS.md ships and verifies on
its own.
</content>

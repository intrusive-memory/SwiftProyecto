---
name: per-language-voice-prompts
description: Add per-language voice prompts to CastMember (v3.5.4 → v3.6.0)
target_version: 3.6.0
status: READY_FOR_EXECUTION
---

# EXECUTION_PLAN.md — Per-Language Voice Prompts on CastMember

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

---

## Mission Summary

Add optional per-language voice prompt support to `CastMember`, allowing characters cast in non-English languages to use language-specific voice conditioning prompts instead of the single English fallback. Greenlit by A/B testing spike (REQUIREMENTS.md § Precondition). Minor version bump: v3.5.4 → v3.6.0. Non-breaking additive feature.

**Fully testable within SwiftProyecto** — no dependency on SwiftEchada or runtime voice/TTS systems.

---

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| Per-Language Voice Prompts | `/` | 4 | - | none |

---

## Sortie Definitions

### Sortie 1: Implement CastMember Model and Selection Logic

**Entry criteria**:
- [ ] First sortie — no prerequisites

**Tasks**:
1. Add `voicePrompts: [String: String]?` optional field to `CastMember` struct (nil when absent — no behavior change for existing files)
2. Update `CastMember.init()` to accept `voicePrompts: [String: String]? = nil` parameter for back-compatibility
3. Implement pure selection helper `voicePrompt(forLanguage language: String) -> String?` with resolution order:
   - Try exact (normalized) language key in `voicePrompts` map
   - Fall back to base-language key (split on `-`, take first, lowercase)
   - Fall back to `voiceDescription`
   - Return nil if none available
4. Normalize language input: trim and lowercase; treat empty/whitespace as base-language miss
5. Add `voicePrompts` to `CodingKeys` enum
6. Implement `init(from decoder:)` using `decodeIfPresent([String:String].self, forKey: .voicePrompts)`
7. Implement `encode(to encoder:)` using `encodeIfPresent(voicePrompts, forKey: .voicePrompts)`
8. Preserve existing `voicePrompt`/`voiceDescription` dual-key logic unchanged

**Exit criteria**:
- [ ] Code compiles without warnings
- [ ] `voicePrompts` field is optional, defaults to nil
- [ ] `voicePrompt(forLanguage:)` resolves in correct order (exact key → base key → voiceDescription → nil)
- [ ] Case-insensitive matching works ("ES" matches "es")
- [ ] Codable round-trip preserves the field
- [ ] No behavior change for existing CastMember instances lacking the field

**Agent model**: Sonnet

---

### Sortie 2: Update ProjectMarkdownParser for Per-Language Prompts

**Entry criteria**:
- [ ] Sortie 1 complete: CastMember model accepts `voicePrompts` field

**Tasks**:
1. Verify `parseYAML` → `ProjectFrontMatter(json:)` → `Decodable` read path works for nested `voicePrompts:` map (no code changes expected — standard JSON decoding)
2. Update `ProjectMarkdownParser.generate()` (Sources/SwiftProyecto/Utilities/ProjectMarkdownParser.swift:162) to emit `voicePrompts:` block when `member.voicePrompts` is non-nil and non-empty
3. Emit keys in **sorted order** for deterministic output
4. Match existing indentation and formatting style in hand-rolled emitter (matching `voices:` and `tts:` blocks)
5. Write a simple integration test case to verify write output format (PROJECT.md parse/generate cycle doesn't break)

**Exit criteria**:
- [ ] `generate()` output includes properly formatted `voicePrompts:` block for cast members with language-specific prompts
- [ ] Keys are sorted alphabetically
- [ ] YAML structure is valid (indentation, nesting matches rest of file)
- [ ] Round-trip parsing (parse existing PROJECT.md with voicePrompts) → `generate()` → re-parse produces identical `voicePrompts` map
- [ ] Existing PROJECT.md files without `voicePrompts` are unchanged by generate() (backward compatible)

**Agent model**: Sonnet

---

### Sortie 3: Write and Run Tests

**Entry criteria**:
- [ ] Sortie 1 complete: CastMember selection logic implemented
- [ ] Sortie 2 complete: Parser read/write verified

**Tasks**:
1. Add unit tests to `Tests/SwiftProyectoTests/CastMemberTests.swift` (mirror existing test patterns):
   - **Acceptance 1**: Init/default — `CastMember(character:)` → `voicePrompts == nil`; init with map stores it
   - **Acceptance 2**: Selection/exact key — `voicePrompts["es"]` present → `voicePrompt(forLanguage:"es")` returns it
   - **Acceptance 3**: Selection/base fallback — only `"es"` present → `voicePrompt(forLanguage:"es-MX")` returns the `"es"` value
   - **Acceptance 4**: Selection/case-insensitive — `voicePrompt(forLanguage:"ES")` matches `"es"`
   - **Acceptance 5**: Selection/fallback to voiceDescription — language absent from map → returns `voiceDescription`
   - **Acceptance 6**: Selection/nil — no map and no `voiceDescription` → returns nil
   - **Acceptance 7**: Codable round-trip (full) — encode→decode a member with `voicePrompts` yields equal map (compare field directly, not via struct `==` per REQUIREMENTS.md note)
   - **Acceptance 8**: Codable back-compat — decoding payload WITHOUT `voicePrompts` → `voicePrompts == nil`, `voiceDescription` intact
2. Add integration tests (in existing parser test file, mirror `ProjectGenerationIntegrationTest`):
   - **Acceptance 9**: Parser write — `generate()` output for a member with `voicePrompts` contains the nested block with sorted keys
   - **Acceptance 10**: Parser round-trip — `parse(generate(frontMatter))` reproduces `voicePrompts` exactly
3. Run `make test` (xcodebuild, not `swift test`) to verify all tests pass
4. Run `make lint` to verify code style clean

**Exit criteria**:
- [ ] All 10 acceptance criteria tests pass
- [ ] `make test` succeeds (all targets, all schemes)
- [ ] `make lint` passes
- [ ] No test coverage regressions

**Agent model**: Haiku (straightforward test writing against well-defined acceptance criteria)

---

### Sortie 4: Version Bump and Release

**Entry criteria**:
- [ ] Sortie 3 complete: All tests pass, make lint clean

**Tasks**:
1. Update version to next minor release version (v3.5.4 → v3.6.0) in appropriate manifest files (Package.swift, version.swift, or project config)
2. Verify all changes are staged and committed
3. Execute `ship-swift-library` flow (automated skill):
   - Version bump on `development` branch
   - Create PR, await CI pass
   - Merge to `main`
   - Tag release on `main`
   - Create GitHub release with generated notes
4. Confirm tag pushed and GitHub release published

**Exit criteria**:
- [ ] Version updated to v3.6.0 in all manifest files
- [ ] GitHub tag `v3.6.0` created on `main` branch
- [ ] GitHub release published (visible in Releases tab)
- [ ] SwiftEchada can depend on `v3.6.0` or later

**Agent model**: Haiku (straightforward version bump via existing release skill)

---

## Open Questions

_No blocking open questions identified during breakdown._

The REQUIREMENTS.md is thorough and well-specified. All key decisions are documented:
- Data model structure (field type, optional semantics)
- Selection order (exact → base → fallback)
- Codable strategy (decodeIfPresent / encodeIfPresent)
- Parser approach (hand-rolled emit matching existing style)
- Test locations (`CastMemberTests.swift` units 1-8; existing integration test file units 9-10)
- Version bump (minor)
- Release flow (ship-swift-library)

The existing test file locations can be discovered by the agent via grep if needed (e.g., searching for `ProjectGenerationIntegrationTest`).

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 1 |
| Total sorties | 4 |
| Open questions | 0 |
| Dependency structure | 4-layer sequential (Sortie 1 → 2 → 3 → 4) |
| Test cases (acceptance criteria) | 10 |
| Estimated effort | Medium (well-scoped, testable, no external dependencies) |
| Version bump | v3.5.4 → v3.6.0 (minor) |

---

## Notes

- **Fully testable within SwiftProyecto** — no runtime voice/TTS system needed
- **Backward compatible** — existing CastMember instances and PROJECT.md files unchanged
- **Design debt noted** — PROJECT.md serialization asymmetry (YAML→JSON→Decodable reads vs hand-rolled `generate()` writes) is documented in REQUIREMENTS.md § Related Architectural Debt as separate concern; this feature does **not** address that (out of scope per REQUIREMENTS.md)
- **Acceptance criteria** — Each sortie must produce machine-verifiable evidence for its exit criteria

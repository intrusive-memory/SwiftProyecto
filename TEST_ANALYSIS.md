---
type: doc
title: Test Analysis Report
date: 2026-10-12
---

# Test Analysis Report

**Repository**: SwiftProyecto
**Branch**: development (`40d2ee7`)
**Date**: 2026-10-12
**Test scheme**: SwiftProyecto-Package (Debug, macOS, XcodeBuildMCP `test_macos` with coverage)
**Tests considered**: 55 test files (43 in `SwiftProyectoTests`, 12 in `ProjectBrowserTests`); 990 test cases executed locally (988 passed, 2 failed, 0 skipped reported)

**Run notes**: `make lint` passed with no working-tree changes. The local run excluded `AcervoDownloadIntegrationTests` via `-skip-testing` (my choice, not a project convention). Coverage is from the run's xcresult: 82% overall, 35,786 / 43,634 executable lines.

## Executive summary

| Pass | Findings | Highest priority item |
|------|----------|------------------------|
| 0. Testing gaps (added) | 7 | `ProjectModel.parseBatchConfig(with:)` is public, untested, and duplicates a tested static implementation |
| 1. High-repetition tests | 0 | No `for _ in 0..<N` (N ≥ 1000) or repeat-loop stress tests found; clone detection not run |
| 2. Superfluous tests | 2 | `AcervoDownloadIntegrationTests` asserts `XCTAssertTrue(true, …)` |
| 3. Coverage gaps | 9 files | ProjectBrowser views at 0–20% and `ClaudeAPIBackend.parseResponse` at 0% |
| 4. Flaky-in-CI / red tests | 3 | 2 tests fail locally in `ProjectBundleTests`; the CI result check can pass a failing run |
| 5. Performance gating | 1 issue | CI runs `-only-testing:SwiftProyectoTests`, so all 12 `ProjectBrowserTests` files never run in CI |

**Narrative.** The suite is broad where it's tested (most `SwiftProyecto` core files are 85–100%), but the risk is concentrated in two places. First, the `ProjectBrowser` product target is at 30% and its tests never run in CI. Second, the CI pass/fail check in `tests.yml` is weak enough to hide a real failure. The most impactful single change is to fix the CI result check (`.github/workflows/tests.yml:85`) so it trusts `xcodebuild`'s exit status. After that, the two failing `ProjectBundleTests` should be triaged, since they show a real regression that CI cannot currently see.

---

## Pass 0 — Testing gaps (added first, per request)

This pass reads the source against the xccov line data. It asks which *correctness-relevant* code has no test exercising it, rather than just which files are low-coverage.

### G1. Public API duplicated in untested code — `ProjectModel+ParseBatch`
- `Sources/SwiftProyecto/Extensions/ProjectModel+ParseBatch.swift:16` — `public func parseBatchConfig(with:)` is **0%** covered. No caller in `Sources` or `Tests`.
- Its private helpers (`discoverFiles` :82, `isGlobPattern` :104, `glob` :108, `matchesPattern` :131) are also **0%**. They mirror the `static` helpers at :217–266, which are **77–95%** covered through `ParseBatchConfig`.
  - **Why it matters**: two copies of glob logic, one tested and one not. Any fix made to one drifts from the other.
  - **Action**: investigate whether external consumers call `ProjectModel.parseBatchConfig`. If not, delete the duplicate and forward to `ParseBatchConfig`. If so, add tests that pin it to the same behavior as the static path.

### G2. Untested validation — `ParseBatchArguments`
- `Sources/SwiftProyecto/Models/ParseBatchArguments.swift:104` — `validate()` is **0%** (13 executable lines). The `ValidationError` description (:122) and `projectURL` getter (:98) are also 0%.
  - **Why it matters**: this is the input gate for batch audio generation. Invalid args reach the pipeline unchecked.
  - **Action**: add tests for each validation rule, with one passing and one failing case per rule.

### G3. Untested LLM response parsing — `ClaudeAPIBackend`
- `Sources/SwiftProyecto/LLMBackend/ClaudeAPIBackend.swift:252` — `parseResponse(_:project:)` is **0%** (34 lines). `buildPrompt` (:123, 82 lines), `callClaudeAPI` (:207, 43 lines), and `logTokenUsage` (:290) are also 0%. `generate(project:)` is 30%.
  - **Why it matters**: `parseResponse` is the boundary where model output becomes project metadata. Malformed or partial model output is the failure mode, and nothing currently exercises it. Tests in `ClaudeAPIBackendTests` (615 covered lines) evidently cover other surfaces.
  - **Action**: unit-test `parseResponse` against fixture responses (valid JSON, fenced JSON, missing fields, non-JSON). Test `buildPrompt` for stable output given a fixed `ProjectAnalysis`.

### G4. Untested name-extraction heuristics — `CastExtractor`
- `Sources/SwiftProyecto/LLMBackend/CastExtractor.swift:321` — `isLikelyCharacterName(_:)` is **0%** (42 lines, seven closures all uncovered). `extractCastRegex(from:)` (:257, 26 lines) and `removeParentheticals(from:)` (:296) are also 0%.
  - **Why it matters**: these heuristics decide which screenplay names become cast members at generation time (`proyecto generate-project`). A wrong filter silently drops or invents characters.
  - **Action**: table-driven tests for `isLikelyCharacterName` covering real screenplay cue forms (`MARY (V.O.)`, `JOHN (CONT'D)`, lowercase action lines, and transitions like `CUT TO:`).

### G5. Model-readiness gating — `ModelManager`
- `Sources/SwiftProyecto/Infrastructure/ModelManager.swift` — **12.1%**. `isModelReady` (:73), `isModelCached` (:88), `ensureModelReady(progress:)` (:103), `modelDescriptor()` (:110), and `withModelAccess` (:125) are all 0%. `_loadModel` (:137–155) is 0%.
  - **Why it matters**: these decide whether generation runs at all. The file has only `ModelManagerBareDescriptorTests` (7 covered lines).
  - **Action**: `isModelCached` and `isModelReady` are likely testable against a temp cache directory with no network. Check whether SwiftAcervo's cache path can be injected; if it can't, that's the blocker to note.

### G6. ProjectBrowser product target — views with no coverage
- Zero coverage: `Views/ProjectHeader.swift` (87 lines), `Views/ProjectActionBar.swift` (66), `Views/ImageContentView.swift` (315), `Views/PDFContentView.swift` (82), `Handlers/DefaultHandlers.swift` (56).
- Near zero: `DefaultContentViews.swift` 1.6% (191 lines), `EditableTextContentView.swift` 8.4% (143), `ProjectBrowserSidebar.swift` 10.1% (149), `FileTreeView.swift` 15.1% (351), `AudioPlayerView.swift` 19.7% (689).
  - **Why it matters**: `ProjectBrowser` is a public library product that downstream apps (Produciesta) consume. `AudioPlayerView` is the largest file in the target and has the lowest meaningful coverage.
  - **Action**: `DefaultHandlers` and `ProjectActionBar` are cheap to cover with logic-level tests. The view files are better covered by a few snapshot-style construction tests than by line-by-line tests.

### G7. Bundle-extension logic is covered, but two of its tests are red
- `ProjectFileDiscovery` is 97.6% covered, so the code is exercised. Yet the two tests asserting its behavior fail (see Pass 4, F1). Treat the bundle path as **covered but currently broken**, not as a coverage gap.

---

## Pass 1 — High-repetition tests

### Copy-paste patterns
- Not exhaustively checked. The structural-clone check (≥3 tests with ≥80% identical bodies) requires a tool I did not run. The `ProjectBrowserTests` files each re-declare their own `tempRoot` setup and `makeDossier`/`makeFile` helpers. Consolidating these into one shared fixture is a likely win, but I have not verified the line overlap.
  - **Action**: investigate. Extract a shared `ProjectBrowserTestFixtures` if the overlap holds.

### High-iteration loops
- No findings. Grep for `0..<N` with N ≥ 1000 and `repeat {` in `Tests/` returned no matches.

---

## Pass 2 — Superfluous tests

- `Tests/SwiftProyectoTests/AcervoDownloadIntegrationTests.swift:25`, `:38`, `:51` — `XCTAssertTrue(true, …)`. The test's body only documents that Foundation Models are available; it never calls the API it names.
  - **Action**: delete, or replace with a real call to the availability API it describes.
- `Tests/SwiftProyectoTests/AcervoDownloadIntegrationTests.swift` — the file name says "download," but its contents test Foundation Models availability with no download. The name is misleading.
  - **Action**: merge into `AppleFoundationModelsBackendTests` (which already has availability tests) and delete the file.
- No version-string assertions against the library's own version were found. The `version` asserts in `ProjectMarkdownParserTests` (:915, :942, :992, :1028) test front-matter schema fields, not the package version, so they are not superfluous.

---

## Pass 3 — Coverage gaps

Coverage from the local `test_macos` run, `Debug`, all tests except the excluded Acervo file. Generated, vendored, and trivial files are excluded. Only files where a gap matters for correctness or public API are listed; see Pass 0 for the reasoning.

| File | Line coverage | Why it matters | Top uncovered |
|------|---------------|----------------|---------------|
| `SwiftProyecto/Infrastructure/ModelManager.swift` | 12.1% | Gates whether generation runs | `isModelReady`, `isModelCached`, `ensureModelReady`, `withModelAccess` |
| `SwiftProyecto/LLMBackend/ClaudeAPIBackend.swift` | 20.9% | LLM response parsing; a malformed response is the failure mode | `parseResponse`, `buildPrompt`, `callClaudeAPI` |
| `SwiftProyecto/LLMBackend/CastExtractor.swift` | 22.4% | Decides which screenplay names become cast members | `isLikelyCharacterName`, `extractCastRegex`, `removeParentheticals` |
| `SwiftProyecto/Models/ParseBatchArguments.swift` | 39.5% | Input validation for batch generation | `validate()` |
| `SwiftProyecto/Extensions/ProjectModel+ParseBatch.swift` | 47.3% | Public `parseBatchConfig`; duplicated logic | `parseBatchConfig(with:)`, `glob`, `matchesPattern` |
| `ProjectBrowser/Views/AudioPlayerView.swift` | 19.7% | Largest view in product target (689 lines) | Most playback/control paths |
| `ProjectBrowser/Views/FileTreeView.swift` | 15.1% | Primary navigation surface | Most of 351 lines |
| `ProjectBrowser/Views/ImageContentView.swift` | 0% | User-visible content rendering (315 lines) | All |
| `ProjectBrowser/Handlers/DefaultHandlers.swift` | 0% | Default action wiring for the product | All |

---

## Pass 4 — Flaky-in-CI predictions and red tests

### F1. Two failing tests in `ProjectBundleTests` (highest priority)
- `Tests/ProjectBrowserTests/ProjectBundleTests.swift:155–157` — `testCustomBundleExtensionsReplaceTheDefault`: `XCTAssertFalse(dossier.isBundle)` / `XCTAssertTrue(dossier.isDirectory)` / `XCTAssertTrue(files.contains { … manifest.json })` fail. With `bundleExtensions: ["scene"]`, `.dossier` should be a plain folder.
- `Tests/ProjectBrowserTests/ProjectBundleTests.swift:166–169` — `testEmptyBundleExtensionsTreatsDossierAsAFolder`: the descendant count is **0, expected 7**. `files` contains no entries under `characters/GARETH.dossier/`.
  - **Smell**: deterministic failure in one run, not confirmed flaky. The expected count of 7 implies discovery stopped descending into a folder that should be walked.
  - **Why it matters**: `ProjectFileDiscovery.swift` is 97.6% covered and this is the code the failing assertions target. The suite is green on the bundle path only because these tests are red.
  - **Action**: reproduce in isolation with `-only-testing:ProjectBrowserTests/ProjectBundleTests`. Check whether the bundle-extension check in `ProjectFileDiscovery` treats an empty set as "everything is a bundle" or "nothing is a bundle", since the two tests disagree.

### F2. CI result check can pass a failing run
- `.github/workflows/tests.yml:75` `set +e`, then `:85` `if grep -q "Test Suite.*passed\|TEST SUCCEEDED" test_output_macos.txt; then … exit 0`.
  - **Smell**: `Test Suite '…' passed` is printed per suite, including when other suites fail. A run with one failing suite and one passing suite matches the first alternative, and the step exits 0 regardless of `$TEST_EXIT_CODE`.
  - **Why it matters**: this is the CI gate for the correctness lane. F1's red tests would not fail CI even if `ProjectBrowserTests` were included.
  - **Action**: replace the grep with `exit $TEST_EXIT_CODE`, and keep the grep only for the human-readable summary. This is the single highest-leverage fix in the report.

### F3. Silent skip on a path-relative lookup
- `Tests/ProjectBrowserTests/ProjectFileDiscoveryIntegrationTests.swift:335` — `throw XCTSkip("Sources/ProjectBrowser not found relative to test file; skipping.")`.
  - **Smell**: the test locates source files by walking up from `#filePath`. If that walk fails in some build environment, the test skips and reports nothing.
  - **Action**: fail instead of skipping when the source root is missing, or use a `Bundle.module` resource.

### Also noted: concurrency warnings in test code
- The local run emitted about 130 warnings in `ProjectBrowserTests`, mostly `call to main actor-isolated initializer … in a synchronous nonisolated context`. The package sets `StrictConcurrency` and `swiftLanguageModes: [.v6]`, so these will become errors on a future toolchain. Not a flake, but it's a time bomb. Fixing it means marking the affected test classes `@MainActor`.

---

## Pass 5 — Performance test gating

- No perf tests were found. Grep for `measure {`, `measure(metrics:`, `PerformanceTests`, and `Benchmark` in `Tests/` returned no matches.
- No `perf` target exists in the Makefile.

### Gating issue: `ProjectBrowserTests` is excluded from CI
- `.github/workflows/tests.yml:79` — `-only-testing:SwiftProyectoTests`. The entire `ProjectBrowserTests` target (12 files) never runs in CI, and the CI build step (`:66`) builds only the `SwiftProyecto` scheme. Yet `ProjectBrowser` is a public product.
  - **Why it matters**: this is why F1's red tests are invisible to CI. The 0% views in Pass 0 G6 are unguarded.
  - **Action**: add a `ProjectBrowserTests` run to CI (a second `xcodebuild test` invocation or an additional `-only-testing:`), or record in `CLAUDE.md` that it's intentionally local-only. Given F1, adding it to CI is the stronger choice.

### Gating issue: `AppleFoundationModelsBackendTests` gate on macOS 27
- `Tests/SwiftProyectoTests/AppleFoundationModelsBackendTests.swift` — 8 `throw XCTSkip("Test requires macOS 27+")` guards (lines 84, 158, 175, 232, 252, 270, 346, 373), each on `isMacOSVersionAtLeast(major: 27)`.
  - **Why it matters**: the package's platform floor is macOS 26 (`Package.swift`), and CI runs on `macos-26`. On CI these 8 tests always skip, so the Foundation Models backend is untested in CI.
  - **Action**: investigate. If the APIs really need macOS 27, keep the guard and add a comment. If they don't, drop the guard.

---

## Consolidated action items

### Fix first (red / CI-blind)
- **F1** — Triage the two failing `ProjectBundleTests` tests (`ProjectBundleTests.swift:155`, `:166`).
- **F2** — Fix the CI pass/fail check (`.github/workflows/tests.yml:85`) to honor `$TEST_EXIT_CODE`.
- **Pass 5** — Add `ProjectBrowserTests` to CI (`.github/workflows/tests.yml:79`).

### Delete
- `Tests/SwiftProyectoTests/AcervoDownloadIntegrationTests.swift` — tautological asserts (:25, :38, :51), misnamed. Merge availability checks into `AppleFoundationModelsBackendTests`, then delete.
- Duplicate glob logic in `Sources/SwiftProyecto/Extensions/ProjectModel+ParseBatch.swift:82–131` — **investigate first** whether external consumers use `parseBatchConfig(with:)`. Delete only if they don't.

### Refactor
- Consolidate `ProjectBrowserTests` fixtures (`tempRoot`, `makeDossier`, `makeFile`) into one shared helper. Verify overlap first.
- Mark `ProjectBrowserTests` classes `@MainActor` to clear the ~130 concurrency warnings.
- `ProjectFileDiscoveryIntegrationTests.swift:335` — fail, not skip, when the source root is missing.

### Gate / investigate
- `AppleFoundationModelsBackendTests` — decide whether the macOS 27 guard is real (8 tests, lines listed in Pass 5).

### Add tests for (in priority order)
1. `ClaudeAPIBackend.parseResponse` and `buildPrompt` — `Sources/SwiftProyecto/LLMBackend/ClaudeAPIBackend.swift:252`, `:123`.
2. `CastExtractor.isLikelyCharacterName` and `extractCastRegex` — `Sources/SwiftProyecto/LLMBackend/CastExtractor.swift:321`, `:257`.
3. `ParseBatchArguments.validate()` — `Sources/SwiftProyecto/Models/ParseBatchArguments.swift:104`.
4. `ModelManager.isModelCached` / `isModelReady` — `Sources/SwiftProyecto/Infrastructure/ModelManager.swift:88`, `:73`. Check cache-path injection first.
5. `ProjectBrowser` `DefaultHandlers` and `ProjectActionBar` — cheap logic coverage for a public product.

---

## Status after fixes (2026-10-12)

Local run on `development` with uncommitted changes: **1026 passed, 0 failed, 0 skipped** (was 988 passed, 2 failed). Coverage of the product targets: `SwiftProyecto` 80.1% → 85.1%, `ProjectBrowser` 30.4% → 35.7%.

### Resolved
- **F1 — `ProjectBundleTests` red.** Root cause: `ProjectFileDiscovery.isBundle` honors `URLResourceValues.isPackage` before it checks the configured set. On this machine, an installed app registers `io.intrusive-memory.dossier` as a `com.apple.package` (confirmed with `mdls`; I did not identify which app). So `.dossier` folders were always bundles here, and the tests were environment-dependent. CI does not have that registration, so they would have passed there, and CI doesn't run them anyway. The tests now use an unregistered extension (`zzfixture`). The doc comment that said the set could "narrow" the default was wrong and now says the OS flag cannot be turned off.
- **F2 — CI gate.** `tests.yml` now sets `pipefail`, gates on `xcodebuild`'s exit status, and no longer decides pass/fail with a grep. Verified the YAML parses and the failure branch still ends in `exit $TEST_EXIT_CODE`. Not verified on a macOS-26 runner.
- **Pass 5 — ProjectBrowserTests excluded from CI.** Added `-only-testing:ProjectBrowserTests`. Not verified on a headless macOS-26 runner. Some `ProjectBrowser` tests may behave differently without a display.
- **F3 — silent skip.** `ProjectFileDiscoveryIntegrationTests` now fails when the source root is missing instead of skipping.
- **Pass 2 — tautological Acervo tests.** Deleted `AcervoDownloadIntegrationTests.swift` (three `XCTAssertTrue(true)` asserts). The skip for it is removed from the session defaults. Copies still exist under `.claude/worktrees/cast-md-requirements/`, which I did not touch.
- **G1 — duplicated glob logic.** The instance helpers in `ProjectModel+ParseBatch.swift` are deleted. `parseBatchConfig(with:)` delegates to the tested `ParseBatchConfig` helpers. Public signature unchanged.
- **G2 — `ParseBatchArguments.validate()`.** Six tests added.
- **G3 — `ClaudeAPIBackend`.** Response decoding moved to `parseMetadataJSON(_:)`, which has tests for bare JSON, fenced JSON, invalid JSON, and a missing required field. `buildPrompt` is internal and has tests.
  - **Bug fixed:** fenced output dropped every line containing "json", so a description like "A JSON-based show" broke decoding. Only fence lines are removed now.
- **G4 — `CastExtractor` heuristics.** Helpers are internal and tested.
  - **Bug fixed:** `CUT`, `FADE`, and `DISSOLVE` prefixes without a trailing space rejected real names such as `CUTHBERT` and `FADERS`.
  - **Behavior change:** `#` is now a valid name character, as the existing comment already said (`DOCTOR #2`).
- **G6 (partial) — `DefaultHandlers`, `ProjectHeader`, `ProjectActionBar`.** Tests added. The two views are smoke tests only.

### Still open
- **G5 — `ModelManager`.** `isModelCached`, `ensureModelReady`, and `withModelAccess` need an injectable cache directory. SwiftAcervo doesn't expose one here, so these stay untested.
- **G6 — view depth.** `AudioPlayerView`, `FileTreeView`, `ImageContentView`, and `PDFContentView` are still low. Smoke tests don't cover their behavior.
- **Foundation Models gate.** Eight tests in `AppleFoundationModelsBackendTests` skip unless macOS 27+, but the package floor and CI runner are macOS 26. Dropping the guard needs a decision about whether those APIs exist on 26.
- **Concurrency warnings.** Roughly 130 strict-concurrency warnings in `ProjectBrowserTests` remain.
- **Branch protection name.** `CLAUDE.md` lists a required check named "macOS Unit Tests", but the job is named "Test on macOS". I did not rename the job, so branch protection is unchanged. Check it before merging.
- **Nothing committed.** Changes are in the working tree on `development`.

---
feature_name: OPERATION MANIFEST AIRDROP
starting_point_commit: 60d5c9d71298a1a925073c196489523eda2965e2
mission_branch: mission/manifest-airdrop/1
iteration: 1
---

# EXECUTION_PLAN: SwiftAcervo 0.8.0 Migration

**Version**: 2.0 (refined)
**Date**: 2026-04-25
**Status**: READY FOR EXECUTION
**Requirements Source**: `ACERVO_AUDIT.md`
**Supersedes**: `Docs/complete/EXECUTION_PLAN_CDN_MIGRATION.md` (the v3.4.0 CDN integration plan is complete)

---

## Terminology

**Mission** — Adopt SwiftAcervo 0.8.0's manifest-first contract, remove direct filesystem path handling from consumer code, and guarantee that every model SwiftProyecto needs is pre-published on the CDN.

**Sortie** — Atomic task executed by a single agent. Each sortie must have a clear entry/exit contract and be independently testable.

**Work Unit** — Phase grouping: Dependency Bump (1), Consumer Path Elimination (2), Test Sandboxing (3), CDN Validation (4), Documentation (5).

---

## Mission Overview

SwiftAcervo 0.8.0 (released 2026-04-23) ships non-breaking additions but materially shifts the integration contract: **the CDN manifest is the only authoritative source**, bare `ComponentDescriptor`s are first-class, and consumer code should never construct or slugify model paths by hand. A consumer requests a model by slug (`org/repo` or registered component id) and receives a list of files through `ComponentHandle`; it never walks `sharedModelsDirectory` itself.

SwiftProyecto today still carries 0.7-era patterns: hardcoded `ComponentFile` arrays with sizes and SHA-256s, hand-built paths via `Acervo.sharedModelsDirectory.appendingPathComponent(slugify(id))`, and two latent bugs that only work by accident (see `ACERVO_AUDIT.md` §3). This mission eliminates direct path manipulation, adopts the bare-descriptor pattern, and verifies the CDN side of the contract.

**Success Criteria**:
- `Package.swift` declares `SwiftAcervo from: "0.8.0"` and `xcodebuild test` passes.
- No consumer file (in `Sources/` or `Tests/`) calls `Acervo.sharedModelsDirectory.appendingPathComponent(...)`, `Acervo.slugify(...)`, or otherwise constructs a model path from pieces. Every file access goes through `ComponentHandle` (`withComponentAccess`) or `Acervo.modelDirectory(for:)` with a full `org/repo` slug.
- `ComponentDescriptor` for the canonical model uses the bare initializer (no declared `files:`, no hardcoded sizes or SHA-256s).
- `AcervoDownloadIntegrationTests` runs against `Acervo.customBaseDirectory`-scoped temp directories and leaves no multi-GB residue on the host.
- Every model slug this library declares has a verified, current manifest on R2. Any missing slug is uploaded via the `acervo` CLI before the sortie closes.
- `AGENTS.md` documents the App Group entitlement requirement (already landed in this plan's preamble commit — see Sortie 5.1 notes).

---

## Parallelism & Execution Metadata

**Critical path** (sequential, supervising agent only):
`1.1 → 2.0 → 2.1a → 2.1b → 2.2 → 2.3 → 4.1 → 3.1 → 5.1 → 5.2a → 5.2b → 5.2c`

**Agent allocation**: 1 supervising agent + 1 sub-agent (max 2 concurrent at any moment).

**Build constraint**: Any sortie that runs `xcodebuild` (build/test/resolve) MUST run on the supervising agent only — concurrent builds collide on the Xcode lock and DerivedData cache.

| Sortie | Eligible Agent | Touches Build? |
|--------|---------------|----------------|
| 1.1 | Supervising only | Yes (`-resolvePackageDependencies`, `xcodebuild test`) |
| 2.0 | Supervising only | Yes (build verification) |
| 2.1a | Supervising only | Yes (build verification) |
| 2.1b | Supervising only | Yes (`xcodebuild test`) |
| 2.2 | Supervising only | Yes (build verification) |
| 2.3 | Supervising only | Yes (`xcodebuild test`) |
| 3.1 | Supervising only | Yes (`xcodebuild test`) |
| 4.1 | Sub-agent eligible | No (CLI + curl + workflow YAML edit) |
| 5.1 | Sub-agent eligible | No (doc verification) |
| 5.2a | Sub-agent eligible | No (AGENTS.md edits) |
| 5.2b | Sub-agent eligible | No (AGENTS.md edits) |
| 5.2c | Sub-agent eligible | No (`git mv` + stub creation) |
| 5.3 | Sub-agent eligible | No (optional issue filing) |

**Parallel execution opportunities** (2 windows):

1. **After 2.1b completes**: supervising agent runs 2.2; sub-agent 1 runs 4.1 in parallel (4.1 depends only on `ProjectModel` constant from 2.0, which is already in place; it touches R2 + workflow YAML, no Xcode build).
2. **After 2.3 completes**: supervising agent runs 3.1; sub-agent 1 runs 5.3 (optional follow-up). 5.3 has no code dependencies.

**Note**: 5.2a/b/c run sequentially after 5.1 because they all edit `AGENTS.md` and would collide on the same file. They are sub-agent eligible individually but not parallel-with-each-other.

---

## Work Units & Sorties

### WORK UNIT 1: Dependency Bump

**Objective**: Move to SwiftAcervo 0.8.0 with no behavior change.

#### Sortie 1.1: Bump `Package.swift` to 0.8.0

**Priority Score**: 27.5
**Agent Eligibility**: Supervising agent only

**Entry Criteria**:
- Working tree clean on a feature branch off `main` (or `feature/acervo-080-migration`).
- `xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'` passes against the current 0.7.3 pin.

**Actions**:
- Change `Package.swift` dependency to `.package(url: ..., from: "0.8.0")`.
- Delete the stale `// Requires v2 access patterns (withComponentAccess)` comment.
- Run `xcodebuild -resolvePackageDependencies -scheme SwiftProyecto`.
- Run the full test suite via `xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'`.

**Exit Criteria**:
- ✅ `Package.resolved` pins SwiftAcervo to a 0.8.x revision (verify: `grep -A1 'SwiftAcervo' Package.resolved` shows version starting with `0.8.`).
- ✅ Library and `proyecto` CLI build clean.
- ✅ Full test suite passes EXCEPT one expected failure: **`ModelManager.isModelAvailable()` returns `false` instead of `true` for an available model**, because it uses `componentId` (no slash) instead of `repoId`. This is the known latent bug from `ACERVO_AUDIT.md` §3.1 and will be fixed in Sortie 2.1a. All other tests must pass.

**Effort**: 0.5 hours | **Model**: Haiku

---

### WORK UNIT 2: Consumer Path Elimination

**Principle (from user directive, 2026-04-24)**: *"Consumers of Acervo should never actually address any path directly. SwiftAcervo should handle paths with a simple init of the slug and give you back a list of files in the model."*

No code in `Sources/` or `Tests/` may call `Acervo.sharedModelsDirectory.appendingPathComponent(...)`, `Acervo.slugify(...)`, or otherwise build a model path from pieces. The replacement primitives are:

1. `try await Acervo.ensureComponentReady(componentId)` — make the model present.
2. `let dir = try Acervo.modelDirectory(for: repoId)` — resolve a directory URL from a full `org/repo` slug when a framework API requires a path.
3. `try await AcervoManager.shared.withComponentAccess(componentId) { handle in … }` — scoped file access via `ComponentHandle.url(for:)`, `handle.url(matching:)`, `handle.urls(matching:)`.

**Model Standardization (from user directive, 2026-04-25)**: *"Let's decide on an open-source model that will be used for our PROJECT.md management. Once we've established the right model for this, let's make that a CONSTANT for the project and everywhere the model is used, refer to the model as the constant so that we can control the model from the project from a single text entry in the code."*

The canonical model for SwiftProyecto is **Llama-3.2-1B-Instruct-4bit** (`mlx-community/Llama-3.2-1B-Instruct-4bit`). This model is sufficient for PROJECT.md metadata generation (focused, small prompts), has a smaller download footprint (~1 GB vs. ~2.3 GB for Phi-3), and offers a larger context window (8K tokens).

All model references throughout the codebase (ModelManager, CLI commands, tests) must use a single constant `ProjectModel: ComponentDescriptor` to ensure consistency and provide a single point of change.

#### Sortie 2.0: Create canonical ProjectModel constant

**Priority Score**: 24.5
**Agent Eligibility**: Supervising agent only

**Entry Criteria**:
- Sortie 1.1 complete (SwiftAcervo 0.8.0 resolved; `Package.resolved` shows 0.8.x).

**Actions**:
- In `Sources/SwiftProyecto/Infrastructure/ModelManager.swift`, add a public constant before the `Phi3ModelRepo` enum:
  ```swift
  import SwiftAcervo

  /// The canonical model for PROJECT.md generation across SwiftProyecto.
  ///
  /// This constant provides a single source of truth for the model used by:
  /// - `proyecto download` command
  /// - `proyecto init` command
  /// - All ModelManager operations
  /// - Integration tests
  ///
  /// To change the model used by SwiftProyecto, update this constant.
  public let ProjectModel = ComponentDescriptor(
      id: "llama-3.2-1b-instruct-4bit",
      type: .languageModel,
      displayName: "Llama 3.2 1B Instruct (4-bit)",
      repoId: "mlx-community/Llama-3.2-1B-Instruct-4bit",
      minimumMemoryBytes: 1_500_000_000,
      metadata: [
          "quantization": "4-bit",
          "context_length": "8192",
          "architecture": "Llama",
          "version": "3.2",
      ]
  )
  ```
- Delete the `Phi3ModelRepo` enum entirely (it will be replaced by `ProjectModel`).
- No other changes in this sortie — subsequent sorties will migrate call sites to use `ProjectModel`.

**Exit Criteria**:
- ✅ `grep -n "public let ProjectModel" Sources/SwiftProyecto/Infrastructure/ModelManager.swift` returns one match.
- ✅ `grep -rn "Phi3ModelRepo" Sources/` returns no matches (enum deleted).
- ✅ Library does NOT yet build clean — references to `Phi3ModelRepo` in the rest of the file/codebase will produce compile errors. This is expected and will be fixed in 2.1a. (Run `xcodebuild build -scheme SwiftProyecto -destination 'platform=macOS'` and confirm errors are limited to "cannot find 'Phi3ModelRepo' in scope".)
- ✅ Constant is properly documented with usage guidance (doc comment block above declaration).

**Effort**: 0.25 hours | **Model**: Haiku

---

#### Sortie 2.1a: Refactor ModelManager to use ProjectModel and bare-descriptor pattern

**Priority Score**: 23
**Agent Eligibility**: Supervising agent only

**Entry Criteria**:
- Sortie 2.0 complete (`ProjectModel` constant exists; `Phi3ModelRepo` enum deleted).
- **CDN fallback verification**: CDN manifest fetchable via `Acervo.fetchManifest(for: ProjectModel.repoId)`. Verify once interactively before starting:
  ```bash
  curl -I https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models/mlx-community_Llama-3.2-1B-Instruct-4bit/manifest.json
  ```
  If it returns HTTP 404 or any non-200, run Sortie 4.1 first (out of order) to publish the model: `acervo ship mlx-community/Llama-3.2-1B-Instruct-4bit`. Do not proceed with 2.1a until the curl returns HTTP 200.

**Actions**:
- In `Sources/SwiftProyecto/Infrastructure/ModelManager.swift`:
  - **Delete** the entire `phi3RequiredFiles: [ComponentFile]` constant (no longer needed with bare descriptor).
  - **Replace** `phi3ComponentDescriptors` array with single-component registration of `ProjectModel`:
    ```swift
    private let _registerProjectModel: Void = {
      Acervo.register([ProjectModel])
    }()
    ```
  - **Rename** `isModelAvailable(_:)` to `isModelReady()` (remove parameter — always checks `ProjectModel`):
    ```swift
    public func isModelReady() -> Bool {
      Acervo.isComponentReady(ProjectModel.id)
    }
    ```
    This also fixes the §3.1 audit bug: `isComponentReady` is the registry-aware check and works correctly for the bare descriptor.
  - **Rename** `ensureModelReady(_:)` to `ensureModelReady()` (remove parameter — always ensures `ProjectModel`):
    ```swift
    public func ensureModelReady() async throws {
      try await Acervo.ensureComponentReady(ProjectModel.id) { progress in
        // Existing progress handling
      }
    }
    ```
  - **Update** `withModelAccess(_:perform:)` to use `ProjectModel.id` instead of taking a parameter.
  - **Update** `_loadModel(_:)` to reference `ProjectModel` and its hydrated `files` array.
- No other file in `Sources/SwiftProyecto/` should be touched in this sortie.

**Exit Criteria**:
- ✅ `grep -rn "phi3RequiredFiles\|ComponentFile\|Phi3ModelRepo" Sources/SwiftProyecto/Infrastructure/` returns nothing.
- ✅ `grep -rn "sha256\|expectedSizeBytes" Sources/SwiftProyecto/Infrastructure/` returns nothing.
- ✅ `grep -n "ProjectModel" Sources/SwiftProyecto/Infrastructure/ModelManager.swift | wc -l` returns ≥ 5 (constant declaration + at least 4 usages).
- ✅ `xcodebuild build -scheme SwiftProyecto -destination 'platform=macOS'` exits 0.
- ✅ No new unit test added in this sortie — that is 2.1b.

**Effort**: 0.75 hours | **Model**: Haiku

---

#### Sortie 2.1b: Add unit test for bare descriptor hydration state

**Priority Score**: 8
**Agent Eligibility**: Supervising agent only (runs `xcodebuild test`)

**Entry Criteria**:
- Sortie 2.1a complete (`ModelManager` migrated; build clean).

**Actions**:
- Create a new test file at `Tests/SwiftProyectoTests/ModelManagerBareDescriptorTests.swift`.
- Add an XCTestCase that asserts immediately after `ModelManager()` construction (and before any `ensureModelReady` call):
  ```swift
  import XCTest
  import SwiftAcervo
  @testable import SwiftProyecto

  final class ModelManagerBareDescriptorTests: XCTestCase {
      func testBareDescriptorIsRegisteredButNotHydrated() throws {
          _ = ModelManager()  // Triggers registration side-effect
          let component = Acervo.component(ProjectModel.id)
          XCTAssertNotNil(component, "ProjectModel should be registered")
          XCTAssertEqual(component?.isHydrated, false, "Bare descriptor should not be hydrated before first ensureComponentReady")
          XCTAssertEqual(component?.needsHydration, true, "Bare descriptor needs hydration on first use")
      }
  }
  ```
- Run `xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS' -only-testing:SwiftProyectoTests/ModelManagerBareDescriptorTests` to verify in isolation.
- Run the full test suite to ensure no regression.

**Exit Criteria**:
- ✅ File exists at `Tests/SwiftProyectoTests/ModelManagerBareDescriptorTests.swift`.
- ✅ `xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS' -only-testing:SwiftProyectoTests/ModelManagerBareDescriptorTests` exits 0.
- ✅ Full test suite (`xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'`) exits 0. The Sortie 1.1 expected failure is now resolved by 2.1a, so all tests should pass.

**Effort**: 0.25 hours | **Model**: Haiku

---

#### Sortie 2.2: Remove direct path construction from `proyecto` CLI

**Priority Score**: 12.0
**Agent Eligibility**: Supervising agent only

**Entry Criteria**:
- Sortie 2.1b complete (`ProjectModel` is registered, used by ModelManager, and validated by unit test).

**Actions**:
- In `Sources/proyecto/ProyectoCLI.swift`:
  - **DownloadCommand** (locate via `grep -n "DownloadCommand" Sources/proyecto/ProyectoCLI.swift`):
    - Replace `let componentId = Phi3ModelRepo.mini4bit.componentId` with `let componentId = ProjectModel.id`.
    - Keep the `Acervo.sharedModelsDirectory.path` print statement as a general "destination root" message — this is informational and does not construct a model path. **Allowed.**
    - Replace the slugify-based path construction (the line containing `Acervo.slugify(componentId)`) with:
      ```swift
      let modelDir = try Acervo.modelDirectory(for: ProjectModel.repoId)
      print("Model available at: \(modelDir.path)")
      ```
  - **InitCommand** (locate via `grep -n "InitCommand" Sources/proyecto/ProyectoCLI.swift`):
    - Change the `@Option` default from `Bruja.defaultModel` to `ProjectModel.repoId`:
      ```swift
      @Option(help: "Model path or HuggingFace model ID")
      var model: String = ProjectModel.repoId
      ```
- In `Sources/proyecto/IterativeProjectGenerator.swift`:
  - Rewrite `resolveModelPath(_:)`:
    ```swift
    private static func resolveModelPath(_ model: String) throws -> String {
      // Local filesystem path: pass through.
      if FileManager.default.fileExists(atPath: model) {
        return model
      }
      if model.hasPrefix("~") {
        let expanded = NSString(string: model).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expanded) {
          return expanded
        }
      }
      // Otherwise it must be an org/repo slug — let SwiftAcervo resolve the directory.
      return try Acervo.modelDirectory(for: model).path
    }
    ```
    `resolveModelPath` now throws; propagate in `init(model:authorOverride:)` (make the init throwing) and at the call site in `ProyectoCLI.InitCommand.run()`.

**Exit Criteria**:
- ✅ `grep -rn "sharedModelsDirectory.appendingPathComponent\|Acervo.slugify\|Phi3ModelRepo\|Bruja.defaultModel" Sources/proyecto/` returns nothing.
- ✅ All references to the model in `Sources/proyecto/` use `ProjectModel.id` or `ProjectModel.repoId` (verify: `grep -rn "ProjectModel\." Sources/proyecto/` returns ≥ 3 matches).
- ✅ `proyecto download` and `proyecto init` both use the same model (Llama-3.2-1B-Instruct-4bit). Verify by inspecting the `--model` default in `proyecto init --help` output after building.
- ✅ `proyecto download` prints a path that actually exists (run once interactively post-build; the path should resolve under `Acervo.sharedModelsDirectory`).
- ✅ `xcodebuild build -scheme proyecto -destination 'platform=macOS'` exits 0.

**Effort**: 1 hour | **Model**: Haiku

---

#### Sortie 2.3: Remove direct path construction from tests

**Priority Score**: 8.0
**Agent Eligibility**: Supervising agent only

**Entry Criteria**:
- Sortie 2.2 complete.
- **CI CDN access verification**: CI has CDN access. Verify locally: `curl -I https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models/manifest.json` returns HTTP 200 (or HTTP 404 with `x-amz-bucket-region` header — confirms R2 is reachable). If verification fails, do not run integration tests until CI access is restored.

**Actions**:
- In `Tests/SwiftProyectoTests/ProjectGenerationIntegrationTest.swift`:
  - Locate the `modelPath` computation (search `grep -n "Acervo.slugify\|sharedModelsDirectory.appendingPathComponent" Tests/SwiftProyectoTests/ProjectGenerationIntegrationTest.swift`).
  - Replace the existence-check / download branch with:
    ```swift
    if !Acervo.isComponentReady(ProjectModel.id) {
      try await Acervo.ensureComponentReady(ProjectModel.id) { progress in
        // Existing progress handling
      }
    }
    let modelDir = try Acervo.modelDirectory(for: ProjectModel.repoId)
    ```
  - Replace the hand-built "requiredFiles" XCTAssert loop with a `withComponentAccess` block that asks the handle to resolve each name; a file not in the manifest will throw `AcervoError.fileNotInComponent`, which is the correct negative-case assertion.
- In `Tests/SwiftProyectoTests/AcervoDownloadIntegrationTests.swift`:
  - Replace all references to `Phi3ModelRepo.mini4bit.componentId` with `ProjectModel.id`.
  - Replace references to `Phi3ModelRepo.mini4bit.rawValue` with `ProjectModel.repoId`.
  - Remove the hardcoded `expectedHashes` dictionary entirely. The test's job is to verify that `ensureComponentReady` produces a working model directory with the manifest's files; SHA-256 verification is SwiftAcervo's contract and is already tested upstream. If any per-file assertion is needed, use `Acervo.fetchManifest(forComponent: ProjectModel.id)` and iterate its `files`.

**Exit Criteria**:
- ✅ `grep -rn "sharedModelsDirectory.appendingPathComponent\|Acervo.slugify\|Phi3ModelRepo" Tests/` returns nothing.
- ✅ `grep -rn "0e2e43bc4358\|d0f067e1e15c\|d6e13c85fbde\|8d75680621a0" Tests/` returns nothing (the hardcoded Phi-3 hashes).
- ✅ `grep -rn "ProjectModel\." Tests/SwiftProyectoTests/` returns ≥ 4 matches (use across both modified test files).
- ✅ `xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'` exits 0 (CI access to CDN required — gated on entry criterion above).

**Effort**: 1 hour | **Model**: Haiku

---

### WORK UNIT 4: CDN Model Availability Guarantee

**User directive (2026-04-24)**: *"During one sortie, validate that the model(s) needed to power this library are available on the CDN. Ship them with Acervo binary if they are not."*

#### Sortie 4.1: Audit and publish every required model to the CDN

**Priority Score**: 6.25
**Agent Eligibility**: Sub-agent eligible (CLI + curl + workflow YAML edit; no Xcode build)

**Entry Criteria**:
- Sortie 2.3 complete (`ProjectModel` constant is the authoritative source of model identity, all consumer code paths migrated).
- **acervo CLI installed and configured**:
  ```bash
  which acervo || brew install intrusive-memory/tap/acervo
  acervo config validate || echo "Configure per ../SwiftAcervo/CDN_UPLOAD.md"
  ```
  If `acervo config validate` fails, follow the setup steps in `../SwiftAcervo/CDN_UPLOAD.md` before proceeding. Do not start this sortie with unconfigured R2 credentials.

**Actions**:
1. Enumerate every model slug referenced by SwiftProyecto. Source of truth:
   - `ProjectModel.repoId` in `ModelManager.swift` (single canonical model).
   - Any other hardcoded `org/repo` slug in `Sources/` (audit via `grep -rn 'mlx-community/' Sources/`).
   - Expected result: **one model** (`mlx-community/Llama-3.2-1B-Instruct-4bit`).
2. For the model slug, run:
   ```bash
   acervo manifest verify mlx-community/Llama-3.2-1B-Instruct-4bit
   ```
   If the manifest is missing, stale, or fails the checksum-of-checksums check, continue to step 3; otherwise mark it green.
3. If missing/stale, publish:
   ```bash
   acervo ship mlx-community/Llama-3.2-1B-Instruct-4bit
   ```
   (`acervo ship` downloads from HuggingFace, hashes, generates the manifest, uploads to R2, and re-verifies. See `../SwiftAcervo/ACERVO_CDN_UPLOAD_PATTERN.md`.)
4. Re-run `acervo manifest verify mlx-community/Llama-3.2-1B-Instruct-4bit`; must return green.
5. Update `.github/workflows/ensure-model-cdn.yml`:
   - Change `MODEL_REPO` from `mlx-community/Phi-3-mini-4k-instruct-4bit` to `mlx-community/Llama-3.2-1B-Instruct-4bit`.
   - Change `MODEL_SLUG` from `mlx-community_Phi-3-mini-4k-instruct-4bit` to `mlx-community_Llama-3.2-1B-Instruct-4bit`.
6. Run the workflow once manually (`gh workflow run ensure-model-cdn.yml`) to confirm the CI idempotency check agrees with the local verification. Confirm green via `gh run list --workflow=ensure-model-cdn.yml --limit 1`.

**Exit Criteria**:
- ✅ A signed-off verification in the sortie's PR description: `mlx-community/Llama-3.2-1B-Instruct-4bit` → manifest status (green/red) → action taken → final status (green).
- ✅ `curl -I https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models/mlx-community_Llama-3.2-1B-Instruct-4bit/manifest.json` returns HTTP 200.
- ✅ `Acervo.fetchManifest(for: ProjectModel.repoId)` succeeds from a test harness (run any one of the integration tests; success implies manifest fetch succeeded).
- ✅ `.github/workflows/ensure-model-cdn.yml` references the correct model (verify: `grep -n 'Llama-3.2-1B-Instruct-4bit' .github/workflows/ensure-model-cdn.yml` returns ≥ 2 matches).
- ✅ `gh run list --workflow=ensure-model-cdn.yml --limit 1` shows the most recent run as `success`.
- ✅ No model required by SwiftProyecto requires a HuggingFace round-trip at runtime.

**Effort**: 1–2 hours (depends on whether Llama-3.2-1B needs uploading; ~1 GB upload is ~10 minutes) | **Model**: Sonnet (decision judgment on stale-vs-current manifests)

**Note on scope**: this sortie touches R2 directly. It is **not** reversible without re-uploading, so the agent must confirm each `acervo ship` target before running, and must abort on any ambiguity (e.g., a slug that maps to a renamed HuggingFace repo).

---

### WORK UNIT 3: Test Sandboxing

#### Sortie 3.1: Scope integration tests to an isolated `customBaseDirectory`

**Priority Score**: 4.75
**Agent Eligibility**: Supervising agent only

**Entry Criteria**:
- Sortie 4.1 complete (CDN manifest verified green; integration tests will not block on missing CDN content).

**Actions**:
- In `Tests/SwiftProyectoTests/AcervoDownloadIntegrationTests.swift`, locate the `setUp` and `tearDown` methods (search: `grep -n "override func setUp\|override func tearDown" Tests/SwiftProyectoTests/AcervoDownloadIntegrationTests.swift`).
- Add helper functions if not already present:
  ```swift
  private func makeTempSharedModels() throws -> URL {
      let tempDir = FileManager.default.temporaryDirectory
          .appendingPathComponent("SwiftProyectoTests-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      return tempDir
  }

  private func cleanupTempDirectory(_ url: URL) {
      try? FileManager.default.removeItem(at: url)
  }
  ```
- Replace setUp/tearDown bodies:
  ```swift
  override func setUp() async throws {
    try await super.setUp()
    tempSharedModels = try makeTempSharedModels()
    Acervo.customBaseDirectory = tempSharedModels
  }

  override func tearDown() async throws {
    Acervo.customBaseDirectory = nil
    if let tempSharedModels { cleanupTempDirectory(tempSharedModels) }
    try await super.tearDown()
  }
  ```
- Delete the stale `// Can't actually reset Acervo's directory without private API` comment.
- Audit `ProjectGenerationIntegrationTest.swift`: run `grep -n "sharedModelsDirectory\|customBaseDirectory" Tests/SwiftProyectoTests/ProjectGenerationIntegrationTest.swift`. If it mutates the shared-models directory, apply the same setUp/tearDown treatment.

**Exit Criteria**:
- ✅ `grep -n "Can't actually reset Acervo's directory" Tests/` returns nothing (stale comment removed).
- ✅ `grep -n "Acervo.customBaseDirectory" Tests/SwiftProyectoTests/AcervoDownloadIntegrationTests.swift` returns ≥ 2 matches (set in setUp, reset in tearDown).
- ✅ After running `xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'` on a clean machine, the host's real shared-models directory is unchanged. Verify by capturing `find ~/Library/Application\ Support/SwiftAcervo/SharedModels/ -type f | sort | shasum` before and after the test run; the two hashes must match.
- ✅ Tests still pass: `xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'` exits 0.

**Effort**: 0.5 hours | **Model**: Haiku

---

### WORK UNIT 5: Documentation & Follow-ups

#### Sortie 5.1: Verify the App Group entitlement section landed in AGENTS.md

**Priority Score**: 4.5
**Agent Eligibility**: Sub-agent eligible (no build, no code edits)

The App Group entitlement section was added to `AGENTS.md` (see `### App Group Entitlement (REQUIRED for app consumers of this library)` inside the "Model Validation & CDN Integration" block) as part of the commit that introduced this plan. This sortie just confirms it survived review.

**Entry Criteria**:
- Sortie 3.1 complete (mission code work done; doc work begins).

**Actions**:
- Verify the section exists: `grep -n "App Group Entitlement (REQUIRED" AGENTS.md` returns ≥ 1 match.
- Confirm the section renders correctly in GitHub preview (visual check — open `AGENTS.md` in GitHub web UI on the feature branch).
- Update the "Latest Changes" block at the top of AGENTS.md to add a v3.5.0 entry documenting the 0.8.0 migration.

**Exit Criteria**:
- ✅ `grep -n "App Group Entitlement (REQUIRED" AGENTS.md` returns ≥ 1 match.
- ✅ `grep -n "v3.5.0" AGENTS.md` returns ≥ 1 match (changelog entry exists).
- ✅ Section visible and correctly formatted in GitHub preview (manual verification).

**Effort**: 15 minutes | **Model**: Haiku

---

#### Sortie 5.2a: AGENTS.md model/API updates

**Priority Score**: 2.25
**Agent Eligibility**: Sub-agent eligible

**Motivation**: `AGENTS.md` carries 0.7-era examples — full `ComponentDescriptor` init with hardcoded `files:` + SHA-256s referencing Phi-3, a Download Workflow diagram that names `~/Library/SharedModels/`, and an `IterativeProjectGenerator.resolveModelPath` sample that uses `model.replacingOccurrences(of: "/", with: "_")` + `Acervo.sharedModelsDirectory.appendingPathComponent(...)`. This sortie updates the **model/API surface** sections.

**Entry Criteria**:
- Sortie 5.1 complete (App Group entitlement section verified).

**Actions** — `AGENTS.md` (locate sections via section headers, not line numbers):
1. **Section: `### ComponentDescriptor Registration`** — Rewrite the code block to show the `ProjectModel` constant pattern:
   ```swift
   /// The canonical model for PROJECT.md generation across SwiftProyecto.
   public let ProjectModel = ComponentDescriptor(
       id: "llama-3.2-1b-instruct-4bit",
       type: .languageModel,
       displayName: "Llama 3.2 1B Instruct (4-bit)",
       repoId: "mlx-community/Llama-3.2-1B-Instruct-4bit",
       minimumMemoryBytes: 1_500_000_000,
       metadata: [
           "quantization": "4-bit",
           "context_length": "8192",
           "architecture": "Llama",
           "version": "3.2",
       ]
   )

   private let _registerProjectModel: Void = {
       Acervo.register([ProjectModel])
   }()
   ```
   Delete every reference to `Phi3ModelRepo`, `phi3RequiredFiles`, `ComponentFile`, `expectedSizeBytes`, `sha256`, `estimatedSizeBytes`, `cdn_url` in `metadata`, and `manifest_checksum` in `metadata`.
2. **Subsection: "Key Points"** (immediately following the code block above) — Rewrite the bullet list to emphasize:
   - *"Single source of truth — `ProjectModel` constant provides one canonical model for all SwiftProyecto operations."*
   - *"Bare descriptor — `ComponentDescriptor` is registered without a file list. SwiftAcervo hydrates `files` and `estimatedSizeBytes` from the CDN manifest on first call to `ensureComponentReady`."*
   - *"Model choice — Llama-3.2-1B-Instruct-4bit chosen for smaller download footprint (~1 GB vs. ~2.3 GB) and sufficient capability for PROJECT.md metadata generation."*
3. **Section: `### Download Workflow`** — Update the diagram:
   - Change the path reference from `~/Library/SharedModels/…` to `<group.intrusive-memory.models container>/SharedModels/…` (the canonical path for entitled apps). Note the fallback path only in a trailing sentence.
   - Step 1 should read "Initialize ModelManager (registers `ProjectModel` constant with bare descriptor)" rather than calling out a specific file list or Phi-3.
   - Insert a new step 2a: "On first call, SwiftAcervo fetches the CDN manifest and hydrates the descriptor."
   - Update all model references from Phi-3 to Llama-3.2-1B-Instruct-4bit.
4. **Section: `### Integration Points` → subsection `IterativeProjectGenerator`** — Rewrite the sample to use `Acervo.modelDirectory(for: model).path` (the form Sortie 2.2 lands). Delete the `model.replacingOccurrences(of: "/", with: "_")` line and the `sharedModelsDirectory.appendingPathComponent(...)` line.

**Exit Criteria**:
- ✅ `grep -n 'sharedModelsDirectory.appendingPathComponent\|replacingOccurrences(of: "/"\|phi3RequiredFiles\|ComponentFile\|Phi3ModelRepo\|Phi-3' AGENTS.md` returns nothing.
- ✅ All model references in the modified sections of `AGENTS.md` use `ProjectModel` constant and Llama-3.2-1B-Instruct-4bit (verify: `grep -n "ProjectModel\|Llama-3.2-1B" AGENTS.md` returns ≥ 5 matches across the modified sections).
- ✅ "Download Workflow" diagram references the App Group container path as the canonical location, with the fallback called out as "unsigned CLI / unentitled app only".

**Effort**: 30 minutes | **Model**: Sonnet (judgment on prose surrounding code samples)

---

#### Sortie 5.2b: AGENTS.md guidance updates

**Priority Score**: 2.25
**Agent Eligibility**: Sub-agent eligible

**Entry Criteria**:
- Sortie 5.2a complete (model/API surface in AGENTS.md updated).

**Actions** — `AGENTS.md`:
1. **Section: `### Related Documentation` → subsection `ModelManager.swift`** — Update the bullet list to reflect the real method names after Sortie 2.1a:
   - `isModelReady()` (no parameter) — replaces `isModelAvailable(_:)`
   - `ensureModelReady()` (no parameter) — replaces `ensureModelReady(_:)`
   - All operations use `ProjectModel` constant
2. **Section: `### Agent Guidance: Adding New Models`** — Rename to `### Agent Guidance: Changing the Canonical Model` and rewrite content:
   - To change the model used by SwiftProyecto, update the `ProjectModel` constant in `Sources/SwiftProyecto/Infrastructure/ModelManager.swift`.
   - Steps:
     - (a) Update `ProjectModel.repoId` to the new `org/repo` slug.
     - (b) Update metadata fields (`quantization`, `context_length`, `architecture`, `version`).
     - (c) Publish the new model via `acervo ship <org/repo>`.
     - (d) Update `.github/workflows/ensure-model-cdn.yml` `MODEL_REPO` and `MODEL_SLUG` to reference the new model.
     - (e) Run `xcodebuild test` to confirm integration tests still pass against the new manifest.
   - Note: No multi-model support — SwiftProyecto uses one canonical model for consistency.

**Exit Criteria**:
- ✅ `grep -n "isModelReady()\|ensureModelReady()" AGENTS.md` returns ≥ 2 matches (no parameter forms documented).
- ✅ `grep -n "isModelAvailable(_:)\|ensureModelReady(_:)" AGENTS.md` returns nothing (old signatures removed).
- ✅ `grep -n "Changing the Canonical Model" AGENTS.md` returns 1 match (section renamed).
- ✅ `grep -n "Adding New Models" AGENTS.md` returns nothing (old section title removed).

**Effort**: 20 minutes | **Model**: Sonnet

---

#### Sortie 5.2c: Archive ACERVO_MIGRATION_REQUIREMENTS.md as historical

**Priority Score**: 2.25
**Agent Eligibility**: Sub-agent eligible

**Motivation**: `Docs/ACERVO_MIGRATION_REQUIREMENTS.md` describes a "Target State" in which *"No code changes needed in SwiftProyecto beyond configuration"* and *"SwiftProyecto stays simple: just calls Bruja.download() and Bruja.query()"* — SwiftProyecto imports SwiftAcervo directly today, and the 0.8.0 migration doubles down on that choice (direct imports are the recommended pattern per `../SwiftAcervo/USAGE.md`). The doc is a 2026-03-25 snapshot and should be archived as historical (Option A from original plan, now the default).

**Entry Criteria**:
- Sortie 5.2b complete (AGENTS.md fully refreshed).

**Actions**:
1. Archive the file:
   ```bash
   git mv Docs/ACERVO_MIGRATION_REQUIREMENTS.md Docs/complete/ACERVO_MIGRATION_REQUIREMENTS_2026-03.md
   ```
2. Add a one-line note at the top of the archived file (above the existing content):
   ```markdown
   **Status**: HISTORICAL — superseded by `EXECUTION_PLAN.md` (2026-04-25) and `ACERVO_AUDIT.md`. The "Target State" in §"Target Architecture" was never adopted; SwiftProyecto imports SwiftAcervo directly, which is the pattern recommended by `../SwiftAcervo/USAGE.md` 0.8.0.
   ```
3. Create a stub at `Docs/ACERVO_MIGRATION_REQUIREMENTS.md` that redirects readers:
   ```markdown
   # ACERVO Migration Requirements

   **This document has been archived.**

   The original 2026-03-25 requirements describing a "SwiftProyecto via SwiftBruja" architecture were never adopted. SwiftProyecto imports SwiftAcervo directly per the 0.8.0 manifest-first contract.

   See instead:
   - `EXECUTION_PLAN.md` — current migration plan (2026-04-25)
   - `ACERVO_AUDIT.md` — current integration audit
   - `Docs/complete/ACERVO_MIGRATION_REQUIREMENTS_2026-03.md` — archived historical document
   - `../SwiftAcervo/USAGE.md` — upstream integration contract
   ```

**Exit Criteria**:
- ✅ `test -f Docs/complete/ACERVO_MIGRATION_REQUIREMENTS_2026-03.md` returns 0.
- ✅ `grep -n "HISTORICAL — superseded by" Docs/complete/ACERVO_MIGRATION_REQUIREMENTS_2026-03.md` returns 1 match.
- ✅ `test -f Docs/ACERVO_MIGRATION_REQUIREMENTS.md` returns 0 (stub exists).
- ✅ `grep -n "This document has been archived" Docs/ACERVO_MIGRATION_REQUIREMENTS.md` returns 1 match.
- ✅ `grep -rn 'Bruja.download\|No code changes needed in SwiftProyecto\|SwiftProyecto stays simple: just calls' Docs/ACERVO_MIGRATION_REQUIREMENTS.md` returns nothing (the stale "target state" wording is gone from the live doc).

**Effort**: 10 minutes | **Model**: Haiku

---

#### Sortie 5.3: Model standardization follow-up — update Bruja dependency if needed

**Priority Score**: 1.5
**Agent Eligibility**: Sub-agent eligible (optional, no code or build changes)

**RESOLVED AS PART OF SORTIE 2.0.** The model standardization decision (Sortie 2.0) resolves the drift identified in `ACERVO_AUDIT.md` §3.5. Both `proyecto download` and `proyecto init` now use the same model (Llama-3.2-1B-Instruct-4bit via `ProjectModel` constant).

**Optional follow-up**: If SwiftBruja exposes a `defaultModel` property that SwiftProyecto should align with (or vice versa), file a GitHub issue at `https://github.com/intrusive-memory/SwiftBruja/issues/new` to track cross-repo model consistency. This is not blocking for the 0.8.0 migration.

**Entry Criteria**:
- None — can run in parallel with 3.1, 5.1, 5.2a/b/c.

**Exit Criteria**:
- ✅ `ProjectModel` constant is the single source of truth in SwiftProyecto (already verified in 2.1a exit criteria).
- ✅ (Optional) Issue filed at SwiftBruja repo if cross-repo coordination is needed; URL recorded in PR description.

**Effort**: 10 minutes | **Model**: Haiku

---

## Sortie Dependencies

```
1.1 ──► 2.0 ──► 2.1a ──► 2.1b ──┬──► 2.2 ──► 2.3 ──► 4.1 ──► 3.1 ──► 5.1 ──► 5.2a ──► 5.2b ──► 5.2c
                                │
                                └──► 4.1 (parallel: sub-agent eligible after 2.1b
                                          completes; supervising agent runs 2.2 in parallel)

After 2.3, optional:
                              ┌──► 5.3 (parallel with 3.1; sub-agent eligible)
```

**Critical path** (longest sequential chain):
`1.1 → 2.0 → 2.1a → 2.1b → 2.2 → 2.3 → 4.1 → 3.1 → 5.1 → 5.2a → 5.2b → 5.2c`

**Parallel windows** (see Parallelism & Execution Metadata above):
1. After 2.1b completes: supervising runs 2.2; sub-agent runs 4.1.
2. After 2.3 completes: supervising runs 3.1; sub-agent runs 5.3 (optional).

**Why 4.1 moved before 3.1**: CDN work has higher risk (network, R2 credentials, irreversible uploads) and is foundation for 3.1 (test sandboxing depends on a known-good CDN manifest). Surfacing CDN blockers earlier prevents a late-stage scramble.

**Why 5.2a/b/c run sequentially**: all three edit `AGENTS.md` and would conflict if run in parallel. Each is independently sub-agent eligible, but only one at a time.

---

## Execution Timeline

| Phase | Sorties | Est. Hours | Notes |
|-------|---------|-----------|-------|
| Dependency bump | 1.1 | 0.5 | Single-file edit + resolve |
| Model standardization | 2.0 | 0.25 | Create `ProjectModel` constant |
| Path elimination | 2.1a, 2.1b, 2.2, 2.3 | 3 | Sequential; touches `Sources/` + `Tests/` |
| CDN guarantee | 4.1 | 1–2 | Network-bound; R2 uploads (Llama ~1 GB); parallelizable with 2.2 |
| Test sandboxing | 3.1 | 0.5 | Isolated to integration tests |
| Docs + follow-up | 5.1, 5.2a, 5.2b, 5.2c, 5.3 | 1.5 | App Group verify + full doc refresh + archive |
| **Total** | **14 sorties** | **~7–8 hours** | Critical path: ~6 hours; with parallelism: ~5 hours |

---

## Success Checklist

- [ ] Phase 1: `from: "0.8.0"` pinned; tests green (with documented expected failure that 2.1a resolves).
- [ ] Phase 2: `ProjectModel` constant created as single source of truth; zero direct path construction in `Sources/` or `Tests/`; bare descriptor landed; all code references `ProjectModel`; bare-descriptor unit test passes.
- [ ] Phase 4 (runs before 3.1): Llama-3.2-1B-Instruct-4bit verified live on R2; `ensure-model-cdn.yml` updated; CDN manifest green; CI workflow run shows success.
- [ ] Phase 3: integration tests scoped to `customBaseDirectory` sandbox; host shared-models directory unchanged after test run.
- [ ] Phase 5: AGENTS.md fully refreshed (no 0.7-era samples, no Phi-3 references, all examples use `ProjectModel` and Llama-3.2-1B); `ACERVO_MIGRATION_REQUIREMENTS.md` archived as historical with redirect stub.

---

## Out of Scope

- Refactoring `IterativeProjectGenerator` to drop the path-string interface entirely and hand Bruja a component id. That requires a SwiftBruja API change and is separate work.
- Multi-model support. SwiftProyecto uses one canonical model (`ProjectModel`) for consistency. Supporting multiple models would require API changes and is not needed for PROJECT.md generation use case.

---

**Status**: Ready for `/mission-supervisor start SwiftProyecto/EXECUTION_PLAN.md`

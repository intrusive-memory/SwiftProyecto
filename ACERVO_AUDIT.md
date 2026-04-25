# SwiftAcervo Integration Audit — SwiftProyecto

**Date**: 2026-04-24
**Reference**: `../SwiftAcervo/USAGE.md` (v0.8.0 contract)
**Currently declared**: `from: "0.7.1"` (resolved at `0.7.3`)
**Audited by**: Claude Code

---

## TL;DR

SwiftProyecto is functional under SwiftAcervo 0.7.x, but it sits on **two latent bugs** (`isModelAvailable` / `slugify(componentId)` path misuse) that work only because downloads happen to land in the right place by other means, and it has not adopted the manifest-first contract that 0.8.0 is built around. The v0.8.0 upgrade itself is **non-breaking** — nothing in this repo must change to compile against it — but leaving the current code unchanged means:

1. A latent `isModelAvailable()` bug keeps returning `false` forever for the Phi-3 component.
2. Two user-facing path prints in the CLI and tests show a **wrong directory** for the downloaded model.
3. The declared `phi3RequiredFiles` (sizes + SHA-256) are now an *escape-hatch pattern*, not the default, and will trigger drift warnings on stderr the first time the CDN manifest is regenerated with any different byte count.
4. We give up free 0.8.0 capabilities (`fetchManifest`, `hydrateComponent`, `isComponentReadyAsync`) that would simplify tests and enable pre-download size UIs.

Recommendation: bump to `from: "0.8.0"`, fix the two path bugs (required — they are wrong under any version), and migrate `ModelManager` to the bare-descriptor pattern (optional but strongly recommended — shorter, drift-proof, and matches the reference implementation style SwiftBruja will converge on).

---

## 1. What Changed in SwiftAcervo 0.8.0

From `../SwiftAcervo/CHANGELOG.md` and `USAGE.md`:

### New public API

| Symbol | Purpose |
| --- | --- |
| `Acervo.hydrateComponent(_:)` | Fetches CDN manifest for a registered component and populates `files` + `estimatedSizeBytes`. Idempotent; concurrent calls coalesce. |
| `Acervo.fetchManifest(for modelId:)` | Raw manifest by `org/repo`. No registry dependency. |
| `Acervo.fetchManifest(forComponent id:)` | Registry-aware companion. |
| `Acervo.isComponentReadyAsync(_:)` | Async readiness check that hydrates first. |
| `Acervo.unhydratedComponents()` | Lists component IDs awaiting first hydration. |
| `ComponentDescriptor.isHydrated` / `.needsHydration` | State flags. |
| `ComponentDescriptor` bare init | `init(id:type:displayName:repoId:minimumMemoryBytes:metadata:)` — no `files:` required. |
| `AcervoError.componentNotHydrated(id:)` | Thrown from sync-only paths when descriptor has no file list. |

### Contract shift (documented, not enforced by a breaking API change)

- **The manifest is the only authoritative source.** Declared `files: [...]` arrays are now framed as an "escape hatch" and cause stderr drift warnings if they disagree with the manifest.
- **`files: []` is the preferred argument** to `Acervo.ensureAvailable` and `AcervoManager.download` — the manifest decides what to fetch.
- **`isComponentReady(_:)` (sync) returns `false` for un-hydrated descriptors.** A descriptor that was registered *without* a file list will report not-ready until `ensureComponentReady` or `hydrateComponent` runs once.
- **App Group entitlement is now a first-class integration step.** Without `group.intrusive-memory.models`, apps silently fall back to `~/Library/Application Support/SwiftAcervo/SharedModels/` — not shared across apps.

### Non-breaking

Every existing 0.7-era call site compiles and behaves identically under 0.8. The only observable difference for SwiftProyecto as-is would be the drift-warning stderr line if the CDN manifest's bytes differ from the hardcoded `phi3RequiredFiles` values.

---

## 2. Current SwiftProyecto Usage — Inventory

### `Package.swift`
```swift
.package(url: "...SwiftAcervo.git", from: "0.7.1"),  // comment: "Requires v2 access patterns (withComponentAccess)"
```
`Package.resolved` pins to `0.7.3`.

### `Sources/SwiftProyecto/Infrastructure/ModelManager.swift`
- Declares `phi3RequiredFiles: [ComponentFile]` with **4 hardcoded paths, sizes, and SHA-256s** (`config.json`, `tokenizer.json`, `tokenizer_config.json`, `model.safetensors`).
- Registers one `ComponentDescriptor` at module-load time via a private `let _registerPhi3Components`.
- Full descriptor init (with `files:`, `estimatedSizeBytes:`, `minimumMemoryBytes:`, `metadata`).
- `ensureModelReady(_:)` → `Acervo.ensureComponentReady(componentId)`.
- `isModelAvailable(_:)` → `Acervo.isModelAvailable(componentId)` ⚠️ **bug, see §3.1**.
- `withModelAccess(_:perform:)` → `AcervoManager.shared.withComponentAccess(componentId, perform:)`.
- `_loadModel(_:)` iterates `descriptor.files` and resolves each via `ComponentHandle.url(for:)`.

### `Sources/proyecto/ProyectoCLI.swift`
- `DownloadCommand` calls `Acervo.ensureComponentReady(componentId)` with a progress callback that reads `progress.overallProgress`, `progress.fileName`, `progress.fileIndex`, `progress.totalFiles`.
- After success, prints `"Model available at: \(Acervo.sharedModelsDirectory.appendingPathComponent(Acervo.slugify(componentId)).path)"` ⚠️ **bug, see §3.2**.
- `InitCommand.model` defaults to `Bruja.defaultModel` (`mlx-community/Llama-3.2-1B-Instruct-4bit` — *different model than the one we register with Acervo*, see §3.5).

### `Sources/proyecto/IterativeProjectGenerator.swift`
- `resolveModelPath(_:)` hand-slugifies `model.replacingOccurrences(of: "/", with: "_")` and appends to `Acervo.sharedModelsDirectory`. Works, but duplicates `Acervo.slugify` / `Acervo.modelDirectory(for:)`.
- Uses `Bruja.query(..., model: modelPath, ...)` with the resulting path string.

### `Tests/SwiftProyectoTests/AcervoDownloadIntegrationTests.swift`
- Creates a temp dir in `setUp`, reads `Acervo.sharedModelsDirectory` in `originalSharedModelsDirectory`, **never sets `Acervo.customBaseDirectory`** — so the temp dir is unused and the test actually mutates the real shared-models directory on the host machine. Comment acknowledges "Can't actually reset Acervo's directory without private API" — this is outdated; `customBaseDirectory` is public since 0.7.
- Integration tests call `Acervo.ensureComponentReady("phi3-mini-4k-4bit")` directly.
- Expected-hashes map duplicates the values from `phi3RequiredFiles` in `ModelManager.swift`.

### `Tests/SwiftProyectoTests/ProjectGenerationIntegrationTest.swift`
- Line 137: `Acervo.sharedModelsDirectory.appendingPathComponent(Acervo.slugify(componentId))` ⚠️ **same bug as §3.2**.

### `.github/workflows/ensure-model-cdn.yml`
- Hardcoded `MODEL_REPO=mlx-community/Phi-3-mini-4k-instruct-4bit`, `MODEL_SLUG=mlx-community_Phi-3-mini-4k-instruct-4bit`.
- Matches the compliant pattern documented in `../SwiftAcervo/ACERVO_CDN_UPLOAD_PATTERN.md` — **no changes needed for 0.8.0**.

### Entitlements
- No `.entitlements` file in the repo. Expected: `proyecto` is an unsigned macOS CLI and legitimately uses the fallback path per USAGE.md §2. But neither `AGENTS.md` nor `CLAUDE.md` calls out that downstream *app* consumers of the `SwiftProyecto` library must enable `group.intrusive-memory.models`, which is a 0.8.0-era documentation gap.

---

## 3. Issues Found

### 3.1 Latent bug: `ModelManager.isModelAvailable(_:)` always returns `false`

**File**: `Sources/SwiftProyecto/Infrastructure/ModelManager.swift:143-145`

```swift
public func isModelAvailable(_ model: Phi3ModelRepo) -> Bool {
  Acervo.isModelAvailable(model.componentId)   // "phi3-mini-4k-4bit"
}
```

`Acervo.isModelAvailable(_ modelId:)` calls `modelDirectory(for:)`, which throws `AcervoError.invalidModelId` when the argument does not contain exactly one `/`. `isModelAvailable` swallows that error with `try?` and returns `false`.

Our `componentId` is `"phi3-mini-4k-4bit"` — **no slash**. So this method **always returns `false`**, regardless of whether the model is on disk.

The reason this hasn't surfaced: every call site either (a) calls `ensureModelReady` first (which uses `isComponentReady` internally, not `isModelAvailable`), or (b) is a test that just checks the method is callable.

**Fix**: pass `model.rawValue` (the `org/repo` modelId), **or** switch to the component-aware check.

```swift
public func isModelAvailable(_ model: Phi3ModelRepo) -> Bool {
  Acervo.isModelAvailable(model.rawValue)        // byte-level check: config.json on disk
}

// ...or, preferred for 0.8-style bare descriptors:
public func isModelReady(_ model: Phi3ModelRepo) -> Bool {
  Acervo.isComponentReady(model.componentId)     // registry-aware, respects hydration
}
```

`isComponentReady` is the component-aware answer (checks all declared files exist) and returns `false` cleanly for bare, un-hydrated descriptors — which is what you want. The `isModelAvailable(modelId)` form is the byte-level "just check config.json" answer.

### 3.2 Wrong path displayed in CLI and tests

**Files**:
- `Sources/proyecto/ProyectoCLI.swift:98`
- `Tests/SwiftProyectoTests/ProjectGenerationIntegrationTest.swift:136-137`

Both sites do:
```swift
Acervo.sharedModelsDirectory.appendingPathComponent(Acervo.slugify(componentId))
```

`slugify("phi3-mini-4k-4bit")` returns `"phi3-mini-4k-4bit"` unchanged (no `/` to replace). The resulting path is `<sharedModels>/phi3-mini-4k-4bit/` — a directory that **does not exist**. The model actually lives at `<sharedModels>/mlx-community_Phi-3-mini-4k-instruct-4bit/`, which is derived from the descriptor's `repoId`, not its `id`.

The CLI print therefore displays a misleading path to the user, and the test's `FileManager.default.fileExists` guard on that path always succeeds down the "model not found, attempting download" branch even when the model is present.

**Fix**: use the component's `repoId` (or `try Acervo.modelDirectory(for: repoId)`).

```swift
// CLI:
let repoId = Phi3ModelRepo.mini4bit.rawValue
let dir = try Acervo.modelDirectory(for: repoId)
print("Model available at: \(dir.path)")

// Test:
let repoId = Phi3ModelRepo.mini4bit.rawValue
let modelPath = try Acervo.modelDirectory(for: repoId)
```

### 3.3 Hardcoded file list is now an escape-hatch pattern

**File**: `Sources/SwiftProyecto/Infrastructure/ModelManager.swift:42-63`

The declared `phi3RequiredFiles` worked fine under 0.7, but USAGE.md 0.8 explicitly reframes this as *"the v0.7-era pattern, still supported"* and *"the escape hatch ... when you actually need to narrow the download — not because you want to feel safer about what gets fetched."*

Concrete consequences of keeping the hardcoded list:

1. **Drift warnings**: any time the CDN manifest regenerates with a byte-different config.json (e.g., whitespace change upstream), stderr gets `[SwiftAcervo] Manifest drift detected for phi3-mini-4k-4bit: declared 4 files, manifest has N files. Using manifest.`
2. **Source-of-truth duplication**: SHA-256s live in `ModelManager.swift`, the CDN manifest, the `ensure-model-cdn.yml` workflow, and again in `AcervoDownloadIntegrationTests.swift`. Four places to keep in sync.
3. **Manual work on CDN updates**: regenerating the model on R2 requires hand-updating the hashes in this file.

**Recommended migration** — bare descriptor:

```swift
private let phi3ComponentDescriptors: [ComponentDescriptor] = [
  ComponentDescriptor(
    id: Phi3ModelRepo.mini4bit.componentId,
    type: .languageModel,
    displayName: Phi3ModelRepo.mini4bit.displayName,
    repoId: Phi3ModelRepo.mini4bit.rawValue,
    minimumMemoryBytes: 8_000_000_000,
    metadata: [
      "quantization": "4-bit",
      "context_length": "4096",
      "architecture": "Phi",
      "version": "1.0.0",
    ]
  ),
]
```

`ensureComponentReady` auto-hydrates on first call. `cdn_url` and `manifest_checksum` in the existing `metadata` dictionary are either redundant (the CDN URL is derived from `sharedModelsDirectory` resolution upstream) or subject to drift; drop them.

Once hydrated, `descriptor.files` contains the full file list from the CDN manifest, so `_loadModel` continues to work unchanged.

**Keep the declared list only if** we genuinely need one of:
- A pre-hydration size estimate for UI *before* `ensureComponentReady` runs. (Not applicable to proyecto today — it's a CLI.)
- A narrowed subset download (we don't want all files). (Not applicable — we want all 4.)
- Air-gapped CI where the manifest cannot be fetched. (Not our case — `ensure-model-cdn.yml` always has network.)

### 3.4 Tests never override `sharedModelsDirectory`

**File**: `Tests/SwiftProyectoTests/AcervoDownloadIntegrationTests.swift:63-86`

```swift
tempSharedModels = try makeTempSharedModels()
originalSharedModelsDirectory = Acervo.sharedModelsDirectory
// ...
// "Can't actually reset Acervo's directory without private API"
```

The override hook exists: `Acervo.customBaseDirectory` (public since 0.7). The test should set it in `setUp` and restore in `tearDown`:

```swift
override func setUp() async throws {
  try await super.setUp()
  tempSharedModels = try makeTempSharedModels()
  Acervo.customBaseDirectory = tempSharedModels
}

override func tearDown() async throws {
  Acervo.customBaseDirectory = nil
  cleanupTempDirectory(tempSharedModels)
  try await super.tearDown()
}
```

Without this, the integration tests pollute `~/Library/Application Support/SwiftAcervo/SharedModels/` on whichever machine runs them and leave a 2.3 GB Phi-3 copy behind.

### 3.5 `Bruja.defaultModel` vs. registered component: mismatched models

**File**: `Sources/proyecto/ProyectoCLI.swift:283`

`InitCommand` defaults `--model` to `Bruja.defaultModel` which is (per the resolved Package.resolved) `"mlx-community/Llama-3.2-1B-Instruct-4bit"`. `DownloadCommand` downloads Phi-3. So:

```
$ proyecto download         # downloads Phi-3
$ proyecto init             # tries to load Llama, fails or re-downloads via Bruja
```

This is not a SwiftAcervo v0.8.0 issue — it predates the release — but any cleanup pass over this integration should decide: are we standardizing on Phi-3, or on whatever Bruja defaults to? If Phi-3, `InitCommand.model` should default to `Phi3ModelRepo.mini4bit.rawValue` (or the component id, piped through `Bruja.query(component:)` if Bruja exposes that). If Llama, `ModelManager`/`phi3ComponentDescriptors` should register Llama instead of Phi-3.

Flagging candidly: this smells like the Phi-3 story was added on top of a pre-existing Bruja-Llama path without anyone noticing the defaults diverged. Worth a conversation before the 0.8.0 migration ships.

### 3.6 Documentation gap: App Group entitlement for downstream consumers

`SwiftProyecto` ships as both an executable (`proyecto` — unsigned CLI, fallback path is correct) and a **library** (`SwiftProyecto` target). A signed app that imports the library target needs the `group.intrusive-memory.models` App Group to get cross-app model sharing. USAGE.md 0.8 calls this out as integration step #2; `AGENTS.md` and `CLAUDE.md` here don't mention it.

**Fix**: add a short section to `AGENTS.md` (the universal doc) under "Integrating SwiftProyecto":

> **Signed app consumers**: enable the `group.intrusive-memory.models` App Group capability on every target that imports `SwiftProyecto`. Without it, the library silently falls back to a non-shared models directory and your app will re-download Phi-3 instead of reusing the copy downloaded by other intrusive-memory tools.

### 3.7 Unused 0.8 capabilities worth adopting

None of these are required for correctness, but they're free wins once we're on 0.8:

- **`Acervo.fetchManifest(forComponent:)`** — use in a test to verify CDN publishing without downloading 2 GB. Wires up naturally with the `ensure-model-cdn.yml` workflow.
- **`Acervo.hydrateComponent(_:)`** — use in a hypothetical future UI to show model size before the user commits to the download.
- **`Acervo.isComponentReadyAsync(_:)`** — use from async paths so bare descriptors report accurately without needing to hydrate by hand.
- **`ModelDownloadManager.shared.ensureModelsAvailable([...])`** — currently irrelevant (one model), but the idiomatic batch entry point if we ever ship multi-model selection.

---

## 4. Upgrade Plan — Recommended Order

Each step is small and independently testable. Steps 1–3 are strictly required (they fix real bugs). Steps 4–6 are the manifest-first migration. Step 7 cleans up the loose ends.

### Step 1 — Bump SwiftAcervo to 0.8.0 (non-breaking)
- `Package.swift`: `from: "0.7.1"` → `from: "0.8.0"`
- Remove the now-stale comment `// Requires v2 access patterns (withComponentAccess)`.
- `swift package resolve` / `xcodebuild -resolvePackageDependencies`.
- `xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'` — nothing should break.

### Step 2 — Fix `isModelAvailable` (§3.1)
Change the argument from `componentId` to `rawValue`, **or** rename the method and switch to `Acervo.isComponentReady`.

### Step 3 — Fix the slugify-componentId bug (§3.2)
- `ProyectoCLI.swift:98` — use `try Acervo.modelDirectory(for: Phi3ModelRepo.mini4bit.rawValue)`.
- `ProjectGenerationIntegrationTest.swift:136-137` — same.

### Step 4 — Wire up the test sandbox (§3.4)
Set `Acervo.customBaseDirectory = tempSharedModels` in `AcervoDownloadIntegrationTests.setUp` and reset it in `tearDown`. Stop polluting the host's real shared-models directory.

### Step 5 — Adopt the bare-descriptor pattern (§3.3)
Replace `phi3RequiredFiles` + full descriptor init with the bare initializer. Delete the hardcoded SHA-256s from `ModelManager.swift`. Integration tests that assert those hashes should either (a) move to `fetchManifest(forComponent:)` for a read-only manifest check, or (b) keep the hashes as a local `knownGoodHashes` constant in the test file only.

### Step 6 — Decide Phi-3 vs. Bruja.defaultModel (§3.5)
Separate conversation. Not a SwiftAcervo migration task.

### Step 7 — Documentation polish (§3.6)
Add the "App Group entitlement" note to `AGENTS.md`. Update the README's "SwiftAcervo Integration" section to reflect the manifest-first wording and link to `../SwiftAcervo/USAGE.md`.

---

## 5. Risk Assessment

| Change | Risk | Reversible? |
| --- | --- | --- |
| Bump `from: "0.8.0"` | Low — release notes mark non-breaking; existing tests cover the call sites we use. | Yes, pin back to 0.7.3. |
| Fix `isModelAvailable` | Low — current behavior is always-false, so any not-false result is strictly new information. | Yes. |
| Fix slugify path print | Trivial — display-only. | Yes. |
| Wire up `customBaseDirectory` in tests | Low — scoped to test target. | Yes. |
| Bare-descriptor migration | Medium — requires a real download during first run of `ensureComponentReady` to hydrate. Offline/air-gapped environments need the manifest fetchable. **CI must have network** (it does: `ensure-model-cdn.yml` uploads to R2). | Yes — re-add the declared files if needed. |
| Phi-3 vs. Bruja default | Unknown — requires product decision. | n/a |

---

## 6. What Does *Not* Need to Change

- `.github/workflows/ensure-model-cdn.yml` — compliant with `ACERVO_CDN_UPLOAD_PATTERN.md`, aligned with 0.8.0.
- `AcervoManager.shared.withComponentAccess(_:perform:)` usage in `ModelManager.withModelAccess` — unchanged under 0.8.
- `ComponentHandle.url(for:)` resolution in `_loadModel` — unchanged; continues to work after bare-descriptor migration because `descriptor.files` is populated by hydration.
- The registration side-effect via `private let _registerPhi3Components` — fine. (Could be replaced with an explicit `ModelManager.registerIfNeeded()` call for clarity, but not required.)
- Entitlements for the `proyecto` CLI target — unsigned, fallback path is correct and documented.

---

## 7. Candid Notes

A few things I'd flag even though the user didn't ask:

- **The `phi3RequiredFiles` block exists because 0.7 required it.** Nothing about our use case genuinely needs the declared list; the bare pattern is a clean win here.
- **`proyecto download` / `proyecto init` use different models.** This is the kind of thing that bites users in a "works on my machine, fails on a fresh checkout" way. Worth fixing regardless of the SwiftAcervo version.
- **Tests polluting `~/Library/Application Support/SwiftAcervo/SharedModels/`** is obnoxious on dev machines — a 2.3 GB file that doesn't get cleaned up. Fix it while you're in there.
- **The `ACERVO_MIGRATION_REQUIREMENTS.md` doc at `Docs/ACERVO_MIGRATION_REQUIREMENTS.md`** describes a "Target State" where SwiftProyecto doesn't touch SwiftAcervo directly (only via SwiftBruja). We are not in that state — `ModelManager.swift`, `IterativeProjectGenerator.swift`, and `ProyectoCLI.swift` all import SwiftAcervo directly. Either the doc is aspirational and should be marked as such, or the direct imports should be removed and routed through Bruja. I lean toward archiving the doc: direct SwiftAcervo use is fine, USAGE.md positions it as a first-class consumer API.

---

## Appendix A — Referenced Files

- `Package.swift`
- `Sources/SwiftProyecto/Infrastructure/ModelManager.swift`
- `Sources/SwiftProyecto/SwiftProyecto.swift`
- `Sources/proyecto/ProyectoCLI.swift`
- `Sources/proyecto/IterativeProjectGenerator.swift`
- `Tests/SwiftProyectoTests/AcervoDownloadIntegrationTests.swift`
- `Tests/SwiftProyectoTests/ProjectGenerationIntegrationTest.swift`
- `.github/workflows/ensure-model-cdn.yml`
- `AGENTS.md`, `CLAUDE.md`, `README.md`
- `Docs/ACERVO_MIGRATION_REQUIREMENTS.md`

## Appendix B — Upstream References

- `../SwiftAcervo/USAGE.md` — integration contract
- `../SwiftAcervo/CHANGELOG.md` — 0.8.0 release notes
- `../SwiftAcervo/ACERVO_CDN_UPLOAD_PATTERN.md` — CDN workflow standard
- `../SwiftAcervo/SHARED_MODELS_DIRECTORY.md` — directory layout + App Group troubleshooting

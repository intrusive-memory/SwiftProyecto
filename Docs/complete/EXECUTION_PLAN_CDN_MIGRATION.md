# EXECUTION_PLAN: SwiftProyecto CDN Model Management

**Version**: 1.0  
**Date**: 2026-04-17  
**Status**: READY FOR EXECUTION  
**Requirements Source**: `REQUIREMENTS.md`

---

## Terminology

**Mission** — Standardize SwiftProyecto LLM model management via SwiftAcervo CDN integration (Phi-3-mini-4k-4bit).

**Sortie** — Atomic task executed by a single agent: implement one component, test one flow, or document one pattern.

**Work Unit** — Phase grouping: CDN Upload (Phase 1), Integration (Phase 2), Testing (Phase 3), Documentation (Phase 4).

---

## Mission Overview

Migrate SwiftProyecto from direct HuggingFace downloads to SwiftAcervo CDN-based model management. Enables shared model storage, integrity verification, and streamlined download workflows.

**Success Criteria**:
- GitHub Actions workflow uploads Phi-3 model to Cloudflare R2 with manifest
- SwiftProyecto ComponentDescriptor registered at startup
- `proyecto download` uses `Acervo.ensureComponentReady()`
- All integration tests pass
- Documentation reflects new architecture

---

## Work Units & Sorties

### WORK UNIT 1: CDN Upload Setup (Phase 1)

**Objective**: Create GitHub Actions workflow to download model from HuggingFace, generate manifest, and upload to R2.

#### Sortie 1.1: Create GitHub Actions Workflow

**Objective**: Implement `.github/workflows/ensure-model-cdn.yml` that uploads Phi-3 model to CDN.

**Entry Criteria**:
- SwiftProyecto repository accessible
- `.github/workflows/` directory exists
- Cloudflare R2 secrets configured (verified via other workflows)

**Exit Criteria**:
- ✅ Workflow file created at `.github/workflows/ensure-model-cdn.yml`
- ✅ Workflow downloads `mlx-community/Phi-3-mini-4k-instruct-4bit` from HuggingFace
- ✅ Generates `manifest.json` with SHA-256 checksums for all 4 files
- ✅ Computes `manifestChecksum` (sorted SHA-256 concatenation)
- ✅ Uploads all files to `models/mlx-community_Phi-3-mini-4k-instruct-4bit/` on R2
- ✅ Includes idempotency: skips if manifest already exists on CDN
- ✅ Includes verification: downloads and validates all checksums
- ✅ Triggers: `workflow_dispatch` + push to main when workflow file changes

**Effort**: 1.5 hours | **Model**: Haiku

---

#### Sortie 1.2: Test CDN Upload Workflow

**Objective**: Manually trigger workflow, verify manifest and files are correctly uploaded to R2.

**Entry Criteria**:
- Sortie 1.1 complete (workflow file created)
- GitHub Actions workflow accessible for manual dispatch

**Exit Criteria**:
- ✅ Workflow triggered via `workflow_dispatch`
- ✅ Workflow completes successfully
- ✅ Manifest.json accessible at CDN URL and valid
- ✅ All 4 model files (config.json, tokenizer.json, tokenizer_config.json, model.safetensors) downloadable from CDN
- ✅ SHA-256 checksums in manifest match actual file checksums
- ✅ ManifestChecksum computation verified correct

**Effort**: 1 hour | **Model**: Haiku

---

### WORK UNIT 2: SwiftAcervo Integration (Phase 2)

**Objective**: Register Phi-3 ComponentDescriptor with SwiftAcervo, update download logic.

#### Sortie 2.1: Add SwiftAcervo Dependency

**Objective**: Add SwiftAcervo to `Package.swift` and import in project.

**Entry Criteria**:
- `Package.swift` accessible
- SwiftProyecto builds without errors

**Exit Criteria**:
- ✅ SwiftAcervo dependency added to `Package.swift` (main branch)
- ✅ Project imports SwiftAcervo successfully
- ✅ Project builds without warnings: `xcodebuild build -scheme SwiftProyecto`

**Effort**: 0.5 hours | **Model**: Haiku

---

#### Sortie 2.2: Create ModelManager with ComponentDescriptor

**Objective**: Implement `Sources/SwiftProyecto/Infrastructure/ModelManager.swift` with Phi-3 descriptor.

**Entry Criteria**:
- Sortie 2.1 complete (SwiftAcervo dependency added)
- `Sources/SwiftProyecto/Infrastructure/` directory exists
- Manifest values known from CDN (size, SHA-256)

**Exit Criteria**:
- ✅ `ModelManager.swift` created with:
  - `ComponentDescriptor` for Phi-3 with all 4 required files
  - File paths, sizes, and SHA-256 from manifest
  - `estimatedSizeBytes: 2_315_000_000`
  - `minimumMemoryBytes: 8_000_000_000`
  - Metadata: quantization, context_length, architecture, cdn_url
- ✅ `Acervo.register()` called at module init
- ✅ Project builds without errors

**Effort**: 1 hour | **Model**: Haiku

---

#### Sortie 2.3: Update DownloadCommand to Use ModelManager

**Objective**: Replace HuggingFace download logic in `DownloadCommand.run()` with `Acervo.ensureComponentReady()`.

**Entry Criteria**:
- Sortie 2.2 complete (ModelManager with descriptor exists)
- `DownloadCommand.swift` accessible
- Current download logic identifiable

**Exit Criteria**:
- ✅ `DownloadCommand.run()` calls `Acervo.ensureComponentReady("proyecto-llm-phi3-mini-4k-4bit")`
- ✅ Progress callback implemented (displays percent or file status)
- ✅ Error handling for `AcervoError.modelNotFound`, `downloadFailed`
- ✅ HuggingFace download code removed
- ✅ Project builds and tests pass

**Effort**: 1.5 hours | **Model**: Haiku

---

#### Sortie 2.4: Update Model Path Resolution

**Objective**: Modify `IterativeProjectGenerator.swift` to use `Acervo.sharedModelsDirectory` for model paths.

**Entry Criteria**:
- Sortie 2.3 complete (DownloadCommand updated)
- `IterativeProjectGenerator.swift` accessible
- SwiftBruja inference logic unchanged

**Exit Criteria**:
- ✅ `IterativeProjectGenerator` uses `Acervo.sharedModelsDirectory` for model paths
- ✅ Model path resolves to `~/Library/SharedModels/mlx-community_Phi-3-mini-4k-instruct-4bit/`
- ✅ SwiftBruja inference (`Bruja.query()`) continues unchanged
- ✅ Project builds and tests pass

**Effort**: 0.5 hours | **Model**: Haiku

---

### WORK UNIT 3: Testing (Phase 3)

**Objective**: Verify integration end-to-end.

#### Sortie 3.1: Integration Test: Download from CDN

**Objective**: Create integration test that downloads Phi-3 from CDN via `proyecto download`.

**Entry Criteria**:
- Sortie 2.4 complete (model path resolution updated)
- Test infrastructure in place (XCTest)
- Local model removed for testing

**Exit Criteria**:
- ✅ Integration test downloads model from CDN successfully
- ✅ All 4 files present in `~/Library/SharedModels/mlx-community_Phi-3-mini-4k-instruct-4bit/`
- ✅ SHA-256 verification succeeds
- ✅ Progress callback invoked during download
- ✅ Test mocks are clean (no real CDN access in unit tests)

**Effort**: 1 hour | **Model**: Haiku

---

#### Sortie 3.2: Integration Test: PROJECT.md Generation

**Objective**: Verify `proyecto init` generates PROJECT.md successfully with CDN-downloaded model.

**Entry Criteria**:
- Sortie 3.1 complete (download test passes)
- Test screenplay directory available
- `IterativeProjectGenerator` updated

**Exit Criteria**:
- ✅ `proyecto init` generates PROJECT.md from test screenplay
- ✅ LLM inference via Bruja.query() completes without errors
- ✅ Generated PROJECT.md is valid and well-formed
- ✅ Test passes

**Effort**: 1 hour | **Model**: Haiku

---

#### Sortie 3.3: Manual Verification

**Objective**: Manually test `proyecto download` and model sharing across tools.

**Entry Criteria**:
- Sortie 3.2 complete (all tests pass)
- SwiftBruja accessible for cross-tool test
- Local machine ready for manual testing

**Exit Criteria**:
- ✅ `proyecto download` downloads Phi-3 model from CDN
- ✅ Progress display shows download status
- ✅ Model appears in `~/Library/SharedModels/`
- ✅ SwiftBruja can access the model (cross-library sharing works)
- ✅ `proyecto init` generates PROJECT.md with inference

**Effort**: 1 hour | **Model**: Haiku

---

### WORK UNIT 4: Documentation (Phase 4)

**Objective**: Update all documentation to reflect CDN architecture.

#### Sortie 4.1: Update README.md

**Objective**: Document CDN model management in README.

**Entry Criteria**:
- All prior sorties complete
- `README.md` accessible

**Exit Criteria**:
- ✅ README includes "Model Management" section
- ✅ Explains automatic CDN download on first run
- ✅ Documents Phi-3 model storage location
- ✅ Notes shared storage across intrusive-memory tools
- ✅ Includes `proyecto download` usage

**Effort**: 0.5 hours | **Model**: Haiku

---

#### Sortie 4.2: Update AGENTS.md

**Objective**: Document SwiftAcervo integration patterns in AGENTS.md.

**Entry Criteria**:
- All prior sorties complete
- `AGENTS.md` exists

**Exit Criteria**:
- ✅ AGENTS.md includes "Model Validation" section
- ✅ References SwiftAcervo validation pattern
- ✅ Documents ComponentDescriptor registration
- ✅ Explains download workflow
- ✅ Links to SwiftAcervo AGENTS.md

**Effort**: 0.5 hours | **Model**: Haiku

---

#### Sortie 4.3: Update CHANGELOG.md

**Objective**: Document migration from HuggingFace to CDN in CHANGELOG.

**Entry Criteria**:
- All prior sorties complete
- `CHANGELOG.md` exists

**Exit Criteria**:
- ✅ CHANGELOG.md documents version with CDN migration
- ✅ Explains breaking changes (if any) for users
- ✅ Notes improved performance / reliability
- ✅ Includes migration notes for existing users

**Effort**: 0.5 hours | **Model**: Haiku

---

## Sortie Dependencies

```
Sortie 1.1 → 1.2 (sequential)
    ↓
Sortie 2.1 → 2.2 → 2.3 → 2.4 (sequential)
    ↓
Sortie 3.1 → 3.2 → 3.3 (sequential)
    ↓
Sortie 4.1, 4.2, 4.3 (parallel)
```

**Critical Path**: 1.1 → 1.2 → 2.1 → 2.2 → 2.3 → 2.4 → 3.1 → 3.2 → 3.3 (sequential)

**Parallelization**: Documentation (4.1–4.3) can run in parallel after 3.3 complete.

---

## Execution Timeline

| Phase | Sorties | Est. Hours | Notes |
|-------|---------|-----------|-------|
| CDN Setup | 1.1–1.2 | 2.5 | Sequential |
| Integration | 2.1–2.4 | 3 | Sequential |
| Testing | 3.1–3.3 | 3 | Sequential |
| Documentation | 4.1–4.3 | 1.5 | Parallel |
| **Total** | **12 sorties** | **~10** | Critical path: ~8 hrs |

---

## Success Checklist

- [ ] Phase 1: CDN manifest valid, files downloadable
- [ ] Phase 2: ComponentDescriptor registered, DownloadCommand uses Acervo
- [ ] Phase 3: All integration tests pass
- [ ] Phase 4: README, AGENTS.md, CHANGELOG updated

---

**Status**: Ready for `/mission-supervisor start SwiftProyecto/EXECUTION_PLAN.md`

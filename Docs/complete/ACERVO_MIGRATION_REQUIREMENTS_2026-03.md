**Status**: HISTORICAL — superseded by `EXECUTION_PLAN.md` (2026-04-25) and `ACERVO_AUDIT.md`. The "Target State" in §"Target Architecture" was never adopted; SwiftProyecto imports SwiftAcervo directly, which is the pattern recommended by `../SwiftAcervo/USAGE.md` 0.8.0.

---

# SwiftProyecto CDN Migration Requirements

**Date**: 2026-03-25
**Version**: 2.0
**Status**: ACTIVE

---

## Overview

Configure SwiftProyecto to use CDN-hosted LLM models with App Group container storage. This document outlines the technical requirements for:

1. **App Group Container**: Ensure proyecto stores models in shared container for cross-app access
2. **CDN Infrastructure**: Host LLM models on CDN with manifest-based integrity verification
3. **SwiftBruja Integration**: Leverage SwiftBruja's SwiftAcervo integration (no direct migration needed)

---

## Architecture Decision

**DECISION**: Keep SwiftBruja as LLM abstraction layer.

**Rationale**:
- SwiftBruja provides clean API over MLX Swift complexity
- SwiftBruja already uses SwiftAcervo internally for model management
- SwiftProyecto stays simple: just calls `Bruja.download()` and `Bruja.query()`
- No code changes needed in SwiftProyecto beyond configuration

---

## Current Architecture

### SwiftProyecto (Current State)

```
proyecto CLI
├── SwiftBruja (dependency)
│   ├── SwiftAcervo: Model downloads/storage
│   ├── MLX Swift: LLM inference
│   └── Provides: Bruja.download() + Bruja.query()
└── Usage:
    ├── proyecto download → Bruja.download() from HuggingFace
    └── proyecto init → Bruja.query() for LLM inference
```

**Current Model Storage**: `~/Library/SharedModels/` (via SwiftAcervo)
**Current Model Source**: HuggingFace Hub
**Current LLM**: `Bruja.defaultModel` (currently `mlx-community/Qwen3-Coder-Next-4bit`)

---

## Target Architecture

### SwiftProyecto (Target State)

```
proyecto CLI
├── SwiftBruja (dependency) - UNCHANGED
│   ├── SwiftAcervo: Model downloads/storage (now with CDN support)
│   ├── MLX Swift: LLM inference
│   └── Provides: Bruja.download() + Bruja.query()
└── Usage:
    ├── proyecto download → Bruja.download() from CDN (automatic)
    └── proyecto init → Bruja.query() (unchanged)
```

**Target Model Storage**: App Group Container `group.intrusive-memory.models/SharedModels/`
**Target Model Source**: Private CDN with manifest.json (fallback to HuggingFace)
**Target LLM**: `Bruja.defaultModel` served from CDN (currently `mlx-community/Qwen3-Coder-Next-4bit`)

---

## Requirements

### R1: App Group Container for Shared Storage

**Description**: Ensure SwiftAcervo (via SwiftBruja) uses the App Group container for model storage, shared across all intrusive-memory tools.

**App Group ID**: `group.intrusive-memory.models`

**Storage Path**:
```
<App Group Container>/SharedModels/
└── mlx-community_Qwen3-Coder-Next-4bit/
    ├── config.json
    ├── tokenizer.json
    ├── tokenizer_config.json
    └── model.safetensors
```

**Implementation**:
1. **Verify SwiftAcervo Configuration**:
   - Check if SwiftAcervo already uses App Group container
   - If yes: No changes needed in SwiftProyecto ✅
   - If no: Configure SwiftAcervo to use `group.intrusive-memory.models`

2. **Verify proyecto Entitlements** (if needed):
   - Check if `proyecto.entitlements` exists and includes App Group
   - Add entitlements file if required for App Group access
   - Note: May not be needed if SwiftBruja handles this transparently

3. **Test Storage Location**:
   ```bash
   proyecto download
   # Verify model is in App Group container, not ~/Library/SharedModels/
   ```

**Acceptance Criteria**:
- [ ] SwiftAcervo uses App Group container `group.intrusive-memory.models`
- [ ] Models downloaded by proyecto are stored in App Group container
- [ ] Models are accessible to other tools (SwiftVoxAlta, etc.)
- [ ] macOS and iOS share the same container path

**Notes**:
- SwiftBruja may already handle this configuration
- SwiftProyecto code changes are NOT required (SwiftBruja provides abstraction)
- This is primarily a SwiftAcervo/SwiftBruja configuration task

---

### R2: CDN Model Hosting

#### R2.1: CDN Infrastructure Setup

**Description**: Host LLM models on a CDN with manifest-based integrity verification.

**CDN URL Structure**:
```
https://pub-<id>.r2.dev/models/{slug}/
├── manifest.json
├── config.json
├── tokenizer.json
├── tokenizer_config.json
└── model.safetensors
```

**Example** (using current default model):
```
https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models/mlx-community_Qwen3-Coder-Next-4bit/
├── manifest.json
├── config.json
├── tokenizer.json
├── tokenizer_config.json
└── model.safetensors
```

**Acceptance Criteria**:
- [ ] CDN URL is accessible from macOS and iOS
- [ ] All model files are publicly downloadable
- [ ] HTTPS is enforced
- [ ] CORS headers allow downloads from Swift URLSession

---

#### R2.2: Generate manifest.json for Each Model

**Description**: Create a `manifest.json` file for each LLM model on the CDN.

**Manifest Format** (per SwiftAcervo CDNManifest.swift):
```json
{
  "manifestVersion": 1,
  "modelId": "mlx-community/Qwen3-Coder-Next-4bit",
  "slug": "mlx-community_Qwen3-Coder-Next-4bit",
  "updatedAt": "2026-03-25T12:00:00Z",
  "files": [
    {
      "path": "config.json",
      "sha256": "<64-char-hex-digest>",
      "sizeBytes": 1234
    },
    {
      "path": "tokenizer.json",
      "sha256": "<64-char-hex-digest>",
      "sizeBytes": 5678
    },
    {
      "path": "tokenizer_config.json",
      "sha256": "<64-char-hex-digest>",
      "sizeBytes": 910
    },
    {
      "path": "model.safetensors",
      "sha256": "<64-char-hex-digest>",
      "sizeBytes": 2314567890
    }
  ],
  "manifestChecksum": "<64-char-hex-digest-of-sorted-file-checksums>"
}
```

**Manifest Checksum Calculation**:
1. Extract all `files[].sha256` values
2. Sort lexicographically
3. Concatenate into a single string
4. Compute SHA-256 of the concatenation
5. Store as lowercase hex string

**Acceptance Criteria**:
- [ ] manifest.json passes SwiftAcervo verification (`CDNManifest.verifyChecksum()`)
- [ ] All file SHA-256 checksums are correct
- [ ] All file sizes are accurate
- [ ] manifestChecksum matches computed value

---

#### R2.3: Upload LLM Model to CDN

**Description**: Upload the default LLM model and manifest to the CDN.

**Default Model**: `Bruja.defaultModel` (currently `mlx-community/Qwen3-Coder-Next-4bit`)

**Required Files**:
- `config.json` - Model configuration
- `tokenizer.json` - Tokenizer vocabulary
- `tokenizer_config.json` - Tokenizer settings
- `model.safetensors` - Quantized model weights
- `manifest.json` - File integrity manifest

**Upload Checklist**:
- [ ] Download model from HuggingFace
- [ ] Verify model works with MLX Swift
- [ ] Generate SHA-256 checksums for all files
- [ ] Create manifest.json
- [ ] Upload all files to CDN
- [ ] Test download from CDN URL

---

### R3: Documentation and Testing

#### R3.1: Update Documentation

**Files to Update**:
- `README.md` - Document CDN model hosting (if user-facing)
- `AGENTS.md` - Update architecture diagrams if changed
- `CHANGELOG.md` - Document CDN migration (likely patch version bump)

**New Content** (if applicable):
- Document that models are now served from CDN (transparent to users)
- Explain App Group container usage for model sharing
- Add troubleshooting for CDN download issues

**Acceptance Criteria**:
- [ ] Documentation reflects CDN hosting (if user-facing changes)
- [ ] App Group container usage is documented
- [ ] CDN fallback behavior is clear (CDN → HuggingFace fallback)

**Notes**:
- If CDN migration is transparent (SwiftBruja handles it), minimal doc updates needed
- Focus on user-facing behavior: model download location, cross-tool sharing

---

#### R3.2: End-to-End Testing

**Test Scenarios**:

1. **Fresh Install (no existing models)**:
   - [ ] `proyecto download` downloads from CDN (via SwiftBruja → SwiftAcervo)
   - [ ] Files are verified with SHA-256 checksums
   - [ ] Model appears in App Group container `group.intrusive-memory.models`
   - [ ] `proyecto init` works with downloaded model (inference via SwiftBruja)

2. **Existing Model (already downloaded)**:
   - [ ] `proyecto download` skips download (idempotent)
   - [ ] `proyecto download --force` re-downloads from CDN
   - [ ] Integrity verification passes for all files

3. **Model Sharing**:
   - [ ] Model downloaded by proyecto is visible to SwiftBruja
   - [ ] Model downloaded by SwiftBruja is visible to proyecto
   - [ ] Both tools use the same App Group container

4. **Error Handling**:
   - [ ] Network errors are handled gracefully
   - [ ] Corrupted files are detected and rejected
   - [ ] Manifest checksum failures are caught
   - [ ] Clear error messages guide user actions

---

#### R3.3: Version Bump and Release

**Version**: 3.3.0 (patch/minor bump - no breaking changes)

**Rationale**: CDN migration is transparent to users. SwiftBruja handles it internally via SwiftAcervo. No API changes in SwiftProyecto.

**Locations to Update**:
- `ProyectoCLI.swift` - version string (currently 2.5.0 → 3.3.0)
- `CHANGELOG.md` - document changes

**Release Notes**:
- Models now served from CDN for faster downloads (transparent to users)
- App Group container for model sharing across intrusive-memory tools
- Integrity verification with SHA-256 checksums (via SwiftAcervo)
- No API changes - existing `proyecto download` and `proyecto init` commands unchanged

**Acceptance Criteria**:
- [ ] Version bumped to 3.3.0
- [ ] CHANGELOG documents CDN migration
- [ ] Git tag created
- [ ] GitHub release published (optional for patch release)

---

## Implementation Phases

### Phase 1: CDN Infrastructure Setup
**Owner**: Infrastructure / DevOps (external to SwiftProyecto codebase)

- [ ] Set up Cloudflare R2 bucket or alternative CDN
- [ ] Download LLM model from HuggingFace: `Bruja.defaultModel` (currently `mlx-community/Qwen3-Coder-Next-4bit`)
- [ ] Generate SHA-256 checksums for all model files
- [ ] Create manifest.json with integrity checksums
- [ ] Upload model files + manifest.json to CDN
- [ ] Verify CDN URL is accessible (HTTPS, CORS, public read)
- [ ] Test download via `curl` or Swift URLSession

**Estimated Time**: 2-4 hours
**Dependencies**: Cloudflare R2 account (or alternative CDN)

---

### Phase 2: SwiftAcervo Configuration
**Owner**: SwiftBruja / SwiftAcervo maintainer

- [ ] Verify SwiftAcervo uses App Group container `group.intrusive-memory.models`
- [ ] Configure SwiftAcervo with CDN base URL
- [ ] Update SwiftBruja to use latest SwiftAcervo (if needed)
- [ ] Test that `Bruja.download()` pulls from CDN (not HuggingFace)

**Estimated Time**: 1-2 hours
**Dependencies**: Phase 1 complete, SwiftAcervo access

---

### Phase 3: SwiftProyecto Testing & Release
**Owner**: SwiftProyecto maintainer

- [ ] Verify proyecto uses latest SwiftBruja (which uses SwiftAcervo + CDN)
- [ ] Run end-to-end tests (R3.2)
- [ ] Update documentation if needed (R3.1)
- [ ] Bump version to 3.3.0 (R3.3)
- [ ] Create git tag and GitHub release

**Estimated Time**: 1-2 hours
**Dependencies**: Phase 1 & 2 complete

---

## Open Questions

### 1. CDN URL Configuration
**Question**: What is the CDN base URL for model hosting?

**Options**:
- Cloudflare R2: `https://pub-<id>.r2.dev/models/`
- Custom domain: `https://models.intrusive-memory.com/`
- Current assumption: `https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models/`

**Status**: ⚠️ Needs confirmation

---

### 2. App Group Container Status
**Question**: Does SwiftAcervo already use App Group container `group.intrusive-memory.models`?

**If YES**: No configuration needed, SwiftProyecto inherits this via SwiftBruja ✅

**If NO**: Need to configure SwiftAcervo to use App Group container (Phase 2 task)

**Status**: ⚠️ Needs verification (check SwiftAcervo source)

---

### 3. Model Selection
**Question**: Should we use the current `Bruja.defaultModel` or specify a different model?

**Current Model**: `mlx-community/Qwen3-Coder-Next-4bit` (4-bit quantized)
**Alternative**: Could use a different model if SwiftBruja's default changes

**Status**: ✅ Resolved - Use whatever model `Bruja.defaultModel` points to (currently Qwen3-Coder-Next-4bit)

---

### 4. Model Update Strategy
**Question**: How will we handle model updates on the CDN?

**Options**:
- **Option A**: Update in-place (same URL, new manifest checksums)
  - Pros: Simple, users automatically get updates
  - Cons: Breaking change if model incompatible
- **Option B**: Versioned model IDs (e.g., `phi3-mini-v2`)
  - Pros: Explicit upgrades, no breaking changes
  - Cons: More CDN storage, manual upgrade path

**Recommendation**: Option A for patch versions, Option B for major model changes

**Status**: ⚠️ Needs decision

---

## Success Criteria

### Must Have
- [x] **Architecture Decision**: Keep SwiftBruja (no direct migration) ✅
- [ ] **CDN Infrastructure**: Models hosted on CDN with manifest.json
- [ ] **App Group Storage**: Models stored in `group.intrusive-memory.models`
- [ ] **Integrity Verification**: SHA-256 checksums validated on download
- [ ] **End-to-End Tests**: All test scenarios pass (R3.2)

### Nice to Have
- [ ] **Model Sharing**: Other tools (SwiftVoxAlta, etc.) can access shared models
- [ ] **Documentation**: Architecture diagrams updated
- [ ] **Fallback**: Graceful fallback to HuggingFace if CDN unavailable

### Non-Goals (Explicitly Out of Scope)
- ❌ Remove SwiftBruja dependency
- ❌ Add direct MLX Swift integration
- ❌ Implement custom LLM inference wrapper
- ❌ Breaking API changes to SwiftProyecto

---

## Next Steps

1. **Confirm CDN URL** (Open Question #1)
   - Where will models be hosted?
   - What's the base URL?

2. **Check SwiftAcervo Storage** (Open Question #2)
   - Does it already use App Group container?
   - If not, configure it

3. **Start Phase 1: CDN Setup**
   - Upload model to CDN
   - Generate manifest.json
   - Test CDN accessibility

4. **Update SwiftBruja/SwiftAcervo** (Phase 2)
   - Point to CDN in SwiftAcervo configuration
   - Test downloads work from CDN

5. **Test & Release SwiftProyecto** (Phase 3)
   - Run end-to-end tests
   - Bump version to 3.3.0
   - Document changes in CHANGELOG.md

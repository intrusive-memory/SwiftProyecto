# SwiftProyecto CDN Model Management Requirements

**Date**: 2026-03-25  
**Status**: APPROVED FOR IMPLEMENTATION (Updated: 2026-04-17)

---

## Overview

Migrate SwiftProyecto from downloading LLM models directly from HuggingFace to using SwiftAcervo's CDN-based model management system. This enables:

1. **Shared model storage** across all intrusive-memory tools via App Group container
2. **CDN-hosted models** with integrity verification via SHA-256 checksums
3. **Automatic download** when models are missing locally

---

## Architecture

```
GitHub Actions Workflow
    ↓
Download from HuggingFace → Generate manifest.json (SHA-256) → Upload to CDN
                                                                      ↓
                                                            Cloudflare R2 CDN
                                                                      ↓
proyecto CLI (local machine)
    ↓
SwiftAcervo checks local cache → Download from CDN if missing → Verify SHA-256
    ↓
App Group Container: group.intrusive-memory.models/SharedModels/
    ↓
MLX Swift loads model for inference
```

---

## Components

### 1. CDN Infrastructure

**CDN URL**: `https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev`
**Storage**: Cloudflare R2 bucket `intrusive-memory-audio`

**Model URL Structure**:
```
https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models/{slug}/
├── manifest.json          ← Integrity manifest with SHA-256 checksums
├── config.json            ← Model configuration
├── tokenizer.json         ← Tokenizer vocabulary
├── tokenizer_config.json  ← Tokenizer settings
└── model.safetensors      ← Quantized model weights
```

**Example**:
```
https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models/mlx-community_Phi-3-mini-4k-instruct-4bit/
```

---

### 2. LLM Model Specification

**Model**: `mlx-community/Phi-3-mini-4k-instruct-4bit`
**Purpose**: PROJECT.md generation via local LLM inference
**Size**: ~2.15 GB
**Quantization**: 4-bit for memory efficiency

**Required Files**:
- `config.json` - Model architecture configuration
- `tokenizer.json` - Tokenizer vocabulary mappings
- `tokenizer_config.json` - Tokenizer behavior settings
- `model.safetensors` - 4-bit quantized model weights

---

### 3. Manifest Format (SwiftAcervo Compatible)

The `manifest.json` follows SwiftAcervo's `CDNManifest` structure:

```json
{
  "manifestVersion": 1,
  "modelId": "mlx-community/Phi-3-mini-4k-instruct-4bit",
  "slug": "mlx-community_Phi-3-mini-4k-instruct-4bit",
  "updatedAt": "2026-03-25T12:00:00Z",
  "files": [
    {
      "path": "config.json",
      "sha256": "abc123...",
      "sizeBytes": 1234
    },
    {
      "path": "tokenizer.json",
      "sha256": "def456...",
      "sizeBytes": 5678
    },
    {
      "path": "tokenizer_config.json",
      "sha256": "ghi789...",
      "sizeBytes": 910
    },
    {
      "path": "model.safetensors",
      "sha256": "jkl012...",
      "sizeBytes": 2314567890
    }
  ],
  "manifestChecksum": "xyz789..."
}
```

**Manifest Checksum Calculation**:
1. Extract all `files[].sha256` values
2. Sort lexicographically
3. Concatenate into a single string
4. Compute SHA-256 hash of the concatenation
5. Store as lowercase hex string

**Purpose**: Ensures the manifest itself hasn't been tampered with.

---

## Implementation

### Phase 1: CDN Upload (GitHub Actions)

**Workflow**: `.github/workflows/ensure-model-cdn.yml`

**Trigger**:
- Manual: `workflow_dispatch`
- Automatic: Push to `main` when workflow file changes

**Steps**:
1. **Check CDN**: Verify if manifest already exists
2. **Download**: Fetch model files from HuggingFace (if missing)
3. **Generate Manifest**: Create `manifest.json` with SHA-256 checksums
4. **Upload to R2**: Sync model files to Cloudflare R2
5. **Verify**: Download and verify all files match manifest

**Secrets Required**:
- `CLOUDFLARE_ACCOUNT_ID` - Cloudflare account identifier
- `R2_ACCESS_KEY_ID` - R2 API access key
- `R2_SECRET_ACCESS_KEY` - R2 API secret key

**Files Uploaded**:
```
models/mlx-community_Phi-3-mini-4k-instruct-4bit/
├── manifest.json
├── config.json
├── tokenizer.json
├── tokenizer_config.json
└── model.safetensors
```

---

### Phase 2: SwiftAcervo Integration

**Package Dependency**:
```swift
// Package.swift
.package(url: "https://github.com/intrusive-memory/SwiftAcervo.git", branch: "main")
```

**Component Registration** (in proyecto CLI startup):
```swift
import SwiftAcervo

// Register LLM component with SwiftAcervo
let llmComponent = ComponentDescriptor(
    id: "proyecto-llm-phi3-mini-4k-4bit",
    type: .languageModel,
    displayName: "Phi-3 Mini 4K Instruct (4-bit)",
    huggingFaceRepo: "mlx-community/Phi-3-mini-4k-instruct-4bit",
    files: [
        ComponentFile(
            relativePath: "config.json",
            expectedSizeBytes: <from manifest>,
            sha256: <from manifest>
        ),
        ComponentFile(
            relativePath: "tokenizer.json",
            expectedSizeBytes: <from manifest>,
            sha256: <from manifest>
        ),
        ComponentFile(
            relativePath: "tokenizer_config.json",
            expectedSizeBytes: <from manifest>,
            sha256: <from manifest>
        ),
        ComponentFile(
            relativePath: "model.safetensors",
            expectedSizeBytes: <from manifest>,
            sha256: <from manifest>
        )
    ],
    estimatedSizeBytes: 2_315_000_000, // ~2.15 GB
    minimumMemoryBytes: 8_000_000_000, // 8 GB minimum RAM
    metadata: [
        "quantization": "4-bit",
        "context_length": "4096",
        "architecture": "phi3",
        "cdn_url": "https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev"
    ]
)

Acervo.register(llmComponent)
```

**Download on Demand**:
```swift
// In DownloadCommand.run()
try await Acervo.ensureComponentReady(
    "proyecto-llm-phi3-mini-4k-4bit",
    progress: { progress in
        if showProgress {
            let percent = Int(progress.overallProgress * 100)
            print("\rDownloading \(progress.fileName): \(percent)%", terminator: "")
            fflush(stdout)
        }
    }
)

if showProgress {
    print("\nDownload complete!")
}
```

**Model Location** (macOS):
```
~/Library/SharedModels/
└── mlx-community_Phi-3-mini-4k-instruct-4bit/
    ├── config.json
    ├── tokenizer.json
    ├── tokenizer_config.json
    └── model.safetensors
```

**Note**: CLI tools run unsandboxed and don't require App Group entitlements. The shared directory is managed by SwiftAcervo's `sharedModelsDirectory` property.

---

### Phase 3: LLM Inference

**Two Options**:

**Decision**: Keep SwiftBruja for inference

- No changes to `IterativeProjectGenerator.swift`
- SwiftBruja continues to handle `Bruja.query()`
- SwiftBruja uses SwiftAcervo internally for model access
- **Benefit**: Minimal code changes, faster migration, proven inference stack

---

## Requirements

### R1: GitHub Actions Workflow

- [ ] `.github/workflows/ensure-model-cdn.yml` created
- [ ] Workflow downloads `mlx-community/Phi-3-mini-4k-instruct-4bit` from HuggingFace
- [ ] Manifest generated with SHA-256 checksums for all files
- [ ] Manifest checksum computed correctly (sorted SHA-256 concatenation)
- [ ] Files uploaded to `models/mlx-community_Phi-3-mini-4k-instruct-4bit/` on R2
- [ ] Verification step confirms all files downloadable and checksums match

### R2: SwiftAcervo Integration

- [ ] SwiftAcervo dependency added to `Package.swift`
- [ ] LLM component registered at proyecto startup
- [ ] Component descriptor includes all required files with checksums
- [ ] `proyecto download` uses `Acervo.ensureComponentReady()`
- [ ] Progress callbacks display download status
- [ ] SHA-256 verification succeeds for all downloaded files

### R3: Model Storage

- [ ] Models stored in shared directory via `Acervo.sharedModelsDirectory`
- [ ] Path: `~/Library/SharedModels/mlx-community_Phi-3-mini-4k-instruct-4bit/` (macOS)
- [ ] Models shared across all intrusive-memory CLI tools
- [ ] No entitlements required (CLI tools run unsandboxed)

### R4: LLM Inference

**Decision**: Keep SwiftBruja for inference (no migration to direct MLX)

- [ ] SwiftBruja dependency retained for inference
- [ ] `Bruja.query()` continues to work unchanged
- [ ] SwiftBruja uses SwiftAcervo internally for model paths
- [ ] No changes to `IterativeProjectGenerator.swift` required
- [ ] Minimal code changes for faster deployment

### R5: Testing

- [ ] `proyecto download` downloads from CDN successfully
- [ ] Progress display matches original behavior
- [ ] `proyecto download --force` re-downloads from CDN
- [ ] `proyecto init` works with CDN-downloaded model
- [ ] LLM inference quality unchanged
- [ ] Model appears in `Acervo.listModels()`
- [ ] Model shared with other tools (verified by checking App Group container)

### R6: Documentation

- [ ] README.md updated with CDN model management
- [ ] AGENTS.md documents SwiftAcervo integration
- [ ] CLAUDE.md updated if needed
- [ ] CHANGELOG.md documents changes
- [ ] Migration notes for existing users

---

## Security Considerations

1. **GitHub Secrets**: R2 credentials stored as repository secrets
2. **CDN Public Access**: Models are publicly readable (no sensitive data)
3. **Integrity Verification**: SHA-256 checksums prevent tampering
4. **Manifest Checksum**: Ensures manifest integrity
5. **HTTPS Only**: All downloads over TLS

---

## Verification Steps

### After Workflow Runs:

1. **Check CDN**:
   ```bash
   curl https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models/mlx-community_Phi-3-mini-4k-instruct-4bit/manifest.json
   ```

2. **Verify Manifest**:
   ```bash
   # Download manifest
   curl -o manifest.json https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models/mlx-community_Phi-3-mini-4k-instruct-4bit/manifest.json

   # Extract and sort checksums
   jq -r '.files[].sha256' manifest.json | sort | tr -d '\n' | shasum -a 256

   # Compare to manifestChecksum field
   jq -r '.manifestChecksum' manifest.json
   ```

3. **Test Download**:
   ```bash
   # Download a file
   curl -o config.json https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models/mlx-community_Phi-3-mini-4k-instruct-4bit/config.json

   # Verify SHA-256
   shasum -a 256 config.json

   # Compare to manifest
   jq -r '.files[] | select(.path == "config.json") | .sha256' manifest.json
   ```

### After SwiftAcervo Integration:

1. **Test proyecto download**:
   ```bash
   # Remove local model if exists
   rm -rf ~/Library/SharedModels/mlx-community_Phi-3-mini-4k-instruct-4bit

   # Download via proyecto
   proyecto download

   # Verify files exist
   ls -lh ~/Library/SharedModels/mlx-community_Phi-3-mini-4k-instruct-4bit/
   ```

2. **Test PROJECT.md generation**:
   ```bash
   # Create test directory
   mkdir -p /tmp/test-podcast/episodes
   touch /tmp/test-podcast/episodes/{01,02,03}.fountain

   # Generate PROJECT.md
   proyecto init /tmp/test-podcast

   # Verify output
   cat /tmp/test-podcast/PROJECT.md
   ```

3. **Verify model sharing**:
   ```bash
   # Check if SwiftBruja can see the model
   bruja list | grep Phi-3

   # Or use SwiftAcervo directly
   swift run acervo list | grep Phi-3
   ```

---

## Success Criteria

- [ ] GitHub Actions workflow successfully uploads model to CDN
- [ ] Manifest.json is valid and checksums verify correctly
- [ ] All model files are publicly downloadable from CDN
- [ ] proyecto downloads model from CDN (not HuggingFace)
- [ ] SHA-256 verification passes for all files
- [ ] Model stored in App Group container
- [ ] Model visible to all intrusive-memory tools
- [ ] `proyecto init` generates PROJECT.md successfully
- [ ] LLM inference quality unchanged from previous version
- [ ] Documentation accurately reflects new architecture

---

## Execution Checklist

**Priority**: HIGH (2–3 hours)

### Phase 1: CDN Upload Setup
- [ ] Create `.github/workflows/ensure-model-cdn.yml` workflow
  - [ ] Download `mlx-community/Phi-3-mini-4k-instruct-4bit` from HuggingFace
  - [ ] Generate manifest.json with SHA-256 checksums
  - [ ] Compute manifestChecksum (sorted SHA-256 concatenation)
  - [ ] Upload to R2 bucket: `models/mlx-community_Phi-3-mini-4k-instruct-4bit/`
  - [ ] Add idempotency check: skip if manifest already exists on CDN
  - [ ] Add verification step: download files and validate checksums
- [ ] Test workflow manually via `workflow_dispatch` trigger
- [ ] Verify manifest.json is valid and publicly accessible

### Phase 2: SwiftAcervo Integration
- [ ] Add SwiftAcervo dependency to `Package.swift`
- [ ] Create `Sources/SwiftProyecto/Infrastructure/ModelManager.swift`
  - [ ] Define Phi-3 ComponentDescriptor with all required files
  - [ ] Register descriptor at module initialization
  - [ ] Include checksums from CDN manifest
  - [ ] Set estimatedSizeBytes and minimumMemoryBytes
- [ ] Update `DownloadCommand.run()`:
  - [ ] Replace HuggingFace download logic with `Acervo.ensureComponentReady()`
  - [ ] Implement progress callback for user feedback
  - [ ] Add error handling for model not found / download failed
- [ ] Update `IterativeProjectGenerator.swift`:
  - [ ] Use `Acervo.sharedModelsDirectory` for model paths
  - [ ] No changes to SwiftBruja inference (Bruja.query() stays as-is)

### Phase 3: Testing
- [ ] Integration test: `proyecto download` downloads from CDN successfully
- [ ] Integration test: Progress display works (no crashes)
- [ ] Integration test: `proyecto download --force` re-downloads
- [ ] Integration test: `proyecto init` works with CDN-downloaded model
- [ ] Cross-library test: Verify SwiftBruja can access the model
- [ ] Manual test: Run `proyecto init` on a real screenplay directory

### Phase 4: Documentation
- [ ] Update README.md: Document CDN model management
- [ ] Update AGENTS.md: Document SwiftAcervo integration patterns
- [ ] Update CLAUDE.md: Add build/test instructions if needed
- [ ] Update CHANGELOG.md: Document migration from HuggingFace to CDN
- [ ] Add migration guide for existing users (if applicable)

---

## Decisions Made

1. **✅ Secrets**: Organization-level secrets are already configured
   - `CLOUDFLARE_ACCOUNT_ID`
   - `R2_ACCESS_KEY_ID`
   - `R2_SECRET_ACCESS_KEY`
   - Verified via Vinetas workflow usage

2. **✅ App Group Entitlement**: Not required
   - CLI tools run unsandboxed
   - No entitlements needed
   - SwiftAcervo manages shared directory automatically

3. **✅ Model Naming**: No versioning
   - Use clean HuggingFace model ID format
   - `mlx-community_Phi-3-mini-4k-instruct-4bit` (no -v1 suffix)
   - Avoids confusion for consuming services

4. **✅ SwiftBruja**: Keep for inference
   - No migration to direct MLX
   - Minimal code changes
   - Proven, stable inference stack

## Open Questions

1. **CDN Upload Trigger**: When should the workflow run?
   - Current: `workflow_dispatch` (manual) + push to main when workflow changes
   - Alternative: Only `workflow_dispatch` for explicit control
   - **Recommendation**: Keep current (allows updates via PR to workflow file)

---

**Status**: Ready for review and approval to proceed with implementation.

---
title: "SwiftProyecto — SwiftAcervo v2 Integration Requirements"
date: 2026-04-18
source: "ACERVO_CONSUMER_AUDIT.md"
version: "1.0"
status: "ACTIVE"
priority: "🟡 MEDIUM"
---

# SwiftProyecto — SwiftAcervo v2 Integration Requirements

**Audit Reference**: [ACERVO_CONSUMER_AUDIT.md § 2. SwiftProyecto](../ACERVO_CONSUMER_AUDIT.md#2-swiftproyecto--phi-3-llm-framework) (lines 76–93)  
**Master Index**: [/Users/stovak/Projects/REQUIREMENTS.md](../REQUIREMENTS.md)  
**Sortie**: 5.2 (Create audit-aligned REQUIREMENTS.md)

---

## Executive Summary

**Status**: 🟡 **MEDIUM PRIORITY** — Registration done, access missing

SwiftProyecto has **partial SwiftAcervo integration**:
- ✅ **Component Registration**: ComponentDescriptor defined with full checksums
- ✅ **Registry Integration**: Calls `Acervo.register(phi3ComponentDescriptors)`
- ✅ **Integrity Metadata**: Checksums declared in ComponentFile entries
- ❌ **Abstracted Access**: Public `modelDirectory()` returns URLs; **NO `withComponentAccess()` usage**
- ❌ **Integrity Validation**: Checksums exist but **never verified during access**
- ❌ **Encapsulation**: Model loading logic exposed to callers; file paths leak to CLI and tests

**Gap Impact**: If Acervo changes storage location, caching strategy, or enforces integrity checks, SwiftProyecto will:
1. Bypass new caching mechanisms (still uses direct file paths)
2. Miss integrity verification benefits (checksums never checked)
3. Break if CDN storage structure changes

**Work Scope**: Convert model loading from **path-based v1 access** to **opaque-handle v2 access** with automatic integrity verification.

---

## Audit Findings — SwiftProyecto (lines 76–93)

### Current State

| Aspect | Status | Details | Evidence |
|--------|--------|---------|----------|
| **Component Registration** | ✅ DONE | ComponentDescriptor defined in ModelManager.swift with full checksums | [audit line 82] |
| **Registry Integration** | ✅ DONE | Calls `Acervo.register(phi3ComponentDescriptors)` | [audit line 83] |
| **v1 Path Access** | ❌ ACTIVE | Public `modelDirectory()` method returns URLs to callers | [audit line 84] |
| **`withComponentAccess`** | ❌ MISSING | Never called; path access only | [audit line 85] |
| **Integrity Verification** | ✅ PARTIAL | Checksums declared but never validated during access | [audit line 86] |

### Changes Needed (audit lines 88–92)

1. **Create internal `_loadModel()` method** using `withComponentAccess()`
   - Loads model weights within closure scope only
   - Never constructs or stores URLs outside closure
   - Receives opaque `ComponentHandle` from framework

2. **Remove public `modelDirectory()` method**
   - Eliminates direct file path exposure
   - Callers no longer tempted to bypass Acervo

3. **Update callers** (CLI, tests)
   - Replace `modelDirectory()` usage with high-level API
   - CLI no longer constructs paths; calls internal `_loadModel()`

4. **Verify checksums are validated**
   - Ensure `withComponentAccess` enforces integrity checks
   - Add test to confirm `AcervoError.integrityCheckFailed` on corrupted files

---

## What "Complete Integration" Means

Per [SwiftAcervo REQUIREMENTS.md § A.2](https://github.com/intrusive-memory/SwiftAcervo/blob/main/REQUIREMENTS.md#a2-abstracted-component-access):

> **"SwiftProyecto should only ever address a model from the Acervo context and with abstraction, never with individual file paths."**

### Four Pillars

1. **Component Registration** ✅ (Already done)
   - Define `ComponentDescriptor` with all required files and checksums
   - Register at module init via `Acervo.register()`

2. **Abstracted Access** ❌ (PRIMARY WORK)
   - Use `AcervoManager.shared.withComponentAccess(componentId)` instead of `Acervo.modelDirectory()`
   - Receive a `ComponentHandle` opaque to filesystem paths
   - Load weights within the closure scope only
   - Never construct or store URLs outside the closure

3. **Integrity Verification** ✅ (AUTOMATIC via withComponentAccess)
   - Declare SHA-256 checksums in `ComponentFile` (already done)
   - Acervo verifies on download and before access
   - Throw `AcervoError.integrityCheckFailed` if corrupted

4. **Zero Direct File Access** ❌ (ENFORCEMENT NEEDED)
   - Never call `Acervo.modelDirectory()` to get a URL
   - Never access files via `Acervo.sharedModelsDirectory`
   - All access flows through `ComponentHandle` within `withComponentAccess` closure

---

## Implementation Plan

### Phase 1: Refactor Model Loading (Hours 1–2)

**Objective**: Move model loading logic into ModelManager, away from callers.

**Location**: `Sources/SwiftProyecto/Infrastructure/ModelManager.swift`

**Changes**:
```swift
// BEFORE (current — exposes paths to callers):
public var modelDirectory: URL? {
    let baseURL = Acervo.sharedModelsDirectory
    return baseURL.appendingPathComponent(phi3ComponentId)
}

// AFTER (internal — uses withComponentAccess):
private func _loadModel() async throws -> MLXModel {
    var loadedModel: MLXModel?
    try await AcervoManager.shared.withComponentAccess(phi3ComponentId) { handle in
        let modelPath = handle.resolvedPath.appendingPathComponent("model.safetensors")
        loadedModel = try MLXModel(contentsOf: modelPath)
    }
    guard let model = loadedModel else {
        throw ModelError.loadFailed("Phi-3 model failed to load")
    }
    return model
}
```

**Exit Criteria**:
- [ ] `_loadModel()` method exists and compiles
- [ ] Uses `withComponentAccess()` closure
- [ ] Never constructs URLs outside closure
- [ ] Returns loaded model to caller

### Phase 2: Remove Path Exposure (Hours 2–3)

**Objective**: Delete or deprecate `modelDirectory()` public method.

**Location**: `Sources/SwiftProyecto/Infrastructure/ModelManager.swift`

**Changes**:
```swift
// DELETE or DEPRECATE:
// ❌ public var modelDirectory: URL? { ... }

// REPLACE with high-level API:
public func loadModel() async throws -> MLXModel {
    return try await _loadModel()
}
```

**Exit Criteria**:
- [ ] `public modelDirectory()` method removed
- [ ] No public methods return `URL` to model files
- [ ] All model access goes through `loadModel()` or similar high-level method
- [ ] Compiler shows no public path-returning APIs

### Phase 3: Update Callers (Hours 3–4)

**Objective**: Replace path-based access with high-level API calls.

**Locations**:
- `Sources/proyecto/Commands/DownloadCommand.swift` (if it uses modelDirectory)
- `Sources/proyecto/IterativeProjectGenerator.swift` (model loading)
- Test files referencing `modelDirectory`

**Changes**:
```swift
// BEFORE:
let modelDir = modelManager.modelDirectory
let modelPath = modelDir?.appendingPathComponent("model.safetensors")

// AFTER:
let model = try await modelManager.loadModel()
```

**Exit Criteria**:
- [ ] No calls to `modelDirectory()` in codebase
- [ ] All model loading uses `_loadModel()` or high-level API
- [ ] Tests use high-level API, not paths
- [ ] `grep -r "modelDirectory" Sources/` returns no matches

### Phase 4: Verify Integrity Validation (Hours 4–5)

**Objective**: Confirm checksums are validated on every access.

**Method**:
```swift
// Add integration test:
func testIntegrityVerificationOnAccess() async throws {
    // Corrupt a model file locally
    let corruptedFile = Acervo.sharedModelsDirectory
        .appendingPathComponent(phi3ComponentId)
        .appendingPathComponent("model.safetensors")
    
    // Overwrite with garbage data
    try Data(count: 100).write(to: corruptedFile)
    
    // Attempt to load — should throw AcervoError.integrityCheckFailed
    do {
        _ = try await modelManager.loadModel()
        XCTFail("Expected integrityCheckFailed error")
    } catch AcervoError.integrityCheckFailed {
        // ✅ Expected: integrity check caught corruption
    }
}
```

**Exit Criteria**:
- [ ] Test added to suite
- [ ] Test passes (integrity check works)
- [ ] Corrupted file is rejected with `AcervoError.integrityCheckFailed`

### Phase 5: Integration Testing (Hours 5–6)

**Objective**: Verify complete workflow end-to-end.

**Test Cases**:
1. ✅ `proyecto download` downloads model (existing CDN workflow)
2. ✅ `proyecto init` loads model and generates PROJECT.md
3. ✅ Model access works only via `withComponentAccess`
4. ✅ Integrity verification rejects corrupted files
5. ✅ Model shared with SwiftBruja (cross-library access)

**Exit Criteria**:
- [ ] All 5 test cases pass
- [ ] No regressions in existing functionality
- [ ] CLI output unchanged (progress display, error messages)

---

## Acceptance Criteria

### Functional

- [ ] `_loadModel()` method exists and uses `withComponentAccess()`
- [ ] Public `modelDirectory()` method removed
- [ ] No direct file path access outside Acervo context
- [ ] All calls to `Acervo.modelDirectory()` removed from non-test code
- [ ] Integrity verification works (test confirms)
- [ ] `proyecto download` still works (no breaking changes)
- [ ] `proyecto init` still works (no breaking changes)

### Code Quality

- [ ] No compiler warnings
- [ ] All tests pass (existing + new)
- [ ] No public methods return `URL` to model files
- [ ] No `sharedModelsDirectory` access outside ModelManager
- [ ] Proper error handling (throws on integrity failure)

### Documentation

- [ ] ModelManager docstring updated (references withComponentAccess pattern)
- [ ] AGENTS.md section on Acervo integration updated
- [ ] CHANGELOG.md documents breaking API changes (if any)
- [ ] Comments in code explain why paths are not exposed

---

## Entry Criteria

✅ SATISFIED:
- Sortie 5.1 (audit) complete: ACERVO_CONSUMER_AUDIT.md exists with SwiftProyecto findings
- Pre-existing REQUIREMENTS.md documents CDN setup (separate from this audit work)
- SwiftProyecto repo exists at `/Users/stovak/Projects/SwiftProyecto`
- ComponentDescriptor and Acervo.register() already in place

---

## Exit Criteria

✅ DELIVERABLE: `/Users/stovak/Projects/SwiftProyecto/REQUIREMENTS_ACERVO_INTEGRATION.md` (this file)

**File Contents**:
- [x] Priority: 🟡 MEDIUM (status from audit)
- [x] Audit findings summary (lines 76–93 of ACERVO_CONSUMER_AUDIT.md)
- [x] Four work items matching audit "Changes Needed" (create _loadModel, remove modelDirectory, update callers, verify checksums)
- [x] Clear sorties with entry/exit criteria for each phase
- [x] Links to master REQUIREMENTS.md
- [x] Acceptance criteria (functional + code quality + docs)
- [x] Concise mission-focused format (<200 lines content)

---

## Work Items (Sortie-Ready)

### WI-1: Create internal `_loadModel()` with `withComponentAccess()`

**Entry**: ModelManager.swift exists; ComponentDescriptor registered  
**Exit**: `_loadModel()` method compiles; uses `withComponentAccess()` closure; never constructs URLs outside closure  
**Estimated**: 1 hour

### WI-2: Remove public `modelDirectory()` method

**Entry**: `_loadModel()` complete and tested  
**Exit**: `public modelDirectory()` deleted; no compiler errors; `grep modelDirectory` shows zero results in Sources/  
**Estimated**: 30 minutes

### WI-3: Update callers (CLI, tests, IterativeProjectGenerator)

**Entry**: `_loadModel()` exists; `modelDirectory()` removed  
**Exit**: All files using old API updated; zero calls to `modelDirectory()`; all tests pass  
**Estimated**: 1.5 hours

### WI-4: Verify checksums validated on access

**Entry**: WI-1, WI-2, WI-3 complete  
**Exit**: Integration test added; test passes; corrupted file rejected with AcervoError.integrityCheckFailed  
**Estimated**: 1 hour

### WI-5: Full integration testing

**Entry**: All WI-1 through WI-4 complete  
**Exit**: All 5 test cases pass; no regressions; CLI output unchanged  
**Estimated**: 1.5 hours

---

## Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| `withComponentAccess()` usage | ≥1 (model loading) | ⚪ PENDING |
| Public path-returning methods | 0 | ⚪ PENDING |
| Integrity verification tests | ≥1 | ⚪ PENDING |
| Existing test suite | 100% passing | ⚪ PENDING |
| Code coverage (ModelManager) | ≥90% | ⚪ PENDING |

---

## Dependencies

- **SwiftAcervo** (≥0.7.1): Provides `withComponentAccess()`, `ComponentHandle`, `AcervoError`
- **Existing ComponentDescriptor**: Already registered in ModelManager
- **Phi-3 model on CDN**: Managed by separate CDN workflow (documented in original REQUIREMENTS.md)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Breaking changes to public API | Use high-level `loadModel()` method; deprecate gradually if needed |
| Model loading slowdown | `withComponentAccess()` is no slower than direct file access; same I/O path |
| Cross-library sharing breaks | SwiftBruja also uses Acervo; shared directory is transparent to consumers |
| Existing tests fail | Update tests to use high-level API; no test should access `modelDirectory` directly |

---

## References

- [ACERVO_CONSUMER_AUDIT.md](../ACERVO_CONSUMER_AUDIT.md) — Complete consumer audit
- [REQUIREMENTS.md (master)](../REQUIREMENTS.md) — Mission-wide index
- [SwiftAcervo REQUIREMENTS.md](https://github.com/intrusive-memory/SwiftAcervo) — Framework design spec
- [Original CDN REQUIREMENTS.md](./REQUIREMENTS.md) — CDN model management (separate work)

---

## Status History

| Date | Status | Notes |
|------|--------|-------|
| 2026-04-18 | 🟡 CREATED | Audit-aligned sortie 5.2 deliverable |
| - | - | - |

---

**Prepared by**: Claude Code  
**Mission**: SwiftAcervo Consumer Adoption (Wave 2)  
**Next Action**: Assign to development agent for WI-1 through WI-5 execution

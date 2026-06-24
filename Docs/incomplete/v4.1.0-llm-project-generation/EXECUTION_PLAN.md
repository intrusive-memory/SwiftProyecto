---
type: doc
name: v4.1.0-llm-project-generation
description: LLM-Based PROJECT.md Auto-Generation for SwiftProyecto
status: planning
created: 2026-06-23
state: planning
---

# EXECUTION_PLAN — SwiftProyecto v4.1.0 LLM-Based PROJECT.md Auto-Generation

## Terminology

**Mission** — Complete scope of work implementing v4.1.0 LLM-based PROJECT.md auto-generation, decomposing into work units and sorties.

**Work Unit (WU)** — Coherent deliverable component (e.g., "Claude API Backend"). Each WU contains 1–N sorties producing a verifiable artifact.

**Sortie** — Atomic task assigned to one agent in one dispatch with single objective, crystal-clear entry/exit criteria, and machine-verifiable success.

---

## Mission Scope

Implement `proyecto generate-project <path>` command to automatically generate valid v4.x PROJECT.md files by:
1. Analyzing project directory structure
2. Selecting appropriate LLM backend (SwiftBruja, Foundation Models, or Claude API)
3. Extracting cast lists from scripts and file names
4. Inferring project metadata, TTS providers, and episode patterns
5. Generating schema-valid output with minimal user input
6. Validating and safely writing output (no silent overwrites)

**Acceptance Criteria**:
- ✅ `proyecto generate-project <path>` produces valid v4.x PROJECT.md
- ✅ All three backends generate valid output
- ✅ **CRITICAL**: Multi-backend comparison test on lingua-matra passes
- ✅ CLI supports `--dry-run`, `--interactive`, `--force`, `--llm`, `--model` flags
- ✅ Documentation complete (user + developer guides)

---

## Work Units Summary

| WU | Title | Sorties | Dependencies |
|----|-------|---------|-------------|
| WU1 | Backend Abstraction & OS Detection | 2 | None |
| WU2 | Claude API Backend | 1 | WU1 |
| WU3 | Foundation Models Backend | 1 | WU1 |
| WU4 | SwiftBruja Backend (Optional) | 1 | WU1 |
| WU5 | Directory Analysis & Preprocessing | 1 | WU1 |
| WU6 | CLI Integration | 1 | WU1, WU2, WU5 |
| WU7 | Testing & Multi-Backend Validation | 3 | WU1-6 |
| WU8 | Documentation | 2 | WU6, WU7 |

**Total**: 12 sorties (or 13-14 with optional WU4)

---

## Work Unit 1: Backend Abstraction & OS Detection

**Sortie 1.1** (Opus): LLMBackendProtocol + BackendRegistry, OS detection framework

**Sortie 1.2** (Haiku): ProjectGeneratorService with fallback chain (Bruja→FM→Claude)

**Exit Criteria**:
- [ ] Protocol + service compile without errors
- [ ] OS version detection working (macOS 26, 27+)
- [ ] All tests pass

---

## Work Unit 2: Claude API Backend

**Sortie 2.1** (Opus): ClaudeAPIBackend with URLSession, few-shot prompts, JSON parsing, error handling

**Exit Criteria**:
- [ ] Backend implements protocol
- [ ] Parsing robust against format variations
- [ ] Token usage <5000 per project
- [ ] All tests pass

---

## Work Unit 3: Foundation Models Backend

**Sortie 3.1** (Opus): AppleFoundationModelsBackend for macOS 27+, graceful fallback

**Exit Criteria**:
- [ ] Available on macOS 27+, graceful unavailable on 26
- [ ] Fallback to Claude documented
- [ ] All tests pass

---

## Work Unit 4: SwiftBruja Backend (Optional)

**Sortie 4.1** (Haiku): SwiftBrujaBackend with soft dependency, query/response formats

**Exit Criteria**:
- [ ] Gracefully reports unavailable if package missing
- [ ] Fallback chain works
- [ ] All tests pass

---

## Work Unit 5: Directory Analysis & Preprocessing

**Sortie 5.1** (Opus): CastExtractor (Fountain, file patterns), MetadataExtractor, ProjectService.scanAndRecognize()

**Exit Criteria**:
- [ ] Cast extraction >80% accurate on real scripts
- [ ] Metadata inference produces reasonable output
- [ ] All tests pass

---

## Work Unit 6: CLI Integration

**Sortie 6.1** (Opus): `proyecto generate-project` command with all flags, backend selection, file safety, validation

**Exit Criteria**:
- [ ] All flags work (--dry-run, --interactive, --force, --llm, --model)
- [ ] File safety: backups, no overwrites without --force
- [ ] All tests pass

---

## Work Unit 7: Testing & Multi-Backend Validation

**Sortie 7.1** (Opus): Unit & integration tests for all backends, OS detection, flag combinations, coverage >80%

**Sortie 7.2** (Opus): **CRITICAL** Multi-backend comparison test on lingua-matra
- Run all 3 backends on lingua-matra project
- Validate all generate valid v4.x PROJECT.md
- ≥2 backends detect all languages
- ≥2 backends detect seasons correctly
- Generate comparison report with quality scores

**Sortie 7.3** (Haiku): CLI integration tests (all flag combos, error handling, file safety, user workflows)

**Exit Criteria**:
- [ ] All tests pass
- [ ] **CRITICAL**: lingua-matra test passes (all backends valid)
- [ ] Coverage >80%
- [ ] Comparison report documents findings

---

## Work Unit 8: Documentation

**Sortie 8.1** (Haiku): LLM_GENERATION_GUIDE.md (user guide with examples, troubleshooting, FAQ), AGENTS.md update, CLI help text

**Sortie 8.2** (Haiku): PROJECT_GENERATION_ARCHITECTURE.md (developer guide), BACKEND_EXTENSION_GUIDE.md, prompt engineering docs, API docs, testing guide

**Exit Criteria**:
- [ ] User guide clear and helpful
- [ ] Developer docs complete
- [ ] AGENTS.md updated with v4.1.0
- [ ] All links verified

---

## Execution Path

**Phase 1** (2-3h): Sorties 1.1, 1.2
**Phase 2** (4-6h, parallel): Sorties 2.1, 5.1, 3.1, 4.1 (optional)
**Phase 3** (4-5h): Sorties 6.1, 7.1, **7.2 (CRITICAL)**, 7.3
**Phase 4** (2-3h): Sorties 8.1, 8.2

**Total Wall-Clock**: ~12-17 hours (with parallelization)

---

## Success Criteria

**Mission COMPLETE** when:
1. ✅ `proyecto generate-project <path>` works end-to-end
2. ✅ All three backends generate valid v4.x PROJECT.md
3. ✅ **CRITICAL**: lingua-matra multi-backend test passes
4. ✅ All flags work correctly
5. ✅ File safety guaranteed
6. ✅ All tests pass (>80% coverage)
7. ✅ Documentation complete

---

## Open Questions (for Refinement Pass 1)

- **OQ-1**: API integration method (FoundationModels + URLSession)?
  - **Recommended**: FoundationModels if available; URLSession fallback
- **OQ-2**: Prompt strategy (few-shot + JSON output)?
  - **Recommended**: Few-shot examples, JSON→YAML conversion
- **OQ-4**: Script parsing formats (Fountain only for v4.1)?
  - **Recommended**: Fountain v4.1; defer Highland/FDX to v4.2
- **OQ-5**: Review workflow (--dry-run default)?
  - **Recommended**: --dry-run default, --interactive for review, --auto-write for trusted
- **OQ-6**: Backend selection priority (Bruja→FM→Claude)?
  - **Recommended**: SwiftBruja (if installed) → FM (macOS 27+) → Claude
- **OQ-7**: SwiftBruja query format?
  - **Deferred to Sortie 4.1**
- **OQ-8**: Error recovery (fallback if API fails)?
  - **Recommended**: Return directory structure only; user retries or edits manually

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Claude API rate-limited | High | Fallback to FM; retry with backoff |
| FM insufficient on macOS 26 | Medium | Default Claude on 26; FM optional 27+ |
| SwiftBruja unavailable | Low | Soft dependency; graceful fallback |
| Directory ambiguous | Medium | Error + guidance; --interactive review |
| Metadata incomplete | Medium | Validation catches schema errors |
| Performance >60s | Medium | Profile LLM calls; optimize prompts |

---

**Plan Status**: Ready for refinement (Pass 1: Blockers)

**Next**: `/mission-supervisor refine Docs/incomplete/v4.1.0-llm-project-generation/EXECUTION_PLAN.md`

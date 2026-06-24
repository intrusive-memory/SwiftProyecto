---
type: execution-plan
name: v4.1.0-llm-project-generation
description: LLM-Based PROJECT.md Auto-Generation for SwiftProyecto
status: completed
created: 2026-06-23
state: completed
last_refined: 2026-06-23
completed: 2026-06-24
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

### Sortie 1.1 (Opus): LLMBackendProtocol + BackendRegistry, OS detection framework

**Priority**: 39.5 — Foundation protocol reused by all 11 downstream sorties; establishes core architecture

**Agent Assignment**: Supervising agent only (builds included)

**Entry criteria**:
- Clean working tree on development branch
- Existing SwiftProyecto package structure reviewed

**Exit Criteria**:
- [ ] `LLMBackendProtocol` compiles without errors
- [ ] `BackendRegistry` singleton implemented and tested
- [ ] OS version detection function works for macOS 26, 27+ (`macOSVersion() → (major: Int, minor: Int)`)
- [ ] Unit tests pass: `swift test --filter BackendAbstraction`
- [ ] All tests pass; coverage ≥80%

### Sortie 1.2 (Haiku): ProjectGeneratorService with fallback chain (Bruja→FM→Claude)

**Priority**: 36.5 — Core service architecture reused by CLI and tests; establishes fallback pattern

**Agent Assignment**: Supervising agent only (builds included)

**Entry criteria**:
- Sortie 1.1 complete: `LLMBackendProtocol` and `BackendRegistry` available
- Fallback chain order confirmed: SwiftBruja → FM → Claude

**Exit Criteria**:
- [ ] `ProjectGeneratorService` compiles without errors
- [ ] Fallback chain initialization works: SwiftBruja unavailable → FM unavailable → Claude fallback
- [ ] Service responds to `generate()` calls on all three backends
- [ ] Unit tests pass: `swift test --filter ProjectGeneratorService`
- [ ] All tests pass

---

## Work Unit 2: Claude API Backend

### Sortie 2.1 (Opus): ClaudeAPIBackend with URLSession, few-shot prompts, JSON parsing, error handling

**Priority**: 16 — External API dependency; enables main Claude fallback path

**Agent Assignment**: Parallel sub-agent (Phase 2, 4-way parallel), no supervising responsibility

**Entry criteria**:
- Sortie 1.1–1.2 complete: Protocol and service foundation available
- Claude API key available in environment (test/mock for tests)

**Exit Criteria**:
- [ ] `ClaudeAPIBackend` compiles and registers with `BackendRegistry`
- [ ] Few-shot prompts generate valid JSON output (robustness tested on 10+ edge cases)
- [ ] JSON parsing handles: nested structures, missing optional fields, extra fields
- [ ] Token usage ≤5000 per project (verified with instrument/logging)
- [ ] Unit tests pass: `swift test --filter ClaudeAPIBackend`
- [ ] All tests pass; coverage ≥80%

---

## Work Unit 3: Foundation Models Backend

### Sortie 3.1 (Opus): AppleFoundationModelsBackend for macOS 27+, graceful fallback

**Priority**: 16 — External API dependency; platform-specific, macOS 27+ only

**Agent Assignment**: Parallel sub-agent (Phase 2, 4-way parallel), no supervising responsibility

**Entry criteria**:
- Sortie 1.1–1.2 complete: Protocol and service foundation available
- OS detection from Sortie 1.1 available

**Exit Criteria**:
- [ ] `AppleFoundationModelsBackend` compiles without errors
- [ ] Available on macOS 27+: `#available(macOS 27, *)` guards in place
- [ ] Graceful fallback on macOS 26: Backend unavailable error handled, chain continues to next
- [ ] Unit tests pass: `swift test --filter AppleFoundationModelsBackend` (skipped on macOS 26)
- [ ] Integration test confirms fallback: macOS 26 → skips FM, uses Claude
- [ ] All tests pass

---

## Work Unit 4: SwiftBruja Backend (Optional)

### Sortie 4.1 (Haiku): SwiftBrujaBackend with soft dependency, query/response formats

**Priority**: 15 — Optional backend; establishes soft dependency pattern; determines SwiftBruja query format (OQ-7)

**Agent Assignment**: Parallel sub-agent (Phase 2, 4-way parallel), no supervising responsibility

**Entry criteria**:
- Sortie 1.1–1.2 complete: Protocol and service foundation available
- Soft dependency mechanism (package check) understood

**Exit Criteria**:
- [ ] `SwiftBrujaBackend` compiles without errors
- [ ] If SwiftBruja package unavailable: Backend reports `.unavailable` error; fallback chain continues
- [ ] If SwiftBruja available: Query format documented and tested (OQ-7 resolved here)
- [ ] Unit tests pass: `swift test --filter SwiftBrujaBackend`
- [ ] Integration: Fallback chain skips unavailable backend correctly
- [ ] All tests pass

---

## Work Unit 5: Directory Analysis & Preprocessing

### Sortie 5.1 (Opus): CastExtractor (Fountain, file patterns), MetadataExtractor, ProjectService.scanAndRecognize()

**Priority**: 14 — Reused by CLI and test infrastructure; preprocesses input for all backends

**Agent Assignment**: Parallel sub-agent (Phase 2, 4-way parallel), no supervising responsibility

**Entry criteria**:
- Sortie 1.1–1.2 complete: Service foundation available
- Reference cast data from 2+ real Fountain scripts available for testing

**Exit Criteria**:
- [ ] `CastExtractor` (Fountain parsing) compiles without errors
- [ ] Cast extraction ≥80% accurate on reference scripts (test dataset: lingua-matra, Produciesta)
- [ ] `MetadataExtractor` infers: project title, episode patterns, TTS providers
- [ ] Metadata inference produces output matching patterns from ≥1 reference project + passes schema validation
- [ ] `ProjectService.scanAndRecognize()` implemented and callable
- [ ] Unit tests pass: `swift test --filter DirectoryAnalysis`
- [ ] All tests pass; coverage ≥80%

---

## Work Unit 6: CLI Integration

### Sortie 6.1 (Opus): `proyecto generate-project` command with all flags, backend selection, file safety, validation

**Priority**: 9 — Integrates all previous work; entry point for end users

**Agent Assignment**: Supervising agent only (builds included), depends on 2.1 + 5.1 completion

**Entry criteria**:
- Sortie 2.1 + 5.1 complete: Claude backend and directory analysis available
- All Phase 2 sorties complete (2.1, 3.1, 4.1, 5.1)
- Flag design finalized (OQ-5 decision: --dry-run default, --interactive, --force, --llm, --model)

**Exit Criteria**:
- [ ] `proyecto generate-project <path>` command compiles without errors
- [ ] Flag `--dry-run` works (outputs to stdout, no write)
- [ ] Flag `--interactive` works (presents review prompt, user confirms/edits)
- [ ] Flag `--force` works (overwrites existing PROJECT.md without prompt)
- [ ] Flag `--llm` works (selects backend: claude, fm, bruja)
- [ ] Flag `--model` works (selects Claude model version)
- [ ] File safety: automatic `.bak` backup created before write
- [ ] Validation: generated PROJECT.md passes schema validation before write
- [ ] Integration tests pass: `swift test --filter CLIGenerate`
- [ ] All tests pass

---

## Work Unit 7: Testing & Multi-Backend Validation

### Sortie 7.1 (Opus): Unit & integration tests for all backends, OS detection, flag combinations

**Priority**: 3 — Validation work; depends on all implementation sorties; coverage infrastructure

**Agent Assignment**: Supervising agent only (builds included)

**Entry criteria**:
- Sortie 1.1–6.1 complete: All backends, CLI, service implementation available
- Test reference data prepared (cast lists, metadata samples, lingua-matra project)

**Exit Criteria**:
- [ ] Unit test suite compiles: `swift test --filter ".*" --help` produces all sorties' test names
- [ ] Backend unit tests pass: `swift test --filter "(ClaudeAPI|AppleFoundationModels|SwiftBruja|ProjectGenerator)"`
- [ ] OS detection tests pass: macOS 26 vs 27+ behavior verified
- [ ] Flag combination tests pass: all flag permutations (--dry-run, --interactive, --force, --llm, --model)
- [ ] Coverage report shows ≥80% coverage (xcodebuild with codecov flags)
- [ ] All tests pass; no skipped tests (except platform-specific on macOS 26)

### Sortie 7.2 (Opus): **CRITICAL** Multi-backend comparison test on lingua-matra project

**Priority**: 3 — CRITICAL validation gate; acceptance criterion for entire mission

**Agent Assignment**: Supervising agent only (builds included), depends on 6.1 completion

**Entry criteria**:
- Sortie 6.1 complete: CLI integration available
- lingua-matra project (real, multi-language, multi-season) accessible locally

**Exit Criteria**:
- [ ] **CRITICAL: All 3 backends generate valid v4.x PROJECT.md** (schema validation passes for each)
- [ ] Language detection: ≥2 backends detect all languages in lingua-matra
- [ ] Season detection: ≥2 backends detect season structure correctly
- [ ] Quality comparison report generated with scores: accuracy (cast), completeness (metadata), validation (schema)
- [ ] Report documents: which backend performed best per dimension, any failures, recommendations
- [ ] Test result: lingua-matra test passes (exit code 0)

### Sortie 7.3 (Haiku): CLI integration tests (all flag combos, error handling, user workflows)

**Priority**: 2 — Integration validation; E2E user scenarios

**Agent Assignment**: Supervising agent only (builds included), depends on 6.1 completion

**Entry criteria**:
- Sortie 6.1 complete: CLI command available
- Test project directories (small, real-world-like) prepared

**Exit Criteria**:
- [ ] CLI tests compile without errors
- [ ] All flag combinations produce expected behavior
- [ ] Error handling: invalid path, no PROJECT.md permission, invalid flags → helpful errors
- [ ] File safety test: existing PROJECT.md not overwritten without --force
- [ ] Integration tests pass: `swift test --filter CLIIntegration`
- [ ] All tests pass

---

## Work Unit 8: Documentation

### Sortie 8.1 (Haiku): LLM_GENERATION_GUIDE.md (user guide with examples, troubleshooting, FAQ), AGENTS.md update, CLI help text

**Priority**: 2 — User-facing documentation; depends on all implementation work

**Agent Assignment**: Sub-agent (Phase 4, no builds after 7.3 complete)

**Entry criteria**:
- Sortie 7.1–7.3 complete: All features tested and working
- CLI finalized and stable

**Exit Criteria**:
- [ ] `LLM_GENERATION_GUIDE.md` written (user guide format: overview, quick start, examples, troubleshooting, FAQ)
- [ ] All flags documented with examples: --dry-run, --interactive, --force, --llm, --model
- [ ] Backend selection logic documented (fallback chain: Bruja → FM → Claude)
- [ ] `AGENTS.md` updated with v4.1.0 milestone and `proyecto generate-project` command
- [ ] CLI help text (`proyecto generate-project --help`) comprehensive and clear
- [ ] All internal links verified (no broken markdown links)

### Sortie 8.2 (Haiku): Developer documentation (architecture, backend extension guide, prompt docs, API docs, testing guide)

**Priority**: 2 — Developer-facing documentation; enables future backend extensions

**Agent Assignment**: Sub-agent (Phase 4, no builds)

**Entry criteria**:
- Sortie 7.1–7.3 complete: Implementation stable
- Architecture decisions finalized

**Exit Criteria**:
- [ ] `PROJECT_GENERATION_ARCHITECTURE.md` written (architecture overview, module responsibilities, data flow)
- [ ] `BACKEND_EXTENSION_GUIDE.md` written (how to add new backend, protocol requirements, error handling)
- [ ] Prompt engineering documentation: few-shot examples, JSON output specification, error recovery
- [ ] API documentation: `LLMBackendProtocol`, `ProjectGeneratorService`, `CastExtractor`, `MetadataExtractor`
- [ ] Testing guide: how to add tests for new backends, mock data, coverage expectations
- [ ] All internal links verified

---

## Parallelism Structure

### Critical Path
Sortie 1.1 → Sortie 1.2 → Sortie 6.1 → Sorties 7.1/7.2/7.3 (length: 6 sequential decision points)

### Parallel Execution Groups

**Phase 1 — Foundation (Sequential)**
- Sortie 1.1: Supervising agent — LLMBackendProtocol, BackendRegistry, OS detection
- Sortie 1.2: Supervising agent — ProjectGeneratorService, fallback chain

**Phase 2 — Backends (4-Way Parallel)**
- Sortie 2.1: Sub-agent A — Claude API Backend (no supervising responsibility, builds included)
- Sortie 3.1: Sub-agent B — Foundation Models Backend (no supervising responsibility, builds included)
- Sortie 4.1: Sub-agent C — SwiftBruja Backend (no supervising responsibility, builds included)
- Sortie 5.1: Sub-agent D — Directory Analysis & Preprocessing (no supervising responsibility, builds included)
- **Constraint**: All sub-agents run in parallel after Phase 1 complete; supervising agent awaits all 4

**Phase 3 — Integration (Sequential)**
- Sortie 6.1: Supervising agent — CLI Integration (depends on 2.1, 5.1; has builds)
- Sortie 7.1: Supervising agent — Unit & Integration Tests (depends on 1.1–6.1; has builds)
- Sortie 7.2: Supervising agent — **CRITICAL** Multi-Backend Comparison on lingua-matra (depends on 6.1; has builds)
- Sortie 7.3: Supervising agent — CLI Integration Tests (depends on 6.1; has builds)

**Phase 4 — Documentation (Sequential)**
- Sortie 8.1: Sub-agent — User Guide & AGENTS.md (no builds after Phase 3 complete)
- Sortie 8.2: Sub-agent — Developer Documentation (no builds)

### Agent Allocation
- **Supervising Agent**: Handles all sorties in Phases 1, 3 (6 sorties: 1.1, 1.2, 6.1, 7.1, 7.2, 7.3)
- **Sub-agents (up to 4)**: Phase 2 (4-way parallel: 2.1, 3.1, 4.1, 5.1), then Phase 4 (2 sequential: 8.1, 8.2)
- **Build responsibility**: Only supervising agent performs builds; sub-agents create files, documentation, but no compilation

---

## Execution Path

**Phase 1** (2-3h): Sorties 1.1, 1.2 (sequential, supervising agent)
**Phase 2** (4-6h, parallel): Sorties 2.1, 3.1, 4.1, 5.1 (4-way parallel, 4 sub-agents)
**Phase 3** (4-5h): Sorties 6.1, 7.1, **7.2 (CRITICAL)**, 7.3 (sequential, supervising agent)
**Phase 4** (2-3h): Sorties 8.1, 8.2 (sequential, 2 sub-agents, no builds)

**Total Wall-Clock**: ~12-17 hours (with parallelization)
**Critical Path**: Phase 1 + Phase 3 bottleneck (supervising agent serializes all builds)

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

## Open Questions — Refinement Pass 1 Review

**Status**: ✅ **All reviewed; no blockers found.** All open questions have actionable recommendations.

| # | Question | Recommendation | Resolved |
|---|----------|---|---|
| OQ-1 | API integration method (FoundationModels + URLSession)? | FoundationModels if available; URLSession fallback | ✅ Embedded in Sortie 3.1 entry/exit criteria |
| OQ-2 | Prompt strategy (few-shot + JSON output)? | Few-shot examples, JSON→YAML conversion | ✅ Embedded in Sortie 2.1 exit criteria |
| OQ-4 | Script parsing formats (Fountain only for v4.1)? | Fountain v4.1; defer Highland/FDX to v4.2 | ✅ Embedded in Sortie 5.1 scope |
| OQ-5 | Review workflow (--dry-run default)? | --dry-run default, --interactive for review, --force for trusted | ✅ Embedded in Sortie 6.1 flag specifications |
| OQ-6 | Backend selection priority (Bruja→FM→Claude)? | SwiftBruja (if installed) → FM (macOS 27+) → Claude | ✅ Embedded in Sortie 1.2 fallback chain |
| OQ-7 | SwiftBruja query format? | Deferred to Sortie 4.1 (agent determines during implementation) | ✅ Appropriate deferral to Sortie 4.1 |
| OQ-8 | Error recovery (fallback if API fails)? | Return directory structure only; user retries or edits manually | ✅ Embedded in Sortie 2.1, 3.1 error handling specs |

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

---

## Refinement Complete — Plan Ready for Execution

**Plan Status**: ✅ **REFINED AND READY**

**Refinement Results**:
- ✅ Pass 1 (Blocking Open Questions): 0 blockers; all OQ-1 through OQ-8 have clear recommendations
- ✅ Pass 2 (Atomicity & Testability): All 12 sorties fit within context budget; no splits/merges needed
- ✅ Pass 3 (Prioritization): Execution order verified optimal; priority scores: 1.1 (39.5) → 1.2 (36.5) → phases 2–4
- ✅ Pass 4 (Parallelism): 1 supervising agent + 4 sub-agents Phase 2; critical path optimized
- ✅ Pass 5 (Vague Criteria): 1 criterion clarified (Sortie 5.1 "reasonable output" → "matches reference patterns + schema valid"); no blocking issues

**Execution Summary**:
- **Total Sorties**: 12 (11 required + 1 optional WU4)
- **Average Sortie Size**: 20 turns (context budget: 50 turns; all green)
- **Critical Path Length**: 6 decision points (1.1 → 1.2 → 6.1 → 7.1/7.2/7.3)
- **Parallelism**: Phase 2 (4-way parallel); Phases 1, 3, 4 sequential
- **Wall-Clock Estimate**: 12–17 hours (assuming ~1 hour/sortie, 40% parallelism efficiency)
- **CRITICAL Gate**: Sortie 7.2 (multi-backend comparison on lingua-matra) — must pass for mission complete

**Next Step**: `/mission-supervisor start Docs/incomplete/v4.1.0-llm-project-generation/EXECUTION_PLAN.md`

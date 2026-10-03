---
type: supervisor-state
mission_title: SwiftProyecto ProjectBrowser Enhancements
mission_slug: projectbrowser-personaje
operation_name: Operation Persona
starting_point_commit: ad8bf9e4e699cb3509a25d20091421f70f54b36c
mission_branch: mission/persona/01
state: RUNNING
created: 2026-10-03
updated: 2026-10-03
---

# Mission Supervisor State

## Configuration

- **max_retries**: 3 attempts per sortie
- **max_verifier_rounds**: 2 per sortie
- **watchdog_interval_minutes**: 20
- **watchdog_max_strikes**: 3

## Work Unit: ProjectBrowser Enhancements

| Sortie | Requirement | State | Attempts | Dispatch Time | Notes |
|--------|-------------|-------|----------|---------------|-------|
| 1 | PY-P1 (foundation) | ✅ COMPLETED | 1 | 2026-10-03 | Expected files parameter |
| 2 | PY-P1 (UI) | READY → DISPATCHING | 0 | 2026-10-03 | Waits for Sortie 1 (now ready) |
| 3 | PY-P2 | ✅ COMPLETED | 1 | 2026-10-03 | Per-file handler lookup |
| 4 | PY-P3 (foundational) | ✅ COMPLETED | 1 | 2026-10-03 | `style:` block |
| 5 | PY-P4 | READY → DISPATCHING | 0 | 2026-10-03 | Waits for Sortie 4 (now ready) |
| 6 | PY-P5 (optional) | DEFERRED | 0 | — | Deferred to v5.2.0 |

## Sortie Details

### Sortie 1: Add Expected Files Foundation
- **Status**: ✅ COMPLETED
- **Dependency**: None
- **Exit Criteria**: ✓ All satisfied
- **Commit**: 783b0df
- **Notes**: mergeExpectedFiles() implemented; 157/157 tests passing; ready for Sortie 2
- **Layer**: 1 (parallel eligible)

### Sortie 2: Missing File Visual State
- **Status**: PENDING
- **Dependency**: Sortie 1
- **Entry Criteria Met**: Awaiting Sortie 1 completion
- **Exit Criteria**: Missing files render distinctly; callback fires
- **Layer**: 2 (waits for Layer 1)

### Sortie 3: Per-File Handler Disambiguation
- **Status**: ✅ COMPLETED
- **Dependency**: None
- **Exit Criteria**: ✓ All satisfied
- **Changes**: Updated ProjectDetailPane handler lookup to check filename first, then extension
- **Tests**: 10/10 passing (name-based routing, extension fallback, backward compatibility)
- **Layer**: 1 (parallel eligible)

### Sortie 4: Add `style:` Block
- **Status**: ✅ COMPLETED
- **Dependency**: None
- **Exit Criteria**: ✓ All satisfied
- **Changes**: Style struct added; YAML parsing/writing; round-trip compatibility verified
- **Tests**: 11 new tests passing; 157/157 existing tests passing
- **Layer**: 1 (parallel eligible); foundation for Sortie 5

### Sortie 5: NSFileCoordinator Wrapper
- **Status**: PENDING
- **Dependency**: Sortie 4
- **Entry Criteria Met**: Awaiting Sortie 4 completion
- **Exit Criteria**: Coordinated writes serialize; no data loss
- **Layer**: 2 (waits for Layer 1)

### Sortie 6: Move Recents Infrastructure
- **Status**: DEFERRED
- **Target Release**: v5.2.0
- **Notes**: Deferred per OQ-3 resolution

## Decisions Log

### THE RITUAL (Pending)
- Operation name: PENDING (to be generated)
- Mission branch: PENDING (to be created)

### Open Questions Resolution
- **OQ-1**: Release Sequencing → Option B (ship v5.1.0 with Sorties 1–5)
- **OQ-2**: Palette and Wardrobe → No enum validation; consume strings
- **OQ-3**: Include Sortie 6 → Deferred to v5.2.0

## Execution State

- **Current Layer**: 2 (ready for dispatch)
- **Next Action**: Dispatch Layer 2 sorties (2, 5)
- **Active Sorties**: None (Layer 1 complete, Layer 2 ready)
- **Completed Sorties**: 1 (expectedFiles), 3 (handlers), 4 (style)

---

## Dispatch Timeline

1. ✅ Execute THE RITUAL: Operation Persona (2026-10-03 11:45 UTC)
2. ✅ Create mission branch: mission/persona/01
3. ✅ Dispatch Layer 1 sorties: 1, 3, 4 (parallel, 2026-10-03 11:48 UTC)
4. → Monitor and await Layer 1 completion (ETA ~0.75 dev-days, ~4 hours wall-clock)
5. Dispatch Layer 2 sorties: 2, 5 (serial sequence)
6. Conclude with Layer 2 completion and mission brief

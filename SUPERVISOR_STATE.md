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
| 1 | PY-P1 (foundation) | PENDING | 0 | — | Expected files parameter |
| 2 | PY-P1 (UI) | PENDING | 0 | — | Missing file visual state |
| 3 | PY-P2 | PENDING | 0 | — | Per-file handler lookup |
| 4 | PY-P3 (foundational) | PENDING | 0 | — | `style:` block |
| 5 | PY-P4 | PENDING | 0 | — | NSFileCoordinator wrapper |
| 6 | PY-P5 (optional) | DEFERRED | 0 | — | Deferred to v5.2.0 |

## Sortie Details

### Sortie 1: Add Expected Files Foundation
- **Status**: PENDING
- **Dependency**: None
- **Entry Criteria Met**: Awaiting ritual + branch creation
- **Exit Criteria**: ProjectWindow accepts expectedFiles; discovery merge works
- **Layer**: 1 (parallel eligible)

### Sortie 2: Missing File Visual State
- **Status**: PENDING
- **Dependency**: Sortie 1
- **Entry Criteria Met**: Awaiting Sortie 1 completion
- **Exit Criteria**: Missing files render distinctly; callback fires
- **Layer**: 2 (waits for Layer 1)

### Sortie 3: Per-File Handler Disambiguation
- **Status**: PENDING
- **Dependency**: None
- **Entry Criteria Met**: Awaiting ritual + branch creation
- **Exit Criteria**: Filename lookup takes precedence
- **Layer**: 1 (parallel eligible)

### Sortie 4: Add `style:` Block
- **Status**: PENDING
- **Dependency**: None
- **Entry Criteria Met**: Awaiting ritual + branch creation
- **Exit Criteria**: YAML round-trip works; no mutation without `style:`
- **Layer**: 1 (parallel eligible)

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

- **Current Layer**: 1 (ready for dispatch)
- **Next Action**: Dispatch Layer 1 sorties (1, 3, 4)
- **Active Sorties**: None (awaiting dispatch)
- **Completed Sorties**: None

---

## Next Steps

1. ✅ Execute THE RITUAL: Operation Persona
2. ✅ Create mission branch: mission/persona/01
3. → Dispatch Layer 1 sorties: 1, 3, 4 (parallel)
4. Monitor and advance to Layer 2 when Layer 1 complete

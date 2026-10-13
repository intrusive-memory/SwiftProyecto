---
type: requirements
state: draft
updated: 2026-10-03
origin: intrusive-memory/Personaje @ 74721c3 (docs/REQUIREMENTS-APP-UI.md §2, §3.2, §11.6; RECON_REPORT.md)
sequence: 1 (PY-P1, PY-P2), 3 (PY-P3, PY-P4) — PY-P1/P2 are needed before Personaje's app shell
---

# SwiftProyecto — what Personaje needs

Personaje's project window **is** `ProjectBrowser.ProjectWindow`, the same view
Escribir uses. Three changes belong here rather than in a Personaje fork, and a
fourth is optional.

## Requirements

| ID | Requirement | Needed for | Source |
|----|-------------|-----------|--------|
| PY-P1 | **Expected files.** `ProjectWindow` takes a list of paths that appear in the tree whether or not they exist. A missing one is shown in a missing state (grey, "missing") and has a selection callback. `ProjectFileDiscovery` keeps listing only existing files; the expected entries are merged in after discovery. | Showing a missing CAST.md and building it on selection | APP-UI §3, §3.2 item 1 |
| PY-P2 | **Per-file handlers.** `handlers:` can be keyed by file name as well as extension. A name match wins over an extension match. Today the lookup is `handlers[file.fileExtension ?? ""]`, so PROJECT.md and CAST.md collide on `md`. | PROJECT.md and CAST.md having different detail views | APP-UI §3.2 item 2 |
| PY-P3 | **Shared `style:` block** at the top level of PROJECT.md front matter: art style, palette, wardrobe, each one choice from a short list. Personaje reads and writes the art style only; Vinetas reads all three. Palette and wardrobe option lists are **not specified yet** (Vinetas Q2). | One art style for characters and scenes | APP-UI UD16, §3.1, §11.6; Vinetas DOSSIER-INTEGRATION §5, Q1 |
| PY-P4 | **Coordinated writes.** Two apps write PROJECT.md (Personaje its `personaje:` section and `style.artStyle`, Vinetas its projects and sequences). Writes go through `NSFileCoordinator` and preserve sections the writer doesn't own. | Neither app overwriting the other | Vinetas DOSSIER-INTEGRATION §6 |
| PY-P5 | *(optional)* **Recents in `ProjectBrowser`.** Move Escribir's `RecentProjectEntry`, `RecentProjectList`, `RecentProjectsStore`, `RecentProjects`, `ProjectFolderBookmarkStore`, `ProjectFolderBookmark` (today app-private in `Escribir/Shared/RecentProjectFolders.swift` and `ProjectFolderBookmark.swift`) into the package. If this isn't done, Personaje copies the two files. | Launch window recents | APP-UI §2; RECON A-11 |

## Constraints

- **Escribir must not change behavior.** It relies on the two-column
  `NavigationSplitView` (`ProjectWindow.swift:286-298`) and is pinned to 5.0.0.
  PY-P1 and PY-P2 are additive: default arguments, no change when unused.
- **No third split-view column.** Personaje's dossier panel is an `.inspector`
  inside its own CAST.md detail view.
- `ProjectBrowser` keeps `dependencies: []`.

## Facts already verified at v5.0.0 (Personaje recon)

- `AppFrontMatterSettings` with `settings(for:)`, `setSettings(_:)`,
  `hasSettings(for:)` — Personaje's `personaje:` section works today.
- `ProjectWindow` takes `fileFilter: ((ProjectFile) -> Bool)?`, applied after
  discovery (`ProjectWindow.swift:198,595`).
- `episodesDir` and `filePattern` are on `ProjectFrontMatter` (`:103,109`).
- No `style`, `palette` or `wardrobe` field exists.
- The Import button is a no-op stub (`ProjectWindow.swift:353`).

## Acceptance

1. A `ProjectWindow` given `expectedFiles: ["CAST.md"]` on a folder without
   one shows the row as missing, and selecting it fires the callback.
2. Handlers for `PROJECT.md` and `CAST.md` by name each receive only their file;
   an `md` extension handler still receives every other `.md`.
3. A PROJECT.md with `style:` round-trips; one without it is unchanged on write.
4. Escribir builds against the release with no source change.

## Depends on

Nothing in this effort. (SwiftProyecto links SwiftCompartido, but none of this
uses the new neighbour query.)

## Blocks

- **Personaje app shell** (hard): PY-P1, PY-P2.
- **Vinetas scene style** (hard): PY-P3.
- **Personaje art style** (soft): reads `personaje.artStyle` until PY-P3 ships.

## Open

Is PY-P3 one release with PY-P1/P2, or a later one? PY-P1/P2 are fully
specified; PY-P3 waits on the palette and wardrobe lists. Recommended: ship
PY-P1/P2 first as a minor, PY-P3 and PY-P4 together after.

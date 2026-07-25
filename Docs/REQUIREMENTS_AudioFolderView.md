---
type: specification
---

# Audio Folder View — Requirements & Open Questions

**Status**: DRAFT — NOT APPROVED. Open questions in §9 must be resolved first.
**Created**: 2026-07-25
**Target**: SwiftProyecto 4.7.0 (additive public API to `ProjectBrowser`)
**Consumers affected**: `Proyecto` (app shell), `Produciesta`, any `ProjectWindow` host

---

## 1. Problem Statement

Today an audio file is browsed like any other file: you expand a folder in the
navigation pane, click one `.mp3`, and `AudioPlayerView`
(`Sources/ProjectBrowser/Views/AudioPlayerView.swift`) takes over the entire
detail pane as a full-height "now playing" screen. Three things are wrong with
this:

**1.1 — The interaction model is wrong for a folder of audio.** A podcast
project's `audio/` folder holds dozens of related takes. Auditioning them means
collapsing back to the tree, clicking the next file, and waiting for a whole new
player to mount. The tree is the wrong instrument for a flat list of
interchangeable media.

**1.2 — The player does not fit the pane.** `AudioPlayerView` is built as a
full-bleed screen: `Spacer()` → 48pt `waveform` glyph → `Spacer()` → transport,
wrapped in `.frame(maxWidth: .infinity, maxHeight: .infinity)`
(`AudioPlayerView.swift:20–117`). It therefore stretches to whatever height the
pane has, floating a giant icon in dead center and gluing the transport to the
bottom edge. At the app's minimum window width (640pt, set in the app's
`ContentView.swift:163`) minus a 250pt sidebar, the transport row —
play button + `Spacer()` + two speaker glyphs + a 100pt volume slider
(`AudioPlayerView.swift:66–90`) — has under 390pt to work with and crowds.

**1.3 — The colors are wrong, and not only in the player.** Root causes, all
hardcoded non-semantic values:

| Location | Code | Why it's wrong |
| --- | --- | --- |
| `AudioPlayerView.swift:118` **as built** | `.background(Color(white: 0.95))` | A fixed light grey. In dark mode this is a bright panel with `.secondary` text on it. **This is almost certainly what the user is looking at — see §1.4.** |
| `AudioPlayerView.swift:121` **in the working copy** | `.background(.background)` | The 4.6.1 fix for the above, but still wrong: it paints an opaque window-background *over* the split-view detail column, which normally has its own material. The player becomes a visibly different shade than the text editor in the same slot. |
| `ImageContentView.swift:18` | `Color(white: 0.95)` | The identical unfixed bug in the image view. 4.6.1 fixed only the audio view. |
| `AudioPlayerView.swift:111` | `Color.red.opacity(0.1)` | Fixed alpha over an unknown backdrop; muddy in light mode, nearly black-red in dark. |
| `AudioPlayerView.swift:73` | `.buttonStyle(.plain)` on the transport | Suppresses accent tint and hover/pressed feedback. The primary control reads as flat dead text. |
| `FileTreeView.swift:186` | `Color.blue.opacity(0.2)` | Hand-rolled selection highlight inside a `.listStyle(.sidebar)` `List`. Ignores the user's accent color, does not desaturate when the window loses focus, does not invert the label, and has no keyboard focus ring. This is why sidebar selection looks foreign on macOS. |
| `FileTreeView.swift:258` | `.blue` folder icons | Should follow accent/tint. |
| `AudioPlayerView.swift:46, 83` | Untinted `Slider`s | Progress and volume read as system-chrome grey rather than as the app's accent. |

The sidebar row in `FileTreeView` is the deeper issue: it is a hand-painted
approximation of native selection rather than SwiftUI's `List(selection:)`.
Fixing that fixes selection color, focus behavior, and keyboard navigation at
once.

**1.4 — The app is not running the code we've been fixing.** `Proyecto`'s
`Package.resolved` pins SwiftProyecto **4.6.0**, and the requirement is
`upToNextMajorVersion` from `4.4.0` (`Proyecto.xcodeproj/project.pbxproj:383–389`).
The 4.6.1 "audio player contrast fixes" — the `.background(.background)` change,
the `AudioTimeFormatter` extraction, the `NaN` duration guard, the idempotent
`stop()`, the whole `AudioPlayerViewTests.swift` file — are **not in the build**.
The DerivedData checkout the app actually compiles still has
`.background(Color(white: 0.95))`.

So a meaningful slice of "the colors are all off" is a stale dependency, not a
design problem. **Resolving the app to 4.6.1 is a prerequisite step, and should
happen before any of this work, so we're judging the current design rather than
last month's.** It will not fix the layout complaint (§1.2), which is unchanged
in 4.6.1, and it will not fix the sidebar selection color.

Any fix here must be **verified visually in both color schemes**, not just
reasoned about — 4.6.1 reasoned about semantic colors and still produced the
pane-mismatch defect.

---

## 2. Proposed Solution

Introduce the concept of a **special folder** in `ProjectBrowser`: a directory
that, when selected in the navigation pane, renders a purpose-built view for its
*contents* in the detail pane instead of exposing its children as tree rows.

The first (and for now only) special folder is the **audio folder**, rendered by
a new `AudioFolderView`:

```
┌─ Navigation ────────┬─ Detail ──────────────────────────────────┐
│ ▸ episodes          │ ┌───────────────────────────────────────┐ │
│ ▸ scripts           │ │ ♪  intro-take-3.m4a          1:04     │ │  ← player header
│   audio          ◀──┼─┤ ◀◀  ▶  ▶▶   ──●────────────  🔊 ────  │ │    (fixed height,
│   README.md         │ └───────────────────────────────────────┘ │     does not scroll)
│                     │  intro-take-1.m4a              0:58   ⋯  │
│   (no children)     │  intro-take-2.m4a              1:01   ⋯  │  ← scrolling list
│                     │ ▶ intro-take-3.m4a             1:04   ⋯  │
│                     │  outro.mp3                     0:22   ⋯  │
└─────────────────────┴───────────────────────────────────────────┘
```

The single player instance persists across track changes — selecting a different
row retargets the existing player rather than mounting a new one, so volume
survives and there is no remount flash.

---

## 3. Functional Requirements

### 3.1 Special-folder identification

- **FR-1** A folder is treated as an audio folder when its name matches, case
  insensitively, one of a configurable set of names. Default: `["audio"]`.
- **FR-2** Matching applies at **any depth**, not only the project root.
- **FR-3** Identification is by name only. The view never sniffs contents to
  decide whether a folder is special — a folder named `audio` that happens to be
  empty is still an audio folder (see FR-16), and a folder named `renders` full
  of `.wav` files is not.
- **FR-4** The host app can override the name set, and can disable the behavior
  entirely by passing an empty set. The default `ProjectWindow` initializer must
  keep today's behavior for callers who pass nothing, so 4.6.x consumers see no
  change until they opt in.

### 3.2 Navigation pane

- **FR-5** An audio folder renders as a **selectable leaf row** — no disclosure
  triangle, no children. It uses a distinct icon (`music.note.list`) so it reads
  as a destination rather than a container.
- **FR-6** Selecting it makes it the detail pane's subject. This is new: folder
  rows are currently `DisclosureGroup`s with no tap handler at all
  (`FileTreeView.swift:164–178`), so folders cannot be selected today.
- **FR-7** Audio-folder descendants must remain present in `ProjectWindow`'s
  `files` array — they are the audio view's data source. Hiding them must happen
  at tree-build time (`FileTreeView.buildTree`), **not** via the existing
  `fileFilter` parameter (`ProjectWindow.swift:95`), which filters the discovered
  list itself and would starve the audio view of data.
- **FR-8** Non-audio children of an audio folder (a `README.md`, a `cover.jpg`,
  a `stems/` subfolder) must not become unreachable. See open question §9.2.

### 3.3 The player header

- **FR-9** Fixed-height header pinned to the top of the detail pane; the file
  list scrolls beneath it. Target height ≤ 96pt; hard ceiling 120pt.
- **FR-10** Contains: track title, elapsed / total time, a seek scrubber,
  play/pause, previous/next track, and volume.
- **FR-11** Must lay out without clipping or crowding down to a **280pt** pane
  width. Below the comfortable threshold, degrade in this order: (a) hide the
  speaker glyphs flanking the volume slider, (b) hide the volume slider entirely,
  (c) move the time labels under the scrubber. Never truncate the transport
  controls.
- **FR-12** With no track loaded, the header shows a disabled/placeholder state
  at the same height — it must not collapse and reflow the list when the first
  track loads.
- **FR-13** The player is created once per audio-folder view and **retargeted**
  on track change. `AudioPlayerController` currently binds its URL at `init`
  (`AudioPlayerView.swift:182`) and must gain a `load(url:)` that tears down the
  previous item's observers and arms the new one, preserving volume.

### 3.4 The file list

- **FR-14** Lists every audio file under the audio folder, recursively.
  "Audio file" is determined by extension against `DefaultHandlers.audioExtensions`
  (`Sources/ProjectBrowser/Handlers/DefaultHandlers.swift:11`), case insensitively.
- **FR-14a** There must be exactly **one** audio-extension list in the library.
  `FileTreeRowLabel.fileIconName` currently keeps a second, disagreeing one
  (`FileTreeView.swift:278`: `"mp3", "wav", "m4a", "aiff", "caf"`), so today
  `.flac` / `.aac` / `.ogg` / `.opus` / `.wma` / `.alac` play correctly but draw a
  generic `doc` icon, while `.caf` draws a waveform and has no handler at all.
  This must be collapsed onto `DefaultHandlers.audioExtensions` — otherwise the
  audio view and the tree will disagree about what an audio file is.
- **FR-14b** Extension matching is case insensitive **everywhere**. The app
  currently works around lowercase-only handler keys by mirroring every key
  uppercased (`ContentView.swift:187–194`), which still misses mixed case like
  `Song.Mp3`. Lookup should lowercase the extension in the library so the host
  needs no workaround.
- **FR-15** Each row shows: filename, duration, and a now-playing indicator.
  Rows for files in a subfolder also show their path relative to the audio folder,
  so `stems/vox.wav` is distinguishable from `vox.wav`.
- **FR-16** Empty state: an audio folder with no audio files shows a
  `ContentUnavailableView`, not a blank pane.
- **FR-17** Selecting a row loads it into the header player and begins playback.
- **FR-18** **Selected** and **now playing** are distinct states and must be
  visually distinct — with auto-advance (§9.3) they routinely diverge.
- **FR-19** Rows carry the same context menu as tree file rows (Reload, Show in
  Finder, Delete). Deleting the now-playing track stops playback and clears the
  header.

### 3.5 Duration metadata

- **FR-20** Durations load asynchronously and lazily — only for rows that have
  been on screen — and are cached for the view's lifetime. Eagerly loading an
  `AVURLAsset` per file would stall a folder of 500 takes.
- **FR-21** A row whose duration cannot be read shows `--:--`, not `0:00`, and
  remains selectable so the failure surfaces in the player's error state rather
  than being silently hidden.

### 3.6 Lifecycle and correctness

- **FR-22** Playback stops when the audio folder is deselected, the view
  disappears, or the window closes. The existing idempotent `stop()` and `deinit`
  backstop (`AudioPlayerView.swift:270–304`) must be preserved through the
  refactor.
- **FR-23** Playback state must derive from `AVPlayer.timeControlStatus`, not
  from a locally toggled flag. `togglePlayPause` currently does
  `isPlaying.toggle()` (`AudioPlayerView.swift:251`), so a stall or a failed
  `play()` leaves the UI asserting playback that isn't happening.
- **FR-24** Non-finite / zero-duration guard from 4.6.1
  (`AudioPlayerView.swift:213`) must survive: a malformed asset must not let the
  scrubber build `NaN` `CMTime`s.
- **FR-25** Files are read inside the host's security scope. The scope is held
  for the window's lifetime by the app (`ContentView.swift:210–240`), and
  `AVPlayer` reads lazily throughout playback — so playback must not outlive the
  view that the scope is tied to.

### 3.7 Color and material (fixes §1.3)

- **FR-26** Neither `AudioFolderView` nor `AudioPlayerView` sets an opaque
  background on the detail pane. Remove `.background(.background)`. The pane
  supplies its own backdrop; the player is chrome drawn on top of it.
- **FR-27** No hardcoded color literals. Every fill, tint, and foreground comes
  from a semantic role (`.primary`, `.secondary`, `.tint`, `.selection`,
  `.quaternary`) or a `Material`. This applies to the header, the rows, the error
  state, and the sliders.
- **FR-28** `FileTreeView` migrates to `List(selection:)` with native row
  selection, deleting the `Color.blue.opacity(0.2)` highlight
  (`FileTreeView.swift:186`). Folder icons follow the accent, not literal `.blue`
  (`FileTreeView.swift:258`).
- **FR-29** Progress and volume sliders are `.tint`ed. The play/pause button uses
  an accented, hit-targeted style — not `.buttonStyle(.plain)`.
- **FR-30** Verified by eye in **light and dark**, at the **default and a
  non-blue accent color**, and with **Increase Contrast** enabled. A screenshot
  of each is the acceptance artifact; reasoning about semantic colors is not
  sufficient, since 4.6.1 did exactly that and still regressed.

### 3.8 Accessibility and keyboard

- **FR-31** Up/Down arrows move row selection; Space toggles play/pause;
  Left/Right seek by a fixed increment.
- **FR-32** Every transport control has an accessibility label. The scrubber
  exposes an accessibility value as elapsed-of-total, not a raw 0–1 fraction.
- **FR-33** Now-playing state is conveyed by more than color (an icon), for
  color-vision deficiency and for FR-18's selected-vs-playing distinction.

---

## 4. Non-Functional Requirements

- **NFR-1** No new package dependencies. `AVFoundation` only.
- **NFR-2** A 500-file audio folder opens in under 250ms to first paint;
  durations fill in progressively.
- **NFR-3** Additive public API only. No existing `ProjectWindow` initializer
  signature changes in a source-breaking way.
- **NFR-4** iOS and macOS both supported, consistent with the rest of
  `ProjectBrowser`. On compact iOS the audio folder pushes `AudioFolderView` as a
  navigation destination exactly as a file does today
  (`ProjectWindow.swift:301–317`).

---

## 5. Public API Sketch

```swift
// New: describes folders that render as a destination rather than a container.
public struct SpecialFolderRule: Sendable {
  public let names: Set<String>            // matched case-insensitively
  public let icon: String                  // SF Symbol for the nav row
}

extension SpecialFolderRule {
  public static let audio = SpecialFolderRule(names: ["audio"], icon: "music.note.list")
}

// New: the detail-pane view for an audio folder.
public struct AudioFolderView: View {
  public init(folder: ProjectFile, files: [ProjectFile], directoryURL: URL)
}

// ProjectWindow gains one parameter, defaulted to preserve 4.6.x behavior.
public init(
  directoryURL: URL,
  handlers: [String: (ProjectFile) -> AnyView] = [:],
  folderHandlers: [SpecialFolderRule: (ProjectFile, [ProjectFile]) -> AnyView] = [:],
  // …existing parameters unchanged…
)
```

`ProjectDetailPane` currently routes solely on
`handlers[file.fileExtension ?? ""]` (`ProjectDetailPane.swift:160`). A folder
has a `nil` extension, so it would land on the `""` key — routing must branch on
`isDirectory` **before** the extension lookup, not lean on that coincidence.

---

## 6. Non-Goals

- Waveform rendering (see §9.4).
- Playlists, queues, or reordering.
- Editing, trimming, format conversion, or export.
- `MPNowPlayingInfoCenter` / media-key integration.
- Persisting per-file playback position across sessions.
- Any special folder other than audio (the rule type is the extension point).

---

## 7. Nuances Worth Naming

These are the non-obvious consequences of the design, recorded so they are
decided rather than discovered.

**7.1 — Folders are not currently selectable at all.** This is the largest piece
of work, and it is invisible from the outside. `FileTreeNodeRow` gives directory
nodes a `DisclosureGroup` and no tap handler (`FileTreeView.swift:164–178`).
Making one folder a destination means introducing a selection model that spans
files *and* folders, which touches `selectedFile`, `ProjectDetailPane`, and every
call site that assumes selection is a file.

**7.2 — The per-extension audio handler does not go away.** Audio files living
outside an audio folder (`episodes/01/scratch.m4a`) still need
`AudioPlayerView`. Both paths must be maintained, which means two players can
exist in one window — one in a tree-selected file's pane, one in an audio
folder's header. Only one detail pane is visible at a time, so they cannot
overlap in practice, but the teardown paths must both be correct.

**7.3 — Two windows, two players.** `WindowGroup(for: URL.self)` allows several
project windows (`ContentView.swift:22`). Each gets an independent player, so two
windows can play simultaneously. That is arguably correct for a media browser and
arguably infuriating. No coordination is proposed; flagging it as accepted
behavior.

**7.4 — Nothing watches the filesystem.** Discovery runs once on appear
(`ProjectWindow.swift:567`); refresh is the sidebar's manual Sync button. A file
rendered into `audio/` by another tool — which for this ecosystem is the *normal*
case, since Produciesta writes into `audio/` — will not appear until the user
syncs. For a view whose whole purpose is auditioning freshly generated takes,
that is a real gap. Either scope FSEvents/`DispatchSource` watching in, or put a
visible Refresh affordance in the audio view's header.

**7.5 — `fileFilter` is the wrong tool and will silently break this.** It
filters the discovered array (`ProjectWindow.swift:573`), so using it to hide
audio children would also remove them from `files`, leaving the audio view with
an empty list and no obvious cause. Hiding must be a tree-build concern.

**7.6 — Recursive flattening loses structure.** `audio/stems/`, `audio/music/`,
`audio/episode-01/` all collapse into one list. FR-15's relative-path column
mitigates it but does not restore grouping. If projects nest audio meaningfully,
sectioned rows are a follow-up.

**7.7 — Duration loading is the hidden performance cliff.** Every row's duration
is an async `AVURLAsset.load(.duration)`. Naively mapping over the file list
spawns one task per file on appear. FR-20's lazy+cached requirement is load
bearing, and it interacts with `List` laziness — a non-lazy container defeats it.

**7.8 — Retargeting a player is not the same as replacing one.** The obvious
implementation — key the controller off the selected track so SwiftUI recreates
it — resets volume, flashes the header, and re-runs duration loading on every
track change. FR-13's `load(url:)` exists specifically to avoid that, and it has
to correctly unwind the previous item's periodic time observer and
`AVPlayerItemDidPlayToEndTime` observer, which is where the 4.6.1 crash fixes
lived.

**7.9 — Selection survives a delete-in-place.** Deleting the now-playing file
must stop the player, not leave `AVPlayer` holding a vanished URL. The existing
delete path clears `selectedFile` only when the deleted file *was* the selection
(`ProjectWindow.swift:462`); now-playing is a separate identity.

**7.10 — The color fix is bigger than the player.** FR-28 changes `FileTreeView`
for every file type, not just audio. That is the correct fix, but it means this
work visibly alters the sidebar for every consumer — it belongs in the release
notes, not slipped in as an audio change.

**7.11 — "Special folder" is a precedent.** Once `audio/` is a destination,
`images/`, `scripts/`, and `episodes/` are obvious next requests. Naming the
extension point `SpecialFolderRule` rather than hardcoding audio costs almost
nothing now and avoids a second refactor later.

**7.12 — The `audioDir` convention already exists, one target away.** This
project already has a canonical answer to "which folder is the audio folder":

- `SwiftProyecto/Models/ProjectFrontMatter.swift:106` declares an `audioDir`
  front-matter field, and `resolvedAudioDir` (line 426) defaults it to `"audio"`.
- `ProjectService.isAudioDirectory` (`ProjectService.swift:1111–1114`) already
  recognizes `audio`, `audio_output`, and `output`, feeding
  `ProjectStructure.audioDirectories`.

None of it is reachable from the browser: `ProjectBrowser` is declared with **no
dependencies at all** (`Package.swift:119–126`), deliberately, and parses
`PROJECT.md` with its own small `ProjectMetadata` type. Honoring `audioDir` means
either giving `ProjectBrowser` its first dependency (rejects the library's design
principle of genericity), teaching its own `ProjectMetadata` to read the
`audioDir` key (cheap, duplicates a schema), or having the host app read it and
pass the folder name in (keeps the library generic, pushes work onto every
consumer). This is the substance of §9.1 and it is a design-principle decision,
not a detail.

**7.13 — Waveform prior art exists, and it costs a dependency.**
`SwiftCompartido` already ships `AudioPlayerManager` (real `AVAudioPlayer`
metering, published `audioLevels: [Float]`) and `SpectrogramVisualizerView`.
Tempting — but `ProjectBrowser` imports nothing today, and `SwiftCompartido` is a
large library. Adopting it for a waveform would be the single biggest
architectural change in this proposal, for the most cosmetic requirement. This is
the main argument for §9.4's recommendation.

---

## 8. Acceptance Criteria

1. A project with an `audio/` folder shows it as a leaf row with a distinct icon
   and no disclosure triangle.
2. Selecting it shows a header player plus a scrolling list of every audio file
   beneath it, recursively.
3. Selecting a row plays it; the header does not remount, and volume set on the
   previous track carries over.
4. The header stays ≤ 120pt tall and renders without clipping at a 280pt pane
   width.
5. The detail pane's background is visually identical between the audio folder
   view, the text editor, and the image view.
6. Screenshots in light and dark, at a non-blue accent, with Increase Contrast on,
   show no hardcoded-color artifacts.
7. Sidebar selection matches native macOS sidebar selection, including
   window-focus desaturation.
8. An empty `audio/` folder shows an explanatory empty state.
9. A corrupt audio file shows `--:--` in its row and a readable error in the
   header on selection; no crash, no `NaN` scrubber.
10. Deselecting the audio folder or closing the window stops playback.
11. Projects with no `audio/` folder behave exactly as in 4.6.1.
12. Existing `ProjectWindow` call sites compile unchanged.
13. `.flac`, `.aac`, `.opus`, `.alac`, `.wma`, and `.ogg` files draw a waveform
    icon in the tree, and `.caf` no longer claims one (FR-14a).
14. `Song.Mp3` opens in the player with no key-mirroring workaround in the host
    (FR-14b).
15. `ImageContentView` no longer hardcodes `Color(white: 0.95)`.

**Prerequisite, done first and separately:** bump `Proyecto`'s SwiftProyecto
dependency so the app builds 4.6.1 rather than 4.6.0 (§1.4), then re-look at the
player. Some of the color complaint may evaporate, and what remains is what this
document should actually be scoped against.

---

## 9. Open Questions — BLOCKING

**9.1 — How is the audio folder identified?** (see §7.12)
Options: (a) a configurable name set defaulting to `["audio"]`, matched
case-insensitively at any depth, entirely inside `ProjectBrowser`; (b) honor
`PROJECT.md`'s `audioDir` by teaching `ProjectBrowser`'s own `ProjectMetadata` to
read that one key; (c) honor `audioDir` by depending on the `SwiftProyecto`
target; (d) the host app resolves it and passes the name in.
*Recommendation: (a) now, shaped so (b) is a later drop-in. It keeps
`ProjectBrowser` dependency-free and generic, and `"audio"` is already the
`resolvedAudioDir` default — so for every real project in this ecosystem (a) and
(b) agree. Reject (c) outright: a UI library taking a dependency on the domain
library inverts the layering.*

**9.2 — What happens to non-audio files inside `audio/`?**
Options: (a) hide the folder's children entirely — a `README.md` in `audio/`
becomes unreachable; (b) hide only the audio files, leaving non-audio children
visible under the folder row, which means the row needs a disclosure triangle
after all and contradicts FR-5; (c) show non-audio children in a second section
of `AudioFolderView`.
*Recommendation: (c). It honors "just show the audio file view," keeps everything
reachable, and keeps the nav row a clean leaf.*

**9.3 — Does playback auto-advance to the next track?**
Options: (a) stop at end of track; (b) auto-advance through the list; (c)
auto-advance with a user toggle.
*Recommendation: (a) for the first cut. Auditioning takes means comparing two
files, not listening through; auto-advance would play the wrong take over you.
It is also what makes selected-vs-now-playing (FR-18) diverge, so deferring it
removes a whole class of state.*

**9.4 — Waveform, or a plain scrubber?** (see §7.13)
A waveform needs sample decoding and an offscreen render per track — real cost in
implementation and per-track latency, it fights the ≤96pt header height, and the
existing prior art (`SwiftCompartido.AudioPlayerManager` / `SpectrogramVisualizerView`)
would give `ProjectBrowser` its first-ever dependency.
*Recommendation: plain tinted scrubber. Revisit only if auditioning takes turns
out to need visual comparison, and treat it as its own piece of work.*

**9.5 — Should the audio view watch the filesystem?** (§7.4)
Options: (a) manual Sync only, as today; (b) a Refresh button in the audio
header; (c) FSEvents watching.
*Recommendation: (b) now, (c) as a follow-up for all of `ProjectBrowser` rather
than as an audio-only special case.*

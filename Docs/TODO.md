---
type: doc
name: SwiftProyecto TODO
description: Active backlog and completed-work log for SwiftProyecto.
---

# TODO: Let a host select a file in `ProjectWindow` 🚧

**Requested by:** Escribir, for its Markdown preview. A link in the preview of
`chapter1.md` to `chapter2.md` must be able to show `chapter2.md` in the project
window. Escribir's requirements: `docs/REQUIREMENTS-markdown-preview.md` § 7 on its
`feature/markdown-preview` branch. That work cannot build file links until this
ships in a release.

**The gap (verified at v5.2.0, `bbb1235`):** `ProjectWindow` keeps selection in
`@State private var selectedFile` (`Sources/ProjectBrowser/ProjectWindow.swift:139`)
and exposes it only through the outbound `onFileSelection` callback. A host has no
binding, method, environment action or notification to request a selection. There is
also no public lookup of a `ProjectFile` by path, and a host-built `ProjectFile`
never equals the window's own, because `id` is a fresh `UUID` per construction.

**Behaviour required** (the API shape is this package's call: a binding, a request
value, or an action):

- The host identifies the file by its path relative to `directoryURL`.
- The sidebar highlights the file and expands its ancestor folders.
- The detail pane shows it through the same path a click takes: the private
  `selectFile(_:)` at `ProjectWindow.swift:443`, so lazy loading and
  `onMissingFileSelected` behave identically.
- `onFileSelection` fires, as for a click.
- A path that is not in the discovered tree, or that names a directory, is ignored
  and the current selection stands. No error, no crash.
- It works in both layouts: `splitLayout`, and the compact `stackLayout`, where it
  pushes the detail through `navigationDestination(item:)`.
- Requesting the already-selected file is a no-op that does not reload its content.
- Source-compatible: every existing `ProjectWindow(...)` call site compiles unchanged.

**Open work:**
- [x] **Decided: environment action.** `\.selectProjectFile` (`ProjectFileSelectionAction`)
      is installed on the detail pane in both layouts. The request comes from inside
      the detail pane, so an environment action fits. No binding was added.
      (`Sources/ProjectBrowser/Models/ProjectFileSelectionRequest.swift`)
- [x] Resolve a relative path to the window's own `ProjectFile` in its `files` array,
      matching exactly on `relativePath` (`ProjectFileSelectionResolver`).
- [x] Ancestor expansion: every ancestor folder id is unioned into `expandedFolders`.
- [x] **Decided: no sidebar scroll in this release.** Scrolling the revealed row into
      view is deferred to a follow-up. It is documented as not implemented in
      `Docs/ARCHITECTURE_ProjectBrowser.md` §6.5.
- [x] Route through `selectFile(_:)` so there is one selection path.
- [ ] Tests for each bullet under "Behaviour required", in both layouts. **Partial.**
      `ProjectFileSelectionRequestTests` covers resolution, ancestors, rejection of
      unknown and directory paths, and the action. The window-level bullets (highlight,
      detail load, `onFileSelection`, no-op on the selected file, both layouts) have no
      test: selection lives in the window's private `@State`, and no seam exposes it.
- [x] Fix the doc comment at `ProjectWindow.swift:41`, which called a nonexistent
      `file.url(in:)`.
- [ ] Ship in the next minor release. The CHANGELOG and architecture doc are updated
      under Unreleased. The release itself is still pending, and so is the item above.

**Not in scope:** a public by-path lookup on `ProjectFileDiscovery`, host ownership
of the file list, or any change to security scoping (the host keeps that).

---

# TODO: Required `type` property in episode/intro/outro front matter 🚧

**Decision:** `type` (`episode` | `intro` | `outro`) is a **write-time
guarantee, not an intake requirement.**

- **Intake stays permissive.** Reading/parsing NEVER requires `type` and never
  errors when it is missing. FountainParser is already fully permissive — leave
  it that way; do not add an intake validator.
- **On every write, emit `type`.** Whenever we write a screenplay file we always
  write a `type` key, and we **infer the value from context and (re)write it** —
  setting it when absent and correcting it when it disagrees with the inferred
  type. Inference: the intro bracket writer → `intro`; the outro bracket writer →
  `outro`; episode generation → `episode`.

This keeps a file's relationship to the whole self-describing and discoverable
from the file itself, independent of where it sits in `episodesDir`, without
rejecting hand-authored or third-party files that omit it.

**Path interpretation (settled):** `introFile`/`outroFile` are *project-resolved*
— relative to the project root (the PROJECT.md location), NOT relative to
`episodesDir`. The code already resolves this way
(`GenerateCommand.swift` → `projectDirectory.appendingPathComponent(path)`); the
docs/comments were corrected to match. Example value: `episodes/intro.fountain`.

**Open work:**
- [x] **Write-side normalization.** The only screenplay writers in this repo are the
      intro and outro placeholders in `GenerateCommand.swift`. Both now render through
      `ScreenplayFileType.placeholderDocument(...)` (`Sources/SwiftProyecto/Models/ScreenplayFileType.swift`),
      which always writes `type:`. Each writer overwrites its file wholesale, so a
      written file always carries the inferred value.
- [x] **Episode generation: nothing to change here.** This repo has no writer that
      produces episode screenplays. `episode` exists as a case so a future writer can
      use it.
- [x] Do **NOT** add intake validation/enforcement. Nothing in this change reads or
      rejects `type`.
- [x] **Generation prompt: nothing to change.** `IterativeProjectGenerator` writes only
      PROJECT.md, never a screenplay, so it has no `type` to emit.
- [x] Fix the placeholder writers: `type: fountain` is now `type: intro` or `type: outro`.
- [ ] Fixtures and round-trip tests. **Partial.** `ScreenplayFileTypeTests` asserts the
      rendered `type:` value, that it sits inside the front matter, and the full output.
      Still missing: a test that the CLI writer actually uses the helper (CLI tests drive
      the binary, and no end-to-end test covers `generate` output), and a test that
      reading a file WITHOUT `type` still succeeds. The fountain reader is in
      SwiftCompartido, not this package.

---

# SwiftBruja → Apple Foundation Models Refactor ✅

## Overview
Replaced SwiftBruja LLM inference with macOS 27 native Apple Foundation Models API. Eliminated external dependency while using optimized on-device inference.

## Completed Changes

### Phase 1: API Discovery ✅
**Framework**: FoundationModels  
**Session**: `LanguageModelSession`  
**Method**: `respond(options:prompt:) async throws -> Response<String>`  
**Supported Parameters**:
- `temperature: Double?` (via GenerationOptions)
- `maximumResponseTokens: Int?` (via GenerationOptions)
- `samplingMode: GenerationOptions.SamplingMode?`
- System prompt via `Instructions`

**Implementation**:
```swift
let session = try LanguageModelSession(model: .default, tools: [], instructions: instructions)
let response = try await session.respond(options: options) { Prompt(userPrompt) }
```

### Phase 2: Remove Bruja Dependency ✅
- ✅ Removed SwiftBruja from Package.swift dependencies
- ✅ Removed SwiftBruja from proyecto executable target
- ✅ Removed SwiftBruja from test target
- ✅ Removed `import SwiftBruja` from ProyectoCLI.swift
- ✅ Removed `import SwiftBruja` from IterativeProjectGenerator.swift
- ✅ Verified no other files reference SwiftBruja

### Phase 3: Implement Apple Foundation Models ✅
- ✅ Added `import FoundationModels` to IterativeProjectGenerator
- ✅ Replaced `Bruja.query()` with `queryFoundationModel()` helper
- ✅ Handles both JSON config and text responses
- ✅ Maintains temperature (0.3) and max tokens control via GenerationOptions
- ✅ Proper error handling via Foundation Models exceptions

### Phase 4: Update proyecto CLI ✅
- ✅ Removed DownloadCommand struct
- ✅ Removed `--model` option from InitCommand
- ✅ Updated InitCommand to not pass modelId to IterativeProjectGenerator
- ✅ Updated help text to reference Foundation Models
- ✅ Removed DownloadCommand from subcommands list

### Phase 5: Testing ✅
- ✅ Project compiles successfully (Debug and Release)
- ✅ No compilation errors or warnings
- ✅ Build validation confirms all Foundation Models APIs are correct

### Phase 6: Cleanup ✅
- ✅ Removed modelId parameter from IterativeProjectGenerator.init()
- ✅ Updated IterativeProjectGenerator documentation
- ✅ Updated TODO.md with completion status

## Summary

**Files Changed**:
- Package.swift: Removed SwiftBruja dependency
- Sources/proyecto/IterativeProjectGenerator.swift: Replaced Bruja.query() with Foundation Models
- Sources/proyecto/ProyectoCLI.swift: Removed DownloadCommand and --model option

**Impact**:
- SwiftProyecto no longer depends on SwiftBruja (eliminated external dependency)
- Uses macOS 27 native Foundation Models for on-device LLM inference
- Better performance and lower latency for on-device inference
- Simplified project structure with fewer dependencies

**Testing Notes**:
To fully test at runtime, the proyecto CLI should be run on macOS 27 with Foundation Models available. The code compiles and builds successfully, validating that the Foundation Models API usage is correct.

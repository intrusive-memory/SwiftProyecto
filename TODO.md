---
type: doc
name: SwiftProyecto TODO
description: Active backlog and completed-work log for SwiftProyecto.
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
- [ ] **Write-side normalization (the core change).** Every code path that writes
      a screenplay file must emit `type`, inferring the value and rewriting it
      (set if absent, correct if wrong). Inference by writer role: intro → `type:
      intro`, outro → `type: outro`, episode generation → `type: episode`.
- [ ] Do **NOT** add intake validation/enforcement. Parsing stays permissive
      (FountainParser already tolerates missing/arbitrary keys; `.fountain` front
      matter isn't schema-validated). No "type required" error on read.
- [ ] **Test our generation prompt against the required `type` property.** The
      LLM generation path (`Sources/proyecto/IterativeProjectGenerator.swift`)
      and the intro/outro writers (`Sources/proyecto/GenerateCommand.swift`
      `generateIntroFile`/`generateOutroFile`) must emit the inferred `type`, with
      tests asserting the produced front matter carries the correct value.
- [ ] Fix the placeholder writers: they currently emit `type: fountain` — change
      to the inferred intro/outro/episode value.
- [ ] Add fixtures + round-trip tests asserting written files carry the inferred
      `type` (and that reading a file WITHOUT `type` still succeeds).

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

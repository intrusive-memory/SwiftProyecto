---
type: reference
name: AGENTS.md
description: Quick reference for AI agents working with SwiftProyecto
updated: 2026-07-19
---

# SwiftProyecto — Agent Quick Reference

SwiftProyecto is a Swift package providing **extensible, agentic discovery of content projects and project components** with machine-readable PROJECT.md front matter, file discovery, and cast list extraction.

**What it does**: Stores project metadata (title, author, season, episodes, cast lists) in structured YAML front matter for AI agent consumption. Parses/generates PROJECT.md files, discovers files recursively, extracts cast from screenplay files (.fountain, .fdx, .highland).

**What it doesn't do**: Parse screenplay content, render content, store document models, or provide UI.

**Platforms**: iOS 26.0+, macOS 26.0+ (Apple Silicon only)

---

## 📚 Documentation Index

### Quick Start
- **[INTEGRATION_GUIDE.md](Docs/INTEGRATION_GUIDE.md)** — How to integrate SwiftProyecto into your app
- **[PROJECT_MD_REFERENCE_v4.md](Docs/PROJECT_MD_REFERENCE_v4.md)** — All PROJECT.md field specifications
- **[EXAMPLE_PROJECT_v4.md](Docs/EXAMPLE_PROJECT_v4.md)** — Working PROJECT.md examples

### Detailed References
- **[CORE_ARCHITECTURE.md](Docs/CORE_ARCHITECTURE.md)** — Data models, services, backends
- **[CLI_REFERENCE.md](Docs/CLI_REFERENCE.md)** — `proyecto` CLI command reference
- **[PROJECT_MD_RULES.md](Docs/PROJECT_MD_RULES.md)** — Strict rules for modifying PROJECT.md

### Advanced Topics
- **[EXTENDING_PROJECT_MD.md](Docs/EXTENDING_PROJECT_MD.md)** — App-specific settings extension protocol
- **[MIGRATION_GUIDE.md](Docs/MIGRATION_GUIDE.md)** — Upgrading PROJECT.md between versions
- **[VARIANT_REFERENCE.md](Docs/VARIANT_REFERENCE.md)** — Master + variant file patterns
- **[INTRO_OUTRO_GUIDE.md](Docs/INTRO_OUTRO_GUIDE.md)** — Intro/outro file configuration

### Tools & Visualization
- **[graphify-out/graph.html](graphify-out/graph.html)** — Interactive visual map of codebase (1104 nodes)
- **[graphify-out/GRAPH_REPORT.md](graphify-out/GRAPH_REPORT.md)** — God nodes and community analysis

---

## ⚠️ Critical Rules

### Platform Version Enforcement

**iOS 26.0+ and macOS 26.0+ ONLY. NEVER support older platforms.**

- ❌ NO `@available(iOS < 26.0, ...)` attributes
- ❌ NO `#available(iOS < 26.0, ...)` runtime checks
- ✅ OK: `#if os(macOS)` or `#if canImport(UIKit)` for platform-specific code
- ✅ Package.swift must specify: `platforms: [.iOS(.v26), .macOS(.v26)]`

**Apps using this library must update deployment targets to iOS 26+ and macOS 26+.**

### Development Workflow

**⚠️ See [.claude/WORKFLOW.md](.claude/WORKFLOW.md) for complete workflow.**

- **Development branch**: All work happens here
- **Main branch**: Protected, PR-only (no direct pushes)
- **Required CI checks**: Code Quality, macOS Unit Tests, Integration Tests
- **Version strategy**: Semantic versioning (semver)
- **Never**: Commit to main, delete development branch, force push

**Branch Protection Updates**: When test names change, update `main` branch protection via:
```bash
gh api --method PATCH repos/intrusive-memory/SwiftProyecto/branches/main/protection/required_status_checks \
  --input - <<'EOF'
{
  "strict": true,
  "contexts": ["Code Quality", "macOS Unit Tests", "Integration Tests"]
}
EOF
```

---

## 🔧 Common Tasks

### Reading PROJECT.md

```swift
let parser = ProjectMarkdownParser()
let (frontMatter, body) = try parser.parse(fileURL: projectURL)
print(frontMatter.title)      // From YAML front matter
print(frontMatter.season)     // Optional field
print(body)                   // Content after front matter
```

### Discovering Cast from Screenplays

```swift
let projectService = ProjectService(modelContext: context)
let project = try await projectService.openProject(at: folderURL)
let cast = try await projectService.discoverCastList(for: project)
// Returns [CastMember(character: "NAME"), ...] with nil actors/voices
```

### Batch Audio Generation

```swift
let args = ParseBatchArguments(projectPath: "/path/to/project", format: "m4a")
let batchConfig = try ParseBatchConfig.from(projectPath: projectPath, args: args)

var iterator = batchConfig.makeIterator()
while let fileArgs = iterator.next() {
  // Generate audio for fileArgs.episodeFileURL
}
```

### Updating Cast with Voice Assignments

```swift
// ✅ CORRECT: Preserves other provider voices
let updated = frontMatter.mergingCast(newCast, forProvider: "apple")

// ❌ WRONG: Loses other provider voices
let updated = frontMatter.withCast(newCast)
```

---

## 🔐 Foundation Models Integration

SwiftProyecto uses Apple's `FoundationModels` framework for on-device LLM inference:

- **Model**: Qwen2.5 7B Instruct (4-bit quantized, ~4GB)
- **Download**: `proyecto download` caches model via SwiftAcervo CDN
- **Inference**: Zero-network after model cached locally
- **Use**: `proyecto init` generates PROJECT.md iteratively (8 focused LLM queries)
- **Configuration**: Edit `LanguageModel` in `ModelManager.swift` to use different model

---

## 📦 Extending with App-Specific Settings

Apps can define custom PROJECT.md settings without modifying SwiftProyecto:

```swift
struct MyAppSettings: AppFrontMatterSettings {
    static let sectionKey = "myapp"
    var theme: String?
    var autoSave: Bool?
}

let settings = try frontMatter.settings(for: MyAppSettings.self)
try frontMatter.setSettings(MyAppSettings(theme: "dark"))
```

**See [EXTENDING_PROJECT_MD.md](Docs/EXTENDING_PROJECT_MD.md) for full guide.**

---

## 🎬 Screenplay Format Support

Supports 3 formats with format-agnostic parsing via SwiftCompartido:
- **Fountain** (`.fountain`) — Plain-text
- **Final Draft** (`.fdx`) — XML-based
- **Highland** (`.highland`) — TextBundle (ZIP)

CastExtractor auto-detects format and extracts character names:

```swift
let extractor = CastExtractor()
let cast = try extractor.extractCast(from: screenplayURL)  // Returns ["NARRATOR", "LAO TZU", ...]
```

---

## 📦 Dependencies

- **UNIVERSAL** — YAML/JSON/XML parser for PROJECT.md
- **SwiftAcervo** — CDN model management & Qwen2.5 downloads
- **FoundationModels** (Apple) — On-device LLM inference
- **SwiftCompartido** — Screenplay parsing (.fountain, .fdx, .highland)
- **swift-argument-parser** — CLI argument parsing

---

## 🔗 Related Projects

- **SwiftCompartido** — Screenplay parsing & document models
- **SwiftHablare** — TTS & voice provider integration
- **Produciesta** — macOS/iOS app integrating these libraries

---

## 📌 Key Files

- `.claude/WORKFLOW.md` — Complete development workflow
- `.claude/AGENTS.md` → `CLAUDE.md` (symlink to this file)
- `Sources/SwiftProyecto/` — Core library code
- `Sources/proyecto/` — CLI implementation
- `Docs/` — Detailed reference documentation

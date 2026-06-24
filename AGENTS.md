---
type: reference
name: AGENTS.md
description: Comprehensive documentation for AI agents working with SwiftProyecto codebase
updated: 2026-06-23
---

# AGENTS.md

This file provides comprehensive documentation for AI agents working with the SwiftProyecto codebase.

**Current Version**: 4.0.0 (June 2026)

**Latest Changes (v4.0.0)**:
- **Multi-Season Schema**: `seasons[]` array replaces single `season` field for multi-season projects
- **Per-Character Language**: Optional `language` field on CastMember for language-specific voice selection
- **Property Hierarchy**: Four-level resolution (variant > season > master > default)
- **Backward Compatible**: v3.x PROJECT.md files automatically convert to synthetic seasons
- **CLI Enhancement**: `proyecto generate --season N` for per-season output

See [UPGRADING.md](UPGRADING.md) for complete v3.x → v4.0 migration guide.

**Previous Changes (v3.6.0)**:
- **Foundation Models Integration**: Replaced SwiftBruja with Apple Foundation Models framework
- **Model Change**: Qwen2.5 7B Instruct (4-bit) — enhanced instruction following and reasoning
- **MLX Removal**: No longer depends on MLX or metal shader compilation
- **Per-Language Voice Prompts**: Voice selection now supports language-specific prompt tuning

**Previous Changes (v3.4.0)**:
- Updated SwiftBruja to 1.4.0 (improved LLM inference performance)
- Updated default model to Llama-3.2-1B-Instruct-4bit (faster, more efficient)
- Updated SwiftAcervo to 0.6.0 (latest audio processing features)
- Synchronized all dependencies to latest resolved versions

**Previous Changes (v3.3.0)**:
- Add `proyecto validate` command to validate PROJECT.md files
- Support directory or direct file path arguments for validation
- Add --verbose flag to show parsed metadata
- Add 9 comprehensive integration tests for CLI validation
- Synchronized proyecto CLI version with library version

**Previous Changes (v3.2.0)**:
- `TTSConfig.actionLineVoice` field for configurable action line voice in audio generation
- Enables separate voice selection for dialogue vs action/stage directions
- Backward compatible (optional field, defaults to nil)

**Previous Changes (v3.1.0)**:
- `ProjectDiscovery` service for locating PROJECT.md from any file path
- `readCast(from:filterByProvider:)` for reading cast with provider filtering
- `ProjectMarkdownParser.write(frontMatter:body:to:)` for atomic file writes
- `ProjectFrontMatter.withCast(_:)` for replacing cast list
- `ProjectFrontMatter.mergingCast(_:forProvider:)` for safe, additive cast updates
- PROJECT.md Modification Rules documented in AGENTS.md

**Previous Changes (v3.0.0)**:
- **BREAKING**: Voice representation migrated from URL-style to key/value pairs
- Simpler API: `voice(for: "apple")` replaces `filterVoices(provider:)`
- Faster voice lookups with dictionary-based storage
- Better type safety with provider names as keys

**Previous Changes (v2.6.0)**:
- AppFrontMatterSettings protocol for extensible app-specific settings
- Namespaced settings sections in PROJECT.md frontmatter
- AnyCodable type-erased wrapper for storage
- Complete extension system with 50+ tests
- Full backward compatibility maintained

**Previous Changes (v2.5.0)**:
- CastMember.voiceDescription field for TTS voice selection guidance
- Inline cast list support in PROJECT.md
- Cast list discovery and merging helpers

---

## Project Overview

SwiftProyecto is a Swift package providing **extensible, agentic discovery of content projects and project components**.

**Purpose**: This project exists to help AI coding agents understand content projects in a single pass, eliminating the need for multiple utilities and discovery iterations. By storing project settings, utilities, intent, and composition in structured PROJECT.md front matter, AI agents can immediately comprehend what a project is, how it's structured, and how to render its content.

**Core Capabilities**:
- **Agentic Metadata**: Machine-readable PROJECT.md front matter for AI agent consumption
  - Project intent (title, author, genre, description, tags)
  - Composition structure (season, episodes, file patterns)
  - Generation settings (output directories, export formats)
  - Cast lists (character-to-voice mappings for TTS)
  - Workflow hooks (pre/post-generation automation)
  - App-specific settings (extensible via AppFrontMatterSettings protocol - **NEW in v2.6.0**)
- **File Discovery**: Recursively discover project components in folders/git repos
- **Secure Access**: Security-scoped bookmarks for sandboxed environments
- **Hierarchical Structure**: FileNode trees for navigation
- **SwiftData Persistence**: Project metadata and file references

**What SwiftProyecto Does**:
- ✅ Provides structured metadata for AI agents to understand projects
- ✅ Discovers files and builds navigable project structure
- ✅ Stores rendering settings and utilities in front matter
- ✅ Enables single-pass project comprehension (not multi-pass inference)
- ✅ Parses and generates PROJECT.md with YAML front matter

**What SwiftProyecto Does NOT Do**:
- ❌ Parse content files (use SwiftCompartido or other parsers)
- ❌ Render or generate content (provides metadata to renderers)
- ❌ Store content models (apps handle integration)
- ❌ Display UI (provides data only)

**Platforms**: iOS 26.0+, macOS 26.0+

---

## 📚 Developer Documentation

### 🕸️ Knowledge Graph

**Interactive Graph**: Open [`graphify-out/graph.html`](graphify-out/graph.html) in your browser for an interactive visual map of the codebase with 1104 nodes, 1662 edges, and 71 semantic communities.

**Graph Report**: See [`graphify-out/GRAPH_REPORT.md`](graphify-out/GRAPH_REPORT.md) for:
- God nodes (most connected abstractions)
- Surprising cross-community connections
- Hyperedges (group relationships)
- Community structure and cohesion scores

**Raw Data**: [`graphify-out/graph.json`](graphify-out/graph.json) is GraphRAG-ready for downstream LLM applications.

### 📖 Integration Guide for Developers

**🔗 Main Reference**: See [**Docs/INTEGRATION_GUIDE.md**](Docs/INTEGRATION_GUIDE.md) for a complete guide to integrating SwiftProyecto into your app.

Covers:
- **Core Components**: ProjectService, ProjectMarkdownParser, ProjectDiscovery
- **Common Workflows**: Reading/writing PROJECT.md, discovering files, accessing projects
- **Generating PROJECT.md**: Both CLI (`proyecto generate`) and programmatic approaches
- **Best Practices**: Security-scoped bookmarks, batch processing, error handling
- **Integration Patterns**: SwiftUI views, batch processing, SwiftData models

### 📖 PROJECT.md Documentation — v4.0.0 Schema

**v4.0.0 introduced multi-season and multi-language support with full backward compatibility for v3.x files.**

#### Core Documentation (Recommended Reading Order)

1. **[PROJECT_MD_REFERENCE_v4.md](Docs/PROJECT_MD_REFERENCE_v4.md)** — Complete field reference
   - All v4.0.0 schema fields and types
   - Multi-season array structure
   - Language definitions and variants
   - Cast member structure (including multi-voice support)
   - Property inheritance and resolution hierarchy
   - v3.x backward compatibility and auto-migration

2. **[EXAMPLE_PROJECT_v4.md](Docs/EXAMPLE_PROJECT_v4.md)** — Working examples
   - Single-season projects
   - Multi-season projects
   - Master + variant files (multi-language)
   - Variant files with language-specific casting
   - Single file with `episodePath` templating

3. **[MIGRATION_GUIDE.md](Docs/MIGRATION_GUIDE.md)** — v3.x → v4.0.0 upgrade
   - Step-by-step migration paths for different project types
   - Scenarios: single-season, multi-season, multi-language variants
   - Backward compatibility and safe upgrade procedures
   - Validation and testing

4. **[VARIANT_REFERENCE.md](Docs/VARIANT_REFERENCE.md)** — Master + variant patterns
   - When to use variants vs. single files
   - Master file structure (type: overview)
   - Variant file structure (type: project)
   - Pattern types: language variants, season variants, multi-language matrices
   - Directory organization best practices
   - Property inheritance and cast merging

5. **[INTRO_OUTRO_GUIDE.md](Docs/INTRO_OUTRO_GUIDE.md)** — Text directions and segment files
   - `introFile` and `outroFile` field usage
   - Path resolution and relative paths
   - Per-season and per-language intros
   - Fallback hierarchies and inheritance
   - Real-world patterns

#### Legacy Documentation (v3.x)

- **[PROJECT_MD_REFERENCE.md](Docs/PROJECT_MD_REFERENCE.md)** — v3.x schema (maintained for compatibility)
- **[EXAMPLE_PROJECT.md](Docs/EXAMPLE_PROJECT.md)** — v3.x example (maintained for reference)

---

## 🔐 Foundation Models Integration

**SwiftProyecto 3.6.0+ uses Apple Foundation Models for on-device LLM inference.**

### Architecture: Foundation Models via SwiftAcervo

SwiftProyecto v3.6.0 replaces SwiftBruja with Apple's `FoundationModels` framework. The `proyecto` CLI downloads Qwen2.5 7B via SwiftAcervo CDN, then uses Foundation Models for zero-network inference:

```
proyecto CLI
  ├─ FoundationModels (Apple framework) - LLM inference
  ├─ SwiftAcervo (CDN model management) - Qwen2.5 model downloads
  └─ UNIVERSAL (YAML parser) - PROJECT.md parsing
```

### Canonical Model Configuration

The canonical language model is defined in `ModelManager.swift`:

```swift
// Sources/SwiftProyecto/Infrastructure/ModelManager.swift

/// The canonical model for PROJECT.md generation across SwiftProyecto.
public let LanguageModel = ComponentDescriptor(
  id: "qwen2.5-7b-instruct-4bit",
  type: .languageModel,
  displayName: "Qwen2.5 7B Instruct (4-bit)",
  repoId: "mlx-community/Qwen2.5-7B-Instruct-4bit",
  minimumMemoryBytes: 4_000_000_000,
  metadata: [
    "quantization": "4-bit",
    "context_length": "131072",
    "architecture": "Qwen2.5",
    "version": "2.5",
    "parameters": "7B",
  ]
)
```

**Model Selection Rationale**:
- **Qwen2.5 7B**: Excellent instruction following, minimal hallucination, 128K context
- **4-bit quantization**: ~4GB download, practical for CDN distribution
- **Foundation Models compatible**: Native support for on-device inference via Apple's framework

### Download & Inference Workflow

When `proyecto init` or `proyecto download` runs:

```
1. Initialize ModelManager
   └─ Registers LanguageModel descriptor with SwiftAcervo

2. Call Acervo.ensureComponentReady(LanguageModel.id)
   ├─ Check if model cached locally
   ├─ Download from CDN if needed (parallel file transfer)
   ├─ Verify SHA-256 checksums
   └─ Return model directory

3. Load model with Foundation Models
   └─ LanguageModelSession(model: url) — zero-network inference
   └─ Prompt streaming with cancellation support

4. Stream responses for iterative generation
   └─ One LLM query per PROJECT.md section
```

### Integration Points

**IterativeProjectGenerator** (`Sources/proyecto/IterativeProjectGenerator.swift`):
```swift
import FoundationModels

class IterativeProjectGenerator {
  func generate(for directory: URL, progressHandler: ...) async throws -> ProjectFrontMatter {
    let context = try await directoryAnalyzer.analyze(directory)
    
    for section in ProjectSection.allCases {
      let systemPrompt = section.systemPrompt(for: context, previousResults: results)
      let userPrompt = section.userPrompt(for: context)
      
      // Query Foundation Models for this section
      let response = try await queryFoundationModel(
        userPrompt: userPrompt,
        systemPrompt: systemPrompt,
        maxTokens: 16_384
      )
      // Process response...
    }
  }
  
  private func queryFoundationModel(
    userPrompt: String,
    systemPrompt: String,
    maxTokens: Int
  ) async throws -> String {
    let model = try await LanguageModelSession(
      model: LanguageModel  // Qwen2.5 7B descriptor
    )
    
    let params = LanguageModelSession.RequestParameters(
      systemPrompt: systemPrompt,
      temperature: 0.3,
      topK: 40,
      topP: 0.8,
      maxTokens: maxTokens
    )
    
    let response = try await model.complete(prompt: userPrompt, with: params)
    return response
  }
}
```

### Changing the Model

To use a different model, update the `LanguageModel` constant in `ModelManager.swift`:

1. **Update the descriptor**:
   ```swift
   public let LanguageModel = ComponentDescriptor(
     id: "new-model-id",
     displayName: "New Model Name",
     repoId: "org/model-repo",
     minimumMemoryBytes: ...,
     metadata: [...]
   )
   ```

2. **Publish model to CDN** (intrusive-memory team only):
   ```bash
   acervo ship org/model-repo
   ```

3. **Verify with tests**:
   ```bash
   make test
   ```


---

---

## 📦 Extending PROJECT.md with App-Specific Settings

**SwiftProyecto 2.6.0+ supports an extension system** that allows apps to define their own settings sections in PROJECT.md frontmatter without modifying the library.

### Quick Example

```swift
// 1. Define your settings
struct MyAppSettings: AppFrontMatterSettings {
    static let sectionKey = "myapp"
    var theme: String?
    var autoSave: Bool?
}

// 2. Read settings
let (frontMatter, _) = try parser.parse(fileURL: projectURL)
let settings = try frontMatter.settings(for: MyAppSettings.self)

// 3. Write settings
var frontMatter = ProjectFrontMatter(title: "My Project")
try frontMatter.setSettings(MyAppSettings(theme: "dark"))
```

**📖 Complete Guide**: See [**Docs/EXTENDING_PROJECT_MD.md**](Docs/EXTENDING_PROJECT_MD.md) for:
- Step-by-step implementation guide
- Complete examples (podcast app, screenplay tools)
- Best practices and common patterns
- UserDefaults sync, settings migration, multi-app coexistence
- Troubleshooting

**Key Benefits:**
- ✅ Type-safe with Codable
- ✅ No coupling between SwiftProyecto and your app
- ✅ Multiple apps can store settings in same PROJECT.md
- ✅ Backward compatible with existing PROJECT.md files

---

## ⚠️ CRITICAL: Platform Version Enforcement

**This library ONLY supports iOS 26.0+ and macOS 26.0+. NEVER add code that supports older platforms.**

### Rules for Platform Versions

1. **NEVER add `@available` attributes** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `@available(iOS 15.0, macOS 12.0, *)`
   - ✅ CORRECT: No `@available` needed (package enforces iOS 26/macOS 26)

2. **NEVER add `#available` runtime checks** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `if #available(iOS 15.0, *) { ... }`
   - ✅ CORRECT: No runtime checks needed (package enforces minimum versions)

3. **Platform-specific code is OK** (macOS vs iOS differences)
   - ✅ CORRECT: `#if os(macOS)` or `#if canImport(AppKit)`
   - ✅ CORRECT: `#if canImport(UIKit)`
   - ❌ WRONG: Checking for specific OS versions below 26

4. **Package.swift must always specify iOS 26 and macOS 26**
   ```swift
   platforms: [
       .iOS(.v26),
       .macOS(.v26)
   ]
   ```

**DO NOT lower the platform requirements. Apps using this library must update their deployment targets to iOS 26+ and macOS 26+.**

---

## Development Workflow

**⚠️ CRITICAL: See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for complete development workflow.**

This project follows a **strict branch-based workflow**:

### Quick Reference

- **Development branch**: `development` (all work happens here)
- **Main branch**: `main` (protected, PR-only)
- **Workflow**: `development` → PR → CI passes → Merge → Tag → Release
- **NEVER** commit directly to `main`
- **NEVER** delete the `development` branch

### CI/CD Requirements

**Main branch is protected:**
- Direct pushes blocked (PRs only)
- No PR review required
- GitHub Actions must pass before merge:
  - Code Quality: Linting and code checks
  - macOS Unit Tests: Unit tests on macOS
  - Integration Tests: Build CLI binary via `make release`, verify `--version` and `--help`
- Tests run on pull requests and pushes to main

**Development branch is NOT protected:**
- Work happens directly on `development`
- No CI checks required for pushes to `development`
- CI only runs when creating PR from `development` to `main`

**See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for:**
- Complete branch strategy
- Commit message conventions
- PR creation templates
- Tagging and release process
- Version numbering (semver)
- Emergency hotfix procedures

### Branch Protection Configuration

**⚠️ IMPORTANT: When tests are changed or renamed, branch protections must be evaluated.**

The `main` branch has required status checks that must pass before PRs can be merged. These checks are configured in GitHub repository settings and must match the actual CI workflow job names.

**When to Update Branch Protections:**
- ✅ When CI workflow job names change
- ✅ When test jobs are added or removed
- ✅ When platforms are added or removed (iOS, macOS)
- ✅ When test structure is reorganized

**How to Update Branch Protections:**

View current protections:
```bash
gh api repos/intrusive-memory/SwiftProyecto/branches/main/protection/required_status_checks
```

Update required checks:
```bash
gh api --method PATCH repos/intrusive-memory/SwiftProyecto/branches/main/protection/required_status_checks \
  -H "Accept: application/vnd.github.v3+json" \
  --input - <<'EOF'
{
  "strict": true,
  "contexts": [
    "Code Quality",
    "macOS Unit Tests",
    "Integration Tests"
  ]
}
EOF
```

**Best Practices:**
- Keep branch protection checks minimal but essential
- Align check names exactly with CI workflow job names
- Document protection changes in PR descriptions
- Test protection changes by creating a test PR

---

## Core Architecture

### Project Models

**ProjectModel** - SwiftData model representing a screenplay project folder
- Stores PROJECT.md metadata (title, author, season, episodes, etc.)
- References discovered files via `fileReferences` relationship
- Provides file tree building via `fileTree()` method
- Manages security-scoped bookmark for project folder

**ProjectFileReference** - SwiftData model for discovered files
- Tracks file metadata (path, name, extension, modification date)
- Optional security-scoped bookmark for file-level access
- No relationship to document models (apps manage that)

**ProjectFrontMatter** - Codable struct for PROJECT.md metadata
- YAML front matter representation
- Required fields: type, title, author, created
- Optional metadata fields: description, season, episodes, genre, tags
- Optional generation config: episodesDir, audioDir, filePattern, exportFormat
- Optional cast list: cast (array of CastMember for character-to-voice mappings)
- Optional hooks: preGenerateHook, postGenerateHook
- Convenience accessors: resolvedEpisodesDir, resolvedAudioDir, resolvedFilePatterns, resolvedExportFormat

**Gender** - Gender specification for character roles
- Enum values: `.male` (M), `.female` (F), `.nonBinary` (NB), `.notSpecified` (NS)
- Used to specify expected or preferred gender for character roles
- `.notSpecified` indicates role doesn't depend on character's gender
- Codable with raw string values for PROJECT.md YAML
- Display names: "Male", "Female", "Non-Binary", "Not Specified"

**CastMember** - Character-to-voice mapping for audio generation
- Maps screenplay characters to actors and TTS voice URIs
- Fields: character (String), actor (String?), gender (Gender?), voiceDescription (String?), voices ([String: String])
- Voice format: Key/value pairs where key is provider name, value is voice identifier
  - Examples:
    - `apple: com.apple.voice.compact.en-US.Samantha` (Apple TTS)
    - `elevenlabs: 21m00Tcm4TlvDq8ikWAM` (ElevenLabs)
    - `voxalta: female-voice-1` (VoxAlta)
- **voiceDescription** (v2.5.0+): Optional description of desired voice characteristics for TTS voice selection
  - Used by CastMatcher in SwiftHablare to guide intelligent voice selection
  - Example: "Deep, warm baritone with measured pacing and gravitas"
- Stored inline in PROJECT.md cast array
- Identity based on character name (mutable for renaming)
- Voice resolution: Appropriate voice is selected based on enabled TTS provider
- No validation of voice identifiers in model - validation happens at generation time

**FilePattern** - Flexible file pattern type for generation config
- Accepts single string or array of strings
- Normalizes to array via `.patterns` property
- Supports glob patterns (e.g., "*.fountain") and explicit file lists
- Codable with automatic string/array detection

**AppFrontMatterSettings** - Protocol for app-specific settings extension (v2.6.0+)
- Defines contract for type-safe, namespaced settings in PROJECT.md
- Requires `sectionKey` static property for YAML section name
- Conforms to Codable and Sendable
- Apps implement this protocol to define their own settings
- Settings stored in dedicated YAML section (e.g., `myapp:`)
- See [Docs/EXTENDING_PROJECT_MD.md](../Docs/EXTENDING_PROJECT_MD.md) for complete guide

**AnyCodable** - Type-erased wrapper for Codable values (v2.6.0+)
- Internal utility for storing app settings without SwiftProyecto knowing their types
- Wraps any Codable value while preserving encoding/decoding
- Used by ProjectFrontMatter to store app-specific settings
- Not exposed in public API (apps use generic `settings(for:)` methods)

**FileNode** - Hierarchical tree structure for file navigation
- Built from flat ProjectFileReference array
- Supports folders and files
- Used for navigation UIs (OutlineGroup, List, etc.)

### Audio Generation Models

**ParseBatchArguments** - CLI batch-level flags for audio generation
- Raw command-line arguments for processing multiple files
- Fields: projectPath, output, format, skipExisting, resumeFrom, regenerate, skipHooks, useCastList, castListPath, dryRun, failFast, verbose, quiet, jsonOutput
- Validation: Checks for mutually exclusive flags
- Merged with PROJECT.md metadata to create ParseBatchConfig

**ParseBatchConfig** - Resolved batch configuration from PROJECT.md + CLI overrides
- Combines ProjectFrontMatter defaults with ParseBatchArguments overrides
- Contains discovered episode files (discoveredFiles: [URL])
- Provides iterator: `makeIterator() -> ParseFileIterator`
- Factory methods: `from(projectPath:args:)` (static) or `ProjectModel.parseBatchConfig(with:)` (extension)
- Includes hooks (preGenerateHook, postGenerateHook) and filter flags

**ParseFileIterator** - Iterator yielding ParseCommandArguments for each file
- Implements IteratorProtocol and Sequence
- Applies filters during initialization (resumeFrom) and iteration (skipExisting)
- Yields one ParseCommandArguments per discovered file
- Methods: `next() -> ParseCommandArguments?`, `collect() -> [ParseCommandArguments]`
- Properties: `totalCount`, `currentFileIndex`

**ParseCommandArguments** - Single-file generation arguments
- Command arguments for generating audio from ONE screenplay file
- Fields: episodeFileURL, outputURL, exportFormat, castListURL, useCastList, verbose, quiet, dryRun
- Validation: File existence, mutually exclusive flags, cast list requirements
- This is what the `generate` command accepts as input

### Services

**ProjectService** - Main service for project operations (@MainActor)
- **File Discovery**: `discoverFiles(for:allowedExtensions:)`
- **Project Management**: `createProject(at:title:author:...)`, `openProject(at:)`
- **Bookmark Management**: `getSecureURL(for:in:)`, `refreshBookmark(for:in:)`, `createFileBookmark(for:in:)`
- **PROJECT.md**: Reads/writes project metadata files
- **Cast List Discovery**: `discoverCastList(for:)` - Automatically extracts CHARACTER elements from .fountain files
- **Cast List Merging**: `mergeCastLists(discovered:existing:)` - Merges discovered characters with existing cast, preserving user edits

**ModelContainerFactory** - SwiftData container creation
- Creates containers for project metadata only
- Schema: `ProjectModel`, `ProjectFileReference`
- Supports both app-wide and project-local storage

**FileSource Protocol** - Abstraction for file discovery
- Protocol for discovering files from different source types
- Implementations: `DirectoryFileSource`, `GitRepositoryFileSource`
- Handles file enumeration, filtering, and metadata extraction
- ProjectService delegates discovery to FileSource implementations

**DirectoryFileSource** - Local directory file discovery
- Discovers files in a local directory recursively
- Excludes system files (.DS_Store, Thumbs.db, etc.)
- Excludes build artifacts (.build, .cache, DerivedData)
- Excludes PROJECT.md from file listings

**GitRepositoryFileSource** - Git repository file discovery
- Extends DirectoryFileSource with git repository validation
- Validates `.git/` directory exists
- Same exclusion patterns as DirectoryFileSource
- Does NOT perform git operations (use git library for that)

**ProjectMarkdownParser** - YAML front matter parser using UNIVERSAL
- Parses PROJECT.md files with YAML front matter (delimited by `---`)
- Generates PROJECT.md content from ProjectFrontMatter
- Uses UNIVERSAL library for spec-compliant YAML parsing
- Properly handles quoted strings, colons in values, complex arrays, and ISO8601 dates
- Supports lazy loading: parse PROJECT.md only when needed
- Two parsing methods: `parse(fileURL:)` and `parse(content:)`
- Returns tuple of `(ProjectFrontMatter, String)` - front matter and body content

**BookmarkManager** - Security-scoped bookmark utilities
- Cross-platform (macOS/iOS)
- Handles bookmark creation, resolution, refresh
- Platform-specific: macOS uses `.withSecurityScope`, iOS uses `.minimalBookmark`

### proyecto CLI Components (v2.2.0+)

**DirectoryAnalyzer** - Analyzes project directories for LLM context
- Gathers file listings, README content, git author, directory structure
- Executes once per project analysis, result reused for all LLM queries
- Returns `DirectoryContext` with all analyzed information

**ProjectSection** - Enum defining metadata sections for iterative generation
- 8 sections: title, author, description, genre, tags, season, episodes, config
- Each section has focused prompt templates tailored to specific metadata
- Sections build on previous results (e.g., description uses title)

**IterativeProjectGenerator** - Orchestrates sequential LLM queries
- Queries LLM 8 times with focused prompts (one per section)
- Provides progress callbacks for UI feedback
- Handles response parsing and validation
- Assembles final `ProjectFrontMatter` from individual section results
- Robust error handling with section-specific retry capability

### PROJECT.md Parsing Pattern

SwiftProyecto uses **lazy loading** for PROJECT.md parsing. Metadata is only parsed when needed:

```swift
// 1. Parse PROJECT.md from file URL
let parser = ProjectMarkdownParser()
let (frontMatter, body) = try parser.parse(fileURL: projectURL.appendingPathComponent("PROJECT.md"))

// 2. Or parse from string content (for in-memory operations)
let content = """
---
type: project
title: My Series
author: Jane Doe
created: 2025-11-17T10:30:00Z
season: 1
episodes: 12
genre: Science Fiction
tags: [sci-fi, drama]
episodesDir: scripts
audioDir: output
filePattern: "*.fountain"
exportFormat: m4a
cast:
  - character: NARRATOR
    actor: Tom Stovall
    voiceDescription: "Deep, warm baritone with measured pacing and gravitas"
    voices:
      apple: com.apple.voice.compact.en-US.Aaron
      elevenlabs: 21m00Tcm4TlvDq8ikWAM
  - character: LAO TZU
    actor: Jason Manino
    voiceDescription: "Wise, contemplative voice with subtle Eastern accent"
    voices:
      voxalta: narrative-1
preGenerateHook: "./scripts/prepare.sh"
postGenerateHook: "./scripts/upload.sh"
---

# Production Notes
Additional notes here...
"""
let (frontMatter, body) = try parser.parse(content: content)

// 3. Access front matter fields
print(frontMatter.title)       // "My Series"
print(frontMatter.author)      // "Jane Doe"
print(frontMatter.season)      // Optional(1)
print(frontMatter.episodes)    // Optional(12)
print(frontMatter.tags)        // Optional(["sci-fi", "drama"])
print(body)                    // "# Production Notes\nAdditional notes here..."

// 4. Access generation config with defaults
print(frontMatter.resolvedEpisodesDir)   // "scripts" (or "episodes" if nil)
print(frontMatter.resolvedAudioDir)      // "output" (or "audio" if nil)
print(frontMatter.resolvedFilePatterns)  // ["*.fountain"]
print(frontMatter.resolvedExportFormat)  // "m4a"
print(frontMatter.preGenerateHook)       // Optional("./scripts/prepare.sh")

// 5. Generate PROJECT.md content
let newFrontMatter = ProjectFrontMatter(
    title: "New Project",
    author: "John Writer",
    season: 2,
    episodes: 10,
    episodesDir: "episodes",
    audioDir: "audio",
    filePattern: .multiple(["*.fountain", "*.fdx"]),
    exportFormat: "m4a"
)
let markdown = parser.generate(frontMatter: newFrontMatter, body: "# Notes")
// Produces valid PROJECT.md with YAML front matter
```

**Key Points**:
- **Lazy**: PROJECT.md is only parsed when you call `parse()`, not automatically on project open
- **Stateless**: ProjectMarkdownParser is a stateless utility - no caching, just pure parsing
- **YAML Front Matter**: Must be delimited by `---` markers
- **Required Fields**: `type`, `title`, `author`, `created` (validated during parsing)
- **Optional Metadata Fields**: `description`, `season`, `episodes`, `genre`, `tags`
- **Optional Generation Config**: `episodesDir`, `audioDir`, `filePattern`, `exportFormat`
- **Optional Hooks**: `preGenerateHook`, `postGenerateHook`
- **Date Format**: ISO8601 format for `created` field (e.g., `2025-11-17T10:30:00Z`)
- **Error Handling**: Throws `ProjectMarkdownParser.ParserError` with detailed error messages
- **Backward Compatible**: All new fields are optional with sensible defaults

### File Discovery Pattern

SwiftProyecto discovers files and parses PROJECT.md metadata but does NOT load screenplay documents:

```swift
// 1. Open/create project (automatically parses PROJECT.md)
let projectService = ProjectService(modelContext: context)
let project = try await projectService.openProject(at: folderURL)
// Project metadata is now available (title, author, season, etc.)

// 2. Discover files (lazy - call when needed)
try await projectService.discoverFiles(for: project)

// 3. Access PROJECT.md metadata (already parsed during openProject)
print(project.title)       // From PROJECT.md front matter
print(project.author)      // From PROJECT.md front matter
print(project.season)      // Optional field

// 4. Get security-scoped URL for a screenplay file
let fileRef = project.fileReferences.first!
let url = try projectService.getSecureURL(for: fileRef, in: project)

// 5. App parses screenplay file (using SwiftCompartido or other parser)
let parsed = try await GuionParsedElementCollection(file: url.path)

// 6. App stores document (apps manage integration)
let document = await GuionDocumentModel.from(parsed, in: context)

// 7. (Optional) Manually parse or regenerate PROJECT.md
let parser = ProjectMarkdownParser()
let projectMdURL = folderURL.appendingPathComponent("PROJECT.md")
let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)
```

### Cast List Discovery Pattern

SwiftProyecto can automatically discover characters from .fountain files and generate cast list entries:

```swift
import SwiftProyecto

// 1. Discover characters from all .fountain files in project
let projectService = ProjectService(modelContext: context)
let project = try await projectService.openProject(at: folderURL)

let discoveredCast = try await projectService.discoverCastList(for: project)
// Returns: [CastMember(character: "NARRATOR"), CastMember(character: "LAO TZU")]
// All actor and voices fields are nil/empty - user fills these in manually

// 2. Merge with existing cast list (preserves user edits)
let parser = ProjectMarkdownParser()
let (frontMatter, body) = try parser.parse(fileURL: folderURL.appendingPathComponent("PROJECT.md"))

let existingCast = frontMatter.cast ?? []
let mergedCast = projectService.mergeCastLists(
    discovered: discoveredCast,
    existing: existingCast
)
// Existing actor/voice assignments are preserved
// New characters are added with empty actor/voices
// Old characters not in .fountain files are preserved

// 3. Update PROJECT.md with merged cast
let updatedFrontMatter = ProjectFrontMatter(
    title: frontMatter.title,
    author: frontMatter.author,
    created: frontMatter.created,
    cast: mergedCast
    // ... other fields
)
let updatedMarkdown = parser.generate(frontMatter: updatedFrontMatter, body: body)
try updatedMarkdown.write(
    to: folderURL.appendingPathComponent("PROJECT.md"),
    atomically: true,
    encoding: .utf8
)
```

**Character Extraction Rules**:
- Extracts all-uppercase lines from .fountain files
- Removes parentheticals like `(V.O.)`, `(CONT'D)`, `(O.S.)`
- Ignores transitions (lines ending with `TO:`)
- Ignores scene headings (`INT.`, `EXT.`, `EST.`)
- Deduplicates across all files in project
- Returns sorted by character name

**Merge Strategy**:
- Characters in both lists: Keep existing actor/voices (preserves user edits)
- Characters only in discovered: Add as new (empty actor/voices)
- Characters only in existing: Keep (user may have manually added)

**Voice URI Format**: `<providerId>://<voiceId>?lang=<languageCode>`

Follows [SwiftHablare VoiceURI specification](https://github.com/intrusive-memory/SwiftHablare):

| Provider | Key | Voice ID Format | Example Voice ID |
|----------|-----|-----------------|------------------|
| Apple TTS | `apple` | `com.apple.voice.{quality}.{locale}.{VoiceName}` | `com.apple.voice.compact.en-US.Samantha` |
| ElevenLabs | `elevenlabs` | Unique voice ID (alphanumeric) | `21m00Tcm4TlvDq8ikWAM` |
| VoxAlta | `voxalta` | Voice name or ID | `female-voice-1` |

### Audio Generation Iterator Pattern

SwiftProyecto provides an iterator pattern for batch audio generation from PROJECT.md configuration:

```swift
import SwiftProyecto

// 1. Create batch configuration from PROJECT.md
let projectPath = "/Users/username/Projects/podcast-meditations"
let args = ParseBatchArguments(
    projectPath: projectPath,
    format: "m4a",
    skipExisting: true,
    verbose: true
)

// Parse PROJECT.md and discover episode files
let batchConfig = try ParseBatchConfig.from(projectPath: projectPath, args: args)

print("Project: \(batchConfig.title)")
print("Author: \(batchConfig.author)")
print("Discovered \(batchConfig.discoveredFiles.count) episode files")

// 2. Create iterator to yield per-file generation arguments
var iterator = batchConfig.makeIterator()

// 3. Iterate over each episode file
while let commandArgs = iterator.next() {
    print("\nProcessing: \(commandArgs.episodeFileURL.lastPathComponent)")
    print("  Input:  \(commandArgs.episodeFileURL.path)")
    print("  Output: \(commandArgs.outputURL.path)")
    print("  Format: \(commandArgs.exportFormat)")

    if let castListURL = commandArgs.castListURL {
        print("  Cast List: \(castListURL.path)")
    }

    // Validate arguments before generation
    try commandArgs.validate()

    if commandArgs.dryRun {
        print("  [DRY RUN] Skipping actual generation")
        continue
    }

    if commandArgs.outputExists && batchConfig.skipExisting {
        print("  [SKIP] Output file already exists")
        continue
    }

    // 4. Pass commandArgs to your audio generation function
    // try await generateAudio(with: commandArgs)
}

print("\nProcessed \(iterator.currentFileIndex) of \(iterator.totalCount) files")
```

**Alternative: Using ProjectModel**

If you already have a SwiftData `ProjectModel` instance, use the extension method:

```swift
import SwiftProyecto

// 1. Open project with ProjectService
let projectService = ProjectService(modelContext: context)
let project = try await projectService.openProject(at: folderURL)

// 2. Create batch configuration from ProjectModel
let args = ParseBatchArguments(
    projectPath: project.sourceRootURL,
    output: "custom-audio-dir",
    format: "mp3",
    resumeFrom: 10  // Resume from episode 10
)

let batchConfig = try project.parseBatchConfig(with: args)

// 3. Iterate and generate
var iterator = batchConfig.makeIterator()
while let commandArgs = iterator.next() {
    print("Episode: \(commandArgs.episodeFileURL.lastPathComponent)")
    // Process file...
}
```

**Collect All Arguments**

To get all `ParseCommandArguments` as an array without iterating:

```swift
var iterator = batchConfig.makeIterator()
let allArgs = iterator.collect()

print("Total files to process: \(allArgs.count)")

for (index, args) in allArgs.enumerated() {
    print("\(index + 1). \(args.episodeFileURL.lastPathComponent) → \(args.outputURL.lastPathComponent)")
}
```

**Iterator Behavior**:
- **resumeFrom**: Skips first N files during iterator initialization
- **skipExisting**: Skips files during iteration if output exists (unless `regenerate` is true)
- **regenerate**: Ignores `skipExisting` filter, processes all files
- **Filters are applied automatically**: No need to check manually

**Configuration Priority**:
1. CLI arguments (`ParseBatchArguments`) - highest priority
2. PROJECT.md front matter (`ProjectFrontMatter`) - default values
3. Built-in defaults (`episodesDir: "episodes"`, `audioDir: "audio"`, `exportFormat: "m4a"`)

---

## Dependencies

**Current (v3.6.0)**:
- **UNIVERSAL** (5.3.0+): Zero-dependency YAML/JSON/XML parser for PROJECT.md parsing
  - Spec-compliant YAML parsing with quoted strings, colons, complex arrays, ISO8601 dates
  - Used by ProjectMarkdownParser
- **SwiftAcervo** (0.16.0+): Component descriptor validation and CDN-based model distribution
  - Manages Qwen2.5 7B model downloads and SHA-256 verification
  - Local model caching for all intrusive-memory tools
  - Used by `proyecto download` and `proyecto init` commands
- **FoundationModels** (Apple framework): On-device LLM inference
  - Zero-network inference after model download
  - Part of macOS 26.0+, iOS 26.0+ platform SDK (no separate dependency)
  - Used by `proyecto init` for iterative PROJECT.md generation
- **swift-argument-parser** (1.7.1+): CLI argument parsing for the `proyecto` executable

**Removed** (v3.6.0):
- ~~SwiftBruja~~ - Replaced with Foundation Models
- ~~MLX dependency~~ - Foundation Models provides native support
- ~~SwiftCompartido~~ - Apps integrate directly (removed in v2.0)
- ~~GRMustache.swift~~ - Template rendering removed in v2.0

---

## Integration with Apps

### Recommended Pattern

Apps should create an integration layer (e.g., `DocumentRegistry` in Produciesta) that links SwiftProyecto files to SwiftCompartido documents:

```swift
@Model
class DocumentRegistry {
    var projectID: UUID?
    var fileReferenceID: UUID?
    var fileURL: URL
    @Relationship var document: GuionDocumentModel?
}

// Usage
let url = try projectService.getSecureURL(for: fileRef, in: project)
let parsed = try await GuionParsedElementCollection(file: url.path)
let document = await GuionDocumentModel.from(parsed, in: context)

let registry = DocumentRegistry(
    fileURL: url,
    projectID: project.id,
    fileReferenceID: fileRef.id,
    document: document
)
context.insert(registry)
```

**Note**: The refactoring to remove document loading from SwiftProyecto is complete. Apps should implement their own DocumentRegistry pattern to link ProjectFileReference with parsed documents.

---

## Important Notes

- This library is **Apple Silicon-only** (arm64)
- Requires macOS 26.0+ or iOS 26.0+
- All files use security-scoped bookmarks for sandboxed access
- SwiftData models use cascade delete for cleanup
- Library is **standalone** - no dependency on SwiftCompartido

---

## Building

The `proyecto` CLI can be built with standard Swift tools:

### Build Commands

```bash
# Build and install proyecto CLI to ./bin (Debug)
make install

# Build and install proyecto CLI to ./bin (Release)
make release

# Swift Package build (fast, library + CLI)
make build

# Run tests
make test

# Clean all build artifacts
make clean

# Show all available targets
make help
```

### Swift Package vs. Xcode

Both are supported:

**Swift Package Manager**:
```bash
swift build -c release
# Binary: .build/release/proyecto
```

**Xcode**:
```bash
xcodebuild -scheme proyecto -destination 'platform=macOS,arch=arm64' build
# Binary: ~/Library/Developer/Xcode/DerivedData/SwiftProyecto-*/Build/Products/Release/proyecto
```

Foundation Models framework is available on macOS 26.0+ and iOS 26.0+, so no special build steps or shaders are required.

---

## proyecto CLI

The `proyecto` CLI uses local LLM inference (via Foundation Models) to analyze directories and generate PROJECT.md files with appropriate metadata.

### Installation

The CLI can be installed via Homebrew or built from source:

**Homebrew (Recommended):**
```bash
brew tap intrusive-memory/tap
brew install proyecto
proyecto --version
```

**Build from Source:**
```bash
make install  # Debug build
make release  # Release build
./bin/proyecto --version
```

### Commands

#### `proyecto init` (default)

Analyzes a directory and generates PROJECT.md metadata using local LLM inference.

```bash
# Analyze current directory
proyecto init

# Analyze specific directory
proyecto init /path/to/podcast

# Override author field
proyecto init --author "Jane Doe"

# Update existing PROJECT.md (preserves created, body, hooks)
proyecto init --update

# Force overwrite existing PROJECT.md
proyecto init --force

# Quiet mode
proyecto init --quiet
```

**Options:**
- `directory` (argument): Directory to analyze (default: current directory)
- `--author`: Override the author field (skip LLM detection)
- `--update`: Update existing PROJECT.md, preserving created date, body content, and hooks
- `--force`: Completely overwrite existing PROJECT.md
- `--quiet, -q`: Suppress progress output

**Model**: Uses the canonical Qwen2.5 7B Instruct model defined in `ModelManager.swift`. To use a different model, update the `LanguageModel` constant and rebuild the CLI.

**Behavior with existing PROJECT.md:**
- Default: Error if PROJECT.md exists (prevents accidental overwrites)
- `--force`: Completely replace existing PROJECT.md
- `--update`: Preserve created date, body content, and hooks; update other fields

#### `proyecto download`

Downloads the Qwen2.5 7B LLM model from SwiftAcervo CDN for local inference. Model is cached locally for use by `proyecto init` and all projects using Foundation Models.

```bash
# Download Qwen2.5 7B model from CDN
proyecto download

# Force re-download (validates and re-downloads all files)
proyecto download --force

# Quiet mode (suppress progress)
proyecto download --quiet
```

**Options:**
- `--force`: Force re-download even if model exists, verifying all checksums
- `--quiet, -q`: Suppress progress output

**Model Details:**
- **Name**: Qwen2.5 7B Instruct (4-bit quantized)
- **Size**: ~4 GB
- **Location**: Managed by SwiftAcervo (typically `~/Library/Group Containers/group.intrusive-memory.models/SharedModels/mlx-community_Qwen2.5-7B-Instruct-4bit/`)
- **Checksum Verification**: All files verified with SHA-256 after download
- **Capability**: 128K context window, excellent instruction following, minimal hallucination

**Note**: The model is downloaded from SwiftAcervo CDN (Cloudflare R2) for reliable validation and checksumming.

### Iterative LLM Architecture (v3.6.0+)

The `proyecto init` command uses an **iterative LLM approach** with 8 focused queries via Foundation Models:

**Components:**
- **DirectoryContext** - Gathers directory analysis once, reused for all queries
- **ProjectSection** - Enum defining 8 sections with focused prompt templates
- **IterativeProjectGenerator** - Orchestrates sequential Foundation Models queries with progress feedback
- **FoundationModels** - Apple's on-device LLM framework (zero network, after model download)

**Sections Queried (in order):**
1. **Title** - Analyzes folder name, files, README for project title
2. **Author** - Checks git config, README, file metadata for author
3. **Description** - Generates 1-2 sentence description based on title and structure
4. **Genre** - Categorizes project (Philosophy, Education, Drama, Sci-Fi, etc.)
5. **Tags** - Generates 3-5 relevant tags based on title, description, genre
6. **Season** - Detects season numbers from folder/file patterns
7. **Episodes** - Counts episode files (*.fountain, *.fdx, etc.)
8. **Config** - Suggests episodesDir, audioDir, filePattern, exportFormat

**Benefits:**
- Smaller, focused prompts improve LLM accuracy
- Real-time progress visibility (`[Title] ✓ Title: My Project`)
- Better fault tolerance (retry individual sections)
- Context building (later sections reference earlier results)
- Successfully handles large projects (tested with 366 episodes)

**Example Output:**
```
[Title] Analyzing directory structure...
[Title] Querying LLM for Title...
[Title] ✓ Title: Space Exploration Podcast
[Author] Using author override: Tom Stovall
[Description] Querying LLM for Description...
[Description] ✓ Description: A science fiction podcast series...
[Genre] ✓ Genre: Science Fiction
[Tags] ✓ Tags: space, sci-fi, podcast, adventure
[Season] ✓ Season: 1
[Episodes] ✓ Episodes: 12
[Generation Config] ✓ Generation Config: episodesDir=episodes...
```

---

## PROJECT.md Modification Rules

### Single Source of Truth

**SwiftProyecto is the ONLY package that should modify PROJECT.md files.**

Other projects (Produciesta, podcast generators, etc.) must use SwiftProyecto's API for all PROJECT.md operations.

### Finding PROJECT.md

Use `ProjectDiscovery` service:

```swift
import SwiftProyecto

let discovery = ProjectDiscovery()
if let projectMdURL = discovery.findProjectMd(from: screenplayURL) {
    // Found PROJECT.md
}
```

**Search Logic**:
1. If screenplay is in "episodes" folder -> check parent directory first
2. Check current directory
3. Check parent directory (fallback)

### Reading PROJECT.md

```swift
let parser = ProjectMarkdownParser()
let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)

// Access data
let title = frontMatter.title
let cast = frontMatter.cast
```

### Reading Cast from PROJECT.md

```swift
let discovery = ProjectDiscovery()
if let projectMd = discovery.findProjectMd(from: screenplayURL) {
    // Read all cast members
    let allCast = try discovery.readCast(from: projectMd)

    // Read only Apple voices
    let appleCast = try discovery.readCast(from: projectMd, filterByProvider: "apple")
}
```

### Writing PROJECT.md

**CORRECT (Use SwiftProyecto API)**:

```swift
// Modify front matter (in-memory)
let updatedFrontMatter = frontMatter.mergingCast(newCast, forProvider: "apple")

// Write using SwiftProyecto
let parser = ProjectMarkdownParser()
try parser.write(frontMatter: updatedFrontMatter, body: body, to: projectMdURL)
```

**WRONG (Direct File I/O)**:

```swift
// NEVER DO THIS
let content = parser.generate(frontMatter: updatedFrontMatter, body: body)
try content.write(to: projectMdURL, atomically: true, encoding: .utf8)
```

### Cast Merging - Preserving Other Providers

**CRITICAL**: When updating cast voices for a specific provider, you MUST preserve voices for other providers.

```swift
// CORRECT: Merge cast for current provider only
let updatedFrontMatter = frontMatter.mergingCast(newCast, forProvider: "apple")

// WRONG: Replaces entire cast (loses other provider voices)
let updatedFrontMatter = frontMatter.withCast(newCast)
```

**Example**:
```yaml
# Before: Has ElevenLabs voice
cast:
  - character: NARRATOR
    voices:
      elevenlabs: 21m00Tcm4TlvDq8ikWAM

# After mergingCast with Apple provider: Preserves ElevenLabs, adds Apple
cast:
  - character: NARRATOR
    voices:
      apple: com.apple.voice.premium.en-US.Aaron
      elevenlabs: 21m00Tcm4TlvDq8ikWAM
```

### Why These Rules Matter

1. **Format consistency** - YAML serialization handled uniformly
2. **Validation** - SwiftProyecto validates before writing
3. **Atomic writes** - Prevents file corruption
4. **Future evolution** - Format can change without breaking clients
5. **Data loss prevention** - Cast merging preserves all provider voices

### Ownership Clarification

**SwiftProyecto owns**:
- PROJECT.md file format specification
- Parsing and serialization logic
- File I/O operations (read, write, atomic writes)
- Discovery and location logic (findProjectMd)

**Client projects (Produciesta, etc.) own**:
- When to read/write PROJECT.md (business logic)
- What data to store (cast assignments, preferences)
- UI for editing metadata
- Integration with their own data models (SwiftData, etc.)

**Services like ProjectMdSyncService**: These are **allowed** in client projects - they coordinate WHEN to call SwiftProyecto's API based on business logic (e.g., "sync cast when voice assignment changes").

---

## Related Projects

- **SwiftCompartido**: Screenplay parsing and SwiftData document models
- **SwiftHablare**: TTS and voice provider integration
- **Produciesta**: macOS/iOS application integrating these libraries


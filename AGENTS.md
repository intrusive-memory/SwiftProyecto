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
- ✅ Extracts cast lists from screenplay files (all supported formats via SwiftCompartido)

**What SwiftProyecto Does NOT Do**:
- ❌ Parse full screenplay content (dialogue, action, structure) — apps use SwiftCompartido directly
- ❌ Render or generate content (provides metadata to renderers)
- ❌ Store screenplay document models (apps handle integration via SwiftCompartido)
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

## 🚀 Generating PROJECT.md with LLM Backends (v4.1.0+)

**SwiftProyecto v4.1.0 introduces automated PROJECT.md generation using LLM backends.**

### Overview

The `proyecto generate-project` command analyzes a project directory structure and generates a valid v4.x PROJECT.md file using available LLM backends. This enables AI agents to understand projects in a single pass without manual metadata curation.

**What it does:**
- Analyzes directory structure, discovers files, extracts cast names from scripts
- Generates PROJECT.md with inferred title, author, description, genre, tags, and cast list
- Validates generated content against v4.x schema
- Outputs to stdout, interactive review, or direct file write (with automatic backup)

**Why it matters:**
- Eliminates manual PROJECT.md creation for new projects
- Reduces time for AI agents to understand project composition
- Enables batch project processing in CI/CD pipelines
- Fallback chain ensures generation works across platforms

### Backend Availability

`proyecto generate-project` uses a **priority-ordered fallback chain** to select the best available LLM backend:

| Priority | Backend | Availability | When Used |
|----------|---------|--------------|-----------|
| 1 | **SwiftBruja** | When linked to proyecto CLI | Local inference, fastest |
| 2 | **Apple Foundation Models** | macOS 27+ only | Native on-device inference |
| 3 | **Claude API** (fallback) | Requires `CLAUDE_API_KEY` | Network-based, always available |

**How it works:**
1. Tries SwiftBruja if available
2. If SwiftBruja fails or unavailable, tries Foundation Models (macOS 27+ only)
3. If both fail or unavailable, uses Claude API
4. Fails with error if no backends are available

### Command Usage

#### Basic Syntax

```bash
proyecto generate-project [OPTIONS] [DIRECTORY]
```

**Arguments:**
- `DIRECTORY`: Path to project directory to analyze (default: current directory `.`)

#### Common Usage Patterns

**1. Dry-Run Preview (default)**
```bash
# Preview generated PROJECT.md without writing to disk
proyecto generate-project /path/to/project

# Shows output in terminal, suggests how to write if needed
```

**2. Interactive Review**
```bash
# Display generated content and prompt for confirmation
proyecto generate-project /path/to/project --interactive

# You'll see:
#   - Generated PROJECT.md in terminal
#   - "Confirm to proceed? (yes/no):" prompt
#   - Writes file only if you answer "yes"
```

**3. Force Overwrite (with backup)**
```bash
# Overwrite existing PROJECT.md without confirmation
proyecto generate-project /path/to/project --force

# Creates PROJECT.md.bak before writing
# Validates content before write
```

**4. Specific Backend Selection**
```bash
# Use Claude API backend explicitly
proyecto generate-project /path/to/project --llm claude --force

# Use Foundation Models backend (macOS 27+)
proyecto generate-project /path/to/project --llm fm --force

# Use SwiftBruja backend (if available)
proyecto generate-project /path/to/project --llm bruja --force
```

**5. Custom Claude Model**
```bash
# Use a specific Claude model (default: claude-3-5-sonnet-20241022)
proyecto generate-project /path/to/project --llm claude --model claude-3-opus-20250219 --force
```

**6. Quiet Mode (CI/CD)**
```bash
# Suppress progress output for automated workflows
proyecto generate-project /path/to/project --quiet --force

# Only output errors (if any)
```

**7. Verbose Output (Debugging)**
```bash
# Show detailed analysis and extraction information
proyecto generate-project /path/to/project --verbose --dry-run

# Displays:
#   - Cast members extracted: N
#   - Episode pattern: <detected pattern>
#   - Full generated PROJECT.md
```

### Option Reference

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--dry-run` | | enabled | Output to stdout, no disk write |
| `--interactive` | | disabled | Show generated content, prompt for confirmation |
| `--force` | | disabled | Overwrite existing PROJECT.md without confirmation |
| `--llm NAME` | | auto | Select backend: `claude`, `fm`, or `bruja` |
| `--model NAME` | | `claude-3-5-sonnet-20241022` | Claude model to use (Claude API backend only) |
| `--quiet` | `-q` | disabled | Suppress progress output |
| `--verbose` | `-v` | disabled | Show detailed analysis and output |

**Flag Combinations:**
- `--dry-run` and `--force` are mutually exclusive
- `--interactive` and `--force` are mutually exclusive
- `--quiet` suppresses progress but still shows errors

### Generated PROJECT.md Structure

The command generates valid v4.x PROJECT.md with YAML front matter:

```yaml
---
type: project
title: Inferred Project Title
author: Inferred Author Name
created: 2025-06-23T14:30:00Z
description: Inferred project description based on directory analysis
genre: Inferred Genre (e.g., Podcast, Drama, Comedy)
tags: [tag1, tag2, tag3]
seasons:
  - number: 1
    episodes: Inferred episode count
cast:
  - character: CHARACTER_NAME
    actor: Actor/Performer Name
    voiceProvider: apple
    voiceId: com.apple.voice.compact.en-US.Aaron
    voiceDescription: Voice description for TTS provider selection
  # ... more cast members
---

# Project Metadata

Generated metadata summary and project notes.
```

**Generated Fields:**
- ✅ `type`: Always `"project"`
- ✅ `title`: Inferred from directory name or README content
- ✅ `author`: Inferred from git config or file metadata
- ✅ `created`: Timestamp when PROJECT.md is generated
- ✅ `description`: Inferred from README or file content
- ✅ `genre`: Inferred from file patterns and content analysis
- ✅ `tags`: Inferred categories (e.g., podcast, audio, drama)
- ✅ `seasons`: Array with detected episode count
- ✅ `cast`: Extracted character names with voice provider suggestions

**Not Generated (Manual):**
- `episodesDir`, `audioDir`, `filePattern`, `exportFormat` (inferred in future versions)
- `preGenerateHook`, `postGenerateHook` (project-specific, not auto-generated)
- Voice IDs and detailed cast descriptions (user must review and complete)

### Error Handling

**Common Errors and Solutions:**

#### 1. Directory Not Found
```
Error: Directory not found: /nonexistent/path
```
**Solution**: Verify the path exists and is a directory.

#### 2. PROJECT.md Already Exists
```
Error: PROJECT.md already exists at /path/to/project/PROJECT.md
Use --force to overwrite, --interactive to review, or --dry-run to preview
```
**Solution:** Choose one of:
- `--dry-run`: Preview before making changes
- `--interactive`: Review and confirm before writing
- `--force`: Overwrite existing file (creates .bak backup)

#### 3. Invalid Backend Name
```
Error: Invalid backend 'xyz'
Valid options: claude, fm, bruja
```
**Solution**: Use one of the valid backend names: `claude`, `fm`, or `bruja`.

#### 4. Backend Unavailable
```
Error: Backend 'Apple Foundation Models' is not available
Backend is not available on this system
```
**Solutions:**
- For FM: Ensure you're on macOS 27 or later
- For Claude API: Set `CLAUDE_API_KEY` environment variable
- Use `--llm claude` to fallback to Claude API

#### 5. Generation Failed
```
Error: Failed to generate metadata: <backend error details>
```
**Solutions:**
- Verify directory is a valid project (has screenplay files: .fountain, .fdx, .highland, README, etc.)
- Check backend logs: `--verbose --dry-run` for details
- Try a different backend: `--llm claude`
- Check network connectivity (Claude API backend only)

#### 6. Schema Validation Error
```
Error: Schema validation error: Generated PROJECT.md failed validation: <details>
```
**Solutions:**
- This is rare - indicates a backend bug
- Report with `--verbose` output
- Try a different backend: `--llm claude`

### Use Cases

#### Use Case 1: Preview Before Committing

```bash
cd ~/Projects/my-podcast-series
proyecto generate-project --dry-run

# Review output in terminal
# If acceptable: proyecto generate-project --force
```

#### Use Case 2: Interactive Review with Editing

```bash
proyecto generate-project . --interactive

# Shows generated metadata
# Prompts "Confirm to proceed? (yes/no): "
# User reviews and answers
```

#### Use Case 3: Automated CI/CD Pipeline

```bash
#!/bin/bash
set -e

# Generate PROJECT.md in CI/CD with automatic backend selection
proyecto generate-project . \
  --force \
  --quiet \
  --verbose

# Optional: Validate generated file
proyecto validate PROJECT.md
```

#### Use Case 4: Batch Processing Multiple Projects

```bash
#!/bin/bash

for project_dir in projects/*/; do
  echo "Generating PROJECT.md for $project_dir"
  proyecto generate-project "$project_dir" \
    --force \
    --quiet \
    --llm claude  # Use Claude API for consistency
done
```

### Directory Analysis

Before generation, the command analyzes the project directory:

**Cast Extraction:**
- Discovers screenplay files (`.fountain`, `.fdx`, `.highland`)
- Extracts character names using format-specific parsers (SwiftCompartido)
- Removes parentheticals and non-character lines
- Deduplicates across all files and formats
- Returns sorted list

**Episode Pattern Detection:**
- Looks for numbered file patterns: `s01e01`, `ep001`, `episode_1`, etc.
- Counts matching files
- Infers season/episode structure
- Handles multi-season projects

**Metadata Inference:**
- Reads README.md or similar documentation
- Inspects git author information
- Analyzes file types and structure
- Infers project type (podcast, screenplay, etc.)

### Integration with Agents

**For AI Agents:**

Use the fallback chain via `ProjectGeneratorService` in code:

```swift
import SwiftProyecto

let service = ProjectGeneratorService()
let analysis = ProjectService.analyzeForGeneration(at: projectURL)
let metadata = try await service.generate(project: analysis)

// metadata is ready for ProjectFrontMatter conversion
```

**Check available backends:**

```swift
let backends = BackendRegistry.shared.availableBackends()
for backend in backends {
  print("Available: \(backend.backendName)")
}
```

**Use specific backend:**

```swift
if let backend = BackendRegistry.shared.backend(named: "Claude API") {
  let metadata = try await backend.generate(project: analysis)
}
```

### Limitations & Caveats

- **Cast Accuracy**: Typical ≥80% accuracy for cast extraction (manual review recommended)
- **Metadata Inference**: Generated descriptions may be generic; manual refinement suggested
- **Schema Validation**: All generated content is validated, but fields are optional - may need completion
- **Voice Providers**: Voice IDs are suggested but must be verified for correctness
- **Language Detection**: Limited detection for multi-language projects (manual override recommended)
- **Backend Performance**: Generation time varies by backend (SwiftBruja fastest, Claude API may have latency)
- **API Rate Limits**: Claude API backend respects rate limits (may fail during high volume)

### Best Practices

1. **Always use `--dry-run` first** to preview before committing
2. **Review cast extraction** - manual verification ensures voice assignment correctness
3. **Validate generated schema** - use `proyecto validate PROJECT.md` after generation
4. **Use `--force` with `--quiet`** only in trusted CI/CD pipelines
5. **Prefer SwiftBruja/FM** for speed; use Claude API as fallback
6. **Test with `--verbose`** to debug directory analysis issues
7. **Create backups** - `--force` creates `.bak` files automatically
8. **Commit generated PROJECT.md** - include in version control for project reproducibility

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
- **Cast List Discovery**: `discoverCastList(for:)` - Automatically extracts characters from all screenplay formats (.fountain, .fdx, .highland)
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

### LLM Backend Services (v4.1.0+) — For Agents

**LLMBackendProtocol** - Abstract protocol for LLM backends
- All backends conform to this protocol
- Required properties: `backendName`, `isAvailable`
- Core method: `generate(project: ProjectAnalysis) async throws -> ProjectMetadata`
- Implementors: SwiftBruja, Apple Foundation Models, Claude API

**ProjectGeneratorService** - High-level generation service
- Singleton at `ProjectGeneratorService.default`
- Implements **priority-ordered fallback chain**:
  1. SwiftBruja (fastest if available)
  2. Apple Foundation Models (macOS 27+ only)
  3. Claude API (always available with CLAUDE_API_KEY)
- Core method: `generate(project: ProjectAnalysis) async throws -> ProjectMetadata`
- Convenience method: `generateFrom(projectPath: URL) async throws -> ProjectMetadata`
- Thread-safe for concurrent use

**BackendRegistry** - Backend discovery and management
- Singleton at `BackendRegistry.shared`
- Backends auto-register at initialization
- Key methods:
  - `availableBackends()` - Returns only backends where `isAvailable == true`
  - `backend(named:)` - Get backend by name (first match, availability-aware)
  - `allBackends()` - For debugging (includes unavailable backends)

**ProjectAnalysis** - Input data structure for backends
- `projectPath: URL` - Project directory location
- `discoveredFiles: [String]` - File names found in directory
- `extractedCast: [String]` - Character names from scripts
- `episodePattern: String?` - Detected episode numbering pattern
- `inferredTitle: String?` - Detected project title
- `detectedLanguages: [String]` - Languages found in project

**ProjectMetadata** - Output data structure from backends
- `title: String` - Project title
- `author: String` - Project creator
- `description: String?` - Project description
- `created: Date` - Generation timestamp
- `type: String` - Project type (usually "project")
- `episodes: Int?` - Episode count
- `season: Int?` - Season number
- `genre: String?` - Genre classification
- `tags: [String]` - Categorization tags
- `ttsProvider: String?` - TTS recommendation
- `cast: [CastMemberData]` - Character list with voices

**LLMBackendError** - Error types from backends
- `.unavailable(reason:)` - Backend not available on this system
- `.generationFailed(reason:)` - LLM generation error
- `.invalidInput(reason:)` - Bad input to backend

**Example: Using ProjectGeneratorService in an Agent**

```swift
import SwiftProyecto

// 1. Analyze project directory
guard let analysis = ProjectService.analyzeForGeneration(at: projectURL) else {
  throw LLMBackendError.invalidInput(reason: "Cannot analyze directory")
}

// 2. Generate using fallback chain
let service = ProjectGeneratorService()
let metadata = try await service.generate(project: analysis)

// 3. Convert to ProjectFrontMatter
let frontMatter = ProjectFrontMatter(
  type: metadata.type,
  title: metadata.title,
  author: metadata.author,
  created: metadata.created,
  description: metadata.description,
  season: metadata.season,
  episodes: metadata.episodes,
  genre: metadata.genre,
  tags: metadata.tags
)

// 4. Write to PROJECT.md
let parser = ProjectMarkdownParser()
let content = parser.generate(frontMatter: frontMatter, body: "")
try content.write(to: projectURL.appendingPathComponent("PROJECT.md"), atomically: true, encoding: .utf8)
```

**Example: Selecting a Specific Backend**

```swift
// Check available backends
let available = BackendRegistry.shared.availableBackends()
print("Available backends: \(available.map { $0.backendName }.joined(separator: ", "))")

// Use specific backend
if let claudeBackend = BackendRegistry.shared.backend(named: "Claude API") {
  let metadata = try await claudeBackend.generate(project: analysis)
} else {
  print("Claude API not available - check CLAUDE_API_KEY")
}

// Use Foundation Models (macOS 27+ only)
if let fmBackend = BackendRegistry.shared.backend(named: "Apple Foundation Models") {
  let metadata = try await fmBackend.generate(project: analysis)
}
```

**Backend Availability Guide for Agents**

| Backend | Name | Availability Check | When to Use |
|---------|------|-------------------|------------|
| SwiftBruja | `"SwiftBruja"` | `backend(named:) != nil` | Local inference, fastest |
| Foundation Models | `"Apple Foundation Models"` | macOS 27+ check | On-device, native Apple API |
| Claude API | `"Claude API"` | `CLAUDE_API_KEY` env var set | Fallback, network-based |

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

## Screenplay Format Support

SwiftProyecto's cast extraction supports three screenplay formats:

- **Fountain** (`.fountain`): Plain-text screenplay format
- **Final Draft** (`.fdx`): XML-based screenplay format (Final Draft 8+)
- **Highland** (`.highland`): ZIP-based screenplay format (TextBundle)

### Format Detection

File format is automatically detected from file extension. The underlying parsing is delegated to **SwiftCompartido**, a robust, format-agnostic screenplay parser library that handles format-specific parsing, character extraction, and scene analysis.

### CastExtractor API

The `CastExtractor` class provides two methods for character extraction:

1. **From text** (`extractCast(from fountainText:)`) — assumes Fountain format, suitable for in-memory text
2. **From file** (`extractCast(from fileURL:)`) — auto-detects format by extension

Both methods return a sorted, deduplicated array of character names (uppercase).

```swift
import SwiftProyecto
import SwiftCompartido

let extractor = CastExtractor()

// Extract from Fountain text
let cast = try extractor.extractCast(from: fountainText)
// Returns: ["NARRATOR", "LAO TZU", "CONFUCIUS"]

// Extract from file (auto-detects format)
let cast = try extractor.extractCast(from: URL(fileURLWithPath: "screenplay.fdx"))
// Same result regardless of format
```

### Error Handling

- **Unsupported format** — throws `CastExtractionError.unsupportedFormat` for unknown extensions
- **Parse failure** — Fountain files fall back to regex extraction; other formats throw error
- **Empty cast** — Returns empty array (not an error)

### RolesCommand

The `proyecto roles` command discovers and extracts characters from all three screenplay formats recursively:

```bash
# Discover .fountain, .fdx, .highland files and extract characters
proyecto roles                      

# Process FDX files matching glob pattern
proyecto roles episodes/*.fdx       

# Process single Highland file
proyecto roles screenplay.highland  

# Verbose output showing format detection
proyecto roles --verbose            
```

**Output Format**:
```
Project: My Screenplay Series
Total characters: 42

Format Summary:
  .fountain files: 12 (324 characters extracted)
  .fdx files: 8 (287 characters extracted)
  .highland files: 5 (156 characters extracted)

Characters (deduplicated, sorted):
  1. ADVISOR
  2. ASTROLOGIST
  3. BAKER
  ...
```

### Dependency

Cast extraction relies on **SwiftCompartido** (v7.2.1+), which provides:
- Robust parsing for all three screenplay formats
- Consistent character extraction across formats
- Format auto-detection by file extension
- Comprehensive error handling
- Support for character alternatives and variations

---

### Cast List Discovery Pattern

SwiftProyecto can automatically discover characters from screenplay files (all supported formats) and generate cast list entries:

```swift
import SwiftProyecto

// 1. Discover characters from all screenplay files in project
// (supports .fountain, .fdx, .highland formats)
let projectService = ProjectService(modelContext: context)
let project = try await projectService.openProject(at: folderURL)

let discoveredCast = try await projectService.discoverCastList(for: project)
// Returns: [CastMember(character: "NARRATOR"), CastMember(character: "LAO TZU")]
// All actor and voices fields are nil/empty - user fills these in manually
// Format auto-detected for each file discovered

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
// Old characters not in any screenplay files are preserved

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
- Supports all three screenplay formats (.fountain, .fdx, .highland)
- Format-specific parsing delegated to SwiftCompartido
- Removes parentheticals like `(V.O.)`, `(CONT'D)`, `(O.S.)` (format-aware)
- Ignores non-character lines (transitions, scene headings, action)
- Deduplicates across all files and formats in project
- Returns sorted by character name (uppercase)
- Handles character alternatives and variations consistently

**Merge Strategy**:
- Characters in both lists: Keep existing actor/voices (preserves user edits)
- Characters only in discovered: Add as new (empty actor/voices)
- Characters only in existing: Keep (user may have manually added characters not in screenplay files)

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

**Current (v4.2.0+)**:
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
- **SwiftCompartido** (7.2.1+): Format-agnostic screenplay parsing
  - Supports Fountain (.fountain), Final Draft (.fdx), and Highland (.highland) formats
  - Character extraction and screenplay analysis
  - Used by CastExtractor and `proyecto roles` command
- **swift-argument-parser** (1.7.1+): CLI argument parsing for the `proyecto` executable

**Removed** (v3.6.0):
- ~~SwiftBruja~~ - Replaced with Foundation Models
- ~~MLX dependency~~ - Foundation Models provides native support
- ~~GRMustache.swift~~ - Template rendering removed in v2.0

**Restored** (v4.2.0+):
- **SwiftCompartido** - Re-added for format-agnostic screenplay parsing (previously removed in v2.0)

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

#### `proyecto roles`

Discovers and extracts character lists from screenplay files in a project. Supports all three screenplay formats (.fountain, .fdx, .highland) with format auto-detection.

```bash
# Extract characters from all screenplay files in current directory
proyecto roles

# Extract from specific directory
proyecto roles /path/to/project

# Process specific files or patterns
proyecto roles episodes/*.fdx
proyecto roles screenplay.highland

# Show per-format breakdown
proyecto roles --verbose

# Quiet mode (minimal output)
proyecto roles --quiet
```

**Options:**
- `directory` (argument): Project directory or file pattern (default: current directory)
- `--verbose, -v`: Show format-specific extraction details
- `--quiet, -q`: Suppress progress output

**Output:**
```
Project: My Screenplay Series
Total characters: 42

Format Summary:
  .fountain files: 12
  .fdx files: 8
  .highland files: 5

Characters (sorted):
  1. ADVISOR
  2. ASTROLOGIST
  3. BAKER
  ...
```

**Related**: See [Screenplay Format Support](#screenplay-format-support) section for detailed format specifications and integration examples.

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


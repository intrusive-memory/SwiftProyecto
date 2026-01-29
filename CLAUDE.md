# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftProyecto is a Swift package for **file discovery and project metadata management** in screenplay applications. It provides:
- Project folder management and file discovery
- PROJECT.md metadata parsing and generation
- Security-scoped bookmark handling
- File tree building for navigation UIs

**What SwiftProyecto Does**:
- ✅ Discovers screenplay files in folders/git repos
- ✅ Manages PROJECT.md metadata
- ✅ Provides security-scoped URLs for file access
- ✅ Builds hierarchical file trees

**What SwiftProyecto Does NOT Do**:
- ❌ Parse screenplay files (use SwiftCompartido)
- ❌ Store document models (apps handle integration)
- ❌ Display UI (provides data only)

**Platforms**: iOS 26.0+, macOS 26.0+

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

**CastMember** - Character-to-voice mapping for audio generation
- Maps screenplay characters to actors and TTS voice URIs
- Fields: character (String), actor (String?), voices ([String])
- Voice URI format: `<providerId>://<voiceId>?lang=<languageCode>` (follows SwiftHablare VoiceURI spec)
  - Examples:
    - `apple://com.apple.voice.compact.en-US.Samantha?lang=en` (Apple TTS)
    - `elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en` (ElevenLabs)
    - `qwen-tts://female-voice-1?lang=en` (Qwen TTS)
- Stored inline in PROJECT.md cast array
- Identity based on character name (mutable for renaming)
- Voice resolution: First matching enabled provider is used, falls back to default if none match
- No validation of voice URIs in model - validation happens at generation time

**FilePattern** - Flexible file pattern type for generation config
- Accepts single string or array of strings
- Normalizes to array via `.patterns` property
- Supports glob patterns (e.g., "*.fountain") and explicit file lists
- Codable with automatic string/array detection

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
    voices:
      - apple://en-US/Aaron
      - elevenlabs://en/wise-elder
  - character: LAO TZU
    actor: Jason Manino
    voices:
      - qwen://en/narrative-1
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

| Provider | providerId | Voice ID Format | Example |
|----------|-----------|-----------------|---------|
| Apple TTS | `apple` | `com.apple.voice.{quality}.{locale}.{VoiceName}` | `apple://com.apple.voice.compact.en-US.Samantha?lang=en` |
| ElevenLabs | `elevenlabs` | Unique voice ID (alphanumeric) | `elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en` |
| Qwen TTS | `qwen-tts` | Voice name or ID | `qwen-tts://female-voice-1?lang=en` |

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

**Current**:
- **UNIVERSAL** (from 5.0.5): Zero-dependency YAML/JSON/XML parser for PROJECT.md parsing
  - Spec-compliant YAML parsing
  - Handles quoted strings, colons in values, complex arrays
  - Used by ProjectMarkdownParser
- **SwiftBruja** (branch: main): On-device LLM inference for PROJECT.md generation
  - Used by the `proyecto` CLI for AI-powered metadata generation
- **swift-argument-parser** (from 1.3.0): CLI argument parsing for the `proyecto` executable

**Removed** (v2.0+):
- ~~SwiftCompartido~~ - Apps integrate directly
- ~~GRMustache.swift~~ - Template rendering was never used, removed in v2.0

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

See `.claude/REFACTORING_PLAN.md` for complete Produciesta integration guide.

---

## Important Notes

- This library is **Apple Silicon-only** (arm64)
- Requires macOS 26.0+ or iOS 26.0+
- All files use security-scoped bookmarks for sandboxed access
- SwiftData models use cascade delete for cleanup
- Library is **standalone** - no dependency on SwiftCompartido

---

## Building

**CRITICAL: Use the correct xcodebuild destination for macOS 26 on Apple Silicon.**

```bash
# Build and install proyecto CLI to ./bin (Debug, with Metal shaders)
make install

# Build and install proyecto CLI to ./bin (Release, with Metal shaders)
make release

# Development build only (swift build - fast but no Metal shaders)
make build

# Run tests
make test

# Clean all build artifacts
make clean

# Show all available targets
make help
```

**Manual xcodebuild (if not using Makefile):**
```bash
# MUST use this exact destination string for macOS 26 Apple Silicon:
xcodebuild -scheme proyecto -destination 'platform=macOS,arch=arm64' build
```

**Destination String:**
- ✅ CORRECT: `'platform=macOS,arch=arm64'`
- ❌ WRONG: `'platform=OS X'` (legacy, doesn't specify architecture)
- ❌ WRONG: `'platform=macOS'` (missing architecture)

---

## proyecto CLI

The `proyecto` CLI uses local LLM inference (via SwiftBruja) to analyze directories and generate PROJECT.md files with appropriate metadata.

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
make install  # Debug build with Metal shaders
make release  # Release build with Metal shaders
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

# Use specific model
proyecto init --model ~/Models/Phi-3

# Update existing PROJECT.md (preserves created, body, hooks)
proyecto init --update

# Force overwrite existing PROJECT.md
proyecto init --force

# Quiet mode
proyecto init --quiet
```

**Options:**
- `directory` (argument): Directory to analyze (default: current directory)
- `--model`: Model path or HuggingFace ID (default: mlx-community/Phi-3-mini-4k-instruct-4bit)
- `--author`: Override the author field (skip LLM detection)
- `--update`: Update existing PROJECT.md, preserving created date, body content, and hooks
- `--force`: Completely overwrite existing PROJECT.md
- `--quiet, -q`: Suppress progress output

**Behavior with existing PROJECT.md:**
- Default: Error if PROJECT.md exists (prevents accidental overwrites)
- `--force`: Completely replace existing PROJECT.md
- `--update`: Preserve created date, body content, and hooks; update other fields

#### `proyecto download`

Downloads an LLM model from HuggingFace for local inference.

```bash
# Download default model
proyecto download

# Download specific model
proyecto download --model "mlx-community/Llama-3-8B"

# Force re-download
proyecto download --force
```

**Options:**
- `--model`: HuggingFace model ID (default: mlx-community/Phi-3-mini-4k-instruct-4bit)
- `--force`: Re-download even if model exists
- `--quiet, -q`: Suppress progress output

### Iterative LLM Architecture (v2.2.0+)

The `proyecto init` command uses an **iterative LLM approach** with 8 focused queries instead of one large request:

**Components:**
- **DirectoryContext** - Gathers directory analysis once, reused for all queries
- **ProjectSection** - Enum defining 8 sections with focused prompt templates
- **IterativeProjectGenerator** - Orchestrates sequential LLM queries with progress feedback

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

## Related Projects

- **SwiftCompartido**: Screenplay parsing and SwiftData document models
- **SwiftHablare**: TTS and voice provider integration
- **Produciesta**: macOS/iOS application integrating these libraries


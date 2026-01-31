# Claude-Specific Agent Instructions

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation.

This file contains instructions specific to Claude Code agents working on SwiftProyecto.

---

## Quick Reference

**Project**: SwiftProyecto - Swift package for extensible, agentic discovery of content projects
**Purpose**: Enables AI agents to understand content projects in a single pass via PROJECT.md metadata
**Platforms**: iOS 26.0+, macOS 26.0+
**Current Version**: 3.0.0

**Universal Documentation**: See [AGENTS.md](AGENTS.md) for:
- Product overview and architecture
- Core models and services
- Integration patterns
- Dependencies and related projects
- proyecto CLI documentation

---

## Claude-Specific Build Preferences

### CRITICAL: Use xcodebuild for Swift Projects

**ALWAYS use `xcodebuild` instead of `swift build` or `swift test`** for building and testing Swift packages and Xcode projects.

**Why xcodebuild over swift build:**
- ✅ Better integration with Xcode toolchain
- ✅ Supports Metal shader compilation (required for proyecto CLI)
- ✅ Proper handling of platform-specific code
- ✅ Compatible with MCP server automation

**Examples:**
```bash
# ❌ DON'T use swift build/test
swift build
swift test

# ✅ DO use xcodebuild (or XcodeBuildMCP tools)
xcodebuild build -scheme SwiftProyecto -destination 'platform=macOS'
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'
```

**For proyecto CLI specifically:**
- MUST use `make install` or `make release` (uses xcodebuild under the hood)
- MUST NOT use `swift build` (Metal shaders won't compile)
- See AGENTS.md § Building for details

---

## MCP Server Configuration

### XcodeBuildMCP

**CRITICAL**: XcodeBuildMCP is installed and should be used for ALL Xcode operations instead of direct `xcodebuild` or `xcrun` commands.

**Available Operations:**
- **Building**: `build_sim`, `build_device`, `build_macos`, `build_run_sim`, `build_run_macos`
- **Testing**: `test_sim`, `test_device`, `test_macos`
- **Swift Packages**: `swift_package_build`, `swift_package_test`, `swift_package_run`, `swift_package_clean`
- **Simulator Management**: `list_sims`, `boot_sim`, `open_sim`, `install_app_sim`, `launch_app_sim`
- **Project Info**: `discover_projs`, `list_schemes`, `show_build_settings`
- **Utilities**: `clean`, `get_app_bundle_id`, `screenshot`, `describe_ui`

**Usage Pattern:**
```swift
// ❌ DON'T use direct xcodebuild
xcodebuild -scheme SwiftProyecto -destination 'platform=macOS' build

// ✅ DO use XcodeBuildMCP tools
// "Build SwiftProyecto package for macOS"
// Tool: swift_package_build with scheme parameter
```

**Benefits:**
- Structured output instead of parsing xcodebuild text
- Built-in error handling and retry logic
- Automatic scheme and destination discovery
- Better CI/CD integration

### App Store Connect MCP

**Available for App Store metrics, TestFlight, and Xcode Cloud CI/CD monitoring.**

**Available Operations:**
- **Apps**: `list_apps`, `get_app` - App metadata
- **Xcode Cloud**: `get_xcode_cloud_summary`, `get_xcode_cloud_workflows`, `get_xcode_cloud_builds` - CI/CD monitoring
- **TestFlight**: `get_testflight_metrics`, `get_beta_testers`
- **Reviews**: `get_customer_reviews`, `get_review_metrics`
- **Financial**: `get_sales_report`, `get_revenue_metrics`

**Usage for SwiftProyecto:**
- Not directly applicable (library, not app)
- Useful for apps that depend on SwiftProyecto (Produciesta, etc.)

---

## Claude-Specific Critical Rules

1. **ALWAYS use XcodeBuildMCP tools** instead of direct `xcodebuild` commands
2. **NEVER use `swift build` or `swift test`** - use `xcodebuild` or XcodeBuildMCP equivalents
3. **Use MCP servers for automation** - Leverage XcodeBuildMCP for all build/test operations
4. **Follow global Claude patterns** - Communication style, security, CI/CD workflows from `~/.claude/CLAUDE.md`

---

## Global Claude Settings

**Your global Claude instructions**: `~/.claude/CLAUDE.md`

**Key patterns from global settings:**
- Communication: Complete candor, flag risks directly
- Security: NEVER expose secrets or environment variables
- Swift Build: ALWAYS use xcodebuild (matches this project's requirements)
- CI/CD: GitHub Actions with macos-26+ runners, iPhone 17/iOS 26.1 simulators
- MCP Servers: XcodeBuildMCP and App Store Connect MCP available

---

## Common Claude-Specific Workflows

### Running Tests

**Using XcodeBuildMCP:**
```
Use swift_package_test tool with:
- scheme: SwiftProyecto
- destination: platform=macOS
```

**Using xcodebuild directly:**
```bash
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'
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
- Fields: character (String), actor (String?), gender (Gender?), voices ([String])
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

**CRITICAL: The `proyecto` CLI MUST be built with `xcodebuild`, NOT `swift build`.**

### Why xcodebuild is Required

The `proyecto` CLI uses **SwiftBruja** for on-device LLM inference, which depends on **MLX** (Apple's ML framework). MLX requires **Metal shaders** to be compiled into a `.metallib` bundle (`mlx-swift_Cmlx.bundle`).

- ✅ **xcodebuild**: Compiles Metal shaders + creates `.bundle` → CLI works
- ❌ **swift build**: No Metal shader compilation → CLI fails with `MLX error: Failed to load the default metallib`

### Build Commands

**Using Makefile (recommended):**
```bash
# Build and install proyecto CLI to ./bin (Debug, with Metal shaders)
make install

# Build and install proyecto CLI to ./bin (Release, with Metal shaders)
make release

# Development build only (swift build - fast but NO Metal shaders)
# ⚠️ WARNING: Binary will NOT work for LLM features
make build

# Run tests (library tests only, no LLM)
make test

# Clean all build artifacts
make clean

# Show all available targets
make help
```

### Manual xcodebuild (if not using Makefile)

**CRITICAL: Use the correct destination string for macOS 26 on Apple Silicon.**

```bash
xcodebuild -scheme proyecto -destination 'platform=macOS,arch=arm64' build

# Find the built binary and Metal bundle:
# Binary: ~/Library/Developer/Xcode/DerivedData/SwiftProyecto-*/Build/Products/Debug/proyecto
# Bundle: ~/Library/Developer/Xcode/DerivedData/SwiftProyecto-*/Build/Products/Debug/mlx-swift_Cmlx.bundle
```

### Creating a Release

Follow the ship-swift-library skill workflow:
1. Version bump on development
2. Run `/organize-agent-docs` (this skill)
3. Update README.md
4. Merge PR to main
5. Tag on main
6. Create GitHub release

See [AGENTS.md § Development Workflow](.AGENTS.md#development-workflow) for complete git workflow.

**Metal Bundle:**
The `mlx-swift_Cmlx.bundle` must be copied alongside the `proyecto` binary for the CLI to work. The Makefile handles this automatically (lines 30-32, 50-52 in Makefile).

---

**Last Updated**: 2026-02-14 (v3.0.0)

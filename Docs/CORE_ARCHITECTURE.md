---
type: reference
name: Core Architecture
description: Data models, services, and internal architecture
---

# Core Architecture

## Project Models

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
- **voiceDescription**: Optional description of desired voice characteristics for TTS voice selection
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

**AppFrontMatterSettings** - Protocol for app-specific settings extension
- Defines contract for type-safe, namespaced settings in PROJECT.md
- Requires `sectionKey` static property for YAML section name
- Conforms to Codable and Sendable
- Apps implement this protocol to define their own settings
- Settings stored in dedicated YAML section (e.g., `myapp:`)
- See [Docs/EXTENDING_PROJECT_MD.md](EXTENDING_PROJECT_MD.md) for complete guide

**AnyCodable** - Type-erased wrapper for Codable values
- Internal utility for storing app settings without SwiftProyecto knowing their types
- Wraps any Codable value while preserving encoding/decoding
- Used by ProjectFrontMatter to store app-specific settings
- Not exposed in public API (apps use generic `settings(for:)` methods)

**FileNode** - Hierarchical tree structure for file navigation
- Built from flat ProjectFileReference array
- Supports folders and files
- Used for navigation UIs (OutlineGroup, List, etc.)

## Audio Generation Models

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

## Services

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

## LLM Backend Services

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

| Backend | Name | Availability Check | When to Use |
|---------|------|-------------------|------------|
| SwiftBruja | `"SwiftBruja"` | `backend(named:) != nil` | Local inference, fastest |
| Foundation Models | `"Apple Foundation Models"` | macOS 27+ check | On-device, native Apple API |
| Claude API | `"Claude API"` | `CLAUDE_API_KEY` env var set | Fallback, network-based |

---
type: architecture-reference
name: LLMBackend-Architecture
description: Internal API reference and architecture documentation for v4.1.0 LLM-based PROJECT.md generation
version: 4.1.0
updated: 2026-06-23
---

# LLMBackend Architecture — Internal API Reference & Developer Guide

**For v4.1.0+** — Automated PROJECT.md generation via LLM backends

This document provides:
- ✅ **Internal API Reference** — Complete protocol and service documentation
- ✅ **Architecture & Design Rationale** — Why decisions were made
- ✅ **Testing Guide** — How to test and extend this feature
- ✅ **Contributing Guidelines** — How to add backends or modify behavior

---

## Table of Contents

1. [Internal API Reference](#internal-api-reference)
2. [Architecture & Design Decisions](#architecture--design-decisions)
3. [Data Flow & Pipeline](#data-flow--pipeline)
4. [Testing Guide](#testing-guide)
5. [Contributing Guide](#contributing-guide)
6. [ADR — Architecture Decision Records](#adr--architecture-decision-records)

---

## Internal API Reference

### LLMBackendProtocol

**Location**: `Sources/SwiftProyecto/LLMBackend/LLMBackendProtocol.swift`

Protocol that all LLM backends must conform to. Provides a unified interface for project metadata generation.

#### Definition

```swift
public protocol LLMBackendProtocol: Sendable {
  /// Unique name for this backend (e.g., "Claude API", "Apple Foundation Models").
  var backendName: String { get }

  /// Whether this backend is available for use on the current platform.
  /// Returns false if SDK unavailable, credentials missing, or platform requirements not met.
  var isAvailable: Bool { get }

  /// Generate PROJECT.md metadata from a project analysis.
  func generate(project: ProjectAnalysis) async throws -> ProjectMetadata
}
```

#### Properties

**`backendName: String`**
- Unique, human-readable identifier for the backend
- Used for backend lookup and user-facing error messages
- Examples: `"Claude API"`, `"Apple Foundation Models"`, `"SwiftBruja"`
- Should remain consistent across invocations
- **Thread-safe**: Must be computed or stored safely

**`isAvailable: Bool`**
- Indicates whether the backend can be used on the current platform
- Should return `false` if:
  - Backend SDK/framework is not available
  - Required credentials (API keys) are missing
  - Platform version requirements are not met (e.g., macOS 27+ for Foundation Models)
  - System resources are unavailable
- Checked at each lookup (not cached)
- **Thread-safe**: Must be safe for concurrent access
- **Performance**: Should be fast (availability checks are frequent)

#### Methods

**`generate(project:) async throws -> ProjectMetadata`**
- Core generation method
- **Input**: `ProjectAnalysis` containing directory structure, discovered files, extracted cast
- **Output**: `ProjectMetadata` ready to write to PROJECT.md
- **Throws**: `LLMBackendError` if generation fails
- **Async**: All implementations must be async-safe (use `nonisolated(unsafe)` sparingly)
- **Error Handling**:
  - Throw `.unavailable(reason:)` if backend becomes unavailable during generation
  - Throw `.generationFailed(reason:)` for LLM failures, API errors, or malformed output
  - Throw `.invalidInput(reason:)` if input is invalid or incomplete

#### Error Types

```swift
public enum LLMBackendError: LocalizedError {
  case unavailable(reason: String)       // Backend not available on this platform
  case generationFailed(reason: String)  // LLM generation failed
  case invalidInput(reason: String)      // Invalid input to backend
}
```

#### Implementation Checklist

For a new backend implementation:

- [ ] Conform to `LLMBackendProtocol`
- [ ] Implement `backendName` property (must be unique)
- [ ] Implement `isAvailable` property with platform checks
- [ ] Implement `generate(project:)` method with error handling
- [ ] Mark as `Sendable` (thread-safe)
- [ ] Register in `BackendRegistry` at initialization
- [ ] Write unit tests for availability logic
- [ ] Write integration test with `ProjectAnalysis`
- [ ] Add error handling for all failure modes
- [ ] Document availability requirements and constraints

---

### ProjectAnalysis

**Location**: `Sources/SwiftProyecto/LLMBackend/LLMBackendProtocol.swift`

Input data structure passed to backends during generation.

#### Definition

```swift
public struct ProjectAnalysis: Sendable {
  /// Path to the project directory
  public let projectPath: URL

  /// Files discovered in the project directory (relative paths)
  public let discoveredFiles: [String]

  /// Extracted cast names from scripts
  public let extractedCast: [String]

  /// Inferred episode pattern if detectable (e.g., "episode_\\d+")
  public let episodePattern: String?

  /// Inferred project title if detectable
  public let inferredTitle: String?

  /// Languages detected in project (ISO 639-1 codes, e.g., ["en", "es"])
  public let detectedLanguages: [String]
}
```

#### Fields

**`projectPath: URL`** (required)
- Root directory of the project being analyzed
- Set by directory analysis phase
- Backends may use this for relative file lookups

**`discoveredFiles: [String]`** (optional, default: empty)
- List of file names/paths discovered during directory scan
- Relative to `projectPath`
- Examples: `["episode1.fountain", "es/episode2.fountain", "README.md"]`
- Used for context (backends may reference specific files)

**`extractedCast: [String]`** (optional, default: empty)
- Character names extracted from Fountain scripts
- Extracted via `CastExtractor` from `.fountain` files
- Sorted alphabetically for determinism
- Typical accuracy: ≥80% (manual review recommended)
- May contain duplicates or typos (backend should handle gracefully)

**`episodePattern: String?`** (optional)
- Detected pattern for episode numbering
- Format: regex pattern string (e.g., `"s\\d+e\\d+"`, `"episode_\\d+"`)
- Set by `MetadataExtractor` if pattern found
- Backend should use for episode count inference
- May be `nil` if pattern not detected

**`inferredTitle: String?`** (optional)
- Project title inferred from directory name or metadata
- Generated from directory name by `MetadataExtractor`
- Formatted with proper capitalization
- Backend should use as starting point (may be overridden by LLM)
- Example: `"lingua-matra"` → `"Lingua Matra"`

**`detectedLanguages: [String]`** (optional, default: empty)
- ISO 639-1 language codes detected in directory structure
- Examples: `["en"]`, `["es", "it", "pt"]`
- Detected from language-named subdirectories
- Backend should use for multi-language project detection
- May be incomplete (manual override recommended)

#### Usage in Backends

Backends receive `ProjectAnalysis` and should:

1. **Use as context** — Feed extracted data to LLM prompts
2. **Handle missing data** — Don't crash if fields are `nil` or empty
3. **Combine with LLM inference** — Validate/enhance extracted data via LLM
4. **Return complete ProjectMetadata** — Fill in all fields even if some inputs are missing

#### Example Backend Usage

```swift
// In a backend implementation
func generate(project: ProjectAnalysis) async throws -> ProjectMetadata {
  // Use provided data as context
  let castContext = project.extractedCast.isEmpty
    ? "No cast extracted from scripts"
    : "Cast: \(project.extractedCast.joined(separator: ", "))"

  let titleContext = project.inferredTitle ?? "Unknown Project"

  // Build prompt using analysis
  let prompt = """
  Analyze this project:
  - Path: \(project.projectPath.path)
  - Title: \(titleContext)
  - Cast: \(castContext)
  - Languages: \(project.detectedLanguages.isEmpty ? "Undetected" : project.detectedLanguages.joined(separator: ", "))
  - Episode Pattern: \(project.episodePattern ?? "None detected")
  - Files: \(project.discoveredFiles.count) discovered

  Generate PROJECT.md metadata...
  """

  // Send to LLM, parse response
  let metadata = try await generateViaLLM(prompt)
  return metadata
}
```

---

### ProjectMetadata

**Location**: `Sources/SwiftProyecto/LLMBackend/LLMBackendProtocol.swift`

Output data structure returned by backends.

#### Definition

```swift
public struct ProjectMetadata: Sendable {
  public let title: String                    // Project title
  public let author: String                   // Project author/creator
  public let description: String?             // Project description
  public let created: Date                    // Creation date
  public let type: String                     // Detected project type (default: "project")
  public let episodes: Int?                   // Number of episodes (if applicable)
  public let season: Int?                     // Season number (if applicable)
  public let genre: String?                   // Genre classification
  public let tags: [String]                   // Categorization tags
  public let ttsProvider: String?             // TTS provider configuration
  public let cast: [CastMemberData]           // Cast member list
}
```

#### Fields

**`title: String`** (required)
- Project name/title
- Used in PROJECT.md frontmatter
- Should be user-friendly and descriptive
- Constraint: Non-empty, under 200 characters recommended

**`author: String`** (required)
- Creator/author name
- Set from git config, file metadata, or inferred by LLM
- Used in PROJECT.md frontmatter
- Constraint: Non-empty

**`description: String?`** (optional)
- Project summary/description
- Multi-sentence prose describing project scope and intent
- Used in PROJECT.md frontmatter body
- Recommended: 1-3 sentences
- Can be `nil` if not detectable

**`created: Date`** (required, default: `Date()`)
- Timestamp when PROJECT.md is generated
- Set to current time by backend
- Serialized to ISO 8601 in YAML frontmatter

**`type: String`** (optional, default: `"project"`)
- Project classification
- Examples: `"project"`, `"podcast"`, `"screenplay"`, `"audiobook"`
- Inferred from file types and project structure

**`episodes: Int?`** (optional)
- Number of episodes if this is a episodic project
- Inferred from episode pattern and file count
- Can be `nil` for non-episodic projects
- Constraint: Must be ≥1 if set

**`season: Int?`** (optional)
- Season number if applicable
- Typically `1` for single-season projects
- Can be `nil` if not multi-season
- Note: v4.x uses `seasons[]` array in schema; this field is legacy support

**`genre: String?`** (optional)
- Genre classification
- Examples: `"Comedy"`, `"Drama"`, `"Thriller"`, `"Educational"`
- Inferred from content analysis
- Can be `nil` if not detectable

**`tags: [String]`** (optional, default: empty)
- Categorization tags for project discovery
- Examples: `["podcast", "spanish", "educational", "narrative"]`
- Backend should generate 3-5 relevant tags
- Can be empty if no tags identified
- Constraint: Each tag should be lowercase, single-word or hyphenated

**`ttsProvider: String?`** (optional)
- TTS provider name detected in project
- Examples: `"apple"`, `"google"`, `"aws"`, `"openai"`
- Inferred from configuration files or Fountain metadata
- Used to suggest voice providers for cast
- Can be `nil` if not detectable

**`cast: [CastMemberData]`** (optional, default: empty)
- Character-to-voice mappings
- Should include all extracted cast members
- See `CastMemberData` documentation below
- Can be empty if no cast extracted

#### Schema Validation

All fields must be:
- ✅ Present and non-nil for required fields
- ✅ Valid according to PROJECT.md v4.x schema
- ✅ Serializable to YAML without errors
- ✅ Safe to write to disk without escaping issues

Backends should validate output before returning (optional but recommended).

#### Example Backend Output

```swift
// Typical backend output
let metadata = ProjectMetadata(
  title: "Lingua Matra",
  author: "Educational Collective",
  description: "A Spanish language podcast series for learners, featuring daily vocabulary lessons and cultural insights.",
  created: Date(),
  type: "podcast",
  episodes: 120,
  season: 1,
  genre: "Educational",
  tags: ["podcast", "spanish", "language", "educational"],
  ttsProvider: "apple",
  cast: [
    CastMemberData(
      name: "MAESTRA",
      actor: "Voice Performer 1",
      voiceProvider: "apple",
      voiceId: "com.apple.voice.compact.es-ES.Monica",
      voiceDescription: "Clear, educational voice for instructor role"
    ),
    CastMemberData(
      name: "NARRADOR",
      actor: "Voice Performer 2",
      voiceProvider: "apple",
      voiceId: "com.apple.voice.compact.es-ES.Diego",
      voiceDescription: "Warm, engaging voice for narration"
    )
  ]
)
```

---

### CastMemberData

**Location**: `Sources/SwiftProyecto/LLMBackend/LLMBackendProtocol.swift`

Cast member definition with voice configuration.

#### Definition

```swift
public struct CastMemberData: Sendable {
  public let name: String              // Character name
  public let actor: String?            // Actor/performer name
  public let voiceProvider: String?    // Voice provider (e.g., "apple", "google")
  public let voiceId: String?          // Voice identifier
  public let voiceDescription: String? // Character description for voice selection
}
```

#### Fields

**`name: String`** (required)
- Character name as it appears in scripts
- Should match extracted cast name
- Constraint: Non-empty, typically all-caps (from Fountain scripts)
- Used as key in voice provider lookups

**`actor: String?`** (optional)
- Actor or performer name
- Can be human actor or description ("AI Voice", "TTS")
- Used for credit purposes in PROJECT.md
- Can be `nil` if not specified

**`voiceProvider: String?`** (optional)
- TTS provider name for this character's voice
- Examples: `"apple"`, `"google"`, `"aws"`, `"elevenlabs"`
- Should match one of detected TTS providers
- Can be `nil` if provider not determined
- **Note**: Must be a valid provider key recognized by SwiftProyecto

**`voiceId: String?`** (optional)
- Voice identifier within the provider's catalog
- Format varies by provider:
  - Apple: `"com.apple.voice.compact.en-US.Aaron"`
  - Google: `"en-US-Journey-D"`
  - AWS: `"Joanna"`
- Used for actual voice selection during generation
- Can be `nil` (user must select manually)
- **Warning**: Must be validated against provider's available voices

**`voiceDescription: String?`** (optional)
- Human-readable description for this voice choice
- Examples: `"Clear, professional voice for instructor"`, `"Warm, engaging narrator"`
- Used to explain voice selection rationale
- Helps users verify voice appropriateness
- Can be `nil` if no description available

#### Validation Rules

- `name` must always be present and non-empty
- `voiceProvider` and `voiceId` should be consistent (both present or both nil)
- If `voiceProvider` is set, it should be a recognized provider
- `voiceDescription` should be 1-2 sentences
- Multiple cast members can share same `voiceProvider`

#### Example

```swift
// Typical cast member from backend
CastMemberData(
  name: "MAESTRA",
  actor: nil,
  voiceProvider: "apple",
  voiceId: "com.apple.voice.compact.es-ES.Monica",
  voiceDescription: "Clear, Spanish voice for instructor role"
)
```

---

### BackendRegistry

**Location**: `Sources/SwiftProyecto/LLMBackend/BackendRegistry.swift`

Singleton registry for discovering and managing available LLM backends.

#### Definition

```swift
public final class BackendRegistry: @unchecked Sendable {
  /// Shared singleton instance
  public static let shared = BackendRegistry()

  /// Register a backend with the registry
  public func register(_ backend: LLMBackendProtocol)

  /// Get all available backends
  public func availableBackends() -> [LLMBackendProtocol]

  /// Get a backend by name
  public func backend(named name: String) -> LLMBackendProtocol?

  /// Get all registered backends (including unavailable)
  public func allBackends() -> [LLMBackendProtocol]
}
```

#### Pattern: Singleton

- Access via `BackendRegistry.shared`
- Single global instance shared across application
- Initialized on first access
- Thread-safe (uses `NSLock` for synchronization)

#### Thread-Safety

- ✅ All methods are thread-safe
- ✅ Multiple threads can call `register()`, `backend(named:)`, etc. concurrently
- ✅ Uses lock-based synchronization internally
- ✅ Safe for concurrent access from async contexts

#### Methods

**`register(_ backend: LLMBackendProtocol)`**
- Registers a backend for later discovery
- Typically called at app initialization
- Duplicates allowed (multiple backends with same name can be registered)
- Thread-safe
- Time complexity: O(1)

**`availableBackends() -> [LLMBackendProtocol]`**
- Returns all registered backends where `isAvailable == true`
- Ordered by registration order
- Empty array if no backends available
- Time complexity: O(n) where n = number of registered backends
- Used by `ProjectGeneratorService` for fallback chain

**`backend(named name: String) -> LLMBackendProtocol?`**
- Returns first available backend matching `backendName`
- Returns `nil` if:
  - No backend registered with this name
  - All backends with this name are unavailable
- Time complexity: O(n)
- Used by CLI for `--llm` flag backend selection

**`allBackends() -> [LLMBackendProtocol]`**
- Returns all registered backends, including unavailable ones
- Primarily for testing and debugging
- Shows which backends are registered but not available
- Time complexity: O(n)

#### Usage Pattern

```swift
// Registration (typically at app startup)
let registry = BackendRegistry.shared
registry.register(ClaudeAPIBackend())
registry.register(AppleFoundationModelsBackend())
registry.register(SwiftBrujaBackend())

// Discovery
let available = registry.availableBackends()  // Only available backends
for backend in available {
  print("Available: \(backend.backendName)")
}

// Lookup by name
if let backend = registry.backend(named: "Claude API") {
  let metadata = try await backend.generate(project: analysis)
}
```

#### Internal Implementation Details

- **Storage**: Stored in mutable array `backends`
- **Synchronization**: Uses `NSLock` with helper `withLock(_:)` method
- **Availability Checking**: Checked at lookup time (not cached) to handle dynamic availability changes
- **No deduplication**: Duplicate registrations are allowed (for flexibility)

---

### ProjectGeneratorService

**Location**: `Sources/SwiftProyecto/LLMBackend/ProjectGeneratorService.swift`

High-level service orchestrating PROJECT.md generation via fallback chain.

#### Definition

```swift
public final class ProjectGeneratorService: @unchecked Sendable {
  /// Shared singleton instance
  public static let `default` = ProjectGeneratorService()

  /// Initialize with a registry
  public init(registry: BackendRegistry = .shared)

  /// Generate metadata using fallback chain
  public func generate(project: ProjectAnalysis) async throws -> ProjectMetadata

  /// Analyze and generate in one call
  public func generateFrom(projectPath: URL) async throws -> ProjectMetadata
}
```

#### Fallback Chain Strategy

Implements priority-ordered backend selection:

```
1. SwiftBruja (if available)
   ↓ fails or unavailable
2. Apple Foundation Models (if available & macOS 27+)
   ↓ fails or unavailable
3. Claude API (fallback, always attempt)
   ↓ fails
4. Throw LLMBackendError.unavailable
```

**Rationale**: Prefer local inference (SwiftBruja/FM) for speed and privacy; fall back to Claude API for reliability.

#### Methods

**`generate(project: ProjectAnalysis) async throws -> ProjectMetadata`**

Main generation method.

- **Input**: `ProjectAnalysis` with directory structure and metadata
- **Output**: `ProjectMetadata` ready to write
- **Throws**:
  - `LLMBackendError.unavailable(reason:)` — No backends available
  - `LLMBackendError.generationFailed(reason:)` — All backends tried and failed
- **Async**: Safe to call from async contexts
- **Behavior**:
  1. Try backend priority 1 (SwiftBruja) if available
  2. Try backend priority 2 (FM, macOS 27+ only) if priority 1 fails
  3. Try backend priority 3 (Claude API) if priority 2 fails
  4. Throw error if priority 3 fails

**Example Usage**

```swift
let service = ProjectGeneratorService()
let analysis = ProjectAnalysis(
  projectPath: URL(fileURLWithPath: "/path/to/project"),
  extractedCast: ["MAESTRA", "NARRADOR"],
  inferredTitle: "Lingua Matra"
)

do {
  let metadata = try await service.generate(project: analysis)
  print("Generated: \(metadata.title)")
} catch LLMBackendError.unavailable(let reason) {
  print("No backends available: \(reason)")
} catch LLMBackendError.generationFailed(let reason) {
  print("Generation failed: \(reason)")
}
```

**`generateFrom(projectPath: URL) async throws -> ProjectMetadata`**

Convenience method combining analysis and generation.

- **Input**: Project directory URL
- **Output**: `ProjectMetadata` ready to write
- **Throws**: `LLMBackendError` if analysis or generation fails
- **Behavior**:
  1. Analyzes directory via `ProjectService.analyzeForGeneration()`
  2. Calls `generate(project:)` with analysis
  3. Returns metadata

**Example Usage**

```swift
let service = ProjectGeneratorService()
do {
  let metadata = try await service.generateFrom(
    projectPath: URL(fileURLWithPath: "/path/to/project")
  )
  // metadata is ready to write to PROJECT.md
  print("Generated: \(metadata.title)")
} catch {
  print("Error: \(error)")
}
```

#### Error Handling

**Silent Fallthrough**: Errors from backends are silently caught (not logged) to allow fallback chain to proceed. Production logging would be added via a logging framework.

**Final Backend Special Handling**: Claude API (priority 3) errors are propagated as `.generationFailed` since it's the last resort.

---

### CastExtractor

**Location**: `Sources/SwiftProyecto/LLMBackend/CastExtractor.swift`

Extracts character names from Fountain script files.

#### Definition

```swift
public final class CastExtractor {
  /// Extract unique character names from Fountain text
  public func extractCast(from fountainText: String) -> [String]

  /// Extract from file URL
  public func extractCast(from fileURL: URL) throws -> [String]
}
```

#### Algorithm

1. Split content into lines
2. For each line:
   - Trim whitespace
   - Remove parentheticals (e.g., `(CONT'D)`, `(V.O.)`)
   - Skip if empty or doesn't pass validation
   - Add to cast if likely character name
3. Deduplicate and sort alphabetically

#### Methods

**`extractCast(from fountainText: String) -> [String]`**

- **Input**: Fountain script content as string
- **Output**: Sorted array of unique character names
- **Accuracy**: ≥80% typical (manual review recommended)
- **Example**:
  ```swift
  let fountain = """
  NARRADOR
  Today we drill the present tense.

  MAESTRA
  Io porto i libri a scuola.
  """
  let cast = CastExtractor().extractCast(from: fountain)
  // Returns: ["MAESTRA", "NARRADOR"]
  ```

**`extractCast(from fileURL: URL) throws -> [String]`**

- **Input**: URL to `.fountain` file
- **Output**: Sorted array of unique character names
- **Throws**: If file cannot be read
- **Encoding**: Assumes UTF-8 encoding

#### Fountain Format Support

Recognizes standard Fountain character line format:

```
INT. STUDY - NIGHT

UNCLE FU
The Tao that can be spoken is not the eternal Tao.

UNCLE FU (CONT'D)
The name that can be named is not the eternal name.
```

- Character names must be entirely uppercase
- Handles continuation markers: `(CONT'D)`, `(V.O.)`, `(O.S.)`, etc.
- Filters out scene headings: `INT.`, `EXT.`, `EST.`
- Filters out transitions: lines ending with `TO:`
- Filters out metadata: `FADE`, `CUT`, `DISSOLVE`

#### Accuracy & Limitations

- **Typical Accuracy**: ≥80% for reference scripts (lingua-matra, Produciesta)
- **Limitations**:
  - May extract false positives from malformed Fountain
  - May miss character names in unusual formats
  - Multi-word names are supported (`UNCLE FU`)
  - Hyphenated names are supported (`MARIE-LOUISE`)
  - Single-letter names are filtered (unlikely to be characters)
  - Names >50 characters filtered (likely malformed)

#### Usage in Directory Analysis

Used by `MetadataExtractor` to build `ProjectAnalysis.extractedCast`:

```swift
// Discovery phase
let extractor = CastExtractor()
for fountainFile in discoveredFountainFiles {
  let cast = try extractor.extractCast(from: fountainFile)
  allCast.append(contentsOf: cast)
}
let uniqueCast = Array(Set(allCast)).sorted()
```

---

### MetadataExtractor

**Location**: `Sources/SwiftProyecto/LLMBackend/MetadataExtractor.swift`

Infers project metadata from directory structure and file patterns.

#### Definition

```swift
public final class MetadataExtractor {
  /// Infer metadata from directory
  public func inferMetadata(
    from directoryPath: URL
  ) -> ProjectMetadataInference?
}

public struct ProjectMetadataInference: Sendable {
  public let title: String?           // Inferred title from directory name
  public let languages: [String]?     // Detected ISO 639-1 codes
  public let seasons: [Int]?          // Detected season numbers
  public let ttsProviders: [String]?  // Detected TTS providers
}
```

#### Methods

**`inferMetadata(from directoryPath: URL) -> ProjectMetadataInference?`**

- **Input**: Project directory URL
- **Output**: Partial metadata with inferred fields (all optional)
- **Returns**: `nil` if directory doesn't exist
- **Idempotent**: Safe to call multiple times
- **Example**:
  ```swift
  let extractor = MetadataExtractor()
  if let inferred = extractor.inferMetadata(from: projectURL) {
    print("Title: \(inferred.title ?? "Unknown")")
    print("Languages: \(inferred.languages ?? [])")
  }
  ```

#### Inference Rules

**Title Inference** (from directory name)
- Convert `lingua-matra` → `"Lingua Matra"`
- Convert `my_podcast` → `"My Podcast"`
- Strip trailing UUIDs: `project-12345678-...` → `"Project"`
- Capitalize each word
- Preserve mixed-case words

**Language Detection** (from ISO 639-1 directory codes)
- Recognizes standard ISO 639-1 codes: `en`, `es`, `it`, `pt`, `de`, `fr`, etc.
- Scans directory structure for language-named subdirectories
- Example: `/project/es/episode1.fountain` → detects `"es"`
- Case-insensitive matching

**Season Detection** (from directory names)
- Recognizes patterns: `season-1`, `s1`, `1`, `season_1`, etc.
- Extracts numeric season number
- Handles both numeric and text formats
- Multiple seasons detected if multiple directories found

**TTS Provider Detection** (from file patterns and metadata)
- Scans for Fountain frontmatter metadata
- Looks for TTS provider configuration files
- Infers from file naming conventions
- Examples: `apple.json`, `google-config.txt`, etc.

#### Internal Implementation

- **Recursive Scanning**: Traverses entire directory tree
- **Non-destructive**: Doesn't modify files
- **Error Handling**: Gracefully handles missing/unreadable directories
- **Deduplication**: Returns sorted, deduplicated results

#### Usage in Analysis Pipeline

Called as part of `ProjectService.analyzeForGeneration()`:

```swift
// Analysis phase
let extractor = MetadataExtractor()
let inferred = extractor.inferMetadata(from: projectPath)

return ProjectAnalysis(
  projectPath: projectPath,
  extractedCast: cast,
  inferredTitle: inferred?.title,
  detectedLanguages: inferred?.languages ?? [],
  // ...
)
```

---

### LLMBackendError

**Location**: `Sources/SwiftProyecto/LLMBackend/LLMBackendProtocol.swift`

Error types thrown by backends and services.

#### Definition

```swift
public enum LLMBackendError: LocalizedError {
  case unavailable(reason: String)
  case generationFailed(reason: String)
  case invalidInput(reason: String)
}
```

#### Cases

**`unavailable(reason: String)`**
- Backend is not available on current platform
- Thrown when:
  - Backend SDK not installed
  - Required credentials missing (e.g., no `CLAUDE_API_KEY`)
  - Platform requirements not met (e.g., macOS <27 for Foundation Models)
  - System resources unavailable
- Handled by: Fallback chain attempts next backend
- Example: `"Claude API: CLAUDE_API_KEY not set"`

**`generationFailed(reason: String)`**
- Backend error during generation
- Thrown when:
  - LLM API returns error
  - JSON parsing fails
  - Schema validation fails
  - Network error (API backends)
  - Timeout
- Handled by: Fallback chain attempts next backend (except final backend)
- Example: `"Claude API: Rate limit exceeded"`

**`invalidInput(reason: String)`**
- Invalid input to backend
- Thrown when:
  - `ProjectAnalysis` is malformed
  - Required fields missing or invalid
  - Path doesn't exist
- Handled by: Caller (not retried in fallback chain)
- Example: `"Invalid input: projectPath must exist"`

#### Error Conformance

Conforms to `LocalizedError`:
```swift
public var errorDescription: String? {
  switch self {
  case .unavailable(let reason):
    return "LLM Backend unavailable: \(reason)"
  case .generationFailed(let reason):
    return "LLM Backend generation failed: \(reason)"
  case .invalidInput(let reason):
    return "Invalid input to LLM Backend: \(reason)"
  }
}
```

---

## Architecture & Design Decisions

### Why LLMBackendProtocol (Protocol vs Enum vs Class Hierarchy)?

**Decision**: Use a protocol with concrete implementations rather than enum or class hierarchy.

**Rationale**:

1. **Extensibility Without Coupling**: New backends can be added without modifying SwiftProyecto core
   - Protocol-based design allows soft dependencies (backends can be in separate frameworks)
   - Enum-based design would require core enum modification for each new backend
   - Class hierarchy would create tight coupling

2. **Soft Dependencies**: Backends can be optionally available
   - SwiftBruja: Optional dependency (may not be linked)
   - Foundation Models: Only on macOS 27+
   - Claude API: External network service
   - Protocol allows "availability" to be dynamic, not compile-time decision

3. **Runtime Registration**: Backends self-register via singleton registry
   - Cleaner than switch statements or factory pattern
   - No central dependency list to maintain
   - Easier to test (can inject mock backends)

4. **Thread-Safety**: Easier to implement with protocol + registry pattern
   - Protocol methods can be marked async/await safe
   - Registry singleton provides central synchronization
   - Implementations can use `@unchecked Sendable` where needed

5. **Testing**: Mock backends can be created inline for testing
   - No need for complex test doubles
   - Easy to simulate availability/failure scenarios

### Why Fallback Chain (not Multi-Model Inference)?

**Decision**: Use priority-ordered fallback chain rather than querying multiple backends.

**Rationale**:

1. **Predictable Behavior**: Single backend chosen per generation
   - Deterministic output (same input → same output)
   - Easier to debug and reproduce issues
   - Clear error messages about which backend failed

2. **Simplicity**: Single LLM inference per generation, not multiple
   - Lower latency (one query, not three)
   - Lower API costs (single Claude query, not multiple)
   - No coordination complexity (no voting, merging, consensus)
   - Easier to reason about correctness

3. **Platform Pragmatism**: First available backend wins
   - Local inference (Bruja/FM) preferred for speed/privacy
   - Falls back to Claude API for reliability
   - Respects platform constraints (FM macOS 27+ only)

4. **Clear Failure Path**: If backend fails, try next (not silent failure)
   - Explicit error handling and fallthrough
   - User can debug which backends available
   - CLI can show helpful error messages

5. **Performance**: Fallback chain faster than alternatives
   - SwiftBruja: Fastest, instant local inference
   - Foundation Models: Fast, on-device (macOS 27+ only)
   - Claude API: Slower but most reliable

**Alternative Considered**: Multi-model inference (query all, vote)
- ❌ Would be slower (3x API calls)
- ❌ Would require sophisticated merging logic
- ❌ Would increase costs
- ❌ Would make debugging harder
- ❌ No clear benefit over single best backend

### Why ProjectGeneratorService (not Static Functions)?

**Decision**: Use singleton service class instead of static functions.

**Rationale**:

1. **Dependency Injection**: Service can accept registry in constructor
   - Easier to test (can inject mock registry)
   - Can swap registries for different scenarios
   - Static functions can't be mocked without global state

2. **Future Configuration**: Service can grow to accept options
   - Timeout configuration
   - Retry policy
   - Logging/telemetry
   - Backend preferences
   - Static functions would require global state or method parameters

3. **Singleton Pattern Clarity**: Single global instance is explicit
   - Consumers know there's one service
   - Easier to track lifecycle
   - Can support multiple instances if needed (testing)

4. **Sendable Safety**: Class can implement `@unchecked Sendable`
   - Clarifies thread-safety assumptions
   - Easier to reason about concurrency
   - Static functions would have same safety requirements but less clear

### Why BackendRegistry (Singleton Pattern)?

**Decision**: Use singleton registry instead of static registry or factory.

**Rationale**:

1. **Global Discovery**: Single source of truth for backends
   - All backends discoverable via `BackendRegistry.shared`
   - No hidden backends or multiple registries
   - Consistent across application

2. **Thread-Safe Access**: Singleton provides synchronization point
   - All backend access goes through single lock
   - No race conditions between registration and lookup
   - Lock-based synchronization is simpler than lock-free alternatives

3. **Testing Flexibility**: Can create new instances for tests
   - Test can create isolated registry: `BackendRegistry()`
   - No global state pollution between tests
   - Singleton provides default for production

4. **Clear Lifecycle**: Backends register once at startup
   - No re-registration or cleanup needed
   - Easier to reason about availability timeline
   - Supports lazy initialization if needed

---

## Data Flow & Pipeline

### Full Generation Pipeline

```
User Input
    ↓
┌──────────────────────────────────┐
│   GenerateProjectCommand (CLI)   │  Parses arguments, validates flags
│   - --directory                  │  Resolves paths
│   - --dry-run / --interactive    │
│   - --force                       │
│   - --llm (backend selection)     │
└──────────────────────────────────┘
    ↓
┌──────────────────────────────────┐
│  ProjectService.analyzeForGeneration  │  Phase 1: Analysis
│  at: directoryPath               │
└──────────────────────────────────┘
    ↓
  ┌─ CastExtractor ─ Discovers .fountain files, extracts cast
  │                 Returns: ["CHARACTER1", "CHARACTER2", ...]
  │
  ├─ MetadataExtractor ─ Scans directory structure
  │                      Returns: title, languages, seasons, ttsProviders
  │
  └─ FileDiscovery ─ Lists all discovered files
                     Returns: ["ep1.fountain", "README.md", ...]
    ↓
ProjectAnalysis
├─ projectPath: URL
├─ discoveredFiles: [String]
├─ extractedCast: [String]
├─ episodePattern: String?
├─ inferredTitle: String?
└─ detectedLanguages: [String]
    ↓
┌──────────────────────────────────┐
│  BackendRegistry                 │  Lookup backend
│  .backend(named: "Claude API")   │  or .availableBackends()
│  or auto-select via chain        │
└──────────────────────────────────┘
    ↓
┌──────────────────────────────────┐
│  Selected Backend                │  Phase 2: Generation
│  .generate(project: analysis)    │  - Send analysis to LLM
│                                  │  - Parse LLM response
│                                  │  - Return ProjectMetadata
└──────────────────────────────────┘
    ↓
ProjectMetadata
├─ title: String
├─ author: String
├─ description: String?
├─ created: Date
├─ type: String
├─ episodes: Int?
├─ season: Int?
├─ genre: String?
├─ tags: [String]
├─ ttsProvider: String?
└─ cast: [CastMemberData]
    ↓
┌──────────────────────────────────┐
│  Output Handler                  │  Phase 3: Output
│  - Dry-run: stdout               │
│  - Interactive: review + prompt  │
│  - Force: write to disk           │
└──────────────────────────────────┘
    ↓
Result
✅ PROJECT.md generated and written (or stdout)
```

### Directory Analysis Phase Detail

```
ProjectService.analyzeForGeneration(at: projectPath)
│
├─ Step 1: File Discovery
│  ├─ FileManager recursively lists all files
│  └─ Result: [String] relative paths
│
├─ Step 2: Cast Extraction
│  ├─ Find all .fountain files
│  ├─ For each fountain file:
│  │  └─ CastExtractor.extractCast(from: file)
│  ├─ Deduplicate cast across all files
│  └─ Result: [String] sorted unique characters
│
├─ Step 3: Metadata Inference
│  ├─ MetadataExtractor.inferMetadata(from: directoryPath)
│  ├─ Detects:
│  │  - title (from directory name)
│  │  - languages (ISO 639-1 codes)
│  │  - seasons (season directory patterns)
│  │  - ttsProviders (from config)
│  └─ Result: ProjectMetadataInference
│
└─ Step 4: Assemble ProjectAnalysis
   └─ Return ProjectAnalysis with all gathered data
```

### LLM Generation Phase Detail (Backend Implementation)

```
Backend.generate(project: ProjectAnalysis)
│
├─ Step 1: Build Prompt
│  ├─ Use ProjectAnalysis fields as context
│  ├─ Few-shot examples (backend-specific)
│  ├─ Schema instructions (v4.x PROJECT.md format)
│  └─ Request JSON response
│
├─ Step 2: Query LLM
│  ├─ Backend-specific implementation:
│  │  - ClaudeAPIBackend: URLSession + Anthropic API
│  │  - AppleFoundationModelsBackend: FoundationModels framework
│  │  - SwiftBrujaBackend: SwiftBruja local inference
│  └─ Result: String response (should be valid JSON)
│
├─ Step 3: Parse Response
│  ├─ Decode JSON to ProjectMetadata struct
│  ├─ Handle malformed JSON gracefully
│  └─ Result: ProjectMetadata or error
│
├─ Step 4: Validate (Optional)
│  ├─ Check required fields present
│  ├─ Validate against schema
│  └─ Return error if invalid
│
└─ Step 5: Return ProjectMetadata
   └─ Ready for writing to PROJECT.md
```

### Error Handling in Fallback Chain

```
ProjectGeneratorService.generate(project: analysis)
│
├─ Try SwiftBruja
│  ├─ backend(named: "SwiftBruja") → optional
│  ├─ If available: generate(project)
│  ├─ If generation fails: catch error, continue
│  └─ If generation succeeds: return metadata ✅
│
├─ Try Apple Foundation Models (macOS 27+ only)
│  ├─ Check platform version
│  ├─ backend(named: "Apple Foundation Models") → optional
│  ├─ If available: generate(project)
│  ├─ If generation fails: catch error, continue
│  └─ If generation succeeds: return metadata ✅
│
├─ Try Claude API (fallback)
│  ├─ backend(named: "Claude API") → optional
│  ├─ If available: generate(project)
│  ├─ If generation fails: throw error ❌ (last resort)
│  └─ If generation succeeds: return metadata ✅
│
└─ All backends exhausted
   └─ throw LLMBackendError.unavailable(...) ❌
```

---

## Testing Guide

### Unit Testing Patterns

#### Test File Location

```
Tests/SwiftProyectoTests/
├─ BackendAbstractionTests.swift          (Protocol & Registry)
├─ ClaudeAPIBackendTests.swift            (Claude Backend)
├─ AppleFoundationModelsBackendTests.swift (FM Backend)
├─ SwiftBrujaBackendTests.swift           (Bruja Backend)
├─ CastExtractorTests.swift               (Cast Extraction)
├─ MetadataExtractorTests.swift           (Metadata Inference)
└─ ProjectGeneratorServiceTests.swift     (Generation Service)
```

#### Testing LLMBackendProtocol Conformance

```swift
import XCTest
@testable import SwiftProyecto

final class CustomBackendTests: XCTestCase {

  // Test protocol conformance
  func testProtocolConformance() {
    let backend = MyCustomBackend()
    XCTAssertTrue(backend.isAvailable)
    XCTAssertEqual(backend.backendName, "My Backend")
  }

  // Test availability logic
  func testAvailabilityCheck() {
    let availableBackend = MyCustomBackend(available: true)
    let unavailableBackend = MyCustomBackend(available: false)

    XCTAssertTrue(availableBackend.isAvailable)
    XCTAssertFalse(unavailableBackend.isAvailable)
  }

  // Test generation method
  func testGeneration() async throws {
    let backend = MyCustomBackend()
    let analysis = ProjectAnalysis(
      projectPath: URL(fileURLWithPath: "/test"),
      extractedCast: ["CHAR1", "CHAR2"]
    )

    let metadata = try await backend.generate(project: analysis)

    XCTAssertEqual(metadata.title, "Test Project")
    XCTAssertEqual(metadata.cast.count, 2)
  }

  // Test error handling
  func testGenerationError() async {
    let backend = MyCustomBackend(shouldFail: true)
    let analysis = ProjectAnalysis(
      projectPath: URL(fileURLWithPath: "/test")
    )

    do {
      _ = try await backend.generate(project: analysis)
      XCTFail("Should have thrown error")
    } catch LLMBackendError.generationFailed {
      // Expected
    } catch {
      XCTFail("Wrong error type: \(error)")
    }
  }
}
```

#### Testing BackendRegistry

```swift
final class BackendRegistryTests: XCTestCase {

  // Test singleton
  func testSingleton() {
    let registry1 = BackendRegistry.shared
    let registry2 = BackendRegistry.shared
    XCTAssertTrue(registry1 === registry2)
  }

  // Test registration
  func testRegister() {
    let registry = BackendRegistry()
    let backend = MockLLMBackend(name: "Test", available: true)

    registry.register(backend)

    XCTAssertEqual(registry.allBackends().count, 1)
  }

  // Test availability filtering
  func testAvailableBackends() {
    let registry = BackendRegistry()
    registry.register(MockLLMBackend(name: "Available", available: true))
    registry.register(MockLLMBackend(name: "Unavailable", available: false))

    let available = registry.availableBackends()

    XCTAssertEqual(available.count, 1)
    XCTAssertEqual(available[0].backendName, "Available")
  }

  // Test lookup by name
  func testBackendLookup() {
    let registry = BackendRegistry()
    let backend = MockLLMBackend(name: "Claude API", available: true)
    registry.register(backend)

    let found = registry.backend(named: "Claude API")

    XCTAssertNotNil(found)
    XCTAssertEqual(found?.backendName, "Claude API")
  }

  // Test lookup returns nil for unavailable
  func testLookupUnavailable() {
    let registry = BackendRegistry()
    let backend = MockLLMBackend(name: "Unavailable", available: false)
    registry.register(backend)

    let found = registry.backend(named: "Unavailable")

    XCTAssertNil(found)
  }
}
```

#### Testing ProjectGeneratorService

```swift
final class ProjectGeneratorServiceTests: XCTestCase {

  // Test fallback chain
  func testFallbackChain() async throws {
    // Create mock backends
    let bruja = MockLLMBackend(name: "SwiftBruja", available: true)
    let fm = MockLLMBackend(name: "Apple Foundation Models", available: true)
    let claude = MockLLMBackend(name: "Claude API", available: true)

    // Create registry and register in order
    let registry = BackendRegistry()
    registry.register(bruja)
    registry.register(fm)
    registry.register(claude)

    // Create service with custom registry
    let service = ProjectGeneratorService(registry: registry)

    let analysis = ProjectAnalysis(
      projectPath: URL(fileURLWithPath: "/test")
    )

    // First available backend should be used
    let metadata = try await service.generate(project: analysis)
    XCTAssertNotNil(metadata)
  }

  // Test fallback when first unavailable
  func testFallbackWhenFirstUnavailable() async throws {
    let registry = BackendRegistry()
    registry.register(MockLLMBackend(name: "SwiftBruja", available: false))
    registry.register(MockLLMBackend(name: "Claude API", available: true))

    let service = ProjectGeneratorService(registry: registry)

    let analysis = ProjectAnalysis(
      projectPath: URL(fileURLWithPath: "/test")
    )

    // Should skip unavailable Bruja and use Claude
    let metadata = try await service.generate(project: analysis)
    XCTAssertNotNil(metadata)
  }

  // Test error when no backends available
  func testErrorWhenNoBackends() async {
    let registry = BackendRegistry()
    let service = ProjectGeneratorService(registry: registry)

    let analysis = ProjectAnalysis(
      projectPath: URL(fileURLWithPath: "/test")
    )

    do {
      _ = try await service.generate(project: analysis)
      XCTFail("Should have thrown unavailable error")
    } catch LLMBackendError.unavailable {
      // Expected
    } catch {
      XCTFail("Wrong error type: \(error)")
    }
  }
}
```

#### Testing CastExtractor

```swift
final class CastExtractorTests: XCTestCase {

  let extractor = CastExtractor()

  // Test basic cast extraction
  func testBasicExtraction() {
    let fountain = """
    NARRADOR
    Today we drill.

    MAESTRA
    Let's begin.
    """

    let cast = extractor.extractCast(from: fountain)

    XCTAssertEqual(cast, ["MAESTRA", "NARRADOR"])
  }

  // Test parenthetical removal
  func testParentheticalRemoval() {
    let fountain = """
    CHARACTER (CONT'D)
    Continuing dialogue.

    CHARACTER (V.O.)
    Voice over narration.
    """

    let cast = extractor.extractCast(from: fountain)

    XCTAssertEqual(cast, ["CHARACTER"])
  }

  // Test multi-word names
  func testMultiWordNames() {
    let fountain = """
    UNCLE FU
    Wisdom.

    MARIE-LOUISE
    Bonjour.
    """

    let cast = extractor.extractCast(from: fountain)

    XCTAssertEqual(cast, ["MARIE-LOUISE", "UNCLE FU"])
  }

  // Test scene heading filtering
  func testSceneHeadingFiltering() {
    let fountain = """
    INT. STUDY - NIGHT

    CHARACTER
    Dialogue.
    """

    let cast = extractor.extractCast(from: fountain)

    XCTAssertEqual(cast, ["CHARACTER"])
  }

  // Test deduplication
  func testDeduplication() {
    let fountain = """
    CHAR1
    Line 1.

    CHAR1
    Line 2.

    CHAR2
    Line 3.
    """

    let cast = extractor.extractCast(from: fountain)

    XCTAssertEqual(cast, ["CHAR1", "CHAR2"])
  }
}
```

#### Testing MetadataExtractor

```swift
final class MetadataExtractorTests: XCTestCase {

  let extractor = MetadataExtractor()

  // Test title inference
  func testTitleInference() {
    let fileManager = FileManager.default
    let tempDir = fileManager.temporaryDirectory
      .appendingPathComponent("lingua-matra")

    try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let inferred = extractor.inferMetadata(from: tempDir)

    XCTAssertEqual(inferred?.title, "Lingua Matra")

    try? fileManager.removeItem(at: tempDir)
  }

  // Test language detection
  func testLanguageDetection() {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("project-\(UUID().uuidString)")

    try? FileManager.default.createDirectory(
      at: tempDir,
      withIntermediateDirectories: true
    )

    // Create language subdirectories
    try? FileManager.default.createDirectory(
      at: tempDir.appendingPathComponent("es"),
      withIntermediateDirectories: true
    )
    try? FileManager.default.createDirectory(
      at: tempDir.appendingPathComponent("en"),
      withIntermediateDirectories: true
    )

    let inferred = extractor.inferMetadata(from: tempDir)

    XCTAssertEqual(Set(inferred?.languages ?? []), ["en", "es"])

    try? FileManager.default.removeItem(at: tempDir)
  }
}
```

### Integration Testing Patterns

#### Test File Location

```
Tests/SwiftProyectoTests/
├─ GenerateProjectCommandIntegrationTests.swift
├─ CLIGenerateProjectTests.swift
└─ MultiBackendComparisonTests.swift
```

#### CLI Integration Test Example

```swift
import XCTest
@testable import SwiftProyecto

final class CLIGenerateProjectIntegrationTests: XCTestCase {

  // Test command execution
  func testDryRunExecution() throws {
    let testProjectPath = Bundle(for: type(of: self))
      .resourceURL?
      .appendingPathComponent("test-project")

    XCTAssertNotNil(testProjectPath)

    // Simulate: proyecto generate-project testProject --dry-run
    var command = GenerateProjectCommand()
    command.directory = testProjectPath?.path
    command.dryRun = true

    // Execute and verify no crash
    try command.run()
  }

  // Test interactive mode
  func testInteractiveMode() throws {
    // Test that --interactive and --force are mutually exclusive
    var command = GenerateProjectCommand()
    command.interactive = true
    command.force = true
    command.directory = "/tmp/test"

    XCTAssertThrowsError(try command.run())
  }

  // Test file writing
  func testForceWrite() throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("test-\(UUID().uuidString)")

    try FileManager.default.createDirectory(
      at: tempDir,
      withIntermediateDirectories: true
    )

    // Create test content
    try "# Test Project".write(
      toFile: tempDir.appendingPathComponent("README.md").path,
      atomically: true,
      encoding: .utf8
    )

    var command = GenerateProjectCommand()
    command.directory = tempDir.path
    command.force = true
    command.quiet = true

    try command.run()

    // Verify PROJECT.md was created
    let projectMDPath = tempDir.appendingPathComponent("PROJECT.md")
    XCTAssertTrue(FileManager.default.fileExists(atPath: projectMDPath.path))

    // Cleanup
    try FileManager.default.removeItem(at: tempDir)
  }
}
```

#### Multi-Backend Comparison Test

```swift
final class MultiBackendComparisonTests: XCTestCase {

  // Test all backends produce valid output
  func testAllBackendsGenerateValidOutput() async throws {
    // Use lingua-matra as reference project
    let linguaMatra = URL(fileURLWithPath: "/path/to/lingua-matra")

    guard FileManager.default.fileExists(atPath: linguaMatra.path) else {
      XCTSkip("lingua-matra not found")
    }

    let backends = BackendRegistry.shared.availableBackends()

    for backend in backends {
      let analysis = ProjectService.analyzeForGeneration(at: linguaMatra)
      XCTAssertNotNil(analysis, "Analysis failed for \(backend.backendName)")

      let metadata = try await backend.generate(project: analysis!)

      // Validate required fields
      XCTAssertFalse(metadata.title.isEmpty, "\(backend.backendName): title empty")
      XCTAssertFalse(metadata.author.isEmpty, "\(backend.backendName): author empty")
      XCTAssertFalse(metadata.cast.isEmpty, "\(backend.backendName): cast empty")

      // Validate cast accuracy (≥80%)
      let accuracyThreshold = 0.8
      let expectedCast = ["MAESTRA", "NARRADOR"]
      let extractedCast = metadata.cast.map { $0.name }
      let matchCount = expectedCast.filter { extractedCast.contains($0) }.count
      let accuracy = Double(matchCount) / Double(expectedCast.count)

      XCTAssertGreaterThanOrEqual(
        accuracy,
        accuracyThreshold,
        "\(backend.backendName): cast accuracy \(accuracy) < \(accuracyThreshold)"
      )
    }
  }
}
```

### Test Coverage Guidelines

#### High-Value Test Areas

1. **Backend Availability Logic** (High Value)
   - ✅ Test `isAvailable` property
   - ✅ Test platform constraints (macOS version, SDK availability)
   - ✅ Test credential checks (API keys)
   - Goal: 100% coverage

2. **Fallback Chain** (High Value)
   - ✅ Test backend priority order
   - ✅ Test fallthrough on error
   - ✅ Test error when all backends fail
   - Goal: 100% coverage

3. **Error Handling** (High Value)
   - ✅ Test all `LLMBackendError` cases
   - ✅ Test error propagation
   - ✅ Test error messages
   - Goal: 100% coverage

4. **Cast Extraction** (Medium Value)
   - ✅ Test character name detection
   - ✅ Test parenthetical removal
   - ✅ Test scene heading filtering
   - ✅ Test multi-word names
   - Goal: ≥90% coverage

5. **Metadata Inference** (Medium Value)
   - ✅ Test title extraction
   - ✅ Test language detection
   - ✅ Test season detection
   - ✅ Test TTS provider detection
   - Goal: ≥85% coverage

#### Low-Value Test Areas (Avoid Over-Testing)

- ❌ UI/formatting (how PROJECT.md is formatted)
- ❌ YAML serialization (handled by Codable)
- ❌ Third-party library behavior (URLSession, FoundationModels)
- ❌ File I/O edge cases (already handled by system)

---

## Contributing Guide

### Adding a New LLM Backend

#### Step 1: Create Backend Implementation

```swift
// Sources/SwiftProyecto/LLMBackend/MyBackend.swift

import Foundation

public final class MyBackend: LLMBackendProtocol, @unchecked Sendable {
  public let backendName = "My Backend"

  public var isAvailable: Bool {
    // Check availability: SDK installed, credentials present, platform compatible
    // Examples:
    // - Check if optional dependency is available
    // - Check for environment variables (API keys)
    // - Check platform version (e.g., macOS 27+)
    return true
  }

  public func generate(project: ProjectAnalysis) async throws -> ProjectMetadata {
    // Implement generation logic:
    // 1. Build prompt from ProjectAnalysis
    // 2. Query LLM
    // 3. Parse response to ProjectMetadata
    // 4. Return or throw error

    // Throw appropriate errors:
    // - throw LLMBackendError.unavailable(reason:) if unavailable
    // - throw LLMBackendError.generationFailed(reason:) if generation fails
    // - throw LLMBackendError.invalidInput(reason:) if input invalid

    let metadata = ProjectMetadata(
      title: "Generated Title",
      author: "Generated Author"
    )
    return metadata
  }
}
```

#### Step 2: Register Backend at Initialization

```swift
// Typically in GenerateProjectCommand or app startup

func initializeLLMBackends() {
  let registry = BackendRegistry.shared

  // Register new backend
  registry.register(MyBackend())

  // Register other backends
  registry.register(ClaudeAPIBackend())
  registry.register(AppleFoundationModelsBackend())
  registry.register(SwiftBrujaBackend())
}
```

#### Step 3: Write Unit Tests

```swift
// Tests/SwiftProyectoTests/MyBackendTests.swift

import XCTest
@testable import SwiftProyecto

final class MyBackendTests: XCTestCase {

  let backend = MyBackend()

  // Test availability
  func testAvailability() {
    XCTAssertTrue(backend.isAvailable)
  }

  // Test generation
  func testGeneration() async throws {
    let analysis = ProjectAnalysis(
      projectPath: URL(fileURLWithPath: "/test"),
      extractedCast: ["CHARACTER1", "CHARACTER2"]
    )

    let metadata = try await backend.generate(project: analysis)

    XCTAssertFalse(metadata.title.isEmpty)
    XCTAssertFalse(metadata.author.isEmpty)
    XCTAssertEqual(metadata.cast.count, 2)
  }

  // Test error handling
  func testErrorHandling() async {
    let invalidAnalysis = ProjectAnalysis(
      projectPath: URL(fileURLWithPath: "/nonexistent")
    )

    do {
      _ = try await backend.generate(project: invalidAnalysis)
      XCTFail("Should throw error")
    } catch LLMBackendError.invalidInput {
      // Expected
    } catch {
      XCTFail("Wrong error: \(error)")
    }
  }
}
```

#### Step 4: Write Integration Test

```swift
final class MyBackendIntegrationTests: XCTestCase {

  // Test with real project (lingua-matra)
  func testRealProjectGeneration() async throws {
    let linguaMatra = URL(fileURLWithPath: "/path/to/lingua-matra")

    let analysis = ProjectService.analyzeForGeneration(at: linguaMatra)
    XCTAssertNotNil(analysis)

    let backend = MyBackend()
    let metadata = try await backend.generate(project: analysis!)

    // Validate output
    XCTAssertEqual(metadata.title, "Lingua Matra")
    XCTAssertEqual(metadata.genre, "Educational")
    XCTAssertGreaterThan(metadata.cast.count, 0)
  }
}
```

#### Step 5: Update Documentation

1. **AGENTS.md**: Add backend to availability table (§ Backend Availability)
2. **This file**: Document backend-specific details
3. **README**: Update backend list if user-facing

#### Step 6: Test Backend Selection

```bash
# Test auto-selection (should find your backend)
proyecto generate-project /path --dry-run

# Test explicit selection
proyecto generate-project /path --llm mybackend --dry-run
```

---

### Modifying Project Analysis

#### Modifying CastExtraction

If improving cast extraction accuracy:

1. Update `CastExtractor.isLikelyCharacterName()` algorithm
2. Add test cases for edge cases
3. Run against lingua-matra reference project
4. Verify accuracy ≥80%
5. Update documentation with new accuracy metrics

#### Modifying MetadataInference

If adding new inference capabilities:

1. Extend `MetadataExtractor` with new scanning logic
2. Add fields to `ProjectMetadataInference` if needed
3. Write tests for new detection patterns
4. Verify against lingua-matra project
5. Update error handling for edge cases

**Impact Zone**: Changes here affect all backends (they receive updated `ProjectAnalysis`)

---

### Modifying CLI Behavior

#### Adding New Flags

```swift
// In GenerateProjectCommand

@Flag(name: .long, help: "Description") var newFlag: Bool = false

mutating func run() async throws {
  // Validate flag combinations
  if newFlag && someOtherFlag {
    throw ValidationError("Cannot use both")
  }

  // Use flag in logic
  if newFlag {
    // ...
  }
}
```

#### Changing Default Behavior

- ✅ Update default values in flag definitions
- ✅ Update command documentation
- ✅ Test backward compatibility
- ✅ Update AGENTS.md examples

#### Error Messages

Use consistent style:

```swift
throw GenerateProjectError.directoryNotFound(
  "Directory not found: \(path)\nUse: proyecto generate-project /path/to/project"
)
```

---

### Code Style & Conventions

#### Backend Implementation

- Use async/await for all LLM queries
- Throw specific `LLMBackendError` cases
- Include comprehensive documentation comments
- Mark as `@unchecked Sendable` if thread-safe
- Test availability logic thoroughly

#### Error Handling

```swift
// Good: Specific error with context
throw LLMBackendError.generationFailed(
  reason: "Claude API: rate limit exceeded (429)"
)

// Bad: Vague error
throw LLMBackendError.generationFailed(reason: "error")
```

#### Documentation Comments

```swift
/// One-sentence summary.
///
/// Longer description if needed, explaining:
/// - What the function does
/// - What it expects as input
/// - What it returns
/// - Any important side effects or errors
///
/// - Parameter name: Description
/// - Returns: Description
/// - Throws: When and why this throws errors
///
/// ## Example
/// ```swift
/// // Code example
/// ```
public func methodName() { }
```

---

## ADR — Architecture Decision Records

### ADR-1: Use LLMBackendProtocol Instead of Enum/Class Hierarchy

**Status**: Accepted (v4.1.0)

**Context**: Need to support multiple LLM backends (Claude API, Foundation Models, SwiftBruja) and allow future extensions without modifying core.

**Decision**: Use protocol-based design with `BackendRegistry` singleton.

**Rationale**:
- Enables soft dependencies (backends optional)
- Allows runtime registration
- Easier to test with mock backends
- Clear "availability" semantics
- No central enum/class dependency list

**Consequences**:
- (+) Easy to add new backends
- (+) Soft dependencies allow optional frameworks
- (+) Runtime availability checking
- (-) Slightly more complex than enum
- (-) Requires registry management

**Alternatives Rejected**:
- ❌ Enum-based: Requires core modification for each backend
- ❌ Class hierarchy: Tight coupling, harder to extend
- ❌ Factory pattern: Requires central factory knowledge
- ❌ Static functions: Can't inject for testing

---

### ADR-2: Fallback Chain Instead of Multi-Model Inference

**Status**: Accepted (v4.1.0)

**Context**: Multiple backends available (Bruja, FM, Claude). Need to handle failures gracefully and provide consistent output.

**Decision**: Use priority-ordered fallback chain.

**Rationale**:
- Deterministic output (single backend per generation)
- Lower latency (one query, not three)
- Lower costs (no multi-query overhead)
- Simpler error handling
- Respects platform constraints (FM macOS 27+ only)

**Consequences**:
- (+) Fast, predictable behavior
- (+) Low cost (single API call)
- (+) Simple error messages
- (-) Can't combine strengths of multiple backends
- (-) No consensus/voting
- (-) Output varies by backend availability

**Alternatives Rejected**:
- ❌ Multi-model voting: Too slow, too expensive
- ❌ Weighted ensemble: Still requires multiple queries
- ❌ Single backend only: No fallback, fragile

---

### ADR-3: Singleton ProjectGeneratorService Instead of Static Functions

**Status**: Accepted (v4.1.0)

**Context**: Need centralized generation service that uses `BackendRegistry`.

**Decision**: Use singleton service class.

**Rationale**:
- Dependency injection support (can pass registry)
- Testability (can create isolated instances)
- Future configurability (timeouts, retry policy, logging)
- Clearer than static function methods

**Consequences**:
- (+) Testable with dependency injection
- (+) Extensible (can add options)
- (+) Clear lifecycle management
- (-) Singleton pattern (but resolvable for testing)

**Alternatives Rejected**:
- ❌ Static functions: Can't inject registry, harder to test
- ❌ Global variable: Same issues as singleton but less explicit
- ❌ Struct with static methods: Same problems

---

### ADR-4: Protocol-Based BackendRegistry Instead of Static Dispatch Table

**Status**: Accepted (v4.1.0)

**Context**: Need to store and query backends at runtime.

**Decision**: Use singleton registry with protocol-based lookup.

**Rationale**:
- Centralized backend management
- Thread-safe access via lock
- Availability is dynamic, not compile-time
- Clear registration phase
- Supports testing with isolated instances

**Consequences**:
- (+) Single source of truth
- (+) Thread-safe by design
- (+) Runtime registration
- (-) Must initialize backends at startup

**Alternatives Rejected**:
- ❌ Type dispatch: Compile-time only, can't be optional
- ❌ Conditional compilation: Platform features compile-time, not runtime
- ❌ Global variable: Same as singleton but less clear

---

## Appendix: Mock Backend for Testing

```swift
// Tests/SwiftProyectoTests/Helpers/MockLLMBackend.swift

import Foundation
@testable import SwiftProyecto

final class MockLLMBackend: LLMBackendProtocol, @unchecked Sendable {
  let backendName: String
  let isAvailable: Bool
  let shouldFail: Bool

  init(
    name: String = "Mock Backend",
    available: Bool = true,
    shouldFail: Bool = false
  ) {
    self.backendName = name
    self.isAvailable = available
    self.shouldFail = shouldFail
  }

  func generate(project: ProjectAnalysis) async throws -> ProjectMetadata {
    if shouldFail {
      throw LLMBackendError.generationFailed(reason: "Mock failure")
    }

    return ProjectMetadata(
      title: project.inferredTitle ?? "Mock Project",
      author: "Mock Author",
      description: "Generated by mock backend",
      created: Date(),
      type: "project",
      episodes: project.extractedCast.count,
      season: 1,
      genre: "Unknown",
      tags: ["mock", "test"],
      ttsProvider: "apple",
      cast: project.extractedCast.map { name in
        CastMemberData(
          name: name,
          actor: "Mock Actor",
          voiceProvider: "apple",
          voiceId: "com.apple.voice.compact.en-US.Aaron"
        )
      }
    )
  }
}
```

---

## References & Related Files

- **User Guide**: [AGENTS.md § Generating PROJECT.md with LLM Backends](AGENTS.md#-generating-projectmd-with-llm-backends-v41)
- **Source Code**:
  - `Sources/SwiftProyecto/LLMBackend/LLMBackendProtocol.swift`
  - `Sources/SwiftProyecto/LLMBackend/BackendRegistry.swift`
  - `Sources/SwiftProyecto/LLMBackend/ProjectGeneratorService.swift`
  - `Sources/proyecto/GenerateProjectCommand.swift`
- **Tests**:
  - `Tests/SwiftProyectoTests/BackendAbstractionTests.swift`
  - `Tests/SwiftProyectoTests/ClaudeAPIBackendTests.swift`
  - `Tests/SwiftProyectoTests/GenerateProjectCommandIntegrationTests.swift`
- **Schema**: [PROJECT_MD_REFERENCE_v4.md](PROJECT_MD_REFERENCE_v4.md)

---

**Document Version**: 4.1.0  
**Last Updated**: 2026-06-23  
**Maintainer**: SwiftProyecto Team

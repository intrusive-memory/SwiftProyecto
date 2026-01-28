# PARSE Architecture

## Overview

The PARSE command generates audio for a **single screenplay file**. The PROJECT.md provides an iterator that discovers files and yields `ParseCommandArguments` for each file.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ ProjectModel (SwiftData)                                        │
│ - title, author                                                 │
│ - sourceRootURL: "/path/to/project"                            │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ parseConfig(batchArgs)
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ ParseBatchConfig                                                │
│ - Reads PROJECT.md for: episodesDir, audioDir, filePattern,    │
│   exportFormat, hooks                                           │
│ - Applies CLI batch-level overrides: --output, --format,       │
│   --skip-existing, --resume-from, --regenerate, etc.           │
│ - Discovers files based on filePattern                         │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ makeIterator()
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ ParseFileIterator                                               │
│ - Iterates discovered episode files                            │
│ - Yields ParseCommandArguments for EACH file                   │
│ - Applies file-level logic: skipExisting, resumeFrom           │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ next()
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ ParseCommandArguments (for SINGLE file)                        │
│ - episodeFileURL: URL                  (absolute path)          │
│ - outputURL: URL                       (absolute path)          │
│ - exportFormat: String                 ("m4a")                  │
│ - castListURL: URL?                    (if specified)           │
│ - useCastList: Bool                                             │
│ - verbose: Bool                                                 │
│ - quiet: Bool                                                   │
│ - dryRun: Bool                                                  │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ pass to
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│ Generation Engine (Produciesta)                                │
│ - Parses single screenplay file                                │
│ - Generates audio for single file                              │
│ - Exports to outputURL                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### 1. Batch Configuration (Project-Level)

```swift
// CLI invocation: generate /path/to/project --skip-existing --format mp3
let batchArgs = ParseBatchArguments(
    projectPath: "/path/to/project",
    output: nil,              // Use PROJECT.md audioDir
    format: "mp3",            // Override PROJECT.md exportFormat
    skipExisting: true,       // Skip files that already have audio
    resumeFrom: nil,          // Start from beginning
    regenerate: false,        // Don't overwrite existing files
    skipHooks: false,         // Run hooks
    useCastList: true,        // Use cast list if found
    castListPath: nil,        // Auto-discover
    verbose: false,
    quiet: false,
    dryRun: false
)

// Create batch config from PROJECT.md + args
let batchConfig = try ParseBatchConfig.from(
    projectPath: batchArgs.projectPath,
    args: batchArgs
)

// Result:
// - title: "Meditations"
// - episodesDirURL: file:///path/to/project/episodes/
// - audioDirURL: file:///path/to/project/audio/
// - filePatterns: ["*.fountain"]
// - exportFormat: "mp3" (overridden from CLI)
// - discoveredFiles: [episode-001.fountain, episode-002.fountain, ...]
// - castListURL: file:///path/to/project/custom-pages.json (auto-discovered)
```

### 2. File Iterator

```swift
// Create iterator from batch config
let iterator = batchConfig.makeIterator()

// Iterator logic:
// - Filters files based on skipExisting
// - Applies resumeFrom offset
// - Yields ParseCommandArguments for each file

for parseCommand in iterator {
    // parseCommand is ready for single-file generation
    print("Processing: \(parseCommand.episodeFileURL.lastPathComponent)")
    try await generateAudio(parseCommand)
}
```

### 3. Single File Generation

```swift
// ParseCommandArguments for a SINGLE file
let parseCommand = ParseCommandArguments(
    episodeFileURL: URL(fileURLWithPath: "/path/to/project/episodes/episode-001.fountain"),
    outputURL: URL(fileURLWithPath: "/path/to/project/audio/episode-001.mp3"),
    exportFormat: "mp3",
    castListURL: URL(fileURLWithPath: "/path/to/project/custom-pages.json"),
    useCastList: true,
    verbose: false,
    quiet: false,
    dryRun: false
)

// Pass to generation engine
await generateAudio(parseCommand)

// Generation engine:
// 1. Parse parseCommand.episodeFileURL (screenplay file)
// 2. Load cast list from parseCommand.castListURL if useCastList
// 3. Generate audio for all speakable elements
// 4. Export to parseCommand.outputURL in parseCommand.exportFormat
```

---

## Object Definitions

### ParseBatchArguments (CLI-level)

```swift
/// Command-line arguments for batch generation
public struct ParseBatchArguments: Sendable, Codable {
    // Project configuration
    var projectPath: String              // Required positional
    var output: String?                  // -o/--output (override audioDir)
    var format: String?                  // -f/--format (override exportFormat)

    // Batch-level flags
    var skipExisting: Bool               // --skip-existing
    var resumeFrom: Int?                 // --resume-from N
    var regenerate: Bool                 // --regenerate (ignores skipExisting)
    var skipHooks: Bool                  // --skip-hooks

    // Voice configuration
    var useCastList: Bool                // --use-cast-list
    var castListPath: String?            // -c/--cast-list

    // Execution flags
    var verbose: Bool                    // --verbose
    var quiet: Bool                      // --quiet
    var dryRun: Bool                     // --dry-run
}
```

### ParseBatchConfig (Resolved Batch Configuration)

```swift
/// Resolved batch configuration from PROJECT.md + CLI args
public struct ParseBatchConfig: Sendable, Codable {
    // Project metadata
    var title: String
    var author: String
    var projectURL: URL

    // Directories (absolute URLs)
    var episodesDirURL: URL
    var audioDirURL: URL

    // File discovery
    var filePatterns: [String]           // From PROJECT.md
    var discoveredFiles: [URL]           // Discovered episode files

    // Generation config
    var exportFormat: String             // Resolved from PROJECT.md or CLI override

    // Hooks
    var preGenerateHook: String?
    var postGenerateHook: String?
    var skipHooks: Bool

    // Voice configuration
    var castListURL: URL?                // Resolved cast list path
    var useCastList: Bool

    // Batch flags
    var skipExisting: Bool
    var resumeFrom: Int?
    var regenerate: Bool

    // Execution flags
    var verbose: Bool
    var quiet: Bool
    var dryRun: Bool

    // Iterator factory
    func makeIterator() -> ParseFileIterator
}
```

### ParseFileIterator

```swift
/// Iterator that yields ParseCommandArguments for each file
public struct ParseFileIterator: IteratorProtocol, Sequence {
    private let batchConfig: ParseBatchConfig
    private var currentIndex: Int = 0
    private var filesToProcess: [URL]

    init(batchConfig: ParseBatchConfig) {
        self.batchConfig = batchConfig

        // Apply resumeFrom filter
        var files = batchConfig.discoveredFiles
        if let resumeFrom = batchConfig.resumeFrom {
            files = Array(files.dropFirst(resumeFrom - 1))
        }

        // Apply skipExisting filter (if not regenerating)
        if batchConfig.skipExisting && !batchConfig.regenerate {
            files = files.filter { fileURL in
                let outputURL = batchConfig.audioDirURL
                    .appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent)
                    .appendingPathExtension(batchConfig.exportFormat)
                return !FileManager.default.fileExists(atPath: outputURL.path)
            }
        }

        self.filesToProcess = files
    }

    public mutating func next() -> ParseCommandArguments? {
        guard currentIndex < filesToProcess.count else {
            return nil
        }

        let episodeFileURL = filesToProcess[currentIndex]
        currentIndex += 1

        // Build output URL
        let baseName = episodeFileURL.deletingPathExtension().lastPathComponent
        let outputURL = batchConfig.audioDirURL
            .appendingPathComponent(baseName)
            .appendingPathExtension(batchConfig.exportFormat)

        return ParseCommandArguments(
            episodeFileURL: episodeFileURL,
            outputURL: outputURL,
            exportFormat: batchConfig.exportFormat,
            castListURL: batchConfig.castListURL,
            useCastList: batchConfig.useCastList,
            verbose: batchConfig.verbose,
            quiet: batchConfig.quiet,
            dryRun: batchConfig.dryRun
        )
    }
}
```

### ParseCommandArguments (Single File)

```swift
/// Arguments for generating audio for a SINGLE screenplay file
public struct ParseCommandArguments: Sendable, Codable {
    // File paths (absolute URLs)
    var episodeFileURL: URL              // Input screenplay file
    var outputURL: URL                   // Output audio file

    // Generation config
    var exportFormat: String             // "m4a", "mp3", etc.

    // Voice configuration
    var castListURL: URL?                // Optional cast list
    var useCastList: Bool                // Use cast list if available

    // Execution flags
    var verbose: Bool
    var quiet: Bool
    var dryRun: Bool
}
```

---

## Usage Example

### CLI Tool (generate command)

```swift
@main
struct GenerateCLI: AsyncParsableCommand {
    @Argument var projectPath: String
    @Option(name: .shortAndLong) var output: String?
    @Option(name: .shortAndLong) var format: String?
    @Flag var skipExisting: Bool = false
    @Flag var regenerate: Bool = false
    @Flag var verbose: Bool = false
    @Flag var dryRun: Bool = false

    func run() async throws {
        // 1. Build batch args from CLI
        let batchArgs = ParseBatchArguments(
            projectPath: projectPath,
            output: output,
            format: format,
            skipExisting: skipExisting,
            regenerate: regenerate,
            verbose: verbose,
            dryRun: dryRun
        )

        // 2. Create batch config (reads PROJECT.md)
        let batchConfig = try ParseBatchConfig.from(
            projectPath: batchArgs.projectPath,
            args: batchArgs
        )

        // 3. Run pre-generate hook
        if batchConfig.shouldRunPreGenerateHook {
            try await runHook(batchConfig.preGenerateHook!)
        }

        // 4. Iterate files and generate
        var processedCount = 0
        var errorCount = 0

        for parseCommand in batchConfig.makeIterator() {
            print("[\(processedCount + 1)] \(parseCommand.episodeFileURL.lastPathComponent)")

            do {
                try await generateAudio(parseCommand)
                processedCount += 1
            } catch {
                print("Error: \(error)")
                errorCount += 1
            }
        }

        // 5. Run post-generate hook
        if batchConfig.shouldRunPostGenerateHook {
            try await runHook(batchConfig.postGenerateHook!)
        }

        // 6. Print summary
        print("\nProcessed: \(processedCount)")
        print("Errors: \(errorCount)")
    }
}
```

### Produciesta GUI

```swift
// User clicks "Generate All" button
let batchArgs = ParseBatchArguments(
    projectPath: project.sourceRootURL,
    skipExisting: true,
    useCastList: true,
    verbose: false
)

let batchConfig = try ParseBatchConfig.from(
    projectPath: batchArgs.projectPath,
    args: batchArgs
)

// Show progress UI
for parseCommand in batchConfig.makeIterator() {
    updateProgress("Generating \(parseCommand.episodeFileURL.lastPathComponent)...")
    try await generateAudio(parseCommand)
}

showSuccess("Generated \(batchConfig.discoveredFiles.count) episodes")
```

### Single File Generation (Produciesta)

```swift
// User clicks "Generate" on a single file
let parseCommand = ParseCommandArguments(
    episodeFileURL: fileRef.url,
    outputURL: projectConfig.audioDirURL.appendingPathComponent("episode-01.m4a"),
    exportFormat: "m4a",
    castListURL: nil,
    useCastList: false,
    verbose: true,
    dryRun: false
)

try await generateAudio(parseCommand)
```

---

## Benefits

1. **Clear separation**: Batch config (PROJECT.md-level) vs. single file command
2. **Reusable**: ParseCommandArguments works for CLI, GUI, and API
3. **Testable**: Can test iterator logic independently
4. **Flexible**: Easy to add filters (skipExisting, resumeFrom) at iterator level
5. **Type-safe**: Iterator yields fully-resolved, ready-to-use commands

---

## Key Design Principle

**The `generate` command takes a single `ParseCommandArguments` object as input.**

- `ParseCommandArguments` = single file (episodeFileURL → outputURL)
- Batch processing is handled by a **separate script/command** that:
  1. Reads PROJECT.md
  2. Creates iterator from ParseBatchConfig
  3. Yields ParseCommandArguments for each file
  4. Calls `generate` command for each ParseCommandArguments

**Separation of Concerns:**
```
┌──────────────────────┐
│ Batch Script/Command │  ← Reads PROJECT.md, iterates files
│ (batch.sh, batch cmd)│
└──────────┬───────────┘
           │ for each file:
           ▼
┌──────────────────────┐
│ generate command     │  ← Takes ParseCommandArguments
│ (single file only)   │  ← Produces one audio file
└──────────────────────┘
```

---

## Migration from Current Design

### Current State (v2.2.0)

**Files:**
- `ParseCommandArguments.swift` - Has batch-level flags (skipExisting, resumeFrom, etc.)
- `ParseConfig.swift` - Combines batch config with single-file config
- `ProjectModel+ParseConfig.swift` - Extension to create ParseConfig

**Issues:**
- ParseCommandArguments conflates batch logic with single-file generation
- No clear iterator pattern
- Hard to use for single-file generation in GUI

### Target State

**Files to Create:**
- `ParseBatchArguments.swift` - CLI batch-level flags
- `ParseBatchConfig.swift` - Resolved batch config from PROJECT.md
- `ParseFileIterator.swift` - Iterator yielding ParseCommandArguments
- `ParseCommandArguments.swift` (refactored) - Single file only
- `ProjectModel+ParseBatch.swift` - Extension to create ParseBatchConfig

**Files to Remove:**
- `ParseConfig.swift` (replaced by ParseBatchConfig)
- `ProjectModel+ParseConfig.swift` (replaced by ProjectModel+ParseBatch)

---

## Implementation Changes

### 1. Rename Current Files

**Step 1a: Rename ParseCommandArguments → ParseBatchArguments**
```swift
// OLD: Sources/SwiftProyecto/Models/ParseCommandArguments.swift
// NEW: Sources/SwiftProyecto/Models/ParseBatchArguments.swift

public struct ParseBatchArguments: Sendable, Codable {
    // Keep current structure - this is correct for batch args
    var projectPath: String
    var output: String?
    var format: String?
    var skipExisting: Bool
    var resumeFrom: Int?
    var regenerate: Bool
    var skipHooks: Bool
    var useCastList: Bool
    var castListPath: String?
    var verbose: Bool
    var quiet: Bool
    var dryRun: Bool
}
```

**Step 1b: Rename ParseConfig → ParseBatchConfig**
```swift
// OLD: Sources/SwiftProyecto/Models/ParseConfig.swift
// NEW: Sources/SwiftProyecto/Models/ParseBatchConfig.swift

public struct ParseBatchConfig: Sendable, Codable {
    // Project metadata
    var title: String
    var author: String
    var projectURL: URL

    // Directories
    var episodesDirURL: URL
    var audioDirURL: URL

    // File discovery (ADD THIS)
    var discoveredFiles: [URL]
    var filePatterns: [String]

    // Generation config
    var exportFormat: String
    var preGenerateHook: String?
    var postGenerateHook: String?

    // Batch flags
    var skipExisting: Bool
    var resumeFrom: Int?
    var regenerate: Bool
    var skipHooks: Bool
    var useCastList: Bool
    var castListURL: URL?

    // Execution flags
    var verbose: Bool
    var quiet: Bool
    var dryRun: Bool

    // ADD: Iterator factory method
    public func makeIterator() -> ParseFileIterator {
        ParseFileIterator(batchConfig: self)
    }
}
```

**Step 1c: Rename ProjectModel+ParseConfig → ProjectModel+ParseBatch**
```swift
// OLD: Sources/SwiftProyecto/Extensions/ProjectModel+ParseConfig.swift
// NEW: Sources/SwiftProyecto/Extensions/ProjectModel+ParseBatch.swift

extension ProjectModel {
    public func parseBatchConfig(with args: ParseBatchArguments?) throws -> ParseBatchConfig
}

extension ParseBatchConfig {
    public static func from(projectPath: String, args: ParseBatchArguments?) throws -> ParseBatchConfig
}
```

### 2. Create New ParseFileIterator

**File:** `Sources/SwiftProyecto/Models/ParseFileIterator.swift`

```swift
public struct ParseFileIterator: IteratorProtocol, Sequence {
    private let batchConfig: ParseBatchConfig
    private var currentIndex: Int = 0
    private let filesToProcess: [URL]

    init(batchConfig: ParseBatchConfig) {
        self.batchConfig = batchConfig

        // Apply resumeFrom filter
        var files = batchConfig.discoveredFiles
        if let resumeFrom = batchConfig.resumeFrom {
            files = Array(files.dropFirst(resumeFrom - 1))
        }

        // Apply skipExisting filter (if not regenerating)
        if batchConfig.skipExisting && !batchConfig.regenerate {
            files = files.filter { fileURL in
                let outputURL = batchConfig.audioDirURL
                    .appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent)
                    .appendingPathExtension(batchConfig.exportFormat)
                return !FileManager.default.fileExists(atPath: outputURL.path)
            }
        }

        self.filesToProcess = files
    }

    public mutating func next() -> ParseCommandArguments? {
        guard currentIndex < filesToProcess.count else {
            return nil
        }

        let episodeFileURL = filesToProcess[currentIndex]
        currentIndex += 1

        // Build output URL
        let baseName = episodeFileURL.deletingPathExtension().lastPathComponent
        let outputURL = batchConfig.audioDirURL
            .appendingPathComponent(baseName)
            .appendingPathExtension(batchConfig.exportFormat)

        return ParseCommandArguments(
            episodeFileURL: episodeFileURL,
            outputURL: outputURL,
            exportFormat: batchConfig.exportFormat,
            castListURL: batchConfig.castListURL,
            useCastList: batchConfig.useCastList,
            verbose: batchConfig.verbose,
            quiet: batchConfig.quiet,
            dryRun: batchConfig.dryRun
        )
    }
}
```

### 3. Refactor ParseCommandArguments (Single File Only)

**File:** `Sources/SwiftProyecto/Models/ParseCommandArguments.swift`

**REPLACE ENTIRE FILE** with:

```swift
//
//  ParseCommandArguments.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import Foundation

/// Arguments for generating audio for a SINGLE screenplay file.
///
/// This is the input to the `generate` command. It contains everything needed
/// to generate audio for one screenplay file and export it to one audio file.
///
/// ## Usage
///
/// ```swift
/// let parseCommand = ParseCommandArguments(
///     episodeFileURL: URL(fileURLWithPath: "/path/to/episode.fountain"),
///     outputURL: URL(fileURLWithPath: "/path/to/episode.m4a"),
///     exportFormat: "m4a",
///     castListURL: nil,
///     useCastList: false,
///     verbose: true,
///     quiet: false,
///     dryRun: false
/// )
///
/// try await generateAudio(parseCommand)
/// ```
public struct ParseCommandArguments: Sendable, Codable, Equatable {
    // MARK: - File Paths

    /// Absolute URL to the screenplay file to parse and generate audio for
    public var episodeFileURL: URL

    /// Absolute URL where the generated audio should be written
    public var outputURL: URL

    // MARK: - Generation Configuration

    /// Audio export format (e.g., "m4a", "mp3", "wav")
    public var exportFormat: String

    // MARK: - Voice Configuration

    /// Optional cast list file for voice mappings
    public var castListURL: URL?

    /// Whether to use the cast list for voice selection
    public var useCastList: Bool

    // MARK: - Execution Flags

    /// Verbose output mode
    public var verbose: Bool

    /// Quiet mode - minimal output
    public var quiet: Bool

    /// Dry run - don't actually generate, just show what would happen
    public var dryRun: Bool

    /// Initialize a ParseCommandArguments for single-file generation
    public init(
        episodeFileURL: URL,
        outputURL: URL,
        exportFormat: String = "m4a",
        castListURL: URL? = nil,
        useCastList: Bool = false,
        verbose: Bool = false,
        quiet: Bool = false,
        dryRun: Bool = false
    ) {
        self.episodeFileURL = episodeFileURL
        self.outputURL = outputURL
        self.exportFormat = exportFormat
        self.castListURL = castListURL
        self.useCastList = useCastList
        self.verbose = verbose
        self.quiet = quiet
        self.dryRun = dryRun
    }
}

// MARK: - Validation

extension ParseCommandArguments {
    /// Validate that the arguments are valid
    public func validate() throws {
        if verbose && quiet {
            throw ValidationError.mutuallyExclusive("verbose", "quiet")
        }

        if useCastList && castListURL == nil {
            throw ValidationError.missingCastList
        }
    }

    /// Validation errors
    public enum ValidationError: LocalizedError {
        case mutuallyExclusive(String, String)
        case missingCastList

        public var errorDescription: String? {
            switch self {
            case .mutuallyExclusive(let flag1, let flag2):
                return "Cannot use --\(flag1) and --\(flag2) together"
            case .missingCastList:
                return "useCastList is true but castListURL is nil"
            }
        }
    }
}
```

### 4. Add File Discovery to ParseBatchConfig

**In ParseBatchConfig.swift, ADD:**

```swift
// MARK: - File Discovery

/// Discover episode files based on filePatterns in episodesDirURL
private func discoverFiles() throws -> [URL] {
    var discovered: [URL] = []

    for pattern in filePatterns {
        if isGlobPattern(pattern) {
            // Use glob matching
            let matches = try glob(pattern: pattern, in: episodesDirURL)
            discovered.append(contentsOf: matches)
        } else {
            // Explicit filename
            let fileURL = episodesDirURL.appendingPathComponent(pattern)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                discovered.append(fileURL)
            }
        }
    }

    // Remove duplicates, sort naturally
    return Array(Set(discovered)).sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
}

private func isGlobPattern(_ pattern: String) -> Bool {
    pattern.contains("*") || pattern.contains("?")
}

private func glob(pattern: String, in directory: URL) throws -> [URL] {
    // Implementation using FileManager or glob(3)
    // For now, simple *.fountain matching
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    var matches: [URL] = []
    for case let fileURL as URL in enumerator {
        if matchesPattern(fileURL.lastPathComponent, pattern: pattern) {
            matches.append(fileURL)
        }
    }
    return matches
}

private func matchesPattern(_ filename: String, pattern: String) -> Bool {
    // Simple glob matching (*.fountain, *.fdx, etc.)
    if pattern.hasPrefix("*") {
        let suffix = String(pattern.dropFirst())
        return filename.hasSuffix(suffix)
    }
    return filename == pattern
}
```

### 5. Update ProjectModel+ParseBatch Extension

**Add file discovery call:**

```swift
extension ParseBatchConfig {
    public static func from(projectPath: String, args: ParseBatchArguments?) throws -> ParseBatchConfig {
        // ... existing code to read PROJECT.md ...

        // ADD: Discover files
        var config = ParseBatchConfig(...)
        config.discoveredFiles = try config.discoverFiles()

        return config
    }
}
```

---

## Summary of Changes

### Files to Rename
1. ✅ `ParseCommandArguments.swift` → `ParseBatchArguments.swift`
2. ✅ `ParseConfig.swift` → `ParseBatchConfig.swift`
3. ✅ `ProjectModel+ParseConfig.swift` → `ProjectModel+ParseBatch.swift`

### Files to Create
4. ✅ `ParseFileIterator.swift` - Iterator yielding single-file ParseCommandArguments
5. ✅ `ParseCommandArguments.swift` (new) - Single file only (episodeFileURL, outputURL)

### Files to Update
6. ✅ `ParseBatchConfig.swift` - Add `discoveredFiles: [URL]` field
7. ✅ `ParseBatchConfig.swift` - Add `discoverFiles()` method
8. ✅ `ParseBatchConfig.swift` - Add `makeIterator()` method
9. ✅ `ProjectModel+ParseBatch.swift` - Call `discoverFiles()` during initialization

### Breaking Changes
- ❌ `ParseCommandArguments` is now single-file only (episodeFileURL + outputURL)
- ❌ `ParseConfig` renamed to `ParseBatchConfig`
- ❌ `ProjectModel.parseConfig()` renamed to `ProjectModel.parseBatchConfig()`

### Migration Path for Consumers
**Before:**
```swift
let config = try ParseConfig.from(projectPath: path, args: args)
// config has all files mixed with batch config
```

**After:**
```swift
let batchConfig = try ParseBatchConfig.from(projectPath: path, args: args)
for parseCommand in batchConfig.makeIterator() {
    try await generateAudio(parseCommand)
}
```

---

## CLI Command Design

### generate Command (Single File)

```swift
struct GenerateCommand: AsyncParsableCommand {
    @Argument var episodeFile: String
    @Argument var outputFile: String
    @Option var format: String = "m4a"
    @Option var castList: String?
    @Flag var useCastList: Bool = false
    @Flag var verbose: Bool = false
    @Flag var quiet: Bool = false
    @Flag var dryRun: Bool = false

    func run() async throws {
        let parseCommand = ParseCommandArguments(
            episodeFileURL: URL(fileURLWithPath: episodeFile),
            outputURL: URL(fileURLWithPath: outputFile),
            exportFormat: format,
            castListURL: castList.map { URL(fileURLWithPath: $0) },
            useCastList: useCastList,
            verbose: verbose,
            quiet: quiet,
            dryRun: dryRun
        )

        try parseCommand.validate()
        try await generateAudio(parseCommand)
    }
}
```

**Usage:**
```bash
# Generate single file
generate episode.fountain episode.m4a --format m4a --verbose

# With cast list
generate episode.fountain episode.m4a --cast-list custom-pages.json --use-cast-list
```

### batch Command (Multi-File via Iterator)

```swift
struct BatchCommand: AsyncParsableCommand {
    @Argument var projectPath: String
    @Option var output: String?
    @Option var format: String?
    @Flag var skipExisting: Bool = false
    @Flag var regenerate: Bool = false
    @Flag var useCastList: Bool = false
    @Flag var verbose: Bool = false
    @Flag var dryRun: Bool = false

    func run() async throws {
        let batchArgs = ParseBatchArguments(
            projectPath: projectPath,
            output: output,
            format: format,
            skipExisting: skipExisting,
            regenerate: regenerate,
            useCastList: useCastList,
            verbose: verbose,
            dryRun: dryRun
        )

        let batchConfig = try ParseBatchConfig.from(
            projectPath: batchArgs.projectPath,
            args: batchArgs
        )

        // Run pre-generate hook
        if batchConfig.shouldRunPreGenerateHook {
            try await runHook(batchConfig.preGenerateHook!)
        }

        // Iterate and generate
        var count = 0
        for parseCommand in batchConfig.makeIterator() {
            print("[\(count + 1)] \(parseCommand.episodeFileURL.lastPathComponent)")
            try await generateAudio(parseCommand)
            count += 1
        }

        // Run post-generate hook
        if batchConfig.shouldRunPostGenerateHook {
            try await runHook(batchConfig.postGenerateHook!)
        }

        print("Generated \(count) files")
    }
}
```

**Usage:**
```bash
# Batch generate all files
batch /path/to/project --skip-existing --verbose

# Override format
batch /path/to/project --format mp3 --use-cast-list
```

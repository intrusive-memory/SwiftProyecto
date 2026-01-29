# SwiftProyecto Enhancement for Produciesta CLI Support

## Context

Produciesta is building a headless CLI tool (`generate`) that needs PROJECT.md to store configuration for audio generation. This requires enhancing SwiftProyecto's `ProjectFrontMatter` model with new fields.

**Related Document**: `/Users/stovak/Projects/Produciesta/Docs/HEADLESS_CLI_REQUIREMENTS_V2.md`

**Priority**: This work is **blocking** for Produciesta CLI implementation (Phase 0 prerequisite).

## Overview

Add 7 new fields to `ProjectFrontMatter` for audio generation configuration:
1. `episodesDir` - Path to episode files
2. `audioDir` - Path for audio output
3. `filePattern` - Glob pattern(s) for file discovery
4. `exportFormat` - Audio export format
5. `castList` - Path to voice casting file
6. `preGenerateHook` - Shell command before generation
7. `postGenerateHook` - Shell command after generation

## Tasks

### 1. Add New Fields to ProjectFrontMatter

**File**: `Sources/SwiftProyecto/Models/ProjectFrontMatter.swift`

Add these fields to the struct:

```swift
public struct ProjectFrontMatter: Codable, Sendable, Equatable {
    // ... existing fields (type, title, author, created, description, season, episodes, genre, tags)

    // MARK: - Audio Generation Configuration (for Produciesta CLI)

    /// Relative path to episode files (default: "episodes")
    public let episodesDir: String?

    /// Relative path for audio output (default: "audio")
    public let audioDir: String?

    /// Glob pattern(s) for file discovery (default: ["*.fountain"])
    /// Can be String or [String]
    public let filePattern: FilePattern?

    /// Audio export format (default: "m4a")
    /// Valid values: m4a, aiff, wav, caf, mp3
    public let exportFormat: String?

    /// Path to cast list file (custom-pages.json format)
    /// Relative to project root
    public let castList: String?

    /// Shell command to run before audio generation
    public let preGenerateHook: String?

    /// Shell command to run after audio generation
    public let postGenerateHook: String?
}
```

**Update initializer** to include new fields:

```swift
public init(
    type: String = "project",
    title: String,
    author: String,
    created: Date = Date(),
    description: String? = nil,
    season: Int? = nil,
    episodes: Int? = nil,
    genre: String? = nil,
    tags: [String]? = nil,
    // New fields
    episodesDir: String? = nil,
    audioDir: String? = nil,
    filePattern: FilePattern? = nil,
    exportFormat: String? = nil,
    castList: String? = nil,
    preGenerateHook: String? = nil,
    postGenerateHook: String? = nil
) {
    self.type = type
    self.title = title
    self.author = author
    self.created = created
    self.description = description
    self.season = season
    self.episodes = episodes
    self.genre = genre
    self.tags = tags
    // New fields
    self.episodesDir = episodesDir
    self.audioDir = audioDir
    self.filePattern = filePattern
    self.exportFormat = exportFormat
    self.castList = castList
    self.preGenerateHook = preGenerateHook
    self.postGenerateHook = postGenerateHook
}
```

### 2. Implement FilePattern Type

**File**: `Sources/SwiftProyecto/Models/FilePattern.swift` (new file)

Create a custom Codable type that accepts either String or [String]:

```swift
import Foundation

/// Represents file pattern(s) for episode discovery.
///
/// Can be initialized from:
/// - Single string: `"*.fountain"`
/// - Array of strings: `["*.fountain", "*.fdx"]`
/// - Mixed: `["intro.fountain", "chapter-*.fountain", "outro.fountain"]`
///
/// Internally normalizes to array of strings for consistent handling.
public struct FilePattern: Codable, Sendable, Equatable {
    /// Array of file patterns (globs or explicit filenames)
    public let patterns: [String]

    public init(patterns: [String]) {
        self.patterns = patterns
    }

    public init(pattern: String) {
        self.patterns = [pattern]
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let singlePattern = try? container.decode(String.self) {
            // Single string: "*.fountain"
            self.patterns = [singlePattern]
        } else if let multiplePatterns = try? container.decode([String].self) {
            // Array: ["*.fountain", "*.fdx"]
            self.patterns = multiplePatterns
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "FilePattern must be a String or [String]"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if patterns.count == 1 {
            // Encode as single string for cleaner YAML
            try container.encode(patterns[0])
        } else {
            // Encode as array
            try container.encode(patterns)
        }
    }
}
```

### 3. Add discoverCastList Helper

**File**: `Sources/SwiftProyecto/Services/ProjectService.swift`

Add extension with helper function:

```swift
// MARK: - Cast List Discovery

public extension ProjectService {
    /// Discover custom-pages.json file in project directory.
    ///
    /// Searches recursively for a file named "custom-pages.json" and returns
    /// its path relative to the project root.
    ///
    /// - Parameter projectURL: The project root directory to search
    /// - Returns: Relative path to custom-pages.json, or nil if not found
    ///
    /// ## Example
    /// ```swift
    /// let projectURL = URL(fileURLWithPath: "/path/to/project")
    /// if let castListPath = projectService.discoverCastList(in: projectURL) {
    ///     print(castListPath)  // "episodes/custom-pages.json"
    /// }
    /// ```
    func discoverCastList(in projectURL: URL) -> String? {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: projectURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        while let url = enumerator.nextObject() as? URL {
            if url.lastPathComponent == "custom-pages.json" {
                // Return path relative to project root
                let relativePath = url.path.replacingOccurrences(
                    of: projectURL.path + "/",
                    with: ""
                )
                return relativePath
            }
        }

        return nil
    }
}
```

### 4. Update ProjectMarkdownParser

**File**: `Sources/SwiftProyecto/Utilities/ProjectMarkdownParser.swift`

**Update `generate()` method** to include new fields:

```swift
public func generate(frontMatter: ProjectFrontMatter, body: String = "") -> String {
    var yaml = "---\n"
    yaml += "type: \(frontMatter.type)\n"
    yaml += "title: \(frontMatter.title)\n"
    yaml += "author: \(frontMatter.author)\n"
    yaml += "created: \(ISO8601DateFormatter().string(from: frontMatter.created))\n"

    if let description = frontMatter.description {
        yaml += "description: \(description)\n"
    }
    if let season = frontMatter.season {
        yaml += "season: \(season)\n"
    }
    if let episodes = frontMatter.episodes {
        yaml += "episodes: \(episodes)\n"
    }
    if let genre = frontMatter.genre {
        yaml += "genre: \(genre)\n"
    }
    if let tags = frontMatter.tags {
        yaml += "tags: [\(tags.joined(separator: ", "))]\n"
    }

    // NEW: Generation configuration fields
    if let episodesDir = frontMatter.episodesDir {
        yaml += "episodesDir: \(episodesDir)\n"
    }
    if let audioDir = frontMatter.audioDir {
        yaml += "audioDir: \(audioDir)\n"
    }
    if let filePattern = frontMatter.filePattern {
        if filePattern.patterns.count == 1 {
            yaml += "filePattern: \"\(filePattern.patterns[0])\"\n"
        } else {
            yaml += "filePattern: [\(filePattern.patterns.map { "\"\($0)\"" }.joined(separator: ", "))]\n"
        }
    }
    if let exportFormat = frontMatter.exportFormat {
        yaml += "exportFormat: \(exportFormat)\n"
    }
    if let castList = frontMatter.castList {
        yaml += "castList: \(castList)\n"
    }
    if let preGenerateHook = frontMatter.preGenerateHook {
        // Handle multiline strings (YAML literal block)
        if preGenerateHook.contains("\n") {
            yaml += "preGenerateHook: |\n"
            yaml += preGenerateHook.split(separator: "\n").map { "  \($0)" }.joined(separator: "\n")
            yaml += "\n"
        } else {
            yaml += "preGenerateHook: \"\(preGenerateHook)\"\n"
        }
    }
    if let postGenerateHook = frontMatter.postGenerateHook {
        // Handle multiline strings (YAML literal block)
        if postGenerateHook.contains("\n") {
            yaml += "postGenerateHook: |\n"
            yaml += postGenerateHook.split(separator: "\n").map { "  \($0)" }.joined(separator: "\n")
            yaml += "\n"
        } else {
            yaml += "postGenerateHook: \"\(postGenerateHook)\"\n"
        }
    }

    yaml += "---\n"

    if !body.isEmpty {
        yaml += "\n\(body)\n"
    }

    return yaml
}
```

**Note**: Parsing is automatic via UNIVERSAL's Codable support - no changes needed to `parse()` method.

### 5. Add Tests

**File**: `Tests/SwiftProyectoTests/ProjectFrontMatterTests.swift` (new file)

```swift
import XCTest
@testable import SwiftProyecto

final class ProjectFrontMatterTests: XCTestCase {

    // MARK: - FilePattern Tests

    func testFilePatternSingleString() throws {
        let yaml = """
        ---
        type: project
        title: Test
        author: Test Author
        created: 2025-01-01T00:00:00Z
        filePattern: "*.fountain"
        ---
        """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        XCTAssertEqual(frontMatter.filePattern?.patterns, ["*.fountain"])
    }

    func testFilePatternArray() throws {
        let yaml = """
        ---
        type: project
        title: Test
        author: Test Author
        created: 2025-01-01T00:00:00Z
        filePattern: ["*.fountain", "*.fdx"]
        ---
        """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        XCTAssertEqual(frontMatter.filePattern?.patterns, ["*.fountain", "*.fdx"])
    }

    func testFilePatternMixed() throws {
        let yaml = """
        ---
        type: project
        title: Test
        author: Test Author
        created: 2025-01-01T00:00:00Z
        filePattern: ["intro.fountain", "chapter-*.fountain", "outro.fountain"]
        ---
        """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        XCTAssertEqual(frontMatter.filePattern?.patterns, ["intro.fountain", "chapter-*.fountain", "outro.fountain"])
    }

    // MARK: - Generation Config Tests

    func testParsingGenerationFields() throws {
        let yaml = """
        ---
        type: project
        title: Test
        author: Test Author
        created: 2025-01-01T00:00:00Z
        episodesDir: episodes
        audioDir: audio
        filePattern: "*.fountain"
        exportFormat: m4a
        castList: episodes/custom-pages.json
        ---
        """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        XCTAssertEqual(frontMatter.episodesDir, "episodes")
        XCTAssertEqual(frontMatter.audioDir, "audio")
        XCTAssertEqual(frontMatter.filePattern?.patterns, ["*.fountain"])
        XCTAssertEqual(frontMatter.exportFormat, "m4a")
        XCTAssertEqual(frontMatter.castList, "episodes/custom-pages.json")
    }

    func testParsingOptionalGenerationFields() throws {
        let yaml = """
        ---
        type: project
        title: Test
        author: Test Author
        created: 2025-01-01T00:00:00Z
        ---
        """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        XCTAssertNil(frontMatter.episodesDir)
        XCTAssertNil(frontMatter.audioDir)
        XCTAssertNil(frontMatter.filePattern)
        XCTAssertNil(frontMatter.exportFormat)
        XCTAssertNil(frontMatter.castList)
    }

    // MARK: - Hook Tests

    func testParsingSimpleHook() throws {
        let yaml = """
        ---
        type: project
        title: Test
        author: Test Author
        created: 2025-01-01T00:00:00Z
        preGenerateHook: "./scripts/prepare.sh"
        postGenerateHook: "./scripts/upload.sh"
        ---
        """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        XCTAssertEqual(frontMatter.preGenerateHook, "./scripts/prepare.sh")
        XCTAssertEqual(frontMatter.postGenerateHook, "./scripts/upload.sh")
    }

    func testParsingMultilineHook() throws {
        let yaml = """
        ---
        type: project
        title: Test
        author: Test Author
        created: 2025-01-01T00:00:00Z
        preGenerateHook: |
          echo "Starting..."
          ./scripts/prepare.sh
        ---
        """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        XCTAssertNotNil(frontMatter.preGenerateHook)
        XCTAssertTrue(frontMatter.preGenerateHook!.contains("echo"))
        XCTAssertTrue(frontMatter.preGenerateHook!.contains("prepare.sh"))
    }

    // MARK: - Round-Trip Tests

    func testRoundTrip() throws {
        let original = ProjectFrontMatter(
            title: "Test Project",
            author: "Test Author",
            created: Date(),
            episodesDir: "episodes",
            audioDir: "audio",
            filePattern: FilePattern(patterns: ["*.fountain", "*.fdx"]),
            exportFormat: "m4a",
            castList: "episodes/custom-pages.json",
            preGenerateHook: "./scripts/prepare.sh",
            postGenerateHook: "./scripts/upload.sh"
        )

        let parser = ProjectMarkdownParser()
        let generated = parser.generate(frontMatter: original, body: "")
        let (parsed, _) = try parser.parse(content: generated)

        XCTAssertEqual(parsed.title, original.title)
        XCTAssertEqual(parsed.author, original.author)
        XCTAssertEqual(parsed.episodesDir, original.episodesDir)
        XCTAssertEqual(parsed.audioDir, original.audioDir)
        XCTAssertEqual(parsed.filePattern?.patterns, original.filePattern?.patterns)
        XCTAssertEqual(parsed.exportFormat, original.exportFormat)
        XCTAssertEqual(parsed.castList, original.castList)
        XCTAssertEqual(parsed.preGenerateHook, original.preGenerateHook)
        XCTAssertEqual(parsed.postGenerateHook, original.postGenerateHook)
    }
}
```

**File**: `Tests/SwiftProyectoTests/ProjectServiceCastListTests.swift` (new file)

```swift
import XCTest
@testable import SwiftProyecto

final class ProjectServiceCastListTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testDiscoverCastListInRoot() throws {
        // Create custom-pages.json in root
        let castListURL = tempDirectory.appendingPathComponent("custom-pages.json")
        try "[]".write(to: castListURL, atomically: true, encoding: .utf8)

        let projectService = ProjectService(modelContext: nil)
        let result = projectService.discoverCastList(in: tempDirectory)

        XCTAssertEqual(result, "custom-pages.json")
    }

    func testDiscoverCastListInSubdirectory() throws {
        // Create episodes directory
        let episodesDir = tempDirectory.appendingPathComponent("episodes")
        try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)

        // Create custom-pages.json in episodes
        let castListURL = episodesDir.appendingPathComponent("custom-pages.json")
        try "[]".write(to: castListURL, atomically: true, encoding: .utf8)

        let projectService = ProjectService(modelContext: nil)
        let result = projectService.discoverCastList(in: tempDirectory)

        XCTAssertEqual(result, "episodes/custom-pages.json")
    }

    func testDiscoverCastListNotFound() throws {
        let projectService = ProjectService(modelContext: nil)
        let result = projectService.discoverCastList(in: tempDirectory)

        XCTAssertNil(result)
    }

    func testDiscoverCastListFindsFirstMatch() throws {
        // Create multiple custom-pages.json files
        let episodesDir = tempDirectory.appendingPathComponent("episodes")
        try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)

        let rootCastList = tempDirectory.appendingPathComponent("custom-pages.json")
        let episodesCastList = episodesDir.appendingPathComponent("custom-pages.json")

        try "[]".write(to: rootCastList, atomically: true, encoding: .utf8)
        try "[]".write(to: episodesCastList, atomically: true, encoding: .utf8)

        let projectService = ProjectService(modelContext: nil)
        let result = projectService.discoverCastList(in: tempDirectory)

        // Should find one of them (order may vary)
        XCTAssertNotNil(result)
        XCTAssertTrue(result == "custom-pages.json" || result == "episodes/custom-pages.json")
    }
}
```

### 6. Update Documentation

**File**: `CHANGELOG.md`

Add entry for new version:

```markdown
## [2.1.0] - 2026-01-XX

### Added
- **Audio Generation Configuration**: Added new optional fields to `ProjectFrontMatter` for Produciesta CLI support:
  - `episodesDir`: Relative path to episode files (default: "episodes")
  - `audioDir`: Relative path for audio output (default: "audio")
  - `filePattern`: Glob pattern(s) for file discovery (accepts String or [String])
  - `exportFormat`: Audio export format (default: "m4a")
  - `castList`: Path to cast list file (custom-pages.json format)
  - `preGenerateHook`: Shell command to run before generation
  - `postGenerateHook`: Shell command to run after generation
- **FilePattern Type**: Custom Codable type that accepts either String or [String] for flexible file pattern specification
- **Cast List Discovery**: Added `discoverCastList(in:)` helper to `ProjectService` for finding custom-pages.json files

### Changed
- `ProjectMarkdownParser.generate()` now includes new generation configuration fields in output
- `ProjectFrontMatter` initializer includes new optional parameters for generation configuration

### Notes
- All new fields are optional and backward-compatible
- YAML parsing automatically handles new fields via UNIVERSAL library
- Multiline hook commands use YAML literal block syntax (|)
```

**File**: `README.md`

Add section documenting new fields:

```markdown
## Audio Generation Configuration (Produciesta CLI)

SwiftProyecto supports additional optional fields in PROJECT.md for audio generation configuration:

```yaml
---
type: project
title: My Podcast
author: Jane Doe
created: 2025-01-01T00:00:00Z

# Audio generation config (all optional)
episodesDir: episodes          # Path to episode files
audioDir: audio                # Path for audio output
filePattern: "*.fountain"      # File discovery pattern(s)
exportFormat: m4a              # Audio export format
castList: episodes/custom-pages.json  # Voice casting file

# Hooks (optional)
preGenerateHook: "./scripts/prepare.sh"
postGenerateHook: "./scripts/upload.sh"
---
```

### Cast List Discovery

Use the `discoverCastList(in:)` helper to find custom-pages.json files:

```swift
let projectService = ProjectService(modelContext: context)
if let castListPath = projectService.discoverCastList(in: projectURL) {
    print("Found cast list: \(castListPath)")
}
```
```

### 7. Version Bump and Release

- [ ] Update version in `Sources/SwiftProyecto/SwiftProyecto.swift` to `2.1.0`
- [ ] Update version in `Package.swift` if applicable
- [ ] Commit all changes to `development` branch
- [ ] Create PR to `main` branch
- [ ] Wait for CI to pass
- [ ] Merge PR
- [ ] Tag release: `git tag v2.1.0`
- [ ] Push tag: `git push origin v2.1.0`
- [ ] Create GitHub release from tag

## Testing Checklist

- [ ] Unit tests pass for FilePattern (single string, array, mixed)
- [ ] Unit tests pass for new ProjectFrontMatter fields
- [ ] Unit tests pass for hook parsing (simple and multiline)
- [ ] Unit tests pass for discoverCastList() helper
- [ ] Round-trip test passes (parse → generate → parse)
- [ ] Test with actual PROJECT.md files from Produciesta
- [ ] Verify YAML generation is properly formatted
- [ ] Verify multiline hooks use literal block syntax
- [ ] Test backward compatibility (existing PROJECT.md files still parse)

## Example PROJECT.md for Testing

```yaml
---
type: project
title: Daily Dao - Tao De Jing Podcast
author: Tom Stovall
created: 2025-11-21T20:06:59Z
description: Daily readings from the Tao De Jing
season: 1
episodes: 81
genre: Philosophy
tags: [taoism, philosophy, meditation]

# Generation config
episodesDir: episodes
audioDir: audio
filePattern: "*.fountain"
exportFormat: m4a
castList: episodes/custom-pages.json

# Hooks
preGenerateHook: "./scripts/generate-fountain.sh"
postGenerateHook: "./scripts/upload-to-cdn.sh"
---

# Production Notes

This is a daily podcast series covering all 81 chapters of the Tao De Jing.
```

## Notes

- **Backward Compatibility**: All new fields are optional and will not break existing PROJECT.md files
- **UNIVERSAL Dependency**: No changes needed to YAML parsing - UNIVERSAL handles new fields automatically via Codable
- **Multiline Handling**: Use YAML literal block syntax (`|`) for multiline hook commands
- **FilePattern Flexibility**: Accepts both `"*.fountain"` and `["*.fountain", "*.fdx"]` syntax
- **Cast List Discovery**: Helper function returns relative path for storing in PROJECT.md

## Questions?

If you have questions about these requirements, refer to:
- `/Users/stovak/Projects/Produciesta/Docs/HEADLESS_CLI_REQUIREMENTS_V2.md`
- SwiftProyecto CLAUDE.md for architecture context

## Success Criteria

- [ ] All new fields parse correctly from YAML
- [ ] All new fields generate correctly to YAML
- [ ] FilePattern accepts both String and [String]
- [ ] discoverCastList() finds custom-pages.json files
- [ ] Tests pass (100% coverage for new code)
- [ ] Backward compatibility maintained
- [ ] Documentation updated
- [ ] Released as v2.1.0

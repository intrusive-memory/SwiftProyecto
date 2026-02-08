//
//  DocumentationExamplesTests.swift
//  SwiftProyecto
//
//  Tests that validate every code example in Docs/EXTENDING_PROJECT_MD.md works correctly.
//  This ensures our documentation is accurate and can be trusted by users.
//

import Foundation
import Testing
@testable import SwiftProyecto

/// Tests that validate all code examples from EXTENDING_PROJECT_MD.md
///
/// These tests serve as living documentation - if they pass, the guide is accurate.
/// Each test corresponds to specific examples in the guide.
@Suite("Documentation Examples Validation")
struct DocumentationExamplesTests {

    // MARK: - Settings Types from Guide

    /// MyAppSettings from Quick Start section (lines 103-110)
    private struct MyAppSettings: AppFrontMatterSettings {
        static let sectionKey = "myapp"

        var theme: String?
        var autoSave: Bool?
        var exportFormat: String?
    }

    /// PodcastAppSettings from Complete Example section (lines 270-296)
    private struct PodcastAppSettings: AppFrontMatterSettings {
        static let sectionKey = "podcast"

        // Audio settings
        var sampleRate: Int?
        var bitRate: Int?
        var format: AudioFormat?

        // Chapters
        var chapters: [Chapter]?

        // Export
        var includeMetadata: Bool?
        var coverArtPath: String?

        enum AudioFormat: String, Codable, Sendable {
            case mp3
            case aac
            case flac
        }

        struct Chapter: Codable, Equatable, Sendable {
            var title: String
            var startTime: Double
            var endTime: Double
        }
    }

    /// VersionedSettings from Best Practices section (lines 416-437)
    private struct VersionedSettings: AppFrontMatterSettings {
        static let sectionKey = "versioned"

        var version: Int?
        var theme: String?
    }

    /// NestedSettings from Common Patterns section (lines 528-549)
    private struct NestedSettings: AppFrontMatterSettings {
        static let sectionKey = "nested"

        var ui: UISettings?
        var export: ExportSettings?
        var generation: GenerationSettings?

        struct UISettings: Codable, Equatable, Sendable {
            var theme: String?
            var fontSize: Int?
        }

        struct ExportSettings: Codable, Equatable, Sendable {
            var format: String?
            var quality: Int?
        }

        struct GenerationSettings: Codable, Equatable, Sendable {
            var enabled: Bool?
            var model: String?
        }
    }

    // MARK: - Quick Start Validation (3 tests)

    /// Validates that MyAppSettings compiles and conforms to AppFrontMatterSettings
    /// Reference: Guide lines 103-110
    @Test("Quick Start: Define Settings")
    func quickStartDefineSettings() throws {
        let settings = MyAppSettings(
            theme: "dark",
            autoSave: true,
            exportFormat: "pdf"
        )

        // Verify settings structure works
        #expect(settings.theme == "dark")
        #expect(settings.autoSave == true)
        #expect(settings.exportFormat == "pdf")
        #expect(MyAppSettings.sectionKey == "myapp")
    }

    /// Validates reading settings example from guide
    /// Reference: Guide lines 114-121
    @Test("Quick Start: Read Settings")
    func quickStartReadSettings() throws {
        // Create PROJECT.md with settings
        let yamlContent = """
        ---
        type: project
        title: "My Project"
        author: "Test Author"
        created: 2025-01-01T00:00:00Z
        myapp:
          theme: "dark"
          autoSave: true
          exportFormat: "pdf"
        ---

        # Description
        """

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try yamlContent.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Example code from guide (lines 115-120)
        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(fileURL: tempURL)

        if let settings = try frontMatter.settings(for: MyAppSettings.self) {
            #expect(settings.theme == "dark")
            #expect(settings.autoSave == true)
            #expect(settings.exportFormat == "pdf")
        } else {
            Issue.record("Settings should exist")
        }
    }

    /// Validates writing settings example from guide
    /// Reference: Guide lines 125-137
    @Test("Quick Start: Write Settings")
    func quickStartWriteSettings() throws {
        // Example code from guide (lines 126-133)
        var frontMatter = ProjectFrontMatter(title: "My Project", author: "Test Author")

        let settings = MyAppSettings(
            theme: "dark",
            autoSave: true,
            exportFormat: "pdf"
        )
        try frontMatter.setSettings(settings)

        let parser = ProjectMarkdownParser()
        let content = parser.generate(frontMatter: frontMatter, body: "# Description")

        // Verify YAML contains settings (line 136-137 pattern)
        #expect(content.contains("myapp:"))
        #expect(content.contains("theme: dark"))
        #expect(content.contains("autoSave: true"))
        #expect(content.contains("exportFormat: pdf"))

        // Verify round-trip works
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try content.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let (parsedFrontMatter, _) = try parser.parse(fileURL: tempURL)
        let parsedSettings = try parsedFrontMatter.settings(for: MyAppSettings.self)

        #expect(parsedSettings?.theme == "dark")
        #expect(parsedSettings?.autoSave == true)
        #expect(parsedSettings?.exportFormat == "pdf")
    }

    // MARK: - Podcast Example Validation (4 tests)

    /// Validates PodcastAppSettings with nested types works
    /// Reference: Guide lines 270-296
    @Test("Podcast: Settings Structure")
    func podcastSettingsStructure() throws {
        let settings = PodcastAppSettings(
            sampleRate: 44100,
            bitRate: 128,
            format: .mp3,
            chapters: [
                PodcastAppSettings.Chapter(
                    title: "Introduction",
                    startTime: 0,
                    endTime: 120
                ),
                PodcastAppSettings.Chapter(
                    title: "Chapter 1",
                    startTime: 120,
                    endTime: 600
                )
            ],
            includeMetadata: true,
            coverArtPath: "assets/cover.jpg"
        )

        // Verify structure
        #expect(settings.sampleRate == 44100)
        #expect(settings.bitRate == 128)
        #expect(settings.format == .mp3)
        #expect(settings.chapters?.count == 2)
        #expect(settings.chapters?[0].title == "Introduction")
        #expect(settings.chapters?[0].startTime == 0)
        #expect(settings.chapters?[0].endTime == 120)
        #expect(settings.includeMetadata == true)
        #expect(settings.coverArtPath == "assets/cover.jpg")
        #expect(PodcastAppSettings.sectionKey == "podcast")
    }

    /// Validates generated YAML matches guide example
    /// Reference: Guide lines 302-319
    @Test("Podcast: YAML Output")
    func podcastYAMLOutput() throws {
        let settings = PodcastAppSettings(
            sampleRate: 44100,
            bitRate: 128,
            format: .mp3,
            chapters: [
                PodcastAppSettings.Chapter(
                    title: "Introduction",
                    startTime: 0,
                    endTime: 120
                ),
                PodcastAppSettings.Chapter(
                    title: "Chapter 1",
                    startTime: 120,
                    endTime: 600
                )
            ],
            includeMetadata: true,
            coverArtPath: "assets/cover.jpg"
        )

        var frontMatter = ProjectFrontMatter(
            type: "project",
            title: "My Podcast",
            author: "Test Author"
        )
        try frontMatter.setSettings(settings)

        let parser = ProjectMarkdownParser()
        let yaml = parser.generate(frontMatter: frontMatter, body: "")

        // Verify YAML structure matches guide example (lines 302-319)
        #expect(yaml.contains("podcast:"))
        #expect(yaml.contains("sampleRate: 44100"))
        #expect(yaml.contains("bitRate: 128"))
        #expect(yaml.contains("format: mp3"))
        #expect(yaml.contains("chapters:"))
        #expect(yaml.contains("title: Introduction"))
        #expect(yaml.contains("startTime: 0"))
        #expect(yaml.contains("endTime: 120"))
        #expect(yaml.contains("title: Chapter 1"))
        #expect(yaml.contains("startTime: 120"))
        #expect(yaml.contains("endTime: 600"))
        #expect(yaml.contains("includeMetadata: true"))
        #expect(yaml.contains("coverArtPath: assets/cover.jpg"))
    }

    /// Validates createProject() example from guide
    /// Reference: Guide lines 326-342
    @Test("Podcast: Create Project")
    func podcastCreateProject() throws {
        // Example code from guide (lines 326-342)
        func createProject(title: String, settings: PodcastAppSettings) throws -> String {
            var frontMatter = ProjectFrontMatter(
                type: "project",
                title: title,
                author: "Test Author"
            )
            try frontMatter.setSettings(settings)

            let parser = ProjectMarkdownParser()
            let content = parser.generate(
                frontMatter: frontMatter,
                body: "# My Podcast\n\nDescription here."
            )

            return content
        }

        let settings = PodcastAppSettings(
            sampleRate: 44100,
            bitRate: 128,
            format: .mp3,
            includeMetadata: true
        )

        let content = try createProject(title: "Test Podcast", settings: settings)

        // Verify output
        #expect(content.contains("title: Test Podcast"))
        #expect(content.contains("podcast:"))
        #expect(content.contains("sampleRate: 44100"))
        #expect(content.contains("# My Podcast"))
        #expect(content.contains("Description here."))
    }

    /// Validates loadProject() example from guide
    /// Reference: Guide lines 345-360
    @Test("Podcast: Load Project")
    func podcastLoadProject() throws {
        // Example code from guide (lines 345-360)
        func loadProject(from url: URL) throws -> PodcastAppSettings {
            let parser = ProjectMarkdownParser()
            let (frontMatter, _) = try parser.parse(fileURL: url)

            if let settings = try frontMatter.settings(for: PodcastAppSettings.self) {
                return settings
            } else {
                // Return defaults for legacy projects (lines 352-358)
                return PodcastAppSettings(
                    sampleRate: 44100,
                    bitRate: 128,
                    format: .mp3,
                    includeMetadata: true
                )
            }
        }

        // Test with settings present
        let yamlWithSettings = """
        ---
        type: project
        title: "My Podcast"
        author: "Test Author"
        created: 2025-01-01T00:00:00Z
        podcast:
          sampleRate: 48000
          bitRate: 256
          format: "aac"
        ---

        # Podcast
        """

        let tempURL1 = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try yamlWithSettings.write(to: tempURL1, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempURL1) }

        let settings1 = try loadProject(from: tempURL1)
        #expect(settings1.sampleRate == 48000)
        #expect(settings1.bitRate == 256)
        #expect(settings1.format == .aac)

        // Test with no settings (legacy project)
        let yamlWithoutSettings = """
        ---
        type: project
        title: "Legacy Podcast"
        author: "Test Author"
        created: 2025-01-01T00:00:00Z
        ---

        # Podcast
        """

        let tempURL2 = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try yamlWithoutSettings.write(to: tempURL2, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempURL2) }

        let settings2 = try loadProject(from: tempURL2)
        #expect(settings2.sampleRate == 44100)  // Default
        #expect(settings2.bitRate == 128)       // Default
        #expect(settings2.format == .mp3)       // Default
        #expect(settings2.includeMetadata == true)  // Default
    }

    // MARK: - Best Practices Patterns (6 tests)

    /// Validates static .default extension pattern
    /// Reference: Guide lines 398-411
    @Test("Best Practice: Defaults Pattern")
    func bestPracticeDefaultsPattern() throws {
        // Test the .default pattern from guide (lines 399-407)
        let defaultSettings = MyAppSettings(
            theme: "light",
            autoSave: true,
            exportFormat: "pdf"
        )

        // Usage pattern from line 410
        let frontMatter = ProjectFrontMatter(title: "Test", author: "Test Author")
        let settings = try frontMatter.settings(for: MyAppSettings.self) ?? defaultSettings

        #expect(settings.theme == "light")
        #expect(settings.autoSave == true)
        #expect(settings.exportFormat == "pdf")

        // Verify defaults are used when settings don't exist
        let yamlContent = """
        ---
        type: project
        title: "Test"
        author: "Test Author"
        created: 2025-01-01T00:00:00Z
        ---
        """

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try yamlContent.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parser = ProjectMarkdownParser()
        let (parsedFrontMatter, _) = try parser.parse(fileURL: tempURL)
        let loadedSettings = try parsedFrontMatter.settings(for: MyAppSettings.self) ?? defaultSettings

        #expect(loadedSettings.theme == "light")
        #expect(loadedSettings.autoSave == true)
    }

    /// Validates versioning pattern from guide
    /// Reference: Guide lines 416-437
    @Test("Best Practice: Versioning Pattern")
    func bestPracticeVersioningPattern() throws {
        let settings = VersionedSettings(
            version: 2,
            theme: "dark"
        )

        var frontMatter = ProjectFrontMatter(title: "Test", author: "Test Author")
        try frontMatter.setSettings(settings)

        let parser = ProjectMarkdownParser()
        let yaml = parser.generate(frontMatter: frontMatter, body: "")

        // Verify version field is preserved
        #expect(yaml.contains("versioned:"))
        #expect(yaml.contains("version: 2"))
        #expect(yaml.contains("theme: dark"))

        // Round-trip verification
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try yaml.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let (parsedFrontMatter, _) = try parser.parse(fileURL: tempURL)
        let parsedSettings = try parsedFrontMatter.settings(for: VersionedSettings.self)

        #expect(parsedSettings?.version == 2)
        #expect(parsedSettings?.theme == "dark")
    }

    /// Validates nested structures pattern
    /// Reference: Guide lines 528-565
    @Test("Best Practice: Nested Structures")
    func bestPracticeNestedStructures() throws {
        let settings = NestedSettings(
            ui: NestedSettings.UISettings(
                theme: "dark",
                fontSize: 14
            ),
            export: NestedSettings.ExportSettings(
                format: "pdf",
                quality: 100
            ),
            generation: NestedSettings.GenerationSettings(
                enabled: true,
                model: "gpt-4"
            )
        )

        var frontMatter = ProjectFrontMatter(title: "Test", author: "Test Author")
        try frontMatter.setSettings(settings)

        let parser = ProjectMarkdownParser()
        let yaml = parser.generate(frontMatter: frontMatter, body: "")

        // Verify YAML structure matches guide example (lines 554-565)
        #expect(yaml.contains("nested:"))
        #expect(yaml.contains("ui:"))
        #expect(yaml.contains("theme: dark"))
        #expect(yaml.contains("fontSize: 14"))
        #expect(yaml.contains("export:"))
        #expect(yaml.contains("format: pdf"))
        #expect(yaml.contains("quality: 100"))
        #expect(yaml.contains("generation:"))
        #expect(yaml.contains("enabled: true"))
        #expect(yaml.contains("model: gpt-4"))

        // Round-trip verification
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try yaml.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let (parsedFrontMatter, _) = try parser.parse(fileURL: tempURL)
        let parsedSettings = try parsedFrontMatter.settings(for: NestedSettings.self)

        #expect(parsedSettings?.ui?.theme == "dark")
        #expect(parsedSettings?.ui?.fontSize == 14)
        #expect(parsedSettings?.export?.format == "pdf")
        #expect(parsedSettings?.export?.quality == 100)
        #expect(parsedSettings?.generation?.enabled == true)
        #expect(parsedSettings?.generation?.model == "gpt-4")
    }

    /// Validates preservation pattern when updating one field
    /// Reference: Guide lines 458-474
    @Test("Best Practice: Preservation Pattern")
    func bestPracticePreservationPattern() throws {
        // Create initial settings
        let initialSettings = MyAppSettings(
            theme: "light",
            autoSave: true,
            exportFormat: "pdf"
        )

        var frontMatter = ProjectFrontMatter(title: "Test", author: "Test Author")
        try frontMatter.setSettings(initialSettings)

        let parser = ProjectMarkdownParser()

        // Write to file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        let content = parser.generate(frontMatter: frontMatter, body: "# Body")
        try content.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Update only theme field (lines 463-467)
        let (existingFrontMatter, body) = try parser.parse(fileURL: tempURL)
        var settings = try existingFrontMatter.settings(for: MyAppSettings.self) ?? MyAppSettings()

        settings.theme = "dark"  // Only update theme

        var updatedFrontMatter = existingFrontMatter
        try updatedFrontMatter.setSettings(settings)

        // Write back (lines 470-473)
        let updatedContent = parser.generate(frontMatter: updatedFrontMatter, body: body)
        try updatedContent.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)

        // Verify other fields were preserved
        let (finalFrontMatter, _) = try parser.parse(fileURL: tempURL)
        let finalSettings = try finalFrontMatter.settings(for: MyAppSettings.self)

        #expect(finalSettings?.theme == "dark")           // Updated
        #expect(finalSettings?.autoSave == true)          // Preserved
        #expect(finalSettings?.exportFormat == "pdf")     // Preserved
    }

    /// Validates enum for constrained values
    /// Reference: Guide lines 442-453
    @Test("Best Practice: Enum Constraints")
    func bestPracticeEnumConstraints() throws {
        let settings = PodcastAppSettings(
            sampleRate: 44100,
            format: .mp3  // Type-safe enum
        )

        var frontMatter = ProjectFrontMatter(title: "Test", author: "Test Author")
        try frontMatter.setSettings(settings)

        let parser = ProjectMarkdownParser()
        let yaml = parser.generate(frontMatter: frontMatter, body: "")

        // Verify enum is encoded as string
        #expect(yaml.contains("format: mp3"))

        // Test all enum cases
        for format in [PodcastAppSettings.AudioFormat.mp3, .aac, .flac] {
            let testSettings = PodcastAppSettings(format: format)
            var testFrontMatter = ProjectFrontMatter(title: "Test", author: "Test Author")
            try testFrontMatter.setSettings(testSettings)

            let testYAML = parser.generate(frontMatter: testFrontMatter, body: "")
            #expect(testYAML.contains("format: \(format.rawValue)"))

            // Round-trip verification
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("md")
            try testYAML.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let (parsedFrontMatter, _) = try parser.parse(fileURL: tempURL)
            let parsedSettings = try parsedFrontMatter.settings(for: PodcastAppSettings.self)

            #expect(parsedSettings?.format == format)
        }
    }

    /// Validates all optional fields encode/decode correctly
    /// Reference: Guide lines 382-394
    @Test("Best Practice: Optional Fields")
    func bestPracticeOptionalFields() throws {
        // Test with partial fields set (some nil, some set)
        let partialSettings = MyAppSettings(
            theme: "dark",
            autoSave: nil,
            exportFormat: "pdf"
        )
        var frontMatter = ProjectFrontMatter(title: "Test", author: "Test Author")
        try frontMatter.setSettings(partialSettings)

        let parser = ProjectMarkdownParser()
        let yaml = parser.generate(frontMatter: frontMatter, body: "")

        // Verify YAML contains only non-nil fields
        #expect(yaml.contains("myapp:"))
        #expect(yaml.contains("theme: dark"))
        #expect(yaml.contains("exportFormat: pdf"))

        // Round-trip verification
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try yaml.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let (parsedFrontMatter, _) = try parser.parse(fileURL: tempURL)
        let parsedSettings = try parsedFrontMatter.settings(for: MyAppSettings.self)

        #expect(parsedSettings?.theme == "dark")
        #expect(parsedSettings?.autoSave == nil)
        #expect(parsedSettings?.exportFormat == "pdf")

        // Test with all fields set
        let fullSettings = MyAppSettings(
            theme: "light",
            autoSave: true,
            exportFormat: "html"
        )
        var frontMatter2 = ProjectFrontMatter(title: "Test", author: "Test Author")
        try frontMatter2.setSettings(fullSettings)

        let yaml2 = parser.generate(frontMatter: frontMatter2, body: "")
        let tempURL2 = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try yaml2.write(to: tempURL2, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempURL2) }

        let (parsedFrontMatter2, _) = try parser.parse(fileURL: tempURL2)
        let parsedSettings2 = try parsedFrontMatter2.settings(for: MyAppSettings.self)

        #expect(parsedSettings2?.theme == "light")
        #expect(parsedSettings2?.autoSave == true)
        #expect(parsedSettings2?.exportFormat == "html")
    }
}

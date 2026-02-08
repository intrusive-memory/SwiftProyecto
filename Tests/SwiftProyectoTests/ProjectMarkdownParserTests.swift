import XCTest
@testable import SwiftProyecto

final class ProjectMarkdownParserTests: XCTestCase {

    var parser: ProjectMarkdownParser!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        parser = ProjectMarkdownParser()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ParserTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Parsing Tests - Valid Content

    func testParse_MinimalContent() throws {
        let content = """
        ---
        type: project
        title: My Project
        author: Jane Doe
        created: 2025-11-17T10:30:00Z
        ---

        # Body content
        """

        let (frontMatter, body) = try parser.parse(content: content)

        XCTAssertEqual(frontMatter.type, "project")
        XCTAssertEqual(frontMatter.title, "My Project")
        XCTAssertEqual(frontMatter.author, "Jane Doe")
        XCTAssertEqual(body, "# Body content")
    }

    func testParse_FullContent() throws {
        let content = """
        ---
        type: project
        title: My Series
        author: Jane Showrunner
        created: 2025-11-17T10:30:00Z
        description: A sci-fi series
        season: 1
        episodes: 12
        genre: Science Fiction
        tags: [sci-fi, drama, action]
        ---

        # Project Notes

        This is a test project.
        """

        let (frontMatter, body) = try parser.parse(content: content)

        XCTAssertEqual(frontMatter.type, "project")
        XCTAssertEqual(frontMatter.title, "My Series")
        XCTAssertEqual(frontMatter.author, "Jane Showrunner")
        XCTAssertEqual(frontMatter.description, "A sci-fi series")
        XCTAssertEqual(frontMatter.season, 1)
        XCTAssertEqual(frontMatter.episodes, 12)
        XCTAssertEqual(frontMatter.genre, "Science Fiction")
        XCTAssertEqual(frontMatter.tags, ["sci-fi", "drama", "action"])
        XCTAssertTrue(body.contains("# Project Notes"))
        XCTAssertTrue(body.contains("This is a test project."))
    }

    func testParse_EmptyBody() throws {
        let content = """
        ---
        type: project
        title: No Body Project
        author: Author
        created: 2025-11-17T10:30:00Z
        ---
        """

        let (frontMatter, body) = try parser.parse(content: content)

        XCTAssertEqual(frontMatter.title, "No Body Project")
        XCTAssertTrue(body.isEmpty)
    }

    func testParse_WhitespaceInBody() throws {
        let content = """
        ---
        type: project
        title: Whitespace Test
        author: Author
        created: 2025-11-17T10:30:00Z
        ---


        # Body with leading whitespace


        Content here.


        """

        let (frontMatter, body) = try parser.parse(content: content)

        XCTAssertEqual(frontMatter.title, "Whitespace Test")
        // Body should be trimmed of leading/trailing whitespace
        XCTAssertFalse(body.hasPrefix("\n\n\n"))
        XCTAssertFalse(body.hasSuffix("\n\n\n"))
        XCTAssertTrue(body.contains("# Body with leading whitespace"))
        XCTAssertTrue(body.contains("Content here."))
    }

    func testParse_QuotedValues() throws {
        let content = """
        ---
        type: project
        title: "Quoted Title: With Colon"
        author: "Jane Doe"
        created: 2025-11-17T10:30:00Z
        description: "A description with: colons and special chars!"
        ---
        """

        let (frontMatter, _) = try parser.parse(content: content)

        // UNIVERSAL correctly strips quotes from values
        XCTAssertEqual(frontMatter.title, "Quoted Title: With Colon")
        XCTAssertEqual(frontMatter.author, "Jane Doe")
        XCTAssertEqual(frontMatter.description, "A description with: colons and special chars!")
    }

    func testParse_TagsWithSpaces() throws {
        let content = """
        ---
        type: project
        title: Tags Test
        author: Author
        created: 2025-11-17T10:30:00Z
        tags: [sci-fi, space opera, action thriller]
        ---
        """

        let (frontMatter, _) = try parser.parse(content: content)

        XCTAssertEqual(frontMatter.tags, ["sci-fi", "space opera", "action thriller"])
    }

    // MARK: - Parsing Tests - File URL

    func testParse_FromFile() throws {
        let fileURL = tempDirectory.appendingPathComponent("PROJECT.md")
        let content = """
        ---
        type: project
        title: File Test
        author: File Author
        created: 2025-11-17T10:30:00Z
        ---

        # File body
        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let (frontMatter, body) = try parser.parse(fileURL: fileURL)

        XCTAssertEqual(frontMatter.title, "File Test")
        XCTAssertEqual(frontMatter.author, "File Author")
        XCTAssertEqual(body, "# File body")
    }

    // MARK: - Parsing Tests - Error Cases

    func testParse_NoFrontMatter() {
        let content = """
        # Just markdown

        No front matter here!
        """

        XCTAssertThrowsError(try parser.parse(content: content)) { error in
            guard let parserError = error as? ProjectMarkdownParser.ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            if case .noFrontMatter = parserError {
                // Expected
            } else {
                XCTFail("Expected noFrontMatter error")
            }
        }
    }

    func testParse_MissingClosingDelimiter() {
        let content = """
        ---
        type: project
        title: Unclosed
        author: Author
        """

        XCTAssertThrowsError(try parser.parse(content: content)) { error in
            guard let parserError = error as? ProjectMarkdownParser.ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            if case .noFrontMatter = parserError {
                // Expected - no closing delimiter
            } else {
                XCTFail("Expected noFrontMatter error")
            }
        }
    }

    func testParse_MissingRequiredField_Type() {
        let content = """
        ---
        title: My Project
        author: Author
        created: 2025-11-17T10:30:00Z
        ---
        """

        XCTAssertThrowsError(try parser.parse(content: content)) { error in
            guard let parserError = error as? ProjectMarkdownParser.ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            if case .missingRequiredField(let field) = parserError {
                XCTAssertEqual(field, "type")
            } else {
                XCTFail("Expected missingRequiredField error")
            }
        }
    }

    func testParse_MissingRequiredField_Title() {
        let content = """
        ---
        type: project
        author: Author
        created: 2025-11-17T10:30:00Z
        ---
        """

        XCTAssertThrowsError(try parser.parse(content: content)) { error in
            guard let parserError = error as? ProjectMarkdownParser.ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            if case .missingRequiredField(let field) = parserError {
                XCTAssertEqual(field, "title")
            } else {
                XCTFail("Expected missingRequiredField error")
            }
        }
    }

    func testParse_MissingRequiredField_Author() {
        let content = """
        ---
        type: project
        title: My Project
        created: 2025-11-17T10:30:00Z
        ---
        """

        XCTAssertThrowsError(try parser.parse(content: content)) { error in
            guard let parserError = error as? ProjectMarkdownParser.ParserError else {
                XCTFail("Expected ParserError")
                return
            }
            if case .missingRequiredField(let field) = parserError {
                XCTAssertEqual(field, "author")
            } else {
                XCTFail("Expected missingRequiredField error")
            }
        }
    }

    func testParse_InvalidDateFormat() {
        let content = """
        ---
        type: project
        title: My Project
        author: Author
        created: not-a-date
        ---
        """

        XCTAssertThrowsError(try parser.parse(content: content)) { error in
            guard let parserError = error as? ProjectMarkdownParser.ParserError else {
                XCTFail("Expected ParserError, got \(error)")
                return
            }
            // UNIVERSAL returns invalidYAML for date parsing errors
            // (dates that don't match ISO8601 format)
            switch parserError {
            case .invalidDateFormat, .invalidYAML:
                // Expected - either error type is acceptable
                break
            default:
                XCTFail("Expected invalidDateFormat or invalidYAML error, got \(parserError)")
            }
        }
    }

    // MARK: - Generation Tests

    func testGenerate_MinimalFields() {
        let frontMatter = ProjectFrontMatter(
            title: "My Project",
            author: "Jane Doe"
        )

        let generated = parser.generate(frontMatter: frontMatter)

        XCTAssertTrue(generated.contains("type: project"))
        XCTAssertTrue(generated.contains("title: My Project"))
        XCTAssertTrue(generated.contains("author: Jane Doe"))
        XCTAssertTrue(generated.hasPrefix("---\n"))
        XCTAssertTrue(generated.contains("\n---\n"))
    }

    func testGenerate_FullFields() {
        let frontMatter = ProjectFrontMatter(
            title: "My Series",
            author: "Jane Showrunner",
            description: "A sci-fi series",
            season: 1,
            episodes: 12,
            genre: "Science Fiction",
            tags: ["sci-fi", "drama"]
        )

        let generated = parser.generate(frontMatter: frontMatter)

        XCTAssertTrue(generated.contains("type: project"))
        XCTAssertTrue(generated.contains("title: My Series"))
        XCTAssertTrue(generated.contains("author: Jane Showrunner"))
        XCTAssertTrue(generated.contains("description: A sci-fi series"))
        XCTAssertTrue(generated.contains("season: 1"))
        XCTAssertTrue(generated.contains("episodes: 12"))
        XCTAssertTrue(generated.contains("genre: Science Fiction"))
        XCTAssertTrue(generated.contains("tags: [sci-fi, drama]"))
    }

    func testGenerate_WithBody() {
        let frontMatter = ProjectFrontMatter(
            title: "My Project",
            author: "Author"
        )
        let body = "# Notes\n\nProject notes here."

        let generated = parser.generate(frontMatter: frontMatter, body: body)

        XCTAssertTrue(generated.contains("---\n"))
        XCTAssertTrue(generated.contains("\n---\n"))
        XCTAssertTrue(generated.contains("# Notes"))
        XCTAssertTrue(generated.contains("Project notes here."))
    }

    func testGenerate_EmptyBody() {
        let frontMatter = ProjectFrontMatter(
            title: "My Project",
            author: "Author"
        )

        let generated = parser.generate(frontMatter: frontMatter, body: "")

        XCTAssertTrue(generated.hasPrefix("---\n"))
        XCTAssertTrue(generated.hasSuffix("---\n"))
    }

    // MARK: - Round-trip Tests

    func testRoundTrip_MinimalContent() throws {
        let original = ProjectFrontMatter(
            title: "Round Trip",
            author: "Author"
        )
        let body = "# Body"

        let generated = parser.generate(frontMatter: original, body: body)
        let (parsed, parsedBody) = try parser.parse(content: generated)

        XCTAssertEqual(parsed.title, original.title)
        XCTAssertEqual(parsed.author, original.author)
        XCTAssertEqual(parsed.type, original.type)
        XCTAssertEqual(parsedBody, body)
    }

    func testRoundTrip_FullContent() throws {
        let original = ProjectFrontMatter(
            title: "Full Round Trip",
            author: "Author",
            description: "Description",
            season: 2,
            episodes: 10,
            genre: "Drama",
            tags: ["tag1", "tag2"]
        )
        let body = "# Notes\n\nFull body content."

        let generated = parser.generate(frontMatter: original, body: body)
        let (parsed, parsedBody) = try parser.parse(content: generated)

        XCTAssertEqual(parsed.title, original.title)
        XCTAssertEqual(parsed.author, original.author)
        XCTAssertEqual(parsed.description, original.description)
        XCTAssertEqual(parsed.season, original.season)
        XCTAssertEqual(parsed.episodes, original.episodes)
        XCTAssertEqual(parsed.genre, original.genre)
        XCTAssertEqual(parsed.tags, original.tags)
        XCTAssertEqual(parsedBody, body)
    }

    // MARK: - Error Description Tests

    func testErrorDescriptions() {
        XCTAssertNotNil(ProjectMarkdownParser.ParserError.noFrontMatter.errorDescription)
        XCTAssertNotNil(ProjectMarkdownParser.ParserError.invalidYAML("test").errorDescription)
        XCTAssertNotNil(ProjectMarkdownParser.ParserError.missingRequiredField("test").errorDescription)
        XCTAssertNotNil(ProjectMarkdownParser.ParserError.invalidDateFormat("test").errorDescription)
    }

    // MARK: - Generation Config Parsing Tests

    func testParse_GenerationConfigFields() throws {
        let content = """
        ---
        type: project
        title: Podcast Project
        author: Jane Doe
        created: 2025-11-17T10:30:00Z
        episodesDir: scripts
        audioDir: output
        filePattern: "*.fountain"
        exportFormat: m4a
        ---
        """

        let (frontMatter, _) = try parser.parse(content: content)

        XCTAssertEqual(frontMatter.episodesDir, "scripts")
        XCTAssertEqual(frontMatter.audioDir, "output")
        XCTAssertEqual(frontMatter.filePattern?.patterns, ["*.fountain"])
        XCTAssertEqual(frontMatter.exportFormat, "m4a")
    }

    func testParse_FilePatternAsArray() throws {
        let content = """
        ---
        type: project
        title: Multi-Format Project
        author: Jane Doe
        created: 2025-11-17T10:30:00Z
        filePattern: ["*.fountain", "*.fdx", "*.highland"]
        ---
        """

        let (frontMatter, _) = try parser.parse(content: content)

        XCTAssertEqual(frontMatter.filePattern?.patterns, ["*.fountain", "*.fdx", "*.highland"])
    }

    func testParse_FilePatternAsYAMLList() throws {
        let content = """
        ---
        type: project
        title: Explicit Files Project
        author: Jane Doe
        created: 2025-11-17T10:30:00Z
        filePattern:
          - "intro.fountain"
          - "chapter-01.fountain"
          - "chapter-02.fountain"
        ---
        """

        let (frontMatter, _) = try parser.parse(content: content)

        XCTAssertEqual(frontMatter.filePattern?.patterns.count, 3)
        XCTAssertEqual(frontMatter.filePattern?.patterns[0], "intro.fountain")
        XCTAssertEqual(frontMatter.filePattern?.patterns[2], "chapter-02.fountain")
    }

    func testParse_HookFields() throws {
        let content = """
        ---
        type: project
        title: Hooks Project
        author: Jane Doe
        created: 2025-11-17T10:30:00Z
        preGenerateHook: "./scripts/prepare.sh"
        postGenerateHook: "./scripts/upload.sh"
        ---
        """

        let (frontMatter, _) = try parser.parse(content: content)

        XCTAssertEqual(frontMatter.preGenerateHook, "./scripts/prepare.sh")
        XCTAssertEqual(frontMatter.postGenerateHook, "./scripts/upload.sh")
    }

    func testParse_FullGenerationConfig() throws {
        let content = """
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
        episodesDir: episodes
        audioDir: audio
        filePattern: "*.fountain"
        exportFormat: m4a
        preGenerateHook: "./scripts/generate-fountain.sh"
        postGenerateHook: "./scripts/upload-to-cdn.sh"
        ---

        # Production Notes

        This is a daily podcast series.
        """

        let (frontMatter, body) = try parser.parse(content: content)

        // Basic fields
        XCTAssertEqual(frontMatter.title, "Daily Dao - Tao De Jing Podcast")
        XCTAssertEqual(frontMatter.author, "Tom Stovall")
        XCTAssertEqual(frontMatter.description, "Daily readings from the Tao De Jing")
        XCTAssertEqual(frontMatter.season, 1)
        XCTAssertEqual(frontMatter.episodes, 81)
        XCTAssertEqual(frontMatter.genre, "Philosophy")
        XCTAssertEqual(frontMatter.tags, ["taoism", "philosophy", "meditation"])

        // Generation config
        XCTAssertEqual(frontMatter.episodesDir, "episodes")
        XCTAssertEqual(frontMatter.audioDir, "audio")
        XCTAssertEqual(frontMatter.filePattern?.patterns, ["*.fountain"])
        XCTAssertEqual(frontMatter.exportFormat, "m4a")

        // Hooks
        XCTAssertEqual(frontMatter.preGenerateHook, "./scripts/generate-fountain.sh")
        XCTAssertEqual(frontMatter.postGenerateHook, "./scripts/upload-to-cdn.sh")

        // Body
        XCTAssertTrue(body.contains("# Production Notes"))
    }

    func testParse_BackwardCompatibility_NoGenerationConfig() throws {
        // Old-style PROJECT.md without generation config fields should still parse
        let content = """
        ---
        type: project
        title: Legacy Project
        author: Old Author
        created: 2025-11-17T10:30:00Z
        description: An old project
        season: 1
        episodes: 10
        ---

        # Notes
        """

        let (frontMatter, _) = try parser.parse(content: content)

        XCTAssertEqual(frontMatter.title, "Legacy Project")
        XCTAssertNil(frontMatter.episodesDir)
        XCTAssertNil(frontMatter.audioDir)
        XCTAssertNil(frontMatter.filePattern)
        XCTAssertNil(frontMatter.exportFormat)
        XCTAssertNil(frontMatter.preGenerateHook)
        XCTAssertNil(frontMatter.postGenerateHook)

        // Resolved defaults should work
        XCTAssertEqual(frontMatter.resolvedEpisodesDir, "episodes")
        XCTAssertEqual(frontMatter.resolvedAudioDir, "audio")
        XCTAssertEqual(frontMatter.resolvedFilePatterns, ["*.fountain"])
        XCTAssertEqual(frontMatter.resolvedExportFormat, "m4a")
    }

    // MARK: - Generation Config Generation Tests

    func testGenerate_WithGenerationConfig() {
        let frontMatter = ProjectFrontMatter(
            title: "Config Project",
            author: "Author",
            episodesDir: "scripts",
            audioDir: "output",
            filePattern: .single("*.fountain"),
            exportFormat: "aiff"
        )

        let generated = parser.generate(frontMatter: frontMatter)

        XCTAssertTrue(generated.contains("episodesDir: scripts"))
        XCTAssertTrue(generated.contains("audioDir: output"))
        XCTAssertTrue(generated.contains("filePattern: \"*.fountain\""))
        XCTAssertTrue(generated.contains("exportFormat: aiff"))
    }

    func testGenerate_WithMultipleFilePatterns() {
        let frontMatter = ProjectFrontMatter(
            title: "Multi-Pattern Project",
            author: "Author",
            filePattern: .multiple(["*.fountain", "*.fdx"])
        )

        let generated = parser.generate(frontMatter: frontMatter)

        XCTAssertTrue(generated.contains("filePattern: [\"*.fountain\", \"*.fdx\"]"))
    }

    func testGenerate_WithHooks() {
        let frontMatter = ProjectFrontMatter(
            title: "Hooks Project",
            author: "Author",
            preGenerateHook: "./scripts/pre.sh",
            postGenerateHook: "./scripts/post.sh"
        )

        let generated = parser.generate(frontMatter: frontMatter)

        // Hooks without special characters are not quoted (valid YAML)
        XCTAssertTrue(generated.contains("preGenerateHook: ./scripts/pre.sh"))
        XCTAssertTrue(generated.contains("postGenerateHook: ./scripts/post.sh"))
    }

    func testGenerate_WithoutGenerationConfig() {
        let frontMatter = ProjectFrontMatter(
            title: "Basic Project",
            author: "Author"
        )

        let generated = parser.generate(frontMatter: frontMatter)

        XCTAssertFalse(generated.contains("episodesDir"))
        XCTAssertFalse(generated.contains("audioDir"))
        XCTAssertFalse(generated.contains("filePattern"))
        XCTAssertFalse(generated.contains("exportFormat"))
        XCTAssertFalse(generated.contains("preGenerateHook"))
        XCTAssertFalse(generated.contains("postGenerateHook"))
    }

    // MARK: - Generation Config Round-trip Tests

    func testRoundTrip_WithGenerationConfig() throws {
        let original = ProjectFrontMatter(
            title: "Round Trip Config",
            author: "Author",
            episodesDir: "scripts",
            audioDir: "output",
            filePattern: .single("*.fountain"),
            exportFormat: "m4a",
            preGenerateHook: "./pre.sh",
            postGenerateHook: "./post.sh"
        )

        let generated = parser.generate(frontMatter: original)
        let (parsed, _) = try parser.parse(content: generated)

        XCTAssertEqual(parsed.episodesDir, original.episodesDir)
        XCTAssertEqual(parsed.audioDir, original.audioDir)
        XCTAssertEqual(parsed.filePattern?.patterns, original.filePattern?.patterns)
        XCTAssertEqual(parsed.exportFormat, original.exportFormat)
        XCTAssertEqual(parsed.preGenerateHook, original.preGenerateHook)
        XCTAssertEqual(parsed.postGenerateHook, original.postGenerateHook)
    }

    func testRoundTrip_WithMultipleFilePatterns() throws {
        let original = ProjectFrontMatter(
            title: "Multi-Pattern Round Trip",
            author: "Author",
            filePattern: .multiple(["*.fountain", "*.fdx", "*.highland"])
        )

        let generated = parser.generate(frontMatter: original)
        let (parsed, _) = try parser.parse(content: generated)

        XCTAssertEqual(parsed.filePattern?.patterns, original.filePattern?.patterns)
    }

    // MARK: - Convenience Accessor Tests

    func testResolvedDefaults() {
        let frontMatter = ProjectFrontMatter(
            title: "Defaults Test",
            author: "Author"
        )

        XCTAssertEqual(frontMatter.resolvedEpisodesDir, "episodes")
        XCTAssertEqual(frontMatter.resolvedAudioDir, "audio")
        XCTAssertEqual(frontMatter.resolvedFilePatterns, ["*.fountain"])
        XCTAssertEqual(frontMatter.resolvedExportFormat, "m4a")
        XCTAssertFalse(frontMatter.hasGenerationConfig)
    }

    func testResolvedValues_WhenSet() {
        let frontMatter = ProjectFrontMatter(
            title: "Custom Values Test",
            author: "Author",
            episodesDir: "scripts",
            audioDir: "output",
            filePattern: .multiple(["*.fountain", "*.fdx"]),
            exportFormat: "wav"
        )

        XCTAssertEqual(frontMatter.resolvedEpisodesDir, "scripts")
        XCTAssertEqual(frontMatter.resolvedAudioDir, "output")
        XCTAssertEqual(frontMatter.resolvedFilePatterns, ["*.fountain", "*.fdx"])
        XCTAssertEqual(frontMatter.resolvedExportFormat, "wav")
        XCTAssertTrue(frontMatter.hasGenerationConfig)
    }

    // MARK: - TTS Config Tests

    func testParse_TTSConfig() throws {
        let content = """
        ---
        type: project
        title: My Series
        author: Jane Doe
        created: 2025-11-17T10:30:00Z
        tts:
          providerId: apple
          voiceId: com.apple.voice.compact.en-US.Samantha
          languageCode: en
          voiceURI: "hablare://apple/com.apple.voice.compact.en-US.Samantha?lang=en"
        ---
        """

        let (frontMatter, _) = try parser.parse(content: content)

        XCTAssertTrue(frontMatter.hasTTSConfig)
        XCTAssertEqual(frontMatter.tts?.providerId, "apple")
        XCTAssertEqual(frontMatter.tts?.voiceId, "com.apple.voice.compact.en-US.Samantha")
        XCTAssertEqual(frontMatter.tts?.languageCode, "en")
        XCTAssertEqual(frontMatter.tts?.voiceURI, "hablare://apple/com.apple.voice.compact.en-US.Samantha?lang=en")
    }

    func testParse_NoTTSConfig() throws {
        let content = """
        ---
        type: project
        title: My Project
        author: Jane Doe
        created: 2025-11-17T10:30:00Z
        ---
        """

        let (frontMatter, _) = try parser.parse(content: content)

        XCTAssertFalse(frontMatter.hasTTSConfig)
        XCTAssertNil(frontMatter.tts)
    }

    func testGenerate_WithTTSConfig() {
        let tts = TTSConfig(
            providerId: "apple",
            voiceId: "com.apple.voice.compact.en-US.Samantha",
            languageCode: "en",
            voiceURI: "hablare://apple/com.apple.voice.compact.en-US.Samantha?lang=en"
        )
        let frontMatter = ProjectFrontMatter(
            title: "My Series",
            author: "Jane Doe",
            created: ISO8601DateFormatter().date(from: "2025-11-17T10:30:00Z")!,
            tts: tts
        )

        let output = parser.generate(frontMatter: frontMatter)

        XCTAssertTrue(output.contains("tts:"))
        XCTAssertTrue(output.contains("  providerId: apple"))
        XCTAssertTrue(output.contains("  voiceId: com.apple.voice.compact.en-US.Samantha"))
        XCTAssertTrue(output.contains("  languageCode: en"))
        XCTAssertTrue(output.contains("  voiceURI: \"hablare://apple/com.apple.voice.compact.en-US.Samantha?lang=en\""))
    }

    func testRoundTrip_TTSConfig() throws {
        let tts = TTSConfig(
            providerId: "elevenlabs",
            voiceId: "voice_abc123",
            languageCode: "es",
            voiceURI: "hablare://elevenlabs/voice_abc123?lang=es"
        )
        let original = ProjectFrontMatter(
            title: "Round Trip TTS",
            author: "Test Author",
            created: ISO8601DateFormatter().date(from: "2025-11-17T10:30:00Z")!,
            tts: tts
        )

        let generated = parser.generate(frontMatter: original, body: "# Notes")
        let (parsed, body) = try parser.parse(content: generated)

        XCTAssertEqual(parsed.title, original.title)
        XCTAssertEqual(parsed.author, original.author)
        XCTAssertEqual(parsed.tts, original.tts)
        XCTAssertEqual(body, "# Notes")
    }

    // MARK: - App Sections Tests

    func testParseYAMLWithAppSection() throws {
        let content = """
        ---
        type: project
        title: Test Project
        author: Test Author
        created: 2025-01-01T00:00:00Z
        myapp:
          theme: dark
          version: 1
        ---

        # Body
        """

        let (frontMatter, body) = try parser.parse(content: content)

        XCTAssertEqual(frontMatter.title, "Test Project")
        XCTAssertEqual(body, "# Body")

        // Verify app section was captured
        XCTAssertTrue(frontMatter.hasSettings(for: TestAppSettings.self))

        let settings = try frontMatter.settings(for: TestAppSettings.self)
        XCTAssertEqual(settings?.theme, "dark")
        XCTAssertEqual(settings?.version, 1)
    }

    func testParseYAMLWithMultipleAppSections() throws {
        let content = """
        ---
        type: project
        title: Multi-App Project
        author: Test Author
        created: 2025-01-01T00:00:00Z
        myapp:
          theme: dark
          version: 1
        otherapp:
          enabled: true
          count: 42
        ---
        """

        let (frontMatter, _) = try parser.parse(content: content)

        // Verify both app sections exist
        XCTAssertTrue(frontMatter.hasSettings(for: TestAppSettings.self))
        XCTAssertTrue(frontMatter.hasSettings(for: OtherAppSettings.self))

        let mySettings = try frontMatter.settings(for: TestAppSettings.self)
        XCTAssertEqual(mySettings?.theme, "dark")
        XCTAssertEqual(mySettings?.version, 1)

        let otherSettings = try frontMatter.settings(for: OtherAppSettings.self)
        XCTAssertEqual(otherSettings?.enabled, true)
        XCTAssertEqual(otherSettings?.count, 42)
    }

    func testGenerateYAMLWithAppSection() throws {
        var frontMatter = ProjectFrontMatter(
            title: "Test Project",
            author: "Test Author",
            created: ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z")!
        )

        let settings = TestAppSettings(theme: "dark", version: 1)
        try frontMatter.setSettings(settings)

        let generated = parser.generate(frontMatter: frontMatter)

        // Verify YAML contains app section
        XCTAssertTrue(generated.contains("myapp:"))
        XCTAssertTrue(generated.contains("theme: dark"))
        XCTAssertTrue(generated.contains("version: 1"))

        // Verify known fields are still present
        XCTAssertTrue(generated.contains("type: project"))
        XCTAssertTrue(generated.contains("title: Test Project"))
        XCTAssertTrue(generated.contains("author: Test Author"))
    }

    func testYAMLRoundTrip_AppSectionsPreserved() throws {
        // Create frontmatter with app section
        var original = ProjectFrontMatter(
            title: "Round Trip Test",
            author: "Author",
            created: ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z")!
        )

        let settings = TestAppSettings(theme: "dark", version: 2)
        try original.setSettings(settings)

        // Generate YAML
        let generated = parser.generate(frontMatter: original, body: "# Body")

        // Parse it back
        let (parsed, body) = try parser.parse(content: generated)

        // Verify app section survived round-trip
        let retrievedSettings = try parsed.settings(for: TestAppSettings.self)
        XCTAssertEqual(retrievedSettings?.theme, "dark")
        XCTAssertEqual(retrievedSettings?.version, 2)
        XCTAssertEqual(body, "# Body")
    }

    func testYAMLRoundTrip_KnownFieldsUnaffected() throws {
        // Create frontmatter with both known fields and app section
        var original = ProjectFrontMatter(
            title: "Full Test",
            author: "Author",
            created: ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z")!,
            description: "Test description",
            season: 1,
            episodes: 10,
            genre: "Drama",
            tags: ["test", "round-trip"]
        )

        let settings = TestAppSettings(theme: "light", version: 3)
        try original.setSettings(settings)

        // Generate and re-parse
        let generated = parser.generate(frontMatter: original)
        let (parsed, _) = try parser.parse(content: generated)

        // Verify all known fields preserved
        XCTAssertEqual(parsed.title, original.title)
        XCTAssertEqual(parsed.author, original.author)
        XCTAssertEqual(parsed.description, original.description)
        XCTAssertEqual(parsed.season, original.season)
        XCTAssertEqual(parsed.episodes, original.episodes)
        XCTAssertEqual(parsed.genre, original.genre)
        XCTAssertEqual(parsed.tags, original.tags)

        // Verify app section also preserved
        let retrievedSettings = try parsed.settings(for: TestAppSettings.self)
        XCTAssertEqual(retrievedSettings?.theme, "light")
        XCTAssertEqual(retrievedSettings?.version, 3)
    }

    func testAppSectionAtRootLevel() throws {
        var frontMatter = ProjectFrontMatter(
            title: "Root Level Test",
            author: "Author",
            created: ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z")!
        )

        let settings = TestAppSettings(theme: "dark", version: 1)
        try frontMatter.setSettings(settings)

        let generated = parser.generate(frontMatter: frontMatter)

        // Split into lines to check structure
        let lines = generated.split(separator: "\n")

        // Find the myapp line
        guard let myappLineIndex = lines.firstIndex(where: { $0.starts(with: "myapp:") }) else {
            XCTFail("myapp section not found")
            return
        }

        // Verify myapp is at root level (no leading whitespace)
        let myappLine = lines[myappLineIndex]
        XCTAssertTrue(myappLine.starts(with: "myapp:"))
        XCTAssertFalse(myappLine.starts(with: " "))

        // Verify theme is indented under myapp
        let themeLine = lines[myappLineIndex + 1]
        XCTAssertTrue(themeLine.contains("theme:"))
        XCTAssertTrue(themeLine.starts(with: "  ")) // Two spaces indent
    }

    func testLegacyYAMLWithoutAppSections() throws {
        // Old-style PROJECT.md without any app sections should parse correctly
        let content = """
        ---
        type: project
        title: Legacy Project
        author: Old Author
        created: 2025-01-01T00:00:00Z
        description: An old project without app sections
        season: 1
        episodes: 10
        ---

        # Notes
        """

        let (frontMatter, body) = try parser.parse(content: content)

        // Verify known fields parsed correctly
        XCTAssertEqual(frontMatter.title, "Legacy Project")
        XCTAssertEqual(frontMatter.author, "Old Author")
        XCTAssertEqual(frontMatter.description, "An old project without app sections")
        XCTAssertEqual(frontMatter.season, 1)
        XCTAssertEqual(frontMatter.episodes, 10)
        XCTAssertEqual(body, "# Notes")

        // Verify no app sections present
        XCTAssertFalse(frontMatter.hasSettings(for: TestAppSettings.self))
    }

    func testYAMLGenerationFormat() throws {
        // Create a frontmatter with app section to verify YAML formatting
        var frontMatter = ProjectFrontMatter(
            title: "Format Test",
            author: "Author",
            created: ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z")!,
            description: "Testing YAML format"
        )

        let settings = TestAppSettings(theme: "dark", version: 99)
        try frontMatter.setSettings(settings)

        let generated = parser.generate(frontMatter: frontMatter, body: "# Body")

        // Print for manual verification (will show in test output if needed)
        // print("\n=== Generated YAML ===\n\(generated)\n======================\n")

        // Verify structure
        let lines = generated.split(separator: "\n", omittingEmptySubsequences: false)

        // Find myapp section
        guard let myappIdx = lines.firstIndex(where: { $0 == "myapp:" }) else {
            XCTFail("myapp section not found at root level")
            return
        }

        // Verify myapp is at root level (no leading whitespace)
        XCTAssertTrue(lines[myappIdx] == "myapp:")

        // Verify next lines are indented properties
        XCTAssertTrue(lines[myappIdx + 1].starts(with: "  "))
        XCTAssertTrue(lines[myappIdx + 2].starts(with: "  "))
    }

    func testTypedSettingsFullRoundTrip() throws {
        // Parse original YAML without app sections
        let original = """
        ---
        type: project
        title: My Project
        author: Author
        created: 2025-01-01T00:00:00Z
        description: Original description
        ---

        # Description

        Original body content.
        """

        let (frontMatter1, body1) = try parser.parse(content: original)

        XCTAssertEqual(frontMatter1.title, "My Project")
        XCTAssertEqual(body1, "# Description\n\nOriginal body content.")
        XCTAssertFalse(frontMatter1.hasSettings(for: TestAppSettings.self))

        // Add typed settings
        var frontMatter2 = frontMatter1
        let settings = TestAppSettings(theme: "dark", version: 42)
        try frontMatter2.setSettings(settings)

        // Generate YAML
        let generated = parser.generate(frontMatter: frontMatter2, body: body1)

        // Verify generated YAML contains app section
        XCTAssertTrue(generated.contains("myapp:"))
        XCTAssertTrue(generated.contains("theme: dark"))
        XCTAssertTrue(generated.contains("version: 42"))

        // Re-parse
        let (frontMatter3, body2) = try parser.parse(content: generated)

        // Verify settings survived round-trip
        let retrievedSettings = try frontMatter3.settings(for: TestAppSettings.self)
        XCTAssertNotNil(retrievedSettings)
        XCTAssertEqual(retrievedSettings?.theme, "dark")
        XCTAssertEqual(retrievedSettings?.version, 42)

        // Verify known fields preserved
        XCTAssertEqual(frontMatter3.title, "My Project")
        XCTAssertEqual(frontMatter3.author, "Author")
        XCTAssertEqual(frontMatter3.description, "Original description")
        XCTAssertEqual(body2, "# Description\n\nOriginal body content.")

        // Modify settings and generate again
        var frontMatter4 = frontMatter3
        let modifiedSettings = TestAppSettings(theme: "light", version: 43)
        try frontMatter4.setSettings(modifiedSettings)

        let regenerated = parser.generate(frontMatter: frontMatter4, body: body2)
        let (frontMatter5, _) = try parser.parse(content: regenerated)

        // Verify modified settings
        let finalSettings = try frontMatter5.settings(for: TestAppSettings.self)
        XCTAssertEqual(finalSettings?.theme, "light")
        XCTAssertEqual(finalSettings?.version, 43)

        // Verify known fields still intact
        XCTAssertEqual(frontMatter5.title, "My Project")
        XCTAssertEqual(frontMatter5.author, "Author")
    }
}

// MARK: - Test Settings Types

/// Test settings type for app sections testing
private struct TestAppSettings: AppFrontMatterSettings {
    static let sectionKey = "myapp"

    var theme: String?
    var version: Int?
}

/// Second test settings type to verify multiple app sections
private struct OtherAppSettings: AppFrontMatterSettings {
    static let sectionKey = "otherapp"

    var enabled: Bool?
    var count: Int?
}

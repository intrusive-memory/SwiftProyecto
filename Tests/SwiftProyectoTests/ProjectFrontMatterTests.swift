import XCTest
@testable import SwiftProyecto

final class ProjectFrontMatterTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization_Minimal() {
        let frontMatter = ProjectFrontMatter(
            title: "My Project",
            author: "Jane Doe"
        )

        XCTAssertEqual(frontMatter.type, "project")
        XCTAssertEqual(frontMatter.title, "My Project")
        XCTAssertEqual(frontMatter.author, "Jane Doe")
        XCTAssertNotNil(frontMatter.created)
        XCTAssertNil(frontMatter.description)
        XCTAssertNil(frontMatter.season)
        XCTAssertNil(frontMatter.episodes)
        XCTAssertNil(frontMatter.genre)
        XCTAssertNil(frontMatter.tags)
    }

    func testInitialization_Full() {
        let created = Date()
        let frontMatter = ProjectFrontMatter(
            type: "project",
            title: "My Series",
            author: "Jane Showrunner",
            created: created,
            description: "A sci-fi series",
            season: 1,
            episodes: 12,
            genre: "Science Fiction",
            tags: ["sci-fi", "drama"]
        )

        XCTAssertEqual(frontMatter.type, "project")
        XCTAssertEqual(frontMatter.title, "My Series")
        XCTAssertEqual(frontMatter.author, "Jane Showrunner")
        XCTAssertEqual(frontMatter.created, created)
        XCTAssertEqual(frontMatter.description, "A sci-fi series")
        XCTAssertEqual(frontMatter.season, 1)
        XCTAssertEqual(frontMatter.episodes, 12)
        XCTAssertEqual(frontMatter.genre, "Science Fiction")
        XCTAssertEqual(frontMatter.tags, ["sci-fi", "drama"])
    }

    func testInitialization_CustomType() {
        let frontMatter = ProjectFrontMatter(
            type: "custom",
            title: "Test",
            author: "Author"
        )

        XCTAssertEqual(frontMatter.type, "custom")
    }

    // MARK: - Validation Tests

    func testValidation_Valid() {
        let frontMatter = ProjectFrontMatter(
            title: "My Project",
            author: "Jane Doe"
        )

        XCTAssertTrue(frontMatter.isValid)
    }

    func testValidation_ValidWithUppercaseType() {
        let frontMatter = ProjectFrontMatter(
            type: "PROJECT",
            title: "My Project",
            author: "Jane Doe"
        )

        XCTAssertTrue(frontMatter.isValid)
    }

    func testValidation_InvalidType() {
        let frontMatter = ProjectFrontMatter(
            type: "invalid",
            title: "My Project",
            author: "Jane Doe"
        )

        XCTAssertFalse(frontMatter.isValid)
    }

    func testValidation_EmptyTitle() {
        let frontMatter = ProjectFrontMatter(
            title: "",
            author: "Jane Doe"
        )

        XCTAssertFalse(frontMatter.isValid)
    }

    func testValidation_EmptyAuthor() {
        let frontMatter = ProjectFrontMatter(
            title: "My Project",
            author: ""
        )

        XCTAssertFalse(frontMatter.isValid)
    }

    func testValidation_WithOptionalFields() {
        let frontMatter = ProjectFrontMatter(
            title: "My Series",
            author: "Jane Showrunner",
            description: "A series",
            season: 1,
            episodes: 10,
            genre: "Drama",
            tags: ["tag1", "tag2"]
        )

        XCTAssertTrue(frontMatter.isValid)
    }

    // MARK: - Equatable Tests

    func testEquatable_Equal() {
        let created = Date()
        let frontMatter1 = ProjectFrontMatter(
            title: "My Project",
            author: "Jane Doe",
            created: created
        )
        let frontMatter2 = ProjectFrontMatter(
            title: "My Project",
            author: "Jane Doe",
            created: created
        )

        XCTAssertEqual(frontMatter1, frontMatter2)
    }

    func testEquatable_NotEqual_DifferentTitle() {
        let created = Date()
        let frontMatter1 = ProjectFrontMatter(
            title: "Project 1",
            author: "Jane Doe",
            created: created
        )
        let frontMatter2 = ProjectFrontMatter(
            title: "Project 2",
            author: "Jane Doe",
            created: created
        )

        XCTAssertNotEqual(frontMatter1, frontMatter2)
    }

    func testEquatable_NotEqual_DifferentAuthor() {
        let created = Date()
        let frontMatter1 = ProjectFrontMatter(
            title: "My Project",
            author: "Jane Doe",
            created: created
        )
        let frontMatter2 = ProjectFrontMatter(
            title: "My Project",
            author: "John Smith",
            created: created
        )

        XCTAssertNotEqual(frontMatter1, frontMatter2)
    }

    func testEquatable_NotEqual_DifferentOptionalFields() {
        let frontMatter1 = ProjectFrontMatter(
            title: "My Project",
            author: "Jane Doe",
            season: 1
        )
        let frontMatter2 = ProjectFrontMatter(
            title: "My Project",
            author: "Jane Doe",
            season: 2
        )

        XCTAssertNotEqual(frontMatter1, frontMatter2)
    }

    // MARK: - Codable Tests

    func testCodable_EncodeAndDecode() throws {
        let original = ProjectFrontMatter(
            title: "My Series",
            author: "Jane Showrunner",
            description: "A sci-fi series",
            season: 1,
            episodes: 12,
            genre: "Science Fiction",
            tags: ["sci-fi", "drama"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProjectFrontMatter.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testCodable_EncodeAndDecode_MinimalFields() throws {
        let original = ProjectFrontMatter(
            title: "Simple Project",
            author: "Author"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProjectFrontMatter.self, from: data)

        XCTAssertEqual(original.title, decoded.title)
        XCTAssertEqual(original.author, decoded.author)
        XCTAssertEqual(original.type, decoded.type)
    }

    // MARK: - Sendable Tests

    func testSendable() {
        // This test verifies that ProjectFrontMatter conforms to Sendable
        // by compiling successfully when used in an async context
        Task {
            let frontMatter = ProjectFrontMatter(
                title: "Concurrent Project",
                author: "Async Author"
            )
            // If this compiles, Sendable is working
            XCTAssertEqual(frontMatter.title, "Concurrent Project")
        }
    }

    // MARK: - Cast List Tests

    func testCast_WithCastList() throws {
        let yaml = """
        ---
        type: project
        title: Test Project
        author: Test Author
        created: 2025-01-01T00:00:00Z
        cast:
          - character: NARRATOR
            actor: Tom Stovall
            voices:
              - apple://com.apple.voice.compact.en-US.Aaron?lang=en
              - elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en
          - character: LAO TZU
            actor: Jason Manino
            voices:
              - qwen-tts://narrative-1?lang=en
        ---
        """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        XCTAssertNotNil(frontMatter.cast)
        XCTAssertEqual(frontMatter.cast?.count, 2)

        let narrator = frontMatter.cast?.first { $0.character == "NARRATOR" }
        XCTAssertEqual(narrator?.actor, "Tom Stovall")
        XCTAssertEqual(narrator?.voices.count, 2)
        XCTAssertEqual(narrator?.voices[0], "apple://com.apple.voice.compact.en-US.Aaron?lang=en")

        let laoTzu = frontMatter.cast?.first { $0.character == "LAO TZU" }
        XCTAssertEqual(laoTzu?.actor, "Jason Manino")
        XCTAssertEqual(laoTzu?.voices.count, 1)
    }

    func testCast_WithoutCastList() throws {
        let yaml = """
        ---
        type: project
        title: Test Project
        author: Test Author
        created: 2025-01-01T00:00:00Z
        ---
        """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        XCTAssertNil(frontMatter.cast)
    }

    func testCast_EmptyArray() throws {
        let yaml = """
        ---
        type: project
        title: Test Project
        author: Test Author
        created: 2025-01-01T00:00:00Z
        cast: []
        ---
        """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        XCTAssertNotNil(frontMatter.cast)
        XCTAssertEqual(frontMatter.cast?.count, 0)
    }

    func testCast_MinimalMembers() throws {
        let yaml = """
        ---
        type: project
        title: Test Project
        author: Test Author
        created: 2025-01-01T00:00:00Z
        cast:
          - character: NARRATOR
          - character: COMMENTATOR
        ---
        """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        XCTAssertEqual(frontMatter.cast?.count, 2)

        let narrator = frontMatter.cast?.first { $0.character == "NARRATOR" }
        XCTAssertNil(narrator?.actor)
        XCTAssertEqual(narrator?.voices.count, 0)
    }

    func testCast_RoundTrip() throws {
        let original = ProjectFrontMatter(
            title: "Test Project",
            author: "Test Author",
            created: Date(),
            episodesDir: "episodes",
            audioDir: "audio",
            filePattern: FilePattern(["*.fountain"]),
            exportFormat: "m4a",
            cast: [
                CastMember(
                    character: "NARRATOR",
                    actor: "Tom Stovall",
                    voices: ["apple://com.apple.voice.compact.en-US.Aaron?lang=en", "elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en"]
                ),
                CastMember(
                    character: "LAO TZU",
                    actor: "Jason Manino",
                    voices: []
                )
            ]
        )

        let parser = ProjectMarkdownParser()
        let generated = parser.generate(frontMatter: original, body: "")
        let (parsed, _) = try parser.parse(content: generated)

        XCTAssertEqual(parsed.cast?.count, original.cast?.count)
        XCTAssertEqual(parsed.episodesDir, original.episodesDir)
        XCTAssertEqual(parsed.audioDir, original.audioDir)
        XCTAssertEqual(parsed.exportFormat, original.exportFormat)

        let narrator = parsed.cast?.first { $0.character == "NARRATOR" }
        XCTAssertEqual(narrator?.actor, "Tom Stovall")
        XCTAssertEqual(narrator?.voices, ["apple://com.apple.voice.compact.en-US.Aaron?lang=en", "elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en"])
    }
}

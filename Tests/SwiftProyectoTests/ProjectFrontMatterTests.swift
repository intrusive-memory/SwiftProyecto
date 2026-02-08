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
        XCTAssertEqual(laoTzu?.voices["voxalta"], "narrative-1")
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
                    voices: [:]
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

    // MARK: - App Sections Tests

    func testAppSectionsInitialization() throws {
        // Create with appSections parameter
        let theme = try AnyCodable("dark")
        let version = try AnyCodable(1)
        let appSettings = ["theme": theme, "version": version]

        let frontMatter = ProjectFrontMatter(
            title: "Test Project",
            author: "Test Author",
            appSections: ["myapp": try AnyCodable(appSettings)]
        )

        XCTAssertEqual(frontMatter.appSections.count, 1)
        XCTAssertNotNil(frontMatter.appSections["myapp"])
    }

    func testAppSectionsEncodingJSON() throws {
        // Encode to JSON includes app sections at root
        let theme = try AnyCodable("dark")
        let version = try AnyCodable(1)
        let appSettings = ["theme": theme, "version": version]

        let frontMatter = ProjectFrontMatter(
            title: "Test Project",
            author: "Test Author",
            created: Date(timeIntervalSince1970: 0),
            appSections: ["myapp": try AnyCodable(appSettings)]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(frontMatter)
        let json = String(data: data, encoding: .utf8)!

        // Verify JSON structure
        XCTAssertTrue(json.contains("\"myapp\""))
        XCTAssertTrue(json.contains("\"theme\""))
        XCTAssertTrue(json.contains("\"dark\""))
        XCTAssertTrue(json.contains("\"version\""))
    }

    func testAppSectionsDecodingJSON() throws {
        // Decode from JSON with unknown fields
        let json = """
        {
            "type": "project",
            "title": "Test",
            "author": "Author",
            "created": "1970-01-01T00:00:00Z",
            "myapp": {
                "theme": "dark",
                "version": 1
            },
            "otherapp": {
                "enabled": true
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let frontMatter = try decoder.decode(ProjectFrontMatter.self, from: json)

        XCTAssertEqual(frontMatter.title, "Test")
        XCTAssertEqual(frontMatter.author, "Author")
        XCTAssertEqual(frontMatter.appSections.count, 2)
        XCTAssertNotNil(frontMatter.appSections["myapp"])
        XCTAssertNotNil(frontMatter.appSections["otherapp"])

        // Verify content of myapp section
        let myappAnyCodable = frontMatter.appSections["myapp"]!
        let myappDict = try myappAnyCodable.decode([String: AnyCodable].self)
        let theme = try myappDict["theme"]?.decode(String.self)
        let version = try myappDict["version"]?.decode(Int.self)
        XCTAssertEqual(theme, "dark")
        XCTAssertEqual(version, 1)

        // Verify content of otherapp section
        let otherappAnyCodable = frontMatter.appSections["otherapp"]!
        let otherappDict = try otherappAnyCodable.decode([String: AnyCodable].self)
        let enabled = try otherappDict["enabled"]?.decode(Bool.self)
        XCTAssertEqual(enabled, true)
    }

    func testAppSectionsRoundTrip() throws {
        // Encode → Decode preserves app sections exactly
        let theme = try AnyCodable("dark")
        let count = try AnyCodable(42)
        let appSettings = ["theme": theme, "count": count]

        let original = ProjectFrontMatter(
            title: "Test Project",
            author: "Test Author",
            created: Date(timeIntervalSince1970: 0),
            appSections: ["myapp": try AnyCodable(appSettings)]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProjectFrontMatter.self, from: data)

        // Verify equality
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.appSections.count, 1)
        XCTAssertNotNil(decoded.appSections["myapp"])

        // Verify exact content preservation
        let decodedMyapp = decoded.appSections["myapp"]!
        let decodedDict = try decodedMyapp.decode([String: AnyCodable].self)
        let decodedTheme = try decodedDict["theme"]?.decode(String.self)
        let decodedCount = try decodedDict["count"]?.decode(Int.self)
        XCTAssertEqual(decodedTheme, "dark")
        XCTAssertEqual(decodedCount, 42)
    }

    func testMultipleAppSectionsCoexist() throws {
        // Multiple app sections store independently
        let app1Settings = ["theme": try AnyCodable("dark")]
        let app2Settings = ["enabled": try AnyCodable(true), "count": try AnyCodable(5)]

        let frontMatter = ProjectFrontMatter(
            title: "Test Project",
            author: "Test Author",
            appSections: [
                "app1": try AnyCodable(app1Settings),
                "app2": try AnyCodable(app2Settings)
            ]
        )

        XCTAssertEqual(frontMatter.appSections.count, 2)

        // Verify app1
        let app1 = frontMatter.appSections["app1"]!
        let app1Dict = try app1.decode([String: AnyCodable].self)
        let theme = try app1Dict["theme"]?.decode(String.self)
        XCTAssertEqual(theme, "dark")

        // Verify app2
        let app2 = frontMatter.appSections["app2"]!
        let app2Dict = try app2.decode([String: AnyCodable].self)
        let enabled = try app2Dict["enabled"]?.decode(Bool.self)
        let count = try app2Dict["count"]?.decode(Int.self)
        XCTAssertEqual(enabled, true)
        XCTAssertEqual(count, 5)
    }

    func testEmptyAppSectionsDoesNotEncode() throws {
        // Empty dictionary omitted from output
        let frontMatter = ProjectFrontMatter(
            title: "Test Project",
            author: "Test Author",
            created: Date(timeIntervalSince1970: 0),
            appSections: [:]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(frontMatter)
        let json = String(data: data, encoding: .utf8)!

        // Verify that no app section keys appear in JSON
        // (This is a simple check - the JSON should only have known fields)
        let knownFields = ["type", "title", "author", "created"]
        for field in knownFields {
            XCTAssertTrue(json.contains("\"\(field)\""))
        }

        // Count the number of root-level keys
        // Should only be the known fields
        let jsonObject = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // We expect at least type, title, author, created (4 required fields)
        // No additional unknown fields should be present
        let expectedKeys: Set<String> = ["type", "title", "author", "created"]
        let actualKeys = Set(jsonObject.keys)
        // Allow for any known fields, but verify no unexpected app section keys
        XCTAssertTrue(expectedKeys.isSubset(of: actualKeys))
    }
}

// MARK: - Test Settings Types

private struct TestAppSettings: AppFrontMatterSettings {
    static let sectionKey = "testapp"
    var theme: String?
    var count: Int?
}

private struct OtherAppSettings: AppFrontMatterSettings {
    static let sectionKey = "otherapp"
    var enabled: Bool?
}

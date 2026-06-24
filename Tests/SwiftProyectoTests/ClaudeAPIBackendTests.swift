import XCTest
@testable import SwiftProyecto

final class ClaudeAPIBackendTests: XCTestCase {

  override func setUpWithError() throws {
    // Note: Tests don't require actual API key - we mock/skip accordingly
  }

  // MARK: - Test 1: Backend Initialization and Availability

  func testBackendInitialization() {
    let backend = ClaudeAPIBackend()
    XCTAssertEqual(backend.backendName, "Claude API")
  }

  func testBackendNameProperty() {
    let backend = ClaudeAPIBackend()
    XCTAssertEqual(backend.backendName, "Claude API")
  }

  func testIsAvailableWithAPIKey() {
    // Set the API key in environment
    setenv("CLAUDE_API_KEY", "test-key-123", 1)
    defer { unsetenv("CLAUDE_API_KEY") }

    let backend = ClaudeAPIBackend()
    XCTAssertTrue(backend.isAvailable, "Backend should be available when CLAUDE_API_KEY is set")
  }

  func testIsUnavailableWithoutAPIKey() {
    // Ensure API key is not set
    unsetenv("CLAUDE_API_KEY")

    let backend = ClaudeAPIBackend()
    XCTAssertFalse(backend.isAvailable, "Backend should be unavailable without CLAUDE_API_KEY")
  }

  func testInitializationWithExplicitAPIKey() {
    let backend = ClaudeAPIBackend(apiKey: "explicit-key-456")
    // isAvailable checks the environment variable, not the instance API key
    // So this may be false if CLAUDE_API_KEY is not set, which is correct behavior
    XCTAssertEqual(backend.backendName, "Claude API")
  }

  func testInitializationWithCustomModel() {
    let backend = ClaudeAPIBackend(
      apiKey: "test-key",
      model: "claude-3-opus-20240229"
    )
    XCTAssertEqual(backend.backendName, "Claude API")
  }

  // MARK: - Test 2: Protocol Conformance

  func testLLMBackendProtocolConformance() {
    let backend = ClaudeAPIBackend(apiKey: "test-key")
    let protocolBackend: LLMBackendProtocol = backend

    XCTAssertEqual(protocolBackend.backendName, "Claude API")
    // isAvailable depends on environment, not on instance initialization
  }

  // MARK: - Test 3: Error Handling - No API Key

  func testGenerationFailsWithoutAPIKey() async throws {
    // Ensure API key is not set
    unsetenv("CLAUDE_API_KEY")

    let backend = ClaudeAPIBackend()
    let analysis = ProjectAnalysis(
      projectPath: URL(fileURLWithPath: "/test/path")
    )

    do {
      _ = try await backend.generate(project: analysis)
      XCTFail("Should throw unavailable error when API key is missing")
    } catch LLMBackendError.unavailable(let reason) {
      XCTAssertTrue(reason.contains("CLAUDE_API_KEY"))
    } catch {
      XCTFail("Wrong error type: \(error)")
    }
  }

  // MARK: - Test 4: JSON Parsing - Valid Responses

  func testParseValidMinimalJSON() {
    let jsonString = """
    {
      "title": "Test Project",
      "author": "Test Author",
      "type": "podcast",
      "tags": []
    }
    """

    guard let jsonData = jsonString.data(using: .utf8) else {
      XCTFail("Could not encode JSON")
      return
    }

    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let parsedJSON = try decoder.decode(MetadataJSON.self, from: jsonData)
      let metadata = parsedJSON.toProjectMetadata()

      XCTAssertEqual(metadata.title, "Test Project")
      XCTAssertEqual(metadata.author, "Test Author")
      XCTAssertEqual(metadata.type, "podcast")
      XCTAssertEqual(metadata.tags.count, 0)
      XCTAssertNil(metadata.description)
      XCTAssertNil(metadata.episodes)
      XCTAssertNil(metadata.season)
    } catch {
      XCTFail("Failed to parse JSON: \(error)")
    }
  }

  func testParseValidFullJSON() {
    let jsonString = """
    {
      "title": "My Podcast",
      "author": "Jane Doe",
      "description": "An interesting podcast",
      "type": "podcast",
      "episodes": 24,
      "season": 1,
      "genre": "Technology",
      "tags": ["tech", "education", "interview"],
      "ttsProvider": "apple",
      "cast": [
        {
          "name": "Host",
          "actor": "Jane Doe",
          "voiceProvider": "apple",
          "voiceId": "com.apple.speech.synthesis.voice.Jane",
          "voiceDescription": "Professional host voice"
        },
        {
          "name": "Guest",
          "actor": null,
          "voiceProvider": null,
          "voiceId": null,
          "voiceDescription": null
        }
      ]
    }
    """

    guard let jsonData = jsonString.data(using: .utf8) else {
      XCTFail("Could not encode JSON")
      return
    }

    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let parsedJSON = try decoder.decode(MetadataJSON.self, from: jsonData)
      let metadata = parsedJSON.toProjectMetadata()

      XCTAssertEqual(metadata.title, "My Podcast")
      XCTAssertEqual(metadata.author, "Jane Doe")
      XCTAssertEqual(metadata.description, "An interesting podcast")
      XCTAssertEqual(metadata.type, "podcast")
      XCTAssertEqual(metadata.episodes, 24)
      XCTAssertEqual(metadata.season, 1)
      XCTAssertEqual(metadata.genre, "Technology")
      XCTAssertEqual(metadata.tags.count, 3)
      XCTAssertEqual(metadata.tags[0], "tech")
      XCTAssertEqual(metadata.ttsProvider, "apple")
      XCTAssertEqual(metadata.cast.count, 2)
      XCTAssertEqual(metadata.cast[0].name, "Host")
      XCTAssertEqual(metadata.cast[0].actor, "Jane Doe")
      XCTAssertEqual(metadata.cast[1].name, "Guest")
      XCTAssertNil(metadata.cast[1].actor)
    } catch {
      XCTFail("Failed to parse JSON: \(error)")
    }
  }

  // MARK: - Test 5: JSON Parsing - Optional Fields

  func testParseJSONWithMissingOptionalFields() {
    let jsonString = """
    {
      "title": "Minimal Project",
      "author": "Author",
      "type": "series"
    }
    """

    guard let jsonData = jsonString.data(using: .utf8) else {
      XCTFail("Could not encode JSON")
      return
    }

    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let parsedJSON = try decoder.decode(MetadataJSON.self, from: jsonData)
      let metadata = parsedJSON.toProjectMetadata()

      XCTAssertEqual(metadata.title, "Minimal Project")
      XCTAssertEqual(metadata.author, "Author")
      XCTAssertNil(metadata.description)
      XCTAssertNil(metadata.episodes)
      XCTAssertNil(metadata.season)
      XCTAssertNil(metadata.genre)
      XCTAssertTrue(metadata.tags.isEmpty)
      XCTAssertTrue(metadata.cast.isEmpty)
    } catch {
      XCTFail("Failed to parse JSON: \(error)")
    }
  }

  func testParseJSONWithNullValues() {
    let jsonString = """
    {
      "title": "Project",
      "author": "Author",
      "description": null,
      "type": "podcast",
      "episodes": null,
      "season": null,
      "genre": null,
      "tags": null,
      "ttsProvider": null,
      "cast": null
    }
    """

    guard let jsonData = jsonString.data(using: .utf8) else {
      XCTFail("Could not encode JSON")
      return
    }

    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let parsedJSON = try decoder.decode(MetadataJSON.self, from: jsonData)
      let metadata = parsedJSON.toProjectMetadata()

      XCTAssertEqual(metadata.title, "Project")
      XCTAssertNil(metadata.description)
      XCTAssertNil(metadata.episodes)
      XCTAssertNil(metadata.season)
      XCTAssertNil(metadata.ttsProvider)
      XCTAssertTrue(metadata.cast.isEmpty)
    } catch {
      XCTFail("Failed to parse JSON: \(error)")
    }
  }

  // MARK: - Test 6: JSON Parsing - Extra Fields

  func testParseJSONWithExtraFields() {
    let jsonString = """
    {
      "title": "Project",
      "author": "Author",
      "type": "podcast",
      "tags": [],
      "extraField": "should be ignored",
      "anotherField": 123
    }
    """

    guard let jsonData = jsonString.data(using: .utf8) else {
      XCTFail("Could not encode JSON")
      return
    }

    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let parsedJSON = try decoder.decode(MetadataJSON.self, from: jsonData)
      let metadata = parsedJSON.toProjectMetadata()

      XCTAssertEqual(metadata.title, "Project")
      XCTAssertEqual(metadata.author, "Author")
    } catch {
      XCTFail("Failed to parse JSON with extra fields: \(error)")
    }
  }

  // MARK: - Test 7: JSON Parsing - Nested Cast Members

  func testParseJSONWithComplexCastStructure() {
    let jsonString = """
    {
      "title": "Complex Cast Project",
      "author": "Author",
      "type": "podcast",
      "tags": [],
      "cast": [
        {
          "name": "Character One",
          "actor": "Actor Name",
          "voiceProvider": "apple",
          "voiceId": "voice-id-1",
          "voiceDescription": "Deep male voice"
        },
        {
          "name": "Character Two",
          "actor": "Another Actor",
          "voiceProvider": "google",
          "voiceId": "voice-id-2",
          "voiceDescription": null
        },
        {
          "name": "Character Three"
        }
      ]
    }
    """

    guard let jsonData = jsonString.data(using: .utf8) else {
      XCTFail("Could not encode JSON")
      return
    }

    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let parsedJSON = try decoder.decode(MetadataJSON.self, from: jsonData)
      let metadata = parsedJSON.toProjectMetadata()

      XCTAssertEqual(metadata.cast.count, 3)
      XCTAssertEqual(metadata.cast[0].name, "Character One")
      XCTAssertEqual(metadata.cast[0].actor, "Actor Name")
      XCTAssertEqual(metadata.cast[0].voiceProvider, "apple")
      XCTAssertEqual(metadata.cast[1].voiceProvider, "google")
      XCTAssertEqual(metadata.cast[2].actor, nil)
    } catch {
      XCTFail("Failed to parse complex cast JSON: \(error)")
    }
  }

  // MARK: - Test 8: Token Usage Logging

  func testBackendCanBeInitializedWithDifferentModels() {
    let models = [
      "claude-3-5-sonnet-20241022",
      "claude-3-opus-20240229",
      "claude-3-haiku-20240307"
    ]

    for modelName in models {
      let backend = ClaudeAPIBackend(apiKey: "test", model: modelName)
      XCTAssertEqual(backend.backendName, "Claude API")
      // Can be initialized with any model; availability depends on environment
    }
  }

  // MARK: - Test 9: Project Analysis to Metadata Conversion

  func testCompleteProjectAnalysisFlow() {
    let analysis = ProjectAnalysis(
      projectPath: URL(fileURLWithPath: "/test/lingua-matra"),
      discoveredFiles: [
        "s01e01_spanish.fountain",
        "s01e02_spanish.fountain",
        "s01e01_italian.fountain"
      ],
      extractedCast: ["Elena Martinez", "Marco Rossi", "Francesca Bianchi"],
      episodePattern: "s\\d+e\\d+",
      inferredTitle: "Lingua Matra",
      detectedLanguages: ["es", "it"]
    )

    XCTAssertEqual(analysis.discoveredFiles.count, 3)
    XCTAssertEqual(analysis.extractedCast.count, 3)
    XCTAssertEqual(analysis.detectedLanguages.count, 2)
    XCTAssertEqual(analysis.inferredTitle, "Lingua Matra")
  }

  // MARK: - Test 10: CastMemberData Creation

  func testCastMemberDataCreation() {
    let castMember = CastMemberData(
      name: "Test Character",
      actor: "Test Actor",
      voiceProvider: "apple",
      voiceId: "voice-123",
      voiceDescription: "A unique voice"
    )

    XCTAssertEqual(castMember.name, "Test Character")
    XCTAssertEqual(castMember.actor, "Test Actor")
    XCTAssertEqual(castMember.voiceProvider, "apple")
    XCTAssertEqual(castMember.voiceId, "voice-123")
    XCTAssertEqual(castMember.voiceDescription, "A unique voice")
  }

  func testCastMemberDataWithOptionalFields() {
    let castMember = CastMemberData(name: "Minimal Character")

    XCTAssertEqual(castMember.name, "Minimal Character")
    XCTAssertNil(castMember.actor)
    XCTAssertNil(castMember.voiceProvider)
    XCTAssertNil(castMember.voiceId)
    XCTAssertNil(castMember.voiceDescription)
  }

  // MARK: - Test 11: ProjectMetadata Creation

  func testProjectMetadataCreation() {
    let cast = [
      CastMemberData(name: "Character A"),
      CastMemberData(name: "Character B")
    ]

    let metadata = ProjectMetadata(
      title: "Test Series",
      author: "Test Author",
      description: "A test series",
      created: Date(),
      type: "podcast",
      episodes: 12,
      season: 1,
      genre: "Drama",
      tags: ["drama", "test"],
      ttsProvider: "apple",
      cast: cast
    )

    XCTAssertEqual(metadata.title, "Test Series")
    XCTAssertEqual(metadata.author, "Test Author")
    XCTAssertEqual(metadata.description, "A test series")
    XCTAssertEqual(metadata.type, "podcast")
    XCTAssertEqual(metadata.episodes, 12)
    XCTAssertEqual(metadata.season, 1)
    XCTAssertEqual(metadata.genre, "Drama")
    XCTAssertEqual(metadata.tags.count, 2)
    XCTAssertEqual(metadata.ttsProvider, "apple")
    XCTAssertEqual(metadata.cast.count, 2)
  }

  // MARK: - Test 12: Edge Cases in JSON Parsing

  func testParseJSONWithEmptyArrays() {
    let jsonString = """
    {
      "title": "Empty Arrays Project",
      "author": "Author",
      "type": "podcast",
      "tags": [],
      "cast": []
    }
    """

    guard let jsonData = jsonString.data(using: .utf8) else {
      XCTFail("Could not encode JSON")
      return
    }

    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let parsedJSON = try decoder.decode(MetadataJSON.self, from: jsonData)
      let metadata = parsedJSON.toProjectMetadata()

      XCTAssertTrue(metadata.tags.isEmpty)
      XCTAssertTrue(metadata.cast.isEmpty)
    } catch {
      XCTFail("Failed to parse JSON with empty arrays: \(error)")
    }
  }

  func testParseJSONWithSpecialCharacters() {
    let jsonString = """
    {
      "title": "Café au Lait: A Story",
      "author": "José García",
      "description": "Contains \\"quotes\\" and\\nescapes",
      "type": "podcast",
      "tags": ["café", "español", "français"],
      "cast": []
    }
    """

    guard let jsonData = jsonString.data(using: .utf8) else {
      XCTFail("Could not encode JSON")
      return
    }

    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let parsedJSON = try decoder.decode(MetadataJSON.self, from: jsonData)
      let metadata = parsedJSON.toProjectMetadata()

      XCTAssertTrue(metadata.title.contains("Café"))
      XCTAssertTrue(metadata.author.contains("José"))
      XCTAssertTrue(metadata.tags.contains("español"))
    } catch {
      XCTFail("Failed to parse JSON with special characters: \(error)")
    }
  }

  func testParseJSONWithLargeNumbers() {
    let jsonString = """
    {
      "title": "Large Project",
      "author": "Author",
      "type": "podcast",
      "episodes": 1000,
      "season": 99,
      "tags": []
    }
    """

    guard let jsonData = jsonString.data(using: .utf8) else {
      XCTFail("Could not encode JSON")
      return
    }

    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let parsedJSON = try decoder.decode(MetadataJSON.self, from: jsonData)
      let metadata = parsedJSON.toProjectMetadata()

      XCTAssertEqual(metadata.episodes, 1000)
      XCTAssertEqual(metadata.season, 99)
    } catch {
      XCTFail("Failed to parse JSON with large numbers: \(error)")
    }
  }

  // MARK: - Test 13: Backend Registration

  func testBackendRegistersWithRegistry() {
    // Create a new registry (not the shared one)
    let registry = BackendRegistry()
    let backend = ClaudeAPIBackend(apiKey: "test")
    registry.register(backend)

    // The backend is registered, but backend(named:) only returns it if isAvailable=true
    // Since isAvailable depends on CLAUDE_API_KEY env var, we just check allBackends
    let all = registry.allBackends()
    XCTAssertTrue(all.count > 0)
    XCTAssertEqual(all[0].backendName, "Claude API")
  }

  // MARK: - Test 14: Multiple Instances

  func testMultipleBackendInstances() {
    let backend1 = ClaudeAPIBackend(apiKey: "key1")
    let backend2 = ClaudeAPIBackend(apiKey: "key2")

    XCTAssertEqual(backend1.backendName, backend2.backendName)
    // isAvailable is determined by environment, not instance initialization
  }
}


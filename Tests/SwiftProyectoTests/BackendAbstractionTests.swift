import XCTest

@testable import SwiftProyecto

final class BackendAbstractionTests: XCTestCase {

  // MARK: - Test 1: LLMBackendProtocol Conformance

  func testProtocolConformance() {
    // Create a mock backend that conforms to LLMBackendProtocol
    let mockBackend = MockLLMBackend(
      name: "Test Backend",
      available: true
    )

    // Verify protocol properties
    XCTAssertEqual(mockBackend.backendName, "Test Backend")
    XCTAssertTrue(mockBackend.isAvailable)
  }

  func testBackendGeneration() async throws {
    let mockBackend = MockLLMBackend(
      name: "Test Generator",
      available: true
    )

    let analysis = ProjectAnalysis(
      projectPath: URL(fileURLWithPath: "/test/path"),
      discoveredFiles: ["episode1.fountain", "episode2.fountain"],
      extractedCast: ["Character A", "Character B"],
      episodePattern: "episode_\\d+",
      inferredTitle: "Test Project",
      detectedLanguages: ["en"]
    )

    let metadata = try await mockBackend.generate(project: analysis)

    XCTAssertEqual(metadata.title, "Test Project")
    XCTAssertEqual(metadata.author, "Test Author")
    XCTAssertEqual(metadata.cast.count, 2)
    XCTAssertEqual(metadata.cast[0].name, "Character A")
  }

  // MARK: - Test 2: BackendRegistry Singleton

  func testRegistrySingleton() {
    // Get the shared instance multiple times
    let registry1 = BackendRegistry.shared
    let registry2 = BackendRegistry.shared

    // Should be the same instance (identity comparison)
    XCTAssertTrue(registry1 === registry2)
  }

  // MARK: - Test 3: Backend Registration

  func testRegisterBackend() {
    let registry = BackendRegistry()
    let backend = MockLLMBackend(
      name: "Test Backend 1",
      available: true
    )

    registry.register(backend)

    let registered = registry.allBackends()
    XCTAssertEqual(registered.count, 1)
    XCTAssertEqual(registered[0].backendName, "Test Backend 1")
  }

  func testRegisterMultipleBackends() {
    let registry = BackendRegistry()
    let backend1 = MockLLMBackend(name: "Backend 1", available: true)
    let backend2 = MockLLMBackend(name: "Backend 2", available: true)
    let backend3 = MockLLMBackend(name: "Backend 3", available: false)

    registry.register(backend1)
    registry.register(backend2)
    registry.register(backend3)

    let all = registry.allBackends()
    XCTAssertEqual(all.count, 3)

    let available = registry.availableBackends()
    XCTAssertEqual(available.count, 2)
  }

  // MARK: - Test 4: Available Backends Filtering

  func testAvailableBackendsFiltering() {
    let registry = BackendRegistry()

    let availableBackend = MockLLMBackend(
      name: "Available Backend",
      available: true
    )
    let unavailableBackend = MockLLMBackend(
      name: "Unavailable Backend",
      available: false
    )

    registry.register(availableBackend)
    registry.register(unavailableBackend)

    let available = registry.availableBackends()

    XCTAssertEqual(available.count, 1)
    XCTAssertEqual(available[0].backendName, "Available Backend")
  }

  // MARK: - Test 5: Backend Lookup by Name

  func testBackendLookupByName() {
    let registry = BackendRegistry()
    let backend = MockLLMBackend(name: "Claude API", available: true)

    registry.register(backend)

    if let found = registry.backend(named: "Claude API") {
      XCTAssertEqual(found.backendName, "Claude API")
    } else {
      XCTFail("Backend 'Claude API' not found")
    }
  }

  func testBackendLookupReturnsNilForUnavailable() {
    let registry = BackendRegistry()
    let backend = MockLLMBackend(name: "Unavailable Backend", available: false)

    registry.register(backend)

    let found = registry.backend(named: "Unavailable Backend")
    XCTAssertNil(found, "Should not return unavailable backends")
  }

  func testBackendLookupReturnsNilForMissing() {
    let registry = BackendRegistry()

    let found = registry.backend(named: "Non-Existent Backend")
    XCTAssertNil(found)
  }

  func testBackendLookupReturnsFirst() {
    let registry = BackendRegistry()
    let backend1 = MockLLMBackend(name: "Claude API", available: true)
    let backend2 = MockLLMBackend(name: "Claude API", available: true)

    registry.register(backend1)
    registry.register(backend2)

    if let found = registry.backend(named: "Claude API") {
      XCTAssertEqual(found.backendName, "Claude API")
      XCTAssertTrue(found.isAvailable)
    } else {
      XCTFail("Should find first available backend")
    }
  }

  // MARK: - Test 6: OS Detection

  func testMacOSVersionDetection() {
    let (major, minor) = macOSVersion()

    // Should return valid version numbers
    XCTAssertGreaterThan(major, 0)
    XCTAssertGreaterThanOrEqual(minor, 0)
  }

  func testMacOSVersionAtLeastCheck() {
    let (major, minor) = macOSVersion()

    // Current version should be at least itself
    XCTAssertTrue(isMacOSVersionAtLeast(major: major, minor: minor))

    // Current version should be greater than an older version
    XCTAssertTrue(isMacOSVersionAtLeast(major: major - 1, minor: 0))

    // Current version should not be less than a future version
    if major < Int.max {
      XCTAssertFalse(isMacOSVersionAtLeast(major: major + 1, minor: 0))
    }
  }

  func testMacOSVersionComparison() {
    let (major, minor) = macOSVersion()

    // Test exact match
    XCTAssertTrue(isMacOSVersionAtLeast(major: major, minor: minor))

    // Test major version only
    if major > 0 {
      XCTAssertTrue(isMacOSVersionAtLeast(major: major - 1))
    }

    // Test higher minor version of current major
    if minor > 0 {
      XCTAssertFalse(isMacOSVersionAtLeast(major: major, minor: minor + 1))
    }
  }

  // MARK: - Test 7: Platform-Specific Backend Selection

  func testMacOS27PlusGating() {
    let (major, _) = macOSVersion()

    if major >= 27 {
      // On macOS 27+, Foundation Models backend should be available
      XCTAssertTrue(isMacOSVersionAtLeast(major: 27))
    } else {
      // On macOS 26, should require fallback to other backends
      XCTAssertFalse(isMacOSVersionAtLeast(major: 27))
    }
  }

  // MARK: - Test 8: ProjectAnalysis Structure

  func testProjectAnalysisCreation() {
    let projectPath = URL(fileURLWithPath: "/test/project")
    let files = ["file1.fountain", "file2.fountain"]
    let cast = ["Alice", "Bob"]
    let languages = ["en", "es"]

    let analysis = ProjectAnalysis(
      projectPath: projectPath,
      discoveredFiles: files,
      extractedCast: cast,
      episodePattern: "S\\dE\\d+",
      inferredTitle: "My Project",
      detectedLanguages: languages
    )

    XCTAssertEqual(analysis.projectPath, projectPath)
    XCTAssertEqual(analysis.discoveredFiles, files)
    XCTAssertEqual(analysis.extractedCast, cast)
    XCTAssertEqual(analysis.episodePattern, "S\\dE\\d+")
    XCTAssertEqual(analysis.inferredTitle, "My Project")
    XCTAssertEqual(analysis.detectedLanguages, languages)
  }

  // MARK: - Test 9: ProjectMetadata Structure

  func testProjectMetadataCreation() {
    let date = Date()
    let cast = [
      CastMemberData(name: "Character A", actor: "Actor A"),
      CastMemberData(name: "Character B", actor: "Actor B"),
    ]

    let metadata = ProjectMetadata(
      title: "My Series",
      author: "Jane Showrunner",
      description: "A test series",
      created: date,
      type: "project",
      episodes: 12,
      season: 1,
      genre: "Drama",
      tags: ["dramatic", "series"],
      ttsProvider: "apple",
      cast: cast
    )

    XCTAssertEqual(metadata.title, "My Series")
    XCTAssertEqual(metadata.author, "Jane Showrunner")
    XCTAssertEqual(metadata.description, "A test series")
    XCTAssertEqual(metadata.type, "project")
    XCTAssertEqual(metadata.episodes, 12)
    XCTAssertEqual(metadata.season, 1)
    XCTAssertEqual(metadata.genre, "Drama")
    XCTAssertEqual(metadata.tags.count, 2)
    XCTAssertEqual(metadata.ttsProvider, "apple")
    XCTAssertEqual(metadata.cast.count, 2)
  }

  // MARK: - Test 10: Error Handling

  func testLLMBackendError() {
    let error1 = LLMBackendError.unavailable(reason: "SDK not installed")
    let error2 = LLMBackendError.generationFailed(reason: "API error")
    let error3 = LLMBackendError.invalidInput(reason: "Missing field")

    XCTAssertNotNil(error1.errorDescription)
    XCTAssertNotNil(error2.errorDescription)
    XCTAssertNotNil(error3.errorDescription)

    XCTAssertTrue(error1.errorDescription!.contains("unavailable"))
    XCTAssertTrue(error2.errorDescription!.contains("generation failed"))
    XCTAssertTrue(error3.errorDescription!.contains("Invalid input"))
  }

  // MARK: - Test 11: Concurrent Registry Access

  func testConcurrentRegistration() {
    let registry = BackendRegistry()
    let dispatchGroup = DispatchGroup()
    let numBackends = 10

    for i in 0..<numBackends {
      dispatchGroup.enter()
      DispatchQueue.global().async {
        let backend = MockLLMBackend(name: "Backend \(i)", available: true)
        registry.register(backend)
        dispatchGroup.leave()
      }
    }

    dispatchGroup.wait()

    let allBackends = registry.allBackends()
    XCTAssertEqual(allBackends.count, numBackends)
  }

  func testConcurrentLookup() {
    let registry = BackendRegistry()
    let backend = MockLLMBackend(name: "Test", available: true)
    registry.register(backend)

    let dispatchGroup = DispatchGroup()
    let numLookups = 10

    for _ in 0..<numLookups {
      dispatchGroup.enter()
      DispatchQueue.global().async {
        // Each thread performs a lookup independently
        let found = registry.backend(named: "Test")
        // Verify the result is correct
        if found == nil {
          XCTFail("Expected to find backend")
        }
        dispatchGroup.leave()
      }
    }

    dispatchGroup.wait()

    // If we got here without failures, all lookups succeeded
    let found = registry.backend(named: "Test")
    XCTAssertNotNil(found)
    XCTAssertEqual(found?.backendName, "Test")
  }
}

// MARK: - Mock Backend Implementation

/// Mock LLM backend for testing.
private struct MockLLMBackend: LLMBackendProtocol {
  let backendName: String
  let isAvailable: Bool

  init(name: String, available: Bool) {
    self.backendName = name
    self.isAvailable = available
  }

  func generate(project: ProjectAnalysis) async throws -> ProjectMetadata {
    return ProjectMetadata(
      title: project.inferredTitle ?? "Generated Project",
      author: "Test Author",
      description: "Generated from \(project.discoveredFiles.count) files",
      created: Date(),
      type: "project",
      episodes: project.discoveredFiles.count,
      cast: project.extractedCast.map { CastMemberData(name: $0) }
    )
  }
}

// MARK: - NSLock Extension for Testing

extension NSLock {
  fileprivate func withLock<T>(_ body: () -> T) -> T {
    lock()
    defer { unlock() }
    return body()
  }
}

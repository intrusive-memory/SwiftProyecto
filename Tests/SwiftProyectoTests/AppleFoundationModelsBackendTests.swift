import XCTest

@testable import SwiftProyecto

final class AppleFoundationModelsBackendTests: XCTestCase {

  // MARK: - Setup & Utilities

  private let testProjectPath = URL(fileURLWithPath: "/test/project")

  private func makeTestAnalysis(
    title: String = "Test Project",
    files: [String] = ["episode1.fountain", "episode2.fountain"],
    cast: [String] = ["Alice", "Bob"]
  ) -> ProjectAnalysis {
    ProjectAnalysis(
      projectPath: testProjectPath,
      discoveredFiles: files,
      extractedCast: cast,
      episodePattern: "episode_\\d+",
      inferredTitle: title,
      detectedLanguages: ["en"]
    )
  }

  // MARK: - Test 1: Backend Initialization

  func testBackendInitialization() {
    let backend = AppleFoundationModelsBackend()
    XCTAssertNotNil(backend, "Backend should initialize successfully")
    XCTAssertEqual(backend.backendName, "Apple Foundation Models")
  }

  // MARK: - Test 2: Platform Version Gating

  func testAvailabilityBasedOnMacOSVersion() {
    let backend = AppleFoundationModelsBackend()

    // Check platform version
    let (majorVersion, _) = macOSVersion()

    if majorVersion >= 27 {
      // On macOS 27+, backend should be available
      XCTAssertTrue(backend.isAvailable, "Backend should be available on macOS 27+")
    } else {
      // On older macOS, backend should be unavailable
      XCTAssertFalse(backend.isAvailable, "Backend should not be available on macOS < 27")
    }
  }

  // MARK: - Test 3: macOS Version Detection

  func testMacOSVersionDetection() {
    let (major, minor) = macOSVersion()
    XCTAssertGreaterThanOrEqual(major, 20, "Major version should be at least 20 (macOS 20+)")
    XCTAssertGreaterThanOrEqual(minor, 0, "Minor version should be non-negative")
  }

  // MARK: - Test 4: Version Comparison Function

  func testIsMacOSVersionAtLeast() {
    let (major, _) = macOSVersion()

    // Current version should always be at least itself
    XCTAssertTrue(isMacOSVersionAtLeast(major: major))

    // Earlier versions should always qualify
    if major > 10 {
      XCTAssertTrue(isMacOSVersionAtLeast(major: major - 1))
    }

    // Much later versions should not qualify
    XCTAssertFalse(isMacOSVersionAtLeast(major: 100))
  }

  // MARK: - Test 5: Generation on macOS 27+

  @available(macOS 27, *)
  func testGenerationOnMacOS27AndLater() async throws {
    let backend = AppleFoundationModelsBackend()

    // This test only runs on macOS 27+
    guard isMacOSVersionAtLeast(major: 27) else {
      throw XCTSkip("Test requires macOS 27+")
    }

    let analysis = makeTestAnalysis()
    let metadata = try await backend.generate(project: analysis)

    XCTAssertNotNil(metadata)
    XCTAssertFalse(metadata.title.isEmpty, "Title should not be empty")
    XCTAssertEqual(metadata.type, "project")
  }

  // MARK: - Test 6: Unavailability on macOS < 27

  func testUnavailabilityErrorOnOldermacOS() async {
    let (major, _) = macOSVersion()

    // Skip if running on macOS 27+
    guard major < 27 else {
      return
    }

    let backend = AppleFoundationModelsBackend()
    let analysis = makeTestAnalysis()

    do {
      _ = try await backend.generate(project: analysis)
      XCTFail("Should throw unavailable error on macOS < 27")
    } catch let error as LLMBackendError {
      if case .unavailable(let reason) = error {
        XCTAssertTrue(reason.contains("macOS 27") || reason.contains("27"))
      } else {
        XCTFail("Should throw unavailable error, got: \(error)")
      }
    } catch {
      XCTFail("Should throw LLMBackendError, got: \(error)")
    }
  }

  // MARK: - Test 7: Backend Name Property

  func testBackendName() {
    let backend = AppleFoundationModelsBackend()
    XCTAssertEqual(backend.backendName, "Apple Foundation Models")
  }

  // MARK: - Test 8: Protocol Conformance

  func testConformsToLLMBackendProtocol() {
    let backend = AppleFoundationModelsBackend()

    // Verify protocol conformance
    let _: LLMBackendProtocol = backend

    XCTAssertTrue(true, "Backend conforms to LLMBackendProtocol")
  }

  // MARK: - Test 9: Sendable Conformance

  func testSendableConformance() {
    let backend = AppleFoundationModelsBackend()

    // This should compile and not throw
    Task {
      let _: AppleFoundationModelsBackend = backend
    }

    XCTAssertTrue(true, "Backend is Sendable")
  }

  // MARK: - Test 10: Generation with Minimal Analysis

  @available(macOS 27, *)
  func testGenerationWithMinimalAnalysis() async throws {
    guard isMacOSVersionAtLeast(major: 27) else {
      throw XCTSkip("Test requires macOS 27+")
    }

    let backend = AppleFoundationModelsBackend()
    let emptyAnalysis = ProjectAnalysis(projectPath: testProjectPath)

    let metadata = try await backend.generate(project: emptyAnalysis)

    XCTAssertNotNil(metadata)
    XCTAssertFalse(metadata.title.isEmpty)
  }

  // MARK: - Test 11: Generation with Full Analysis

  @available(macOS 27, *)
  func testGenerationWithFullAnalysis() async throws {
    guard isMacOSVersionAtLeast(major: 27) else {
      throw XCTSkip("Test requires macOS 27+")
    }

    let backend = AppleFoundationModelsBackend()
    let analysis = ProjectAnalysis(
      projectPath: testProjectPath,
      discoveredFiles: [
        "episode1.fountain",
        "episode2.fountain",
        "episode3.fountain",
      ],
      extractedCast: ["Alice", "Bob", "Charlie"],
      episodePattern: "episode_\\d+",
      inferredTitle: "My Audio Project",
      detectedLanguages: ["en", "es"]
    )

    let metadata = try await backend.generate(project: analysis)

    XCTAssertNotNil(metadata)
    XCTAssertFalse(metadata.title.isEmpty)
    XCTAssertEqual(metadata.type, "project")
  }

  // MARK: - Test 12: Backend Registration in Registry

  func testBackendRegistersWithRegistry() {
    // The backend should auto-register via the module init
    let registry = BackendRegistry()

    // Create a fresh backend for manual registration
    let backend = AppleFoundationModelsBackend()

    // Only register if not already in the registry
    let beforeCount = registry.allBackends().count
    registry.register(backend)
    let afterCount = registry.allBackends().count

    XCTAssertEqual(afterCount, beforeCount + 1, "Backend should register successfully")
  }

  // MARK: - Test 13: Availability Check Doesn't Fail

  func testAvailabilityCheckNeverThrows() {
    let backend = AppleFoundationModelsBackend()

    // This should never throw
    let isAvailable = backend.isAvailable

    XCTAssertNotNil(isAvailable, "Availability check should return a boolean")
  }

  // MARK: - Test 14: Generation Metadata Validation

  @available(macOS 27, *)
  func testGeneratedMetadataValidation() async throws {
    guard isMacOSVersionAtLeast(major: 27) else {
      throw XCTSkip("Test requires macOS 27+")
    }

    let backend = AppleFoundationModelsBackend()
    let analysis = makeTestAnalysis(title: "My Project")

    let metadata = try await backend.generate(project: analysis)

    // Validate basic metadata structure
    XCTAssertFalse(metadata.title.isEmpty, "Title must not be empty")
    XCTAssertFalse(metadata.author.isEmpty, "Author must not be empty")
    XCTAssertEqual(metadata.type, "project", "Type must be 'project'")
    XCTAssertNotNil(metadata.created, "Created date must be set")
  }

  // MARK: - Test 15: Generation with Special Characters in Paths

  @available(macOS 27, *)
  func testGenerationWithSpecialCharactersInPath() async throws {
    guard isMacOSVersionAtLeast(major: 27) else {
      throw XCTSkip("Test requires macOS 27+")
    }

    let backend = AppleFoundationModelsBackend()
    let specialPath = URL(fileURLWithPath: "/test/project with spaces & symbols/")
    let analysis = ProjectAnalysis(projectPath: specialPath)

    let metadata = try await backend.generate(project: analysis)

    XCTAssertNotNil(metadata)
    XCTAssertFalse(metadata.title.isEmpty)
  }

  // MARK: - Test 16: Concurrent Generation Calls

  @available(macOS 27, *)
  func testConcurrentGenerationCalls() async throws {
    guard isMacOSVersionAtLeast(major: 27) else {
      throw XCTSkip("Test requires macOS 27+")
    }

    let backend = AppleFoundationModelsBackend()
    let analysis = makeTestAnalysis()

    // Run multiple concurrent calls
    let results = try await withThrowingTaskGroup(
      of: ProjectMetadata.self,
      returning: [ProjectMetadata].self
    ) { group in
      for _ in 0..<3 {
        group.addTask {
          try await backend.generate(project: analysis)
        }
      }

      var results: [ProjectMetadata] = []
      for try await result in group {
        results.append(result)
      }
      return results
    }

    XCTAssertEqual(results.count, 3, "All concurrent calls should complete")
    for metadata in results {
      XCTAssertFalse(metadata.title.isEmpty)
    }
  }

  // MARK: - Test 17: Multiple Backend Instances

  func testMultipleBackendInstances() {
    let backend1 = AppleFoundationModelsBackend()
    let backend2 = AppleFoundationModelsBackend()

    XCTAssertEqual(backend1.backendName, backend2.backendName)
    XCTAssertEqual(backend1.isAvailable, backend2.isAvailable)
  }

  // MARK: - Test 18: Backend Error Messages

  func testBackendErrorMessages() async {
    let backend = AppleFoundationModelsBackend()

    let (major, _) = macOSVersion()
    guard major < 27 else {
      // Skip on macOS 27+
      return
    }

    let analysis = makeTestAnalysis()

    // Attempt generation and check error message
    do {
      _ = try await backend.generate(project: analysis)
      XCTFail("Should have thrown an error")
    } catch let error as LLMBackendError {
      if case .unavailable(let reason) = error {
        XCTAssertTrue(
          reason.contains("macOS 27") || reason.contains("27"),
          "Error message should mention macOS 27 requirement"
        )
      } else {
        XCTFail("Expected unavailable error, got: \(error)")
      }
    } catch {
      XCTFail("Wrong error type: \(error)")
    }
  }

  // MARK: - Test 19: Analysis Data Preservation

  @available(macOS 27, *)
  func testAnalysisDataPreservation() async throws {
    guard isMacOSVersionAtLeast(major: 27) else {
      throw XCTSkip("Test requires macOS 27+")
    }

    let backend = AppleFoundationModelsBackend()
    let files = ["file1.txt", "file2.txt", "file3.txt"]
    let cast = ["Character1", "Character2"]

    let analysis = ProjectAnalysis(
      projectPath: testProjectPath,
      discoveredFiles: files,
      extractedCast: cast,
      episodePattern: "ep_\\d+",
      inferredTitle: "Test Title",
      detectedLanguages: ["en", "fr"]
    )

    let metadata = try await backend.generate(project: analysis)

    // Backend should process the analysis without throwing
    XCTAssertNotNil(metadata)
  }

  // MARK: - Test 20: Date Handling

  @available(macOS 27, *)
  func testGeneratedMetadataDateHandling() async throws {
    guard isMacOSVersionAtLeast(major: 27) else {
      throw XCTSkip("Test requires macOS 27+")
    }

    let backend = AppleFoundationModelsBackend()
    let analysis = makeTestAnalysis()

    let beforeDate = Date()
    let metadata = try await backend.generate(project: analysis)
    let afterDate = Date()

    XCTAssertTrue(
      metadata.created >= beforeDate && metadata.created <= afterDate,
      "Created date should be within generation timeframe"
    )
  }
}

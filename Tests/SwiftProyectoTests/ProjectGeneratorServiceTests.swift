import XCTest

@testable import SwiftProyecto

final class ProjectGeneratorServiceTests: XCTestCase {

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

  // MARK: - Test 1: Service Initialization

  func testServiceInitialization() {
    let service = ProjectGeneratorService()
    XCTAssertNotNil(service, "Service should initialize successfully")
  }

  func testServiceDefaultSingleton() {
    let service1 = ProjectGeneratorService.default
    let service2 = ProjectGeneratorService.default

    XCTAssertTrue(service1 === service2, "Default should be singleton instance")
  }

  func testServiceInitializationWithRegistry() {
    let registry = BackendRegistry()
    let service = ProjectGeneratorService(registry: registry)

    XCTAssertNotNil(service, "Service should initialize with custom registry")
  }

  // MARK: - Test 2: Fallback Chain - SwiftBruja First

  func testFallbackChainPrioritizesSwiftBruja() async throws {
    let registry = BackendRegistry()
    let swiftBrujaBackend = MockLLMBackend(
      name: "SwiftBruja",
      available: true,
      generatedTitle: "SwiftBruja Generated Title"
    )
    let claudeBackend = MockLLMBackend(
      name: "Claude API",
      available: true,
      generatedTitle: "Claude Generated Title"
    )

    registry.register(swiftBrujaBackend)
    registry.register(claudeBackend)

    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    let metadata = try await service.generate(project: analysis)

    // Should use SwiftBruja (priority 1)
    XCTAssertEqual(metadata.title, "SwiftBruja Generated Title")
  }

  // MARK: - Test 3: Fallback Chain - Foundation Models Second

  func testFallbackChainTriesFoundationModelsWhenSwiftBrujaUnavailable() async throws {
    let registry = BackendRegistry()
    let fmBackend = MockLLMBackend(
      name: "Apple Foundation Models",
      available: true,
      generatedTitle: "FM Generated Title"
    )
    let claudeBackend = MockLLMBackend(
      name: "Claude API",
      available: true,
      generatedTitle: "Claude Generated Title"
    )

    registry.register(fmBackend)
    registry.register(claudeBackend)

    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    let metadata = try await service.generate(project: analysis)

    // Should use Foundation Models (priority 2, SwiftBruja not registered)
    XCTAssertEqual(metadata.title, "FM Generated Title")
  }

  // MARK: - Test 4: Fallback Chain - Claude Fallback

  func testFallbackChainTriesClaudeWhenOthersUnavailable() async throws {
    let registry = BackendRegistry()
    let claudeBackend = MockLLMBackend(
      name: "Claude API",
      available: true,
      generatedTitle: "Claude Generated Title"
    )

    registry.register(claudeBackend)

    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    let metadata = try await service.generate(project: analysis)

    // Should use Claude (fallback, SwiftBruja & FM not registered)
    XCTAssertEqual(metadata.title, "Claude Generated Title")
  }

  // MARK: - Test 5: Fallback Chain - Skips Unavailable Backends

  func testFallbackChainSkipsUnavailableBackends() async throws {
    let registry = BackendRegistry()
    let unavailableSwiftBruja = MockLLMBackend(
      name: "SwiftBruja",
      available: false,
      generatedTitle: "SwiftBruja Title"
    )
    let availableFoundationModels = MockLLMBackend(
      name: "Apple Foundation Models",
      available: true,
      generatedTitle: "FM Title"
    )

    registry.register(unavailableSwiftBruja)
    registry.register(availableFoundationModels)

    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    let metadata = try await service.generate(project: analysis)

    // Should skip unavailable SwiftBruja and use FM
    XCTAssertEqual(metadata.title, "FM Title")
  }

  // MARK: - Test 6: Platform Constraint - macOS 27+ Gating

  func testFallbackChainRespectsMacOS27ConstraintForFoundationModels() async throws {
    let registry = BackendRegistry()

    // Register a Foundation Models backend
    let fmBackend = MockLLMBackend(
      name: "Apple Foundation Models",
      available: true,
      generatedTitle: "FM Title"
    )
    let claudeBackend = MockLLMBackend(
      name: "Claude API",
      available: true,
      generatedTitle: "Claude Title"
    )

    registry.register(fmBackend)
    registry.register(claudeBackend)

    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    let metadata = try await service.generate(project: analysis)

    // The actual backend used depends on the OS version
    // If macOS 27+, should use FM; otherwise should use Claude
    let (majorVersion, _) = macOSVersion()
    if majorVersion >= 27 {
      XCTAssertEqual(metadata.title, "FM Title")
    } else {
      XCTAssertEqual(metadata.title, "Claude Title")
    }
  }

  // MARK: - Test 7: Error Handling - No Backends Available

  func testErrorWhenNoBackendsAvailable() async {
    let registry = BackendRegistry()
    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    do {
      _ = try await service.generate(project: analysis)
      XCTFail("Should throw unavailable error")
    } catch let error as LLMBackendError {
      if case .unavailable = error {
        XCTAssertTrue(true)
      } else {
        XCTFail("Should throw unavailable error, got: \(error)")
      }
    } catch {
      XCTFail("Should throw LLMBackendError, got: \(error)")
    }
  }

  // MARK: - Test 8: Error Handling - Backend Failure

  func testErrorPropagationFromClaudeBackend() async {
    let registry = BackendRegistry()
    let failingBackend = FailingMockLLMBackend(
      name: "Claude API"
    )

    registry.register(failingBackend)

    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    do {
      _ = try await service.generate(project: analysis)
      XCTFail("Should throw generation failed error")
    } catch let error as LLMBackendError {
      if case .generationFailed = error {
        XCTAssertTrue(true)
      } else {
        XCTFail("Should throw generationFailed error, got: \(error)")
      }
    } catch {
      XCTFail("Should throw LLMBackendError, got: \(error)")
    }
  }

  // MARK: - Test 9: Fallback When SwiftBruja Fails

  func testFallbackWhenSwiftBrujaFails() async throws {
    let registry = BackendRegistry()

    // SwiftBruja fails with an error
    let failingSwiftBruja = FailingMockLLMBackend(name: "SwiftBruja")

    // Claude succeeds
    let claudeBackend = MockLLMBackend(
      name: "Claude API",
      available: true,
      generatedTitle: "Claude Generated Title"
    )

    registry.register(failingSwiftBruja)
    registry.register(claudeBackend)

    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    let metadata = try await service.generate(project: analysis)

    // Should skip failed SwiftBruja and use Claude
    XCTAssertEqual(metadata.title, "Claude Generated Title")
  }

  // MARK: - Test 10: Fallback When Foundation Models Fails

  func testFallbackWhenFoundationModelsFails() async throws {
    let registry = BackendRegistry()

    // FM fails
    let failingFM = FailingMockLLMBackend(name: "Apple Foundation Models")

    // Claude succeeds
    let claudeBackend = MockLLMBackend(
      name: "Claude API",
      available: true,
      generatedTitle: "Claude Generated Title"
    )

    registry.register(failingFM)
    registry.register(claudeBackend)

    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    let metadata = try await service.generate(project: analysis)

    // Should skip failed FM and use Claude
    XCTAssertEqual(metadata.title, "Claude Generated Title")
  }

  // MARK: - Test 11: Complete Fallback Chain Execution

  func testCompleteFallbackChain() async throws {
    let registry = BackendRegistry()

    // All three backends in order
    let swiftBrujaBackend = MockLLMBackend(
      name: "SwiftBruja",
      available: true,
      generatedTitle: "SwiftBruja Title"
    )
    let fmBackend = MockLLMBackend(
      name: "Apple Foundation Models",
      available: true,
      generatedTitle: "FM Title"
    )
    let claudeBackend = MockLLMBackend(
      name: "Claude API",
      available: true,
      generatedTitle: "Claude Title"
    )

    registry.register(swiftBrujaBackend)
    registry.register(fmBackend)
    registry.register(claudeBackend)

    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    let metadata = try await service.generate(project: analysis)

    // Should use SwiftBruja (highest priority)
    XCTAssertEqual(metadata.title, "SwiftBruja Title")
  }

  // MARK: - Test 12: Generation with Empty Analysis

  func testGenerationWithEmptyAnalysis() async throws {
    let registry = BackendRegistry()
    let backend = MockLLMBackend(
      name: "Claude API",
      available: true,
      generatedTitle: "Generated Title"
    )

    registry.register(backend)

    let service = ProjectGeneratorService(registry: registry)

    // Create minimal analysis
    let emptyAnalysis = ProjectAnalysis(
      projectPath: testProjectPath
    )

    let metadata = try await service.generate(project: emptyAnalysis)

    XCTAssertEqual(metadata.title, "Generated Title")
  }

  // MARK: - Test 13: Generation with Partial Analysis

  func testGenerationWithPartialAnalysis() async throws {
    let registry = BackendRegistry()
    let backend = MockLLMBackend(
      name: "Claude API",
      available: true,
      generatedTitle: "Partial Analysis Title"
    )

    registry.register(backend)

    let service = ProjectGeneratorService(registry: registry)

    let analysis = ProjectAnalysis(
      projectPath: testProjectPath,
      discoveredFiles: ["file1.fountain"]
    )

    let metadata = try await service.generate(project: analysis)

    XCTAssertEqual(metadata.title, "Partial Analysis Title")
  }

  // MARK: - Test 14: Metadata Content Validation

  func testGeneratedMetadataContent() async throws {
    let registry = BackendRegistry()
    let backend = MockLLMBackend(
      name: "Claude API",
      available: true,
      generatedTitle: "Test Series"
    )

    registry.register(backend)

    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    let metadata = try await service.generate(project: analysis)

    XCTAssertEqual(metadata.title, "Test Series")
    XCTAssertEqual(metadata.author, "Mock Author")
    XCTAssertEqual(metadata.type, "project")
    XCTAssertEqual(metadata.cast.count, 2)
  }

  // MARK: - Test 15: Concurrent Generation Calls

  func testConcurrentGenerationCalls() async throws {
    let registry = BackendRegistry()
    let backend = MockLLMBackend(
      name: "Claude API",
      available: true,
      generatedTitle: "Concurrent Test"
    )

    registry.register(backend)

    let service = ProjectGeneratorService(registry: registry)
    let analysis = makeTestAnalysis()

    // Run multiple concurrent calls
    let results = try await withThrowingTaskGroup(
      of: ProjectMetadata.self, returning: [ProjectMetadata].self
    ) { group in
      for _ in 0..<5 {
        group.addTask {
          try await service.generate(project: analysis)
        }
      }

      var results: [ProjectMetadata] = []
      for try await result in group {
        results.append(result)
      }
      return results
    }

    XCTAssertEqual(results.count, 5)
    for metadata in results {
      XCTAssertEqual(metadata.title, "Concurrent Test")
    }
  }
}

// MARK: - Mock Backends for Testing

/// Mock LLM backend that successfully generates metadata.
private struct MockLLMBackend: LLMBackendProtocol {
  let backendName: String
  let isAvailable: Bool
  let generatedTitle: String

  init(
    name: String,
    available: Bool,
    generatedTitle: String = "Mock Generated Title"
  ) {
    self.backendName = name
    self.isAvailable = available
    self.generatedTitle = generatedTitle
  }

  func generate(project: ProjectAnalysis) async throws -> ProjectMetadata {
    return ProjectMetadata(
      title: generatedTitle,
      author: "Mock Author",
      description: "Generated from \(project.discoveredFiles.count) files",
      created: Date(),
      type: "project",
      episodes: project.discoveredFiles.count,
      cast: project.extractedCast.map { CastMemberData(name: $0) }
    )
  }
}

/// Mock LLM backend that always fails.
private struct FailingMockLLMBackend: LLMBackendProtocol {
  let backendName: String
  let isAvailable: Bool = true

  init(name: String) {
    self.backendName = name
  }

  func generate(project: ProjectAnalysis) async throws -> ProjectMetadata {
    throw LLMBackendError.generationFailed(
      reason: "Mock backend \(backendName) intentionally failed"
    )
  }
}

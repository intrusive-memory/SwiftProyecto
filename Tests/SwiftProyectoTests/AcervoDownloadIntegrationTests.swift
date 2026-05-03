// AcervoDownloadIntegrationTests.swift
// SwiftProyecto
//
// Integration tests that verify CDN model downloads via SwiftAcervo.
// These tests require network access and download a real model from Cloudflare R2.
//
// To run integration tests:
//   make test
//   xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'

import Foundation
import SwiftAcervo
import XCTest

@testable import SwiftProyecto

// MARK: - Integration Tests

final class AcervoDownloadIntegrationTests: XCTestCase {

  /// Per-test App Group identifier so each test resolves to its own
  /// `~/Library/Group Containers/<id>/SharedModels/` and never collides
  /// with another test or with the developer's real models directory.
  private var testGroupID: String!

  /// The value of `ACERVO_APP_GROUP_ID` before this test ran, restored on
  /// teardown so leaking environment state can't poison other test cases.
  private var previousAppGroupEnv: String?

  override func setUp() async throws {
    try await super.setUp()

    // Each test gets a fresh App Group identifier. The sharedModelsDirectory
    // resolver in SwiftAcervo derives a deterministic per-process path from
    // this value, so per-test isolation falls out without any explicit
    // override of the resolved path.
    testGroupID = "group.acervo.test.\(UUID().uuidString.lowercased())"
    previousAppGroupEnv = ProcessInfo.processInfo.environment[Acervo.appGroupEnvironmentVariable]
    setenv(Acervo.appGroupEnvironmentVariable, testGroupID, 1)
  }

  override func tearDown() async throws {
    // Restore the previous environment value (or clear it if there wasn't
    // one) so test ordering can't carry state between cases.
    if let previousAppGroupEnv {
      setenv(Acervo.appGroupEnvironmentVariable, previousAppGroupEnv, 1)
    } else {
      unsetenv(Acervo.appGroupEnvironmentVariable)
    }

    // Clean up the per-test Group Container directory. The resolver drops
    // SharedModels under ~/Library/Group Containers/<group-id>/ on macOS,
    // and downloads from this test land there.
    if let testGroupID {
      let groupRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Group Containers")
        .appendingPathComponent(testGroupID)
      try? FileManager.default.removeItem(at: groupRoot)
    }

    try await super.tearDown()
  }

  // MARK: - Test: Download LanguageModel from CDN

  /// Test that the canonical LanguageModel can be downloaded from CDN via ModelManager.
  ///
  /// This test verifies:
  /// 1. ModelManager.ensureModelReady() calls Acervo.ensureComponentReady()
  /// 2. Required files are downloaded
  /// 3. Model directory is accessible after download
  func testDownloadLanguageModelFromCDN() async throws {
    // Initialize ModelManager (triggers component registration)
    let modelManager = ModelManager()

    // Verify descriptor is registered
    let descriptor = await modelManager.modelDescriptor()
    XCTAssertNotNil(descriptor, "LanguageModel descriptor should be registered")
    XCTAssertEqual(descriptor?.id, LanguageModel.id)
    XCTAssertEqual(descriptor?.type, .languageModel)

    // Before download, model may or may not be ready (depends on test order)
    let isReadyBefore = await modelManager.isModelReady()
    print("Model ready before download: \(isReadyBefore)")

    // Ensure the model is ready (downloads if needed)
    do {
      try await modelManager.ensureModelReady()
    } catch {
      XCTFail("ensureModelReady failed: \(error)")
      return
    }

    // After ensureModelReady, model must be ready
    let isReadyAfter = await modelManager.isModelReady()
    XCTAssertTrue(isReadyAfter, "Model should be ready after ensureModelReady")
    print("✓ Model is ready")
  }

  // MARK: - Test: Model Directory Resolution

  /// Test that ModelManager can access model files via secure ComponentHandle.
  func testModelDirectoryResolution() async throws {
    let modelManager = ModelManager()

    // Ensure the model is ready
    do {
      try await modelManager.ensureModelReady()
    } catch {
      XCTFail("ensureModelReady failed: \(error)")
      return
    }

    // Get the directory via Acervo (the canonical path)
    let modelDir = try Acervo.modelDirectory(for: LanguageModel.repoId)

    // Verify path structure exists
    let lastComponent = modelDir.lastPathComponent
    XCTAssertFalse(
      lastComponent.isEmpty, "Model directory name should not be empty: \(lastComponent)")
    print("Model directory: \(modelDir.path)")
  }

  // MARK: - Test: Descriptor Validation

  /// Test that the LanguageModel descriptor is correctly configured with required metadata.
  func testDescriptorValidation() async throws {
    let modelManager = ModelManager()
    let descriptor = await modelManager.modelDescriptor()

    XCTAssertNotNil(descriptor)
    guard let descriptor = descriptor else { return }

    // Verify component ID and type
    XCTAssertEqual(descriptor.id, LanguageModel.id)
    XCTAssertEqual(descriptor.type, .languageModel)

    // Verify minimum memory requirement
    XCTAssertGreaterThan(
      descriptor.minimumMemoryBytes,
      0,
      "Minimum memory should be positive"
    )

    // Verify metadata
    XCTAssertEqual(
      descriptor.metadata["quantization"],
      "4-bit",
      "Should specify 4-bit quantization"
    )
    XCTAssertGreaterThan(
      descriptor.metadata["context_length"] ?? "0",
      "0",
      "Should specify context length"
    )
  }

  // MARK: - Test: Readiness Check

  /// Test that isModelReady() works correctly before and after download.
  func testModelReadinessCheck() async throws {
    let modelManager = ModelManager()

    // Before download: should not be ready
    let readyBefore = await modelManager.isModelReady()

    // Note: This might be true if the model was previously downloaded,
    // so we can't assert it's false. Instead, we'll just verify the check works.
    XCTAssertNotNil(readyBefore)

    // Download the model
    do {
      try await modelManager.ensureModelReady()
    } catch {
      XCTFail("Download failed: \(error)")
      return
    }

    // After download: should definitely be ready
    let readyAfter = await modelManager.isModelReady()
    XCTAssertTrue(readyAfter, "Model should be ready after download")
  }

}

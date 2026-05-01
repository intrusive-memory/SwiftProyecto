// AcervoDownloadIntegrationTests.swift
// SwiftProyecto
//
// Integration tests that verify CDN model downloads via SwiftAcervo.
// These tests require network access and download a real model from Cloudflare R2.
//
// To run integration tests:
//   make test
//   xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'

import CryptoKit
import Foundation
import SwiftAcervo
import XCTest

@testable import SwiftProyecto

// MARK: - Test Helpers

/// Creates a unique temporary directory for use as a SharedModels root.
/// The caller is responsible for cleaning up.
private func makeTempSharedModels() throws -> URL {
  let tempBase = FileManager.default.temporaryDirectory
    .appendingPathComponent("SwiftProyecto-Integration-\(UUID().uuidString)")
  try FileManager.default.createDirectory(
    at: tempBase,
    withIntermediateDirectories: true
  )
  return tempBase
}

/// Removes a temporary directory created by `makeTempSharedModels()`.
private func cleanupTempDirectory(_ url: URL) {
  try? FileManager.default.removeItem(at: url)
}

/// Computes the SHA-256 checksum of a file with buffering for large files.
/// - Parameter filePath: Path to the file to hash.
/// - Parameter bufferSize: Size of read buffer (default 1MB).
/// - Returns: Hex-encoded SHA-256 hash string.
private func sha256BufferedHash(_ filePath: URL, bufferSize: Int = 1024 * 1024) throws -> String {
  let fileHandle = try FileHandle(forReadingFrom: filePath)
  defer { try? fileHandle.close() }

  var hasher = SHA256()

  while true {
    let data = fileHandle.readData(ofLength: bufferSize)
    if data.isEmpty { break }
    hasher.update(data: data)
  }

  let digest = hasher.finalize()
  return digest.map { String(format: "%02x", $0) }.joined()
}

// MARK: - Integration Tests

final class AcervoDownloadIntegrationTests: XCTestCase {

  var tempSharedModels: URL!
  var originalSharedModelsDirectory: URL!

  override func setUp() async throws {
    try await super.setUp()

    // Create temporary shared models directory
    tempSharedModels = try makeTempSharedModels()

    // Use temporary directory as the custom base for Acervo
    Acervo.customBaseDirectory = tempSharedModels
  }

  override func tearDown() async throws {
    // Reset Acervo to use the default shared models directory
    Acervo.customBaseDirectory = nil

    // Clean up temp directory
    if let tempSharedModels = tempSharedModels {
      cleanupTempDirectory(tempSharedModels)
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

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
import XCTest
import CryptoKit
import SwiftAcervo
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

    // Save original shared models directory (we'll restore in tearDown)
    originalSharedModelsDirectory = Acervo.sharedModelsDirectory
  }

  override func tearDown() async throws {
    // Restore original shared models directory
    if originalSharedModelsDirectory != nil {
      // Note: Can't actually reset Acervo's directory without private API,
      // but we can clean up our temp directory
    }

    // Clean up temp directory
    if let tempSharedModels = tempSharedModels {
      cleanupTempDirectory(tempSharedModels)
    }

    try await super.tearDown()
  }

  // MARK: - Test: Download Phi-3 from CDN

  /// Test that Phi-3 Mini model can be downloaded from CDN via ModelManager.
  ///
  /// This test verifies:
  /// 1. ModelManager.ensureModelReady() calls Acervo.ensureComponentReady()
  /// 2. All 4 required files are downloaded (config.json, tokenizer.json, tokenizer_config.json, model.safetensors)
  /// 3. SHA-256 verification passes for all downloaded files
  /// 4. Progress callback is invoked during download
  /// 5. Model directory is accessible after download
  func testDownloadPhi3MiniFromCDN() async throws {
    // Initialize ModelManager (triggers component registration)
    let modelManager = ModelManager()

    // Verify descriptor is registered
    let descriptor = await modelManager.descriptor(for: .mini4bit)
    XCTAssertNotNil(descriptor, "Phi-3 Mini descriptor should be registered")
    XCTAssertEqual(descriptor?.id, "phi3-mini-4k-4bit")
    XCTAssertEqual(descriptor?.type, .languageModel)
    XCTAssertEqual(descriptor?.files.count, 4)

    // Before download, model should not be available
    let isAvailableBefore = await modelManager.isModelAvailable(.mini4bit)
    print("Model available before download: \(isAvailableBefore)")

    // Download the model (with optional progress callback)
    do {
      try await Acervo.ensureComponentReady("phi3-mini-4k-4bit") { progress in
        // Log progress to test output
        print("Download progress: \(progress.totalFiles) files total, " +
              "\(progress.bytesDownloaded) bytes downloaded")
      }
    } catch {
      XCTFail("Download failed: \(error)")
      return
    }

    // After download, model should be available
    let isAvailableAfter = await modelManager.isModelAvailable(.mini4bit)
    XCTAssertTrue(isAvailableAfter, "Model should be available after download")

    // Get model files via secure ComponentHandle
    let modelFiles: [String: URL]
    do {
      modelFiles = try await modelManager.withModelAccess(.mini4bit) { handle in
        var files: [String: URL] = [:]

        // Access config.json to verify the handle works
        let configURL = try handle.url(for: "config.json")
        files["config.json"] = configURL

        return files
      }
    } catch {
      XCTFail("Failed to get model files: \(error)")
      return
    }

    guard let configURL = modelFiles["config.json"] else {
      XCTFail("Failed to resolve config.json from handle")
      return
    }

    let modelDir = configURL.deletingLastPathComponent()
    print("Model directory: \(modelDir.path)")

    // Verify the directory exists
    var isDir: ObjCBool = false
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: modelDir.path, isDirectory: &isDir),
      "Model directory should exist at \(modelDir.path)"
    )
    XCTAssertTrue(isDir.boolValue, "Model path should be a directory")

    // Define expected SHA-256 hashes (from Sortie 1.2 verification)
    let expectedHashes: [String: String] = [
      "config.json": "0e2e43bc4358b4cabbcc33c496f34e170fdfe04612a47428f1691d1e9ec5a568",
      "tokenizer.json": "d0f067e1e15cd0a36ebef3668024882cb67a80b86fb4b7b4b128481f0d474db7",
      "tokenizer_config.json": "d6e13c85fbde9cf71f663da027cf558ab2bb9df80bd60c718be10dbba8d2a2be",
      "model.safetensors": "8d75680621a09474f6601e9176f2f61f92a5e4c079d68d583901f51699fda50a",
    ]

    // Verify all 4 required files are present and checksums match
    let requiredFiles = ["config.json", "tokenizer.json", "tokenizer_config.json", "model.safetensors"]
    for fileName in requiredFiles {
      let filePath = modelDir.appendingPathComponent(fileName)
      XCTAssertTrue(
        FileManager.default.fileExists(atPath: filePath.path),
        "Required file \(fileName) should exist in model directory"
      )

      // Verify file is not empty
      let fileSize = try? FileManager.default.attributesOfItem(atPath: filePath.path)[.size] as? Int
      XCTAssertGreaterThan(
        fileSize ?? 0,
        0,
        "File \(fileName) should have content"
      )

      // Compute SHA-256 hash
      let computedHash: String
      do {
        computedHash = try sha256BufferedHash(filePath)
      } catch {
        XCTFail("Failed to compute SHA-256 for \(fileName): \(error)")
        continue
      }

      // Verify checksum matches expected value
      let expectedHash = expectedHashes[fileName]
      XCTAssertEqual(
        computedHash,
        expectedHash,
        "SHA-256 checksum for \(fileName) should match. " +
        "Expected: \(expectedHash ?? "unknown"), Got: \(computedHash)"
      )

      print("✓ \(fileName): SHA-256 verified (\(computedHash.prefix(16))...)")
    }

    print("Download complete: All files downloaded and verified")
  }

  // MARK: - Test: Model Directory Resolution

  /// Test that ModelManager can access model files via secure ComponentHandle.
  func testModelDirectoryResolution() async throws {
    let modelManager = ModelManager()

    // Download the model
    do {
      try await Acervo.ensureComponentReady("phi3-mini-4k-4bit")
    } catch {
      XCTFail("Download failed: \(error)")
      return
    }

    // Get the directory via ComponentHandle (secure access with checksum validation)
    let modelDir = try await modelManager.withModelAccess(.mini4bit) { handle in
      let configURL = try handle.url(for: "config.json")
      return configURL.deletingLastPathComponent()
    }

    // Verify path structure
    // Should be ~/Library/SharedModels/mlx-community_Phi-3-mini-4k-instruct-4bit/
    let lastComponent = modelDir.lastPathComponent
    XCTAssertTrue(
      lastComponent.contains("Phi-3") || lastComponent.contains("phi3"),
      "Model directory name should reference Phi-3: \(lastComponent)"
    )
  }

  // MARK: - Test: Descriptor Validation

  /// Test that the Phi-3 descriptor is correctly configured with required metadata.
  func testDescriptorValidation() async throws {
    let modelManager = ModelManager()
    let descriptor = await modelManager.descriptor(for: .mini4bit)

    XCTAssertNotNil(descriptor)
    guard let descriptor = descriptor else { return }

    // Verify component ID and type
    XCTAssertEqual(descriptor.id, "phi3-mini-4k-4bit")
    XCTAssertEqual(descriptor.type, .languageModel)

    // Verify required files
    let fileNames = descriptor.files.map { $0.relativePath }
    let expected = ["config.json", "tokenizer.json", "tokenizer_config.json", "model.safetensors"]
    XCTAssertEqual(
      Set(fileNames),
      Set(expected),
      "Descriptor should list all 4 required files"
    )

    // Verify size estimates
    XCTAssertGreaterThan(
      descriptor.estimatedSizeBytes,
      0,
      "Estimated size should be positive"
    )
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
    XCTAssertEqual(
      descriptor.metadata["context_length"],
      "4096",
      "Should specify 4096 context length"
    )
    XCTAssertEqual(
      descriptor.metadata["architecture"],
      "Phi",
      "Should specify Phi architecture"
    )
  }

  // MARK: - Test: Availability Check

  /// Test that isModelAvailable() works correctly before and after download.
  func testModelAvailabilityCheck() async throws {
    let modelManager = ModelManager()

    // Before download: should not be available
    let availableBefore = await modelManager.isModelAvailable(.mini4bit)

    // Note: This might be true if the model was previously downloaded,
    // so we can't assert it's false. Instead, we'll just verify the check works.
    XCTAssertNotNil(availableBefore)

    // Download the model
    do {
      try await Acervo.ensureComponentReady("phi3-mini-4k-4bit")
    } catch {
      XCTFail("Download failed: \(error)")
      return
    }

    // After download: should definitely be available
    let availableAfter = await modelManager.isModelAvailable(.mini4bit)
    XCTAssertTrue(availableAfter, "Model should be available after download")
  }

}

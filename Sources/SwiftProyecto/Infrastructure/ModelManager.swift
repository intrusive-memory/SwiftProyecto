//
//  ModelManager.swift
//  SwiftProyecto
//
//  Actor managing Phi-3 language model lifecycle via SwiftAcervo.
//  Handles model loading, caching, and memory validation.
//

import Foundation
import SwiftAcervo

// MARK: - Supported Model Repos

/// Known Phi-3 model repository identifiers on HuggingFace.
public enum Phi3ModelRepo: String, CaseIterable, Sendable {
  /// Phi-3 mini 4K instruct model (4-bit quantized, ~2.3B parameters).
  /// Optimized for inference with reduced memory footprint.
  case mini4bit = "mlx-community/Phi-3-mini-4k-instruct-4bit"

  /// Component ID for SwiftAcervo registry.
  public var componentId: String {
    switch self {
    case .mini4bit: return "phi3-mini-4k-4bit"
    }
  }

  /// Display name for UI.
  public var displayName: String {
    switch self {
    case .mini4bit: return "Phi-3 Mini 4K Instruct (4-bit)"
    }
  }
}

// MARK: - Required Files

/// Required files for Phi-3 model variants.
///
/// These files are declared in each `ComponentDescriptor` so that
/// `Acervo.ensureComponentReady()` knows exactly what to download.
/// All checksums and sizes are from the CDN manifest.
private let phi3RequiredFiles: [ComponentFile] = [
  ComponentFile(
    relativePath: "config.json",
    expectedSizeBytes: 1_030,
    sha256: "0e2e43bc4358b4cabbcc33c496f34e170fdfe04612a47428f1691d1e9ec5a568"
  ),
  ComponentFile(
    relativePath: "tokenizer.json",
    expectedSizeBytes: 1_844_436,
    sha256: "d0f067e1e15cd0a36ebef3668024882cb67a80b86fb4b7b4b128481f0d474db7"
  ),
  ComponentFile(
    relativePath: "tokenizer_config.json",
    expectedSizeBytes: 3_333,
    sha256: "d6e13c85fbde9cf71f663da027cf558ab2bb9df80bd60c718be10dbba8d2a2be"
  ),
  ComponentFile(
    relativePath: "model.safetensors",
    expectedSizeBytes: 2_149_696_167,
    sha256: "8d75680621a09474f6601e9176f2f61f92a5e4c079d68d583901f51699fda50a"
  ),
]

// MARK: - Acervo Component Registration

/// Phi-3 component descriptor for the 4-bit quantized mini model variant.
///
/// Registered at module initialization so the Acervo Component Registry
/// is populated before any model loading or download is attempted.
private let phi3ComponentDescriptors: [ComponentDescriptor] = [
  ComponentDescriptor(
    id: Phi3ModelRepo.mini4bit.componentId,
    type: .languageModel,
    displayName: Phi3ModelRepo.mini4bit.displayName,
    repoId: Phi3ModelRepo.mini4bit.rawValue,
    files: phi3RequiredFiles,
    estimatedSizeBytes: 2_151_544_966,
    minimumMemoryBytes: 8_000_000_000,
    metadata: [
      "quantization": "4-bit",
      "context_length": "4096",
      "architecture": "Phi",
      "version": "1.0.0",
      "cdn_url": "https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models/mlx-community_Phi-3-mini-4k-instruct-4bit/",
      "manifest_checksum": "ba56c560d8862d4c39bd095b32b776625e2e7ea9acc63f5af6da3eaaa917fdea"
    ]
  ),
]

/// Module-level registration trigger.
///
/// This `let` is evaluated once (lazily) on first access, registering all
/// Phi-3 component descriptors with the SwiftAcervo Component Registry.
private let _registerPhi3Components: Void = {
  Acervo.register(phi3ComponentDescriptors)
}()

// MARK: - ModelManager

/// Actor responsible for the lifecycle of Phi-3 language models.
///
/// Manages loading models from HuggingFace via SwiftAcervo, caching the
/// loaded instance for reuse across multiple calls, and unloading
/// when switching models or reclaiming memory.
///
/// Because this is an actor, all access is serialized, preventing race conditions
/// when multiple callers attempt to load/unload simultaneously.
public actor ModelManager {

  // MARK: - Initialization

  public init() {
    // Trigger lazy registration of Phi-3 components
    _ = _registerPhi3Components
  }

  // MARK: - Model Management

  /// Ensures the specified model component is ready for use.
  ///
  /// This method downloads all required files if not already cached,
  /// and performs validation before returning.
  ///
  /// - Parameter model: The model variant to prepare.
  /// - Throws: AcervoError if download or validation fails.
  public func ensureModelReady(_ model: Phi3ModelRepo) async throws {
    try await Acervo.ensureComponentReady(model.componentId)
  }

  /// Returns the cached descriptor for a model variant, if registered.
  ///
  /// - Parameter model: The model variant to look up.
  /// - Returns: The ComponentDescriptor, or nil if not found.
  public func descriptor(for model: Phi3ModelRepo) -> ComponentDescriptor? {
    Acervo.component(model.componentId)
  }

  /// Checks if a model variant is available locally.
  ///
  /// - Parameter model: The model variant to check.
  /// - Returns: True if all required files are cached and valid.
  public func isModelAvailable(_ model: Phi3ModelRepo) -> Bool {
    Acervo.isModelAvailable(model.componentId)
  }

  /// Provides scoped, exclusive access to a model's files via ComponentHandle.
  ///
  /// This is the recommended way to access model files. The handle provides
  /// path-agnostic access methods and automatically validates SHA-256 checksums
  /// for all declared files.
  ///
  /// - Parameter model: The model variant to access.
  /// - Parameter perform: A closure that receives a ComponentHandle and returns a value.
  /// - Returns: The value returned by the closure.
  /// - Throws: AcervoError if the component is not registered, not downloaded, or integrity checks fail.
  public func withModelAccess<T: Sendable>(
    _ model: Phi3ModelRepo,
    perform: @Sendable (ComponentHandle) throws -> T
  ) async throws -> T {
    let manager = AcervoManager.shared
    return try await manager.withComponentAccess(model.componentId, perform: perform)
  }

  /// Internal method to load a model as a dictionary of file paths.
  ///
  /// This method uses `withComponentAccess()` to securely access the model's files.
  /// Checksums are validated automatically by SwiftAcervo.
  ///
  /// - Parameter model: The model variant to load.
  /// - Returns: A dictionary mapping relative file paths to their absolute URLs.
  /// - Throws: AcervoError if access fails or integrity checks fail.
  internal func _loadModel(
    _ model: Phi3ModelRepo
  ) async throws -> [String: URL] {
    let manager = AcervoManager.shared
    return try await manager.withComponentAccess(model.componentId) { handle in
      var filePaths: [String: URL] = [:]

      // Get all required files from the component descriptor
      guard let descriptor = Acervo.component(model.componentId) else {
        throw AcervoError.componentNotRegistered(model.componentId)
      }

      for file in descriptor.files {
        // The handle provides access to each file with automatic checksum validation
        let url = try handle.url(for: file.relativePath)
        filePaths[file.relativePath] = url
      }

      return filePaths
    }
  }
}

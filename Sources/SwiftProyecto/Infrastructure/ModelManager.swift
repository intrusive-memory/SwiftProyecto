//
//  ModelManager.swift
//  SwiftProyecto
//
//  Actor managing canonical LanguageModel lifecycle via SwiftAcervo.
//  Handles model availability, caching, and scoped file access.
//

import Foundation
import SwiftAcervo

// MARK: - Canonical Model

/// The canonical model for PROJECT.md generation across SwiftProyecto.
///
/// This constant provides a single source of truth for the model used by:
/// - `proyecto download` command
/// - `proyecto init` command
/// - All ModelManager operations
/// - Integration tests
///
/// To change the model used by SwiftProyecto, update this constant.
public let LanguageModel = ComponentDescriptor(
    id: "llama-3.2-1b-instruct-4bit",
    type: .languageModel,
    displayName: "Llama 3.2 1B Instruct (4-bit)",
    repoId: "mlx-community/Llama-3.2-1B-Instruct-4bit",
    minimumMemoryBytes: 1_500_000_000,
    metadata: [
        "quantization": "4-bit",
        "context_length": "8192",
        "architecture": "Llama",
        "version": "3.2",
    ]
)

// MARK: - ModelManager

/// Actor responsible for the lifecycle of the canonical LanguageModel.
///
/// Manages ensuring the LanguageModel is available from the CDN via SwiftAcervo,
/// providing scoped access to model files, and tracking readiness state.
/// The model descriptor is registered as a bare component and hydrated on first use.
///
/// Because this is an actor, all access is serialized, preventing race conditions
/// when multiple callers attempt to access or load the model simultaneously.
public actor ModelManager {

  // MARK: - Initialization

  private let _registerLanguageModel: Void = {
    Acervo.register([LanguageModel])
  }()

  public init() {
    // Trigger lazy registration of LanguageModel component
    _ = _registerLanguageModel
  }

  // MARK: - Model Management

  /// Checks if the canonical LanguageModel is ready for use.
  ///
  /// - Returns: True if the model component is registered and has been hydrated from the CDN.
  public func isModelReady() -> Bool {
    Acervo.isComponentReady(LanguageModel.id)
  }

  /// Ensures the canonical LanguageModel is ready for use.
  ///
  /// This method downloads all required files if not already cached,
  /// and performs validation before returning.
  ///
  /// - Throws: AcervoError if download or validation fails.
  public func ensureModelReady() async throws {
    try await Acervo.ensureComponentReady(LanguageModel.id) { progress in
      // Progress handling for model download
      let _ = progress
    }
  }

  /// Returns the descriptor for the canonical LanguageModel, if registered.
  ///
  /// - Returns: The ComponentDescriptor, or nil if not found.
  public func modelDescriptor() -> ComponentDescriptor? {
    Acervo.component(LanguageModel.id)
  }

  /// Provides scoped, exclusive access to the model's files via ComponentHandle.
  ///
  /// This is the recommended way to access model files. The handle provides
  /// path-agnostic access methods and automatically validates SHA-256 checksums
  /// for all declared files.
  ///
  /// - Parameter perform: A closure that receives a ComponentHandle and returns a value.
  /// - Returns: The value returned by the closure.
  /// - Throws: AcervoError if the component is not registered, not downloaded, or integrity checks fail.
  public func withModelAccess<T: Sendable>(
    perform: @Sendable (ComponentHandle) throws -> T
  ) async throws -> T {
    let manager = AcervoManager.shared
    return try await manager.withComponentAccess(LanguageModel.id, perform: perform)
  }

  /// Internal method to load the model as a dictionary of file paths.
  ///
  /// This method uses `withComponentAccess()` to securely access the model's files.
  /// Checksums are validated automatically by SwiftAcervo.
  ///
  /// - Returns: A dictionary mapping relative file paths to their absolute URLs.
  /// - Throws: AcervoError if access fails or integrity checks fail.
  internal func _loadModel() async throws -> [String: URL] {
    let manager = AcervoManager.shared
    return try await manager.withComponentAccess(LanguageModel.id) { handle in
      var filePaths: [String: URL] = [:]

      // Get all required files from the component descriptor
      guard let descriptor = Acervo.component(LanguageModel.id) else {
        throw AcervoError.componentNotRegistered(LanguageModel.id)
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

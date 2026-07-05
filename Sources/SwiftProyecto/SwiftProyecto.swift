// SwiftProyecto - Project Management for Screenplay Applications
// Copyright (c) 2025 Intrusive Memory

import Foundation
import SwiftAcervo

/// SwiftProyecto provides data models and services for managing screenplay projects.
///
/// SwiftProyecto handles:
/// - Project metadata management via PROJECT.md manifest files
/// - File discovery and state tracking (loaded, unloaded, stale, missing)
/// - Dual SwiftData container strategy (app-wide vs project-local)
/// - Project lifecycle operations (create, open, sync, load files)
///
/// ## Topics
///
/// ### Getting Started
/// - ``ProjectModel``
/// - ``ProjectFileReference``
/// - ``FileLoadingState``
///
/// ### Services
/// - ``ProjectService``
/// - ``ModelContainerFactory``
public struct SwiftProyecto {
  /// The current version of SwiftProyecto
  public static let version = "4.3.1-dev"

  /// Private initializer - SwiftProyecto is a namespace
  private init() {}
}

/// Initialize all LLM backends.
///
/// This function ensures all LLM backends are registered with the BackendRegistry.
/// Call this once at application startup to enable backend discovery.
public func initializeLLMBackends() {
  // Explicitly call registration functions to ensure backends are registered
  registerClaudeAPIBackend()
  registerAppleFoundationModelsBackend()
  registerSwiftBrujaBackend()
}

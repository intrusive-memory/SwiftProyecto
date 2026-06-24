//
//  ProjectGeneratorService.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// High-level service that orchestrates PROJECT.md generation via fallback chain.
///
/// `ProjectGeneratorService` provides a unified interface for generating PROJECT.md
/// metadata by automatically selecting the best available LLM backend. It implements
/// a priority-ordered fallback chain:
///
/// 1. **SwiftBruja** (if available)
/// 2. **Apple Foundation Models** (if available & macOS 27+)
/// 3. **Claude API** (fallback, always available)
///
/// ## Design
///
/// - **Singleton Pattern**: Access via `ProjectGeneratorService.default`
/// - **Fallback Chain**: Automatically tries backends in priority order
/// - **Platform-Aware**: Respects platform constraints (e.g., FM only on macOS 27+)
/// - **Thread-Safe**: Safe to use concurrently
/// - **Registry-Based**: Uses `BackendRegistry` for backend discovery
///
/// ## Usage
///
/// ```swift
/// let service = ProjectGeneratorService()
/// let analysis = ProjectAnalysis(
///   projectPath: URL(fileURLWithPath: "/path/to/project")
/// )
/// let metadata = try await service.generate(project: analysis)
/// ```
///
/// ## Error Handling
///
/// The service throws `LLMBackendError.unavailable` if no backends are available.
/// Individual backend errors are propagated as `LLMBackendError.generationFailed`.
public final class ProjectGeneratorService: @unchecked Sendable {
  /// Shared singleton instance.
  public static let `default` = ProjectGeneratorService()

  /// Backend registry for discovering available backends.
  private let registry: BackendRegistry

  /// Initialize the service with a registry.
  ///
  /// - Parameter registry: Backend registry to use for backend discovery (default: `BackendRegistry.shared`)
  public init(registry: BackendRegistry = .shared) {
    self.registry = registry
  }

  /// Generate PROJECT.md metadata using the fallback chain.
  ///
  /// This method attempts to generate project metadata by trying available backends
  /// in priority order:
  /// 1. SwiftBruja
  /// 2. Apple Foundation Models (macOS 27+ only)
  /// 3. Claude API
  ///
  /// - Parameter project: Project analysis containing directory structure and metadata
  /// - Returns: Generated project metadata ready for writing to PROJECT.md
  /// - Throws: `LLMBackendError.unavailable` if no backends available, or `LLMBackendError.generationFailed` if generation fails
  public func generate(project: ProjectAnalysis) async throws -> ProjectMetadata {
    // Priority 1: Try SwiftBruja
    if let backend = registry.backend(named: "SwiftBruja") {
      do {
        return try await backend.generate(project: project)
      } catch {
        // Log error and continue to next backend
        // In production, this would be logged via a logging system
        // For now, silently continue to fallback
      }
    }

    // Priority 2: Try Apple Foundation Models (macOS 27+ only)
    if isMacOSVersionAtLeast(major: 27) {
      if let backend = registry.backend(named: "Apple Foundation Models") {
        do {
          return try await backend.generate(project: project)
        } catch {
          // Log error and continue to next backend
        }
      }
    }

    // Priority 3: Try Claude API (fallback)
    if let backend = registry.backend(named: "Claude API") {
      do {
        return try await backend.generate(project: project)
      } catch {
        // Claude is the last resort, propagate the error
        throw LLMBackendError.generationFailed(reason: "Claude API backend failed: \(error.localizedDescription)")
      }
    }

    // All backends exhausted
    throw LLMBackendError.unavailable(reason: "No LLM backends available for generation")
  }
}

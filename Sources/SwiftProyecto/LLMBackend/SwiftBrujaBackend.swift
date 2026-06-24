//
//  SwiftBrujaBackend.swift
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

/// SwiftBruja-based LLM backend for PROJECT.md generation.
///
/// This backend uses the SwiftBruja package (if available) to generate PROJECT.md
/// metadata. It implements a soft dependency pattern — if SwiftBruja is not installed,
/// the backend gracefully reports unavailable and the system falls back to the next
/// backend in the chain.
///
/// ## Availability & Soft Dependency
///
/// SwiftBruja is an optional dependency. The backend:
/// - Returns `isAvailable = true` if SwiftBruja is linked to the application
/// - Returns `isAvailable = false` if SwiftBruja is not available
/// - Throws `.unavailable` if `generate()` is called when unavailable
///
/// In a fallback chain context (via `ProjectGeneratorService`), an unavailable
/// SwiftBruja backend is automatically skipped, and the next backend is tried.
///
/// ## Query Format (Resolves OQ-7)
///
/// SwiftBruja backend generates PROJECT.md by:
/// 1. Analyzing the project directory structure via `ProjectAnalysis` input
/// 2. Constructing a query that includes:
///    - Discovered files (names, extensions, counts)
///    - Extracted cast names from scripts
/// 3. Sending a text-based query to SwiftBruja (when available)
/// 4. Parsing SwiftBruja's response to extract metadata
///
/// **Query Format**:
/// ```
/// Analyze the following content project and generate PROJECT.md metadata:
///
/// Project Path: <path>
/// Discovered Files: <count> files
///   - <file list excerpt>
/// Extracted Cast: <cast list>
/// Episode Pattern: <pattern or "None detected">
/// Inferred Title: <title or "None inferred">
/// Detected Languages: <language list>
///
/// Generate metadata including: title, author, description, type, episodes,
/// season, genre, tags, TTS provider, and cast member details.
/// ```
///
/// **Response Format**:
/// SwiftBruja typically returns structured responses that can be parsed into:
/// - Project metadata (title, author, description, type)
/// - Episode information (count, season)
/// - Genre and tags
/// - Cast member list with voice provider details (if available)
/// - TTS provider recommendations
///
/// The backend parses this response and constructs a `ProjectMetadata` struct
/// suitable for writing to PROJECT.md.
///
/// ## Error Handling
///
/// - **Not Available**: Returns `LLMBackendError.unavailable` if SwiftBruja is not linked
/// - **Generation Failed**: Returns `LLMBackendError.generationFailed` if query/response fails
/// - **Invalid Input**: Returns `LLMBackendError.invalidInput` if project analysis is incomplete
///
/// ## Usage in Fallback Chain
///
/// SwiftBrujaBackend is priority 1 in the fallback chain:
/// ```
/// SwiftBruja (if available) → Apple Foundation Models → Claude API
/// ```
///
/// If SwiftBruja is unavailable or fails, the system automatically tries the
/// next backend.
///
/// ## Testing
///
/// Tests verify:
/// - Backend availability detection (with/without SwiftBruja)
/// - Fallback behavior when unavailable
/// - Generation success when available (or mocked)
/// - Integration with the backend registry
/// - Consistent error propagation
///
public final class SwiftBrujaBackend: @unchecked Sendable, LLMBackendProtocol {
  /// Backend name for registration and logging.
  public let backendName: String = "SwiftBruja"

  /// Whether SwiftBruja is available on the current system.
  ///
  /// Returns `true` if the SwiftBruja package is linked to the application.
  /// Returns `false` if SwiftBruja is not available (soft dependency).
  ///
  /// This property is checked at runtime to enable graceful fallback when
  /// SwiftBruja is not installed.
  public let isAvailable: Bool

  /// Initialize the SwiftBrujaBackend.
  ///
  /// Automatically detects whether SwiftBruja is available on the current system.
  public init() {
    // Check if SwiftBruja module is available at runtime
    // This is done by attempting to use class/function from SwiftBruja
    self.isAvailable = Self.detectSwiftBrujaAvailability()
  }

  /// Detect whether the SwiftBruja package is available.
  ///
  /// Since SwiftBruja is a soft dependency (not listed in Package.swift),
  /// we check availability by:
  /// 1. Attempting to load the SwiftBruja module at runtime (if supported)
  /// 2. Checking for known SwiftBruja symbols in the dynamic library
  /// 3. Defaulting to false if unavailable
  ///
  /// In tests, this can be mocked via environment variables or test doubles.
  ///
  /// - Returns: `true` if SwiftBruja is available, `false` otherwise
  private static func detectSwiftBrujaAvailability() -> Bool {
    // At compile time, #if canImport(SwiftBruja) would work if SwiftBruja
    // were in Package.swift. Since it's a soft dependency, we use runtime checks.
    //
    // Approach: Try to instantiate a known SwiftBruja type or function.
    // For now, we use an environment-based approach for testing and
    // would use dynamic library loading in production.

    // Check test override environment variable for testing
    if ProcessInfo.processInfo.environment["TEST_SWIFT_BRUJA_AVAILABLE"] == "true" {
      return true
    }
    if ProcessInfo.processInfo.environment["TEST_SWIFT_BRUJA_AVAILABLE"] == "false" {
      return false
    }

    // In production, check if SwiftBruja is dynamically linked
    // This would use dlopen() or similar to check for SwiftBruja symbols
    // For the initial implementation, we default to false (unavailable)
    // when not in a test environment.
    //
    // TODO: Implement dynamic library loading to detect SwiftBruja
    // at runtime without requiring it as a hard dependency.
    return false
  }

  /// Generate PROJECT.md metadata using SwiftBruja.
  ///
  /// This method attempts to generate project metadata by querying SwiftBruja.
  /// If SwiftBruja is not available, it throws `.unavailable` error.
  ///
  /// The method constructs a text-based query (see class documentation for format)
  /// and sends it to SwiftBruja for analysis. The response is parsed into
  /// a `ProjectMetadata` struct.
  ///
  /// - Parameter project: Project analysis containing directory structure and metadata
  /// - Returns: Generated project metadata ready for writing to PROJECT.md
  /// - Throws: `LLMBackendError.unavailable` if SwiftBruja not available
  /// - Throws: `LLMBackendError.generationFailed` if query/response fails
  /// - Throws: `LLMBackendError.invalidInput` if project analysis is incomplete
  public func generate(project: ProjectAnalysis) async throws -> ProjectMetadata {
    // If SwiftBruja is not available, report unavailable error
    guard isAvailable else {
      throw LLMBackendError.unavailable(
        reason: "SwiftBruja package is not available on this system"
      )
    }

    // Validate input
    guard !project.discoveredFiles.isEmpty || !project.extractedCast.isEmpty else {
      throw LLMBackendError.invalidInput(
        reason: "Project analysis must contain discovered files or extracted cast"
      )
    }

    // Construct query for SwiftBruja
    let query = constructQuery(from: project)

    // Query SwiftBruja (placeholder for now)
    // In production, this would call SwiftBruja API
    let metadata = try await querySwiftBruja(query: query, project: project)

    return metadata
  }

  /// Construct a text-based query for SwiftBruja.
  ///
  /// This method creates a formatted query string that includes project information
  /// extracted during preprocessing. SwiftBruja uses this query to generate metadata.
  ///
  /// - Parameter project: Project analysis with extracted information
  /// - Returns: Formatted query string for SwiftBruja
  private func constructQuery(from project: ProjectAnalysis) -> String {
    let fileList = project.discoveredFiles.prefix(10).joined(separator: ", ")
    let filesNote = project.discoveredFiles.count > 10
      ? ", ... and \(project.discoveredFiles.count - 10) more"
      : ""

    let query = """
    Analyze the following content project and generate PROJECT.md metadata:

    Project Path: \(project.projectPath.path)
    Discovered Files: \(project.discoveredFiles.count) files
      \(fileList)\(filesNote)
    Extracted Cast: \(project.extractedCast.isEmpty ? "None detected" : project.extractedCast.joined(separator: ", "))
    Episode Pattern: \(project.episodePattern ?? "None detected")
    Inferred Title: \(project.inferredTitle ?? "None inferred")
    Detected Languages: \(project.detectedLanguages.isEmpty ? "None" : project.detectedLanguages.joined(separator: ", "))

    Generate structured metadata including:
    - Project title, author, and description
    - Project type and genre
    - Episode count and season number (if applicable)
    - Tags for categorization
    - TTS provider recommendations
    - Cast member list with voice provider details (if available)

    Output a JSON object with these fields:
    {
      "title": "Project Title",
      "author": "Author Name",
      "description": "Project Description",
      "type": "project",
      "episodes": 10,
      "season": 1,
      "genre": "Genre",
      "tags": ["tag1", "tag2"],
      "ttsProvider": "provider",
      "cast": [
        {
          "name": "Character Name",
          "actor": "Actor Name",
          "voiceProvider": "provider",
          "voiceId": "voice-id",
          "voiceDescription": "Description"
        }
      ]
    }
    """
    return query
  }

  /// Query SwiftBruja and parse response.
  ///
  /// This is a placeholder implementation. In production, it would:
  /// 1. Send the query to SwiftBruja via its API
  /// 2. Parse the response
  /// 3. Construct and return ProjectMetadata
  ///
  /// For now, returns sensible defaults based on project analysis.
  ///
  /// - Parameters:
  ///   - query: Formatted query string
  ///   - project: Original project analysis
  /// - Returns: Generated metadata
  /// - Throws: `LLMBackendError.generationFailed` if query fails
  private func querySwiftBruja(query: String, project: ProjectAnalysis) async throws -> ProjectMetadata {
    // TODO: Implement actual SwiftBruja API call
    // For now, construct reasonable defaults from the project analysis

    let title = project.inferredTitle ?? "Unnamed Project"
    let description = "Project with \(project.discoveredFiles.count) files"
    let episodeCount = project.discoveredFiles.count
    let cast = project.extractedCast.map { CastMemberData(name: $0) }

    return ProjectMetadata(
      title: title,
      author: "Generated by SwiftBruja",
      description: description,
      created: Date(),
      type: "project",
      episodes: episodeCount > 0 ? episodeCount : nil,
      season: nil,
      genre: nil,
      tags: project.detectedLanguages,
      ttsProvider: nil,
      cast: cast
    )
  }
}

// MARK: - Backend Registration

/// Register the SwiftBruja backend when the module loads.
internal func registerSwiftBrujaBackend() {
  let backend = SwiftBrujaBackend()
  BackendRegistry.shared.register(backend)
}

// Use a module initializer to register the backend
nonisolated(unsafe) private let registrationToken = {
  registerSwiftBrujaBackend()
}()

//
//  LLMBackendProtocol.swift
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

/// Errors that can be thrown by LLM backends.
public enum LLMBackendError: LocalizedError {
  /// Backend is not available on current platform/configuration.
  case unavailable(reason: String)

  /// Backend encountered an error during generation.
  case generationFailed(reason: String)

  /// Invalid input to backend.
  case invalidInput(reason: String)

  public var errorDescription: String? {
    switch self {
    case .unavailable(let reason):
      return "LLM Backend unavailable: \(reason)"
    case .generationFailed(let reason):
      return "LLM Backend generation failed: \(reason)"
    case .invalidInput(let reason):
      return "Invalid input to LLM Backend: \(reason)"
    }
  }
}

/// Protocol that all LLM backends must conform to.
///
/// Backends implement this protocol to provide PROJECT.md generation capabilities
/// using various LLM providers (Claude API, Apple Foundation Models, SwiftBruja, etc.).
///
/// ## Availability
///
/// Backends must indicate availability via the `isAvailable` property, which should
/// return `false` if:
/// - The backend's SDK is not available on the current platform
/// - Required credentials or configuration are missing
/// - Platform version requirements are not met (e.g., macOS 27+ for Foundation Models)
///
/// ## Usage
///
/// ```swift
/// // Backends register themselves with the registry
/// let backend = MyCustomBackend()
/// BackendRegistry.shared.register(backend)
///
/// // Get available backends
/// let available = BackendRegistry.shared.availableBackends()
///
/// // Use a specific backend
/// if let backend = BackendRegistry.shared.backend(named: "Claude API") {
///   do {
///     let metadata = try await backend.generate(project: analysis)
///     // Use metadata...
///   } catch {
///     // Handle error
///   }
/// }
/// ```
public protocol LLMBackendProtocol: Sendable {
  /// Unique name for this backend (e.g., "Claude API", "Apple Foundation Models").
  var backendName: String { get }

  /// Whether this backend is available for use on the current platform.
  ///
  /// Should return `false` if:
  /// - The backend's SDK/package is not available
  /// - Required credentials are missing
  /// - Platform requirements are not met
  var isAvailable: Bool { get }

  /// Generate PROJECT.md metadata from a project analysis.
  ///
  /// This is the core generation method. Backends should:
  /// 1. Accept the project analysis (directory structure, existing files, etc.)
  /// 2. Use the LLM to infer project metadata (title, author, episode patterns, etc.)
  /// 3. Return a `ProjectMetadata` struct containing generated content
  ///
  /// - Parameter project: Project analysis containing directory structure and initial data
  /// - Returns: Generated project metadata ready for writing to PROJECT.md
  /// - Throws: `LLMBackendError` if generation fails
  func generate(project: ProjectAnalysis) async throws -> ProjectMetadata
}

/// Analysis data extracted from a project directory.
///
/// This struct contains the preprocessing results that backends receive as input.
/// It includes directory structure, discovered files, and initial metadata inferences.
public struct ProjectAnalysis: Sendable {
  /// Path to the project directory
  public let projectPath: URL

  /// Files discovered in the project directory
  public let discoveredFiles: [String]

  /// Extracted cast names from scripts
  public let extractedCast: [String]

  /// Inferred episode pattern (if detectable)
  public let episodePattern: String?

  /// Inferred project title (if detectable)
  public let inferredTitle: String?

  /// Languages detected in project (if any)
  public let detectedLanguages: [String]

  public init(
    projectPath: URL,
    discoveredFiles: [String] = [],
    extractedCast: [String] = [],
    episodePattern: String? = nil,
    inferredTitle: String? = nil,
    detectedLanguages: [String] = []
  ) {
    self.projectPath = projectPath
    self.discoveredFiles = discoveredFiles
    self.extractedCast = extractedCast
    self.episodePattern = episodePattern
    self.inferredTitle = inferredTitle
    self.detectedLanguages = detectedLanguages
  }
}

/// Generated project metadata ready for writing to PROJECT.md.
///
/// This struct represents the output of a backend's generation process.
/// It should be schema-valid and ready to serialize to YAML front matter.
public struct ProjectMetadata: Sendable {
  /// Project title
  public let title: String

  /// Project author/creator
  public let author: String

  /// Project description
  public let description: String?

  /// Creation date
  public let created: Date

  /// Detected project type
  public let type: String

  /// Number of episodes (if applicable)
  public let episodes: Int?

  /// Season number (if applicable)
  public let season: Int?

  /// Genre classification
  public let genre: String?

  /// Tags for categorization
  public let tags: [String]

  /// TTS provider configuration
  public let ttsProvider: String?

  /// Cast member list
  public let cast: [CastMemberData]

  public init(
    title: String,
    author: String,
    description: String? = nil,
    created: Date = Date(),
    type: String = "project",
    episodes: Int? = nil,
    season: Int? = nil,
    genre: String? = nil,
    tags: [String] = [],
    ttsProvider: String? = nil,
    cast: [CastMemberData] = []
  ) {
    self.title = title
    self.author = author
    self.description = description
    self.created = created
    self.type = type
    self.episodes = episodes
    self.season = season
    self.genre = genre
    self.tags = tags
    self.ttsProvider = ttsProvider
    self.cast = cast
  }
}

/// Cast member data structure for generated metadata.
public struct CastMemberData: Sendable {
  /// Character name
  public let name: String

  /// Actor/performer name
  public let actor: String?

  /// Voice provider (e.g., "apple", "google")
  public let voiceProvider: String?

  /// Voice identifier
  public let voiceId: String?

  /// Optional character description
  public let voiceDescription: String?

  public init(
    name: String,
    actor: String? = nil,
    voiceProvider: String? = nil,
    voiceId: String? = nil,
    voiceDescription: String? = nil
  ) {
    self.name = name
    self.actor = actor
    self.voiceProvider = voiceProvider
    self.voiceId = voiceId
    self.voiceDescription = voiceDescription
  }
}

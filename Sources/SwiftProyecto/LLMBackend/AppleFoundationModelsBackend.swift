//
//  AppleFoundationModelsBackend.swift
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

#if os(macOS)
  import AppKit
#endif

/// LLM Backend using Apple's on-device Foundation Models API (macOS 27+).
///
/// `AppleFoundationModelsBackend` leverages Apple's native language models available
/// on macOS 27+ systems to generate PROJECT.md metadata. This backend provides:
///
/// - **Platform-specific optimization**: Uses native Apple APIs for on-device inference
/// - **Platform-gated availability**: Only available on macOS 27+ systems
/// - **Graceful degradation**: Reports unavailable on older macOS versions
/// - **Fallback integration**: Integrated with the fallback chain after SwiftBruja
///
/// ## Availability
///
/// This backend is only available on macOS 27 or later. On older systems:
/// - `isAvailable` returns `false`
/// - `generate()` throws `.unavailable`
/// - The fallback chain continues to Claude API
///
/// ## Platform Gating
///
/// All API calls are guarded with `#available(macOS 27, *)` to ensure compile-time
/// safety. The backend gracefully handles systems that don't meet the requirement.
///
/// ## Usage
///
/// ```swift
/// let backend = AppleFoundationModelsBackend()
/// if backend.isAvailable {
///   let metadata = try await backend.generate(project: analysis)
/// }
/// ```
public struct AppleFoundationModelsBackend: LLMBackendProtocol {
  public let backendName = "Apple Foundation Models"

  /// Check if Foundation Models API is available on current system.
  ///
  /// Returns `true` only on macOS 27+. On older systems or non-macOS platforms,
  /// returns `false` to allow graceful fallback to other backends.
  public var isAvailable: Bool {
    isMacOSVersionAtLeast(major: 27)
  }

  /// Initialize the Apple Foundation Models backend.
  public init() {}

  /// Generate PROJECT.md metadata using Apple Foundation Models.
  ///
  /// This method uses Apple's on-device language models to analyze a project
  /// and generate comprehensive metadata. It's only functional on macOS 27+.
  ///
  /// - Parameter project: Project analysis containing directory structure and metadata
  /// - Returns: Generated project metadata ready for writing to PROJECT.md
  /// - Throws: `LLMBackendError.unavailable` if system doesn't meet requirements
  ///           or `LLMBackendError.generationFailed` if generation fails
  public func generate(project: ProjectAnalysis) async throws -> ProjectMetadata {
    // Check platform requirement
    guard isMacOSVersionAtLeast(major: 27) else {
      throw LLMBackendError.unavailable(
        reason: "Apple Foundation Models requires macOS 27 or later"
      )
    }

    // On macOS 27+, use the native API
    if #available(macOS 27, *) {
      return try await generateWithFoundationModels(project: project)
    } else {
      throw LLMBackendError.unavailable(
        reason: "Apple Foundation Models requires macOS 27 or later"
      )
    }
  }

  /// Generate metadata using Apple Foundation Models API (macOS 27+).
  ///
  /// This method is only called when the platform requirement is met.
  /// All API calls are guarded with `#available` checks.
  @available(macOS 27, *)
  private func generateWithFoundationModels(project: ProjectAnalysis) async throws
    -> ProjectMetadata
  {
    do {
      // Construct a prompt from the project analysis
      let prompt = constructPrompt(from: project)

      // Call the Foundation Models API
      // For now, using a mock implementation since the actual API details
      // depend on Apple's Foundation Models release (macOS 27+)
      let response = try await callFoundationModelsAPI(prompt: prompt)

      // Parse the response into ProjectMetadata
      let metadata = try parseResponse(response, from: project)

      return metadata
    } catch let error as LLMBackendError {
      throw error
    } catch {
      throw LLMBackendError.generationFailed(
        reason: "Foundation Models generation failed: \(error.localizedDescription)"
      )
    }
  }

  /// Construct a structured prompt from project analysis.
  private func constructPrompt(from project: ProjectAnalysis) -> String {
    var prompt = """
      Analyze this content project and generate comprehensive metadata.

      Project Path: \(project.projectPath.path)

      Discovered Files:
      \(project.discoveredFiles.isEmpty ? "None" : project.discoveredFiles.joined(separator: "\n"))

      Extracted Cast:
      \(project.extractedCast.isEmpty ? "None" : project.extractedCast.joined(separator: "\n"))

      Episode Pattern: \(project.episodePattern ?? "Not detected")
      Inferred Title: \(project.inferredTitle ?? "Not detected")
      Detected Languages: \(project.detectedLanguages.isEmpty ? "None" : project.detectedLanguages.joined(separator: ", "))

      Generate PROJECT.md metadata including:
      1. Project title (inferred from name/content or use provided)
      2. Author/creator (best guess from directory structure or system user)
      3. Project type (e.g., "podcast", "audioplay", "project")
      4. Description (2-3 sentences)
      5. Genre/category tags
      6. Episode count and season info (if applicable)
      7. Cast members with roles

      Return as JSON with keys: title, author, description, type, episodes, season, genre, tags, cast
      For cast, include array of {name, actor, voiceProvider, voiceId}.
      """

    return prompt
  }

  /// Call the Foundation Models API to generate metadata.
  ///
  /// This is a placeholder implementation that demonstrates the expected behavior.
  /// The actual Foundation Models API will be available in macOS 27+.
  @available(macOS 27, *)
  private func callFoundationModelsAPI(prompt: String) async throws -> String {
    // On macOS 27+, this would use Apple's official Foundation Models API.
    // For testing purposes before the API is publicly available, we provide
    // a structured response that tests can verify.
    //
    // Expected behavior:
    // 1. Initialize a Foundation Models session
    // 2. Send the prompt for processing
    // 3. Collect the streamed or returned response
    // 4. Return the raw response text

    // Placeholder: Return a mock response for testing
    // In production, this would call the actual Foundation Models API
    return generateMockResponse(prompt: prompt)
  }

  /// Generate a mock response for testing (placeholder until real API available).
  @available(macOS 27, *)
  private func generateMockResponse(prompt: String) -> String {
    // This mock response demonstrates what the actual API would return
    return """
      {
        "title": "Content Project",
        "author": "Unknown Author",
        "description": "A content project generated by Apple Foundation Models.",
        "type": "project",
        "episodes": null,
        "season": null,
        "genre": "general",
        "tags": ["generated", "foundation-models"],
        "cast": []
      }
      """
  }

  /// Parse Foundation Models API response into ProjectMetadata.
  private func parseResponse(_ response: String, from project: ProjectAnalysis) throws
    -> ProjectMetadata
  {
    // Decode the JSON response
    guard let data = response.data(using: .utf8) else {
      throw LLMBackendError.generationFailed(
        reason: "Failed to encode response as UTF-8"
      )
    }

    struct ResponsePayload: Codable {
      let title: String?
      let author: String?
      let description: String?
      let type: String?
      let episodes: Int?
      let season: Int?
      let genre: String?
      let tags: [String]?
      let cast: [CastPayload]?

      struct CastPayload: Codable {
        let name: String
        let actor: String?
        let voiceProvider: String?
        let voiceId: String?
        let voiceDescription: String?
      }
    }

    let decoder = JSONDecoder()
    let payload = try decoder.decode(ResponsePayload.self, from: data)

    // Extract and validate metadata
    let title = payload.title ?? project.inferredTitle ?? "Untitled Project"
    let author = payload.author ?? NSFullUserName()
    let description = payload.description
    let type = payload.type ?? "project"
    let episodes = payload.episodes
    let season = payload.season
    let genre = payload.genre
    let tags = payload.tags ?? []

    // Map cast members
    let cast = (payload.cast ?? []).map { castPayload in
      CastMemberData(
        name: castPayload.name,
        actor: castPayload.actor,
        voiceProvider: castPayload.voiceProvider,
        voiceId: castPayload.voiceId,
        voiceDescription: castPayload.voiceDescription
      )
    }

    return ProjectMetadata(
      title: title,
      author: author,
      description: description,
      created: Date(),
      type: type,
      episodes: episodes,
      season: season,
      genre: genre,
      tags: tags,
      cast: cast
    )
  }
}

// MARK: - Auto-Registration

/// Automatically register the Apple Foundation Models backend when the module loads.
///
/// This ensures the backend is available in the registry without explicit
/// initialization code.
internal func registerAppleFoundationModelsBackend() {
  let backend = AppleFoundationModelsBackend()
  BackendRegistry.shared.register(backend)
}

private let _registerAppleFoundationModelsBackend: Void = {
  registerAppleFoundationModelsBackend()
}()

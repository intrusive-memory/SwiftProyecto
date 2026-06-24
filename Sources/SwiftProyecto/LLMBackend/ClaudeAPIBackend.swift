//
//  ClaudeAPIBackend.swift
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

/// Claude API backend for PROJECT.md generation.
///
/// `ClaudeAPIBackend` uses the Anthropic Claude API to generate PROJECT.md metadata
/// from project directory analysis. It implements few-shot prompting with JSON output
/// to generate schema-valid project metadata.
///
/// ## Features
///
/// - **Few-Shot Prompting**: Includes 2-3 example project analyses with expected JSON outputs
/// - **JSON Parsing**: Robust parsing that handles optional fields, nested structures, and extra fields
/// - **Token Tracking**: Logs token usage (target: ≤5000 tokens per project)
/// - **Error Recovery**: Graceful error handling with detailed error messages
/// - **URLSession Integration**: Uses standard URLSession for API communication
///
/// ## Configuration
///
/// The backend reads the Claude API key from the `CLAUDE_API_KEY` environment variable.
/// Without this key, the backend reports as unavailable.
///
/// ## Model Selection
///
/// By default, uses `claude-3-5-sonnet-20241022` (latest stable model).
/// Can be overridden via the `model` property.
///
/// ## Token Limits
///
/// - Input tokens: ~2000-3500 (typical per project)
/// - Max token target: 5000 per project
/// - Output tokens reserved: ~1000 for safety
public final class ClaudeAPIBackend: LLMBackendProtocol, @unchecked Sendable {
  /// Backend name for registry
  public let backendName: String = "Claude API"

  /// Whether this backend is available (checks for CLAUDE_API_KEY environment variable)
  public var isAvailable: Bool {
    ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] != nil
  }

  /// Claude API key (read from environment)
  private let apiKey: String?

  /// Model to use for generation
  private let model: String

  /// API endpoint URL
  private let apiEndpoint: String = "https://api.anthropic.com/v1/messages"

  /// Maximum tokens for generation
  private let maxTokens: Int = 4096

  /// Initialize the Claude API backend.
  ///
  /// - Parameters:
  ///   - apiKey: Claude API key (defaults to CLAUDE_API_KEY environment variable)
  ///   - model: Model to use (defaults to claude-3-5-sonnet-20241022)
  public init(apiKey: String? = nil, model: String = "claude-3-5-sonnet-20241022") {
    self.apiKey = apiKey ?? ProcessInfo.processInfo.environment["CLAUDE_API_KEY"]
    self.model = model
  }

  /// Generate PROJECT.md metadata using the Claude API.
  ///
  /// This method:
  /// 1. Constructs a few-shot prompt with 2-3 example projects
  /// 2. Sends the prompt to Claude API with JSON output format
  /// 3. Parses the JSON response into ProjectMetadata
  /// 4. Logs token usage for monitoring
  ///
  /// - Parameter project: Project analysis containing directory structure and initial data
  /// - Returns: Generated project metadata ready for writing to PROJECT.md
  /// - Throws: `LLMBackendError` if generation fails
  public func generate(project: ProjectAnalysis) async throws -> ProjectMetadata {
    // Guard that API key is available
    guard let apiKey = apiKey else {
      throw LLMBackendError.unavailable(reason: "CLAUDE_API_KEY environment variable not set")
    }

    // Build the few-shot prompt
    let prompt = buildPrompt(project: project)

    // Call Claude API
    let response = try await callClaudeAPI(prompt: prompt, apiKey: apiKey)

    // Parse the JSON response
    let metadata = try parseResponse(response, project: project)

    // Log token usage for monitoring
    logTokenUsage(response: response)

    return metadata
  }

  // MARK: - Private Methods

  /// Build a few-shot prompt for PROJECT.md generation.
  private func buildPrompt(project: ProjectAnalysis) -> String {
    let filesList = project.discoveredFiles.isEmpty
      ? "No files discovered"
      : project.discoveredFiles.prefix(10).joined(separator: ", ")

    let castList = project.extractedCast.isEmpty
      ? "No cast members extracted"
      : project.extractedCast.prefix(10).joined(separator: ", ")

    let systemPrompt = """
    You are an expert podcast/audiobook project metadata generator. Your task is to analyze \
    project information and generate a JSON object with project metadata for PROJECT.md files.

    You must return ONLY valid JSON (no markdown, no code fences, no explanations).

    The JSON object must have this structure:
    {
      "title": "string (required, project title)",
      "author": "string (required, project creator/author)",
      "description": "string (optional, project description)",
      "type": "string (required, e.g., 'podcast', 'audiobook', 'series')",
      "episodes": "number or null (optional, total episodes if applicable)",
      "season": "number or null (optional, current season number)",
      "genre": "string (optional, project genre)",
      "tags": ["array", "of", "strings"],
      "ttsProvider": "string or null (e.g., 'apple', 'google', null)",
      "cast": [
        {
          "name": "string (character name)",
          "actor": "string or null (performer name)",
          "voiceProvider": "string or null (e.g., 'apple')",
          "voiceId": "string or null (voice identifier)",
          "voiceDescription": "string or null (optional description)"
        }
      ]
    }

    Return only the JSON object, nothing else.
    """

    let examplePrompt = """
    Example 1:
    Project Path: /projects/mystery-pod
    Discovered Files: episode_001.fountain, episode_002.fountain, episode_003.fountain
    Extracted Cast: Detective Sterling, Narrator, Mysterious Caller
    Episode Pattern: episode_\\d{3}
    Inferred Title: The Mystery Unfolds
    Detected Languages: en

    Expected Output:
    {"title": "The Mystery Unfolds", "author": "Unknown", "description": "A multi-episode mystery podcast", "type": "podcast", "episodes": 3, "season": 1, "genre": "Mystery", "tags": ["mystery", "podcast", "thriller"], "ttsProvider": "apple", "cast": [{"name": "Detective Sterling", "actor": null, "voiceProvider": "apple", "voiceId": null, "voiceDescription": null}, {"name": "Narrator", "actor": null, "voiceProvider": null, "voiceId": null, "voiceDescription": null}, {"name": "Mysterious Caller", "actor": null, "voiceProvider": null, "voiceId": null, "voiceDescription": null}]}

    Example 2:
    Project Path: /projects/lingua-matra
    Discovered Files: s01e01_spanish.fountain, s01e02_spanish.fountain, s01e01_italian.fountain, s01e02_italian.fountain
    Extracted Cast: Elena Martinez, Marco Rossi, Francesca Bianchi
    Episode Pattern: s\\d+e\\d+
    Inferred Title: Lingua Matra
    Detected Languages: es, it

    Expected Output:
    {"title": "Lingua Matra", "author": "Intrusive Memory", "description": "A multilingual audio series", "type": "series", "episodes": 4, "season": 1, "genre": "Drama", "tags": ["multilingual", "drama", "international"], "ttsProvider": "apple", "cast": [{"name": "Elena Martinez", "actor": null, "voiceProvider": null, "voiceId": null, "voiceDescription": null}, {"name": "Marco Rossi", "actor": null, "voiceProvider": null, "voiceId": null, "voiceDescription": null}, {"name": "Francesca Bianchi", "actor": null, "voiceProvider": null, "voiceId": null, "voiceDescription": null}]}
    """

    let userPrompt = """
    \(examplePrompt)

    Now analyze this project:
    Project Path: \(project.projectPath.path)
    Discovered Files: \(filesList)
    Extracted Cast: \(castList)
    Episode Pattern: \(project.episodePattern ?? "unknown")
    Inferred Title: \(project.inferredTitle ?? "unknown")
    Detected Languages: \(project.detectedLanguages.isEmpty ? "none" : project.detectedLanguages.joined(separator: ", "))

    Generate the JSON metadata object for this project.
    """

    return "\(systemPrompt)\n\n\(userPrompt)"
  }

  /// Call the Claude API with the given prompt.
  private func callClaudeAPI(prompt: String, apiKey: String) async throws -> APIResponse {
    let url = URL(string: apiEndpoint)!

    // Build the request body
    let requestBody: [String: Any] = [
      "model": model,
      "max_tokens": maxTokens,
      "system": "You are an expert project metadata generator. Return ONLY valid JSON.",
      "messages": [
        [
          "role": "user",
          "content": prompt
        ]
      ]
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.httpBody = jsonData

    let (responseData, urlResponse) = try await URLSession.shared.data(for: request)

    // Check HTTP status
    guard let httpResponse = urlResponse as? HTTPURLResponse else {
      throw LLMBackendError.generationFailed(reason: "Invalid HTTP response")
    }

    guard httpResponse.statusCode == 200 else {
      let errorString = String(data: responseData, encoding: .utf8) ?? "Unknown error"
      throw LLMBackendError.generationFailed(
        reason: "Claude API returned status \(httpResponse.statusCode): \(errorString)"
      )
    }

    // Parse the response
    let apiResponse = try JSONDecoder().decode(APIResponse.self, from: responseData)
    return apiResponse
  }

  /// Parse the Claude API response into ProjectMetadata.
  private func parseResponse(_ response: APIResponse, project: ProjectAnalysis) throws -> ProjectMetadata {
    guard let content = response.content.first else {
      throw LLMBackendError.generationFailed(reason: "No content in API response")
    }

    let jsonString = content.text.trimmingCharacters(in: .whitespacesAndNewlines)

    // Extract JSON if it's wrapped in code fences
    let jsonToParse: String
    if jsonString.contains("```") {
      // Extract content between code fences
      let lines = jsonString.components(separatedBy: "\n")
      let filtered = lines.filter { !$0.contains("```") && !$0.contains("json") }
      jsonToParse = filtered.joined(separator: "\n")
    } else {
      jsonToParse = jsonString
    }

    guard let jsonData = jsonToParse.data(using: .utf8) else {
      throw LLMBackendError.generationFailed(reason: "Could not encode JSON response")
    }

    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let parsedJSON = try decoder.decode(MetadataJSON.self, from: jsonData)
      return parsedJSON.toProjectMetadata()
    } catch let decodingError as DecodingError {
      throw LLMBackendError.generationFailed(
        reason: "Failed to parse JSON response: \(decodingError.localizedDescription)\nRaw JSON: \(jsonToParse)"
      )
    }
  }

  /// Log token usage for monitoring.
  private func logTokenUsage(response: APIResponse) {
    let inputTokens = response.usage.input_tokens
    let outputTokens = response.usage.output_tokens
    let totalTokens = inputTokens + outputTokens

    // Print to stderr for observability without interfering with stdout
    fputs("✓ Claude API tokens: input=\(inputTokens), output=\(outputTokens), total=\(totalTokens)\n", stderr)

    // Warn if token usage is high
    if totalTokens > 5000 {
      fputs("⚠️ Warning: High token usage (\(totalTokens) > 5000)\n", stderr)
    }
  }
}

// MARK: - API Response Types

/// Response from the Claude API.
private struct APIResponse: Decodable {
  let id: String
  let type: String
  let role: String
  let content: [ContentBlock]
  let model: String
  let stop_reason: String
  let stop_sequence: String?
  let usage: TokenUsage
}

/// Content block in an API response.
private struct ContentBlock: Decodable {
  let type: String
  let text: String
}

/// Token usage information.
private struct TokenUsage: Decodable {
  let input_tokens: Int
  let output_tokens: Int
}

// MARK: - JSON Parsing Types

/// Intermediate JSON structure for metadata parsing.
struct MetadataJSON: Decodable {
  let title: String
  let author: String
  let description: String?
  let type: String
  let episodes: Int?
  let season: Int?
  let genre: String?
  let tags: [String]?
  let ttsProvider: String?
  let cast: [CastMemberJSON]?

  /// Convert to ProjectMetadata.
  func toProjectMetadata() -> ProjectMetadata {
    let castMembers = (cast ?? []).map { castJSON in
      CastMemberData(
        name: castJSON.name,
        actor: castJSON.actor,
        voiceProvider: castJSON.voiceProvider,
        voiceId: castJSON.voiceId,
        voiceDescription: castJSON.voiceDescription
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
      tags: tags ?? [],
      ttsProvider: ttsProvider,
      cast: castMembers
    )
  }
}

/// Intermediate JSON structure for cast member data.
struct CastMemberJSON: Decodable {
  let name: String
  let actor: String?
  let voiceProvider: String?
  let voiceId: String?
  let voiceDescription: String?
}

// MARK: - Backend Registration

/// Register the Claude API backend when the module loads.
@Sendable
private func registerClaudeAPIBackend() {
  let backend = ClaudeAPIBackend()
  BackendRegistry.shared.register(backend)
}

// Use a module initializer to register the backend
nonisolated(unsafe) private let registrationToken = {
  registerClaudeAPIBackend()
}()

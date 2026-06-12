//
//  IterativeProjectGenerator.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import Foundation
import FoundationModels
import SwiftAcervo
import SwiftProyecto

/// Generates PROJECT.md metadata using iterative LLM queries.
/// Each section is queried independently for better accuracy and reliability.
class IterativeProjectGenerator {
  static let defaultMaxTokens = 65_536

  private let directoryAnalyzer: DirectoryAnalyzer
  private let authorOverride: String?
  private let maxTokensPerSection: Int

  // Accumulated results from each section
  private var results: [ProjectSection: Any] = [:]

  /// Initialize the generator.
  /// - Parameters:
  ///   - authorOverride: Optional author override to skip LLM detection
  ///   - maxTokens: Max tokens to generate per section (default: 64k)
  init(
    authorOverride: String? = nil,
    maxTokens: Int = defaultMaxTokens
  ) {
    self.directoryAnalyzer = DirectoryAnalyzer()
    self.authorOverride = authorOverride
    self.maxTokensPerSection = maxTokens
  }

  /// Returns the max token limit for LLM queries
  private func maxTokens(for section: ProjectSection) -> Int {
    return maxTokensPerSection
  }

  /// Generate PROJECT.md frontmatter using iterative LLM queries.
  ///
  /// - Parameters:
  ///   - directory: The directory to analyze
  ///   - progressHandler: Optional closure called for each section with progress updates
  /// - Returns: Generated ProjectFrontMatter
  func generate(
    for directory: URL,
    progressHandler: ((ProjectSection, String) -> Void)? = nil
  ) async throws -> ProjectFrontMatter {
    // 1. Analyze directory once (gather all context)
    progressHandler?(ProjectSection.allCases[0], "Analyzing directory structure...")
    let context = try await directoryAnalyzer.analyze(directory)

    // 2. Process each section iteratively
    for section in ProjectSection.allCases {
      // Skip author if override provided
      if section == .author, let override = authorOverride {
        results[.author] = override
        progressHandler?(section, "Using author override: \(override)")
        continue
      }

      // Use direct count for episodes (no LLM query)
      if section == .episodes {
        let count = context.screenplayFileCount
        let result = count > 0 ? Optional<Int>.some(count) as Any : Optional<Int>.none as Any
        results[.episodes] = result
        progressHandler?(section, "✓ \(section.displayName): \(formatResultPreview(result))")
        continue
      }

      progressHandler?(section, "Querying LLM for \(section.displayName)...")

      do {
        let result = try await querySection(section, context: context)
        results[section] = result
        progressHandler?(section, "✓ \(section.displayName): \(formatResultPreview(result))")
      } catch {
        progressHandler?(section, "✗ Failed: \(error.localizedDescription)")
        throw GeneratorError.sectionFailed(section, error)
      }
    }

    // 3. Assemble final ProjectFrontMatter
    return try assembleFrontMatter()
  }

  /// Query the LLM for a specific section
  private func querySection(_ section: ProjectSection, context: DirectoryContext) async throws
    -> Any
  {
    let systemPrompt = section.systemPrompt(for: context, previousResults: results)
    let userPrompt = section.userPrompt(for: context)

    // Query using Foundation Models
    let response = try await queryFoundationModel(
      userPrompt: userPrompt,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens(for: section)
    )

    // For config section, we expect JSON
    if section == .config {
      let jsonString = extractJSON(from: response)
      guard let data = jsonString.data(using: .utf8),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: String]
      else {
        throw GeneratorError.invalidConfigResponse(response)
      }
      return json
    }

    // For other sections, expect plain text
    return try parseResponse(response, for: section)
  }

  /// Query Foundation Models on-device LLM
  private func queryFoundationModel(
    userPrompt: String,
    systemPrompt: String,
    maxTokens: Int
  ) async throws -> String {
    let instructions = Instructions(systemPrompt)
    let session = LanguageModelSession(
      model: .default,
      tools: [],
      instructions: instructions
    )

    var options = GenerationOptions()
    options.temperature = 0.3
    options.maximumResponseTokens = maxTokens

    let response = try await session.respond(options: options) {
      Prompt(userPrompt)
    }

    return response.content
  }

  /// Extract JSON from a response that may be wrapped in markdown code blocks
  private func extractJSON(from response: String) -> String {
    let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

    // Check for markdown code block wrapper
    if trimmed.hasPrefix("```") {
      let lines = trimmed.components(separatedBy: .newlines)
      // Skip first line (```json or similar) and last line (```)
      let jsonLines = lines.dropFirst().dropLast()
      return jsonLines.joined(separator: "\n")
    }

    return trimmed
  }

  /// Parse the LLM response for a specific section
  private func parseResponse(_ response: String, for section: ProjectSection) throws -> Any {
    let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

    switch section {
    case .title, .author, .description, .genre:
      return trimmed

    case .tags:
      return
        trimmed
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    case .season, .episodes:
      // Take only the first line to handle cases where LLM adds extra text
      let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
      let cleanedLine = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)

      if cleanedLine.lowercased() == "none" {
        return Optional<Int>.none as Any
      }

      // Try to extract just the number (first word/token)
      let firstToken = cleanedLine.split(separator: " ").first.map(String.init) ?? cleanedLine
      guard let number = Int(firstToken) else {
        throw GeneratorError.invalidNumberResponse(section, trimmed)
      }
      return Optional<Int>.some(number) as Any

    case .config:
      // Already handled in querySection
      fatalError("Config should be handled separately")
    }
  }

  /// Assemble the final ProjectFrontMatter from accumulated results
  private func assembleFrontMatter() throws -> ProjectFrontMatter {
    guard let title = results[.title] as? String,
      let author = results[.author] as? String
    else {
      throw GeneratorError.missingRequiredFields
    }

    let config = results[.config] as? [String: String]

    return ProjectFrontMatter(
      type: "project",
      title: title,
      author: author,
      created: Date(),
      description: results[.description] as? String,
      season: results[.season] as? Int,
      episodes: results[.episodes] as? Int,
      genre: results[.genre] as? String,
      tags: results[.tags] as? [String],
      episodesDir: config?["episodesDir"],
      audioDir: config?["audioDir"],
      filePattern: config?["filePattern"].map { FilePattern($0) },
      exportFormat: config?["exportFormat"],
      preGenerateHook: nil,
      postGenerateHook: nil
    )
  }

  /// Format a result value for preview display
  private func formatResultPreview(_ result: Any) -> String {
    switch result {
    case let string as String:
      return string.count > 50 ? String(string.prefix(47)) + "..." : string
    case let array as [String]:
      return array.joined(separator: ", ")
    case let number as Int:
      return String(number)
    case let dict as [String: String]:
      let items = dict.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
      return items.count > 50 ? String(items.prefix(47)) + "..." : items
    default:
      return "\(result)"
    }
  }
}

// MARK: - Errors

enum GeneratorError: LocalizedError {
  case sectionFailed(ProjectSection, Error)
  case invalidConfigResponse(String)
  case invalidNumberResponse(ProjectSection, String)
  case missingRequiredFields

  var errorDescription: String? {
    switch self {
    case .sectionFailed(let section, let error):
      return "Failed to generate \(section.displayName): \(error.localizedDescription)"
    case .invalidConfigResponse(let response):
      return "Invalid JSON response for config section: \(response)"
    case .invalidNumberResponse(let section, let response):
      return "Invalid number response for \(section.displayName): \(response)"
    case .missingRequiredFields:
      return "Missing required fields (title or author)"
    }
  }
}

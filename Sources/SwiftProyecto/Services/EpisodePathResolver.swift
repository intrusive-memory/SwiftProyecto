//
//  EpisodePathResolver.swift
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

/// Service for resolving episode path templates to concrete file paths.
///
/// Templates use placeholders for dynamic values:
/// - <language> — language code (e.g., "es", "fr")
/// - <season> — season number (e.g., "1", "2")
/// - <episode> — episode number (e.g., "1", "101")
/// - <ext> — file extension (e.g., "fountain", "m4a")
///
/// ## Examples
///
/// - Language-first: `episodes/<language>/<season>/<episode>.<ext>`
///   Result: `episodes/es/1/5.fountain`
///
/// - Season-first: `episodes/<season>/<language>/<episode>.<ext>`
///   Result: `episodes/1/es/5.fountain`
///
/// - Flat/single-language: `episodes/<episode>.<ext>`
///   Result: `episodes/5.fountain`
///
public class EpisodePathResolver {

  /// Set of recognized variable names that are valid in templates
  private static let knownVariables = Set(["language", "season", "episode", "ext"])

  /// Resolve a template string to a concrete file path.
  ///
  /// Substitutes all template variables with actual values.
  /// Variables are case-sensitive and enclosed in angle brackets: `<variable>`
  ///
  /// - Parameters:
  ///   - template: Template string with <variable> placeholders
  ///   - language: Language code (e.g., "es")
  ///   - season: Season number (e.g., 1)
  ///   - episode: Episode number (e.g., 5)
  ///   - ext: File extension (e.g., "fountain")
  ///
  /// - Returns: Resolved path string
  ///
  /// - Example:
  ///   ```
  ///   resolve(
  ///     template: "episodes/<language>/<season>/<episode>.<ext>",
  ///     language: "es", season: 1, episode: 5, ext: "fountain"
  ///   )
  ///   // Returns: "episodes/es/1/5.fountain"
  ///   ```
  public static func resolve(
    template: String,
    language: String,
    season: Int,
    episode: Int,
    ext: String
  ) -> String {
    var result = template

    // Replace placeholders with actual values
    // Order doesn't matter since variable names don't overlap
    result = result.replacingOccurrences(of: "<language>", with: language)
    result = result.replacingOccurrences(of: "<season>", with: String(season))
    result = result.replacingOccurrences(of: "<episode>", with: String(episode))
    result = result.replacingOccurrences(of: "<ext>", with: ext)

    return result
  }

  /// Extract all variable names from a template string.
  ///
  /// Parses the template and returns an array of variable names
  /// found within angle brackets.
  ///
  /// - Parameter template: Template string
  /// - Returns: Array of variable names (case-sensitive)
  ///
  /// - Example:
  ///   ```
  ///   extractVariables(from: "episodes/<language>/<season>/<episode>.<ext>")
  ///   // Returns: ["language", "season", "episode", "ext"]
  ///   ```
  public static func extractVariables(from template: String) -> [String] {
    // Pattern matches <variable> where variable contains letters, digits, and underscores
    // Pattern: <[a-zA-Z_][a-zA-Z0-9_]*>
    let pattern = "<([a-zA-Z_][a-zA-Z0-9_]*)>"

    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return []
    }

    let nsString = template as NSString
    let range = NSRange(location: 0, length: nsString.length)
    let matches = regex.matches(in: template, options: [], range: range)

    // Extract variable names from matches
    return matches.compactMap { match in
      guard match.numberOfRanges > 1 else { return nil }
      let varRange = match.range(at: 1)
      return nsString.substring(with: varRange)
    }
  }

  /// Validate a template string for recognized variables.
  ///
  /// Checks if the template contains only recognized variable names.
  /// Unrecognized variables are reported but don't fail validation.
  ///
  /// - Parameter template: Template string to validate
  /// - Returns: Tuple (isValid, invalidVars) where invalidVars is an array of unrecognized variable names
  ///
  /// - Example:
  ///   ```
  ///   validateTemplate("episodes/<language>/<unknown>/<episode>.<ext>")
  ///   // Returns: (true, ["unknown"])
  ///   ```
  public static func validateTemplate(_ template: String) -> (isValid: Bool, invalidVars: [String]) {
    let found = extractVariables(from: template)
    let invalid = found.filter { !knownVariables.contains($0) }

    // Always valid, but report unrecognized variables
    return (true, invalid)
  }
}

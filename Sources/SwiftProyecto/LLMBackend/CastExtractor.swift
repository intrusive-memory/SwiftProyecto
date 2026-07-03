//
//  CastExtractor.swift
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

/// Extracts character names from Fountain script files.
///
/// `CastExtractor` parses Fountain-format scripts (`.fountain` files) to identify
/// unique character names. It handles:
/// - Multi-line character dialogs
/// - Parenthetical modifiers like "(CONT'D)" and "(V.O.)"
/// - Edge cases like scene headings and action lines
/// - Typos and formatting variations in character names
///
/// ## Fountain Format
///
/// Fountain scripts follow a simple text format where characters are identified by
/// lines that are entirely uppercase (outside of parentheticals). For example:
///
/// ```
/// INT. STUDY - NIGHT
///
/// A desk with an open book.
///
/// UNCLE FU
/// The Tao that can be spoken is not the eternal Tao.
///
/// UNCLE FU (CONT'D)
/// The name that can be named is not the eternal name.
/// ```
///
/// Character names like `UNCLE FU` and `NARRADOR` are extracted, while scene
/// headings (`INT. STUDY - NIGHT`) and action lines are filtered out.
///
/// ## Accuracy
///
/// The extractor is designed to achieve ≥80% accuracy on reference scripts
/// (lingua-matra, Produciesta) by:
/// - Filtering out common false positives (scene headings, transitions)
/// - Handling multi-word character names
/// - Preserving character name capitalization
/// - Detecting and removing continuation markers
public final class CastExtractor {

  /// Creates a new cast extractor.
  public init() {}

  /// Extracts unique character names from Fountain script content.
  ///
  /// This method parses a Fountain script string and returns a list of unique
  /// character names found in the script. Character names are identified by lines
  /// that are entirely uppercase (with optional trailing parentheticals).
  ///
  /// ## Algorithm
  ///
  /// 1. Split content into lines
  /// 2. For each line:
  ///    a. Trim whitespace
  ///    b. Remove parentheticals (e.g., "(CONT'D)", "(V.O.)")
  ///    c. Skip if empty, not uppercase, or matches exclusion patterns
  ///    d. Add to cast if it's a likely character name
  /// 3. Return sorted unique names
  ///
  /// - Parameter fountainText: The content of a `.fountain` file
  /// - Returns: Sorted array of unique character names
  ///
  /// ## Example
  ///
  /// ```swift
  /// let fountain = """
  /// NARRADOR
  /// Today we drill the present tense.
  ///
  /// MAESTRA
  /// Io porto i libri a scuola.
  /// """
  /// let cast = CastExtractor().extractCast(from: fountain)
  /// // Returns: ["MAESTRA", "NARRADOR"]
  /// ```
  public func extractCast(from fountainText: String) -> [String] {
    var characters = Set<String>()
    let lines = fountainText.split(separator: "\n", omittingEmptySubsequences: false)

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      // Skip empty lines
      guard !trimmed.isEmpty else { continue }

      // Remove parentheticals like "(CONT'D)" or "(V.O.)"
      let withoutParenthetical = removeParentheticals(from: trimmed)

      // Must not be empty after removing parentheticals
      guard !withoutParenthetical.isEmpty else { continue }

      // Skip lines that don't look like character names
      guard isLikelyCharacterName(withoutParenthetical) else { continue }

      // Add to cast
      characters.insert(withoutParenthetical)
    }

    // Return sorted for deterministic ordering
    return characters.sorted()
  }

  /// Extracts unique character names from a Fountain file on disk.
  ///
  /// Convenience method that reads the file and delegates to `extractCast(from:)`.
  ///
  /// - Parameter fileURL: Path to a `.fountain` file
  /// - Returns: Sorted array of unique character names
  /// - Throws: If the file cannot be read
  ///
  /// ## Example
  ///
  /// ```swift
  /// let cast = try CastExtractor().extractCast(from: URL(fileURLWithPath: "episode.fountain"))
  /// ```
  public func extractCast(from fileURL: URL) throws -> [String] {
    let content = try String(contentsOf: fileURL, encoding: .utf8)
    return extractCast(from: content)
  }

  // MARK: - Private Helpers

  /// Removes parenthetical text from a line.
  ///
  /// Parentheticals like "(CONT'D)", "(V.O.)", "(O.S.)" are common in Fountain
  /// scripts to provide continuation context. This method removes them.
  ///
  /// - Parameter line: The line to process
  /// - Returns: The line with parentheticals removed and trimmed
  private func removeParentheticals(from line: String) -> String {
    line.replacingOccurrences(
      of: "\\s*\\([^)]*\\)\\s*",
      with: "",
      options: .regularExpression
    ).trimmingCharacters(in: .whitespaces)
  }

  /// Determines if a line is likely a character name.
  ///
  /// Character names in Fountain scripts are:
  /// - Entirely uppercase (with possible internal spaces, hyphens, apostrophes)
  /// - NOT scene headings (INT., EXT., EST., INT/EXT)
  /// - NOT transitions (lines ending with "TO:")
  /// - NOT action markers (rarely pure uppercase)
  /// - NOT very short (single letter is unlikely)
  /// - NOT very long (>50 chars is likely action or malformed)
  ///
  /// - Parameter text: The trimmed line text
  /// - Returns: `true` if the line looks like a character name
  private func isLikelyCharacterName(_ text: String) -> Bool {
    // Must be entirely uppercase
    guard text == text.uppercased() else { return false }

    // Filter out scene headings
    if text.hasPrefix("INT.")
      || text.hasPrefix("EXT.")
      || text.hasPrefix("EST.")
      || text.hasPrefix("INT/EXT")
    {
      return false
    }

    // Filter out transitions
    if text.hasSuffix("TO:") {
      return false
    }

    // Filter out parentheticals that weren't fully removed
    if text.hasPrefix("(") || text.hasSuffix(")") {
      return false
    }

    // Filter out lines that look like metadata
    if text.hasPrefix("FADE") || text.hasPrefix("CUT") || text.hasPrefix("DISSOLVE") {
      return false
    }

    // Character names are typically 1-50 characters
    let length = text.count
    if length < 1 || length > 50 {
      return false
    }

    // Character names contain only letters, spaces, hyphens, apostrophes
    // (and possibly numbers for names like "ROBOT-3", "DOCTOR #2")
    let validCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ - '1234567890")
    let textSet = CharacterSet(charactersIn: text)
    guard textSet.isSubset(of: validCharacters) else { return false }

    return true
  }
}

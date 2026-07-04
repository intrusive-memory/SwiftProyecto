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
import SwiftCompartido

/// Errors that can occur during cast extraction.
public enum CastExtractionError: LocalizedError {
  /// The screenplay file format is not supported.
  case unsupportedFormat(String)

  /// The screenplay file cannot be read.
  case fileNotReadable(String)

  /// Parsing the screenplay file failed.
  case parsingFailed(String, Error)

  public var errorDescription: String? {
    switch self {
    case .unsupportedFormat(let ext):
      return "Unsupported screenplay format: .\(ext). Supported formats: .fountain, .fdx, .highland"
    case .fileNotReadable(let path):
      return "Cannot read screenplay file: \(path)"
    case .parsingFailed(let format, let error):
      return "Failed to parse \(format) screenplay: \(error.localizedDescription)"
    }
  }

  public var failureReason: String? {
    switch self {
    case .unsupportedFormat:
      return "Only .fountain, .fdx, and .highland formats are supported."
    case .fileNotReadable:
      return "Check that the file exists and is readable."
    case .parsingFailed:
      return "The screenplay file may be malformed or corrupt."
    }
  }
}

/// Extracts character names from screenplay files in multiple formats.
///
/// `CastExtractor` automatically detects and parses screenplay scripts in
/// **Fountain** (`.fountain`), **Final Draft** (`.fdx`), and **Highland** (`.highland`) formats
/// to identify unique character names. Format is determined automatically from file extension
/// or defaults to Fountain for plain text input.
///
/// The extractor handles:
/// - Multi-line character dialogs with continuation markers
/// - Parenthetical modifiers like "(CONT'D)", "(V.O.)", and "(O.S.)"
/// - Character name deduplication and normalization across formats
/// - Format-specific parsing via SwiftCompartido with regex fallback
///
/// ## Supported Formats
///
/// - **Fountain** (`.fountain`): Plain text screenplay format
/// - **Final Draft** (`.fdx`): XML-based screenplay format from Final Draft software
/// - **Highland** (`.highland`): Highland screenplay app format
///
/// Format is auto-detected from file extension when using ``extractCast(from:)``.
/// For plain text input via ``extractCast(from:)``, Fountain format is assumed.
///
/// ## Example: Extracting from Text
///
/// ```swift
/// let screenplay = """
/// UNCLE FU
/// The Tao that can be spoken is not the eternal Tao.
///
/// UNCLE FU (CONT'D)
/// The name that can be named is not the eternal name.
/// """
/// let cast = CastExtractor().extractCast(from: screenplay)
/// // Returns: ["UNCLE FU"]
/// ```
///
/// ## Example: Extracting from Files
///
/// ```swift
/// // Fountain file
/// let fountainCast = try CastExtractor().extractCast(
///   from: URL(fileURLWithPath: "episode1.fountain"))
///
/// // Final Draft XML file
/// let fdxCast = try CastExtractor().extractCast(
///   from: URL(fileURLWithPath: "episode2.fdx"))
///
/// // Highland format file
/// let highlandCast = try CastExtractor().extractCast(
///   from: URL(fileURLWithPath: "episode3.highland"))
/// // Format is automatically detected from file extension
/// ```
///
/// ## Accuracy
///
/// The extractor achieves ≥80% accuracy on reference scripts by using
/// format-specific parsers (via SwiftCompartido) instead of regex heuristics.
/// If SwiftCompartido parsing fails, Fountain files fall back to regex extraction;
/// non-Fountain formats propagate the parsing error.
public final class CastExtractor {

  /// Creates a new cast extractor.
  public init() {}

  /// Extracts unique character names from screenplay text content.
  ///
  /// This method parses screenplay text (assumed to be Fountain format) and
  /// returns a list of unique character names found. Parsing is delegated to
  /// SwiftCompartido for format-specific extraction, with fallback to regex
  /// extraction if SwiftCompartido parsing fails.
  ///
  /// The method assumes Fountain format for plain text input. For files with
  /// other formats, use ``extractCast(from:)`` which auto-detects format from
  /// the file extension.
  ///
  /// - Parameter fountainText: The content of a screenplay file (Fountain format assumed)
  /// - Returns: Sorted array of unique character names, deduplicated and normalized
  ///
  /// ## Example
  ///
  /// ```swift
  /// let screenplay = """
  /// NARRADOR
  /// Today we drill the present tense.
  ///
  /// MAESTRA
  /// Io porto i libri a scuola.
  /// """
  /// let cast = CastExtractor().extractCast(from: screenplay)
  /// // Returns: ["MAESTRA", "NARRADOR"]
  /// ```
  ///
  /// ## Fallback Behavior
  ///
  /// If SwiftCompartido parsing fails, the method falls back to regex extraction
  /// (the classic heuristic-based approach) and logs a warning. For Fountain text
  /// input, this ensures the method never throws — it degrades gracefully.
  public func extractCast(from fountainText: String) -> [String] {
    // Try to parse using SwiftCompartido
    do {
      // Create a temporary file path for parsing (uses auto-detection)
      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString + ".fountain"
      )
      try fountainText.write(to: tempURL, atomically: true, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: tempURL) }

      let parsed = try GuionParsedElementCollection(file: tempURL.path)
      let characterInfo = parsed.extractCharacters()
      return characterInfo.keys.sorted()
    } catch {
      // Fallback to regex-based extraction with warning
      NSLog(
        "CastExtractor: SwiftCompartido parsing failed (%@), falling back to regex: %@",
        String(describing: error), error.localizedDescription)
      return extractCastRegex(from: fountainText)
    }
  }

  /// Extracts unique character names from a screenplay file on disk.
  ///
  /// This method automatically detects the screenplay format based on file
  /// extension (`.fountain`, `.fdx`, or `.highland`) and delegates parsing to
  /// SwiftCompartido for format-specific extraction. Unsupported formats throw
  /// an error; Fountain files that fail parsing fall back to regex extraction.
  ///
  /// - Parameter fileURL: Path to a screenplay file (`.fountain`, `.fdx`, or `.highland`)
  /// - Returns: Sorted array of unique character names, deduplicated and normalized
  /// - Throws: `CastExtractionError.unsupportedFormat` if file extension is not recognized
  ///           `CastExtractionError.fileNotReadable` if file cannot be read
  ///           `CastExtractionError.parsingFailed` if parsing fails for non-Fountain formats
  ///
  /// ## Examples
  ///
  /// ```swift
  /// // Fountain format
  /// let cast = try CastExtractor().extractCast(
  ///   from: URL(fileURLWithPath: "episode1.fountain"))
  ///
  /// // Final Draft XML format
  /// let cast = try CastExtractor().extractCast(
  ///   from: URL(fileURLWithPath: "episode2.fdx"))
  ///
  /// // Highland format
  /// let cast = try CastExtractor().extractCast(
  ///   from: URL(fileURLWithPath: "episode3.highland"))
  /// ```
  ///
  /// Format detection is fully automatic based on file extension. No manual
  /// format specification is needed.
  public func extractCast(from fileURL: URL) throws -> [String] {
    let fileExtension = fileURL.pathExtension.lowercased()

    // Validate that the file extension is supported
    let supportedExtensions = ["fountain", "fdx", "highland"]
    guard supportedExtensions.contains(fileExtension) else {
      throw CastExtractionError.unsupportedFormat(fileExtension)
    }

    // Check file exists and is readable
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw CastExtractionError.fileNotReadable(fileURL.path)
    }

    // Try to parse using SwiftCompartido
    do {
      let parsed = try GuionParsedElementCollection(file: fileURL.path)
      let characterInfo = parsed.extractCharacters()
      return characterInfo.keys.sorted()
    } catch {
      // Fallback to regex for Fountain files only
      if fileExtension == "fountain" {
        NSLog(
          "CastExtractor: SwiftCompartido parsing failed for %@ (%@), falling back to regex: %@",
          fileURL.lastPathComponent, String(describing: error), error.localizedDescription)
        do {
          let content = try String(contentsOf: fileURL, encoding: .utf8)
          return extractCastRegex(from: content)
        } catch {
          throw CastExtractionError.fileNotReadable(fileURL.path)
        }
      } else {
        // For non-Fountain formats, propagate the error
        throw CastExtractionError.parsingFailed(fileExtension, error)
      }
    }
  }

  // MARK: - Private Helpers

  /// Regex-based character extraction (fallback for parsing failures).
  ///
  /// This method implements the original regex-based character extraction
  /// algorithm. It is used as a fallback when SwiftCompartido parsing fails.
  private func extractCastRegex(from fountainText: String) -> [String] {
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

  /// Removes parenthetical text from a line.
  ///
  /// Parentheticals like "(CONT'D)", "(V.O.)", "(O.S.)" are common in Fountain
  /// scripts to provide continuation context. This method removes them.
  ///
  /// - Parameter line: The line to process
  /// - Returns: The line with parentheticals removed and trimmed
  ///
  /// - Note: Deprecated in favor of SwiftCompartido parsing. Retained for fallback use only.
  @available(*, deprecated, message: "Replaced by SwiftCompartido parsing; retained for fallback use only")
  private func removeParentheticals(from line: String) -> String {
    line.replacingOccurrences(
      of: "\\s*\\([^)]*\\)\\s*",
      with: "",
      options: .regularExpression
    ).trimmingCharacters(in: .whitespaces)
  }

  /// Determines if a line is likely a character name.
  ///
  /// Character names in screenplays are:
  /// - Entirely uppercase (with possible internal spaces, hyphens, apostrophes)
  /// - NOT scene headings (INT., EXT., EST., INT/EXT)
  /// - NOT transitions (lines ending with "TO:")
  /// - NOT action markers (rarely pure uppercase)
  /// - NOT very short (single letter is unlikely)
  /// - NOT very long (>50 chars is likely action or malformed)
  ///
  /// - Parameter text: The trimmed line text
  /// - Returns: `true` if the line looks like a character name
  ///
  /// - Note: Deprecated in favor of SwiftCompartido parsing. Retained for fallback use only.
  @available(*, deprecated, message: "Replaced by SwiftCompartido parsing; retained for fallback use only")
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

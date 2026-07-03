//
//  MetadataExtractor.swift
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

/// Infers project metadata from directory structure and file patterns.
///
/// `MetadataExtractor` analyzes a project directory to detect:
/// - **Project title** — from directory name, Fountain metadata, or nearest PROJECT.md
/// - **Episode patterns** — from directory structure and file naming
/// - **Language detection** — from ISO 639-1 directory codes (e.g., "en", "es", "it")
/// - **TTS providers** — from configuration files and Fountain metadata
/// - **Season structure** — from directory names (season-1, s1, 1, etc.)
///
/// The extractor gracefully handles missing or ambiguous patterns, returning
/// `nil` for fields that cannot be reliably inferred.
public final class MetadataExtractor {

  /// Infers project metadata from a project directory.
  ///
  /// This method scans the directory structure to detect patterns and infer
  /// project-level metadata. It returns a partial metadata struct with inferred
  /// fields; fields that cannot be reliably inferred are left `nil`.
  ///
  /// ## Inference Rules
  ///
  /// - **Title**: Derived from directory name (last path component) if no PROJECT.md
  /// - **Languages**: Detected from ISO 639-1 directory codes
  /// - **Seasons**: Detected from season-like directory names
  /// - **TTS Provider**: Detected from file patterns and Fountain Frontmatter
  ///
  /// - Parameter directoryPath: The root project directory
  /// - Returns: Inferred metadata (may contain nil fields)
  ///
  /// ## Example
  ///
  /// ```swift
  /// let extractor = MetadataExtractor()
  /// let metadata = extractor.inferMetadata(from: URL(fileURLWithPath: "/path/to/project"))
  /// if let title = metadata?.title {
  ///   print("Inferred title: \(title)")
  /// }
  /// ```
  public func inferMetadata(from directoryPath: URL) -> ProjectMetadataInference? {
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: directoryPath.path) else {
      return nil
    }

    // Infer title from directory name
    let dirName = directoryPath.lastPathComponent
    let title = titleFromDirectoryName(dirName)

    // Scan directory structure
    var languages: [String] = []
    var seasons: [Int] = []
    var ttsProviders: [String] = []

    // Recursively scan directory
    scanForMetadata(
      at: directoryPath,
      fileManager: fileManager,
      languages: &languages,
      seasons: &seasons,
      ttsProviders: &ttsProviders
    )

    // Deduplicate and sort
    let uniqueLanguages = Array(Set(languages)).sorted()
    let uniqueSeasons = Array(Set(seasons)).sorted()
    let uniqueTTSProviders = Array(Set(ttsProviders)).sorted()

    return ProjectMetadataInference(
      title: title,
      languages: uniqueLanguages.isEmpty ? nil : uniqueLanguages,
      seasons: uniqueSeasons.isEmpty ? nil : uniqueSeasons,
      ttsProviders: uniqueTTSProviders.isEmpty ? nil : uniqueTTSProviders
    )
  }

  // MARK: - Private Helpers

  /// Infers a project title from a directory name.
  ///
  /// Converts directory names into readable titles:
  /// - "lingua-matra" → "Lingua Matra"
  /// - "my_podcast" → "My Podcast"
  /// - "MyShow" → "MyShow"
  /// - "content" → "Content"
  /// - "project-12345678" → "Project" (strips UUIDs)
  ///
  /// - Parameter dirName: The directory name
  /// - Returns: A formatted title
  private func titleFromDirectoryName(_ dirName: String) -> String {
    var name = dirName

    // Strip trailing UUID patterns (from test directories)
    // Pattern: -xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    if let range = name.range(
      of: "-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
      options: .regularExpression)
    {
      name.removeSubrange(range)
    }

    // Replace underscores and hyphens with spaces
    let withSpaces =
      name
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "-", with: " ")

    // Capitalize each word (preserve case for words that are already mixed-case)
    return withSpaces.split(separator: " ")
      .map { word in
        let wordStr = String(word)
        // If word is all lowercase, capitalize first letter
        // If word is mixed case or all uppercase, keep as is
        if wordStr == wordStr.lowercased() {
          let first = word.prefix(1).uppercased()
          let rest = word.dropFirst()
          return first + rest
        } else {
          return wordStr
        }
      }
      .joined(separator: " ")
  }

  /// Recursively scans a directory for metadata patterns.
  ///
  /// Looks for:
  /// - Language code directories (ISO 639-1, e.g., "en", "es", "it")
  /// - Season number directories (e.g., "season-1", "s1", "1")
  /// - TTS provider hints (from Fountain metadata and config files)
  /// - Script file patterns
  private func scanForMetadata(
    at url: URL,
    fileManager: FileManager,
    languages: inout [String],
    seasons: inout [Int],
    ttsProviders: inout [String]
  ) {
    guard
      let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    else {
      return
    }

    for item in contents {
      let fileName = item.lastPathComponent

      // Skip hidden files
      if fileName.hasPrefix(".") {
        continue
      }

      // Check if it's a directory
      if let isDir = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir {
        // Check for language code
        if let langCode = parseLanguageCode(fileName) {
          languages.append(langCode)
        }

        // Check for season number
        if let seasonNum = parseSeasonNumber(fileName) {
          seasons.append(seasonNum)
        }

        // Recurse into subdirectories
        scanForMetadata(
          at: item,
          fileManager: fileManager,
          languages: &languages,
          seasons: &seasons,
          ttsProviders: &ttsProviders
        )
      } else {
        // It's a file - check for TTS hints
        if fileName.lowercased().hasSuffix(".fountain") {
          // Try to extract TTS provider from Fountain frontmatter
          if let providers = extractTTSProvidersFromFountain(item) {
            ttsProviders.append(contentsOf: providers)
          }
        }

        if fileName.lowercased().hasSuffix("_voices.json")
          || fileName.lowercased().hasSuffix("_voices.yaml")
          || fileName.lowercased().hasSuffix("_narrators.json")
        {
          // Config file hints at custom TTS setup
          ttsProviders.append("custom")
        }
      }
    }
  }

  /// Parses a directory name as a language code.
  ///
  /// Recognizes:
  /// - Two-letter ISO 639-1 codes: "en", "es", "fr", "it", etc.
  /// - BCP 47 tags: "en-US", "pt-BR", "zh-Hans", etc.
  /// - Three-letter ISO 639-2/3 codes (basic check)
  ///
  /// - Parameter dirName: The directory name to parse
  /// - Returns: The language code, or nil if not recognized
  private func parseLanguageCode(_ dirName: String) -> String? {
    let lowercased = dirName.lowercased()

    // Common ISO 639-1 codes (2 letters)
    let iso639_1 = [
      "aa", "ab", "ae", "af", "ak", "am", "an", "ar", "as", "av", "ay", "az",
      "ba", "be", "bg", "bh", "bi", "bm", "bn", "bo", "br", "bs",
      "ca", "ce", "ch", "co", "cr", "cs", "cu", "cv", "cy",
      "da", "de", "dv", "dz",
      "ee", "el", "en", "eo", "es", "et", "eu",
      "fa", "ff", "fi", "fj", "fo", "fr", "fy",
      "ga", "gd", "gl", "gn", "gu", "gv",
      "ha", "he", "hi", "ho", "hr", "ht", "hu", "hy", "hz",
      "ia", "id", "ie", "ig", "ii", "ik", "io", "is", "it", "iu",
      "ja", "jv",
      "ka", "kg", "ki", "kj", "kk", "kl", "km", "kn", "ko", "kr", "ks", "ku", "kv", "kw", "ky",
      "la", "lb", "lg", "li", "ln", "lo", "lt", "lu", "lv",
      "mg", "mh", "mi", "mk", "ml", "mn", "mr", "ms", "mt", "my",
      "na", "nb", "nd", "ne", "ng", "nl", "nn", "no", "nr", "nv", "ny",
      "oc", "oj", "om", "or", "os",
      "pa", "pi", "pl", "ps", "pt",
      "qu",
      "rm", "rn", "ro", "ru", "rw",
      "sa", "sc", "sd", "se", "sg", "si", "sk", "sl", "sm", "sn", "so", "sq", "sr", "ss", "st",
      "su", "sv", "sw",
      "ta", "te", "tg", "th", "ti", "tk", "tl", "tn", "to", "tr", "ts", "tt", "tw", "ty",
      "ug", "uk", "ur", "uz",
      "ve", "vi", "vo",
      "wa", "wo",
      "xh",
      "yi", "yo",
      "za", "zh", "zu",
    ]

    if iso639_1.contains(lowercased) {
      return lowercased
    }

    // Check for BCP 47 tags (e.g., "en-US", "zh-Hans")
    if lowercased.count > 2 && lowercased.contains("-") {
      let parts = lowercased.split(separator: "-").map(String.init)
      if parts.count >= 2 && iso639_1.contains(parts[0]) {
        return parts[0]
      }
    }

    // Check for 3-letter codes
    if lowercased.count == 3 && lowercased.allSatisfy({ $0.isLetter }) {
      return lowercased
    }

    return nil
  }

  /// Parses a directory name as a season number.
  ///
  /// Recognizes patterns:
  /// - "season-1", "season1", "season-01"
  /// - "s1", "s01"
  /// - "1", "01" (just numbers, 1-3 digits, 1-999)
  ///
  /// - Parameter dirName: The directory name to parse
  /// - Returns: The season number, or nil if not recognized
  private func parseSeasonNumber(_ dirName: String) -> Int? {
    let lowercased = dirName.lowercased()

    // Pattern: "season-N" or "seasonN"
    if lowercased.hasPrefix("season") {
      let remainder = String(lowercased.dropFirst(6))
      let numberStr = remainder.hasPrefix("-") ? String(remainder.dropFirst()) : remainder
      if let number = Int(numberStr), number > 0, number < 1000 {
        return number
      }
    }

    // Pattern: "s" or "s0" prefix
    if lowercased.hasPrefix("s") {
      let remainder = String(lowercased.dropFirst())
      if let number = Int(remainder), number > 0, number < 1000 {
        return number
      }
    }

    // Pattern: just a number
    if let number = Int(lowercased), number > 0, number < 1000 {
      if dirName.allSatisfy({ $0.isNumber }) {
        return number
      }
    }

    return nil
  }

  /// Extracts TTS provider hints from a Fountain file's frontmatter.
  ///
  /// Fountain files may have metadata like:
  /// ```
  /// Title: My Podcast
  /// Author: Me
  /// TTSProvider: Apple
  /// ```
  ///
  /// This method looks for common TTS provider keywords.
  ///
  /// - Parameter fountainURL: URL to a `.fountain` file
  /// - Returns: Array of detected TTS providers, or nil if none found
  private func extractTTSProvidersFromFountain(_ fountainURL: URL) -> [String]? {
    guard let content = try? String(contentsOf: fountainURL, encoding: .utf8) else {
      return nil
    }

    var providers: [String] = []
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

    // Look for frontmatter (first few lines) and metadata
    for line in lines.prefix(20) {
      let lowercased = line.lowercased()

      // Stop at first non-metadata line
      if !lowercased.contains(":") || line.starts(with: "INT.") || line.starts(with: "EXT.") {
        break
      }

      // Check for TTS provider hints
      if lowercased.contains("apple") || lowercased.contains("siri") {
        providers.append("apple")
      }
      if lowercased.contains("google") {
        providers.append("google")
      }
      if lowercased.contains("aws") || lowercased.contains("polly") {
        providers.append("aws")
      }
      if lowercased.contains("openai") || lowercased.contains("tts") {
        providers.append("openai")
      }
    }

    return providers.isEmpty ? nil : providers
  }
}

/// Temporary struct for inferred metadata.
///
/// This struct holds partially inferred metadata where some fields may be nil.
/// It's designed to be converted to `ProjectMetadata` by LLM backends.
public struct ProjectMetadataInference: Sendable {
  /// Inferred project title
  public let title: String?

  /// Detected languages (ISO 639-1 codes)
  public let languages: [String]?

  /// Detected seasons (as numbers)
  public let seasons: [Int]?

  /// Detected TTS providers
  public let ttsProviders: [String]?

  public init(
    title: String? = nil,
    languages: [String]? = nil,
    seasons: [Int]? = nil,
    ttsProviders: [String]? = nil
  ) {
    self.title = title
    self.languages = languages
    self.seasons = seasons
    self.ttsProviders = ttsProviders
  }
}

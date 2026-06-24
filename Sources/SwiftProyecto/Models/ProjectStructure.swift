//
//  ProjectStructure.swift
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

/// Recognition pattern describing how a project organizes episodes across languages and seasons.
///
/// Automatically detected by scanning the directory structure and identifying patterns
/// in how directories and files are organized.
///
/// ## Pattern Types
///
/// - **languageFirstMultiSeason**: Language directories contain season subdirectories
///   - Structure: `<lang>/<season>/*.fountain`
///   - Example: `en/season-1/*.fountain`, `es/season-1/*.fountain`
///   - Used by: lingua-matra and similar multi-language projects
///
/// - **singleLanguageMultiSeason**: Season directories at root with no language separation
///   - Structure: `<season>/*.fountain`
///   - Example: `season-1/*.fountain`, `season-2/*.fountain`
///   - Used by: Single-language multi-season projects
///
/// - **languageOnly**: Language directories with no season organization
///   - Structure: `<lang>/*.fountain`
///   - Example: `en/*.fountain`, `es/*.fountain`
///   - Used by: Multi-language single-season projects
///
/// - **flat**: All files in single directory with no language or season separation
///   - Structure: `*.fountain`
///   - Used by: Simple, minimal projects
///
/// - **unknown**: Unable to classify the directory structure
///   - Occurs for: Mixed patterns, unusual organizations, or ambiguous layouts
public enum RecognitionPattern: Equatable, Sendable {
  /// Language directories contain season subdirectories
  /// - languages: List of detected language codes (e.g., ["en", "es", "fr"])
  /// - seasons: List of detected season numbers (e.g., [1, 2, 3])
  case languageFirstMultiSeason(languages: [String], seasons: [Int])

  /// Single language with multiple seasons
  /// - seasons: List of detected season numbers
  case singleLanguageMultiSeason(seasons: [Int])

  /// Multiple languages, no season separation
  /// - languages: List of detected language codes
  case languageOnly(languages: [String])

  /// All files in root directory
  case flat

  /// Unable to classify
  case unknown
}

/// Scanned structure of a project directory showing how it organizes files.
///
/// ProjectStructure provides a machine-readable description of the directory organization,
/// including detected languages, seasons, file patterns, and a classification of the
/// overall organizational pattern.
///
/// ## Usage
///
/// ```swift
/// let structure = ProjectService.scanAndRecognize(at: projectURL)
///
/// switch structure.recognizedPattern {
/// case .languageFirstMultiSeason(let langs, let seasons):
///   print("Multi-language project with \(langs.count) languages and \(seasons.count) seasons")
///
/// case .singleLanguageMultiSeason(let seasons):
///   print("Single-language project with \(seasons.count) seasons")
///
/// case .languageOnly(let langs):
///   print("Language-only project with languages: \(langs.joined(separator: ", "))")
///
/// case .flat:
///   print("Flat directory structure")
///
/// case .unknown:
///   print("Unrecognized structure")
/// }
/// ```
public struct ProjectStructure: Sendable, Equatable {
  /// Root URL of the scanned directory
  public let rootURL: URL

  /// Directory map showing languages and seasons found
  /// Keys are language codes, values are sorted arrays of season numbers
  public let directoryMap: [String: [Int]]

  /// Detected file patterns (e.g., ["*.fountain", "*.fdx", "*.highland"])
  public let filePatterns: [String]

  /// Detected audio output directory paths
  public let audioDirectories: [String]

  /// Detected voice/narrator configuration files
  public let voiceFiles: [String]

  /// Classified organization pattern
  public let recognizedPattern: RecognitionPattern

  /// Creates a new project structure.
  ///
  /// - Parameters:
  ///   - rootURL: Root directory URL
  ///   - directoryMap: Language → season mapping
  ///   - filePatterns: File extensions/patterns found
  ///   - audioDirectories: Audio output paths
  ///   - voiceFiles: Voice configuration files
  ///   - recognizedPattern: Classified structure type
  public init(
    rootURL: URL,
    directoryMap: [String: [Int]] = [:],
    filePatterns: [String] = [],
    audioDirectories: [String] = [],
    voiceFiles: [String] = [],
    recognizedPattern: RecognitionPattern = .unknown
  ) {
    self.rootURL = rootURL
    self.directoryMap = directoryMap
    self.filePatterns = filePatterns
    self.audioDirectories = audioDirectories
    self.voiceFiles = voiceFiles
    self.recognizedPattern = recognizedPattern
  }
}

// MARK: - Pattern Recognition Helpers

extension RecognitionPattern {
  /// Returns a human-readable description of the pattern type
  public var description: String {
    switch self {
    case .languageFirstMultiSeason(let langs, let seasons):
      return "Language-first multi-season (\(langs.count) languages, \(seasons.count) seasons)"
    case .singleLanguageMultiSeason(let seasons):
      return "Single-language multi-season (\(seasons.count) seasons)"
    case .languageOnly(let langs):
      return "Language-only (\(langs.count) languages)"
    case .flat:
      return "Flat structure"
    case .unknown:
      return "Unknown structure"
    }
  }
}

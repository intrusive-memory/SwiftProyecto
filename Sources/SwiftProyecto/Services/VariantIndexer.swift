//
//  VariantIndexer.swift
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

/// Error type for variant discovery and indexing operations.
public enum VariantIndexError: LocalizedError {
  /// Variant file not found at the specified path
  case variantFileNotFound(path: String)

  /// File is not a master file (no variants array)
  case notAMasterFile(String)

  /// Variant with the specified language/season not found
  case variantNotFound(language: String, season: Int)

  /// Invalid variant reference format
  case invalidVariantReference(String)

  /// Failed to parse variant file
  case parseError(path: String, reason: String)

  public var errorDescription: String? {
    switch self {
    case .variantFileNotFound(let path):
      return "Variant file not found at path: \(path)"
    case .notAMasterFile(let filename):
      return "File '\(filename)' is not a master file (must have variants array)"
    case .variantNotFound(let language, let season):
      return "Variant not found: language=\(language), season=\(season)"
    case .invalidVariantReference(let msg):
      return "Invalid variant reference: \(msg)"
    case .parseError(let path, let reason):
      return "Failed to parse variant at \(path): \(reason)"
    }
  }
}

/// Service for discovering and indexing variants from a master PROJECT.md.
///
/// A master file contains a `variants[]` array that references child PROJECT files
/// (one per language/season combination). VariantIndexer loads all variants and
/// builds an in-memory index for quick lookup.
///
/// ## Usage
///
/// ```swift
/// let masterURL = URL(fileURLWithPath: "/path/to/PROJECT.md")
/// let parser = ProjectMarkdownParser()
/// let (master, _) = try parser.parse(fileURL: masterURL)
///
/// let indexer = VariantIndexer(master: master, masterDirectory: masterURL.deletingLastPathComponent())
/// try indexer.loadVariants()
///
/// // Get all variants for a language
/// if let variants = indexer.variants(for: "es") {
///     for (season, variant) in variants {
///         print("Season \(season): \(variant.title)")
///     }
/// }
///
/// // Get a specific variant
/// if let variant = indexer.variant(for: "es", season: 1) {
///     print("Got variant: \(variant.title)")
/// }
/// ```
public class VariantIndexer {

  /// In-memory index of variants keyed by language, then season.
  /// Format: [language: [season: ProjectFrontMatter]]
  private(set) var index: [String: [Int: ProjectFrontMatter]] = [:]

  /// The master ProjectFrontMatter this indexer serves.
  private(set) var master: ProjectFrontMatter

  /// The directory containing the master PROJECT.md.
  private(set) var masterDirectory: URL

  /// Create a new variant indexer.
  ///
  /// - Parameters:
  ///   - master: The master ProjectFrontMatter
  ///   - masterDirectory: The directory containing the master PROJECT.md
  public init(master: ProjectFrontMatter, masterDirectory: URL) {
    self.master = master
    self.masterDirectory = masterDirectory
    self.index = [:]
  }

  /// Load all variants from the master's variants[] array.
  ///
  /// For each VariantReference in master.variants[], loads the referenced
  /// PROJECT file and stores it in the index by (language, season).
  ///
  /// - Throws: VariantIndexError if variant file cannot be loaded or parsed
  public func loadVariants() throws {
    guard let variants = master.variants else { return }

    for variantRef in variants {
      try loadVariant(variantRef)
    }
  }

  /// Load a single variant from a VariantReference.
  ///
  /// - Parameter variantRef: The variant reference to load
  /// - Throws: VariantIndexError if the variant cannot be loaded or parsed
  private func loadVariant(_ variantRef: VariantReference) throws {
    // Construct variant file path relative to master directory
    let variantPath = masterDirectory.appendingPathComponent(variantRef.path)

    // Check that the file exists
    guard FileManager.default.fileExists(atPath: variantPath.path) else {
      throw VariantIndexError.variantFileNotFound(path: variantRef.path)
    }

    // Load and parse variant PROJECT file
    let parser = ProjectMarkdownParser()
    do {
      let (variant, _) = try parser.parse(fileURL: variantPath)

      // Index by language and season
      let key = variantRef.language
      if index[key] == nil {
        index[key] = [:]
      }
      index[key]?[variantRef.season] = variant
    } catch {
      throw VariantIndexError.parseError(path: variantRef.path, reason: error.localizedDescription)
    }
  }

  /// Get a specific variant by language and season.
  ///
  /// - Parameters:
  ///   - language: Language code (e.g., "es")
  ///   - season: Season number
  ///
  /// - Returns: ProjectFrontMatter for the variant, or nil if not found
  public func variant(for language: String, season: Int) -> ProjectFrontMatter? {
    index[language]?[season]
  }

  /// Get all variants for a specific language.
  ///
  /// - Parameter language: Language code
  /// - Returns: Dictionary of season → variant ProjectFrontMatter, or nil if language not found
  public func variants(for language: String) -> [Int: ProjectFrontMatter]? {
    index[language]
  }

  /// Get all available language codes.
  ///
  /// - Returns: Sorted array of language codes
  public var languages: [String] {
    index.keys.sorted()
  }

  /// Get all available seasons for a given language.
  ///
  /// - Parameter language: Language code
  /// - Returns: Sorted array of season numbers
  public func seasons(for language: String) -> [Int] {
    if let seasonVariants = index[language] {
      return Array(seasonVariants.keys).sorted()
    }
    return []
  }

  /// Get all variants as a flat array.
  ///
  /// - Returns: Array of all variants in the index, or empty array if no variants
  public func allVariants() -> [ProjectFrontMatter] {
    var result: [ProjectFrontMatter] = []
    for language in languages {
      if let seasonVariants = variants(for: language) {
        for (_, variant) in seasonVariants.sorted(by: { $0.key < $1.key }) {
          result.append(variant)
        }
      }
    }
    return result
  }
}

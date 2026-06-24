//
//  ProjectValidator.swift
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

/// Comprehensive validator for PROJECT.md files supporting both v3.x and v4.0.0 schemas.
///
/// Detects schema version automatically and applies appropriate validation rules:
/// - v3.x files (no `schemaVersion` field): Basic validation with legacy season support
/// - v4.0.0 files (`schemaVersion: 4`): Extended validation with type checking and multi-season rules
public struct ProjectValidator {

  public init() {}

  /// Validation result containing errors, warnings, and metadata.
  ///
  /// - errors: Critical validation failures (must be fixed)
  /// - warnings: Non-critical issues (should review)
  /// - metadata: Detected schema version, file type, and counts
  public struct ValidationResult: Equatable {
    public let errors: [String]
    public let warnings: [String]
    public let metadata: ValidationMetadata

    /// Returns true if validation passed (no errors)
    public var isValid: Bool {
      errors.isEmpty
    }

    public init(
      errors: [String] = [],
      warnings: [String] = [],
      metadata: ValidationMetadata = ValidationMetadata()
    ) {
      self.errors = errors
      self.warnings = warnings
      self.metadata = metadata
    }
  }

  /// Metadata about the validated PROJECT file.
  public struct ValidationMetadata: Equatable {
    /// Detected schema version (3 for v3.x, 4 for v4.0.0)
    public let schemaVersion: Int

    /// File type classification
    ///
    /// - master: Overview/master file with variants array (v4.0.0 only)
    /// - project: Single project file (v3.x or v4.0.0 with type="project")
    /// - variant: Variant PROJECT file (v4.0.0 only)
    /// - single: Single-episode or legacy file
    public let fileType: String

    /// Number of seasons defined, if any
    public let seasonCount: Int?

    /// Season numbers detected (for duplicate checking)
    public let seasonNumbers: [Int]?

    /// Number of languages defined, if any
    public let languageCount: Int?

    /// Language codes detected
    public let languageCodes: [String]?

    /// Number of variants defined, if any
    public let variantCount: Int?

    public init(
      schemaVersion: Int = 3,
      fileType: String = "project",
      seasonCount: Int? = nil,
      seasonNumbers: [Int]? = nil,
      languageCount: Int? = nil,
      languageCodes: [String]? = nil,
      variantCount: Int? = nil
    ) {
      self.schemaVersion = schemaVersion
      self.fileType = fileType
      self.seasonCount = seasonCount
      self.seasonNumbers = seasonNumbers
      self.languageCount = languageCount
      self.languageCodes = languageCodes
      self.variantCount = variantCount
    }
  }

  /// Validate a PROJECT front matter structure.
  ///
  /// Applies schema-specific validation:
  /// - Both v3 and v4: required fields, type validation, date validity
  /// - v3 files: legacy season/episode support
  /// - v4 files: type-specific rules, season/language uniqueness, episode counts
  ///
  /// - Parameter frontMatter: The parsed PROJECT.md front matter
  /// - Returns: ValidationResult with errors, warnings, and metadata
  public func validate(_ frontMatter: ProjectFrontMatter) -> ValidationResult {
    var errors: [String] = []
    var warnings: [String] = []
    var metadata = detectMetadata(frontMatter)

    // 1. Core field validation (applies to all versions)
    validateCoreFields(frontMatter, errors: &errors)

    // 2. Type field validation
    validateTypeField(frontMatter, errors: &errors)

    // 3. Schema-specific validation
    if metadata.schemaVersion == 4 {
      validateV4Structure(frontMatter, errors: &errors, warnings: &warnings, metadata: &metadata)
    } else {
      validateV3Structure(frontMatter, errors: &errors, warnings: &warnings, metadata: &metadata)
    }

    return ValidationResult(
      errors: errors,
      warnings: warnings,
      metadata: metadata
    )
  }

  // MARK: - Metadata Detection

  private func detectMetadata(_ frontMatter: ProjectFrontMatter) -> ValidationMetadata {
    let schemaVersion = frontMatter.detectedSchemaVersion()
    let fileType = detectFileType(frontMatter)

    let seasonCount = frontMatter.seasons?.count
    let seasonNumbers = frontMatter.seasons?.map { $0.number }.sorted()

    let languageCount = frontMatter.languages?.count
    let languageCodes = frontMatter.languages?.map { $0.code }.sorted()

    let variantCount = frontMatter.variants?.count

    return ValidationMetadata(
      schemaVersion: schemaVersion,
      fileType: fileType,
      seasonCount: seasonCount,
      seasonNumbers: seasonNumbers,
      languageCount: languageCount,
      languageCodes: languageCodes,
      variantCount: variantCount
    )
  }

  private func detectFileType(_ frontMatter: ProjectFrontMatter) -> String {
    let hasVariants = frontMatter.variants != nil && !(frontMatter.variants?.isEmpty ?? true)
    let isOverview = frontMatter.projectType?.lowercased() == "overview"

    if hasVariants || isOverview {
      return "master"
    }

    // Check if this is a variant (has specific variant-like fields)
    if let projectType = frontMatter.projectType, projectType.lowercased() != "project" {
      return "variant"
    }

    return "project"
  }

  // MARK: - Core Validation

  private func validateCoreFields(
    _ frontMatter: ProjectFrontMatter,
    errors: inout [String]
  ) {
    // type field is required and handled separately
    if frontMatter.title.isEmpty {
      errors.append("Missing or empty title field")
    }

    if frontMatter.author.isEmpty {
      errors.append("Missing or empty author field")
    }

    // created date is already validated by parser
  }

  private func validateTypeField(
    _ frontMatter: ProjectFrontMatter,
    errors: inout [String]
  ) {
    let validTypes = ["project", "overview"]
    let normalizedType = frontMatter.type.lowercased()

    if !validTypes.contains(normalizedType) {
      errors.append(
        "Invalid type \"\(frontMatter.type)\" — must be \"project\" or \"overview\""
      )
    }
  }

  // MARK: - v3.x Validation

  private func validateV3Structure(
    _ frontMatter: ProjectFrontMatter,
    errors: inout [String],
    warnings: inout [String],
    metadata: inout ValidationMetadata
  ) {
    // v3 files use legacy season/episodes fields
    // If neither is present, no special validation needed
    // If present, basic consistency check

    if let season = frontMatter.season {
      if season <= 0 {
        warnings.append("Season number should be positive: \(season)")
      }

      if let episodes = frontMatter.episodes, episodes <= 0 {
        warnings.append("Episode count should be positive: \(episodes)")
      }
    }
  }

  // MARK: - v4.0.0 Validation

  private func validateV4Structure(
    _ frontMatter: ProjectFrontMatter,
    errors: inout [String],
    warnings: inout [String],
    metadata: inout ValidationMetadata
  ) {
    let projectType = frontMatter.projectType?.lowercased() ?? "project"

    // Type-specific validation
    if projectType == "overview" {
      validateV4OverviewFile(frontMatter, errors: &errors, warnings: &warnings)
    } else if projectType == "project" {
      validateV4ProjectFile(frontMatter, errors: &errors, warnings: &warnings)
    }

    // Validate seasons if present
    if let seasons = frontMatter.seasons, !seasons.isEmpty {
      validateSeasons(seasons, errors: &errors, warnings: &warnings, metadata: &metadata)
    }

    // Validate languages if present
    if let languages = frontMatter.languages, !languages.isEmpty {
      validateLanguages(languages, errors: &errors)
    }
  }

  private func validateV4OverviewFile(
    _ frontMatter: ProjectFrontMatter,
    errors: inout [String],
    warnings: inout [String]
  ) {
    // Overview files should have variants array (can be empty)
    if frontMatter.variants == nil {
      warnings.append("Overview files should define a 'variants' array")
    }

    // Overview files should NOT have episodesDir
    if frontMatter.episodesDir != nil {
      warnings.append(
        "Overview files should not define 'episodesDir' — that belongs in variants or projects"
      )
    }
  }

  private func validateV4ProjectFile(
    _ frontMatter: ProjectFrontMatter,
    errors: inout [String],
    warnings: inout [String]
  ) {
    // Project files may have seasons and languages
    // No specific restrictions on episodesDir or other fields
    // This is intentionally permissive
  }

  // MARK: - Season Validation

  private func validateSeasons(
    _ seasons: [SeasonDefinition],
    errors: inout [String],
    warnings: inout [String],
    metadata: inout ValidationMetadata
  ) {
    let seasonNumbers = seasons.map { $0.number }
    let uniqueNumbers = Set(seasonNumbers)

    // Check for duplicates
    if uniqueNumbers.count < seasonNumbers.count {
      let duplicates = seasonNumbers.filter { num in
        seasonNumbers.filter { $0 == num }.count > 1
      }
      let uniqueDuplicates = Array(Set(duplicates)).sorted()
      errors.append(
        "Duplicate season numbers: \(uniqueDuplicates.map(String.init).joined(separator: ", "))"
      )
    }

    // Check episode counts
    for season in seasons {
      if season.episodes <= 0 {
        errors.append("Season \(season.number) must have episodes > 0, got \(season.episodes)")
      }

      // Check for reasonable season numbers
      if season.number <= 0 {
        errors.append("Season number must be positive, got \(season.number)")
      }
    }
  }

  // MARK: - Language Validation

  private func validateLanguages(
    _ languages: [LanguageDefinition],
    errors: inout [String]
  ) {
    let codes = languages.map { $0.code }
    let uniqueCodes = Set(codes)

    // Check for duplicates
    if uniqueCodes.count < codes.count {
      let duplicates = codes.filter { code in
        codes.filter { $0 == code }.count > 1
      }
      let uniqueDuplicates = Array(Set(duplicates))
      errors.append(
        "Duplicate language codes: \(uniqueDuplicates.sorted().joined(separator: ", "))"
      )
    }

    // Check for empty codes
    for language in languages {
      if language.code.isEmpty {
        errors.append("Language code cannot be empty")
      }
    }
  }
}

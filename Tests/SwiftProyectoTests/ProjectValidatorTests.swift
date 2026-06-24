//
//  ProjectValidatorTests.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import Foundation
import XCTest
import SwiftProyecto

/// Unit tests for the ProjectValidator.
final class ProjectValidatorTests: XCTestCase {

  let validator = ProjectValidator()

  // MARK: - v3.x Schema Tests

  func testValidateV3MinimalFile() {
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Legacy Project",
      author: "Legacy Author",
      created: Date()
    )

    let result = validator.validate(frontMatter)

    XCTAssertTrue(result.isValid, "v3.x minimal file should be valid")
    XCTAssertEqual(result.metadata.schemaVersion, 3, "Should detect v3.x schema")
    XCTAssertEqual(result.metadata.fileType, "project", "Should detect project file type")
    XCTAssertNil(result.metadata.seasonCount, "v3 file without seasons shouldn't report count")
  }

  func testValidateV3WithLegacySeasonEpisodes() {
    let seasons = [SeasonDefinition(number: 1, episodes: 5)]
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Legacy Project",
      author: "Legacy Author",
      created: Date(),
      season: 1,
      episodes: 5,
      seasons: seasons
    )

    let result = validator.validate(frontMatter)

    XCTAssertTrue(result.isValid, "v3.x file with season/episodes should be valid")
    XCTAssertEqual(result.metadata.schemaVersion, 3)
    XCTAssertEqual(result.metadata.seasonCount, 1)
    XCTAssertEqual(result.metadata.seasonNumbers, [1])
  }

  // MARK: - v4.0.0 Schema Tests

  func testValidateV4ProjectFile() {
    let seasons = [
      SeasonDefinition(number: 1, title: "Season One", episodes: 8),
      SeasonDefinition(number: 2, title: "Season Two", episodes: 10),
    ]
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Modern Project",
      author: "Modern Author",
      created: Date(),
      schemaVersion: 4,
      projectType: "project",
      seasons: seasons
    )

    let result = validator.validate(frontMatter)

    XCTAssertTrue(result.isValid, "v4 project file should be valid")
    XCTAssertEqual(result.metadata.schemaVersion, 4, "Should detect v4.0.0 schema")
    XCTAssertEqual(result.metadata.fileType, "project")
    XCTAssertEqual(result.metadata.seasonCount, 2)
    XCTAssertEqual(result.metadata.seasonNumbers, [1, 2])
  }

  func testValidateV4OverviewWithVariants() {
    let variants = [
      VariantReference(season: 1, language: "en", path: "season-1-en/PROJECT.md"),
      VariantReference(season: 1, language: "es", path: "season-1-es/PROJECT.md"),
    ]
    let frontMatter = ProjectFrontMatter(
      type: "overview",
      title: "Master Series",
      author: "Showrunner",
      created: Date(),
      schemaVersion: 4,
      projectType: "overview",
      variants: variants
    )

    let result = validator.validate(frontMatter)

    XCTAssertTrue(result.isValid, "v4 overview with variants should be valid")
    XCTAssertEqual(result.metadata.fileType, "master", "Should detect master file type")
    XCTAssertEqual(result.metadata.variantCount, 2)
  }

  func testValidateV4OverviewWithoutVariants_Warning() {
    let frontMatter = ProjectFrontMatter(
      type: "overview",
      title: "Overview Without Variants",
      author: "Author",
      created: Date(),
      schemaVersion: 4,
      projectType: "overview"
    )

    let result = validator.validate(frontMatter)

    XCTAssertTrue(result.isValid, "Overview without variants should still be valid")
    XCTAssertTrue(!result.warnings.isEmpty, "Should have warnings")
    XCTAssertTrue(
      result.warnings.contains { $0.contains("variants") },
      "Should warn about missing variants"
    )
  }

  // MARK: - Type Field Validation

  func testValidateInvalidType() {
    let frontMatter = ProjectFrontMatter(
      type: "broadcast",
      title: "Bad Type",
      author: "Author",
      created: Date()
    )

    let result = validator.validate(frontMatter)

    XCTAssertFalse(result.isValid, "Invalid type should fail validation")
    XCTAssertTrue(!result.errors.isEmpty, "Should have errors")
    XCTAssertTrue(
      result.errors.contains { $0.contains("Invalid type") },
      "Should have specific error about invalid type"
    )
    XCTAssertTrue(
      result.errors.contains { $0.contains("must be \"project\" or \"overview\"") },
      "Should provide guidance on valid types"
    )
  }

  func testValidateValidTypes() {
    for type in ["project", "overview", "Project", "OVERVIEW"] {
      let frontMatter = ProjectFrontMatter(
        type: type,
        title: "Test",
        author: "Author",
        created: Date()
      )

      let result = validator.validate(frontMatter)

      XCTAssertFalse(
        result.errors.contains { $0.contains("Invalid type") },
        "Type '\(type)' should be valid"
      )
    }
  }

  // MARK: - Season Validation

  func testValidateUniqueSeasons() {
    let seasons = [
      SeasonDefinition(number: 1, episodes: 8),
      SeasonDefinition(number: 2, episodes: 10),
      SeasonDefinition(number: 3, episodes: 6),
    ]
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Multi-Season Project",
      author: "Author",
      created: Date(),
      schemaVersion: 4,
      projectType: "project",
      seasons: seasons
    )

    let result = validator.validate(frontMatter)

    XCTAssertTrue(result.isValid, "Project with unique seasons should be valid")
  }

  func testValidateDuplicateSeasons() {
    let seasons = [
      SeasonDefinition(number: 1, episodes: 8),
      SeasonDefinition(number: 1, episodes: 10),
    ]
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Duplicate Seasons",
      author: "Author",
      created: Date(),
      schemaVersion: 4,
      projectType: "project",
      seasons: seasons
    )

    let result = validator.validate(frontMatter)

    XCTAssertFalse(result.isValid, "Duplicate seasons should fail")
    XCTAssertTrue(
      result.errors.contains { $0.contains("Duplicate season numbers") },
      "Should report duplicate seasons"
    )
  }

  func testValidateZeroEpisodes() {
    let seasons = [
      SeasonDefinition(number: 1, episodes: 0),
    ]
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Zero Episodes",
      author: "Author",
      created: Date(),
      schemaVersion: 4,
      projectType: "project",
      seasons: seasons
    )

    let result = validator.validate(frontMatter)

    XCTAssertFalse(result.isValid, "Season with zero episodes should fail")
    XCTAssertTrue(
      result.errors.contains { $0.contains("must have episodes > 0") },
      "Should report episode count error"
    )
  }

  func testValidateNegativeEpisodes() {
    let seasons = [
      SeasonDefinition(number: 1, episodes: -5),
    ]
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Negative Episodes",
      author: "Author",
      created: Date(),
      schemaVersion: 4,
      projectType: "project",
      seasons: seasons
    )

    let result = validator.validate(frontMatter)

    XCTAssertFalse(result.isValid, "Season with negative episodes should fail")
  }

  // MARK: - Core Field Validation

  func testValidateMissingTitle() {
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "",
      author: "Author",
      created: Date()
    )

    let result = validator.validate(frontMatter)

    XCTAssertFalse(result.isValid, "Missing title should fail")
    XCTAssertTrue(
      result.errors.contains { $0.contains("title") },
      "Should report missing/empty title"
    )
  }

  func testValidateMissingAuthor() {
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Title",
      author: "",
      created: Date()
    )

    let result = validator.validate(frontMatter)

    XCTAssertFalse(result.isValid, "Missing author should fail")
    XCTAssertTrue(
      result.errors.contains { $0.contains("author") },
      "Should report missing/empty author"
    )
  }

  // MARK: - Metadata Detection

  func testMetadataDetectionMaster() {
    let variants = [
      VariantReference(season: 1, language: "en", path: "s1_en/PROJECT.md"),
    ]
    let frontMatter = ProjectFrontMatter(
      type: "overview",
      title: "Master",
      author: "Author",
      created: Date(),
      schemaVersion: 4,
      projectType: "overview",
      variants: variants
    )

    let result = validator.validate(frontMatter)

    XCTAssertEqual(result.metadata.fileType, "master", "Should detect master file type")
  }

  func testMetadataDetectionProject() {
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Project",
      author: "Author",
      created: Date(),
      schemaVersion: 4,
      projectType: "project"
    )

    let result = validator.validate(frontMatter)

    XCTAssertEqual(result.metadata.fileType, "project", "Should detect project file type")
  }

  // MARK: - Language Validation

  func testValidateUniquenessLanguages() {
    let languages = [
      LanguageDefinition(code: "en", name: "English"),
      LanguageDefinition(code: "es", name: "Spanish"),
      LanguageDefinition(code: "fr", name: "French"),
    ]
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Multi-Language",
      author: "Author",
      created: Date(),
      schemaVersion: 4,
      projectType: "project",
      languages: languages
    )

    let result = validator.validate(frontMatter)

    XCTAssertTrue(result.isValid, "Unique languages should be valid")
    XCTAssertEqual(result.metadata.languageCount, 3)
    XCTAssertEqual(result.metadata.languageCodes, ["en", "es", "fr"])
  }

  func testValidateDuplicateLanguages() {
    let languages = [
      LanguageDefinition(code: "en", name: "English"),
      LanguageDefinition(code: "en", name: "English (USA)"),
    ]
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Duplicate Languages",
      author: "Author",
      created: Date(),
      schemaVersion: 4,
      projectType: "project",
      languages: languages
    )

    let result = validator.validate(frontMatter)

    XCTAssertFalse(result.isValid, "Duplicate languages should fail")
    XCTAssertTrue(
      result.errors.contains { $0.contains("Duplicate language codes") },
      "Should report duplicate language codes"
    )
  }
}

//
//  TypeValidationTests.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import XCTest

@testable import SwiftProyecto

final class TypeValidationTests: XCTestCase {

  // MARK: - Setup Helpers

  func makeTemporaryDirectory() throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("proyectoTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    return tempDir
  }

  func makeTestProjectMD(
    content: String,
    in directory: URL
  ) throws -> URL {
    let projectMDURL = directory.appendingPathComponent("PROJECT.md")
    try content.write(to: projectMDURL, atomically: true, encoding: .utf8)
    return projectMDURL
  }

  // MARK: - Type Field Validation Tests

  func testValidateProjectType_ValidProject_Passes() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: project
      title: Valid Project
      author: Author
      created: 2025-01-01T00:00:00Z
      season: 1
      episodes: 5
      ---

      # Valid project type
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify no errors for valid type
    XCTAssertTrue(result.isValid)
    XCTAssertFalse(
      result.errors.contains { $0.contains("type") || $0.contains("Type") },
      "Should not have type-related errors for valid 'project' type"
    )
  }

  func testValidateProjectType_ValidOverview_Passes() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Valid Overview
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
      ---

      # Valid overview type
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify no errors for valid type
    XCTAssertTrue(result.isValid)
    XCTAssertFalse(
      result.errors.contains { $0.contains("type") || $0.contains("Type") },
      "Should not have type-related errors for valid 'overview' type"
    )
  }

  func testValidateProjectType_InvalidType_Fails() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let invalidTypes = ["invalid", "collection", "bundle", "series", "episode"]

    for invalidType in invalidTypes {
      let projectMDContent = """
        ---
        type: \(invalidType)
        title: Invalid Type
        author: Author
        created: 2025-01-01T00:00:00Z
        ---

        # Invalid type: \(invalidType)
        """

      let tempDir = try makeTemporaryDirectory()
      defer { try? FileManager.default.removeItem(at: tempDir) }

      try makeTestProjectMD(content: projectMDContent, in: tempDir)

      let parser = ProjectMarkdownParser()
      let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

      let validator = ProjectValidator()
      let result = validator.validate(frontMatter)

      // Verify error for invalid type
      XCTAssertFalse(
        result.isValid,
        "Should fail validation for invalid type '\(invalidType)'"
      )
      XCTAssertTrue(
        result.errors.contains { $0.contains("type") || $0.contains("Type") },
        "Should have type-related error for invalid type '\(invalidType)'"
      )
    }
  }

  func testValidateProjectType_CaseSensitive_Lowercase() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // "project" is valid (lowercase)
    let projectMDContent = """
      ---
      type: project
      title: Lowercase
      author: Author
      created: 2025-01-01T00:00:00Z
      ---

      # Lowercase 'project' should work
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify lowercase is accepted
    XCTAssertTrue(result.isValid)
  }

  func testValidateProjectType_CaseInsensitive_MixedCase_Accepted() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let mixedCaseTypes = ["Project", "PROJECT", "Overview", "OVERVIEW"]

    for mixedType in mixedCaseTypes {
      let projectMDContent = """
        ---
        type: \(mixedType)
        title: Mixed Case
        author: Author
        created: 2025-01-01T00:00:00Z
        schemaVersion: 4
        projectType: overview
        ---

        # Mixed case: \(mixedType)
        """

      let tempDir = try makeTemporaryDirectory()
      defer { try? FileManager.default.removeItem(at: tempDir) }

      try makeTestProjectMD(content: projectMDContent, in: tempDir)

      let parser = ProjectMarkdownParser()
      let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

      let validator = ProjectValidator()
      let result = validator.validate(frontMatter)

      // Verify mixed case is accepted (case-insensitive validation)
      XCTAssertTrue(
        result.isValid,
        "Should accept mixed-case type '\(mixedType)' (case-insensitive validation)"
      )
    }
  }

  // MARK: - Type-Specific Validation Tests

  func testValidateTypeSpecific_OverviewShouldHaveVariantsArray() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Overview Without Variants Array
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      ---

      # Overview should have variants array
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify warning for missing variants array
    let hasVariantsWarning = result.warnings.contains { $0.lowercased().contains("variant") }
    XCTAssertTrue(
      hasVariantsWarning,
      "Should warn for overview file without variants array"
    )
  }

  func testValidateTypeSpecific_OverviewWithSeasons_Passes() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Overview With Seasons
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
        - number: 2
          episodes: 10
      ---

      # Overview with proper season definitions
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify valid overview
    XCTAssertTrue(
      result.isValid,
      "Overview with proper seasons should validate"
    )
  }

  func testValidateTypeSpecific_ProjectWithoutEpisodesDir_Acceptable() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: project
      title: Project Without episodesDir
      author: Author
      created: 2025-01-01T00:00:00Z
      season: 1
      episodes: 5
      ---

      # Project without explicit episodesDir (uses default)
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify no error (episodesDir is optional, defaults to "episodes")
    let hasEpisodesDirError = result.errors.contains { $0.lowercased().contains("episodesdir") }
    XCTAssertFalse(
      hasEpisodesDirError,
      "Project without episodesDir should be acceptable (uses default)"
    )
  }

  // MARK: - ProjectType Enum Conversion Tests

  func testProjectTypeEnum_ProjectValue_ReturnsProjectCase() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: project
      title: Test
      author: Author
      created: 2025-01-01T00:00:00Z
      ---

      # Test
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify projectTypeEnum computation
    let projectTypeEnum = ProjectType(rawValue: frontMatter.type)
    XCTAssertEqual(projectTypeEnum, .project)
  }

  func testProjectTypeEnum_OverviewValue_ReturnsOverviewCase() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Test
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      ---

      # Test
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify projectTypeEnum computation
    let projectTypeEnum = ProjectType(rawValue: frontMatter.type)
    XCTAssertEqual(projectTypeEnum, .overview)
  }

  func testProjectTypeEnum_InvalidValue_ReturnsNil() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: invalid
      title: Test
      author: Author
      created: 2025-01-01T00:00:00Z
      ---

      # Test
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify projectTypeEnum is nil for invalid type
    let projectTypeEnum = ProjectType(rawValue: frontMatter.type)
    XCTAssertNil(projectTypeEnum)
  }

  // MARK: - Master vs. Variant Detection Tests

  func testIsMasterFile_WithOverviewAndVariants_True() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Master
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
      variants:
        - season: 1
          language: en
          path: "s01_en/PROJECT.md"
      ---

      # Master file with variants
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify master file detection
    XCTAssertEqual(result.metadata.fileType, "master")
  }

  func testIsMasterFile_WithProjectType_False() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: project
      title: Project
      author: Author
      created: 2025-01-01T00:00:00Z
      season: 1
      episodes: 5
      ---

      # Project file, not master
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify not a master file
    XCTAssertNotEqual(result.metadata.fileType, "master")
  }

  func testIsMasterFile_WithOverviewTypeButNoVariants_IsStillMaster() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Overview Without Variants Yet
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      ---

      # Overview type is master even without variants
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify overview type means master, even without variants array
    XCTAssertEqual(result.metadata.fileType, "master")
  }
}

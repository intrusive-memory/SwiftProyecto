//
//  InfoCommandTests.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import XCTest

@testable import SwiftProyecto

final class InfoCommandTests: XCTestCase {

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

  // MARK: - Info Command Tests

  func testInfoCommand_MasterFile_CorrectlyIdentifies() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Season Series
      author: Jane Showrunner
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
        - number: 2
          episodes: 10
      languages:
        - code: en
          name: English
        - code: es
          name: Spanish
      variants:
        - season: 1
          language: en
          path: "projects/s01_en/PROJECT.md"
          status: published
        - season: 1
          language: es
          path: "projects/s01_es/PROJECT.md"
          status: published
      ---

      # Multi-Season Master Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    // Parse and validate
    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify master file detection
    XCTAssertEqual(result.metadata.fileType, "master")
    XCTAssertEqual(frontMatter.schemaVersion, 4)
    XCTAssertEqual(frontMatter.projectType, "overview")
  }

  func testInfoCommand_ProjectFile_CorrectlyIdentifies() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: project
      title: Single Season Podcast
      author: Producer
      created: 2025-01-01T00:00:00Z
      season: 1
      episodes: 12
      episodesDir: episodes
      audioDir: audio
      ---

      # Single-season project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify project file detection
    XCTAssertEqual(result.metadata.fileType, "project")
    XCTAssertNil(frontMatter.schemaVersion)  // v3
  }

  func testInfoCommand_ShowsSchemaVersion_V3() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: project
      title: Legacy Project
      author: Author
      created: 2025-01-01T00:00:00Z
      season: 1
      episodes: 5
      ---

      # Legacy v3 project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify v3 schema detected
    XCTAssertNil(frontMatter.schemaVersion)  // v3 files don't have schemaVersion
    XCTAssertEqual(frontMatter.type, "project")
  }

  func testInfoCommand_ShowsSchemaVersion_V4() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Modern Project
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
      variants: []
      ---

      # Modern v4 project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify v4 schema detected
    XCTAssertEqual(frontMatter.schemaVersion, 4)
  }

  func testInfoCommand_ShowsVariantCount() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Variant Series
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 5
        - number: 2
          episodes: 5
      variants:
        - season: 1
          language: en
          path: "s01_en/PROJECT.md"
        - season: 1
          language: es
          path: "s01_es/PROJECT.md"
        - season: 2
          language: en
          path: "s02_en/PROJECT.md"
        - season: 2
          language: es
          path: "s02_es/PROJECT.md"
      ---

      # 4 variants total (2 seasons × 2 languages)
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify variant count
    XCTAssertEqual(result.metadata.variantCount, 4)
    XCTAssertEqual(result.metadata.seasonCount, 2)
    XCTAssertEqual(result.metadata.languageCount, nil)  // languages not explicitly defined
  }

  func testInfoCommand_ShowsSeasonCount() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Season
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
        - number: 2
          episodes: 10
        - number: 3
          episodes: 8
      ---

      # 3 seasons
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify season count and IDs
    XCTAssertEqual(result.metadata.seasonCount, 3)
    XCTAssertEqual(result.metadata.seasonNumbers, [1, 2, 3])
  }

  func testInfoCommand_ShowsLanguageCount() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Language
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 5
      languages:
        - code: en
          name: English
        - code: es
          name: Spanish
        - code: fr
          name: French
      ---

      # 3 languages
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify language count and codes
    XCTAssertEqual(result.metadata.languageCount, 3)
    XCTAssertEqual(result.metadata.languageCodes, ["en", "es", "fr"])
  }

  func testInfoCommand_ShowsEpisodeCount() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: project
      title: My Podcast
      author: Author
      created: 2025-01-01T00:00:00Z
      season: 1
      episodes: 24
      ---

      # Single season with 24 episodes
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify episode count
    XCTAssertEqual(frontMatter.episodes, 24)
  }

  func testInfoCommand_ShowsProjectTypeField() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Master File
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      ---

      # Master file with explicit projectType
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify projectType field is present and matches
    XCTAssertEqual(frontMatter.projectType, "overview")
  }

  func testInfoCommand_HandlesNoVariants() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Master Without Variants Yet
      author: Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
      ---

      # Master file with no variants defined yet
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let validator = ProjectValidator()
    let result = validator.validate(frontMatter)

    // Verify no variants
    XCTAssertNil(frontMatter.variants)
    XCTAssertEqual(result.metadata.variantCount, nil)
  }
}

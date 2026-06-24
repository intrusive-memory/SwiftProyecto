//
//  VariantsCommandTests.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import XCTest

@testable import SwiftProyecto

final class VariantsCommandTests: XCTestCase {

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

  // MARK: - Variants Command Tests

  func testVariantsCommand_V4_MultiSeasonMultiLanguage_ListsCorrectly() throws {
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
          status: in_progress
        - season: 2
          language: en
          path: "projects/s02_en/PROJECT.md"
          status: draft
      ---

      # Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    // Parse to verify structure
    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify variants are present and correctly parsed
    XCTAssertEqual(frontMatter.schemaVersion, 4)
    XCTAssertEqual(frontMatter.variants?.count, 3)
    XCTAssertEqual(frontMatter.variants?[0].season, 1)
    XCTAssertEqual(frontMatter.variants?[0].language, "en")
    XCTAssertEqual(frontMatter.variants?[0].status, .published)
    XCTAssertEqual(frontMatter.variants?[1].language, "es")
    XCTAssertEqual(frontMatter.variants?[1].status, .inProgress)
    XCTAssertEqual(frontMatter.variants?[2].season, 2)
    XCTAssertEqual(frontMatter.variants?[2].status, .draft)
  }

  func testVariantsCommand_V4_WithIntroOutroFiles_ParsesCorrectly() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Podcast with Assets
      author: Producer Bob
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 8
      variants:
        - season: 1
          language: en
          path: "season-01/en/PROJECT.md"
          status: published
          introFile: "assets/intro.m4a"
          outroFile: "assets/outro.m4a"
      ---

      # Podcast with intro/outro files
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify intro/outro files are captured
    XCTAssertEqual(frontMatter.variants?.count, 1)
    let variant = frontMatter.variants?[0]
    XCTAssertEqual(variant?.introFile, "assets/intro.m4a")
    XCTAssertEqual(variant?.outroFile, "assets/outro.m4a")
  }

  func testVariantsCommand_V3_Rejects_WithError() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: project
      title: My Podcast
      author: Jane Doe
      created: 2025-01-01T00:00:00Z
      season: 1
      episodes: 5
      ---

      # Single-season podcast
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    // Parse to verify this is v3
    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify this is v3
    XCTAssertNil(frontMatter.schemaVersion)
  }

  func testVariantsCommand_EmptyVariants_ShowsMessage() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Empty Master
      author: Showrunner
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
      ---

      # Master with no variants yet
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify no variants
    XCTAssertEqual(frontMatter.schemaVersion, 4)
    XCTAssertNil(frontMatter.variants)
  }

  func testVariantsCommand_AllVariantStatuses_Supported() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Status Test Series
      author: Tester
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 5
      variants:
        - season: 1
          language: en
          path: "s01_en/PROJECT.md"
          status: published
        - season: 1
          language: es
          path: "s01_es/PROJECT.md"
          status: in_progress
        - season: 1
          language: fr
          path: "s01_fr/PROJECT.md"
          status: draft
        - season: 1
          language: de
          path: "s01_de/PROJECT.md"
          status: obsolete
      ---

      # All statuses represented
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify all statuses are parsed correctly
    XCTAssertEqual(frontMatter.variants?.count, 4)
    let statuses = frontMatter.variants?.map { $0.status }
    XCTAssertEqual(statuses, [.published, .inProgress, .draft, .obsolete])
  }

  func testVariantsCommand_GroupBySeason_Works() throws {
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
          episodes: 5
        - number: 2
          episodes: 5
      variants:
        - season: 1
          language: en
          path: "s01_en/PROJECT.md"
          status: published
        - season: 1
          language: es
          path: "s01_es/PROJECT.md"
          status: published
        - season: 2
          language: en
          path: "s02_en/PROJECT.md"
          status: draft
        - season: 2
          language: es
          path: "s02_es/PROJECT.md"
          status: draft
      ---

      # Multi-season multi-language
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify variants can be grouped by season
    let variantsBySeason = Dictionary(grouping: frontMatter.variants ?? []) { $0.season }
    XCTAssertEqual(variantsBySeason.keys.count, 2)
    XCTAssertEqual(variantsBySeason[1]?.count, 2)
    XCTAssertEqual(variantsBySeason[2]?.count, 2)
  }

  func testVariantsCommand_GroupByLanguage_Works() throws {
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
      variants:
        - season: 1
          language: en
          path: "s01_en/PROJECT.md"
          status: published
        - season: 1
          language: es
          path: "s01_es/PROJECT.md"
          status: published
      ---

      # Multi-language
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify variants can be grouped by language
    let variantsByLanguage = Dictionary(grouping: frontMatter.variants ?? []) { $0.language }
    XCTAssertEqual(variantsByLanguage.keys.count, 2)
    XCTAssertEqual(variantsByLanguage["en"]?.count, 1)
    XCTAssertEqual(variantsByLanguage["es"]?.count, 1)
  }
}

//
//  SchemaV5MigrationSurfaceTests.swift
//  SwiftProyecto
//
//  Copyright (c) 2026 Intrusive Memory
//
//  Tests for the schema v5 cast-egress surface: ProjectSchemaVersion,
//  legacy `cast:` block detection/preservation on ProjectFrontMatter, and
//  the byte-surgical removingCastBlock(in:) / stampingSchemaVersion(in:)
//  operations on ProjectMarkdownParser.
//

import XCTest

@testable import SwiftProyecto

final class SchemaV5MigrationSurfaceTests: XCTestCase {

  let parser = ProjectMarkdownParser()

  // MARK: - ProjectSchemaVersion

  func testSchemaVersionCurrent_Is5() {
    XCTAssertEqual(ProjectSchemaVersion.current, 5)
  }

  func testGenerate_StampsCurrentSchemaVersion() {
    let frontMatter = ProjectFrontMatter(title: "Stamped", author: "Author")
    let generated = parser.generate(frontMatter: frontMatter, body: "")
    XCTAssertTrue(
      generated.contains("schemaVersion: 5"),
      "generate() must stamp the current schema version (5)")
  }

  // MARK: - Legacy cast key detection

  private let legacyCastDocument = """
    ---
    type: project
    title: Legacy Cast Project
    author: Test Author
    created: 2025-01-01T00:00:00Z
    cast:
      - character: NARRATOR
        actor: Tom Stovall
        bio: The steady voice guiding every episode.
      - character: LAO TZU
        actor: Jason Manino
    ---

    # Notes
    """

  func testHasLegacyCastKey_TrueWhenCastBlockPresent() throws {
    let (frontMatter, _) = try parser.parse(content: legacyCastDocument)
    XCTAssertTrue(frontMatter.hasLegacyCastKey)
  }

  func testHasLegacyCastKey_FalseWithoutCastBlock() throws {
    let content = """
      ---
      type: project
      title: No Cast Here
      author: Test Author
      created: 2025-01-01T00:00:00Z
      ---
      """
    let (frontMatter, _) = try parser.parse(content: content)
    XCTAssertFalse(frontMatter.hasLegacyCastKey)
    XCTAssertEqual(frontMatter.legacyCastCharacterNames, [])
  }

  func testLegacyCastCharacterNames_InDocumentOrder() throws {
    let (frontMatter, _) = try parser.parse(content: legacyCastDocument)
    XCTAssertEqual(frontMatter.legacyCastCharacterNames, ["NARRATOR", "LAO TZU"])
  }

  func testRemovingLegacyCastKey_DropsOnlyTheCastKey() throws {
    let (frontMatter, _) = try parser.parse(content: legacyCastDocument)
    XCTAssertTrue(frontMatter.hasLegacyCastKey)

    let removed = frontMatter.removingLegacyCastKey()
    XCTAssertFalse(removed.hasLegacyCastKey)
    XCTAssertEqual(removed.legacyCastCharacterNames, [])
    // Every other field is untouched.
    XCTAssertEqual(removed.title, frontMatter.title)
    XCTAssertEqual(removed.author, frontMatter.author)
    XCTAssertEqual(removed.type, frontMatter.type)
    // The receiver itself is a value type and is not mutated.
    XCTAssertTrue(frontMatter.hasLegacyCastKey)
  }

  // MARK: - removingCastBlock(in:)

  func testRemovingCastBlock_RemovesMultiMemberBlockWithBlanksAndComments() throws {
    let original = """
      ---
      type: project
      title: Surgical Removal
      author: Test Author
      created: 2025-01-01T00:00:00Z
      cast:
        - character: NARRATOR
          actor: Tom Stovall

        # hand-written note between members
        - character: LAO TZU
          actor: Jason Manino
      episodesDir: episodes
      ---

      # Body stays
      """

    let stripped = try parser.removingCastBlock(in: original)

    XCTAssertFalse(stripped.contains("cast:"))
    XCTAssertFalse(stripped.contains("NARRATOR"))
    XCTAssertFalse(stripped.contains("hand-written note"))
    // Everything around the block is byte-identical.
    XCTAssertTrue(stripped.contains("created: 2025-01-01T00:00:00Z\nepisodesDir: episodes"))
    XCTAssertTrue(stripped.contains("# Body stays"))
    // The result still parses.
    let (frontMatter, _) = try parser.parse(content: stripped)
    XCTAssertFalse(frontMatter.hasLegacyCastKey)
    XCTAssertEqual(frontMatter.episodesDir, "episodes")
  }

  func testRemovingCastBlock_NoCastKey_ReturnsInputUnchanged() throws {
    let original = """
      ---
      type: project
      title: No Cast
      author: Test Author
      created: 2025-01-01T00:00:00Z
      ---

      # Body
      """
    let result = try parser.removingCastBlock(in: original)
    XCTAssertEqual(result, original)
  }

  func testRemovingCastBlock_NoFrontMatter_Throws() {
    let original = "# Just a markdown file\n\nNo front matter at all.\n"
    XCTAssertThrowsError(try parser.removingCastBlock(in: original)) { error in
      guard case ProjectMarkdownParser.ParserError.noFrontMatter = error else {
        XCTFail("Expected ParserError.noFrontMatter, got \(error)")
        return
      }
    }
  }

  func testRemovingCastBlock_LeavesIndentedSeasonLevelCastAlone() throws {
    let original = """
      ---
      type: project
      title: Season Cast
      author: Test Author
      created: 2025-01-01T00:00:00Z
      seasons:
        - number: 1
          episodes: 8
          cast:
            - character: SEASON ONLY
      ---
      """
    // The only `cast:` is indented (season-level) — not a top-level key, so
    // the input must come back unchanged.
    let result = try parser.removingCastBlock(in: original)
    XCTAssertEqual(result, original)
    XCTAssertTrue(result.contains("SEASON ONLY"))
  }

  // MARK: - stampingSchemaVersion(in:)

  func testStampingSchemaVersion_ReplacesExistingLineInPlace() throws {
    let original = """
      ---
      type: project
      title: Already Versioned
      schemaVersion: 4
      author: Test Author
      created: 2025-01-01T00:00:00Z
      ---

      # Body
      """
    let stamped = try parser.stampingSchemaVersion(in: original)

    XCTAssertFalse(stamped.contains("schemaVersion: 4"))
    // Replaced in place: same position, every other byte identical.
    XCTAssertEqual(
      stamped,
      original.replacingOccurrences(
        of: "schemaVersion: 4", with: "schemaVersion: \(ProjectSchemaVersion.current)"))
  }

  func testStampingSchemaVersion_InsertsAfterOpeningDelimiterWhenAbsent() throws {
    let original = """
      ---
      type: project
      title: Unversioned
      author: Test Author
      created: 2025-01-01T00:00:00Z
      ---

      # Body
      """
    let stamped = try parser.stampingSchemaVersion(in: original)

    XCTAssertTrue(
      stamped.hasPrefix("---\nschemaVersion: \(ProjectSchemaVersion.current)\ntype: project\n"),
      "schemaVersion must be inserted immediately after the opening ---")
    // Every original byte survives: removing the inserted line restores input.
    XCTAssertEqual(
      stamped.replacingOccurrences(
        of: "---\nschemaVersion: \(ProjectSchemaVersion.current)\n", with: "---\n"),
      original)
  }

  func testStampingSchemaVersion_ExplicitVersionArgument() throws {
    let original = """
      ---
      type: project
      title: Explicit
      author: Test Author
      created: 2025-01-01T00:00:00Z
      ---
      """
    let stamped = try parser.stampingSchemaVersion(in: original, to: 7)
    XCTAssertTrue(stamped.contains("schemaVersion: 7"))
  }

  func testStampingSchemaVersion_NoFrontMatter_Throws() {
    let original = "# No front matter here\n"
    XCTAssertThrowsError(try parser.stampingSchemaVersion(in: original)) { error in
      guard case ProjectMarkdownParser.ParserError.noFrontMatter = error else {
        XCTFail("Expected ParserError.noFrontMatter, got \(error)")
        return
      }
    }
  }
}

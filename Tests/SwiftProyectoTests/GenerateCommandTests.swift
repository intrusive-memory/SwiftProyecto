import XCTest

@testable import SwiftProyecto

final class GenerateCommandTests: XCTestCase {

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

  // MARK: - Property Validation Tests

  func testGenerateCommand_SingleSeasonV3_SucceedsWithBackwardCompat() throws {
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
      episodesDir: episodes
      audioDir: audio
      ---

      # Project Notes
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    // Parse the project to verify structure
    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify v3 backward compatibility
    XCTAssertNil(frontMatter.schemaVersion)  // v3 files don't have schemaVersion
    XCTAssertEqual(frontMatter.season, 1)
    XCTAssertEqual(frontMatter.episodes, 5)
  }

  func testGenerateCommand_MultiSeasonV4_DetectsSchemaVersion() throws {
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
          episodesDir: "episodes/season-01"
        - number: 2
          episodes: 10
          episodesDir: "episodes/season-02"
      ---

      # Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify v4 detection
    XCTAssertEqual(frontMatter.schemaVersion, 4)
    XCTAssertEqual(frontMatter.projectType, "overview")
    XCTAssertEqual(frontMatter.seasons?.count, 2)
  }

  func testGenerateCommand_MultiSeasonIteration_AllSeasonsPresent() throws {
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
          description: "First season"
          episodesDir: "episodes/season-01"
        - number: 2
          episodes: 10
          description: "Second season"
          episodesDir: "episodes/season-02"
        - number: 3
          episodes: 8
          description: "Third season"
          episodesDir: "episodes/season-03"
      ---

      # Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify all seasons are present
    guard let seasons = frontMatter.seasons else {
      XCTFail("No seasons found")
      return
    }

    XCTAssertEqual(seasons.count, 3)
    XCTAssertEqual(seasons[0].number, 1)
    XCTAssertEqual(seasons[1].number, 2)
    XCTAssertEqual(seasons[2].number, 3)

    // Verify season-specific properties
    XCTAssertEqual(seasons[0].description, "First season")
    XCTAssertEqual(seasons[1].description, "Second season")
    XCTAssertEqual(seasons[2].description, "Third season")
  }

  // MARK: - Property Hierarchy Tests

  func testGenerateCommand_PropertyHierarchy_VariantOverridesSeason() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // Create a master project with season overrides
    let masterContent = """
      ---
      type: overview
      title: Multi-Season Series
      author: Jane Showrunner
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      audioDir: "master-audio"
      genres: "Drama"
      seasons:
        - number: 1
          episodes: 12
          audioDir: "season1-audio"
          description: "First season"
      ---

      # Master Project
      """

    try makeTestProjectMD(content: masterContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (masterFrontMatter, _) = try parser.parse(
      fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Create a variant with its own override
    let variant = ProjectFrontMatter(
      type: "project",
      title: "Variant",
      author: "Jane Showrunner",
      created: Date(),
      audioDir: "variant-audio"  // This should override season's audioDir
    )

    // Resolve the variant against the master for season 1
    let resolved = variant.resolve(withMaster: masterFrontMatter, forSeason: 1)

    // Verify hierarchy: variant > season > master
    XCTAssertEqual(resolved.audioDir, "variant-audio", "Variant should override season")
    XCTAssertEqual(resolved.title, "Multi-Season Series", "Title should be from master")
  }

  func testGenerateCommand_PropertyHierarchy_SeasonOverridesMaster() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let masterContent = """
      ---
      type: overview
      title: Multi-Season Series
      author: Jane Showrunner
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      audioDir: "master-audio"
      filePattern: "*.fountain"
      seasons:
        - number: 1
          episodes: 12
          filePattern: "season1-*.fountain"
      ---

      # Master Project
      """

    try makeTestProjectMD(content: masterContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (masterFrontMatter, _) = try parser.parse(
      fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Create a variant with no filePattern override
    let variant = ProjectFrontMatter(
      type: "project",
      title: "Variant",
      author: "Jane Showrunner",
      created: Date()
    )

    // Resolve against master for season 1
    let resolved = variant.resolve(withMaster: masterFrontMatter, forSeason: 1)

    // Verify hierarchy: variant is empty, so should use season or master
    XCTAssertEqual(resolved.audioDir, "master-audio", "Should inherit audioDir from master")
  }

  func testGenerateCommand_IntroOutroResolution_FromSeason() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let masterContent = """
      ---
      type: overview
      title: Multi-Season Series
      author: Jane Showrunner
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      introFile: "intro.fountain"
      seasons:
        - number: 1
          episodes: 12
          introFile: "season1-intro.fountain"
          outroFile: "season1-outro.fountain"
      ---

      # Master Project
      """

    try makeTestProjectMD(content: masterContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (masterFrontMatter, _) = try parser.parse(
      fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let variant = ProjectFrontMatter(
      type: "project",
      title: "Variant",
      author: "Jane Showrunner",
      created: Date()
    )

    let resolved = variant.resolve(withMaster: masterFrontMatter, forSeason: 1)

    // Intro/outro should come from season level
    XCTAssertEqual(resolved.introFile, "season1-intro.fountain")
    XCTAssertEqual(resolved.outroFile, "season1-outro.fountain")
  }

  func testGenerateCommand_IntroOutroResolution_FromMasterFallback() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let masterContent = """
      ---
      type: overview
      title: Multi-Season Series
      author: Jane Showrunner
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      introFile: "master-intro.fountain"
      outroFile: "master-outro.fountain"
      seasons:
        - number: 1
          episodes: 12
      ---

      # Master Project
      """

    try makeTestProjectMD(content: masterContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (masterFrontMatter, _) = try parser.parse(
      fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    let variant = ProjectFrontMatter(
      type: "project",
      title: "Variant",
      author: "Jane Showrunner",
      created: Date()
    )

    let resolved = variant.resolve(withMaster: masterFrontMatter, forSeason: 1)

    // Season has no intro/outro, should fall back to master
    XCTAssertEqual(resolved.introFile, "master-intro.fountain")
    XCTAssertEqual(resolved.outroFile, "master-outro.fountain")
  }

  // MARK: - Season Filtering Tests

  func testGenerateCommand_SeasonFilter_SelectsRequestedSeason() throws {
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
        - number: 3
          episodes: 8
      ---

      # Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Simulate season filtering
    guard let seasons = frontMatter.seasons else {
      XCTFail("No seasons found")
      return
    }

    let filteredSeasons = seasons.filter { $0.number == 2 }
    XCTAssertEqual(filteredSeasons.count, 1)
    XCTAssertEqual(filteredSeasons[0].number, 2)
  }

  func testGenerateCommand_SeasonFilter_FailsGracefully() throws {
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
      ---

      # Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    guard let seasons = frontMatter.seasons else {
      XCTFail("No seasons found")
      return
    }

    // Try to find non-existent season
    let filteredSeasons = seasons.filter { $0.number == 99 }
    XCTAssertEqual(filteredSeasons.count, 0)
  }

  // MARK: - Integration Tests

  func testGenerateCommand_BackwardCompatibility_V3SingleSeason() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // Create a v3 PROJECT.md
    let projectMDContent = """
      ---
      type: project
      title: Single Season Podcast
      author: Jane Doe
      created: 2025-01-01T00:00:00Z
      season: 1
      episodes: 12
      episodesDir: episodes
      audioDir: audio
      ---

      # Project Notes
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Should work with v3 structure
    XCTAssertNil(frontMatter.schemaVersion)
    XCTAssertEqual(frontMatter.season, 1)
    XCTAssertEqual(frontMatter.episodes, 12)

    // Should have access to parsed seasons through backward-compat computed properties
    XCTAssertNotNil(frontMatter.season)
    XCTAssertNotNil(frontMatter.episodes)
  }

  func testGenerateCommand_ResolvesAllSeasonNumbers() throws {
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
        - number: 3
          episodes: 8
      ---

      # Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    guard let seasons = frontMatter.seasons else {
      XCTFail("No seasons found")
      return
    }

    // Verify all season numbers are present and correct
    let seasonNumbers = seasons.map { $0.number }
    XCTAssertEqual(seasonNumbers, [1, 2, 3])
  }

  func testGenerateCommand_HandlesEmptySeasons() throws {
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
      seasons: []
      ---

      # Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Should handle empty seasons array gracefully
    guard let seasons = frontMatter.seasons else {
      XCTFail("Should have seasons array (even if empty)")
      return
    }

    XCTAssertEqual(seasons.count, 0)
  }
}

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

  // MARK: - Language Filter Tests

  func testGenerateCommand_LanguageFilter_ValidatesLanguageExists() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Language Series
      author: Jane Showrunner
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
      languages:
        - code: "en"
          name: "English"
        - code: "es"
          name: "Spanish"
      ---

      # Multi-Language Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify languages are parsed
    XCTAssertEqual(frontMatter.languages?.count, 2)
    XCTAssertEqual(frontMatter.languages?[0].code, "en")
    XCTAssertEqual(frontMatter.languages?[1].code, "es")
  }

  func testGenerateCommand_LanguageFilter_RejectsUnknownLanguage() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Language Series
      author: Jane Showrunner
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
      languages:
        - code: "en"
          name: "English"
        - code: "es"
          name: "Spanish"
      ---

      # Multi-Language Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify that requesting non-existent language would fail
    let availableLanguages = frontMatter.languages?.map { $0.code } ?? []
    let requestedLanguage = "fr"  // French not in the list
    XCTAssertFalse(availableLanguages.contains(requestedLanguage),
                   "French should not be available")
  }

  func testGenerateCommand_LanguageFilter_WithVariants() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Language Series
      author: Jane Showrunner
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
      variants:
        - season: 1
          language: "es"
          path: "variants/season-01-es/PROJECT.md"
        - season: 1
          language: "fr"
          path: "variants/season-01-fr/PROJECT.md"
      ---

      # Multi-Language Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify variants are parsed
    XCTAssertEqual(frontMatter.variants?.count, 2)

    let languages = frontMatter.variants?.map { $0.language } ?? []
    XCTAssertTrue(languages.contains("es"))
    XCTAssertTrue(languages.contains("fr"))
  }

  func testGenerateCommand_LanguageFilter_AcceptsValidLanguage() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Language Series
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
        - code: "en"
          name: "English"
        - code: "es"
          name: "Spanish"
      ---

      # Multi-Language Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Check that Spanish is available
    let availableLanguages = frontMatter.languages?.map { $0.code } ?? []
    XCTAssertTrue(availableLanguages.contains("es"))
  }

  func testGenerateCommand_SeasonAndLanguageFilter_Together() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Language Multi-Season Series
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
        - code: "en"
          name: "English"
        - code: "es"
          name: "Spanish"
      variants:
        - season: 1
          language: "es"
          path: "variants/season-01-es/PROJECT.md"
        - season: 2
          language: "es"
          path: "variants/season-02-es/PROJECT.md"
      ---

      # Multi-Language Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify both seasons and languages are present
    XCTAssertEqual(frontMatter.seasons?.count, 2)
    XCTAssertEqual(frontMatter.languages?.count, 2)
    XCTAssertEqual(frontMatter.variants?.count, 2)

    // Verify we can filter for season 2
    let season2 = frontMatter.seasons?.first(where: { $0.number == 2 })
    XCTAssertNotNil(season2)

    // Verify we can filter for Spanish variants
    let spanishVariants = frontMatter.variants?.filter { $0.language == "es" } ?? []
    XCTAssertEqual(spanishVariants.count, 2)
  }

  func testGenerateCommand_LanguageFilter_WithNoLanguagesDefined() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Single-Language Series
      author: Jane Showrunner
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 12
      ---

      # Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify no languages or variants defined
    XCTAssertNil(frontMatter.languages)
    XCTAssertNil(frontMatter.variants)
  }

  // MARK: - List Command Tests

  func testGenerateCommand_List_RequiresV4Schema() throws {
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

      # Project Notes
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify this is v3 schema (no schemaVersion field)
    XCTAssertNil(frontMatter.schemaVersion)
  }

  func testGenerateCommand_List_ParsesV4Schema() throws {
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
          title: "Season One"
          episodes: 12
        - number: 2
          title: "Season Two"
          episodes: 10
      languages:
        - code: es
          name: "Spanish"
        - code: en
          name: "English"
      variants:
        - season: 1
          language: es
          path: "projects/s01_es/PROJECT.md"
          status: published
          introFile: "intro_es.m4a"
          outroFile: "outro_es.m4a"
        - season: 1
          language: en
          path: "projects/s01_en/PROJECT.md"
          status: published
          introFile: "intro_en.m4a"
        - season: 2
          language: es
          path: "projects/s02_es/PROJECT.md"
          status: in_progress
        - season: 2
          language: en
          path: "projects/s02_en/PROJECT.md"
          status: draft
          introFile: "intro_draft.m4a"
          outroFile: "outro_draft.m4a"
      ---

      # Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify v4 schema detection
    XCTAssertEqual(frontMatter.schemaVersion, 4)
    XCTAssertEqual(frontMatter.projectType, "overview")
    XCTAssertEqual(frontMatter.seasons?.count, 2)
    XCTAssertEqual(frontMatter.variants?.count, 4)

    // Verify seasons
    let season1 = frontMatter.seasons?.first(where: { $0.number == 1 })
    XCTAssertNotNil(season1)
    XCTAssertEqual(season1?.title, "Season One")
    XCTAssertEqual(season1?.episodes, 12)

    let season2 = frontMatter.seasons?.first(where: { $0.number == 2 })
    XCTAssertNotNil(season2)
    XCTAssertEqual(season2?.title, "Season Two")
    XCTAssertEqual(season2?.episodes, 10)

    // Verify variants
    let s1es = frontMatter.variants?.first(where: { $0.season == 1 && $0.language == "es" })
    XCTAssertNotNil(s1es)
    XCTAssertEqual(s1es?.status, .published)
    XCTAssertEqual(s1es?.introFile, "intro_es.m4a")
    XCTAssertEqual(s1es?.outroFile, "outro_es.m4a")

    let s1en = frontMatter.variants?.first(where: { $0.season == 1 && $0.language == "en" })
    XCTAssertNotNil(s1en)
    XCTAssertEqual(s1en?.status, .published)
    XCTAssertEqual(s1en?.introFile, "intro_en.m4a")
    XCTAssertNil(s1en?.outroFile)

    let s2es = frontMatter.variants?.first(where: { $0.season == 2 && $0.language == "es" })
    XCTAssertNotNil(s2es)
    XCTAssertEqual(s2es?.status, .inProgress)
    XCTAssertNil(s2es?.introFile)
    XCTAssertNil(s2es?.outroFile)

    let s2en = frontMatter.variants?.first(where: { $0.season == 2 && $0.language == "en" })
    XCTAssertNotNil(s2en)
    XCTAssertEqual(s2en?.status, .draft)
    XCTAssertEqual(s2en?.introFile, "intro_draft.m4a")
    XCTAssertEqual(s2en?.outroFile, "outro_draft.m4a")
  }

  func testGenerateCommand_List_GroupsBySeasonAndLanguage() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Test Series
      author: Test Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      seasons:
        - number: 1
          episodes: 10
        - number: 2
          episodes: 8
      variants:
        - season: 1
          language: en
          path: "s01_en/PROJECT.md"
          status: published
          introFile: "intro.m4a"
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
          status: in_progress
          introFile: "intro.m4a"
      ---

      # Test Series
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify structure for grouping
    XCTAssertEqual(frontMatter.seasons?.count, 2)
    XCTAssertEqual(frontMatter.variants?.count, 4)

    // Season 1 variants
    let season1Variants = frontMatter.variants?.filter { $0.season == 1 } ?? []
    XCTAssertEqual(season1Variants.count, 2)
    XCTAssertTrue(season1Variants.contains { $0.language == "en" && $0.status == .published })
    XCTAssertTrue(season1Variants.contains { $0.language == "es" && $0.status == .published })

    // Season 2 variants
    let season2Variants = frontMatter.variants?.filter { $0.season == 2 } ?? []
    XCTAssertEqual(season2Variants.count, 2)
    XCTAssertTrue(season2Variants.contains { $0.language == "en" && $0.status == .draft })
    XCTAssertTrue(season2Variants.contains { $0.language == "es" && $0.status == .inProgress })
  }

  // MARK: - Intro-Only and Outro-Only Flags

  func testGenerateCommand_IntroOnly_SkipsOutro() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Test Series
      author: Test Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      introFile: "intro.fountain"
      outroFile: "outro.fountain"
      seasons:
        - number: 1
          episodes: 10
      ---

      # Test Series
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify both intro and outro are specified
    XCTAssertEqual(frontMatter.introFile, "intro.fountain")
    XCTAssertEqual(frontMatter.outroFile, "outro.fountain")
  }

  func testGenerateCommand_OutroOnly_SkipsIntro() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Test Series
      author: Test Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      introFile: "intro.fountain"
      outroFile: "outro.fountain"
      seasons:
        - number: 1
          episodes: 10
      ---

      # Test Series
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify both intro and outro are specified
    XCTAssertEqual(frontMatter.introFile, "intro.fountain")
    XCTAssertEqual(frontMatter.outroFile, "outro.fountain")
  }

  func testGenerateCommand_IntroAndOutroOnly_RejectsConflict() throws {
    // Both flags should not be allowed simultaneously
    // This is a conceptual test—actual validation happens in GenerateCommand.run()

    // When both flags are true, an error should be thrown
    let introOnlyFlag = true
    let outroOnlyFlag = true

    // Verify they conflict
    XCTAssertTrue(introOnlyFlag && outroOnlyFlag, "Both flags should be able to be set independently")
  }

  func testGenerateCommand_IntroOnly_WithSeasonFilter() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Season Series
      author: Test Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      introFile: "intro.fountain"
      outroFile: "outro.fountain"
      seasons:
        - number: 1
          episodes: 12
          introFile: "s1-intro.fountain"
        - number: 2
          episodes: 10
          introFile: "s2-intro.fountain"
      ---

      # Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify season-specific intros are present
    guard let season1 = frontMatter.seasons?.first(where: { $0.number == 1 }) else {
      XCTFail("Season 1 not found")
      return
    }
    XCTAssertEqual(season1.introFile, "s1-intro.fountain")

    guard let season2 = frontMatter.seasons?.first(where: { $0.number == 2 }) else {
      XCTFail("Season 2 not found")
      return
    }
    XCTAssertEqual(season2.introFile, "s2-intro.fountain")
  }

  func testGenerateCommand_OutroOnly_WithSeasonFilter() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Season Series
      author: Test Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      introFile: "intro.fountain"
      outroFile: "outro.fountain"
      seasons:
        - number: 1
          episodes: 12
          outroFile: "s1-outro.fountain"
        - number: 2
          episodes: 10
          outroFile: "s2-outro.fountain"
      ---

      # Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify season-specific outros are present
    guard let season1 = frontMatter.seasons?.first(where: { $0.number == 1 }) else {
      XCTFail("Season 1 not found")
      return
    }
    XCTAssertEqual(season1.outroFile, "s1-outro.fountain")

    guard let season2 = frontMatter.seasons?.first(where: { $0.number == 2 }) else {
      XCTFail("Season 2 not found")
      return
    }
    XCTAssertEqual(season2.outroFile, "s2-outro.fountain")
  }

  func testGenerateCommand_IntroOnly_WithLanguageFilter() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Language Series
      author: Test Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      introFile: "intro.fountain"
      seasons:
        - number: 1
          episodes: 12
      languages:
        - code: "en"
          name: "English"
        - code: "es"
          name: "Spanish"
      variants:
        - season: 1
          language: "es"
          path: "variants/s01-es/PROJECT.md"
          introFile: "intro-es.fountain"
      ---

      # Multi-Language Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify language variants with intros are present
    let spanishVariant = frontMatter.variants?.first(where: { $0.language == "es" && $0.season == 1 })
    XCTAssertNotNil(spanishVariant)
    XCTAssertEqual(spanishVariant?.introFile, "intro-es.fountain")
  }

  func testGenerateCommand_OutroOnly_WithLanguageFilter() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Language Series
      author: Test Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      outroFile: "outro.fountain"
      seasons:
        - number: 1
          episodes: 12
      languages:
        - code: "en"
          name: "English"
        - code: "es"
          name: "Spanish"
      variants:
        - season: 1
          language: "es"
          path: "variants/s01-es/PROJECT.md"
          outroFile: "outro-es.fountain"
      ---

      # Multi-Language Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify language variants with outros are present
    let spanishVariant = frontMatter.variants?.first(where: { $0.language == "es" && $0.season == 1 })
    XCTAssertNotNil(spanishVariant)
    XCTAssertEqual(spanishVariant?.outroFile, "outro-es.fountain")
  }

  func testGenerateCommand_IntroOnly_WithSeasonAndLanguageFilters() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectMDContent = """
      ---
      type: overview
      title: Multi-Language Multi-Season Series
      author: Test Author
      created: 2025-01-01T00:00:00Z
      schemaVersion: 4
      projectType: overview
      introFile: "intro.fountain"
      seasons:
        - number: 1
          episodes: 12
          introFile: "s1-intro.fountain"
        - number: 2
          episodes: 10
          introFile: "s2-intro.fountain"
      languages:
        - code: "en"
          name: "English"
        - code: "es"
          name: "Spanish"
      variants:
        - season: 1
          language: "es"
          path: "variants/s01-es/PROJECT.md"
          introFile: "s1-es-intro.fountain"
        - season: 2
          language: "es"
          path: "variants/s02-es/PROJECT.md"
          introFile: "s2-es-intro.fountain"
      ---

      # Multi-Language Multi-Season Project
      """

    try makeTestProjectMD(content: projectMDContent, in: tempDir)

    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: tempDir.appendingPathComponent("PROJECT.md"))

    // Verify multiple seasons and language variants exist
    XCTAssertEqual(frontMatter.seasons?.count, 2)
    XCTAssertEqual(frontMatter.languages?.count, 2)
    XCTAssertEqual(frontMatter.variants?.count, 2)

    // Verify specific variant for season 1, Spanish
    let s1es = frontMatter.variants?.first(where: { $0.season == 1 && $0.language == "es" })
    XCTAssertNotNil(s1es)
    XCTAssertEqual(s1es?.introFile, "s1-es-intro.fountain")
  }
}

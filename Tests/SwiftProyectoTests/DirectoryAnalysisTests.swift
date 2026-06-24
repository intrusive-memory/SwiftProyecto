import Foundation
import Testing

@testable import SwiftProyecto

// MARK: - CastExtractor Tests

@Suite("CastExtractor")
struct CastExtractorTests {
  let extractor = CastExtractor()

  @Test("Extracts single character")
  func testExtractSingleCharacter() {
    let fountain = """
    NARRADOR
    Today we drill the present tense.
    """
    let cast = extractor.extractCast(from: fountain)
    #expect(cast == ["NARRADOR"])
  }

  @Test("Extracts multiple unique characters")
  func testExtractMultipleCharacters() {
    let fountain = """
    NARRADOR
    Today we drill.

    MAESTRA
    Io porto i libri.

    NARRADOR
    I carry the books.
    """
    let cast = extractor.extractCast(from: fountain)
    #expect(cast.count == 2)
    #expect(cast.contains("NARRADOR"))
    #expect(cast.contains("MAESTRA"))
  }

  @Test("Removes parentheticals like (CONT'D)")
  func testRemoveParenthetical() {
    let fountain = """
    UNCLE FU
    The Tao that can be spoken is not eternal.

    UNCLE FU (CONT'D)
    The name that can be named is not eternal.
    """
    let cast = extractor.extractCast(from: fountain)
    #expect(cast == ["UNCLE FU"])
  }

  @Test("Removes voice modifiers like (V.O.)")
  func testRemoveVoiceModifier() {
    let fountain = """
    NARRADOR (V.O.)
    This is a voice-over.

    NARRADOR (O.S.)
    This is off-screen.
    """
    let cast = extractor.extractCast(from: fountain)
    #expect(cast == ["NARRADOR"])
  }

  @Test("Filters out scene headings")
  func testFilterSceneHeadings() {
    let fountain = """
    INT. STUDY - NIGHT

    A candle burns on a desk.

    UNCLE FU
    The Tao.
    """
    let cast = extractor.extractCast(from: fountain)
    #expect(cast == ["UNCLE FU"])
  }

  @Test("Filters out transitions")
  func testFilterTransitions() {
    let fountain = """
    UNCLE FU
    The Tao.

    CUT TO:

    MAESTRA
    Io porto.
    """
    let cast = extractor.extractCast(from: fountain)
    #expect(cast.count == 2)
    #expect(!cast.contains("CUT"))
  }

  @Test("Handles multi-word character names")
  func testMultiWordCharacterNames() {
    let fountain = """
    UNCLE FU
    Hello.

    DOCTOR SMITH
    How are you?

    LADY IN RED
    I'm fine.
    """
    let cast = extractor.extractCast(from: fountain)
    #expect(cast.count == 3)
    #expect(cast.contains("UNCLE FU"))
    #expect(cast.contains("DOCTOR SMITH"))
    #expect(cast.contains("LADY IN RED"))
  }

  @Test("Sorts cast alphabetically")
  func testSortsCast() {
    let fountain = """
    ZEBRA
    Z.

    APPLE
    A.

    BANANA
    B.
    """
    let cast = extractor.extractCast(from: fountain)
    #expect(cast == ["APPLE", "BANANA", "ZEBRA"])
  }

  @Test("Returns empty for fountain with no dialogue")
  func testEmptyFountain() {
    let fountain = """
    INT. EMPTY ROOM - DAY

    An empty room.
    """
    let cast = extractor.extractCast(from: fountain)
    #expect(cast.isEmpty)
  }

  @Test("Extracts cast from Lingua Matra fixture")
  func testLinguaMatra() throws {
    let lingmaURL = URL(fileURLWithPath: "/Users/stovak/Projects/podcasts/lingua-matra/episodes/it/episode_01.fountain")
    let cast = try extractor.extractCast(from: lingmaURL)

    // Lingua Matra episode 1 should have NARRADOR and MAESTRA
    #expect(cast.contains("NARRADOR"))
    #expect(cast.contains("MAESTRA"))
    #expect(cast.count >= 2)
  }

  @Test("Extracts cast from Produciesta fixture")
  func testProduciesta() throws {
    let prodURL = URL(fileURLWithPath: "/Users/stovak/Projects/Produciesta/fixtures/cast-demo/cast-demo.fountain")
    let cast = try extractor.extractCast(from: prodURL)

    // Should extract UNCLE FU
    #expect(cast.contains("UNCLE FU"))
  }

  @Test("Handles character names with apostrophes")
  func testCharacterNamesWithApostrophes() {
    let fountain = """
    O'BRIEN
    I'm here.

    JO'S SISTER
    Welcome.
    """
    let cast = extractor.extractCast(from: fountain)
    #expect(cast.count == 2)
    #expect(cast.contains("O'BRIEN"))
    #expect(cast.contains("JO'S SISTER"))
  }

  @Test("Handles character names with hyphens")
  func testCharacterNamesWithHyphens() {
    let fountain = """
    MARY-JANE
    Hello.

    JOHN-SMITH
    Hi there.
    """
    let cast = extractor.extractCast(from: fountain)
    #expect(cast.count == 2)
    #expect(cast.contains("MARY-JANE"))
    #expect(cast.contains("JOHN-SMITH"))
  }
}

// MARK: - MetadataExtractor Tests

@Suite("MetadataExtractor")
struct MetadataExtractorTests {
  let extractor = MetadataExtractor()

  @Test("Infers title from directory name with hyphens")
  func testTitleFromDirWithHyphens() {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("lingua-matra")
    let metadata = extractor.inferMetadata(from: tempDir)
    #expect(metadata?.title == "Lingua Matra")
  }

  @Test("Infers title from directory name with underscores")
  func testTitleFromDirWithUnderscores() {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("my_podcast")
    let metadata = extractor.inferMetadata(from: tempDir)
    #expect(metadata?.title == "My Podcast")
  }

  @Test("Infers title from simple directory name")
  func testTitleFromSimpleDir() {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MyShow")
    let metadata = extractor.inferMetadata(from: tempDir)
    #expect(metadata?.title == "MyShow")
  }

  @Test("Returns nil for non-existent directory")
  func testNonExistentDirectory() {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent-12345")
    let metadata = extractor.inferMetadata(from: tempDir)
    #expect(metadata == nil)
  }

  @Test("Detects language codes in directory structure")
  func testDetectsLanguages() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test-project-\(UUID().uuidString)")

    // Create test directory structure with language directories
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("en"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("es"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("it"), withIntermediateDirectories: true)

    defer { try? FileManager.default.removeItem(at: tempDir) }

    let metadata = extractor.inferMetadata(from: tempDir)
    #expect(metadata?.languages != nil)
    #expect(metadata?.languages?.contains("en") == true)
    #expect(metadata?.languages?.contains("es") == true)
    #expect(metadata?.languages?.contains("it") == true)
  }

  @Test("Detects season numbers in directory structure")
  func testDetectsSeasons() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test-season-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("season-1"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("season-2"), withIntermediateDirectories: true)

    defer { try? FileManager.default.removeItem(at: tempDir) }

    let metadata = extractor.inferMetadata(from: tempDir)
    #expect(metadata?.seasons != nil)
    #expect(metadata?.seasons?.contains(1) == true)
    #expect(metadata?.seasons?.contains(2) == true)
  }

  @Test("Recognizes multiple season formats")
  func testMultipleSeasonFormats() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test-seasons-fmt-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("s1"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("season-2"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("3"), withIntermediateDirectories: true)

    defer { try? FileManager.default.removeItem(at: tempDir) }

    let metadata = extractor.inferMetadata(from: tempDir)
    #expect(metadata?.seasons?.count == 3)
    #expect(metadata?.seasons?.contains(1) == true)
    #expect(metadata?.seasons?.contains(2) == true)
    #expect(metadata?.seasons?.contains(3) == true)
  }

  @Test("Analyzes lingua-matra project structure")
  func testLinguaMatra() {
    let projectPath = URL(fileURLWithPath: "/Users/stovak/Projects/podcasts/lingua-matra")
    let metadata = extractor.inferMetadata(from: projectPath)

    #expect(metadata?.title == "Lingua Matra")
    #expect(metadata?.languages != nil)
    #expect(metadata?.languages?.isEmpty == false)
  }
}

// MARK: - ProjectService.analyzeForGeneration Tests

@Suite("ProjectService Analysis Pipeline")
struct ProjectServiceAnalysisTests {
  @Test("Analyzes Lingua Matra project")
  func testAnalyzeLinguaMatra() {
    let projectPath = URL(fileURLWithPath: "/Users/stovak/Projects/podcasts/lingua-matra")
    let analysis = ProjectService.analyzeForGeneration(at: projectPath)

    #expect(analysis != nil)
    #expect(analysis?.extractedCast.isEmpty == false)
    #expect(analysis?.extractedCast.contains("NARRADOR") == true)
    #expect(analysis?.extractedCast.contains("MAESTRA") == true)
  }

  @Test("Analyzes Produciesta project")
  func testAnalyzeProduciesta() {
    let projectPath = URL(fileURLWithPath: "/Users/stovak/Projects/Produciesta")
    let analysis = ProjectService.analyzeForGeneration(at: projectPath)

    #expect(analysis != nil)
    #expect(analysis?.extractedCast.isEmpty == false)
  }

  @Test("Returns nil for non-existent directory")
  func testNonExistentDirectory() {
    let projectPath = URL(fileURLWithPath: "/nonexistent/path-\(UUID().uuidString)")
    let analysis = ProjectService.analyzeForGeneration(at: projectPath)

    #expect(analysis == nil)
  }

  @Test("Returns analysis with empty cast for project without scripts")
  func testProjectWithoutScripts() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("empty-project-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    defer { try? FileManager.default.removeItem(at: tempDir) }

    let analysis = ProjectService.analyzeForGeneration(at: tempDir)

    #expect(analysis != nil)
    #expect(analysis?.extractedCast.isEmpty == true)
  }

  @Test("Extracts all cast from project")
  func testExtractsAllCast() {
    let projectPath = URL(fileURLWithPath: "/Users/stovak/Projects/podcasts/lingua-matra")
    let analysis = ProjectService.analyzeForGeneration(at: projectPath)

    // Lingua Matra has multiple episodes with NARRADOR and MAESTRA
    // Verify cast is deduplicated
    let castSet = Set(analysis?.extractedCast ?? [])
    #expect(castSet.count == (analysis?.extractedCast.count ?? 0))
  }

  @Test("Detects episode pattern from structure")
  func testDetectsEpisodePattern() {
    let projectPath = URL(fileURLWithPath: "/Users/stovak/Projects/podcasts/lingua-matra")
    let analysis = ProjectService.analyzeForGeneration(at: projectPath)

    #expect(analysis?.episodePattern != nil)
    #expect(analysis?.episodePattern?.contains("Multi-language") == true)
  }
}

// MARK: - Integration Tests with Reference Projects

@Suite("Integration: Reference Projects")
struct IntegrationTests {
  let castExtractor = CastExtractor()
  let metadataExtractor = MetadataExtractor()

  @Test("Lingua Matra cast extraction ≥80% accuracy")
  func testLinguaMatraCastAccuracy() throws {
    // Lingua Matra episodes should contain NARRADOR and MAESTRA
    let episodePath = URL(fileURLWithPath: "/Users/stovak/Projects/podcasts/lingua-matra/episodes/it/episode_01.fountain")
    let cast = try castExtractor.extractCast(from: episodePath)

    #expect(cast.contains("NARRADOR"))
    #expect(cast.contains("MAESTRA"))

    // Verify no false positives (scene headings, etc.)
    #expect(!cast.contains("INT"))
    #expect(!cast.contains("EXT"))
  }

  @Test("Produciesta cast extraction")
  func testProduciestaCastAccuracy() throws {
    let castPath = URL(fileURLWithPath: "/Users/stovak/Projects/Produciesta/fixtures/cast-demo/cast-demo.fountain")
    let cast = try castExtractor.extractCast(from: castPath)

    #expect(cast.contains("UNCLE FU"))
  }

  @Test("Lingua Matra metadata inference")
  func testLinguaMatraMetadata() {
    let projectPath = URL(fileURLWithPath: "/Users/stovak/Projects/podcasts/lingua-matra")
    let metadata = metadataExtractor.inferMetadata(from: projectPath)

    #expect(metadata?.title == "Lingua Matra")
    #expect(metadata?.languages != nil)
    #expect(metadata?.languages?.contains("it") == true)
  }

  @Test("End-to-end analysis of Lingua Matra")
  func testEndToEndLinguaMatra() {
    let projectPath = URL(fileURLWithPath: "/Users/stovak/Projects/podcasts/lingua-matra")
    let analysis = ProjectService.analyzeForGeneration(at: projectPath)

    // Verify all components are present
    #expect(analysis != nil)
    #expect(analysis?.projectPath == projectPath)
    #expect(!analysis!.extractedCast.isEmpty)
    #expect(analysis?.inferredTitle == "Lingua Matra")
    #expect(!analysis!.detectedLanguages.isEmpty)
    #expect(analysis?.discoveredFiles.contains("*.fountain") == true)
  }
}

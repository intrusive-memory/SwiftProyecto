import XCTest

@testable import SwiftProyecto

// MARK: - CastExtractor Tests

final class CastExtractorTests: XCTestCase {
  let extractor = CastExtractor()

  func testExtractSingleCharacter() {
    let fountain = """
    NARRADOR
    Today we drill the present tense.
    """
    let cast = extractor.extractCast(from: fountain)
    XCTAssertEqual(cast, ["NARRADOR"])
  }

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
    XCTAssertEqual(cast.count, 2)
    XCTAssertTrue(cast.contains("NARRADOR"))
    XCTAssertTrue(cast.contains("MAESTRA"))
  }

  func testRemoveParenthetical() {
    let fountain = """
    UNCLE FU
    The Tao that can be spoken is not eternal.

    UNCLE FU (CONT'D)
    The name that can be named is not eternal.
    """
    let cast = extractor.extractCast(from: fountain)
    XCTAssertEqual(cast, ["UNCLE FU"])
  }

  func testRemoveVoiceModifier() {
    let fountain = """
    NARRADOR (V.O.)
    This is a voice-over.

    NARRADOR (O.S.)
    This is off-screen.
    """
    let cast = extractor.extractCast(from: fountain)
    XCTAssertEqual(cast, ["NARRADOR"])
  }

  func testFilterSceneHeadings() {
    let fountain = """
    INT. STUDY - NIGHT

    A candle burns on a desk.

    UNCLE FU
    The Tao.
    """
    let cast = extractor.extractCast(from: fountain)
    XCTAssertEqual(cast, ["UNCLE FU"])
  }

  func testFilterTransitions() {
    let fountain = """
    UNCLE FU
    The Tao.

    CUT TO:

    MAESTRA
    Io porto.
    """
    let cast = extractor.extractCast(from: fountain)
    XCTAssertEqual(cast.count, 2)
    XCTAssertFalse(cast.contains("CUT"))
  }

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
    XCTAssertEqual(cast.count, 3)
    XCTAssertTrue(cast.contains("UNCLE FU"))
    XCTAssertTrue(cast.contains("DOCTOR SMITH"))
    XCTAssertTrue(cast.contains("LADY IN RED"))
  }

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
    XCTAssertEqual(cast, ["APPLE", "BANANA", "ZEBRA"])
  }

  func testEmptyFountain() {
    let fountain = """
    INT. EMPTY ROOM - DAY

    An empty room.
    """
    let cast = extractor.extractCast(from: fountain)
    XCTAssertTrue(cast.isEmpty)
  }


  func testCharacterNamesWithApostrophes() {
    let fountain = """
    O'BRIEN
    I'm here.

    JO'S SISTER
    Welcome.
    """
    let cast = extractor.extractCast(from: fountain)
    XCTAssertEqual(cast.count, 2)
    XCTAssertTrue(cast.contains("O'BRIEN"))
    XCTAssertTrue(cast.contains("JO'S SISTER"))
  }

  func testCharacterNamesWithHyphens() {
    let fountain = """
    MARY-JANE
    Hello.

    JOHN-SMITH
    Hi there.
    """
    let cast = extractor.extractCast(from: fountain)
    XCTAssertEqual(cast.count, 2)
    XCTAssertTrue(cast.contains("MARY-JANE"))
    XCTAssertTrue(cast.contains("JOHN-SMITH"))
  }
}

// MARK: - MetadataExtractor Tests

final class MetadataExtractorTests: XCTestCase {
  let extractor = MetadataExtractor()

  func testTitleFromDirWithHyphens() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("lingua-matra-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let metadata = extractor.inferMetadata(from: tempDir)
    XCTAssertEqual(metadata?.title, "Lingua Matra")
  }

  func testTitleFromDirWithUnderscores() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("my_podcast-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let metadata = extractor.inferMetadata(from: tempDir)
    XCTAssertEqual(metadata?.title, "My Podcast")
  }

  func testTitleFromSimpleDir() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MyShow-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let metadata = extractor.inferMetadata(from: tempDir)
    XCTAssertEqual(metadata?.title, "MyShow")
  }

  func testNonExistentDirectory() {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent-12345")
    let metadata = extractor.inferMetadata(from: tempDir)
    XCTAssertNil(metadata)
  }

  func testDetectsLanguages() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test-project-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("en"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("es"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("it"), withIntermediateDirectories: true)

    defer { try? FileManager.default.removeItem(at: tempDir) }

    let metadata = extractor.inferMetadata(from: tempDir)
    XCTAssertNotNil(metadata?.languages)
    XCTAssertTrue(metadata?.languages?.contains("en") ?? false)
    XCTAssertTrue(metadata?.languages?.contains("es") ?? false)
    XCTAssertTrue(metadata?.languages?.contains("it") ?? false)
  }

  func testDetectsSeasons() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test-season-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("season-1"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("season-2"), withIntermediateDirectories: true)

    defer { try? FileManager.default.removeItem(at: tempDir) }

    let metadata = extractor.inferMetadata(from: tempDir)
    XCTAssertNotNil(metadata?.seasons)
    XCTAssertTrue(metadata?.seasons?.contains(1) ?? false)
    XCTAssertTrue(metadata?.seasons?.contains(2) ?? false)
  }

  func testMultipleSeasonFormats() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test-seasons-fmt-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("s1"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("season-2"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("3"), withIntermediateDirectories: true)

    defer { try? FileManager.default.removeItem(at: tempDir) }

    let metadata = extractor.inferMetadata(from: tempDir)
    XCTAssertEqual(metadata?.seasons?.count, 3)
    XCTAssertTrue(metadata?.seasons?.contains(1) ?? false)
    XCTAssertTrue(metadata?.seasons?.contains(2) ?? false)
    XCTAssertTrue(metadata?.seasons?.contains(3) ?? false)
  }

}

// MARK: - ProjectService Analysis Pipeline Tests

final class ProjectServiceAnalysisTests: XCTestCase {

  func testNonExistentDirectory() {
    let projectPath = URL(fileURLWithPath: "/nonexistent/path-\(UUID().uuidString)")
    let analysis = ProjectService.analyzeForGeneration(at: projectPath)

    XCTAssertNil(analysis)
  }

  func testProjectWithoutScripts() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("empty-project-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    defer { try? FileManager.default.removeItem(at: tempDir) }

    let analysis = ProjectService.analyzeForGeneration(at: tempDir)

    XCTAssertNotNil(analysis)
    XCTAssertTrue(analysis?.extractedCast.isEmpty ?? false)
  }

}

// MARK: - Integration Tests with Reference Projects

final class DirectoryAnalysisIntegrationTests: XCTestCase {
  let castExtractor = CastExtractor()
  let metadataExtractor = MetadataExtractor()

}

import XCTest

@testable import ProjectBrowser

final class ProjectMetadataTests: XCTestCase {

  // MARK: - Fixture Management

  private var tempRoot: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ProjectMetadataTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    tempRoot = root
  }

  override func tearDownWithError() throws {
    if let tempRoot, FileManager.default.fileExists(atPath: tempRoot.path) {
      try? FileManager.default.removeItem(at: tempRoot)
    }
    tempRoot = nil
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  private func writeProjectMD(_ contents: String) throws {
    let url = tempRoot.appendingPathComponent("PROJECT.md")
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }

  // MARK: - Test 1: Valid PROJECT.md with all four fields

  func testLoadWithAllFieldsPresent() async throws {
    try writeProjectMD(
      """
      ---
      title: "Confessions"
      author: "Tom Stovall"
      description: "A serialized audio drama."
      created: 2026-01-15
      ---

      # Confessions

      Body content is ignored by metadata loading.
      """
    )

    let metadata = try await ProjectMetadata.load(from: tempRoot)

    let unwrapped = try XCTUnwrap(metadata)
    XCTAssertEqual(unwrapped.title, "Confessions")
    XCTAssertEqual(unwrapped.author, "Tom Stovall")
    XCTAssertEqual(unwrapped.description, "A serialized audio drama.")
    XCTAssertNotNil(unwrapped.created)

    if let created = unwrapped.created {
      let components = Calendar(identifier: .iso8601).dateComponents(
        in: TimeZone(identifier: "UTC")!, from: created)
      XCTAssertEqual(components.year, 2026)
      XCTAssertEqual(components.month, 1)
      XCTAssertEqual(components.day, 15)
    }
  }

  // MARK: - Test 2: Minimal PROJECT.md (title only)

  func testLoadWithOnlyTitlePresent() async throws {
    try writeProjectMD(
      """
      ---
      title: Minimal Project
      ---
      Body text.
      """
    )

    let metadata = try await ProjectMetadata.load(from: tempRoot)

    let unwrapped = try XCTUnwrap(metadata)
    XCTAssertEqual(unwrapped.title, "Minimal Project")
    XCTAssertNil(unwrapped.author)
    XCTAssertNil(unwrapped.description)
    XCTAssertNil(unwrapped.created)
  }

  // MARK: - Test 3: Missing PROJECT.md returns nil

  func testLoadWithMissingProjectMDReturnsNil() async throws {
    let metadata = try await ProjectMetadata.load(from: tempRoot)
    XCTAssertNil(metadata)
  }

  // MARK: - Test 4: Malformed YAML (no closing delimiter) throws

  func testLoadWithUnclosedFrontMatterThrows() async throws {
    try writeProjectMD(
      """
      ---
      title: Unclosed
      Body text without a closing delimiter.
      """
    )

    do {
      _ = try await ProjectMetadata.load(from: tempRoot)
      XCTFail("Expected load(from:) to throw for unclosed front matter")
    } catch let error as ProjectMetadata.LoadError {
      XCTAssertEqual(error, .missingFrontMatter)
    }
  }

  // MARK: - Test 5: Malformed YAML (no front matter at all) throws

  func testLoadWithNoFrontMatterThrows() async throws {
    try writeProjectMD("Just a plain markdown file with no front matter.")

    do {
      _ = try await ProjectMetadata.load(from: tempRoot)
      XCTFail("Expected load(from:) to throw for missing front matter")
    } catch let error as ProjectMetadata.LoadError {
      XCTAssertEqual(error, .missingFrontMatter)
    }
  }

  // MARK: - Test 6: Front matter missing required title throws

  func testLoadWithMissingTitleThrows() async throws {
    try writeProjectMD(
      """
      ---
      author: Tom Stovall
      ---
      Body text.
      """
    )

    do {
      _ = try await ProjectMetadata.load(from: tempRoot)
      XCTFail("Expected load(from:) to throw for missing title")
    } catch let error as ProjectMetadata.LoadError {
      XCTAssertEqual(error, .missingTitle)
    }
  }

  // MARK: - Test 7: Quoted and unquoted values both parse correctly

  func testLoadHandlesQuotedAndUnquotedValues() async throws {
    try writeProjectMD(
      """
      ---
      title: 'Single Quoted Title'
      author: Unquoted Author
      description: "Double quoted description"
      ---
      """
    )

    let metadata = try await ProjectMetadata.load(from: tempRoot)

    let unwrapped = try XCTUnwrap(metadata)
    XCTAssertEqual(unwrapped.title, "Single Quoted Title")
    XCTAssertEqual(unwrapped.author, "Unquoted Author")
    XCTAssertEqual(unwrapped.description, "Double quoted description")
  }

  // MARK: - Test 8: Extra/unknown keys in front matter are ignored

  func testLoadIgnoresUnknownKeys() async throws {
    try writeProjectMD(
      """
      ---
      title: Extended Project
      genre: Drama
      tags: ["one", "two"]
      ---
      """
    )

    let metadata = try await ProjectMetadata.load(from: tempRoot)

    let unwrapped = try XCTUnwrap(metadata)
    XCTAssertEqual(unwrapped.title, "Extended Project")
  }

  // MARK: - YAML scalar decoding

  func testLoadDecodesDoubleQuotedEscapes() async throws {
    try writeProjectMD(
      #"""
      ---
      title: "The \"Quoted\" Show"
      author: "Back\\slash \/ Writer"
      description: "A host named \"Captain\" tours the town.\nSecond line\twith a tab, a \\ backslash and café."
      ---
      """#
    )

    let metadata = try await ProjectMetadata.load(from: tempRoot)

    let unwrapped = try XCTUnwrap(metadata)
    XCTAssertEqual(unwrapped.title, #"The "Quoted" Show"#)
    XCTAssertEqual(unwrapped.author, #"Back\slash / Writer"#)
    XCTAssertEqual(
      unwrapped.description,
      "A host named \"Captain\" tours the town.\nSecond line\twith a tab, a \\ backslash and caf\u{E9}."
    )
  }

  func testLoadDecodesSingleQuotedEscapes() async throws {
    try writeProjectMD(
      #"""
      ---
      title: 'It''s a Show'
      author: 'Pat O''Brien'
      description: 'Single quotes keep \n and \" as written.'
      ---
      """#
    )

    let metadata = try await ProjectMetadata.load(from: tempRoot)

    let unwrapped = try XCTUnwrap(metadata)
    XCTAssertEqual(unwrapped.title, "It's a Show")
    XCTAssertEqual(unwrapped.author, "Pat O'Brien")
    XCTAssertEqual(unwrapped.description, #"Single quotes keep \n and \" as written."#)
  }

  func testLoadLeavesPlainScalarsUnchanged() async throws {
    try writeProjectMD(
      #"""
      ---
      title: Plain Title with a \n and "inner" quotes
      author: It's Plain
      description: Ends with a quote"
      ---
      """#
    )

    let metadata = try await ProjectMetadata.load(from: tempRoot)

    let unwrapped = try XCTUnwrap(metadata)
    XCTAssertEqual(unwrapped.title, #"Plain Title with a \n and "inner" quotes"#)
    XCTAssertEqual(unwrapped.author, "It's Plain")
    XCTAssertEqual(unwrapped.description, #"Ends with a quote""#)
  }

  func testLoadIgnoresCommentAfterClosingQuote() async throws {
    try writeProjectMD(
      #"""
      ---
      title: "Commented \"Title\"" # a trailing comment
      created: "2026-01-15"
      ---
      """#
    )

    let metadata = try await ProjectMetadata.load(from: tempRoot)

    let unwrapped = try XCTUnwrap(metadata)
    XCTAssertEqual(unwrapped.title, #"Commented "Title""#)
    XCTAssertNotNil(unwrapped.created)
  }
}

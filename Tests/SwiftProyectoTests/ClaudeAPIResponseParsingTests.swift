import XCTest

@testable import SwiftProyecto

/// Covers the model-output boundary of `ClaudeAPIBackend`: decoding the JSON
/// the model returns, and the prompt that asks for it.
final class ClaudeAPIResponseParsingTests: XCTestCase {

  private let bareJSON = """
    {
      "title": "The Show",
      "author": "Ann Author",
      "description": "A podcast about things",
      "type": "podcast"
    }
    """

  // MARK: - parseMetadataJSON

  func testParsesBareJSON() throws {
    let metadata = try ClaudeAPIBackend.parseMetadataJSON(bareJSON)

    XCTAssertEqual(metadata.title, "The Show")
    XCTAssertEqual(metadata.author, "Ann Author")
    XCTAssertEqual(metadata.description, "A podcast about things")
  }

  func testStripsCodeFenceAroundJSON() throws {
    let fenced = """
      ```json
      \(bareJSON)
      ```
      """

    let metadata = try ClaudeAPIBackend.parseMetadataJSON(fenced)

    XCTAssertEqual(metadata.title, "The Show")
  }

  /// Regression: fenced output used to drop every line containing the word
  /// "json", so a description such as "A JSON-based show" broke the decode.
  func testFencedOutputKeepsContentLinesThatContainJSON() throws {
    let fenced = """
      ```json
      {
        "title": "Parsers",
        "author": "Ann Author",
        "description": "A JSON-based show about parsers",
        "type": "podcast"
      }
      ```
      """

    let metadata = try ClaudeAPIBackend.parseMetadataJSON(fenced)

    XCTAssertEqual(metadata.title, "Parsers")
    XCTAssertEqual(metadata.description, "A JSON-based show about parsers")
  }

  func testSurroundingWhitespaceIsIgnored() throws {
    let metadata = try ClaudeAPIBackend.parseMetadataJSON("\n\n  \(bareJSON)  \n")

    XCTAssertEqual(metadata.title, "The Show")
  }

  func testNonJSONThrowsGenerationFailed() {
    XCTAssertThrowsError(try ClaudeAPIBackend.parseMetadataJSON("Sorry, I can't help.")) {
      error in
      guard let llmError = error as? LLMBackendError, case .generationFailed = llmError else {
        return XCTFail("Expected generationFailed, got \(error)")
      }
    }
  }

  func testMissingRequiredFieldThrowsGenerationFailed() {
    // `type` is required by MetadataJSON.
    let missingType = """
      {"title": "T", "author": "A"}
      """

    XCTAssertThrowsError(try ClaudeAPIBackend.parseMetadataJSON(missingType)) { error in
      guard let llmError = error as? LLMBackendError, case .generationFailed = llmError else {
        return XCTFail("Expected generationFailed, got \(error)")
      }
    }
  }

  // MARK: - buildPrompt

  func testPromptListsDiscoveredFilesAndCast() {
    let backend = ClaudeAPIBackend(apiKey: nil)
    let project = ProjectAnalysis(
      projectPath: URL(fileURLWithPath: "/tmp/show"),
      discoveredFiles: ["episodes/ep1.fountain"],
      extractedCast: ["MARY", "JOHN"]
    )

    let prompt = backend.buildPrompt(project: project)

    XCTAssertTrue(prompt.contains("episodes/ep1.fountain"))
    XCTAssertTrue(prompt.contains("MARY, JOHN"))
    XCTAssertFalse(prompt.contains("No files discovered"))
    XCTAssertFalse(prompt.contains("No cast members extracted"))
  }

  func testPromptSaysWhenNothingWasDiscovered() {
    let backend = ClaudeAPIBackend(apiKey: nil)
    let project = ProjectAnalysis(projectPath: URL(fileURLWithPath: "/tmp/empty"))

    let prompt = backend.buildPrompt(project: project)

    XCTAssertTrue(prompt.contains("No files discovered"))
    XCTAssertTrue(prompt.contains("No cast members extracted"))
  }
}

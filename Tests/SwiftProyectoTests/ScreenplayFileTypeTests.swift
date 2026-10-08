import XCTest

@testable import SwiftProyecto

/// Tests for the `type:` front matter value that screenplay writers emit.
///
/// Writers always declare `type`, inferred from their role. Parsing never
/// requires it, so these tests cover only what is written.
final class ScreenplayFileTypeTests: XCTestCase {

  // MARK: - Raw values

  func testRawValuesMatchFrontMatterKeywords() {
    XCTAssertEqual(ScreenplayFileType.episode.rawValue, "episode")
    XCTAssertEqual(ScreenplayFileType.intro.rawValue, "intro")
    XCTAssertEqual(ScreenplayFileType.outro.rawValue, "outro")
  }

  func testAllCasesAreTheThreeRoles() {
    XCTAssertEqual(
      ScreenplayFileType.allCases.map(\.rawValue).sorted(),
      ["episode", "intro", "outro"])
  }

  // MARK: - Placeholder documents

  /// The intro writer must declare `intro`, not the old `fountain` placeholder.
  func testIntroPlaceholderDeclaresIntroType() {
    let text = ScreenplayFileType.intro.placeholderDocument(
      title: "Show - Season 1 Intro",
      heading: "Season 1 Intro",
      body: "[Intro content will be generated here]"
    )

    XCTAssertTrue(text.contains("\ntype: intro\n"))
    XCTAssertFalse(text.contains("type: fountain"))
  }

  /// The outro writer must declare `outro`.
  func testOutroPlaceholderDeclaresOutroType() {
    let text = ScreenplayFileType.outro.placeholderDocument(
      title: "Show - Season 2 Outro",
      heading: "Season 2 Outro",
      body: "[Outro content will be generated here]"
    )

    XCTAssertTrue(text.contains("\ntype: outro\n"))
    XCTAssertFalse(text.contains("type: fountain"))
  }

  func testEpisodePlaceholderDeclaresEpisodeType() {
    let text = ScreenplayFileType.episode.placeholderDocument(
      title: "Show - Episode 1",
      heading: "Episode 1",
      body: "Body"
    )

    XCTAssertTrue(text.contains("\ntype: episode\n"))
  }

  /// The front matter block opens on the first line and closes before the
  /// heading, so `type:` sits inside it and not in the body.
  func testTypeLivesInsideFrontMatterBlock() throws {
    let text = ScreenplayFileType.intro.placeholderDocument(
      title: "T",
      heading: "H",
      body: "B"
    )

    let lines = text.components(separatedBy: "\n")
    XCTAssertEqual(lines.first, "---")
    let closing = try XCTUnwrap(lines.dropFirst().firstIndex(of: "---"))
    let typeLine = try XCTUnwrap(lines.firstIndex(of: "type: intro"))
    let headingLine = try XCTUnwrap(lines.firstIndex(of: "# H"))

    XCTAssertLessThan(typeLine, closing)
    XCTAssertLessThan(closing, headingLine)
  }

  func testPlaceholderRendersTitleHeadingAndBody() {
    let text = ScreenplayFileType.intro.placeholderDocument(
      title: "My Show - Season 3 Intro",
      heading: "Season 3 Intro",
      body: "[Intro content will be generated here]"
    )

    XCTAssertEqual(
      text,
      """
      ---
      type: intro
      title: My Show - Season 3 Intro
      ---

      # Season 3 Intro

      [Intro content will be generated here]
      """)
  }

  /// Matches the placeholder writers' previous output: no trailing newline.
  func testPlaceholderHasNoTrailingNewline() {
    let text = ScreenplayFileType.outro.placeholderDocument(
      title: "T", heading: "H", body: "B")

    XCTAssertFalse(text.hasSuffix("\n"))
  }
}

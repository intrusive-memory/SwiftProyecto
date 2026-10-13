import XCTest

@testable import SwiftProyecto

/// Covers the regex fallback that decides which screenplay lines become cast
/// names. The heuristics are marked deprecated (SwiftCompartido replaced them),
/// but they still run on the fallback path, so they are tested here.
@available(*, deprecated, message: "Tests the deprecated regex fallback on purpose")
final class CastExtractorHeuristicTests: XCTestCase {

  private let extractor = CastExtractor()

  // MARK: - isLikelyCharacterName

  func testAcceptsPlainUppercaseNames() {
    XCTAssertTrue(extractor.isLikelyCharacterName("MARY"))
    XCTAssertTrue(extractor.isLikelyCharacterName("LAO TZU"))
    XCTAssertTrue(extractor.isLikelyCharacterName("ROBOT-3"))
    XCTAssertTrue(extractor.isLikelyCharacterName("DOCTOR #2"))
    XCTAssertTrue(extractor.isLikelyCharacterName("O'BRIEN"))
  }

  /// Regression: the bare prefixes "CUT", "FADE" and "DISSOLVE" used to reject
  /// any name beginning with those letters.
  func testAcceptsNamesThatMerelyStartWithTransitionWords() {
    XCTAssertTrue(extractor.isLikelyCharacterName("CUTHBERT"))
    XCTAssertTrue(extractor.isLikelyCharacterName("FADERS"))
    XCTAssertTrue(extractor.isLikelyCharacterName("DISSOLVEN"))
  }

  func testRejectsSceneHeadings() {
    XCTAssertFalse(extractor.isLikelyCharacterName("INT. KITCHEN - DAY"))
    XCTAssertFalse(extractor.isLikelyCharacterName("EXT. PARK - NIGHT"))
    XCTAssertFalse(extractor.isLikelyCharacterName("EST. HARBOR"))
    XCTAssertFalse(extractor.isLikelyCharacterName("INT/EXT. CAR"))
  }

  func testRejectsTransitions() {
    XCTAssertFalse(extractor.isLikelyCharacterName("CUT TO:"))
    XCTAssertFalse(extractor.isLikelyCharacterName("DISSOLVE TO:"))
    XCTAssertFalse(extractor.isLikelyCharacterName("FADE IN:"))
    XCTAssertFalse(extractor.isLikelyCharacterName("FADE OUT"))
    XCTAssertFalse(extractor.isLikelyCharacterName("CUT TO BLACK"))
  }

  func testRejectsMixedCaseAndParentheticalsAndPunctuation() {
    XCTAssertFalse(extractor.isLikelyCharacterName("Mary"))
    XCTAssertFalse(extractor.isLikelyCharacterName("(V.O.)"))
    XCTAssertFalse(extractor.isLikelyCharacterName("BANG!"))
  }

  func testRejectsOverlongLines() {
    let fifty = String(repeating: "A", count: 50)
    XCTAssertTrue(extractor.isLikelyCharacterName(fifty))
    XCTAssertFalse(extractor.isLikelyCharacterName(fifty + "A"))
  }

  // MARK: - removeParentheticals

  func testRemovesContinuationAndExtensionParentheticals() {
    XCTAssertEqual(extractor.removeParentheticals(from: "JOHN (CONT'D)"), "JOHN")
    XCTAssertEqual(extractor.removeParentheticals(from: "MARY (V.O.)"), "MARY")
    XCTAssertEqual(extractor.removeParentheticals(from: "BOB (O.S.) (CONT'D)"), "BOB")
  }

  func testLeavesLinesWithoutParentheticalsAlone() {
    XCTAssertEqual(extractor.removeParentheticals(from: "MARY"), "MARY")
  }

  // MARK: - extractCastRegex

  func testExtractsUniqueSortedCastFromScreenplayText() {
    let fountain = """
      INT. KITCHEN - DAY

      MARY (V.O.)
      Hello there.

      JOHN
      Hi.

      MARY
      Again.

      CUT TO:

      EXT. PARK - NIGHT

      CUTHBERT
      Over here.
      """

    XCTAssertEqual(extractor.extractCastRegex(from: fountain), ["CUTHBERT", "JOHN", "MARY"])
  }

  func testEmptyScreenplayYieldsNoCast() {
    XCTAssertEqual(extractor.extractCastRegex(from: ""), [])
  }
}

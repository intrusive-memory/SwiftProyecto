import Foundation
import XCTest

@testable import ProjectBrowser

/// Covers the extension-to-handler mapping in `DefaultHandlers`. The handlers
/// build SwiftUI views lazily, so these tests check the mapping and never
/// render the views.
final class DefaultHandlersTests: XCTestCase {

  private let directoryURL = URL(fileURLWithPath: "/tmp/show", isDirectory: true)

  func testExtensionGroupsDoNotOverlap() {
    let image = Set(DefaultHandlers.imageExtensions)
    let audio = Set(DefaultHandlers.audioExtensions)
    let pdf = Set(DefaultHandlers.pdfExtensions)

    XCTAssertTrue(image.isDisjoint(with: audio))
    XCTAssertTrue(image.isDisjoint(with: pdf))
    XCTAssertTrue(audio.isDisjoint(with: pdf))
  }

  func testImageHandlersCoverExactlyTheImageExtensions() {
    let handlers = DefaultHandlers.imageHandlers(directoryURL: directoryURL)

    XCTAssertEqual(Set(handlers.keys), Set(DefaultHandlers.imageExtensions))
  }

  func testAudioHandlersCoverExactlyTheAudioExtensions() {
    let handlers = DefaultHandlers.audioHandlers(directoryURL: directoryURL)

    XCTAssertEqual(Set(handlers.keys), Set(DefaultHandlers.audioExtensions))
  }

  func testPDFHandlersCoverExactlyThePDFExtensions() {
    let handlers = DefaultHandlers.pdfHandlers(directoryURL: directoryURL)

    XCTAssertEqual(Set(handlers.keys), Set(DefaultHandlers.pdfExtensions))
  }

  func testAllHandlersIsTheUnionOfTheThreeGroups() {
    let all = DefaultHandlers.allHandlers(directoryURL: directoryURL)
    let expected =
      Set(DefaultHandlers.imageExtensions)
      .union(DefaultHandlers.audioExtensions)
      .union(DefaultHandlers.pdfExtensions)

    XCTAssertEqual(Set(all.keys), expected)
  }

  func testSingleHandlerKeepsItsExtension() {
    XCTAssertEqual(
      DefaultHandlers.audioHandler(for: "mp3", directoryURL: directoryURL).fileExtension, "mp3")
    XCTAssertEqual(
      DefaultHandlers.imageHandler(for: "png", directoryURL: directoryURL).fileExtension, "png")
    XCTAssertEqual(DefaultHandlers.pdfHandler(directoryURL: directoryURL).fileExtension, "pdf")
  }

  func testMatchingIsCaseSensitiveOnTheDictionaryKey() {
    // Callers pass lowercase extensions; ProjectWindow lowercases before lookup.
    let handlers = DefaultHandlers.allHandlers(directoryURL: directoryURL)

    XCTAssertNotNil(handlers["mp3"])
    XCTAssertNil(handlers["MP3"])
  }
}

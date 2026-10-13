import SwiftUI
import XCTest

@testable import ProjectBrowser

/// Smoke tests for the two toolbar views that had no coverage. They confirm the
/// views construct and evaluate their bodies, and that the action bar stores the
/// callbacks it was given, which is the part that can silently break.
@MainActor
final class ProjectHeaderActionBarTests: XCTestCase {

  func testHeaderEvaluatesWithoutMetadata() {
    let header = ProjectHeader(metadata: nil, fileCount: 3, folderCount: 1, title: "Show")

    _ = header.body
  }

  func testHeaderEvaluatesWithNoTitleAndNoCounts() {
    let header = ProjectHeader(metadata: nil, fileCount: 0, folderCount: 0)

    _ = header.body
  }

  func testActionBarEvaluatesWithAllActionsEnabled() {
    let bar = ProjectActionBar(
      onSync: {}, onImport: {}, onLoadAll: {}, onUnloadAll: {})

    _ = bar.body
  }

  func testActionBarEvaluatesWhenDisabled() {
    let bar = ProjectActionBar(
      onSync: {}, onImport: {}, onLoadAll: {}, onUnloadAll: {},
      isEnabled: false, canSync: false, canImport: false,
      canLoadAll: false, canUnloadAll: false)

    _ = bar.body
    XCTAssertFalse(bar.isEnabled)
    XCTAssertFalse(bar.canSync)
  }

  func testActionBarStoresTheCallbacksItWasGiven() {
    var fired: [String] = []
    let bar = ProjectActionBar(
      onSync: { fired.append("sync") },
      onImport: { fired.append("import") },
      onLoadAll: { fired.append("load") },
      onUnloadAll: { fired.append("unload") }
    )

    bar.onSync()
    bar.onImport()
    bar.onLoadAll()
    bar.onUnloadAll()

    XCTAssertEqual(fired, ["sync", "import", "load", "unload"])
  }
}

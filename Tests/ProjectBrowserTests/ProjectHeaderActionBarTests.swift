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

  #if os(macOS)
    /// `ProjectWindow`'s default sidebar minimum width (`sidebarMinWidth`).
    private static let sidebarMinWidth: CGFloat = 250

    private static func fittingWidth(_ style: ProjectActionBar.MacLabelStyle) -> CGFloat {
      let bar = ProjectActionBar(onSync: {}, onImport: {}, onLoadAll: {}, onUnloadAll: {})
      return NSHostingView(rootView: bar.macRow(style)).fittingSize.width
    }

    /// The fallback row must fit the narrowest sidebar `ProjectWindow` allows by
    /// default, or the buttons truncate ("S…", "Im…") as they did before.
    func testIconOnlyRowFitsTheDefaultSidebarMinimumWidth() {
      XCTAssertLessThanOrEqual(Self.fittingWidth(.iconOnly), Self.sidebarMinWidth)
    }

    /// The titled row is the wide one; `ViewThatFits` falls back to the
    /// icon-only row when the titled row doesn't fit.
    func testTitledRowIsWiderThanTheIconOnlyRow() {
      XCTAssertGreaterThan(Self.fittingWidth(.titleAndIcon), Self.fittingWidth(.iconOnly))
    }
  #endif
}

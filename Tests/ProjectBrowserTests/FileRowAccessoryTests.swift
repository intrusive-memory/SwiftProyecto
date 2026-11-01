import SwiftUI
import XCTest

@testable import ProjectBrowser

#if os(macOS)
  import AppKit
#endif

/// The host's view at the trailing edge of a file row.
@MainActor
final class FileRowAccessoryTests: XCTestCase {

  private let bundle = ProjectFile(
    name: "SHANE.dossier",
    relativePath: "characters/SHANE.dossier",
    fileExtension: "dossier",
    isDirectory: false,
    modifiedDate: Date(timeIntervalSince1970: 0),
    isBundle: true
  )

  /// A label with no accessory has none, so existing callers look as they did.
  func testLabelHasNoAccessoryByDefault() {
    XCTAssertNil(FileTreeRowLabel(file: bundle).accessory)
  }

  #if os(macOS)
    /// An accessory takes up room in the row, which is to say it is really laid out.
    func testAccessoryIsLaidOutInTheRow() {
      let plain = NSHostingView(rootView: FileTreeRowLabel(file: bundle))
      let withAccessory = NSHostingView(
        rootView: FileTreeRowLabel(
          file: bundle,
          accessory: AnyView(Color.clear.frame(width: 40, height: 10))
        )
      )

      XCTAssertGreaterThanOrEqual(
        withAccessory.fittingSize.width, plain.fittingSize.width + 40)
    }
  #endif

  /// The closure is passed through every public layer with the argument label a host uses.
  /// Failing to compile is this test's failure; calling each `body` proves nothing more.
  func testEveryPublicLayerAcceptsTheAccessory() {
    let accessory: (ProjectFile) -> AnyView = { _ in AnyView(EmptyView()) }

    _ = ProjectWindow(
      directoryURL: URL(fileURLWithPath: "/tmp"), rowAccessory: accessory)
    _ = FileTreeView(
      files: [bundle],
      expandedFolders: .constant([]),
      selectedFile: .constant(nil),
      onFolderToggle: { _ in },
      onSelect: { _ in },
      rowAccessory: accessory
    )
    _ = ProjectBrowserSidebar(
      files: [bundle],
      metadata: nil,
      selectedFile: .constant(nil),
      expandedFolders: .constant([]),
      onFolderToggle: { _ in },
      onSelect: { _ in },
      onSync: {},
      onImport: {},
      onLoadAll: {},
      onUnloadAll: {},
      rowAccessory: accessory
    )
  }
}

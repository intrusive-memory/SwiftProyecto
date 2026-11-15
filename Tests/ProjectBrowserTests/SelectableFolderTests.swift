import SwiftUI
import XCTest

@testable import ProjectBrowser

/// Tests the selectable-folder hook: `ProjectWindow`'s `selectableFolder:`
/// predicate names the folders whose sidebar row selects them, and its
/// `folderHandler:` builds a selected folder's detail view.
///
/// The contract under test:
///
/// 1. A folder the predicate names is selectable, and a selected folder's
///    detail view is the one `folderHandler` builds.
/// 2. A folder is never looked up in `handlers`, even when its name matches a
///    key.
/// 3. A folder the predicate rejects is not selectable.
/// 4. With no hook, no folder is selectable, as before the hook existed.
@MainActor
final class SelectableFolderTests: XCTestCase {

  // MARK: - Fixtures

  private let locationsFolder = ProjectFile(
    name: "locations",
    relativePath: "locations",
    fileExtension: nil,
    isDirectory: true,
    modifiedDate: Date()
  )

  private let episodesFolder = ProjectFile(
    name: "episodes",
    relativePath: "episodes",
    fileExtension: nil,
    isDirectory: true,
    modifiedDate: Date()
  )

  private let notesFile = ProjectFile(
    name: "notes.md",
    relativePath: "notes.md",
    fileExtension: "md",
    isDirectory: false,
    modifiedDate: Date(),
    fileSize: 12
  )

  /// A predicate naming only `locations/`, comparing a path worked out once.
  private func onlyLocations() -> (ProjectFile) -> Bool {
    let selectablePath = "locations"
    return { $0.relativePath == selectablePath }
  }

  private func window(
    selectableFolder: ((ProjectFile) -> Bool)? = nil,
    folderHandler: ((ProjectFile) -> AnyView)? = nil
  ) -> ProjectWindow {
    ProjectWindow(
      directoryURL: FileManager.default.temporaryDirectory,
      selectableFolder: selectableFolder,
      folderHandler: folderHandler
    )
  }

  // MARK: - Accessibility identifier

  func testFolderAccessibilityIdentifierForTopLevelFolder() {
    XCTAssertEqual(
      FileTreeView.folderAccessibilityIdentifier(for: locationsFolder),
      "projectBrowser.folder.locations")
  }

  func testFolderAccessibilityIdentifierForNestedFolder() {
    let nested = ProjectFile(
      name: "interiors",
      relativePath: "locations/interiors",
      fileExtension: nil,
      isDirectory: true,
      modifiedDate: Date()
    )
    XCTAssertEqual(
      FileTreeView.folderAccessibilityIdentifier(for: nested),
      "projectBrowser.folder.locations/interiors")
  }

  // MARK: - Predicate true

  func testPredicateTrueFolderIsSelectableAndShowsFolderHandlerView() {
    var builtFor: String?
    let window = window(
      selectableFolder: onlyLocations(),
      folderHandler: { file in
        builtFor = file.relativePath
        return AnyView(Text(verbatim: "Folder view for \(file.name)"))
      }
    )

    XCTAssertTrue(window.isSelectableFolder(locationsFolder))
    XCTAssertTrue(
      FileTreeView.isSelectableFolder(locationsFolder, selectableFolder: onlyLocations()))

    let pane = window.detailPane(for: locationsFolder)
    XCTAssertTrue(pane.hasFolderHandler, "ProjectWindow forwards folderHandler to the pane")
    XCTAssertEqual(pane.contentRoute(for: locationsFolder), .folder)

    _ = pane.contentView(for: locationsFolder)
    XCTAssertEqual(builtFor, "locations", "the detail view is folderHandler's")
  }

  // MARK: - handlers are never used for folders

  func testFolderMatchingAHandlersKeyStillGoesToFolderHandler() {
    var handlerCalled = false
    var folderHandlerCalled = false
    let pane = ProjectDetailPane(
      selectedFile: locationsFolder,
      handlers: [
        "locations": { _ in
          handlerCalled = true
          return AnyView(Text(verbatim: "name handler"))
        }
      ],
      folderHandler: { _ in
        folderHandlerCalled = true
        return AnyView(Text(verbatim: "folder handler"))
      }
    )

    XCTAssertEqual(pane.contentRoute(for: locationsFolder), .folder)
    _ = pane.contentView(for: locationsFolder)
    XCTAssertTrue(folderHandlerCalled)
    XCTAssertFalse(handlerCalled, "a folder is never looked up in handlers, even by name")
  }

  func testFolderMatchingAHandlersKeyWithNoFolderHandlerIsUnsupported() {
    var handlerCalled = false
    let pane = ProjectDetailPane(
      selectedFile: locationsFolder,
      handlers: [
        "locations": { _ in
          handlerCalled = true
          return AnyView(Text(verbatim: "name handler"))
        }
      ]
    )

    XCTAssertEqual(pane.contentRoute(for: locationsFolder), .unsupported)
    _ = pane.contentView(for: locationsFolder)
    XCTAssertFalse(handlerCalled)
  }

  // MARK: - Predicate false

  func testPredicateFalseFolderIsNotSelectable() {
    let window = window(
      selectableFolder: onlyLocations(),
      folderHandler: { _ in AnyView(EmptyView()) }
    )

    XCTAssertFalse(window.isSelectableFolder(episodesFolder))
    XCTAssertFalse(
      FileTreeView.isSelectableFolder(episodesFolder, selectableFolder: onlyLocations()))
  }

  func testAFileIsNeverASelectableFolderEvenWhenThePredicateSaysYes() {
    XCTAssertFalse(
      FileTreeView.isSelectableFolder(notesFile, selectableFolder: { _ in true }))
  }

  // MARK: - No hook

  func testWithNoHookNoFolderIsSelectable() {
    let window = window()

    XCTAssertFalse(window.isSelectableFolder(locationsFolder))
    XCTAssertFalse(window.isSelectableFolder(episodesFolder))
    XCTAssertFalse(FileTreeView.isSelectableFolder(locationsFolder, selectableFolder: nil))
    XCTAssertFalse(window.detailPane(for: locationsFolder).hasFolderHandler)
  }

  func testFileRoutingIsUnchangedByAFolderHandler() {
    let pane = ProjectDetailPane(
      selectedFile: notesFile,
      handlers: ["md": { _ in AnyView(Text(verbatim: "md")) }],
      folderHandler: { _ in AnyView(Text(verbatim: "folder")) }
    )

    XCTAssertEqual(pane.contentRoute(for: notesFile), .handler)
  }

  // MARK: - Content loading

  func testSelectedFolderIsNeverLazilyLoaded() {
    XCTAssertFalse(
      ProjectFileContentLoader.shouldLoad(
        file: locationsFolder, hasHandler: false, cache: [:], loadingFiles: []),
      "a folder has no bytes of its own; loading it would only raise an error")
  }
}

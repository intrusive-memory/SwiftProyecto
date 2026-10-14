import SwiftUI
import XCTest

@testable import ProjectBrowser

/// Tests for the host-driven selection request: the path resolver that
/// ``ProjectWindow`` uses to honour `selectProjectFile`, the selection
/// transitions the window runs (``ProjectWindowSelection``), and the action
/// itself.
///
/// The window's `@State` is private, so the transition tests hold that state in
/// a ``WindowState`` and wire it exactly as the window does: a request resolves
/// and expands, then hands the file to the same `select` a sidebar click calls.
/// Which layout shows the result is the window's own `NavigationSplitView` or
/// `NavigationStack` binding to that selection, and is not covered here.
@MainActor
final class ProjectFileSelectionRequestTests: XCTestCase {

  // MARK: - Fixtures

  private func folder(_ path: String) -> ProjectFile {
    ProjectFile(
      name: URL(fileURLWithPath: path).lastPathComponent,
      relativePath: path,
      fileExtension: nil,
      isDirectory: true,
      modifiedDate: Date()
    )
  }

  private func file(_ path: String) -> ProjectFile {
    ProjectFile(
      name: URL(fileURLWithPath: path).lastPathComponent,
      relativePath: path,
      fileExtension: URL(fileURLWithPath: path).pathExtension,
      isDirectory: false,
      modifiedDate: Date()
    )
  }

  /// `chapter1.md`, `chapter2.md`, and a nested `book/part1/notes.md` under
  /// the folders `book` and `book/part1`.
  private var tree: [ProjectFile] {
    [
      file("chapter1.md"),
      file("chapter2.md"),
      folder("book"),
      folder("book/part1"),
      file("book/part1/notes.md"),
    ]
  }

  // MARK: - Resolver: lookup

  func testResolvesTopLevelFileByRelativePath() {
    let resolution = ProjectFileSelectionResolver.resolve(
      relativePath: "chapter2.md", in: tree)

    XCTAssertEqual(resolution?.file.relativePath, "chapter2.md")
    XCTAssertEqual(resolution?.ancestorFolderIDs, [])
  }

  /// The resolution returns the window's own ``ProjectFile`` (same `id`), not a
  /// host-built copy, so selection compares equal to a click's.
  func testResolutionReturnsTheWindowsOwnFileInstance() {
    let files = tree
    let resolution = ProjectFileSelectionResolver.resolve(
      relativePath: "book/part1/notes.md", in: files)

    XCTAssertEqual(resolution?.file, files.last)
  }

  func testUnknownPathIsIgnored() {
    XCTAssertNil(
      ProjectFileSelectionResolver.resolve(relativePath: "missing.md", in: tree))
  }

  func testDirectoryPathIsIgnored() {
    XCTAssertNil(
      ProjectFileSelectionResolver.resolve(relativePath: "book/part1", in: tree))
  }

  func testEmptyPathIsIgnored() {
    XCTAssertNil(ProjectFileSelectionResolver.resolve(relativePath: "", in: tree))
  }

  func testEmptyFileListIgnoresEveryPath() {
    XCTAssertNil(
      ProjectFileSelectionResolver.resolve(relativePath: "chapter1.md", in: []))
  }

  /// Matching is exact: a host path is never treated as a prefix or a suffix.
  func testMatchingIsExactNotPrefixBased() {
    XCTAssertNil(
      ProjectFileSelectionResolver.resolve(relativePath: "chapter", in: tree))
    XCTAssertNil(
      ProjectFileSelectionResolver.resolve(relativePath: "notes.md", in: tree))
  }

  // MARK: - Resolver: ancestors

  /// Every ancestor folder of a nested file is returned, so the sidebar can
  /// expand the whole chain and reveal the row.
  func testReturnsEveryAncestorFolderOfNestedFile() {
    let files = tree
    let resolution = ProjectFileSelectionResolver.resolve(
      relativePath: "book/part1/notes.md", in: files)

    let expected: Set<UUID> = [files[2].id, files[3].id]
    XCTAssertEqual(resolution?.ancestorFolderIDs, expected)
  }

  func testOneLevelDeepFileExpandsOnlyItsParentFolder() {
    let files = tree
    let resolution = ProjectFileSelectionResolver.resolve(
      relativePath: "book/part1", in: files)
    XCTAssertNil(resolution, "A directory is never a valid target")

    let child = ProjectFile(
      name: "intro.md", relativePath: "book/intro.md", fileExtension: "md",
      isDirectory: false, modifiedDate: Date())
    let withChild = files + [child]
    let oneLevel = ProjectFileSelectionResolver.resolve(
      relativePath: "book/intro.md", in: withChild)

    XCTAssertEqual(oneLevel?.ancestorFolderIDs, [files[2].id])
  }

  /// A folder missing from the discovered tree contributes no id, rather than
  /// failing the whole request.
  func testAncestorAbsentFromTreeIsSkipped() {
    let orphan = file("ghost/notes.md")
    let resolution = ProjectFileSelectionResolver.resolve(
      relativePath: "ghost/notes.md", in: [orphan])

    XCTAssertEqual(resolution?.file, orphan)
    XCTAssertEqual(resolution?.ancestorFolderIDs, [])
  }

  // MARK: - Window state

  /// Stands in for the window's `@State` and records every side effect, in
  /// order, as `"<effect>:<relativePath>"`.
  private final class WindowState: @unchecked Sendable {
    var selectedFile: ProjectFile?
    var expandedFolders: Set<UUID> = []
    var events: [String] = []
  }

  /// A sidebar click, wired as ``ProjectWindow/selectFile(_:)`` wires it.
  private func click(_ file: ProjectFile, state: WindowState) {
    ProjectWindowSelection.select(
      file,
      selectedFile: &state.selectedFile,
      onFileSelection: { state.events.append("selected:\($0.relativePath)") },
      onMissingFileSelected: { state.events.append("missing:\($0)") },
      loadContent: { state.events.append("loaded:\($0.relativePath)") }
    )
  }

  /// A host request, wired as ``ProjectWindow/requestSelection(relativePath:)``
  /// wires it.
  @discardableResult
  private func request(_ path: String, in files: [ProjectFile], state: WindowState) -> Bool {
    ProjectWindowSelection.request(
      relativePath: path,
      in: files,
      currentSelection: state.selectedFile,
      expandedFolders: &state.expandedFolders,
      select: { click($0, state: state) }
    )
  }

  // MARK: - Window: host request

  /// A request highlights the window's own file, expands every ancestor so its
  /// row is visible, reports it through `onFileSelection`, then loads it: the
  /// same effects, in the same order, as a click on its row.
  func testRequestSelectsExpandsReportsAndLoadsNestedFile() {
    let files = tree
    let state = WindowState()

    XCTAssertTrue(request("book/part1/notes.md", in: files, state: state))

    XCTAssertEqual(state.selectedFile, files[4])
    XCTAssertEqual(state.expandedFolders, [files[2].id, files[3].id])
    XCTAssertEqual(state.events, ["selected:book/part1/notes.md", "loaded:book/part1/notes.md"])
  }

  /// A request has the same effects as a click on the same row.
  func testRequestAndClickProduceTheSameSelectionAndEvents() {
    let files = tree
    let requested = WindowState()
    let clicked = WindowState()

    request("chapter2.md", in: files, state: requested)
    click(files[1], state: clicked)

    XCTAssertEqual(requested.selectedFile, clicked.selectedFile)
    XCTAssertEqual(requested.events, clicked.events)
  }

  /// Expansion adds the ancestors; folders the user already opened stay open.
  func testRequestKeepsFoldersTheUserAlreadyExpanded() {
    let files = tree
    let state = WindowState()
    let unrelated = UUID()
    state.expandedFolders = [unrelated]

    request("book/part1/notes.md", in: files, state: state)

    XCTAssertEqual(state.expandedFolders, [unrelated, files[2].id, files[3].id])
  }

  func testRequestMovesTheSelectionFromOneFileToAnother() {
    let files = tree
    let state = WindowState()

    request("chapter1.md", in: files, state: state)
    request("chapter2.md", in: files, state: state)

    XCTAssertEqual(state.selectedFile, files[1])
    XCTAssertEqual(
      state.events,
      ["selected:chapter1.md", "loaded:chapter1.md", "selected:chapter2.md", "loaded:chapter2.md"])
  }

  /// An unknown path leaves the current selection standing and has no effect.
  func testRequestForUnknownPathLeavesTheSelectionStanding() {
    let files = tree
    let state = WindowState()
    request("chapter1.md", in: files, state: state)
    let before = state.events

    XCTAssertFalse(request("missing.md", in: files, state: state))

    XCTAssertEqual(state.selectedFile, files[0])
    XCTAssertEqual(state.expandedFolders, [])
    XCTAssertEqual(state.events, before)
  }

  /// A directory is not selectable, and is not expanded either.
  func testRequestForDirectoryLeavesTheSelectionStanding() {
    let files = tree
    let state = WindowState()
    request("chapter1.md", in: files, state: state)
    let before = state.events

    XCTAssertFalse(request("book/part1", in: files, state: state))

    XCTAssertEqual(state.selectedFile, files[0])
    XCTAssertEqual(state.expandedFolders, [])
    XCTAssertEqual(state.events, before)
  }

  /// Requesting the file that is already selected neither reports it again nor
  /// reloads it.
  func testRequestForTheSelectedFileDoesNothing() {
    let files = tree
    let state = WindowState()
    request("chapter2.md", in: files, state: state)
    let before = state.events

    XCTAssertFalse(request("chapter2.md", in: files, state: state))

    XCTAssertEqual(state.selectedFile, files[1])
    XCTAssertEqual(state.events, before)
  }

  /// An expected-but-missing file is in the tree, so a request selects it as a
  /// click on its row does: it is reported, routed to `onMissingFileSelected`,
  /// and never loaded.
  func testRequestForExpectedButMissingFileRoutesToTheMissingHandler() {
    let missing = ProjectFile(
      name: "CAST.md", relativePath: "CAST.md", fileExtension: "md",
      isDirectory: false, modifiedDate: Date(), isExpectedButMissing: true)
    let files = tree + [missing]
    let state = WindowState()

    XCTAssertTrue(request("CAST.md", in: files, state: state))

    XCTAssertEqual(state.selectedFile, missing)
    XCTAssertEqual(state.events, ["selected:CAST.md", "missing:CAST.md"])
  }

  /// With no `onFileSelection` or `onMissingFileSelected` supplied, selection
  /// still moves and a present file still loads.
  func testSelectWithoutConsumerCallbacksStillSelectsAndLoads() {
    let files = tree
    var selectedFile: ProjectFile?
    var loaded: [String] = []

    ProjectWindowSelection.select(
      files[0], selectedFile: &selectedFile,
      onFileSelection: nil, onMissingFileSelected: nil,
      loadContent: { loaded.append($0.relativePath) })

    XCTAssertEqual(selectedFile, files[0])
    XCTAssertEqual(loaded, ["chapter1.md"])
  }

  // MARK: - Action

  func testActionForwardsPathToItsHandler() {
    var received: [String] = []
    let action = ProjectFileSelectionAction { path in
      received.append(path)
    }

    action("chapter2.md")
    action("book/part1/notes.md")

    XCTAssertEqual(received, ["chapter2.md", "book/part1/notes.md"])
  }

  /// Outside a window's detail pane the environment default is a no-op: calling
  /// it must not crash or fail.
  func testDefaultEnvironmentActionIsSafeToCall() {
    let action = EnvironmentValues().selectProjectFile
    action("chapter2.md")
  }

  func testEnvironmentCarriesAssignedAction() {
    var received: String?
    var values = EnvironmentValues()
    values.selectProjectFile = ProjectFileSelectionAction { received = $0 }

    values.selectProjectFile("chapter1.md")

    XCTAssertEqual(received, "chapter1.md")
  }
}

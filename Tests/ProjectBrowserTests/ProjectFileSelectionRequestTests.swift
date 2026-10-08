import SwiftUI
import XCTest

@testable import ProjectBrowser

/// Tests for the host-driven selection request: the path resolver that
/// ``ProjectWindow`` uses to honour `selectProjectFile`, and the action itself.
///
/// The window's `@State` (selection, expansion) is private, so these tests cover
/// the pure lookup and the environment plumbing. The sidebar and detail behaviour
/// that the lookup feeds is exercised by the window in both layouts.
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

import XCTest
import SwiftUI

@testable import ProjectBrowser

final class ProjectFileTests: XCTestCase {

  // MARK: - Fixtures

  private func makeFile(
    id: UUID = UUID(),
    name: String = "outline.fountain",
    relativePath: String = "episodes/01/outline.fountain",
    fileExtension: String? = "fountain",
    isDirectory: Bool = false,
    modifiedDate: Date = Date(timeIntervalSince1970: 1_700_000_000),
    isLoaded: Bool = false,
    loadingState: FileLoadingState = .notLoaded,
    error: String? = nil
  ) -> ProjectFile {
    ProjectFile(
      id: id,
      name: name,
      relativePath: relativePath,
      fileExtension: fileExtension,
      isDirectory: isDirectory,
      modifiedDate: modifiedDate,
      isLoaded: isLoaded,
      loadingState: loadingState,
      error: error
    )
  }

  // MARK: - Test 1: ProjectFile Initialization (defaults)

  func testProjectFileInitializationWithDefaults() {
    let file = ProjectFile(
      name: "README.md",
      relativePath: "README.md",
      fileExtension: "md",
      isDirectory: false,
      modifiedDate: Date(timeIntervalSince1970: 0)
    )

    XCTAssertEqual(file.name, "README.md")
    XCTAssertEqual(file.relativePath, "README.md")
    XCTAssertEqual(file.fileExtension, "md")
    XCTAssertFalse(file.isDirectory)
    XCTAssertFalse(file.isLoaded)
    XCTAssertEqual(file.loadingState, .notLoaded)
    XCTAssertNil(file.error)
  }

  // MARK: - Test 2: ProjectFile Initialization (full property set, directory)

  func testProjectFileInitializationForDirectory() {
    let id = UUID()
    let modified = Date(timeIntervalSince1970: 1_650_000_000)
    let file = ProjectFile(
      id: id,
      name: "episodes",
      relativePath: "episodes",
      fileExtension: nil,
      isDirectory: true,
      modifiedDate: modified,
      isLoaded: false,
      loadingState: .notLoaded,
      error: nil
    )

    XCTAssertEqual(file.id, id)
    XCTAssertTrue(file.isDirectory)
    XCTAssertNil(file.fileExtension)
    XCTAssertEqual(file.modifiedDate, modified)
  }

  // MARK: - Test 3: ProjectFile Equality (same id and properties)

  func testProjectFileEqualityWithSameProperties() {
    let id = UUID()
    let date = Date(timeIntervalSince1970: 1_600_000_000)

    let file1 = makeFile(id: id, modifiedDate: date)
    let file2 = makeFile(id: id, modifiedDate: date)

    XCTAssertEqual(file1, file2)
  }

  // MARK: - Test 4: ProjectFile Inequality (different id)

  func testProjectFileInequalityWithDifferentId() {
    let date = Date(timeIntervalSince1970: 1_600_000_000)
    let file1 = makeFile(id: UUID(), modifiedDate: date)
    let file2 = makeFile(id: UUID(), modifiedDate: date)

    XCTAssertNotEqual(file1, file2)
  }

  // MARK: - Test 5: ProjectFile Inequality (different loadingState)

  func testProjectFileInequalityWithDifferentLoadingState() {
    let id = UUID()
    let date = Date(timeIntervalSince1970: 1_600_000_000)

    let file1 = makeFile(id: id, modifiedDate: date, loadingState: .notLoaded)
    let file2 = makeFile(id: id, modifiedDate: date, loadingState: .loaded)

    XCTAssertNotEqual(file1, file2)
  }

  // MARK: - Test 6: ProjectFile Hashing (usable as dictionary key / set member)

  func testProjectFileHashingAsDictionaryKey() {
    let id = UUID()
    let date = Date(timeIntervalSince1970: 1_600_000_000)
    let file1 = makeFile(id: id, modifiedDate: date)
    let file2 = makeFile(id: id, modifiedDate: date)

    var dict: [ProjectFile: String] = [:]
    dict[file1] = "first"
    dict[file2] = "second"  // should overwrite, since file1 == file2

    XCTAssertEqual(dict.count, 1)
    XCTAssertEqual(dict[file1], "second")

    var set: Set<ProjectFile> = []
    set.insert(file1)
    set.insert(file2)
    XCTAssertEqual(set.count, 1)
  }

  // MARK: - Test 7: ProjectFile.hasKnownHandler stub

  func testProjectFileHasKnownHandlerStubReturnsFalse() {
    let file = makeFile()
    XCTAssertFalse(file.hasKnownHandler)
  }

  // MARK: - Test 8: ProjectFile.displayName stub returns name unmodified

  func testProjectFileDisplayNameStubReturnsName() {
    let file = makeFile(name: "a-very-long-screenplay-filename-that-might-be-truncated.fountain")
    XCTAssertEqual(file.displayName, file.name)
  }

  // MARK: - Test 9: ProjectFile Codable round-trip

  func testProjectFileCodableRoundTrip() throws {
    let file = makeFile(loadingState: .error("disk read failed"), error: "disk read failed")

    let data = try JSONEncoder().encode(file)
    let decoded = try JSONDecoder().decode(ProjectFile.self, from: data)

    XCTAssertEqual(file, decoded)
  }

  // MARK: - Test 10: FileLoadingState — all cases distinguishable

  func testFileLoadingStateAllCases() {
    let states: [FileLoadingState] = [
      .notLoaded,
      .loading,
      .loaded,
      .stale,
      .error("boom"),
    ]

    // Every case should equal itself and no two distinct cases should be equal.
    for (i, lhs) in states.enumerated() {
      for (j, rhs) in states.enumerated() {
        if i == j {
          XCTAssertEqual(lhs, rhs, "state at \(i) should equal itself")
        } else {
          XCTAssertNotEqual(lhs, rhs, "state at \(i) should not equal state at \(j)")
        }
      }
    }
  }

  // MARK: - Test 11: FileLoadingState.error carries associated message

  func testFileLoadingStateErrorAssociatedValue() {
    let state = FileLoadingState.error("network timeout")
    guard case .error(let message) = state else {
      return XCTFail("Expected .error case")
    }
    XCTAssertEqual(message, "network timeout")

    // Different messages produce inequal states.
    XCTAssertNotEqual(FileLoadingState.error("a"), FileLoadingState.error("b"))
    XCTAssertEqual(FileLoadingState.error("a"), FileLoadingState.error("a"))
  }

  // MARK: - Test 12: FileLoadingState hashing and Codable round-trip

  func testFileLoadingStateHashingAndCodable() throws {
    var set: Set<FileLoadingState> = []
    set.insert(.notLoaded)
    set.insert(.loading)
    set.insert(.loaded)
    set.insert(.stale)
    set.insert(.error("x"))
    set.insert(.error("x"))  // duplicate, should not increase count
    XCTAssertEqual(set.count, 5)

    for state: FileLoadingState in [.notLoaded, .loading, .loaded, .stale, .error("oops")] {
      let data = try JSONEncoder().encode(state)
      let decoded = try JSONDecoder().decode(FileLoadingState.self, from: data)
      XCTAssertEqual(state, decoded)
    }
  }

  // MARK: - Test 13: ProjectFileContents initialization

  func testProjectFileContentsInitialization() {
    let file = makeFile(modifiedDate: Date(timeIntervalSince1970: 1_000))
    let loadedAt = Date(timeIntervalSince1970: 2_000)
    let contents = ProjectFileContents(
      file: file,
      data: nil,
      text: "INT. OFFICE - DAY",
      loadedAt: loadedAt
    )

    XCTAssertEqual(contents.file, file)
    XCTAssertNil(contents.data)
    XCTAssertEqual(contents.text, "INT. OFFICE - DAY")
    XCTAssertEqual(contents.loadedAt, loadedAt)
  }

  // MARK: - Test 14: ProjectFileContents.isStale — loaded after modification (fresh)

  func testProjectFileContentsIsStaleFalseWhenLoadedAfterModification() {
    let file = makeFile(modifiedDate: Date(timeIntervalSince1970: 1_000))
    let contents = ProjectFileContents(
      file: file,
      data: nil,
      text: "fresh",
      loadedAt: Date(timeIntervalSince1970: 2_000)
    )

    XCTAssertFalse(contents.isStale)
  }

  // MARK: - Test 15: ProjectFileContents.isStale — loaded before modification (stale)

  func testProjectFileContentsIsStaleTrueWhenLoadedBeforeModification() {
    let file = makeFile(modifiedDate: Date(timeIntervalSince1970: 5_000))
    let contents = ProjectFileContents(
      file: file,
      data: nil,
      text: "old",
      loadedAt: Date(timeIntervalSince1970: 1_000)
    )

    XCTAssertTrue(contents.isStale)
  }

  // MARK: - Test 16: ProjectFileContents default loadedAt and Codable round-trip

  func testProjectFileContentsDefaultLoadedAtAndCodable() throws {
    let file = makeFile()
    let contents = ProjectFileContents(file: file, data: Data([0x01, 0x02]), text: nil)
    XCTAssertNotNil(contents.loadedAt)

    let data = try JSONEncoder().encode(contents)
    let decoded = try JSONDecoder().decode(ProjectFileContents.self, from: data)
    XCTAssertEqual(contents, decoded)
  }

  // MARK: - Test 17: ProjectMetadata with optional fields absent

  func testProjectMetadataWithOnlyRequiredField() {
    let metadata = ProjectMetadata(title: "Confessions")

    XCTAssertEqual(metadata.title, "Confessions")
    XCTAssertNil(metadata.author)
    XCTAssertNil(metadata.description)
    XCTAssertNil(metadata.created)
  }

  // MARK: - Test 18: ProjectMetadata with all fields populated

  func testProjectMetadataWithAllFieldsPopulated() {
    let created = Date(timeIntervalSince1970: 1_234_567)
    let metadata = ProjectMetadata(
      title: "Confessions",
      author: "Tom Stovall",
      description: "A serialized audio drama.",
      created: created
    )

    XCTAssertEqual(metadata.title, "Confessions")
    XCTAssertEqual(metadata.author, "Tom Stovall")
    XCTAssertEqual(metadata.description, "A serialized audio drama.")
    XCTAssertEqual(metadata.created, created)
  }

  // MARK: - Test 19: ProjectMetadata equality and Codable round-trip

  func testProjectMetadataEqualityAndCodable() throws {
    let metadata1 = ProjectMetadata(title: "Same", author: "A")
    let metadata2 = ProjectMetadata(title: "Same", author: "A")
    let metadata3 = ProjectMetadata(title: "Different", author: "A")

    XCTAssertEqual(metadata1, metadata2)
    XCTAssertNotEqual(metadata1, metadata3)

    let data = try JSONEncoder().encode(metadata1)
    let decoded = try JSONDecoder().decode(ProjectMetadata.self, from: data)
    XCTAssertEqual(metadata1, decoded)
  }

  // MARK: - Test 20: FileAction — all built-in cases distinguishable

  func testFileActionAllCases() {
    let actions: [FileAction] = [.reload, .showInFinder, .delete, .custom("duplicate")]

    for (i, lhs) in actions.enumerated() {
      for (j, rhs) in actions.enumerated() {
        if i == j {
          XCTAssertEqual(lhs, rhs)
        } else {
          XCTAssertNotEqual(lhs, rhs)
        }
      }
    }
  }

  // MARK: - Test 21: FileAction.custom payload

  func testFileActionCustomPayload() {
    let action = FileAction.custom("archive")
    guard case .custom(let name) = action else {
      return XCTFail("Expected .custom case")
    }
    XCTAssertEqual(name, "archive")

    XCTAssertEqual(FileAction.custom("a"), FileAction.custom("a"))
    XCTAssertNotEqual(FileAction.custom("a"), FileAction.custom("b"))
  }

  // MARK: - Test 22: FileAction hashing and Codable round-trip

  func testFileActionHashingAndCodable() throws {
    var set: Set<FileAction> = [.reload, .showInFinder, .delete, .custom("x"), .custom("x")]
    XCTAssertEqual(set.count, 4)
    set.insert(.custom("y"))
    XCTAssertEqual(set.count, 5)

    for action: FileAction in [.reload, .showInFinder, .delete, .custom("dup")] {
      let data = try JSONEncoder().encode(action)
      let decoded = try JSONDecoder().decode(FileAction.self, from: data)
      XCTAssertEqual(action, decoded)
    }
  }

  // MARK: - Test 23: FileTypeHandler Identifiable conformance

  func testFileTypeHandlerIdentifiableConformance() {
    let handler = FileTypeHandler(fileExtension: "fountain") { file in
      AnyView(Text(file.name))
    }

    XCTAssertEqual(handler.id, "fountain")
    XCTAssertEqual(handler.id, handler.fileExtension)
  }

  // MARK: - Test 24: FileTypeHandler viewBuilder invocation

  func testFileTypeHandlerViewBuilderIsInvokedWithFile() {
    nonisolated(unsafe) var receivedFile: ProjectFile?
    let handler = FileTypeHandler(fileExtension: "md") { file in
      receivedFile = file
      return AnyView(EmptyView())
    }

    let file = makeFile(name: "notes.md", fileExtension: "md")
    _ = handler.viewBuilder(file)

    XCTAssertEqual(receivedFile, file)
  }

  // MARK: - Test 25: Callback typealias signatures compile and are invocable

  func testCallbackTypealiasSignatures() async throws {
    let file = makeFile()

    nonisolated(unsafe) var selected: ProjectFile?
    let onSelect: FileSelectionCallback = { selected = $0 }
    onSelect(file)
    XCTAssertEqual(selected, file)

    let loader: FileLoaderCallback = { file in
      ProjectFileContents(file: file, data: nil, text: "loaded", loadedAt: Date())
    }
    let contents = try await loader(file)
    XCTAssertEqual(contents.text, "loaded")

    nonisolated(unsafe) var receivedAction: FileAction?
    let onAction: FileActionCallback = { _, action in receivedAction = action }
    onAction(file, .reload)
    XCTAssertEqual(receivedAction, .reload)
  }
}

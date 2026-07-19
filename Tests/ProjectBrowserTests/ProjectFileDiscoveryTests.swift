import XCTest

@testable import ProjectBrowser

final class ProjectFileDiscoveryTests: XCTestCase {

  // MARK: - Fixture Management

  private var tempRoot: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ProjectFileDiscoveryTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    tempRoot = root
  }

  override func tearDownWithError() throws {
    if let tempRoot, FileManager.default.fileExists(atPath: tempRoot.path) {
      try? FileManager.default.removeItem(at: tempRoot)
    }
    tempRoot = nil
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  private func makeDirectory(_ relativePath: String) throws -> URL {
    let url = tempRoot.appendingPathComponent(relativePath, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @discardableResult
  private func makeFile(_ relativePath: String, contents: String = "test") throws -> URL {
    let url = tempRoot.appendingPathComponent(relativePath, isDirectory: false)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  // MARK: - Test 1: Empty directory

  func testDiscoverEmptyDirectoryReturnsEmptyArray() async throws {
    let files = try await ProjectFileDiscovery.discover(at: tempRoot)
    XCTAssertTrue(files.isEmpty)
  }

  // MARK: - Test 2: Flat directory (files only)

  func testDiscoverFlatDirectoryWithFilesOnly() async throws {
    try makeFile("b.txt")
    try makeFile("a.txt")
    try makeFile("c.md")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    XCTAssertEqual(files.count, 3)
    XCTAssertEqual(files.map(\.name), ["a.txt", "b.txt", "c.md"])
    XCTAssertTrue(files.allSatisfy { !$0.isDirectory })
  }

  // MARK: - Test 3: Nested directories, 5+ levels deep

  func testDiscoverNestedDirectoriesFiveLevelsDeep() async throws {
    try makeFile("l1/l2/l3/l4/l5/deep.txt")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    let names = files.map(\.name)
    XCTAssertEqual(names, ["l1", "l2", "l3", "l4", "l5", "deep.txt"])

    guard let deepFile = files.first(where: { $0.name == "deep.txt" }) else {
      return XCTFail("Expected to find deep.txt")
    }
    XCTAssertEqual(deepFile.relativePath, "l1/l2/l3/l4/l5/deep.txt")
    XCTAssertFalse(deepFile.isDirectory)

    guard let l3 = files.first(where: { $0.name == "l3" }) else {
      return XCTFail("Expected to find l3")
    }
    XCTAssertTrue(l3.isDirectory)
    XCTAssertEqual(l3.relativePath, "l1/l2/l3")
  }

  // MARK: - Test 4: Ignore patterns

  func testDiscoverIgnoresDefaultPatterns() async throws {
    try makeFile("README.md")
    try makeFile(".git/HEAD")
    try makeFile(".git/objects/pack/pack.idx")
    try makeFile("node_modules/left-pad/index.js")
    try makeFile(".build/debug/output")
    try makeFile(".swiftpm/config")
    try makeFile(".DS_Store")
    try makeDirectory("MyApp.xcodeproj")
    try makeFile("MyApp.xcodeproj/project.pbxproj")
    try makeFile("Generated.swiftdeps")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    XCTAssertEqual(files.map(\.name), ["README.md"])
    XCTAssertFalse(files.contains { $0.relativePath.hasPrefix(".git") })
    XCTAssertFalse(files.contains { $0.relativePath.hasPrefix("node_modules") })
    XCTAssertFalse(files.contains { $0.relativePath.hasPrefix(".build") })
    XCTAssertFalse(files.contains { $0.relativePath.hasPrefix(".swiftpm") })
    XCTAssertFalse(files.contains { $0.name == ".DS_Store" })
    XCTAssertFalse(files.contains { $0.relativePath.hasPrefix("MyApp.xcodeproj") })
    XCTAssertFalse(files.contains { $0.name == "Generated.swiftdeps" })
  }

  // MARK: - Test 5: Symlink handling

  func testDiscoverIgnoresSymlinks() async throws {
    try makeFile("real.txt")
    let targetDir = try makeDirectory("realDir")
    try makeFile("realDir/inside.txt")

    let symlinkFile = tempRoot.appendingPathComponent("link.txt")
    try FileManager.default.createSymbolicLink(
      at: symlinkFile, withDestinationURL: tempRoot.appendingPathComponent("real.txt"))

    let symlinkDir = tempRoot.appendingPathComponent("linkDir")
    try FileManager.default.createSymbolicLink(at: symlinkDir, withDestinationURL: targetDir)

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    let names = Set(files.map(\.name))
    XCTAssertTrue(names.contains("real.txt"))
    XCTAssertTrue(names.contains("realDir"))
    XCTAssertTrue(names.contains("inside.txt"))
    XCTAssertFalse(names.contains("link.txt"))
    XCTAssertFalse(names.contains("linkDir"))
  }

  // MARK: - Test 6: Sorting — folders first, then files, alphabetical

  func testDiscoverSortsFoldersFirstThenFilesAlphabetically() async throws {
    try makeFile("zebra.txt")
    try makeFile("apple.txt")
    try makeDirectory("Yankee")
    try makeDirectory("Bravo")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    XCTAssertEqual(files.map(\.name), ["Bravo", "Yankee", "apple.txt", "zebra.txt"])
    XCTAssertTrue(files[0].isDirectory)
    XCTAssertTrue(files[1].isDirectory)
    XCTAssertFalse(files[2].isDirectory)
    XCTAssertFalse(files[3].isDirectory)
  }

  // MARK: - Test 7: relativePath correctness for nested files

  func testRelativePathIsCorrectForNestedFile() async throws {
    try makeFile("subfolder/file.txt")
    try makeFile("top.txt")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    guard let nested = files.first(where: { $0.name == "file.txt" }) else {
      return XCTFail("Expected to find file.txt")
    }
    XCTAssertEqual(nested.relativePath, "subfolder/file.txt")

    guard let top = files.first(where: { $0.name == "top.txt" }) else {
      return XCTFail("Expected to find top.txt")
    }
    XCTAssertEqual(top.relativePath, "top.txt")

    guard let folder = files.first(where: { $0.name == "subfolder" }) else {
      return XCTFail("Expected to find subfolder")
    }
    XCTAssertEqual(folder.relativePath, "subfolder")
  }

  // MARK: - Test 8: fileExtension extraction

  func testFileExtensionExtraction() async throws {
    try makeFile("script.fountain")
    try makeFile("noext")
    try makeDirectory("folder")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    let script = files.first { $0.name == "script.fountain" }
    XCTAssertEqual(script?.fileExtension, "fountain")

    let noExt = files.first { $0.name == "noext" }
    XCTAssertNil(noExt?.fileExtension)

    let folder = files.first { $0.name == "folder" }
    XCTAssertNil(folder?.fileExtension)
  }

  // MARK: - Test 9: modifiedDate is retrieved from file attributes

  func testModifiedDateIsRetrievedFromFileAttributes() async throws {
    let fileURL = try makeFile("timed.txt")
    let expectedDate = Date(timeIntervalSince1970: 1_700_000_000)
    try FileManager.default.setAttributes(
      [.modificationDate: expectedDate], ofItemAtPath: fileURL.path)

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)
    guard let timed = files.first(where: { $0.name == "timed.txt" }) else {
      return XCTFail("Expected to find timed.txt")
    }

    XCTAssertEqual(
      timed.modifiedDate.timeIntervalSince1970, expectedDate.timeIntervalSince1970, accuracy: 1)
  }

  // MARK: - Test 10: Root directory itself is not included in results

  func testRootDirectoryItselfIsNotIncludedInResults() async throws {
    try makeFile("solo.txt")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    XCTAssertFalse(files.contains { $0.name == tempRoot.lastPathComponent })
    XCTAssertEqual(files.count, 1)
  }

  // MARK: - Test 11: Throws when root does not exist

  func testDiscoverThrowsWhenRootDoesNotExist() async {
    let missing = tempRoot.appendingPathComponent("does-not-exist", isDirectory: true)

    do {
      _ = try await ProjectFileDiscovery.discover(at: missing)
      XCTFail("Expected discover(at:) to throw for a non-existent directory")
    } catch {
      // Expected.
    }
  }

  // MARK: - Test 12: Mixed nested tree preserves depth-first grouping

  func testDiscoverGroupsSubdirectoryContentsTogether() async throws {
    try makeFile("a/one.txt")
    try makeFile("a/two.txt")
    try makeFile("b/three.txt")
    try makeFile("root.txt")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    XCTAssertEqual(
      files.map(\.name),
      ["a", "one.txt", "two.txt", "b", "three.txt", "root.txt"]
    )
  }
}

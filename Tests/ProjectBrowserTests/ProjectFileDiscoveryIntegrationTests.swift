import XCTest

@testable import ProjectBrowser

/// End-to-end integration tests for ``ProjectFileDiscovery`` and
/// ``ProjectMetadata/load(from:)`` working together against a realistic,
/// deeply-nested project directory — the kind of tree `ProjectWindow` is
/// actually pointed at in practice, rather than the narrow single-behavior
/// fixtures in `ProjectFileDiscoveryTests` and `ProjectMetadataTests`.
final class ProjectFileDiscoveryIntegrationTests: XCTestCase {

  // MARK: - Fixture Management

  private var tempRoot: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "ProjectFileDiscoveryIntegrationTests-\(UUID().uuidString)", isDirectory: true)
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

  @discardableResult
  private func makeDirectory(_ relativePath: String) throws -> URL {
    let url = tempRoot.appendingPathComponent(relativePath, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @discardableResult
  private func makeFile(_ relativePath: String, contents: String = "test", hidden: Bool = false)
    throws -> URL
  {
    let url = tempRoot.appendingPathComponent(relativePath, isDirectory: false)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, atomically: true, encoding: .utf8)
    if hidden {
      var resourceValues = URLResourceValues()
      resourceValues.isHidden = true
      var mutableURL = url
      try mutableURL.setResourceValues(resourceValues)
    }
    return url
  }

  private func buildRealisticProjectTree() throws {
    // Root-level PROJECT.md with metadata.
    try makeFile(
      "PROJECT.md",
      contents: """
        ---
        title: "Confessions"
        author: "Tom Stovall"
        description: "A serialized audio drama."
        created: 2026-01-15
        ---

        # Confessions

        Body content is ignored by metadata loading.
        """
    )

    // Root-level mixed files.
    try makeFile("README.md", contents: "# Confessions\n")
    try makeFile("Package.swift", contents: "// swift-tools-version: 6.2\n")
    try makeFile(".gitignore", contents: ".build/\n", hidden: true)

    // Sources tree, multiple file types.
    try makeFile(
      "Sources/Confessions/Models/Episode.swift", contents: "struct Episode {}\n")
    try makeFile(
      "Sources/Confessions/Models/Character.swift", contents: "struct Character {}\n")
    try makeFile(
      "Sources/Confessions/Services/AudioRenderer.swift",
      contents: "enum AudioRenderer {}\n")
    try makeFile(
      "Sources/Confessions/episodes/01/outline.fountain",
      contents: "Title: Episode 1\n")
    try makeFile(
      "Sources/Confessions/episodes/01/notes.txt", contents: "Draft notes.\n")
    try makeFile(
      "Sources/Confessions/episodes/01/assets/cover.json",
      contents: "{\"title\": \"Episode 1\"}\n")

    // Deeply nested directory — 6 levels below root, exercising the "5+
    // levels" requirement with room to spare.
    try makeFile(
      "Sources/Confessions/episodes/season1/arc1/episode01/scenes/scene01.fountain",
      contents: "INT. STUDIO - DAY\n")

    // Docs directory with markdown.
    try makeFile("Docs/ARCHITECTURE.md", contents: "# Architecture\n")
    try makeFile("Docs/reference/legacy-notes.md", contents: "# Legacy\n")

    // Ignored directories/files that must never appear in results.
    try makeFile(".git/HEAD", contents: "ref: refs/heads/main\n")
    try makeFile(".git/objects/pack/pack.idx", contents: "binary\n")
    try makeFile(".build/debug/output", contents: "binary\n")
    try makeFile(".swiftpm/config", contents: "{}\n")
    try makeFile("node_modules/left-pad/index.js", contents: "module.exports = {}\n")
    try makeFile(".DS_Store", contents: "binary\n")
    try makeDirectory("Confessions.xcodeproj")
    try makeFile("Confessions.xcodeproj/project.pbxproj", contents: "// pbxproj\n")
    try makeFile("Sources/Generated.swiftdeps", contents: "\n")

    // Hidden but non-ignored file — should still be discovered.
    try makeFile(".env.example", contents: "API_KEY=\n", hidden: true)
  }

  // MARK: - Full tree discovery + metadata

  func testDiscoversRealisticNestedProjectTree() async throws {
    try buildRealisticProjectTree()

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    // Non-ignored, non-directory entries we expect to find by relative path.
    let expectedFiles: Set<String> = [
      "PROJECT.md",
      "README.md",
      "Package.swift",
      ".gitignore",
      ".env.example",
      "Sources/Confessions/Models/Episode.swift",
      "Sources/Confessions/Models/Character.swift",
      "Sources/Confessions/Services/AudioRenderer.swift",
      "Sources/Confessions/episodes/01/outline.fountain",
      "Sources/Confessions/episodes/01/notes.txt",
      "Sources/Confessions/episodes/01/assets/cover.json",
      "Sources/Confessions/episodes/season1/arc1/episode01/scenes/scene01.fountain",
      "Docs/ARCHITECTURE.md",
      "Docs/reference/legacy-notes.md",
    ]

    let expectedDirectories: Set<String> = [
      "Sources",
      "Sources/Confessions",
      "Sources/Confessions/Models",
      "Sources/Confessions/Services",
      "Sources/Confessions/episodes",
      "Sources/Confessions/episodes/01",
      "Sources/Confessions/episodes/01/assets",
      "Sources/Confessions/episodes/season1",
      "Sources/Confessions/episodes/season1/arc1",
      "Sources/Confessions/episodes/season1/arc1/episode01",
      "Sources/Confessions/episodes/season1/arc1/episode01/scenes",
      "Docs",
      "Docs/reference",
    ]

    let discoveredFiles = Set(files.filter { !$0.isDirectory }.map(\.relativePath))
    let discoveredDirectories = Set(files.filter { $0.isDirectory }.map(\.relativePath))

    XCTAssertEqual(discoveredFiles, expectedFiles)
    XCTAssertEqual(discoveredDirectories, expectedDirectories)

    // Nothing from ignored trees leaked through. Match on full path
    // components (not a raw string prefix) so legitimate files like
    // `.gitignore` aren't mistaken for the ignored `.git` directory.
    for ignoredPrefix in [".git", ".build", ".swiftpm", "node_modules", "Confessions.xcodeproj"] {
      XCTAssertFalse(
        files.contains {
          $0.relativePath == ignoredPrefix || $0.relativePath.hasPrefix(ignoredPrefix + "/")
        },
        "Expected no entries under \(ignoredPrefix)")
    }
    XCTAssertFalse(files.contains { $0.name == ".DS_Store" })
    XCTAssertFalse(files.contains { $0.name == "Generated.swiftdeps" })

    XCTAssertEqual(files.count, expectedFiles.count + expectedDirectories.count)
  }

  func testDeeplyNestedFileSixLevelsDownHasCorrectPathAndIsFile() async throws {
    try buildRealisticProjectTree()

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    let deepRelativePath =
      "Sources/Confessions/episodes/season1/arc1/episode01/scenes/scene01.fountain"
    guard let deepFile = files.first(where: { $0.relativePath == deepRelativePath }) else {
      return XCTFail("Expected to find deeply nested scene01.fountain")
    }

    XCTAssertFalse(deepFile.isDirectory)
    XCTAssertEqual(deepFile.name, "scene01.fountain")
    XCTAssertEqual(deepFile.fileExtension, "fountain")

    // Every ancestor directory of the deep file must also be present and
    // correctly flagged as a directory.
    let ancestorPaths = [
      "Sources",
      "Sources/Confessions",
      "Sources/Confessions/episodes",
      "Sources/Confessions/episodes/season1",
      "Sources/Confessions/episodes/season1/arc1",
      "Sources/Confessions/episodes/season1/arc1/episode01",
      "Sources/Confessions/episodes/season1/arc1/episode01/scenes",
    ]
    XCTAssertEqual(ancestorPaths.count, 7, "Sanity check: fixture is 7 directories deep")

    for path in ancestorPaths {
      guard let dir = files.first(where: { $0.relativePath == path }) else {
        XCTFail("Expected ancestor directory \(path) to be discovered")
        continue
      }
      XCTAssertTrue(dir.isDirectory, "\(path) should be flagged as a directory")
    }
  }

  func testFileExtensionsExtractedAcrossVariedFileTypes() async throws {
    try buildRealisticProjectTree()

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)
    let extensionsByName = Dictionary(
      uniqueKeysWithValues: files.map { ($0.name, $0.fileExtension) })

    XCTAssertEqual(extensionsByName["Episode.swift"] ?? nil, "swift")
    XCTAssertEqual(extensionsByName["outline.fountain"] ?? nil, "fountain")
    XCTAssertEqual(extensionsByName["notes.txt"] ?? nil, "txt")
    XCTAssertEqual(extensionsByName["cover.json"] ?? nil, "json")
    XCTAssertEqual(extensionsByName["ARCHITECTURE.md"] ?? nil, "md")
    XCTAssertEqual(extensionsByName["PROJECT.md"] ?? nil, "md")
    // Directories never carry an extension, even when their basename
    // contains a dot-like pattern.
    XCTAssertNil(extensionsByName["Sources"] ?? nil)
  }

  func testFoldersSortBeforeFilesAtEveryLevelOfRealisticTree() async throws {
    try buildRealisticProjectTree()

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    // Group children by their parent directory (the relativePath minus the
    // last path component) and verify that within each group, all
    // directories precede all files in the flattened array's relative
    // ordering.
    func parent(of relativePath: String) -> String {
      let components = relativePath.split(separator: "/")
      guard components.count > 1 else { return "" }
      return components.dropLast().joined(separator: "/")
    }

    var indexByPath: [String: Int] = [:]
    for (index, file) in files.enumerated() {
      indexByPath[file.relativePath] = index
    }

    var childrenByParent: [String: [ProjectFile]] = [:]
    for file in files {
      childrenByParent[parent(of: file.relativePath), default: []].append(file)
    }

    for (_, children) in childrenByParent {
      let sortedByIndex = children.sorted { indexByPath[$0.relativePath]! < indexByPath[$1.relativePath]! }
      let lastDirectoryIndex = sortedByIndex.lastIndex(where: { $0.isDirectory })
      let firstFileIndex = sortedByIndex.firstIndex(where: { !$0.isDirectory })

      if let lastDir = lastDirectoryIndex, let firstFile = firstFileIndex {
        XCTAssertLessThan(
          lastDir, firstFile,
          "Expected all directories to sort before all files within the same parent")
      }
    }
  }

  // MARK: - PROJECT.md metadata loading alongside discovery

  func testLoadsProjectMetadataAlongsideDiscoveredFiles() async throws {
    try buildRealisticProjectTree()

    let root = tempRoot!
    let files = try await ProjectFileDiscovery.discover(at: root)
    let metadata = try await ProjectMetadata.load(from: root)

    XCTAssertFalse(files.isEmpty)

    let unwrapped = try XCTUnwrap(metadata, "Expected PROJECT.md to be parsed")
    XCTAssertEqual(unwrapped.title, "Confessions")
    XCTAssertEqual(unwrapped.author, "Tom Stovall")
    XCTAssertEqual(unwrapped.description, "A serialized audio drama.")
    XCTAssertNotNil(unwrapped.created)

    // PROJECT.md itself is discovered as a regular file alongside every
    // other project file — metadata loading doesn't exempt it from the walk.
    XCTAssertTrue(files.contains { $0.relativePath == "PROJECT.md" && !$0.isDirectory })
  }

  func testMetadataIsNilWhenNoProjectMDPresent() async throws {
    // A realistic tree, minus PROJECT.md.
    try makeFile("Sources/App/Main.swift", contents: "// entry point\n")
    try makeFile("README.md", contents: "# No metadata here\n")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)
    let metadata = try await ProjectMetadata.load(from: tempRoot)

    XCTAssertFalse(files.isEmpty)
    XCTAssertNil(metadata)
  }

  // MARK: - Discovery against SwiftProyecto's own source tree

  /// Discovers `Sources/ProjectBrowser` in the checked-out SwiftProyecto
  /// repository itself, verifying known files are found and that build
  /// artifacts (`.build`, `.git`, `.xcodeproj`) are excluded — a real,
  /// version-controlled tree rather than a synthetic fixture.
  func testDiscoversSwiftProyectoSourceTree() async throws {
    // #filePath for this test file is
    // <repoRoot>/Tests/ProjectBrowserTests/ProjectFileDiscoveryIntegrationTests.swift
    let thisFile = URL(fileURLWithPath: #filePath)
    let repoRoot =
      thisFile
      .deletingLastPathComponent()  // .../Tests/ProjectBrowserTests/
      .deletingLastPathComponent()  // .../Tests/
      .deletingLastPathComponent()  // repo root
    let sourcesRoot = repoRoot.appendingPathComponent(
      "Sources/ProjectBrowser", isDirectory: true)

    guard FileManager.default.fileExists(atPath: sourcesRoot.path) else {
      throw XCTSkip("Sources/ProjectBrowser not found relative to test file; skipping.")
    }

    let discoveredFiles = try await ProjectFileDiscovery.discover(at: sourcesRoot)

    let relativePaths = Set(discoveredFiles.map(\.relativePath))

    // Known source files that must be present.
    let expectedKnownFiles = [
      "Models/ProjectFile.swift",
      "Models/ProjectMetadata.swift",
      "Models/FileLoadingState.swift",
      "Models/FileTypeHandler.swift",
      "Models/FileAction.swift",
      "Models/ProjectFileContents.swift",
      "Services/ProjectFileDiscovery.swift",
    ]
    for expected in expectedKnownFiles {
      XCTAssertTrue(
        relativePaths.contains(expected),
        "Expected \(expected) to be discovered in Sources/ProjectBrowser")
    }

    // No build artifacts or VCS metadata should ever appear, even if this
    // repo checkout happens to contain them somewhere under Sources/.
    XCTAssertFalse(discoveredFiles.contains { $0.relativePath.contains(".xcodeproj") })
    XCTAssertFalse(discoveredFiles.contains { $0.relativePath.contains(".git/") })
    XCTAssertFalse(discoveredFiles.contains { $0.relativePath.contains(".build/") })

    // Every discovered .swift file should carry the "swift" extension.
    for file in discoveredFiles where !file.isDirectory && file.name.hasSuffix(".swift") {
      XCTAssertEqual(file.fileExtension, "swift")
    }
  }
}

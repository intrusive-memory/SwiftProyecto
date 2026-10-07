import SwiftUI
import XCTest

@testable import ProjectBrowser

/// Package bundles: a directory with a known extension (`.dossier`,
/// `.textbundle`, or anything the filesystem flags as a package) is one leaf
/// `ProjectFile` with `isBundle == true`, never descended into, rendered by
/// a handler for its extension and never lazily read as text.
@MainActor
final class ProjectBundleTests: XCTestCase {

  // MARK: - Fixture Management

  private var tempRoot: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ProjectBundleTests-\(UUID().uuidString)", isDirectory: true)
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
  private func makeFile(_ relativePath: String, contents: String = "test") throws -> URL {
    let url = tempRoot.appendingPathComponent(relativePath, isDirectory: false)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  /// A Personaje-shaped character bundle: manifest, bible, page, images, voice.
  private func makeDossier(_ name: String, under parent: String = "characters") throws {
    let base = "\(parent)/\(name).dossier"
    try makeFile("\(base)/manifest.json", contents: "{}")
    try makeFile("\(base)/CHARACTER.md", contents: "# \(name)")
    try makeFile("\(base)/dossier.html", contents: "<html></html>")
    try makeFile("\(base)/images/face.png", contents: "png")
    try makeFile("\(base)/voice/\(name).vox", contents: "vox")
  }

  private func bundleFile(
    name: String = "HUNTER.dossier",
    relativePath: String = "characters/HUNTER.dossier",
    fileExtension: String? = "dossier"
  ) -> ProjectFile {
    ProjectFile(
      name: name,
      relativePath: relativePath,
      fileExtension: fileExtension,
      isDirectory: false,
      modifiedDate: Date(timeIntervalSince1970: 0),
      isBundle: true
    )
  }

  // MARK: - Discovery

  func testDossierDirectoryIsDiscoveredAsOneLeafBundle() async throws {
    try makeDossier("HUNTER")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)
    let paths = files.map(\.relativePath)

    XCTAssertEqual(paths, ["characters", "characters/HUNTER.dossier"])

    let bundle = try XCTUnwrap(files.first { $0.name == "HUNTER.dossier" })
    XCTAssertTrue(bundle.isBundle)
    XCTAssertFalse(bundle.isDirectory, "a bundle is a leaf, not an expandable folder")
    XCTAssertEqual(bundle.fileExtension, "dossier", "the extension keys the handler registry")
    XCTAssertNil(bundle.fileSize, "a directory has no meaningful byte size")
  }

  func testNothingInsideABundleIsDiscovered() async throws {
    try makeDossier("RAY")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)

    XCTAssertFalse(files.contains { $0.relativePath.hasPrefix("characters/RAY.dossier/") })
    XCTAssertFalse(files.contains { $0.name == "manifest.json" })
    XCTAssertFalse(files.contains { $0.name == "face.png" })
  }

  func testBundlesSortWithFilesAfterFolders() async throws {
    // Mirrors granville/characters: a hidden folder, nine bundles, one html.
    try makeFile("characters/.generations/scenes/kitchen.json", contents: "{}")
    try makeDossier("ARCHER")
    try makeDossier("TOBY")
    try makeFile("characters/cast.html", contents: "<html></html>")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)
    let characters = files.filter { $0.relativePath.hasPrefix("characters/") }
      .filter { FileTreeView.parentPath(of: $0.relativePath) == "characters" }
      .map(\.name)

    XCTAssertEqual(
      characters, [".generations", "ARCHER.dossier", "cast.html", "TOBY.dossier"],
      "the real folder leads; bundles sort case-insensitively among the files")
  }

  func testTextBundleIsABundleByDefault() async throws {
    try makeFile("notes/Draft.textbundle/text.md", contents: "# Draft")
    try makeFile("notes/Draft.textbundle/info.json", contents: "{}")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)
    let bundle = try XCTUnwrap(files.first { $0.name == "Draft.textbundle" })

    XCTAssertTrue(bundle.isBundle)
    XCTAssertEqual(bundle.fileExtension, "textbundle")
    XCTAssertFalse(files.contains { $0.name == "text.md" })
  }

  func testBundleExtensionMatchingIgnoresCase() async throws {
    try makeFile("characters/JOANN.Dossier/manifest.json", contents: "{}")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)
    let bundle = try XCTUnwrap(files.first { $0.name == "JOANN.Dossier" })

    XCTAssertTrue(bundle.isBundle)
    XCTAssertFalse(files.contains { $0.name == "manifest.json" })
  }

  func testCustomBundleExtensionsReplaceTheDefault() async throws {
    try makeDossier("KEVIN")
    try makeFile("scenes/porch.scene/shots.json", contents: "{}")

    let files = try await ProjectFileDiscovery.discover(
      at: tempRoot, bundleExtensions: ["scene"])

    let scene = try XCTUnwrap(files.first { $0.name == "porch.scene" })
    XCTAssertTrue(scene.isBundle)
    XCTAssertFalse(files.contains { $0.name == "shots.json" })

    // `.dossier` is no longer in the set, so it is a plain folder again.
    let dossier = try XCTUnwrap(files.first { $0.name == "KEVIN.dossier" })
    XCTAssertFalse(dossier.isBundle)
    XCTAssertTrue(dossier.isDirectory)
    XCTAssertTrue(files.contains { $0.relativePath == "characters/KEVIN.dossier/manifest.json" })
  }

  func testEmptyBundleExtensionsTreatsDossierAsAFolder() async throws {
    try makeDossier("GARETH")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot, bundleExtensions: [])
    let dossier = try XCTUnwrap(files.first { $0.name == "GARETH.dossier" })

    XCTAssertFalse(dossier.isBundle)
    XCTAssertTrue(dossier.isDirectory)
    // manifest.json, CHARACTER.md, dossier.html, images/, images/face.png, voice/, voice/GARETH.vox
    XCTAssertEqual(
      files.filter { $0.relativePath.hasPrefix("characters/GARETH.dossier/") }.count, 7)
  }

  func testAPlainFileWithABundleExtensionIsStillAFile() async throws {
    try makeFile("characters/SHANE.dossier", contents: "not a directory")

    let files = try await ProjectFileDiscovery.discover(at: tempRoot)
    let file = try XCTUnwrap(files.first { $0.name == "SHANE.dossier" })

    XCTAssertFalse(file.isBundle)
    XCTAssertFalse(file.isDirectory)
    XCTAssertEqual(file.fileExtension, "dossier")
    XCTAssertNotNil(file.fileSize)
  }

  func testIgnoredSuffixesStillWinOverBundles() async throws {
    try makeFile("App.xcodeproj/project.pbxproj", contents: "// !$*UTF8*$!")

    let files = try await ProjectFileDiscovery.discover(
      at: tempRoot, bundleExtensions: ["xcodeproj"])

    XCTAssertTrue(files.isEmpty, ".xcodeproj is ignored before bundle detection runs")
  }

  func testIsBundlePredicateRequiresADirectory() throws {
    let directoryURL = try makeDirectory("X.dossier")
    let fileURL = try makeFile("Y.dossier")
    let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey]
    let directoryValues = try directoryURL.resourceValues(forKeys: keys)
    let fileValues = try fileURL.resourceValues(forKeys: keys)

    XCTAssertTrue(
      ProjectFileDiscovery.isBundle(
        directoryURL, values: directoryValues, bundleExtensions: ["dossier"]))
    XCTAssertFalse(
      ProjectFileDiscovery.isBundle(fileURL, values: fileValues, bundleExtensions: ["dossier"]),
      "a plain file never becomes a bundle, whatever its extension")
    // Only false when the filesystem itself does not already flag `.dossier`
    // as a package (it does once an app registers the type).
    if directoryValues.isPackage != true {
      XCTAssertFalse(
        ProjectFileDiscovery.isBundle(
          directoryURL, values: directoryValues, bundleExtensions: ["scene"]))
    }
  }

  // MARK: - Model

  func testProjectFileDefaultsToNotABundle() {
    let file = ProjectFile(
      name: "a.md", relativePath: "a.md", fileExtension: "md", isDirectory: false,
      modifiedDate: Date())
    XCTAssertFalse(file.isBundle)
  }

  func testBundleRoundTripsThroughCodable() throws {
    let bundle = bundleFile()

    let data = try JSONEncoder().encode(bundle)
    let decoded = try JSONDecoder().decode(ProjectFile.self, from: data)

    XCTAssertEqual(decoded, bundle)
    XCTAssertTrue(decoded.isBundle)
  }

  func testDecodingAPayloadWithoutIsBundleYieldsFalse() throws {
    // A ProjectFile encoded before `isBundle` existed.
    let legacy = """
      {
        "id": "00000000-0000-0000-0000-000000000001",
        "name": "outline.fountain",
        "relativePath": "episodes/outline.fountain",
        "fileExtension": "fountain",
        "isDirectory": false,
        "modifiedDate": 0,
        "isLoaded": false,
        "loadingState": {"notLoaded": {}},
        "isExpectedButMissing": false
      }
      """
    let decoded = try JSONDecoder().decode(ProjectFile.self, from: Data(legacy.utf8))

    XCTAssertEqual(decoded.name, "outline.fountain")
    XCTAssertFalse(decoded.isBundle)
  }

  func testWithLoadingStatePreservesIsBundle() {
    let bundle = bundleFile()
    let loading = bundle.withLoadingState(.loading)
    let errored = bundle.withLoadingState(.error("nope"))

    XCTAssertTrue(loading.isBundle)
    XCTAssertTrue(errored.isBundle)
    XCTAssertEqual(errored.error, "nope")
  }

  // MARK: - Tree

  func testBundleIsALeafInTheTree() {
    let characters = ProjectFile(
      name: "characters", relativePath: "characters", fileExtension: nil, isDirectory: true,
      modifiedDate: Date())
    let bundle = bundleFile()

    let tree = FileTreeView.buildTree(from: [characters, bundle])

    XCTAssertEqual(tree.count, 1)
    XCTAssertEqual(tree[0].children.count, 1)
    XCTAssertEqual(tree[0].children[0].file.name, "HUNTER.dossier")
    XCTAssertTrue(tree[0].children[0].children.isEmpty)
  }

  func testBundleIconNames() {
    XCTAssertEqual(
      FileTreeRowLabel.bundleIconName(forExtension: "dossier"), "person.crop.rectangle")
    XCTAssertEqual(
      FileTreeRowLabel.bundleIconName(forExtension: "DOSSIER"), "person.crop.rectangle")
    XCTAssertEqual(FileTreeRowLabel.bundleIconName(forExtension: "textbundle"), "doc.richtext")
    XCTAssertEqual(FileTreeRowLabel.bundleIconName(forExtension: "scene"), "shippingbox")
    XCTAssertEqual(FileTreeRowLabel.bundleIconName(forExtension: nil), "shippingbox")
  }

  // MARK: - Content loading

  func testBundlesAreNeverLazilyLoaded() {
    let bundle = bundleFile()

    XCTAssertFalse(
      ProjectFileContentLoader.shouldLoad(
        file: bundle, hasHandler: false, cache: [:], loadingFiles: []),
      "a bundle has no bytes of its own; only a handler can render it")

    let plain = ProjectFile(
      name: "a.md", relativePath: "a.md", fileExtension: "md", isDirectory: false,
      modifiedDate: Date())
    XCTAssertTrue(
      ProjectFileContentLoader.shouldLoad(
        file: plain, hasHandler: false, cache: [:], loadingFiles: []))
  }

  func testDefaultReloadOfABundleThrowsAClearError() async throws {
    try makeDossier("HUNTER")
    let bundle = bundleFile()

    do {
      _ = try await ProjectFileActionHandler.reload(file: bundle, in: tempRoot)
      XCTFail("expected reload to refuse a bundle")
    } catch let error as ProjectFileActionError {
      guard case .underlying(let message) = error else {
        return XCTFail("expected .underlying, got \(error)")
      }
      XCTAssertTrue(message.contains("characters/HUNTER.dossier"))
      XCTAssertTrue(message.contains(".dossier package"))
    }
  }

  func testConsumerLoaderStillRunsForABundle() async throws {
    let bundle = bundleFile()
    let expected = ProjectFileContents(file: bundle, data: Data("page".utf8), text: "page")

    let contents = try await ProjectFileActionHandler.reload(
      file: bundle, in: tempRoot, contentLoader: { _ in expected })

    XCTAssertEqual(contents.text, "page")
  }

  // MARK: - Detail pane routing

  func testBundleWithHandlerRoutesToHandler() {
    let pane = ProjectDetailPane(
      selectedFile: bundleFile(),
      handlers: ["dossier": { _ in AnyView(Text("dossier page")) }])

    XCTAssertEqual(pane.contentRoute(for: bundleFile()), .handler)
  }

  func testBundleWithoutHandlerRoutesToBundleView() {
    let bundle = bundleFile()
    let pane = ProjectDetailPane(selectedFile: bundle, handlers: [:])

    XCTAssertEqual(pane.contentRoute(for: bundle), .bundle)
  }

  func testBundleRouteWinsOverLoadingAndErrorState() {
    let bundle = bundleFile()

    let loading = ProjectDetailPane(selectedFile: bundle, handlers: [:], isLoadingContent: true)
    XCTAssertEqual(loading.contentRoute(for: bundle), .bundle)

    let errored = ProjectDetailPane(selectedFile: bundle, handlers: [:], loadError: "boom")
    XCTAssertEqual(errored.contentRoute(for: bundle), .bundle)
  }

  func testBundleWithFilenameHandlerRoutesToHandler() {
    let bundle = bundleFile()
    let pane = ProjectDetailPane(
      selectedFile: bundle,
      handlers: ["HUNTER.dossier": { _ in AnyView(Text("just Hunter")) }])

    XCTAssertEqual(pane.contentRoute(for: bundle), .handler)
  }
}

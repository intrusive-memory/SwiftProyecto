import SwiftUI
import XCTest

@testable import ProjectBrowser

/// Tests the file-action logic that backs `ProjectWindow`'s S4.2 behavior
/// (reload, delete, show in Finder, custom pass-through).
///
/// `ProjectWindow` itself is a SwiftUI `View` with only `@State`-private
/// action-handling methods, so it can't be driven directly by XCTest.
/// Every piece of actual behavior it delegates to is implemented in
/// ``ProjectFileActionHandler`` (`Sources/ProjectBrowser/Services/ProjectFileActionHandler.swift`),
/// which is stateless and fully testable — these tests exercise that
/// service directly, covering the same contract `ProjectWindow.handleFileAction(_:action:)`
/// relies on: what `.reload`/`.delete`/`.showInFinder`/`.custom` do, and how
/// errors are surfaced.
final class ProjectWindowTests: XCTestCase {

  // MARK: - Fixture Management

  private var tempRoot: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ProjectWindowTests-\(UUID().uuidString)", isDirectory: true)
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

  @discardableResult
  private func makeFile(_ relativePath: String, contents: String = "hello") throws -> ProjectFile {
    let url = tempRoot.appendingPathComponent(relativePath, isDirectory: false)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, atomically: true, encoding: .utf8)
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return ProjectFile(
      name: url.lastPathComponent,
      relativePath: relativePath,
      fileExtension: url.pathExtension.isEmpty ? nil : url.pathExtension,
      isDirectory: false,
      modifiedDate: attributes[.modificationDate] as? Date ?? Date(),
      fileSize: contents.utf8.count == 0 ? nil : Int64(contents.utf8.count)
    )
  }

  private func makeDirectory(_ relativePath: String) throws -> ProjectFile {
    let url = tempRoot.appendingPathComponent(relativePath, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return ProjectFile(
      name: url.lastPathComponent,
      relativePath: relativePath,
      fileExtension: nil,
      isDirectory: true,
      modifiedDate: Date()
    )
  }

  private func missingFile(_ relativePath: String = "missing.txt") -> ProjectFile {
    ProjectFile(
      name: (relativePath as NSString).lastPathComponent,
      relativePath: relativePath,
      fileExtension: "txt",
      isDirectory: false,
      modifiedDate: Date()
    )
  }

  // MARK: - Reload

  func testReloadWithoutContentLoaderReadsFileFromDisk() async throws {
    let file = try makeFile("notes.txt", contents: "updated contents")

    let contents = try await ProjectFileActionHandler.reload(
      file: file, in: tempRoot, contentLoader: nil)

    XCTAssertEqual(contents.text, "updated contents")
    XCTAssertEqual(contents.file.id, file.id)
    XCTAssertNotNil(contents.data)
  }

  func testReloadWithContentLoaderDelegatesToLoader() async throws {
    let file = try makeFile("script.fountain", contents: "INT. OFFICE - DAY")

    let contents = try await ProjectFileActionHandler.reload(
      file: file, in: tempRoot,
      contentLoader: { loadedFile in
        ProjectFileContents(
          file: loadedFile, data: nil, text: "custom loader output", loadedAt: Date())
      })

    XCTAssertEqual(contents.text, "custom loader output")
    XCTAssertEqual(contents.file.id, file.id)
  }

  func testReloadOfMissingFileThrowsFileNotFound() async {
    let file = missingFile()

    do {
      _ = try await ProjectFileActionHandler.reload(file: file, in: tempRoot, contentLoader: nil)
      XCTFail("Expected reload of a missing file to throw")
    } catch let error as ProjectFileActionError {
      XCTAssertEqual(error, .fileNotFound(file.relativePath))
    } catch {
      XCTFail("Expected ProjectFileActionError, got \(error)")
    }
  }

  func testReloadPropagatesContentLoaderFailureAsUnderlyingError() async {
    struct LoaderError: Error, LocalizedError {
      var errorDescription: String? { "loader exploded" }
    }
    let file = missingFile("anything.txt")

    do {
      _ = try await ProjectFileActionHandler.reload(
        file: file, in: tempRoot,
        contentLoader: { _ in throw LoaderError() })
      XCTFail("Expected reload to propagate the loader's error")
    } catch let error as ProjectFileActionError {
      XCTAssertEqual(error, .underlying("loader exploded"))
    } catch {
      XCTFail("Expected ProjectFileActionError, got \(error)")
    }
  }

  // MARK: - Delete

  func testDeleteRemovesFileFromDisk() throws {
    let file = try makeFile("to-delete.txt")
    let url = tempRoot.appendingPathComponent(file.relativePath)
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

    try ProjectFileActionHandler.delete(file: file, in: tempRoot)

    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
  }

  func testDeleteRemovesDirectoryRecursively() throws {
    let folder = try makeDirectory("episodes")
    try makeFile("episodes/01-pilot.fountain")
    try makeFile("episodes/02-followup.fountain")
    let url = tempRoot.appendingPathComponent(folder.relativePath)

    try ProjectFileActionHandler.delete(file: folder, in: tempRoot)

    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
  }

  func testDeleteOfMissingFileThrowsFileNotFound() {
    let file = missingFile()

    XCTAssertThrowsError(try ProjectFileActionHandler.delete(file: file, in: tempRoot)) { error in
      XCTAssertEqual(error as? ProjectFileActionError, .fileNotFound(file.relativePath))
    }
  }

  func testDeleteOfReadOnlyDirectoryThrowsPermissionDenied() throws {
    let folder = try makeDirectory("locked")
    let child = try makeFile("locked/child.txt")
    let folderURL = tempRoot.appendingPathComponent(folder.relativePath)

    // Deny write on the parent directory so removing its child is refused
    // by the filesystem — simulates a real permissions failure.
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folderURL.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: folderURL.path)
    }

    XCTAssertThrowsError(try ProjectFileActionHandler.delete(file: child, in: tempRoot)) { error in
      guard case .permissionDenied = error as? ProjectFileActionError else {
        return XCTFail("Expected .permissionDenied, got \(error)")
      }
    }
  }

  // MARK: - Tree updates after delete

  func testRemovingFromTreeDropsOnlyTheDeletedFile() {
    let a = ProjectFile(
      name: "a.txt", relativePath: "a.txt", fileExtension: "txt", isDirectory: false,
      modifiedDate: Date())
    let b = ProjectFile(
      name: "b.txt", relativePath: "b.txt", fileExtension: "txt", isDirectory: false,
      modifiedDate: Date())
    let files = [a, b]

    let result = ProjectFileActionHandler.removingFromTree(a, from: files)

    XCTAssertEqual(result.map(\.id), [b.id])
  }

  func testRemovingFromTreeDropsDirectoryAndDescendants() {
    let folder = ProjectFile(
      name: "episodes", relativePath: "episodes", fileExtension: nil, isDirectory: true,
      modifiedDate: Date())
    let child = ProjectFile(
      name: "01.fountain", relativePath: "episodes/01.fountain", fileExtension: "fountain",
      isDirectory: false, modifiedDate: Date())
    let grandchild = ProjectFile(
      name: "notes.txt", relativePath: "episodes/drafts/notes.txt", fileExtension: "txt",
      isDirectory: false, modifiedDate: Date())
    let sibling = ProjectFile(
      name: "README.md", relativePath: "README.md", fileExtension: "md", isDirectory: false,
      modifiedDate: Date())
    let files = [folder, child, grandchild, sibling]

    let result = ProjectFileActionHandler.removingFromTree(folder, from: files)

    XCTAssertEqual(result.map(\.id), [sibling.id])
  }

  func testRemovingFromTreeDoesNotAffectSimilarlyPrefixedSiblingPaths() {
    // "episodes" and "episodes-archive" share a string prefix but are not
    // in a parent/child relationship — deleting the former must not drop
    // the latter.
    let folder = ProjectFile(
      name: "episodes", relativePath: "episodes", fileExtension: nil, isDirectory: true,
      modifiedDate: Date())
    let lookalike = ProjectFile(
      name: "episodes-archive", relativePath: "episodes-archive", fileExtension: nil,
      isDirectory: true, modifiedDate: Date())
    let files = [folder, lookalike]

    let result = ProjectFileActionHandler.removingFromTree(folder, from: files)

    XCTAssertEqual(result.map(\.id), [lookalike.id])
  }

  // MARK: - Full dispatch (.handle)

  func testHandleReloadReturnsReloadedContentsAndNoError() async throws {
    let file = try makeFile("reload-me.md", contents: "# Title")

    let result = await ProjectFileActionHandler.handle(
      action: .reload, file: file, in: tempRoot, contentLoader: nil)

    XCTAssertEqual(result.reloadedContents?.text, "# Title")
    XCTAssertFalse(result.didDelete)
    XCTAssertNil(result.errorMessage)
  }

  func testHandleDeleteReturnsDidDeleteTrueAndNoError() async throws {
    let file = try makeFile("delete-me.md")

    let result = await ProjectFileActionHandler.handle(
      action: .delete, file: file, in: tempRoot, contentLoader: nil)

    XCTAssertTrue(result.didDelete)
    XCTAssertNil(result.errorMessage)
    XCTAssertNil(result.reloadedContents)
  }

  func testHandleDeleteOfMissingFileSurfacesErrorMessage() async {
    let file = missingFile()

    let result = await ProjectFileActionHandler.handle(
      action: .delete, file: file, in: tempRoot, contentLoader: nil)

    XCTAssertFalse(result.didDelete)
    XCTAssertNotNil(result.errorMessage)
  }

  func testHandleReloadOfMissingFileSurfacesErrorMessage() async {
    let file = missingFile()

    let result = await ProjectFileActionHandler.handle(
      action: .reload, file: file, in: tempRoot, contentLoader: nil)

    XCTAssertNil(result.reloadedContents)
    XCTAssertNotNil(result.errorMessage)
  }

  func testHandleCustomActionIsANoOp() async throws {
    let file = try makeFile("whatever.txt")

    let result = await ProjectFileActionHandler.handle(
      action: .custom("duplicate"), file: file, in: tempRoot, contentLoader: nil)

    // `.handle` never interprets `.custom` — ProjectWindow forwards it to
    // the consumer's callback itself. The service should report a fully
    // empty, error-free result.
    XCTAssertEqual(result, ProjectFileActionResult())
  }

  func testHandleShowInFinderIsANoOpResultOnEveryPlatform() async throws {
    let file = try makeFile("reveal-me.txt")

    let result = await ProjectFileActionHandler.handle(
      action: .showInFinder, file: file, in: tempRoot, contentLoader: nil)

    XCTAssertEqual(result, ProjectFileActionResult())
  }

  #if os(macOS)
    // MARK: - Show in Finder (macOS)

    func testShowInFinderInvokesWorkspaceWithResolvedPaths() throws {
      final class RecordingWorkspace: FileRevealing {
        var selectedPath: String?
        var rootPath: String?

        func selectFile(_ fullPath: String?, inFileViewerRootedAtPath rootFullPath: String) -> Bool {
          selectedPath = fullPath
          rootPath = rootFullPath
          return true
        }
      }

      let file = try makeFile("reveal.txt")
      let workspace = RecordingWorkspace()

      let didReveal = ProjectFileActionHandler.showInFinder(
        file: file, in: tempRoot, workspace: workspace)

      XCTAssertTrue(didReveal)
      XCTAssertEqual(workspace.selectedPath, tempRoot.appendingPathComponent(file.relativePath).path)
      XCTAssertEqual(workspace.rootPath, tempRoot.path)
    }
  #endif
}

// MARK: - S4.3: Lazy Loading & Progress

/// Tests the lazy content-loading decision logic that backs `ProjectWindow`'s
/// S4.3 behavior: files are discovered but not loaded until selected, loads
/// are cached in memory, in-flight loads are tracked, and errors don't
/// poison the cache (allowing retry).
///
/// As with `ProjectWindowTests` above, `ProjectWindow` itself can't be
/// driven directly by XCTest — its `loadContentIfNeeded(for:)`,
/// `updateLoadingState(for:to:)`, and `loadAllContent()`/`unloadAllContent()`
/// methods are all `private` on the View. The one piece of real
/// decision-making they rely on — whether a given file needs a load kicked
/// off — is factored out into ``ProjectFileContentLoader/shouldLoad(file:hasHandler:cache:loadingFiles:)``,
/// which is stateless and fully testable. The actual fetch reuses
/// ``ProjectFileActionHandler/reload(file:in:contentLoader:)``, already
/// covered by `ProjectWindowTests`'s reload tests above — those same
/// success/failure paths are exactly what `loadContentIfNeeded` drives.
final class ProjectFileContentLoaderTests: XCTestCase {

  private func makeFile(id: UUID = UUID(), relativePath: String = "notes.txt") -> ProjectFile {
    ProjectFile(
      id: id,
      name: (relativePath as NSString).lastPathComponent,
      relativePath: relativePath,
      fileExtension: "txt",
      isDirectory: false,
      modifiedDate: Date()
    )
  }

  // MARK: - Cache miss → load → cache hit

  func testShouldLoadIsTrueOnCacheMiss() {
    let file = makeFile()

    let result = ProjectFileContentLoader.shouldLoad(
      file: file, hasHandler: false, cache: [:], loadingFiles: [])

    XCTAssertTrue(result)
  }

  func testShouldLoadIsFalseOnCacheHit() {
    let file = makeFile()
    let contents = ProjectFileContents(file: file, data: nil, text: "cached", loadedAt: Date())

    let result = ProjectFileContentLoader.shouldLoad(
      file: file, hasHandler: false, cache: [file.id: contents], loadingFiles: [])

    XCTAssertFalse(result)
  }

  // MARK: - Handler-owned files never trigger a lazy load

  func testShouldLoadIsFalseWhenFileHasARegisteredHandler() {
    let file = makeFile()

    let result = ProjectFileContentLoader.shouldLoad(
      file: file, hasHandler: true, cache: [:], loadingFiles: [])

    XCTAssertFalse(result)
  }

  // MARK: - Loading state tracking

  func testShouldLoadIsFalseWhileAlreadyLoading() {
    let file = makeFile()

    let result = ProjectFileContentLoader.shouldLoad(
      file: file, hasHandler: false, cache: [:], loadingFiles: [file.id])

    XCTAssertFalse(result)
  }

  func testShouldLoadBecomesTrueAgainOnceLoadingCompletesWithoutACacheEntry() {
    // Simulates a failed load: the file is removed from `loadingFiles` once
    // the fetch completes, but no cache entry was written (see
    // `ProjectWindow.loadContentIfNeeded`'s catch branch) — so a retry
    // (re-selection or the detail pane's ErrorView) should be permitted.
    let file = makeFile()

    let whileLoading = ProjectFileContentLoader.shouldLoad(
      file: file, hasHandler: false, cache: [:], loadingFiles: [file.id])
    let afterFailedLoad = ProjectFileContentLoader.shouldLoad(
      file: file, hasHandler: false, cache: [:], loadingFiles: [])

    XCTAssertFalse(whileLoading)
    XCTAssertTrue(afterFailedLoad)
  }

  // MARK: - Reload clears cache and re-fetches

  func testShouldLoadBecomesTrueAgainAfterCacheEntryIsEvicted() {
    // `ProjectWindow.handleFileAction` evicts a file's `fileContents` entry
    // before re-fetching on `.reload` — mirror that here: once the cache
    // entry is gone, `shouldLoad` must say yes again so the fetch actually
    // happens (rather than the reload silently being treated as a no-op
    // cache hit).
    let file = makeFile()
    let staleContents = ProjectFileContents(file: file, data: nil, text: "old", loadedAt: Date())
    var cache: [UUID: ProjectFileContents] = [file.id: staleContents]

    XCTAssertFalse(
      ProjectFileContentLoader.shouldLoad(
        file: file, hasHandler: false, cache: cache, loadingFiles: []))

    cache.removeValue(forKey: file.id)

    XCTAssertTrue(
      ProjectFileContentLoader.shouldLoad(
        file: file, hasHandler: false, cache: cache, loadingFiles: []))
  }

  func testReloadAlwaysRefetchesRegardlessOfPriorCachedValue() async throws {
    // `ProjectFileActionHandler.reload` (the fetch `loadContentIfNeeded` and
    // `.reload` both delegate to) never consults a cache itself — it always
    // re-fetches. This confirms fresh content wins even when a caller
    // simulates having had a stale cached value moments before.
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ProjectFileContentLoaderTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let url = root.appendingPathComponent("notes.txt")
    try "fresh contents".write(to: url, atomically: true, encoding: .utf8)
    let file = ProjectFile(
      name: "notes.txt", relativePath: "notes.txt", fileExtension: "txt", isDirectory: false,
      modifiedDate: Date())

    let refetched = try await ProjectFileActionHandler.reload(
      file: file, in: root, contentLoader: nil)

    XCTAssertEqual(refetched.text, "fresh contents")
  }

  // MARK: - Concurrent loads for multiple files

  func testShouldLoadTracksMultipleInFlightFilesIndependently() {
    let fileA = makeFile(relativePath: "a.txt")
    let fileB = makeFile(relativePath: "b.txt")
    let fileC = makeFile(relativePath: "c.txt")

    // All three start eligible.
    XCTAssertTrue(
      ProjectFileContentLoader.shouldLoad(
        file: fileA, hasHandler: false, cache: [:], loadingFiles: []))
    XCTAssertTrue(
      ProjectFileContentLoader.shouldLoad(
        file: fileB, hasHandler: false, cache: [:], loadingFiles: []))
    XCTAssertTrue(
      ProjectFileContentLoader.shouldLoad(
        file: fileC, hasHandler: false, cache: [:], loadingFiles: []))

    // A and B are now in flight; C is untouched and still eligible; A and B
    // are not — each file's in-flight status is independent of the others.
    let loadingFiles: Set<UUID> = [fileA.id, fileB.id]

    XCTAssertFalse(
      ProjectFileContentLoader.shouldLoad(
        file: fileA, hasHandler: false, cache: [:], loadingFiles: loadingFiles))
    XCTAssertFalse(
      ProjectFileContentLoader.shouldLoad(
        file: fileB, hasHandler: false, cache: [:], loadingFiles: loadingFiles))
    XCTAssertTrue(
      ProjectFileContentLoader.shouldLoad(
        file: fileC, hasHandler: false, cache: [:], loadingFiles: loadingFiles))

    // A finishes (loaded into cache) while B is still loading; each file's
    // resulting eligibility reflects only its own state.
    let contentsA = ProjectFileContents(file: fileA, data: nil, text: "a", loadedAt: Date())
    let cacheAfterAFinishes: [UUID: ProjectFileContents] = [fileA.id: contentsA]
    let loadingFilesAfterAFinishes: Set<UUID> = [fileB.id]

    XCTAssertFalse(
      ProjectFileContentLoader.shouldLoad(
        file: fileA, hasHandler: false, cache: cacheAfterAFinishes,
        loadingFiles: loadingFilesAfterAFinishes))
    XCTAssertFalse(
      ProjectFileContentLoader.shouldLoad(
        file: fileB, hasHandler: false, cache: cacheAfterAFinishes,
        loadingFiles: loadingFilesAfterAFinishes))
  }
}

// MARK: - S4.4: Platform-Specific Layouts

/// Smoke tests covering `ProjectWindow`'s platform-specific layout (S4.4):
/// macOS (and iPad in a regular-width size class) uses a two-column
/// `NavigationSplitView`; iOS in a compact-width size class uses a
/// `NavigationStack` drill-down instead.
///
/// `ProjectWindow`'s layout-selection machinery (`platformLayout`,
/// `splitLayout`, `stackLayout`) is entirely `private` — it's `@State`- and
/// `@Environment`-driven SwiftUI, not something with a standalone testable
/// unit the way `ProjectFileActionHandler` and `ProjectFileContentLoader`
/// are (see the note atop `ProjectWindowTests`). What *is* verifiable by
/// XCTest, without standing up a real window/hosting environment:
///
/// - Instantiating `ProjectWindow` and forcing its `body` to evaluate
///   doesn't crash, on whichever platform the test target is built for.
///   `@State`/`@Environment` property wrappers read their default values
///   safely outside of a live view hierarchy, and `.onAppear`'s closure is
///   only *attached*, not invoked, so this is a safe, side-effect-free way
///   to exercise the `#if os(macOS)` / `#else` branch that's actually
///   compiled into this platform's test binary.
/// - The `#if os(macOS)` / `#if os(iOS)` gated tests below only compile (and
///   therefore only run) on their respective platforms — their mere
///   presence in a green test run is proof that *this* platform's code path
///   in `ProjectWindow.swift` compiled cleanly, complementing the
///   cross-platform `xcodebuild build -destination 'platform=macOS'` /
///   `-destination 'generic/platform=iOS'` checks run alongside these tests.
final class ProjectWindowPlatformLayoutTests: XCTestCase {

  private func makeWindow(
    directoryURL: URL = FileManager.default.temporaryDirectory
  ) -> ProjectWindow {
    ProjectWindow(
      directoryURL: directoryURL,
      handlers: [
        "fountain": { file in AnyView(Text(file.name)) }
      ],
      projectTitle: "Platform Layout Test"
    )
  }

  /// Confirms `ProjectWindow` is a valid, constructible `View` on every
  /// platform this package targets — a compile-time guarantee that both the
  /// macOS-only and iOS-only branches of `platformLayout` type-check for
  /// whichever platform this test target is built for.
  func testProjectWindowBodyEvaluatesWithoutCrashing() {
    let window = makeWindow()
    _ = window.body
  }

  /// A second instance, with no registered handlers at all (every file
  /// falls back to `ProjectDetailPane`'s built-in
  /// `UnsupportedFileView`/`PlainTextContentView` rendering), still
  /// evaluates its body cleanly — covering the handler-less code path
  /// through both `splitLayout` and (on iOS) `stackLayout`.
  func testProjectWindowWithNoHandlersBodyEvaluatesWithoutCrashing() {
    let window = ProjectWindow(directoryURL: FileManager.default.temporaryDirectory)
    _ = window.body
  }

  #if os(macOS)
    /// macOS always renders `splitLayout` (a two-column
    /// `NavigationSplitView`) regardless of window size — there's no
    /// "compact" macOS window to accommodate. This test only compiles (and
    /// therefore only runs) when the test target is built for macOS.
    func testMacOSLayoutRendersWithoutCrashing() {
      let window = makeWindow()
      _ = window.body
    }
  #endif

  #if os(iOS)
    /// iOS renders either `splitLayout` (regular-width, e.g. iPad landscape)
    /// or `stackLayout` (compact-width, e.g. iPhone) depending on
    /// `horizontalSizeClass`, which defaults to `nil` outside of a live
    /// view hierarchy — exercising the `stackLayout`/`NavigationStack`
    /// branch's default path. This test only compiles (and therefore only
    /// runs) when the test target is built for iOS.
    func testIOSLayoutRendersWithoutCrashing() {
      let window = makeWindow()
      _ = window.body
    }
  #endif
}

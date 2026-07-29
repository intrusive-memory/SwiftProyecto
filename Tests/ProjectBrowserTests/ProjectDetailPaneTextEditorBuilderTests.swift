import SwiftUI
import XCTest

@testable import ProjectBrowser

/// Tests `ProjectWindow`/`ProjectDetailPane`'s `textEditorBuilder:` override —
/// the consumer-supplied replacement for the built-in
/// ``EditableTextContentView``.
///
/// The contract under test has three halves:
///
/// 1. **Every** handler-less file whose bytes decode as UTF-8 reaches the
///    builder — including files the naive "look at the extension" test misses,
///    like `Makefile`, `LICENSE`, and `.zshrc`, and files with an extension
///    nobody has ever registered. `ProjectBrowser`'s classifier is the decode
///    itself, and this sortie changed only where that branch goes.
/// 2. When a builder is supplied, ``EditableTextContentView`` is not
///    constructed at all — asserted against its construction witness, since a
///    SwiftUI body can't be introspected after the fact.
/// 3. With no builder, the built-in editor is still what runs. That is the
///    source-compatibility guarantee for every existing consumer.
@MainActor
final class ProjectDetailPaneTextEditorBuilderTests: XCTestCase {

  // MARK: - Fixture Management

  private var tempRoot: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "ProjectDetailPaneTextEditorBuilderTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    tempRoot = root
    EditableTextContentView.resetConstructionCount()
  }

  override func tearDownWithError() throws {
    if let tempRoot, FileManager.default.fileExists(atPath: tempRoot.path) {
      try? FileManager.default.removeItem(at: tempRoot)
    }
    tempRoot = nil
    try super.tearDownWithError()
  }

  /// A fixture file on disk plus the exact text it was written with.
  private struct Fixture {
    let file: ProjectFile
    let text: String
  }

  /// The seven-file fixture set this sortie is specified against. Deliberately
  /// heavy on the cases an extension allow-list would drop on the floor:
  ///
  /// - `Makefile`, `LICENSE`, `.zshrc` — no file extension at all.
  /// - `notes.md`, `data.json`, `readme.txt` — ordinary text extensions with no
  ///   registered handler.
  /// - `mystery.qqz` — an extension nothing will ever register.
  private func makeTextFixtures() throws -> [Fixture] {
    let specs = [
      ("Makefile", "build:\n\txcodebuild build\n"),
      ("LICENSE", "MIT License\n\nPermission is hereby granted…\n"),
      (".zshrc", "export EDITOR=vim\nalias ll='ls -la'\n"),
      ("notes.md", "# Notes\n\nA paragraph.\n"),
      ("data.json", "{\"key\": \"value\"}\n"),
      ("readme.txt", "Plain text, no ceremony.\n"),
      ("mystery.qqz", "Nobody has registered a handler for this.\n"),
    ]

    var fixtures: [Fixture] = []
    for (name, text) in specs {
      fixtures.append(Fixture(file: try makeFile(name, contents: text), text: text))
    }
    return fixtures
  }

  /// Writes `contents` to `relativePath` beneath ``tempRoot`` and returns the
  /// ``ProjectFile`` discovery would produce for it.
  @discardableResult
  private func makeFile(_ relativePath: String, contents: String) throws -> ProjectFile {
    let url = tempRoot.appendingPathComponent(relativePath, isDirectory: false)
    try contents.write(to: url, atomically: true, encoding: .utf8)
    return try projectFile(for: url, relativePath: relativePath)
  }

  /// Writes raw `data` (used for the deliberately non-UTF-8 fixture) and
  /// returns the matching ``ProjectFile``.
  private func makeBinaryFile(_ relativePath: String, data: Data) throws -> ProjectFile {
    let url = tempRoot.appendingPathComponent(relativePath, isDirectory: false)
    try data.write(to: url, options: .atomic)
    return try projectFile(for: url, relativePath: relativePath)
  }

  private func projectFile(for url: URL, relativePath: String) throws -> ProjectFile {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return ProjectFile(
      name: url.lastPathComponent,
      relativePath: relativePath,
      fileExtension: url.pathExtension.isEmpty ? nil : url.pathExtension,
      isDirectory: false,
      modifiedDate: attributes[.modificationDate] as? Date ?? Date(),
      fileSize: attributes[.size] as? Int64
    )
  }

  /// Loads a fixture's contents through the *real* loader, so these tests run
  /// against `ProjectBrowser`'s actual attempted-UTF-8-decode classifier rather
  /// than a hand-built `ProjectFileContents`.
  private func loadContents(for file: ProjectFile) async throws -> ProjectFileContents {
    try await ProjectFileActionHandler.reload(file: file, in: tempRoot)
  }

  /// Collects the builder's invocations. A plain class because
  /// ``TextEditorBuilder`` is a non-`Sendable`, main-actor view builder.
  private final class BuilderRecorder {
    private(set) var calls: [(file: ProjectFile, text: String)] = []

    func record(_ file: ProjectFile, _ text: String) {
      calls.append((file, text))
    }
  }

  // MARK: - The builder takes over the text branch

  /// Every one of the seven fixtures routes to the consumer's builder, the
  /// builder receives the file's decoded text verbatim, and the built-in
  /// editor is never constructed.
  func testBuilderReceivesEveryTextFixtureAndBuiltInEditorIsNeverConstructed() async throws {
    let fixtures = try makeTextFixtures()
    XCTAssertEqual(fixtures.count, 7, "The sortie's fixture set is specified as seven files.")

    let recorder = BuilderRecorder()
    EditableTextContentView.resetConstructionCount()

    for fixture in fixtures {
      let contents = try await loadContents(for: fixture.file)
      XCTAssertNotNil(
        contents.text,
        "\(fixture.file.name) must decode as UTF-8 — otherwise this fixture proves nothing.")

      let pane = ProjectDetailPane(
        selectedFile: fixture.file,
        handlers: [:],
        contents: contents,
        onSaveText: { _, _ in
          XCTFail("The built-in save path must be unreachable when a builder is supplied.")
        },
        textEditorBuilder: { file, text in
          recorder.record(file, text)
          return AnyView(Text(verbatim: text))
        }
      )

      XCTAssertEqual(
        pane.contentRoute(for: fixture.file),
        .customTextEditor(fixture.text),
        "\(fixture.file.name) must route to the consumer's builder.")

      // Actually build the branch. `contentView(for:)` is the sole construction
      // site of `EditableTextContentView`, so evaluating it here is what makes
      // the construction-count assertion below a real observation rather than a
      // structural argument.
      _ = pane.contentView(for: fixture.file)
    }

    XCTAssertEqual(
      recorder.calls.count, 7,
      "The builder must be invoked once per fixture.")
    XCTAssertEqual(
      recorder.calls.map(\.file.name),
      fixtures.map(\.file.name),
      "The builder must receive each fixture's own file.")
    XCTAssertEqual(
      recorder.calls.map(\.text),
      fixtures.map(\.text),
      "The builder must receive each file's decoded contents verbatim.")

    XCTAssertEqual(
      EditableTextContentView.constructionCount, 0,
      "EditableTextContentView must never be constructed when a textEditorBuilder is supplied.")
  }

  /// The builder is the fallback *beneath* the exact-extension `handlers`
  /// registry, not a replacement for it: a registered handler still wins.
  func testRegisteredHandlerStillWinsOverTheBuilder() async throws {
    let file = try makeFile("notes.md", contents: "# Notes\n")
    let contents = try await loadContents(for: file)
    let recorder = BuilderRecorder()

    let pane = ProjectDetailPane(
      selectedFile: file,
      handlers: ["md": { file in AnyView(Text(verbatim: file.name)) }],
      contents: contents,
      onSaveText: { _, _ in },
      textEditorBuilder: { file, text in
        recorder.record(file, text)
        return AnyView(Text(verbatim: text))
      }
    )

    XCTAssertEqual(pane.contentRoute(for: file), .handler)
    _ = pane.contentView(for: file)
    XCTAssertTrue(
      recorder.calls.isEmpty,
      "A file with a registered handler must not reach the builder.")
  }

  /// The classifier is untouched: a `.txt` holding non-UTF-8 bytes is still not
  /// text, so it reaches neither the builder nor the built-in editor.
  func testNonUTF8FileReachesNeitherTheBuilderNorTheBuiltInEditor() async throws {
    let file = try makeBinaryFile("payload.txt", data: Data([0xFF, 0xFE, 0xFF, 0x00, 0xC0]))
    let contents = try await loadContents(for: file)
    XCTAssertNil(contents.text, "The fixture must fail to decode as UTF-8.")

    let recorder = BuilderRecorder()
    EditableTextContentView.resetConstructionCount()

    let pane = ProjectDetailPane(
      selectedFile: file,
      handlers: [:],
      contents: contents,
      onSaveText: { _, _ in },
      textEditorBuilder: { file, text in
        recorder.record(file, text)
        return AnyView(Text(verbatim: text))
      }
    )

    XCTAssertEqual(pane.contentRoute(for: file), .readOnlyText(nil))
    _ = pane.contentView(for: file)
    XCTAssertTrue(recorder.calls.isEmpty)
    XCTAssertEqual(EditableTextContentView.constructionCount, 0)
  }

  // MARK: - Source compatibility: the nil-builder path is unchanged

  /// With no builder supplied, all seven fixtures still reach the built-in
  /// ``EditableTextContentView`` — which is the behaviour every existing
  /// consumer depends on.
  func testNilBuilderStillReachesEditableTextContentView() async throws {
    let fixtures = try makeTextFixtures()
    EditableTextContentView.resetConstructionCount()

    for fixture in fixtures {
      let contents = try await loadContents(for: fixture.file)

      let pane = ProjectDetailPane(
        selectedFile: fixture.file,
        handlers: [:],
        contents: contents,
        onSaveText: { _, _ in }
      )

      XCTAssertFalse(pane.hasTextEditorBuilder)
      XCTAssertEqual(
        pane.contentRoute(for: fixture.file),
        .editableText(fixture.text),
        "\(fixture.file.name) must still reach the built-in editor when no builder is supplied.")

      _ = pane.contentView(for: fixture.file)
    }

    XCTAssertEqual(
      EditableTextContentView.constructionCount, 7,
      "The built-in editor must still be constructed for every text file on the nil-builder path.")
  }

  /// The pre-existing no-save-handler behaviour is likewise unchanged: no
  /// `onSaveText` and no builder still means read-only.
  func testNoSaveHandlerAndNoBuilderStillRendersReadOnly() async throws {
    let file = try makeFile("readme.txt", contents: "Read only.\n")
    let contents = try await loadContents(for: file)
    EditableTextContentView.resetConstructionCount()

    let pane = ProjectDetailPane(selectedFile: file, handlers: [:], contents: contents)

    XCTAssertEqual(pane.contentRoute(for: file), .readOnlyText("Read only.\n"))
    _ = pane.contentView(for: file)
    XCTAssertEqual(EditableTextContentView.constructionCount, 0)
  }

  /// Every pre-existing initializer call form still compiles unmodified. This
  /// test's value is that it builds at all; the assertions are incidental.
  func testExistingInitializerCallFormsStillCompile() {
    let window = ProjectWindow(
      directoryURL: tempRoot,
      handlers: ["md": { file in AnyView(Text(verbatim: file.name)) }],
      projectTitle: "Legacy",
      onFileSelection: { _ in },
      onFileAction: { _, _ in },
      contentLoader: nil,
      fileWriter: nil,
      fileFilter: { _ in true },
      sidebarMinWidth: 250,
      sidebarIdealWidth: 300,
      sidebarMaxWidth: 400
    )
    XCTAssertEqual(window.directoryURL, tempRoot)

    let pane = ProjectDetailPane(
      selectedFile: nil,
      handlers: [:],
      contents: nil,
      isLoadingContent: false,
      loadError: nil,
      onAction: { _, _ in },
      onRetryLoad: { _ in },
      onSaveText: { _, _ in }
    )
    XCTAssertFalse(pane.hasTextEditorBuilder)
  }

  // MARK: - ProjectWindow forwarding

  /// `ProjectWindow` actually hands its `textEditorBuilder:` down to the pane —
  /// without this, everything above would pass while the public parameter did
  /// nothing.
  func testProjectWindowForwardsTheBuilderToTheDetailPane() throws {
    let file = try makeFile("notes.md", contents: "# Notes\n")

    let withBuilder = ProjectWindow(
      directoryURL: tempRoot,
      textEditorBuilder: { _, text in AnyView(Text(verbatim: text)) }
    )
    XCTAssertTrue(withBuilder.detailPane(for: file).hasTextEditorBuilder)

    let withoutBuilder = ProjectWindow(directoryURL: tempRoot)
    XCTAssertFalse(withoutBuilder.detailPane(for: file).hasTextEditorBuilder)
  }
}

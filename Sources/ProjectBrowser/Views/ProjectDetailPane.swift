import SwiftUI

/// Renders the contents of the currently-selected ``ProjectFile`` in a
/// `ProjectWindow`, delegating to a consumer-registered handler when one
/// exists for the file's extension and falling back to
/// ``UnsupportedFileView`` otherwise.
///
/// `ProjectDetailPane` is purely presentational: it owns no state of its
/// own, and never invokes a `FileLoaderCallback` itself. `ProjectWindow`
/// owns lazy content loading (S4.3) — it decides when to fetch a
/// handler-less file's contents, tracks in-flight loads, and passes the
/// result down as `contents`/`isLoadingContent`/`loadError`.
/// `ProjectDetailPane` only renders whatever state it's handed:
///
/// - A file with a registered handler always renders via that handler —
///   handlers own fetching their own content and are unaffected by lazy
///   loading.
/// - A handler-less file shows ``LoadingView`` while `isLoadingContent` is
///   `true`, ``ErrorView`` (with a retry action) when `loadError` is set,
///   ``PlainTextContentView`` once `contents` arrives, or
///   ``UnsupportedFileView`` as the final fallback.
///
/// ## Layout
///
/// ```
/// ┌─────────────────────────────────┐
/// │                                   │
/// │  Handler view or                 │
/// │  UnsupportedFileView              │  ← fills remaining space
/// │                                   │
/// ├─────────────────────────────────┤
/// │  📄 512 bytes    🕘 Jul 17, 2026…  │  ← metadata footer
/// └─────────────────────────────────┘
/// ```
///
/// ## Example
///
/// ```swift
/// ProjectDetailPane(
///   selectedFile: selectedFile,
///   handlers: [
///     "fountain": { file in AnyView(ScreenplayView(file: file)) }
///   ]
/// )
/// ```
public struct ProjectDetailPane: View {

  /// The currently-selected file, or `nil` if none is selected.
  private let selectedFile: ProjectFile?

  /// A registry mapping file extensions (without the leading dot) to view
  /// builders. Looked up by ``ProjectFile/fileExtension`` when a file is
  /// selected.
  private let handlers: [String: (ProjectFile) -> AnyView]

  /// The lazily-loaded contents of `selectedFile`, as fetched by
  /// `ProjectWindow`'s ``FileLoaderCallback``-backed cache. `nil` until a
  /// load completes successfully (or immediately, for files with a
  /// registered handler — handlers never consult this).
  private let contents: ProjectFileContents?

  /// Whether `ProjectWindow` currently has a content fetch in flight for
  /// `selectedFile`. Drives ``LoadingView`` for handler-less files.
  private let isLoadingContent: Bool

  /// A human-readable error message if `selectedFile`'s most recent content
  /// load failed, otherwise `nil`. Drives ``ErrorView`` for handler-less
  /// files.
  private let loadError: String?

  /// Invoked when a file action is triggered from the metadata footer's
  /// reload/show-in-Finder/delete buttons.
  ///
  /// Deliberately typed as a plain, non-`Sendable` closure rather than the
  /// public `FileActionCallback` — this is purely UI wiring to whatever
  /// hosts `ProjectDetailPane` (always invoked on the main actor from a
  /// `Button` action), not the consumer-facing callback surfaced by
  /// `ProjectWindow`'s own `onFileAction` initializer parameter.
  private let onAction: ((ProjectFile, FileAction) -> Void)?

  /// Invoked with `selectedFile` when the user taps "Retry" on the
  /// handler-less ``ErrorView`` fallback. `nil` hides the retry button's
  /// effect (the button itself is always shown by ``ErrorView``, but taps
  /// become a no-op).
  private let onRetryLoad: ((ProjectFile) -> Void)?

  /// Persists edited text for a handler-less text file, backing the default
  /// ``EditableTextContentView``. When `nil`, text files render read-only via
  /// ``PlainTextContentView`` instead of the editor.
  ///
  /// Like `onAction`, this is deliberately a plain (non-`Sendable`) closure:
  /// it's UI wiring to whatever hosts the pane (always driven from the main
  /// actor), not a consumer-facing callback.
  private let onSaveText: ((ProjectFile, String) async throws -> Void)?

  /// A consumer-supplied replacement for the built-in ``EditableTextContentView``.
  ///
  /// When non-`nil`, every handler-less file whose contents decoded as UTF-8
  /// text renders through this builder instead of the built-in editor; the
  /// built-in editor is not constructed at all, and `onSaveText` is never
  /// consulted for those files. When `nil`, behaviour is exactly what it was
  /// before this parameter existed.
  ///
  /// The exact-extension `handlers` registry still wins — see
  /// ``TextEditorBuilder``.
  private let textEditorBuilder: TextEditorBuilder?

  /// Whether a consumer-supplied ``TextEditorBuilder`` is installed. Internal
  /// so `ProjectWindow`'s forwarding of its own `textEditorBuilder:` parameter
  /// can be asserted from tests without widening the public surface.
  var hasTextEditorBuilder: Bool { textEditorBuilder != nil }

  /// Creates a project detail pane.
  ///
  /// - Parameters:
  ///   - selectedFile: The currently-selected file, or `nil` if none.
  ///   - handlers: A registry mapping file extensions to view builders.
  ///   - contents: The selected file's lazily-loaded contents, if any.
  ///   - isLoadingContent: Whether a content fetch is in flight for
  ///     `selectedFile`.
  ///   - loadError: An error message if the most recent content load
  ///     failed, otherwise `nil`.
  ///   - onAction: Invoked with the selected file and the chosen action
  ///     when the user taps a footer action button (reload, show in
  ///     Finder, delete).
  ///   - onRetryLoad: Invoked with the selected file when the user taps
  ///     "Retry" on the error fallback view.
  ///   - onSaveText: Persists edited text for a handler-less text file. When
  ///     `nil`, text files render read-only instead of in an editor.
  ///   - textEditorBuilder: Replaces the built-in editable text view for
  ///     handler-less UTF-8 text files. When `nil`, the built-in editor is
  ///     used exactly as before.
  public init(
    selectedFile: ProjectFile?,
    handlers: [String: (ProjectFile) -> AnyView],
    contents: ProjectFileContents? = nil,
    isLoadingContent: Bool = false,
    loadError: String? = nil,
    onAction: ((ProjectFile, FileAction) -> Void)? = nil,
    onRetryLoad: ((ProjectFile) -> Void)? = nil,
    onSaveText: ((ProjectFile, String) async throws -> Void)? = nil,
    textEditorBuilder: TextEditorBuilder? = nil
  ) {
    self.selectedFile = selectedFile
    self.handlers = handlers
    self.contents = contents
    self.isLoadingContent = isLoadingContent
    self.loadError = loadError
    self.onAction = onAction
    self.onRetryLoad = onRetryLoad
    self.onSaveText = onSaveText
    self.textEditorBuilder = textEditorBuilder
  }

  public var body: some View {
    Group {
      if let file = selectedFile {
        VStack(spacing: 0) {
          contentView(for: file)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

          Divider()

          metadataRow(for: file)
        }
      } else {
        emptyStateView
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Content

  /// The view ``contentView(for:)`` renders for the selected file, resolved as
  /// a value so the routing decision is testable on its own.
  ///
  /// `ProjectDetailPane` is a SwiftUI `View`, so which branch of its body ran
  /// can't be observed after the fact. Naming each destination lets tests
  /// assert the choice directly — in particular that a handler-less text file
  /// routes to ``customTextEditor(_:)`` rather than ``editableText(_:)`` when a
  /// ``TextEditorBuilder`` is supplied. ``contentView(for:)`` switches over this
  /// exhaustively and has no routing logic of its own, so the two cannot drift.
  enum ContentRoute: Equatable {

    /// A handler is registered for the file's exact extension; it renders.
    case handler

    /// A content fetch is in flight.
    case loading

    /// The most recent content fetch failed, with this message.
    case error(String)

    /// A UTF-8 text file routed to the consumer's ``TextEditorBuilder``,
    /// carrying the decoded text handed to it.
    case customTextEditor(String)

    /// A UTF-8 text file routed to the built-in ``EditableTextContentView``,
    /// carrying the decoded text.
    case editableText(String)

    /// Contents loaded but aren't editable here — either the bytes weren't
    /// valid UTF-8 (`nil` payload) or no save handler was supplied. Renders
    /// read-only via ``PlainTextContentView``.
    case readOnlyText(String?)

    /// Nothing has loaded and nothing else applies.
    case unsupported
  }

  /// Chooses the rendering destination for `file`.
  ///
  /// A registered handler always wins. Otherwise `ProjectWindow`'s
  /// lazy-loading state decides: a spinner while loading, an error (with
  /// retry) if the load failed, the loaded text once available, or
  /// ``ContentRoute/unsupported`` if nothing has loaded yet.
  ///
  /// The text branch is where a consumer's ``TextEditorBuilder`` takes over.
  /// Note what is *not* consulted here: no extension list, no MIME sniffing.
  /// "Is this text?" is answered solely by whether the loader managed to decode
  /// the bytes as UTF-8 (`contents.text != nil`) — the same test that has always
  /// gated ``EditableTextContentView``. Supplying a builder changes only where
  /// that branch goes, never what falls into it.
  func contentRoute(for file: ProjectFile) -> ContentRoute {
    if handlers[file.fileExtension ?? ""] != nil {
      return .handler
    }
    if isLoadingContent {
      return .loading
    }
    if let loadError {
      return .error(loadError)
    }
    guard let contents else {
      return .unsupported
    }
    guard let text = contents.text else {
      return .readOnlyText(nil)
    }
    if textEditorBuilder != nil {
      return .customTextEditor(text)
    }
    if onSaveText != nil {
      return .editableText(text)
    }
    return .readOnlyText(text)
  }

  /// Renders the destination ``contentRoute(for:)`` selected. Internal rather
  /// than private so tests can force the branch to actually be constructed —
  /// which is how "the built-in editor is never constructed" is asserted.
  @ViewBuilder
  func contentView(for file: ProjectFile) -> some View {
    switch contentRoute(for: file) {
    case .handler:
      handlers[file.fileExtension ?? ""]?(file)

    case .loading:
      LoadingView(filename: file.displayName)

    case .error(let message):
      ErrorView(error: message) {
        onRetryLoad?(file)
      }

    case .customTextEditor(let text):
      // Keyed by `file.id` for the same reason the built-in editor is: a
      // consumer's editor is just as likely to hold a draft in `@State`.
      textEditorBuilder?(file, text)
        .id(file.id)

    case .editableText(let text):
      // A UTF-8 text file with a save handler renders in the default editable
      // ``TextEditor``; keyed by `file.id` so switching selection resets the
      // draft.
      EditableTextContentView(text: text) { edited in
        try await onSaveText?(file, edited)
      }
      .id(file.id)

    case .readOnlyText(let text):
      // Binary files (nil text) and the no-save-handler case fall back to the
      // read-only ``PlainTextContentView``.
      PlainTextContentView(text: text)

    case .unsupported:
      UnsupportedFileView(file: file)
    }
  }

  /// Shown when no file is selected.
  private var emptyStateView: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 40))
        .foregroundStyle(.secondary)

      Text("Select a file to view its contents")
        .font(.headline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }

  // MARK: - Metadata footer

  private func metadataRow(for file: ProjectFile) -> some View {
    HStack(spacing: 16) {
      Label(Self.formattedSize(file.fileSize), systemImage: "internaldrive")
      Label(Self.formattedDate(file.modifiedDate), systemImage: "clock")
      Spacer()
      actionButtons(for: file)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity)
  }

  /// File-action buttons (reload, show in Finder, delete) shown alongside
  /// the metadata footer. Each dispatches through `onAction`; when
  /// `onAction` is `nil` the buttons are hidden entirely rather than shown
  /// disabled, since there's nothing for them to do.
  @ViewBuilder
  private func actionButtons(for file: ProjectFile) -> some View {
    if let onAction {
      HStack(spacing: 12) {
        Button {
          onAction(file, .reload)
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .help("Reload")

        #if os(macOS)
          Button {
            onAction(file, .showInFinder)
          } label: {
            Image(systemName: "folder")
          }
          .help("Show in Finder")
        #endif

        Button(role: .destructive) {
          onAction(file, .delete)
        } label: {
          Image(systemName: "trash")
        }
        .help("Delete")
      }
      .buttonStyle(.borderless)
    }
  }

  // MARK: - Formatting

  private static let byteCountFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowsNonnumericFormatting = false
    return formatter
  }()

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy h:mm a"
    return formatter
  }()

  /// Formats a byte count as a human-readable string (e.g. `"2.4 MB"`,
  /// `"512 bytes"`), or a placeholder when the size is unknown (e.g. for
  /// directories).
  private static func formattedSize(_ size: Int64?) -> String {
    guard let size else {
      return "Unknown size"
    }
    return byteCountFormatter.string(fromByteCount: size)
  }

  /// Formats a date as `"MMM d, yyyy h:mm a"` (e.g. `"Jul 17, 2026 3:45 PM"`).
  private static func formattedDate(_ date: Date) -> String {
    dateFormatter.string(from: date)
  }
}

// MARK: - Previews

#Preview("macOS – No Selection", traits: .fixedLayout(width: 480, height: 360)) {
  ProjectDetailPane(selectedFile: nil, handlers: [:])
}

#Preview("macOS – With Handler", traits: .fixedLayout(width: 480, height: 360)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.fountainFile,
    handlers: [
      "fountain": { file in
        AnyView(
          PlainTextContentView(text: "INT. OFFICE - DAY\n\nA quiet room.\n\nFile: \(file.name)")
        )
      }
    ]
  )
}

#Preview("macOS – No Handler", traits: .fixedLayout(width: 480, height: 360)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.movieFile,
    handlers: [:]
  )
}

#Preview("macOS – Loading (S4.3)", traits: .fixedLayout(width: 480, height: 360)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.movieFile,
    handlers: [:],
    isLoadingContent: true
  )
}

#Preview("macOS – Load Error (S4.3)", traits: .fixedLayout(width: 480, height: 360)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.movieFile,
    handlers: [:],
    loadError: "Permission denied: assets/reel.mov"
  )
}

#Preview("macOS – Fallback Loaded Text (S4.3)", traits: .fixedLayout(width: 480, height: 360)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.movieFile,
    handlers: [:],
    contents: ProjectFileContents(
      file: ProjectDetailPanePreviewFiles.movieFile,
      data: nil,
      text: "Lazily-loaded fallback text contents."
    )
  )
}

#Preview("macOS – Custom Text Editor", traits: .fixedLayout(width: 480, height: 360)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.makefile,
    handlers: [:],
    contents: ProjectFileContents(
      file: ProjectDetailPanePreviewFiles.makefile,
      data: nil,
      text: "build:\n\txcodebuild build\n"
    ),
    onSaveText: { _, _ in },
    textEditorBuilder: { file, text in
      AnyView(
        VStack(alignment: .leading) {
          Text("Consumer editor for \(file.name)").font(.headline)
          Text(text).font(.system(.body, design: .monospaced))
        }
        .padding()
      )
    }
  )
}

#Preview("iOS – No Selection", traits: .fixedLayout(width: 380, height: 500)) {
  ProjectDetailPane(selectedFile: nil, handlers: [:])
}

#Preview("iOS – With Handler", traits: .fixedLayout(width: 380, height: 500)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.fountainFile,
    handlers: [
      "fountain": { file in
        AnyView(PlainTextContentView(text: "INT. OFFICE - DAY\n\nA quiet room."))
      }
    ]
  )
}

#Preview("iOS – No Handler", traits: .fixedLayout(width: 380, height: 500)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.movieFile,
    handlers: [:]
  )
}

/// Shared preview fixtures for ``ProjectDetailPane`` previews.
private enum ProjectDetailPanePreviewFiles {
  static let fountainFile = ProjectFile(
    name: "01-pilot.fountain",
    relativePath: "episodes/01-pilot.fountain",
    fileExtension: "fountain",
    isDirectory: false,
    modifiedDate: Date(),
    fileSize: 2_411_724
  )

  static let movieFile = ProjectFile(
    name: "reel.mov",
    relativePath: "assets/reel.mov",
    fileExtension: "mov",
    isDirectory: false,
    modifiedDate: Date(),
    fileSize: 512
  )

  static let makefile = ProjectFile(
    name: "Makefile",
    relativePath: "Makefile",
    fileExtension: nil,
    isDirectory: false,
    modifiedDate: Date(),
    fileSize: 28
  )
}

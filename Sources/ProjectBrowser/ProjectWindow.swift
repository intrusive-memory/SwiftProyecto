import SwiftUI

/// The top-level, reusable file browser container consumers embed to browse
/// any directory: discovers files, displays a hierarchical sidebar, and
/// renders the selected file's contents via consumer-registered handlers.
///
/// `ProjectWindow` owns all UI state (discovered files, selection, expanded
/// folders, loaded metadata) internally in `@State`; consumers observe
/// activity only through the callbacks passed to the initializer. It performs
/// no domain-specific parsing itself — file discovery is delegated to
/// ``ProjectFileDiscovery``, `PROJECT.md` metadata to ``ProjectMetadata``, and
/// content rendering to the caller-supplied `handlers` registry.
///
/// ## Layout
///
/// - **macOS** and **iPadOS in a regular-width size class**: a two-column
///   `NavigationSplitView` with ``ProjectBrowserSidebar`` on the left and
///   ``ProjectDetailPane`` on the right, so both the file tree and the
///   selected file's contents stay visible at once.
/// - **iOS in a compact-width size class** (iPhone, or a narrow iPad split):
///   a `NavigationStack` rooted at ``ProjectBrowserSidebar``. Selecting a
///   file pushes ``ProjectDetailPane`` as a navigation destination; the
///   system back button (or edge swipe) returns to the file list, which
///   clears the selection automatically since the pushed destination is
///   keyed off `selectedFile` itself.
///
/// ## Example
///
/// ```swift
/// ProjectWindow(
///   directoryURL: projectFolderURL,
///   handlers: [
///     "fountain": { file in AnyView(ScreenplayContentView(file: file)) },
///     "md": { file in AnyView(MarkdownContentView(file: file)) },
///   ],
///   projectTitle: "My Series",
///   onFileSelection: { file in print("Selected \(file.name)") },
///   onFileAction: { file, action in
///     switch action {
///     case .showInFinder:
///       NSWorkspace.shared.activateFileViewerSelecting([file.url(in: projectFolderURL)])
///     default:
///       break
///     }
///   }
/// )
/// ```
public struct ProjectWindow: View {

  // MARK: - Public API

  /// The directory this window browses. Passed to ``ProjectFileDiscovery``
  /// and ``ProjectMetadata`` on appear.
  public let directoryURL: URL

  /// File type handlers, keyed by file extension without the leading dot
  /// (e.g. `"fountain"`). Looked up by ``ProjectDetailPane`` when a file is
  /// selected; extensions with no registered handler fall back to
  /// ``UnsupportedFileView``.
  private let handlers: [String: (ProjectFile) -> AnyView]

  /// An explicit project title that overrides any title found in
  /// `PROJECT.md`. When `nil`, the `PROJECT.md` title (if present) wins,
  /// falling back to `directoryURL`'s last path component.
  private let projectTitle: String?

  /// Invoked whenever the user selects a file in the sidebar.
  private let onFileSelection: FileSelectionCallback?

  /// Invoked whenever a file action (reload, delete, show in Finder,
  /// custom) is triggered, *after* `ProjectWindow` has performed its own
  /// built-in handling (see ``handleFileAction(_:action:)``). Every action,
  /// including `.custom`, is forwarded here so the host app can observe or
  /// react to it.
  private let onFileAction: FileActionCallback?

  /// A consumer-supplied loader for file contents. Used by
  /// ``loadContentIfNeeded(for:)`` to lazily fetch a handler-less file's
  /// contents the first time it's selected, and by
  /// ``handleFileAction(_:action:)`` to re-fetch contents on `.reload`. When
  /// `nil`, both fall back to reading the file directly from disk as UTF-8
  /// text (see ``ProjectFileActionHandler/reload(file:in:contentLoader:)``).
  private let contentLoader: FileLoaderCallback?

  /// A consumer-supplied writer used by the default ``EditableTextContentView``
  /// to persist edited text. When `nil`, edits are written directly to disk as
  /// UTF-8 (see ``ProjectFileActionHandler/save(text:to:in:fileWriter:)``).
  ///
  /// Sandboxed consumers should supply this and bracket the write in their own
  /// security-scoped access — `ProjectBrowser` performs no scoping itself.
  private let fileWriter: FileWriterCallback?

  /// An optional predicate applied to the discovered file list; entries for
  /// which this returns `false` are hidden from the sidebar.
  private let fileFilter: ((ProjectFile) -> Bool)?

  /// Sidebar column minimum width (macOS).
  private let sidebarMinWidth: CGFloat

  /// Sidebar column ideal width (macOS).
  private let sidebarIdealWidth: CGFloat

  /// Sidebar column maximum width (macOS).
  private let sidebarMaxWidth: CGFloat

  // MARK: - Internal state

  /// The flat array of files/folders discovered beneath ``directoryURL``.
  @State private var files: [ProjectFile] = []

  /// The currently-selected file, or `nil` if none.
  @State private var selectedFile: ProjectFile?

  /// The set of folder ``ProjectFile/id``s currently expanded in the sidebar.
  @State private var expandedFolders: Set<UUID> = []

  /// Project metadata parsed from `PROJECT.md`, if present.
  @State private var metadata: ProjectMetadata?

  /// Whether discovery/metadata loading is currently in flight.
  @State private var isLoading: Bool = false

  /// A human-readable message describing the most recent load or
  /// file-action failure, or `nil` if the last operation succeeded (or
  /// none has happened yet).
  @State private var errorMessage: String?

  /// In-memory cache of fetched file contents, keyed by ``ProjectFile/id``.
  /// Populated lazily — on first selection of a handler-less file (see
  /// ``loadContentIfNeeded(for:)``) and on `.reload` — and never persisted;
  /// it's cleared implicitly whenever the view is torn down. A `.reload`
  /// evicts a file's entry before re-fetching, so a stale cache never lingers.
  @State private var fileContents: [UUID: ProjectFileContents] = [:]

  /// The set of file ``ProjectFile/id``s whose contents are currently being
  /// fetched, either via lazy load-on-selection or a `.reload` action.
  /// `ProjectDetailPane` uses membership here (for the selected file) to
  /// decide whether to show ``LoadingView``.
  @State private var loadingFiles: Set<UUID> = []

  /// The file pending user confirmation for a `.delete` action, or `nil`
  /// when no confirmation is in progress.
  @State private var pendingDeleteFile: ProjectFile?

  #if !os(macOS)
    /// Drives the iOS/iPadOS layout choice between a `NavigationStack`
    /// drill-down (compact width, e.g. iPhone) and a `NavigationSplitView`
    /// (regular width, e.g. iPad in landscape or a wide split) — see
    /// ``platformLayout``.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  /// Creates a project window.
  ///
  /// - Parameters:
  ///   - directoryURL: The directory to browse.
  ///   - handlers: File type handlers keyed by extension. Defaults to empty
  ///     (all files fall back to ``UnsupportedFileView``).
  ///   - projectTitle: An explicit title overriding `PROJECT.md`'s title.
  ///   - onFileSelection: Invoked when the user selects a file.
  ///   - onFileAction: Invoked when a file action is triggered (reload,
  ///     delete, show in Finder, custom).
  ///   - contentLoader: A custom content loader, used for lazy
  ///     load-on-selection and `.reload`. Falls back to reading the file
  ///     from disk when `nil`.
  ///   - fileWriter: A custom writer used by the default editable text view
  ///     to persist edits. Falls back to writing UTF-8 directly to disk when
  ///     `nil`.
  ///   - fileFilter: A predicate hiding files for which it returns `false`.
  ///   - sidebarMinWidth: Sidebar minimum width (macOS). Defaults to `250`.
  ///   - sidebarIdealWidth: Sidebar ideal width (macOS). Defaults to `300`.
  ///   - sidebarMaxWidth: Sidebar maximum width (macOS). Defaults to `400`.
  public init(
    directoryURL: URL,
    handlers: [String: (ProjectFile) -> AnyView] = [:],
    projectTitle: String? = nil,
    onFileSelection: FileSelectionCallback? = nil,
    onFileAction: FileActionCallback? = nil,
    contentLoader: FileLoaderCallback? = nil,
    fileWriter: FileWriterCallback? = nil,
    fileFilter: ((ProjectFile) -> Bool)? = nil,
    sidebarMinWidth: CGFloat = 250,
    sidebarIdealWidth: CGFloat = 300,
    sidebarMaxWidth: CGFloat = 400
  ) {
    self.directoryURL = directoryURL
    self.handlers = handlers
    self.projectTitle = projectTitle
    self.onFileSelection = onFileSelection
    self.onFileAction = onFileAction
    self.contentLoader = contentLoader
    self.fileWriter = fileWriter
    self.fileFilter = fileFilter
    self.sidebarMinWidth = sidebarMinWidth
    self.sidebarIdealWidth = sidebarIdealWidth
    self.sidebarMaxWidth = sidebarMaxWidth
  }

  public var body: some View {
    platformLayout
      .onAppear {
        Task { await loadProject() }
      }
      .alert(
        "Failed to Load Project",
        isPresented: Binding(
          get: { errorMessage != nil },
          set: { isPresented in
            if !isPresented { errorMessage = nil }
          }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "An unknown error occurred.")
      }
      .confirmationDialog(
        pendingDeleteFile.map { "Delete \"\($0.name)\"?" } ?? "Delete File?",
        isPresented: Binding(
          get: { pendingDeleteFile != nil },
          set: { isPresented in
            if !isPresented { pendingDeleteFile = nil }
          }
        ),
        presenting: pendingDeleteFile
      ) { file in
        Button("Delete", role: .destructive) {
          pendingDeleteFile = nil
          Task { await handleFileAction(file, action: .delete) }
        }
        Button("Cancel", role: .cancel) {
          pendingDeleteFile = nil
        }
      } message: { file in
        Text(
          "This will permanently delete \"\(file.relativePath)\" from disk. This action cannot be undone."
        )
      }
  }

  // MARK: - Platform Layout (S4.4)

  /// Chooses the platform-appropriate top-level layout.
  ///
  /// - macOS always uses ``splitLayout`` (a two-column
  ///   `NavigationSplitView`) — there's no "compact" macOS window size to
  ///   accommodate.
  /// - iOS/iPadOS uses ``splitLayout`` too when `horizontalSizeClass` is
  ///   `.regular` (iPad in landscape, or a wide multitasking split), giving
  ///   iPad users the same simultaneous tree + detail view macOS gets.
  ///   Otherwise (iPhone, or a narrow iPad split) it uses ``stackLayout``, a
  ///   `NavigationStack` drill-down: the file tree fills the screen until a
  ///   file is selected, at which point ``ProjectDetailPane`` is pushed and
  ///   the system back button returns to the tree.
  @ViewBuilder
  private var platformLayout: some View {
    #if os(macOS)
      splitLayout
    #else
      if horizontalSizeClass == .regular {
        splitLayout
      } else {
        stackLayout
      }
    #endif
  }

  /// A two-column `NavigationSplitView`: ``ProjectBrowserSidebar`` on the
  /// left, ``ProjectDetailPane`` (for ``selectedFile``) on the right. Used
  /// on macOS unconditionally, and on iOS/iPadOS when
  /// `horizontalSizeClass == .regular`.
  private var splitLayout: some View {
    NavigationSplitView {
      sidebar
        .navigationSplitViewColumnWidth(
          min: sidebarMinWidth,
          ideal: sidebarIdealWidth,
          max: sidebarMaxWidth
        )
    } detail: {
      detailPane(for: selectedFile)
        .overlay {
          if isLoading && files.isEmpty {
            ProgressView("Discovering files…")
          }
        }
    }
  }

  #if !os(macOS)
    /// A `NavigationStack` rooted at ``ProjectBrowserSidebar``, pushing
    /// ``ProjectDetailPane`` as a `navigationDestination(item:)` keyed off
    /// ``selectedFile``. Used on iOS/iPadOS when
    /// `horizontalSizeClass != .regular` (iPhone, or a narrow iPad split).
    ///
    /// Keying the destination off `selectedFile` itself — rather than a
    /// separate "is detail showing" flag — means the system back button
    /// (or an edge swipe) automatically clears ``selectedFile`` back to
    /// `nil` when the user returns to the file list, exactly mirroring
    /// what deselecting a file does on the macOS/iPad split layout.
    private var stackLayout: some View {
      NavigationStack {
        sidebar
          .navigationTitle(sidebarFallbackTitle)
          .navigationBarTitleDisplayMode(.large)
          .overlay {
            if isLoading && files.isEmpty {
              ProgressView("Discovering files…")
            }
          }
          .navigationDestination(item: $selectedFile) { file in
            detailPane(for: file)
              .navigationTitle(file.displayName)
              .navigationBarTitleDisplayMode(.inline)
          }
      }
    }
  #endif

  /// Builds ``ProjectBrowserSidebar``, shared verbatim by ``splitLayout``
  /// and ``stackLayout`` so both platforms wire up the same file tree,
  /// header, action bar, and callbacks.
  private var sidebar: some View {
    ProjectBrowserSidebar(
      files: files,
      metadata: effectiveMetadata,
      selectedFile: $selectedFile,
      expandedFolders: $expandedFolders,
      title: sidebarFallbackTitle,
      isActionBarEnabled: !isLoading,
      onFolderToggle: toggleFolder,
      onSelect: selectFile,
      onSync: { Task { await loadProject() } },
      onImport: {
        // No-op stub; directory-import UI is out of scope for S4.1.
      },
      onLoadAll: { Task { await loadAllContent() } },
      onUnloadAll: { unloadAllContent() },
      onFileAction: dispatchFileAction
    )
  }

  /// Builds ``ProjectDetailPane`` for `file`, wiring up its lazily-loaded
  /// contents/loading/error state from `@State` exactly as ``splitLayout``
  /// always has — shared with ``stackLayout`` so a pushed detail view on
  /// iPhone behaves identically to the split-view detail column on macOS
  /// and iPad.
  private func detailPane(for file: ProjectFile?) -> ProjectDetailPane {
    ProjectDetailPane(
      selectedFile: file,
      handlers: handlers,
      contents: file.flatMap { fileContents[$0.id] },
      isLoadingContent: file.map { loadingFiles.contains($0.id) } ?? false,
      loadError: selectedFileLoadError,
      onAction: dispatchFileAction,
      onRetryLoad: { file in dispatchFileAction(file, action: .reload) },
      onSaveText: saveText
    )
  }

  /// Persists edited text for `file` (via `fileWriter` if supplied, otherwise
  /// straight to disk) and refreshes the in-memory content cache so a later
  /// reselection or `.reload` observes the saved text rather than a stale
  /// value. Errors propagate to ``EditableTextContentView``, which surfaces
  /// them inline and keeps the edit dirty for a retry.
  private func saveText(_ file: ProjectFile, _ text: String) async throws {
    try await ProjectFileActionHandler.save(
      text: text, to: file, in: directoryURL, fileWriter: fileWriter)
    fileContents[file.id] = ProjectFileContents(
      file: file, data: Data(text.utf8), text: text, loadedAt: Date())
  }

  // MARK: - Actions

  /// Toggles a folder's expanded/collapsed state.
  private func toggleFolder(_ id: UUID) {
    if expandedFolders.contains(id) {
      expandedFolders.remove(id)
    } else {
      expandedFolders.insert(id)
    }
  }

  /// Updates selection state, forwards the selection to the consumer, and
  /// kicks off a lazy content load for `file` if one is needed (see
  /// ``loadContentIfNeeded(for:)``).
  private func selectFile(_ file: ProjectFile) {
    selectedFile = file
    onFileSelection?(file)
    Task { await loadContentIfNeeded(for: file) }
  }

  // MARK: - File Actions

  /// The synchronous entry point used by child views (``ProjectBrowserSidebar``'s
  /// context menu, ``ProjectDetailPane``'s footer buttons) to trigger a
  /// ``FileAction``.
  ///
  /// `.delete` is intercepted here to collect confirmation first (see
  /// ``pendingDeleteFile``) rather than deleting immediately — file
  /// operations should never happen without the user confirming a
  /// destructive action. Every other action is dispatched to
  /// ``handleFileAction(_:action:)`` right away.
  private func dispatchFileAction(_ file: ProjectFile, action: FileAction) {
    if action == .delete {
      pendingDeleteFile = file
      return
    }
    Task { await handleFileAction(file, action: action) }
  }

  /// Performs a file action's built-in behavior (via
  /// ``ProjectFileActionHandler``), applies the result to `@State`, then
  /// always forwards the action to the consumer's `onFileAction` callback —
  /// including `.custom` actions, which `ProjectFileActionHandler` never
  /// interprets itself.
  ///
  /// - `.reload` evicts any cached contents for `file` up front (so a
  ///   selection made mid-reload can't observe a stale cache hit), marks
  ///   `file` as ``FileLoadingState/loading`` (surfaced as a spinner by
  ///   ``ProjectDetailPane`` and the sidebar's ``FileTreeView``), then
  ///   updates ``fileContents`` with the freshly-fetched value on success or
  ///   the file's ``FileLoadingState/error(_:)`` on failure. Per Phase 1
  ///   scope, there is no separate "stale" indicator — a file is either
  ///   loading, loaded, or in error.
  /// - `.delete` removes `file` (and, if it's a directory, its descendants)
  ///   from ``files``, evicts any cached contents, and clears the
  ///   selection if the deleted file was selected.
  /// - `.showInFinder` has no `@State` side effects; the reveal itself
  ///   happens inside ``ProjectFileActionHandler``.
  /// - Any failure (file not found, permissions, a throwing
  ///   `contentLoader`) is surfaced via ``errorMessage`` rather than
  ///   crashing or silently dropping the action.
  private func handleFileAction(_ file: ProjectFile, action: FileAction) async {
    if action == .reload {
      fileContents.removeValue(forKey: file.id)
      loadingFiles.insert(file.id)
      updateLoadingState(for: file.id, to: .loading)
    }

    let result = await ProjectFileActionHandler.handle(
      action: action,
      file: file,
      in: directoryURL,
      contentLoader: contentLoader
    )

    if action == .reload {
      loadingFiles.remove(file.id)
      if let contents = result.reloadedContents {
        fileContents[file.id] = contents
        updateLoadingState(for: file.id, to: .loaded)
      } else if let message = result.errorMessage {
        updateLoadingState(for: file.id, to: .error(message))
      }
    }

    if result.didDelete {
      files = ProjectFileActionHandler.removingFromTree(file, from: files)
      fileContents.removeValue(forKey: file.id)
      loadingFiles.remove(file.id)
      if selectedFile?.id == file.id {
        selectedFile = nil
      }
    }

    errorMessage = result.errorMessage

    onFileAction?(file, action)
  }

  // MARK: - Lazy Content Loading (S4.3)

  /// Lazily fetches `file`'s contents the first time it's selected, if
  /// ``ProjectFileContentLoader/shouldLoad(file:hasHandler:cache:loadingFiles:)``
  /// says a load is warranted — i.e. `file` has no registered handler (a
  /// handler owns fetching its own content), isn't already cached in
  /// ``fileContents``, and isn't already mid-load in ``loadingFiles``.
  ///
  /// Marks `file.id` as loading (spinner shown in both ``ProjectDetailPane``
  /// and the sidebar's ``FileTreeView``) for the duration of the fetch, then
  /// stores the result in ``fileContents`` on success or the file's
  /// ``FileLoadingState/error(_:)`` — plus ``errorMessage`` for the
  /// window-level alert — on failure. A failed load leaves no cache entry
  /// behind, so re-selecting (or retrying via ``ProjectDetailPane``'s
  /// ``ErrorView``) tries again.
  private func loadContentIfNeeded(for file: ProjectFile) async {
    guard
      ProjectFileContentLoader.shouldLoad(
        file: file,
        hasHandler: handlers[file.fileExtension ?? ""] != nil,
        cache: fileContents,
        loadingFiles: loadingFiles
      )
    else { return }

    loadingFiles.insert(file.id)
    updateLoadingState(for: file.id, to: .loading)

    do {
      let contents = try await ProjectFileActionHandler.reload(
        file: file, in: directoryURL, contentLoader: contentLoader)
      fileContents[file.id] = contents
      updateLoadingState(for: file.id, to: .loaded)
    } catch {
      let message = error.localizedDescription
      updateLoadingState(for: file.id, to: .error(message))
      errorMessage = message
    }

    loadingFiles.remove(file.id)
  }

  /// Eagerly loads every handler-less, not-yet-cached file's contents,
  /// backing the sidebar action bar's "Load All" button. Reuses
  /// ``loadContentIfNeeded(for:)`` file-by-file, so files with a registered
  /// handler or an already-cached/in-flight load are skipped exactly as
  /// they would be on individual selection.
  private func loadAllContent() async {
    for file in files where !file.isDirectory {
      await loadContentIfNeeded(for: file)
    }
  }

  /// Evicts every cached file content and resets each file's
  /// ``FileLoadingState`` back to ``FileLoadingState/notLoaded``, backing
  /// the sidebar action bar's "Unload All" button. Per Phase 1 scope, this
  /// only affects the in-memory cache — nothing is persisted to begin with.
  private func unloadAllContent() {
    fileContents.removeAll()
    loadingFiles.removeAll()
    files = files.map { $0.withLoadingState(.notLoaded) }
    if let selectedFile {
      self.selectedFile = selectedFile.withLoadingState(.notLoaded)
    }
  }

  /// Applies `state` to the file identified by `id` in both ``files`` (so
  /// the sidebar's ``FileTreeView`` icon reflects it) and ``selectedFile``
  /// (so the currently-displayed file's binding stays in sync), if either
  /// currently holds that file.
  private func updateLoadingState(for id: UUID, to state: FileLoadingState) {
    if let index = files.firstIndex(where: { $0.id == id }) {
      files[index] = files[index].withLoadingState(state)
    }
    if selectedFile?.id == id {
      selectedFile = selectedFile?.withLoadingState(state)
    }
  }

  /// The content-load error message for the currently-selected file, if its
  /// most recent lazy load or reload failed — surfaced by
  /// ``ProjectDetailPane`` as an ``ErrorView`` with a retry action. `nil`
  /// when nothing is selected or the selected file isn't in an error state.
  private var selectedFileLoadError: String? {
    guard case .error(let message) = selectedFile?.loadingState else { return nil }
    return message
  }

  /// Discovers files beneath ``directoryURL`` and loads `PROJECT.md`
  /// metadata (if present), updating `@State` as each completes.
  ///
  /// File discovery failures are surfaced via ``errorMessage`` since an
  /// unbrowsable directory is a hard failure for this view. `PROJECT.md`
  /// parsing failures are logged but otherwise swallowed — metadata is
  /// optional decoration, not required for browsing to function.
  private func loadProject() async {
    isLoading = true
    errorMessage = nil

    do {
      let discovered = try await ProjectFileDiscovery.discover(at: directoryURL)
      files = fileFilter.map { predicate in discovered.filter(predicate) } ?? discovered
    } catch {
      errorMessage = error.localizedDescription
    }

    do {
      metadata = try await ProjectMetadata.load(from: directoryURL)
    } catch {
      // PROJECT.md is optional metadata; don't block browsing on it.
      metadata = nil
      #if DEBUG
        print("ProjectWindow: failed to load PROJECT.md metadata: \(error)")
      #endif
    }

    isLoading = false
  }

  // MARK: - Title resolution

  /// The metadata passed to ``ProjectBrowserSidebar``. When `projectTitle`
  /// is set, it takes precedence over any title found in `PROJECT.md` — the
  /// rest of the loaded metadata (author, description, created) is
  /// preserved unchanged.
  private var effectiveMetadata: ProjectMetadata? {
    guard let projectTitle, !projectTitle.isEmpty else {
      return metadata
    }
    return ProjectMetadata(
      title: projectTitle,
      author: metadata?.author,
      description: metadata?.description,
      created: metadata?.created
    )
  }

  /// The fallback title used when neither `projectTitle` nor
  /// `PROJECT.md` supply one.
  private var sidebarFallbackTitle: String {
    projectTitle ?? directoryURL.lastPathComponent
  }
}

// MARK: - ProjectFile loading-state helper

extension ProjectFile {
  /// Returns a copy of `self` with ``loadingState`` set to `state` (and
  /// ``isLoaded``/``error`` derived from it), used by `ProjectWindow` to
  /// keep a file's tree-visible state in sync as its contents are lazily
  /// loaded or reloaded. All other properties are preserved unchanged.
  fileprivate func withLoadingState(_ state: FileLoadingState) -> ProjectFile {
    let errorMessage: String?
    if case .error(let message) = state {
      errorMessage = message
    } else {
      errorMessage = nil
    }
    return ProjectFile(
      id: id,
      name: name,
      relativePath: relativePath,
      fileExtension: fileExtension,
      isDirectory: isDirectory,
      modifiedDate: modifiedDate,
      fileSize: fileSize,
      isLoaded: state == .loaded ? true : isLoaded,
      loadingState: state,
      error: errorMessage
    )
  }
}

// MARK: - Previews

#Preview("macOS – ProjectWindow", traits: .fixedLayout(width: 900, height: 600)) {
  ProjectWindow(
    directoryURL: FileManager.default.temporaryDirectory,
    handlers: [
      "fountain": { file in
        AnyView(PlainTextContentView(text: "INT. OFFICE - DAY\n\nFile: \(file.name)"))
      }
    ],
    projectTitle: "Preview Project"
  )
}

#Preview("macOS – ProjectWindow (no handlers)", traits: .fixedLayout(width: 900, height: 600)) {
  ProjectWindow(directoryURL: FileManager.default.temporaryDirectory)
}

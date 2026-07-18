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
/// Phase 1 targets macOS: a two-column `NavigationSplitView` with
/// ``ProjectBrowserSidebar`` on the left and ``ProjectDetailPane`` on the
/// right. iOS's `NavigationStack`-based layout is deferred to a later sortie
/// (S4.4); this view still compiles for iOS today, just without an
/// iOS-tailored layout yet.
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

  /// Invoked when a file action (reload, delete, show in Finder, custom) is
  /// triggered. Reserved for S4.2; stored and forwarded but not yet
  /// triggered internally by `ProjectWindow` in Phase 1.
  private let onFileAction: FileActionCallback?

  /// A consumer-supplied loader for file contents. Reserved for S4.3 lazy
  /// loading; stored and forwarded but not yet invoked internally by
  /// `ProjectWindow` in Phase 1.
  private let contentLoader: FileLoaderCallback?

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

  /// A human-readable message describing the most recent load failure, or
  /// `nil` if the last load succeeded (or none has happened yet).
  @State private var errorMessage: String?

  /// Creates a project window.
  ///
  /// - Parameters:
  ///   - directoryURL: The directory to browse.
  ///   - handlers: File type handlers keyed by extension. Defaults to empty
  ///     (all files fall back to ``UnsupportedFileView``).
  ///   - projectTitle: An explicit title overriding `PROJECT.md`'s title.
  ///   - onFileSelection: Invoked when the user selects a file.
  ///   - onFileAction: Invoked when a file action is triggered. Reserved for
  ///     S4.2.
  ///   - contentLoader: A custom content loader. Reserved for S4.3.
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
    self.fileFilter = fileFilter
    self.sidebarMinWidth = sidebarMinWidth
    self.sidebarIdealWidth = sidebarIdealWidth
    self.sidebarMaxWidth = sidebarMaxWidth
  }

  public var body: some View {
    NavigationSplitView {
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
        onLoadAll: {
          // No-op stub; lazy "load all" is implemented in S4.3.
        },
        onUnloadAll: {
          // No-op stub; cached-content eviction is implemented in S4.3.
        }
      )
      .navigationSplitViewColumnWidth(
        min: sidebarMinWidth,
        ideal: sidebarIdealWidth,
        max: sidebarMaxWidth
      )
    } detail: {
      ProjectDetailPane(
        selectedFile: selectedFile,
        handlers: handlers,
        contentLoader: contentLoader,
        onAction: onFileAction
      )
      .overlay {
        if isLoading && files.isEmpty {
          ProgressView("Discovering files…")
        }
      }
    }
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

  /// Updates selection state and forwards the selection to the consumer.
  private func selectFile(_ file: ProjectFile) {
    selectedFile = file
    onFileSelection?(file)
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

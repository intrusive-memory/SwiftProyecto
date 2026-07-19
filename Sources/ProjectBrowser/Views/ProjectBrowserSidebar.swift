import SwiftUI

/// Assembles the three primary sidebar components — ``ProjectHeader``,
/// ``FileTreeView``, and ``ProjectActionBar`` — into the vertical sidebar
/// layout used by `ProjectWindow` (WU4).
///
/// `ProjectBrowserSidebar` is purely compositional: it owns no state of its
/// own. Selection and expansion are threaded through as bindings supplied by
/// the caller, and every action bar interaction is forwarded verbatim to the
/// caller-supplied callbacks. File/folder counts shown in the header are
/// derived from the `files` array on each render.
///
/// ## Layout
///
/// ```
/// ┌─────────────────────────┐
/// │  ProjectHeader           │  ← title, counts, author/description
/// ├─────────────────────────┤
/// │  FileTreeView             │  ← scrollable hierarchical list
/// │  (fills remaining space)  │
/// ├─────────────────────────┤
/// │  ProjectActionBar         │  ← Sync / Import / Load All / Unload All
/// └─────────────────────────┘
/// ```
///
/// ## Example
///
/// ```swift
/// ProjectBrowserSidebar(
///   files: discoveredFiles,
///   metadata: projectMetadata,
///   selectedFile: $selectedFile,
///   expandedFolders: $expandedFolders,
///   title: directoryURL.lastPathComponent,
///   onFolderToggle: { id in expandedFolders.formSymmetricDifference([id]) },
///   onSelect: { file in selectedFile = file },
///   onSync: { discoverFiles() },
///   onImport: { isImporterPresented = true },
///   onLoadAll: { loadAllContents() },
///   onUnloadAll: { clearCachedContents() }
/// )
/// ```
public struct ProjectBrowserSidebar: View {

  /// The flat array of files/folders to display, typically the output of
  /// ``ProjectFileDiscovery/discover(at:)``.
  private let files: [ProjectFile]

  /// Project metadata loaded from `PROJECT.md`, if present.
  private let metadata: ProjectMetadata?

  @Binding private var selectedFile: ProjectFile?
  @Binding private var expandedFolders: Set<UUID>

  /// A fallback title used when `metadata` is `nil` or has no title, such as
  /// the browsed directory's last path component.
  private let title: String?

  private let onFolderToggle: (UUID) -> Void
  private let onSelect: (ProjectFile) -> Void
  private let onSync: () -> Void
  private let onImport: () -> Void
  private let onLoadAll: () -> Void
  private let onUnloadAll: () -> Void

  /// Invoked when the user chooses a file action from a file row's context
  /// menu in the embedded ``FileTreeView`` (reload, delete, show in
  /// Finder). `nil` (the default) hides the context menu.
  private let onFileAction: ((ProjectFile, FileAction) -> Void)?

  /// Whether the action bar's buttons are currently enabled. Forwarded
  /// directly to ``ProjectActionBar/isEnabled``.
  private let isActionBarEnabled: Bool

  /// Creates a project browser sidebar.
  ///
  /// - Parameters:
  ///   - files: The flat array of files/folders to display.
  ///   - metadata: Project metadata loaded from `PROJECT.md`, if present.
  ///   - selectedFile: The currently-selected file, or `nil` if none. Owned
  ///     by the caller.
  ///   - expandedFolders: The set of folder ``ProjectFile/id``s currently
  ///     expanded. Owned by the caller.
  ///   - title: A fallback title used when `metadata` has no title.
  ///   - isActionBarEnabled: Whether the action bar's buttons are enabled.
  ///     Defaults to `true`.
  ///   - onFolderToggle: Invoked with a folder's id when the user
  ///     expands/collapses it.
  ///   - onSelect: Invoked with a file when the user selects it.
  ///   - onSync: Invoked when the user taps Sync.
  ///   - onImport: Invoked when the user taps Import.
  ///   - onLoadAll: Invoked when the user taps Load All.
  ///   - onUnloadAll: Invoked when the user taps Unload All.
  ///   - onFileAction: Invoked with a file and the chosen action when the
  ///     user picks a file row's context-menu item. `nil` hides the
  ///     context menu.
  public init(
    files: [ProjectFile],
    metadata: ProjectMetadata?,
    selectedFile: Binding<ProjectFile?>,
    expandedFolders: Binding<Set<UUID>>,
    title: String? = nil,
    isActionBarEnabled: Bool = true,
    onFolderToggle: @escaping (UUID) -> Void,
    onSelect: @escaping (ProjectFile) -> Void,
    onSync: @escaping () -> Void,
    onImport: @escaping () -> Void,
    onLoadAll: @escaping () -> Void,
    onUnloadAll: @escaping () -> Void,
    onFileAction: ((ProjectFile, FileAction) -> Void)? = nil
  ) {
    self.files = files
    self.metadata = metadata
    self._selectedFile = selectedFile
    self._expandedFolders = expandedFolders
    self.title = title
    self.isActionBarEnabled = isActionBarEnabled
    self.onFolderToggle = onFolderToggle
    self.onSelect = onSelect
    self.onSync = onSync
    self.onImport = onImport
    self.onLoadAll = onLoadAll
    self.onUnloadAll = onUnloadAll
    self.onFileAction = onFileAction
  }

  public var body: some View {
    VStack(spacing: 0) {
      ProjectHeader(
        metadata: metadata,
        fileCount: fileCount,
        folderCount: folderCount,
        title: title
      )

      FileTreeView(
        files: files,
        expandedFolders: $expandedFolders,
        selectedFile: $selectedFile,
        onFolderToggle: onFolderToggle,
        onSelect: onSelect,
        onFileAction: onFileAction
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()

      ProjectActionBar(
        onSync: onSync,
        onImport: onImport,
        onLoadAll: onLoadAll,
        onUnloadAll: onUnloadAll,
        isEnabled: isActionBarEnabled,
        canLoadAll: !files.isEmpty,
        canUnloadAll: !files.isEmpty
      )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Derived counts

  /// The number of files (non-directory entries) in `files`.
  private var fileCount: Int {
    files.count { !$0.isDirectory }
  }

  /// The number of folders (directory entries) in `files`.
  private var folderCount: Int {
    files.count { $0.isDirectory }
  }
}

// MARK: - Previews

#Preview("macOS – Sidebar") {
  ProjectBrowserSidebarPreviewContainer()
    .frame(width: 320, height: 600)
}

#Preview("iOS – Compact Sidebar") {
  ProjectBrowserSidebarPreviewContainer()
    .frame(width: 320, height: 640)
}

/// Stateful wrapper providing working `@State` bindings for previews, since
/// `ProjectBrowserSidebar` itself owns no state.
private struct ProjectBrowserSidebarPreviewContainer: View {
  @State private var selectedFile: ProjectFile?
  @State private var expandedFolders: Set<UUID> = []

  private let files: [ProjectFile] = ProjectBrowserSidebarPreviewContainer.makePreviewFiles()

  var body: some View {
    ProjectBrowserSidebar(
      files: files,
      metadata: ProjectMetadata(
        title: "Confessions",
        author: "Tom Stovall",
        description: "A serialized audio drama exploring memory, guilt, and forgiveness.",
        created: Date()
      ),
      selectedFile: $selectedFile,
      expandedFolders: $expandedFolders,
      title: "confessions",
      onFolderToggle: { id in
        if expandedFolders.contains(id) {
          expandedFolders.remove(id)
        } else {
          expandedFolders.insert(id)
        }
      },
      onSelect: { file in selectedFile = file },
      onSync: {},
      onImport: {},
      onLoadAll: {},
      onUnloadAll: {}
    )
  }

  static func makePreviewFiles() -> [ProjectFile] {
    let episodesFolder = ProjectFile(
      name: "episodes",
      relativePath: "episodes",
      fileExtension: nil,
      isDirectory: true,
      modifiedDate: Date()
    )
    let episode1 = ProjectFile(
      name: "01-pilot.fountain",
      relativePath: "episodes/01-pilot.fountain",
      fileExtension: "fountain",
      isDirectory: false,
      modifiedDate: Date()
    )
    let readme = ProjectFile(
      name: "README.md",
      relativePath: "README.md",
      fileExtension: "md",
      isDirectory: false,
      modifiedDate: Date()
    )
    return [episodesFolder, episode1, readme]
  }
}

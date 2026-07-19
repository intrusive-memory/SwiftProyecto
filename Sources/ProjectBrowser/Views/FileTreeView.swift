import SwiftUI

/// Displays a flat array of ``ProjectFile`` entries as a hierarchical,
/// disclosure-group-based file tree.
///
/// `FileTreeView` never mutates its own state directly — expansion and
/// selection are owned by the caller (typically `ProjectWindow` or
/// `ProjectBrowserSidebar`) and threaded through as bindings, so the tree
/// stays in sync with whatever else is observing that state.
///
/// The incoming `files` array is expected to be the flattened, depth-first
/// output of ``ProjectFileDiscovery/discover(at:)`` — folders immediately
/// followed by their descendants — but `FileTreeView` re-derives the actual
/// parent/child relationships from each file's `relativePath`, so any
/// correctly-pathed array works regardless of ordering.
///
/// ## Example
///
/// ```swift
/// FileTreeView(
///   files: discoveredFiles,
///   expandedFolders: $expandedFolders,
///   selectedFile: $selectedFile,
///   onFolderToggle: { id in expandedFolders.formSymmetricDifference([id]) },
///   onSelect: { file in selectedFile = file }
/// )
/// ```
public struct FileTreeView: View {

  private let files: [ProjectFile]

  @Binding private var expandedFolders: Set<UUID>
  @Binding private var selectedFile: ProjectFile?

  private let onFolderToggle: (UUID) -> Void
  private let onSelect: (ProjectFile) -> Void

  /// Invoked when the user chooses a file action from a file row's context
  /// menu (reload, delete, show in Finder). `nil` (the default) hides the
  /// context menu entirely.
  private let onFileAction: ((ProjectFile, FileAction) -> Void)?

  /// Creates a hierarchical file tree view.
  ///
  /// - Parameters:
  ///   - files: The flat array of files/folders to display, typically the
  ///     output of ``ProjectFileDiscovery/discover(at:)``.
  ///   - expandedFolders: The set of folder ``ProjectFile/id``s currently
  ///     expanded. Owned by the caller.
  ///   - selectedFile: The currently-selected file, or `nil` if none.
  ///     Owned by the caller.
  ///   - onFolderToggle: Invoked with a folder's id when the user
  ///     expands/collapses it. The caller is responsible for updating
  ///     `expandedFolders` in response.
  ///   - onSelect: Invoked with a file when the user selects it. The caller
  ///     is responsible for updating `selectedFile` in response.
  ///   - onFileAction: Invoked with a file and the chosen action when the
  ///     user picks a context-menu item. `nil` hides the context menu.
  public init(
    files: [ProjectFile],
    expandedFolders: Binding<Set<UUID>>,
    selectedFile: Binding<ProjectFile?>,
    onFolderToggle: @escaping (UUID) -> Void,
    onSelect: @escaping (ProjectFile) -> Void,
    onFileAction: ((ProjectFile, FileAction) -> Void)? = nil
  ) {
    self.files = files
    self._expandedFolders = expandedFolders
    self._selectedFile = selectedFile
    self.onFolderToggle = onFolderToggle
    self.onSelect = onSelect
    self.onFileAction = onFileAction
  }

  public var body: some View {
    List {
      ForEach(FileTreeView.buildTree(from: files)) { node in
        FileTreeNodeRow(
          node: node,
          expandedFolders: $expandedFolders,
          selectedFile: $selectedFile,
          onFolderToggle: onFolderToggle,
          onSelect: onSelect,
          onFileAction: onFileAction
        )
      }
    }
    #if os(macOS)
      .listStyle(.sidebar)
    #endif
  }

  // MARK: - Tree Building

  /// Builds a nested tree of ``FileTreeNode`` from a flat array of
  /// ``ProjectFile``, grouping entries by the parent directory implied by
  /// their `relativePath`.
  static func buildTree(from files: [ProjectFile]) -> [FileTreeNode] {
    var childrenByParentPath: [String: [ProjectFile]] = [:]
    for file in files {
      let parent = parentPath(of: file.relativePath)
      childrenByParentPath[parent, default: []].append(file)
    }

    func makeNodes(parentPath: String) -> [FileTreeNode] {
      let entries = childrenByParentPath[parentPath] ?? []
      return entries.map { file in
        FileTreeNode(
          file: file,
          children: file.isDirectory ? makeNodes(parentPath: file.relativePath) : []
        )
      }
    }

    return makeNodes(parentPath: "")
  }

  /// Returns the parent directory's relative path for a given
  /// `relativePath` (e.g. `"episodes/01/outline.fountain"` →
  /// `"episodes/01"`; `"README.md"` → `""`).
  static func parentPath(of relativePath: String) -> String {
    var components = relativePath.split(separator: "/", omittingEmptySubsequences: true)
      .map(String.init)
    guard !components.isEmpty else { return "" }
    components.removeLast()
    return components.joined(separator: "/")
  }
}

/// A single node in the tree built from a flat ``ProjectFile`` array,
/// carrying its already-resolved children.
struct FileTreeNode: Identifiable, Hashable {
  let file: ProjectFile
  let children: [FileTreeNode]

  var id: UUID { file.id }
}

/// Renders a single ``FileTreeNode``: a `DisclosureGroup` for directories
/// (recursing into children), or a selectable row with icon and label for
/// files.
private struct FileTreeNodeRow: View {
  let node: FileTreeNode

  @Binding var expandedFolders: Set<UUID>
  @Binding var selectedFile: ProjectFile?

  let onFolderToggle: (UUID) -> Void
  let onSelect: (ProjectFile) -> Void
  let onFileAction: ((ProjectFile, FileAction) -> Void)?

  private var isExpanded: Binding<Bool> {
    Binding(
      get: { expandedFolders.contains(node.file.id) },
      set: { _ in onFolderToggle(node.file.id) }
    )
  }

  private var isSelected: Bool {
    selectedFile?.id == node.file.id
  }

  var body: some View {
    if node.file.isDirectory {
      DisclosureGroup(isExpanded: isExpanded) {
        ForEach(node.children) { child in
          FileTreeNodeRow(
            node: child,
            expandedFolders: $expandedFolders,
            selectedFile: $selectedFile,
            onFolderToggle: onFolderToggle,
            onSelect: onSelect,
            onFileAction: onFileAction
          )
        }
      } label: {
        FileTreeRowLabel(file: node.file)
      }
    } else {
      FileTreeRowLabel(file: node.file)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
          RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        )
        .onTapGesture {
          onSelect(node.file)
        }
        .contextMenu {
          if let onFileAction {
            Button {
              onFileAction(node.file, .reload)
            } label: {
              Label("Reload", systemImage: "arrow.clockwise")
            }

            #if os(macOS)
              Button {
                onFileAction(node.file, .showInFinder)
              } label: {
                Label("Show in Finder", systemImage: "folder")
              }
            #endif

            Divider()

            Button(role: .destructive) {
              onFileAction(node.file, .delete)
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
        }
    }
  }
}

/// The icon + name label shared by both folder and file rows, including
/// loading/error state indicators for files.
private struct FileTreeRowLabel: View {
  let file: ProjectFile

  var body: some View {
    Label {
      Text(file.displayName)
        .lineLimit(1)
        .truncationMode(.middle)
    } icon: {
      Image(systemName: iconName)
        .foregroundStyle(iconColor)
    }
  }

  private var iconName: String {
    if file.isDirectory {
      return "folder.fill"
    }

    switch file.loadingState {
    case .loading:
      return "arrow.triangle.2.circlepath"
    case .error:
      return "exclamationmark.triangle.fill"
    case .notLoaded, .loaded, .stale:
      return FileTreeRowLabel.fileIconName(forExtension: file.fileExtension)
    }
  }

  private var iconColor: Color {
    switch file.loadingState {
    case .error:
      return .orange
    case .loading:
      return .secondary
    default:
      return file.isDirectory ? .blue : .secondary
    }
  }

  /// Maps a file extension to a representative SF Symbol name. Falls back to
  /// a generic document icon for unrecognized or missing extensions.
  static func fileIconName(forExtension fileExtension: String?) -> String {
    guard let ext = fileExtension?.lowercased() else {
      return "doc"
    }

    switch ext {
    case "txt", "md", "markdown", "fountain", "rtf":
      return "doc.text"
    case "swift", "js", "ts", "py", "json", "yaml", "yml", "xml", "html", "css":
      return "chevron.left.forwardslash.chevron.right"
    case "pdf":
      return "doc.richtext"
    case "png", "jpg", "jpeg", "gif", "heic", "webp":
      return "photo"
    case "mp3", "wav", "m4a", "aiff", "caf":
      return "waveform"
    case "mp4", "mov", "m4v":
      return "film"
    case "zip", "tar", "gz":
      return "doc.zipper"
    default:
      return "doc"
    }
  }
}

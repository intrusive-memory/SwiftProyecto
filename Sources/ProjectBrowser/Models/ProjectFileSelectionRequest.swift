import SwiftUI

/// A host-callable action that asks ``ProjectWindow`` to select a file by its
/// path relative to ``ProjectWindow/directoryURL``.
///
/// The window installs this in the environment of its detail pane, so any view
/// the host renders there can read it with `@Environment(\.selectProjectFile)`:
///
/// ```swift
/// @Environment(\.selectProjectFile) private var selectProjectFile
///
/// Button("Open chapter 2") { selectProjectFile("chapter2.md") }
/// ```
///
/// A request runs the same path a sidebar click does: the file is highlighted,
/// its ancestor folders are expanded, and `onFileSelection` fires. A path that is
/// not in the discovered tree, or that names a directory, is ignored. Requesting
/// the file that is already selected does nothing. A file listed in
/// `expectedFiles` but absent on disk is selected like any other, and goes to
/// `onMissingFileSelected` as a click on its row does.
///
/// Outside a ``ProjectWindow`` detail pane the default action does nothing.
public struct ProjectFileSelectionAction: Sendable {

  private let perform: @MainActor @Sendable (String) -> Void

  /// Creates an action that forwards each relative path to `perform`.
  public init(perform: @escaping @MainActor @Sendable (String) -> Void) {
    self.perform = perform
  }

  /// Requests selection of the file at `relativePath`, relative to the
  /// window's `directoryURL` (e.g. `"episodes/01/outline.fountain"`).
  @MainActor
  public func callAsFunction(_ relativePath: String) {
    perform(relativePath)
  }
}

private struct ProjectFileSelectionKey: EnvironmentKey {
  static let defaultValue = ProjectFileSelectionAction { _ in }
}

extension EnvironmentValues {

  /// Requests that the enclosing ``ProjectWindow`` select a file by path. See
  /// ``ProjectFileSelectionAction``.
  public var selectProjectFile: ProjectFileSelectionAction {
    get { self[ProjectFileSelectionKey.self] }
    set { self[ProjectFileSelectionKey.self] = newValue }
  }
}

/// Resolves a host's relative path against a window's discovered file list.
///
/// Kept separate from ``ProjectWindow`` so the lookup and the ancestor
/// calculation can be tested without driving the window's `@State`.
enum ProjectFileSelectionResolver {

  /// The file to select, and the ids of the folders that must be expanded for
  /// its row to be visible.
  struct Resolution: Equatable {
    let file: ProjectFile
    let ancestorFolderIDs: Set<UUID>
  }

  /// Returns the selection for `relativePath`, or `nil` when no file in `files`
  /// has that path or the path names a directory.
  ///
  /// Matching is exact on ``ProjectFile/relativePath``. The host's path is never
  /// used to build a `ProjectFile`, because a host-built value never equals the
  /// window's own (its `id` is a fresh `UUID`).
  static func resolve(relativePath: String, in files: [ProjectFile]) -> Resolution? {
    guard let file = files.first(where: { $0.relativePath == relativePath }),
      !file.isDirectory
    else {
      return nil
    }

    var ancestorFolderIDs: Set<UUID> = []
    var ancestorPath = ""
    let components = relativePath.split(separator: "/", omittingEmptySubsequences: true)
    for component in components.dropLast() {
      ancestorPath = ancestorPath.isEmpty ? String(component) : "\(ancestorPath)/\(component)"
      if let folder = files.first(where: { $0.isDirectory && $0.relativePath == ancestorPath }) {
        ancestorFolderIDs.insert(folder.id)
      }
    }

    return Resolution(file: file, ancestorFolderIDs: ancestorFolderIDs)
  }
}

/// The selection transitions ``ProjectWindow`` runs, with its `@State` passed
/// in as `inout` and its side effects passed in as closures.
///
/// The window calls these and nothing else to change the selection, so tests
/// that call them with plain variables and recording closures exercise exactly
/// what a sidebar click and a host request do, without hosting the view.
@MainActor
enum ProjectWindowSelection {

  /// A sidebar click, or a resolved host request: sets the selection, reports
  /// it through `onFileSelection`, then either routes an expected-but-missing
  /// file to `onMissingFileSelected` or asks for its content to be loaded.
  static func select(
    _ file: ProjectFile,
    selectedFile: inout ProjectFile?,
    onFileSelection: FileSelectionCallback?,
    onMissingFileSelected: ((String) -> Void)?,
    loadContent: (ProjectFile) -> Void
  ) {
    selectedFile = file
    onFileSelection?(file)
    if file.isExpectedButMissing {
      onMissingFileSelected?(file.relativePath)
    } else {
      loadContent(file)
    }
  }

  /// A host request by relative path: resolves it against `files`, expands the
  /// file's ancestor folders, and hands the window's own ``ProjectFile`` to
  /// `select`. An unknown path, a directory, and the file already selected are
  /// ignored, leaving the selection and the expanded folders as they were.
  ///
  /// An expected-but-missing file is in `files`, so it is selected like any
  /// other and `select` routes it to `onMissingFileSelected`, as a click on its
  /// row does.
  ///
  /// `currentSelection` is passed by value, not `inout`: `select` writes the
  /// window's selection itself, and an `inout` copy written back afterwards
  /// would undo that write.
  ///
  /// - Returns: `true` when the request selected a file.
  @discardableResult
  static func request(
    relativePath: String,
    in files: [ProjectFile],
    currentSelection: ProjectFile?,
    expandedFolders: inout Set<UUID>,
    select: (ProjectFile) -> Void
  ) -> Bool {
    guard
      let resolution = ProjectFileSelectionResolver.resolve(
        relativePath: relativePath, in: files),
      currentSelection?.relativePath != resolution.file.relativePath
    else {
      return false
    }
    expandedFolders.formUnion(resolution.ancestorFolderIDs)
    select(resolution.file)
    return true
  }
}

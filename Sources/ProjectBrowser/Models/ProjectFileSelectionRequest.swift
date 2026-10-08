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
/// the file that is already selected does nothing.
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

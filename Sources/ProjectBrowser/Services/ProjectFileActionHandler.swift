import Foundation

#if os(macOS)
  import AppKit
#endif

/// Errors surfaced by ``ProjectFileActionHandler`` when a built-in
/// ``FileAction`` cannot be completed against the filesystem.
public enum ProjectFileActionError: LocalizedError, Equatable, Sendable {

  /// The file no longer exists at its expected location (deleted
  /// externally, moved, or the tree is stale).
  case fileNotFound(String)

  /// The operation failed because of filesystem permissions.
  case permissionDenied(String)

  /// Any other failure, carrying the underlying error's description.
  case underlying(String)

  public var errorDescription: String? {
    switch self {
    case .fileNotFound(let path):
      return "File not found: \(path)"
    case .permissionDenied(let path):
      return "Permission denied: \(path)"
    case .underlying(let message):
      return message
    }
  }
}

/// The outcome of handling a ``FileAction`` against a specific
/// ``ProjectFile``, as computed by
/// ``ProjectFileActionHandler/handle(action:file:in:contentLoader:)``.
///
/// `ProjectWindow` applies this result to its own `@State` (updating the
/// file list, selection, and cached contents); the handler itself never
/// touches SwiftUI state, which keeps it fully unit-testable in isolation
/// from any view.
public struct ProjectFileActionResult: Equatable, Sendable {

  /// The file's freshly-fetched contents, if `.reload` was requested and
  /// succeeded. `nil` for every other action, or if `.reload` failed.
  public var reloadedContents: ProjectFileContents?

  /// Whether `.delete` was requested and successfully removed the file
  /// from disk. `ProjectWindow` uses this to decide whether to also drop
  /// the file (and, for directories, its descendants) from its file list.
  public var didDelete: Bool

  /// A human-readable error message if the action failed, otherwise `nil`.
  public var errorMessage: String?

  public init(
    reloadedContents: ProjectFileContents? = nil,
    didDelete: Bool = false,
    errorMessage: String? = nil
  ) {
    self.reloadedContents = reloadedContents
    self.didDelete = didDelete
    self.errorMessage = errorMessage
  }
}

#if os(macOS)
  /// Abstracts `NSWorkspace`'s file-reveal API so
  /// ``ProjectFileActionHandler/showInFinder(file:in:workspace:)`` can be
  /// unit tested without actually opening a Finder window.
  public protocol FileRevealing {
    @discardableResult
    func selectFile(_ fullPath: String?, inFileViewerRootedAtPath rootFullPath: String) -> Bool
  }

  extension NSWorkspace: FileRevealing {}
#endif

/// Stateless implementations of the built-in ``FileAction`` cases
/// (``FileAction/reload``, ``FileAction/delete``, ``FileAction/showInFinder``),
/// factored out of `ProjectWindow` so they can be unit tested without
/// standing up any SwiftUI view state.
///
/// `ProjectWindow` calls ``handle(action:file:in:contentLoader:)`` from its
/// own action-dispatch method, then applies the returned
/// ``ProjectFileActionResult`` to its `@State` (file list, selection,
/// cached contents) and finally forwards the action to the consumer's
/// `FileActionCallback`, per the contract documented on ``FileAction``.
public enum ProjectFileActionHandler {

  // MARK: - Dispatch

  /// Performs the built-in behavior (if any) for `action` against `file`,
  /// returning a result `ProjectWindow` can apply to its own state.
  ///
  /// - `.reload` re-fetches the file's contents (via `contentLoader` if
  ///   supplied, otherwise by reading the file directly from disk).
  /// - `.delete` removes the file from disk.
  /// - `.showInFinder` reveals the file in Finder (macOS only; a no-op on
  ///   other platforms).
  /// - `.custom` is never interpreted here — `ProjectBrowser` doesn't know
  ///   what consumer-defined actions mean, so this always returns an empty
  ///   result for it. `ProjectWindow` still forwards `.custom` actions to
  ///   the consumer's callback itself.
  public static func handle(
    action: FileAction,
    file: ProjectFile,
    in directoryURL: URL,
    contentLoader: FileLoaderCallback? = nil
  ) async -> ProjectFileActionResult {
    switch action {
    case .reload:
      do {
        let contents = try await reload(file: file, in: directoryURL, contentLoader: contentLoader)
        return ProjectFileActionResult(reloadedContents: contents)
      } catch {
        return ProjectFileActionResult(errorMessage: error.localizedDescription)
      }

    case .delete:
      do {
        try delete(file: file, in: directoryURL)
        return ProjectFileActionResult(didDelete: true)
      } catch {
        return ProjectFileActionResult(errorMessage: error.localizedDescription)
      }

    case .showInFinder:
      #if os(macOS)
        showInFinder(file: file, in: directoryURL)
      #endif
      return ProjectFileActionResult()

    case .custom:
      return ProjectFileActionResult()
    }
  }

  // MARK: - Reload

  /// Re-fetches `file`'s contents: via `contentLoader` if the consumer
  /// supplied one, otherwise by reading the file directly from disk as
  /// UTF-8 text (falling back to `nil` text — but still-present `data` —
  /// if the bytes aren't valid UTF-8).
  ///
  /// - Throws: ``ProjectFileActionError/fileNotFound(_:)`` if the file no
  ///   longer exists, ``ProjectFileActionError/permissionDenied(_:)`` if it
  ///   can't be read, or ``ProjectFileActionError/underlying(_:)`` for any
  ///   other failure (including one thrown by `contentLoader`).
  public static func reload(
    file: ProjectFile,
    in directoryURL: URL,
    contentLoader: FileLoaderCallback? = nil
  ) async throws -> ProjectFileContents {
    if let contentLoader {
      do {
        return try await contentLoader(file)
      } catch let error as ProjectFileActionError {
        throw error
      } catch {
        throw ProjectFileActionError.underlying(error.localizedDescription)
      }
    }

    let url = fileURL(for: file, in: directoryURL)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw ProjectFileActionError.fileNotFound(file.relativePath)
    }

    do {
      let data = try Data(contentsOf: url)
      let text = String(data: data, encoding: .utf8)
      return ProjectFileContents(file: file, data: data, text: text, loadedAt: Date())
    } catch {
      throw mapReadError(error, path: file.relativePath)
    }
  }

  // MARK: - Delete

  /// Deletes `file` from disk. Directories are removed recursively.
  ///
  /// - Throws: ``ProjectFileActionError/fileNotFound(_:)`` if the file no
  ///   longer exists, ``ProjectFileActionError/permissionDenied(_:)`` if
  ///   removal isn't permitted, or ``ProjectFileActionError/underlying(_:)``
  ///   for any other failure.
  public static func delete(file: ProjectFile, in directoryURL: URL) throws {
    let url = fileURL(for: file, in: directoryURL)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw ProjectFileActionError.fileNotFound(file.relativePath)
    }

    do {
      try FileManager.default.removeItem(at: url)
    } catch {
      throw mapWriteError(error, path: file.relativePath)
    }
  }

  /// Computes the file list that results from removing `file` — and, if
  /// it's a directory, all of its descendants (matched by `relativePath`
  /// prefix) — from `files`. Pure and side-effect free, so `ProjectWindow`
  /// can use it to update its `@State` after a successful `.delete`.
  public static func removingFromTree(_ file: ProjectFile, from files: [ProjectFile]) -> [ProjectFile] {
    let descendantPrefix = file.relativePath + "/"
    return files.filter { candidate in
      guard candidate.id != file.id else { return false }
      if file.isDirectory && candidate.relativePath.hasPrefix(descendantPrefix) {
        return false
      }
      return true
    }
  }

  // MARK: - Show in Finder

  #if os(macOS)
    /// Reveals `file` in macOS Finder, selecting it within a window rooted
    /// at `directoryURL`.
    ///
    /// - Parameter workspace: The `FileRevealing`-conforming object used to
    ///   perform the reveal. Defaults to `NSWorkspace.shared`; overridable
    ///   for testing.
    @discardableResult
    public static func showInFinder(
      file: ProjectFile,
      in directoryURL: URL,
      workspace: FileRevealing = NSWorkspace.shared
    ) -> Bool {
      let url = fileURL(for: file, in: directoryURL)
      return workspace.selectFile(url.path, inFileViewerRootedAtPath: directoryURL.path)
    }
  #endif

  // MARK: - Helpers

  private static func fileURL(for file: ProjectFile, in directoryURL: URL) -> URL {
    directoryURL.appendingPathComponent(file.relativePath)
  }

  private static func mapReadError(_ error: Error, path: String) -> ProjectFileActionError {
    let nsError = error as NSError
    if nsError.domain == NSCocoaErrorDomain,
      nsError.code == CocoaError.fileReadNoPermission.rawValue
    {
      return .permissionDenied(path)
    }
    if nsError.domain == NSCocoaErrorDomain,
      nsError.code == CocoaError.fileReadNoSuchFile.rawValue
    {
      return .fileNotFound(path)
    }
    return .underlying(error.localizedDescription)
  }

  private static func mapWriteError(_ error: Error, path: String) -> ProjectFileActionError {
    let nsError = error as NSError
    if nsError.domain == NSCocoaErrorDomain,
      nsError.code == CocoaError.fileWriteNoPermission.rawValue
        || nsError.code == CocoaError.fileWriteVolumeReadOnly.rawValue
    {
      return .permissionDenied(path)
    }
    if nsError.domain == NSCocoaErrorDomain,
      nsError.code == CocoaError.fileNoSuchFile.rawValue
    {
      return .fileNotFound(path)
    }
    // POSIX EACCES/EPERM surfaced directly (not wrapped as a CocoaError).
    if nsError.domain == NSPOSIXErrorDomain,
      nsError.code == Int(EACCES) || nsError.code == Int(EPERM)
    {
      return .permissionDenied(path)
    }
    return .underlying(error.localizedDescription)
  }
}

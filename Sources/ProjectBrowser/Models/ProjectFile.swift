import Foundation

/// A single file or directory entry discovered within a project directory
/// browsed by `ProjectWindow`.
///
/// `ProjectFile` is a lightweight description of a filesystem entry — it
/// does not carry file contents. Contents are loaded lazily on demand and
/// represented separately by ``ProjectFileContents``.
///
/// ## Example
///
/// ```swift
/// let file = ProjectFile(
///   name: "outline.fountain",
///   relativePath: "episodes/01/outline.fountain",
///   fileExtension: "fountain",
///   isDirectory: false,
///   modifiedDate: Date(),
///   isLoaded: false,
///   loadingState: .notLoaded,
///   error: nil
/// )
/// ```
public struct ProjectFile: Identifiable, Codable, Hashable, Equatable, Sendable {

  /// A stable identifier for this file, unique within a single discovery
  /// pass. Used for SwiftUI selection state and diffing.
  public let id: UUID

  /// The file or directory's last path component (e.g. `"outline.fountain"`).
  public let name: String

  /// The path of this entry relative to the root directory passed to
  /// `ProjectWindow` (e.g. `"episodes/01/outline.fountain"`).
  public let relativePath: String

  /// The file's extension without the leading dot (e.g. `"fountain"`), or
  /// `nil` for directories and extensionless files.
  public let fileExtension: String?

  /// Whether this entry represents a directory rather than a file.
  public let isDirectory: Bool

  /// The entry's last-modified date as reported by the filesystem.
  public let modifiedDate: Date

  /// The entry's size in bytes as reported by the filesystem, or `nil` for
  /// directories or when the size could not be determined.
  public let fileSize: Int64?

  /// Whether this file's contents have been loaded into memory at least
  /// once during the current browsing session.
  public let isLoaded: Bool

  /// The current lazy-loading state of this file's contents.
  public let loadingState: FileLoadingState

  /// A human-readable error message if the most recent load attempt
  /// failed, otherwise `nil`.
  public let error: String?

  public init(
    id: UUID = UUID(),
    name: String,
    relativePath: String,
    fileExtension: String?,
    isDirectory: Bool,
    modifiedDate: Date,
    fileSize: Int64? = nil,
    isLoaded: Bool = false,
    loadingState: FileLoadingState = .notLoaded,
    error: String? = nil
  ) {
    self.id = id
    self.name = name
    self.relativePath = relativePath
    self.fileExtension = fileExtension
    self.isDirectory = isDirectory
    self.modifiedDate = modifiedDate
    self.fileSize = fileSize
    self.isLoaded = isLoaded
    self.loadingState = loadingState
    self.error = error
  }

  /// Whether a registered `FileTypeHandler` is known to exist for this
  /// file's extension.
  ///
  /// - Note: This is a stub for WU1. Real handler-registry lookup is
  ///   implemented in WU3 once `FileTypeHandler` and the handler registry
  ///   are available; until then this always returns `false`.
  public var hasKnownHandler: Bool {
    false
  }

  /// A display-friendly version of ``name`` suitable for UI presentation.
  ///
  /// - Note: This is a stub for WU1. Truncation / ellipsis behavior for
  ///   long file names is implemented in WU3; until then this simply
  ///   returns ``name`` unmodified.
  public var displayName: String {
    name
  }
}

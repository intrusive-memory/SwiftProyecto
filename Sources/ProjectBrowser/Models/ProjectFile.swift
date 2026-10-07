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

  /// Whether this file was expected but is missing from the filesystem.
  /// Used to distinguish placeholder entries for expected-but-missing files
  /// (e.g., CAST.md) from discovered files.
  public let isExpectedButMissing: Bool

  /// Whether this entry is a **package bundle**: a directory on disk that the
  /// browser presents as a single, opaque file (the way Finder shows a
  /// `.textbundle` or an `.app`).
  ///
  /// A bundle is a leaf. ``isDirectory`` is `false`, nothing inside it is
  /// discovered, and ``fileExtension`` carries the bundle's extension (for
  /// example `"dossier"`), so the `handlers` registry, the sidebar icon and
  /// selection all treat it exactly like a file of that type. The one place
  /// the distinction matters is content loading: a bundle has no bytes of
  /// its own, so ``ProjectFileContentLoader`` never lazily reads one — a
  /// consumer that wants to show a bundle registers a handler for its
  /// extension and resolves the contents it needs inside the bundle itself.
  ///
  /// Decoding a ``ProjectFile`` encoded before this property existed yields
  /// `false`.
  public let isBundle: Bool

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
    error: String? = nil,
    isExpectedButMissing: Bool = false,
    isBundle: Bool = false
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
    self.isExpectedButMissing = isExpectedButMissing
    self.isBundle = isBundle
  }

  // MARK: - Codable

  private enum CodingKeys: String, CodingKey {
    case id, name, relativePath, fileExtension, isDirectory, modifiedDate, fileSize
    case isLoaded, loadingState, error, isExpectedButMissing, isBundle
  }

  /// Decodes a file, tolerating payloads written before ``isBundle`` existed
  /// (which decode with `isBundle == false`). Encoding stays synthesized.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.relativePath = try container.decode(String.self, forKey: .relativePath)
    self.fileExtension = try container.decodeIfPresent(String.self, forKey: .fileExtension)
    self.isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
    self.modifiedDate = try container.decode(Date.self, forKey: .modifiedDate)
    self.fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
    self.isLoaded = try container.decode(Bool.self, forKey: .isLoaded)
    self.loadingState = try container.decode(FileLoadingState.self, forKey: .loadingState)
    self.error = try container.decodeIfPresent(String.self, forKey: .error)
    self.isExpectedButMissing = try container.decode(Bool.self, forKey: .isExpectedButMissing)
    self.isBundle = try container.decodeIfPresent(Bool.self, forKey: .isBundle) ?? false
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

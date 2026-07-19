import Foundation

/// The lazily-loaded contents of a ``ProjectFile``, produced by a
/// consumer's `FileLoaderCallback`.
///
/// A `ProjectFileContents` value is created once a file is selected and its
/// contents are fetched. It carries either raw ``data``, decoded ``text``,
/// or both, depending on what the loader callback produced.
///
/// ## Example
///
/// ```swift
/// let contents = ProjectFileContents(
///   file: file,
///   data: nil,
///   text: "INT. OFFICE - DAY",
///   loadedAt: Date()
/// )
/// if contents.isStale {
///   // re-fetch before displaying
/// }
/// ```
public struct ProjectFileContents: Codable, Hashable, Equatable, Sendable {

  /// The file description these contents belong to.
  public let file: ProjectFile

  /// The raw file data, if the loader produced binary contents.
  public let data: Data?

  /// The decoded text contents, if the loader produced text contents.
  public let text: String?

  /// The timestamp at which these contents were fetched.
  public let loadedAt: Date

  public init(
    file: ProjectFile,
    data: Data?,
    text: String?,
    loadedAt: Date = Date()
  ) {
    self.file = file
    self.data = data
    self.text = text
    self.loadedAt = loadedAt
  }

  /// Whether these contents are considered out of date relative to the
  /// underlying file's last-modified timestamp.
  ///
  /// Contents are stale when the file on disk was modified after these
  /// contents were loaded.
  public var isStale: Bool {
    loadedAt < file.modifiedDate
  }
}

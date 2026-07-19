import Foundation

/// The lifecycle state of a file's contents as they are lazily loaded by a
/// `ProjectWindow` consumer.
///
/// `ProjectBrowser` never loads file contents eagerly — a file starts in
/// ``notLoaded`` and transitions through this state machine only once the
/// user selects it in the file tree.
///
/// ## State Transitions
///
/// ```
/// notLoaded → loading → loaded
///                     ↘ error(message)
/// loaded → stale (external change detected) → loading → loaded
/// ```
///
/// ## Example
///
/// ```swift
/// var state: FileLoadingState = .notLoaded
/// state = .loading
/// // ... contents fetched successfully ...
/// state = .loaded
/// ```
public enum FileLoadingState: Codable, Hashable, Sendable {
  /// The file's contents have not been requested yet.
  case notLoaded

  /// The file's contents are currently being fetched via the consumer's
  /// `FileLoaderCallback`.
  case loading

  /// The file's contents have been fetched and are available.
  case loaded

  /// The file's contents were loaded previously but are now considered
  /// out of date (for example, the underlying file changed on disk).
  case stale

  /// Loading the file's contents failed. The associated value carries a
  /// human-readable description of the failure.
  case error(String)
}

import Foundation

/// A user- or system-initiated action performed on a ``ProjectFile`` within
/// a `ProjectWindow`, dispatched to a consumer's `FileActionCallback`.
///
/// `ProjectBrowser` handles the built-in cases (``reload``, ``showInFinder``,
/// ``delete``) itself where possible, but always forwards the action to the
/// consumer's `FileActionCallback` so the host app can observe or override
/// behavior. ``custom(_:)`` exists purely for consumer-defined actions (e.g.
/// menu items added by a host app) and is never interpreted by
/// `ProjectBrowser` itself.
///
/// ## Example
///
/// ```swift
/// let action: FileAction = .custom("duplicate")
/// switch action {
/// case .reload:
///   // re-fetch contents
///   break
/// case .showInFinder:
///   // reveal in Finder (macOS only)
///   break
/// case .delete:
///   // remove from disk and file tree
///   break
/// case .custom(let name):
///   // consumer-defined behavior keyed by `name`
///   break
/// }
/// ```
public enum FileAction: Codable, Hashable, Equatable, Sendable {

  /// Re-fetch the file's contents from disk, discarding any cached value.
  case reload

  /// Reveal the file in the platform's file browser (macOS Finder only).
  case showInFinder

  /// Delete the file from disk and remove it from the file tree.
  case delete

  /// A consumer-defined action identified by name, for extensibility beyond
  /// the built-in cases.
  case custom(String)
}

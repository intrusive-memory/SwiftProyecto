import Foundation

/// Stateless decision logic backing `ProjectWindow`'s lazy content-loading
/// behavior (S4.3): whether a newly-selected ``ProjectFile`` needs its
/// contents fetched, given the window's current cache and in-flight loads.
///
/// `ProjectWindow` itself is a SwiftUI `View` with only `@State`-private
/// action-handling methods, so it can't be driven directly by XCTest (see
/// the note on `ProjectWindowTests`). ``shouldLoad(file:hasHandler:cache:loadingFiles:)``
/// factors the one piece of real decision-making out of that private
/// machinery so it can be unit tested in isolation, the same way
/// ``ProjectFileActionHandler`` factors out reload/delete/show-in-Finder
/// behavior for S4.2.
///
/// ## Design: handler-owned vs. fallback-rendered files
///
/// Files with a registered `FileTypeHandler` are the handler's own
/// responsibility to fetch and render — `ProjectWindow` never triggers a
/// lazy load for them, since the handler view builder receives only the raw
/// ``ProjectFile`` and is expected to fetch (or already own) whatever
/// content it needs itself. Lazy loading exists specifically to feed
/// `ProjectDetailPane`'s built-in fallback rendering
/// (`PlainTextContentView`/`UnsupportedFileView`) for files that have *no*
/// registered handler.
///
/// The actual fetch, once ``shouldLoad(file:hasHandler:cache:loadingFiles:)``
/// says to proceed, reuses ``ProjectFileActionHandler/reload(file:in:contentLoader:)``
/// — the same fetch logic used by the `.reload` file action — which calls
/// the consumer's `FileLoaderCallback` if one was supplied, or falls back to
/// reading the file directly from disk as UTF-8 text otherwise.
public enum ProjectFileContentLoader {

  /// Whether `ProjectWindow` should kick off a lazy content load for `file`.
  ///
  /// Returns `false` (skip) when any of the following hold:
  /// - `hasHandler` is `true` — a registered `FileTypeHandler` owns fetching
  ///   this file's content itself.
  /// - `cache` already has an entry for `file.id` — a cache hit; the
  ///   previously-loaded contents are still good enough to display.
  /// - `loadingFiles` already contains `file.id` — a load is already in
  ///   flight; don't start a second, redundant one.
  ///
  /// Otherwise returns `true` (load): the file has no handler, isn't
  /// cached, and isn't already loading.
  public static func shouldLoad(
    file: ProjectFile,
    hasHandler: Bool,
    cache: [UUID: ProjectFileContents],
    loadingFiles: Set<UUID>
  ) -> Bool {
    guard !hasHandler else { return false }
    guard cache[file.id] == nil else { return false }
    guard !loadingFiles.contains(file.id) else { return false }
    return true
  }
}

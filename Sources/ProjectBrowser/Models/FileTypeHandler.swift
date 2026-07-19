import SwiftUI

/// A consumer-supplied callback invoked when the file selection changes in a
/// `ProjectWindow`.
public typealias FileSelectionCallback = @Sendable (ProjectFile) -> Void

/// A consumer-supplied callback that asynchronously loads the contents of a
/// selected ``ProjectFile``.
///
/// `ProjectWindow` invokes this lazily — only once a file is selected — and
/// surfaces thrown errors via ``ProjectFile/loadingState``'s `.error` case.
public typealias FileLoaderCallback = @Sendable (ProjectFile) async throws -> ProjectFileContents

/// A consumer-supplied callback invoked when a ``FileAction`` is triggered
/// for a given ``ProjectFile`` (for example, from a context menu or the
/// detail pane's toolbar).
public typealias FileActionCallback = @Sendable (ProjectFile, FileAction) -> Void

/// A consumer-supplied callback that persists edited text back to a
/// ``ProjectFile``.
///
/// `ProjectWindow` invokes this when the user saves an edit made in the
/// default editable text view (``EditableTextContentView``). When a consumer
/// doesn't supply one, `ProjectWindow` falls back to writing the text
/// directly to disk as UTF-8 (see
/// ``ProjectFileActionHandler/save(text:to:in:fileWriter:)``).
public typealias FileWriterCallback = @Sendable (ProjectFile, String) async throws -> Void

/// Associates a file extension with a SwiftUI view builder used to render
/// files of that type in a `ProjectWindow`'s detail pane.
///
/// Consumers register `FileTypeHandler` values (or an equivalent
/// `[String: (ProjectFile) -> AnyView]` dictionary — see Open Question Q1 in
/// the execution plan) to opt files of a given extension into custom
/// rendering. Extensions with no registered handler fall back to
/// `ProjectBrowser`'s default content views (implemented in WU3).
///
/// ## Example
///
/// ```swift
/// let fountainHandler = FileTypeHandler(fileExtension: "fountain") { file in
///   AnyView(ScreenplayView(file: file))
/// }
/// ```
public struct FileTypeHandler: Identifiable, Sendable {

  /// The handler's identity, equal to ``fileExtension``.
  public var id: String { fileExtension }

  /// The file extension this handler renders, without the leading dot
  /// (e.g. `"fountain"`).
  public let fileExtension: String

  /// Builds the SwiftUI view used to render a file with this handler's
  /// extension.
  public let viewBuilder: @Sendable (ProjectFile) -> AnyView

  public init(
    fileExtension: String,
    viewBuilder: @escaping @Sendable (ProjectFile) -> AnyView
  ) {
    self.fileExtension = fileExtension
    self.viewBuilder = viewBuilder
  }
}

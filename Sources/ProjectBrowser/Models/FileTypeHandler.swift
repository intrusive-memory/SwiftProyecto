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

/// A consumer-supplied builder that replaces `ProjectBrowser`'s built-in text
/// editor for handler-less UTF-8 text files.
///
/// It receives the ``ProjectFile`` and the file's decoded UTF-8 contents, and
/// returns the view to render in place of ``EditableTextContentView``.
///
/// This is the *fallback* beneath the exact-extension `handlers` registry, not
/// a replacement for it: a file whose extension has a registered handler still
/// renders through that handler. The builder only takes over the branch that
/// would otherwise construct ``EditableTextContentView`` — every file whose
/// bytes decode as UTF-8 and that has no registered handler, which is exactly
/// `ProjectBrowser`'s `text/*` test. Extension-less files like `Makefile`,
/// `LICENSE`, and `.zshrc` therefore reach the builder; a `.txt` holding
/// non-UTF-8 bytes does not, and still falls back to the read-only
/// ``PlainTextContentView``.
///
/// Because the consumer owns the substituted view, it also owns persisting
/// edits made in it — `ProjectWindow`'s `fileWriter:` and the built-in Save
/// control belong to ``EditableTextContentView`` and are bypassed entirely.
///
/// Like `handlers`, this is deliberately a plain (non-`Sendable`) closure: it
/// is a SwiftUI view builder invoked during body evaluation on the main actor.
///
/// ## Example
///
/// ```swift
/// ProjectWindow(
///   directoryURL: projectFolderURL,
///   textEditorBuilder: { file, text in
///     AnyView(MyEditor(url: projectFolderURL.appending(path: file.relativePath), text: text))
///   }
/// )
/// ```
public typealias TextEditorBuilder = (ProjectFile, String) -> AnyView

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

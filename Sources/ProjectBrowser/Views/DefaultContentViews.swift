import SwiftUI

// MARK: - PlainTextContentView

/// A fallback content view that renders a file's text contents in a
/// monospaced, scrollable view.
///
/// Used by `ProjectDetailPane` when a selected file has no registered
/// `FileTypeHandler` but its contents were loaded as text, or explicitly by
/// consumers who want a simple text viewer.
///
/// ## Example
///
/// ```swift
/// PlainTextContentView(text: contents.text)
/// ```
public struct PlainTextContentView: View {

  /// The text to display, or `nil`/empty if no content is available.
  private let text: String?

  public init(text: String?) {
    self.text = text
  }

  public var body: some View {
    if let text, !text.isEmpty {
      ScrollView {
        Text(text)
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      VStack(spacing: 8) {
        Image(systemName: "doc.text")
          .font(.system(size: 32))
          .foregroundStyle(.secondary)
        Text("No content")
          .font(.body)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

// MARK: - UnsupportedFileView

/// A fallback content view shown when a selected `ProjectFile` has no
/// registered `FileTypeHandler` for its extension.
///
/// ## Example
///
/// ```swift
/// UnsupportedFileView(file: selectedFile)
/// ```
public struct UnsupportedFileView: View {

  /// The file for which no handler was found.
  private let file: ProjectFile

  public init(file: ProjectFile) {
    self.file = file
  }

  private var extensionLabel: String {
    if let ext = file.fileExtension, !ext.isEmpty {
      return ".\(ext)"
    }
    return "unknown type"
  }

  private var handlerHint: String {
    if let ext = file.fileExtension, !ext.isEmpty {
      return "No file handler for the binary type '.\(ext)'"
    }
    return "No file handler registered for this file type"
  }

  public var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.questionmark")
        .font(.system(size: 40))
        .foregroundStyle(.secondary)

      Text(handlerHint)
        .font(.headline)
        .multilineTextAlignment(.center)

      Text("Register a file handler to view this content")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

// MARK: - LoadingView

/// A centered loading indicator shown while a file's contents are being
/// fetched via a consumer's `FileLoaderCallback`.
///
/// ## Example
///
/// ```swift
/// LoadingView(filename: file.displayName)
/// ```
public struct LoadingView: View {

  /// The name of the file currently being loaded.
  private let filename: String

  public init(filename: String) {
    self.filename = filename
  }

  public var body: some View {
    VStack(spacing: 12) {
      ProgressView()
        .controlSize(.large)

      Text("Loading: \(filename.isEmpty ? "…" : filename)")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

// MARK: - ErrorView

/// A centered error state view with a message and retry action.
///
/// ## Example
///
/// ```swift
/// ErrorView(error: "File not found") {
///   Task { await reload(file) }
/// }
/// ```
public struct ErrorView: View {

  /// A human-readable error message to display.
  private let error: String

  /// Invoked when the user taps the "Retry" button.
  private let onRetry: () -> Void

  public init(error: String, onRetry: @escaping () -> Void) {
    self.error = error
    self.onRetry = onRetry
  }

  public var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 36))
        .foregroundStyle(.red)

      Text(error.isEmpty ? "An unknown error occurred." : error)
        .font(.body)
        .foregroundStyle(.red)
        .multilineTextAlignment(.center)

      Button("Retry", action: onRetry)
        .buttonStyle(.borderedProminent)
        .padding(.top, 4)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

// MARK: - Previews

#Preview("PlainTextContentView - macOS", traits: .fixedLayout(width: 480, height: 320)) {
  PlainTextContentView(text: "INT. OFFICE - DAY\n\nA quiet room.")
}

#Preview("PlainTextContentView - Empty", traits: .fixedLayout(width: 480, height: 320)) {
  PlainTextContentView(text: nil)
}

#Preview("UnsupportedFileView", traits: .fixedLayout(width: 480, height: 320)) {
  UnsupportedFileView(
    file: ProjectFile(
      name: "reel.mov",
      relativePath: "assets/reel.mov",
      fileExtension: "mov",
      isDirectory: false,
      modifiedDate: Date()
    )
  )
}

#Preview("UnsupportedFileView - No Extension", traits: .fixedLayout(width: 480, height: 320)) {
  UnsupportedFileView(
    file: ProjectFile(
      name: "README",
      relativePath: "README",
      fileExtension: nil,
      isDirectory: false,
      modifiedDate: Date()
    )
  )
}

#Preview("LoadingView", traits: .fixedLayout(width: 480, height: 320)) {
  LoadingView(filename: "outline.fountain")
}

#Preview("ErrorView", traits: .fixedLayout(width: 480, height: 320)) {
  ErrorView(error: "Failed to load file: permission denied.") {}
}

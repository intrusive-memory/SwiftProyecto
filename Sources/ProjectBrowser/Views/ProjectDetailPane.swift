import SwiftUI

/// Renders the contents of the currently-selected ``ProjectFile`` in a
/// `ProjectWindow`, delegating to a consumer-registered handler when one
/// exists for the file's extension and falling back to
/// ``UnsupportedFileView`` otherwise.
///
/// `ProjectDetailPane` is purely presentational: it owns no state of its
/// own. Lazy content loading (``FileLoaderCallback``) and file actions
/// (``FileActionCallback``) are threaded through as optional callbacks for
/// forward compatibility with WU4 (S4.2 file actions, S4.3 lazy loading);
/// neither is invoked by `ProjectDetailPane` itself in Phase 1 — handler
/// view builders are responsible for fetching their own content today.
///
/// ## Layout
///
/// ```
/// ┌─────────────────────────────────┐
/// │                                   │
/// │  Handler view or                 │
/// │  UnsupportedFileView              │  ← fills remaining space
/// │                                   │
/// ├─────────────────────────────────┤
/// │  📄 512 bytes    🕘 Jul 17, 2026…  │  ← metadata footer
/// └─────────────────────────────────┘
/// ```
///
/// ## Example
///
/// ```swift
/// ProjectDetailPane(
///   selectedFile: selectedFile,
///   handlers: [
///     "fountain": { file in AnyView(ScreenplayView(file: file)) }
///   ]
/// )
/// ```
public struct ProjectDetailPane: View {

  /// The currently-selected file, or `nil` if none is selected.
  private let selectedFile: ProjectFile?

  /// A registry mapping file extensions (without the leading dot) to view
  /// builders. Looked up by ``ProjectFile/fileExtension`` when a file is
  /// selected.
  private let handlers: [String: (ProjectFile) -> AnyView]

  /// A consumer-supplied callback that asynchronously loads a selected
  /// file's contents.
  ///
  /// - Note: Stub for S4.3 (lazy loading). Stored but not yet invoked by
  ///   `ProjectDetailPane`.
  private let contentLoader: FileLoaderCallback?

  /// A consumer-supplied callback invoked when a file action is triggered.
  ///
  /// - Note: Stub for S4.2 (file actions). Stored but not yet invoked by
  ///   `ProjectDetailPane`.
  private let onAction: FileActionCallback?

  /// Creates a project detail pane.
  ///
  /// - Parameters:
  ///   - selectedFile: The currently-selected file, or `nil` if none.
  ///   - handlers: A registry mapping file extensions to view builders.
  ///   - contentLoader: Reserved for S4.3 lazy loading; unused in Phase 1.
  ///   - onAction: Reserved for S4.2 file actions; unused in Phase 1.
  public init(
    selectedFile: ProjectFile?,
    handlers: [String: (ProjectFile) -> AnyView],
    contentLoader: FileLoaderCallback? = nil,
    onAction: FileActionCallback? = nil
  ) {
    self.selectedFile = selectedFile
    self.handlers = handlers
    self.contentLoader = contentLoader
    self.onAction = onAction
  }

  public var body: some View {
    Group {
      if let file = selectedFile {
        VStack(spacing: 0) {
          contentView(for: file)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

          Divider()

          metadataRow(for: file)
        }
      } else {
        emptyStateView
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Content

  /// Looks up a registered handler for `file`'s extension and renders it,
  /// falling back to ``UnsupportedFileView`` when no handler is registered.
  @ViewBuilder
  private func contentView(for file: ProjectFile) -> some View {
    if let handler = handlers[file.fileExtension ?? ""] {
      handler(file)
    } else {
      UnsupportedFileView(file: file)
    }
  }

  /// Shown when no file is selected.
  private var emptyStateView: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 40))
        .foregroundStyle(.secondary)

      Text("Select a file to view its contents")
        .font(.headline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }

  // MARK: - Metadata footer

  private func metadataRow(for file: ProjectFile) -> some View {
    HStack(spacing: 16) {
      Label(Self.formattedSize(file.fileSize), systemImage: "internaldrive")
      Label(Self.formattedDate(file.modifiedDate), systemImage: "clock")
      Spacer()
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity)
  }

  // MARK: - Formatting

  private static let byteCountFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowsNonnumericFormatting = false
    return formatter
  }()

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy h:mm a"
    return formatter
  }()

  /// Formats a byte count as a human-readable string (e.g. `"2.4 MB"`,
  /// `"512 bytes"`), or a placeholder when the size is unknown (e.g. for
  /// directories).
  private static func formattedSize(_ size: Int64?) -> String {
    guard let size else {
      return "Unknown size"
    }
    return byteCountFormatter.string(fromByteCount: size)
  }

  /// Formats a date as `"MMM d, yyyy h:mm a"` (e.g. `"Jul 17, 2026 3:45 PM"`).
  private static func formattedDate(_ date: Date) -> String {
    dateFormatter.string(from: date)
  }
}

// MARK: - Previews

#Preview("macOS – No Selection", traits: .fixedLayout(width: 480, height: 360)) {
  ProjectDetailPane(selectedFile: nil, handlers: [:])
}

#Preview("macOS – With Handler", traits: .fixedLayout(width: 480, height: 360)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.fountainFile,
    handlers: [
      "fountain": { file in
        AnyView(
          PlainTextContentView(text: "INT. OFFICE - DAY\n\nA quiet room.\n\nFile: \(file.name)")
        )
      }
    ]
  )
}

#Preview("macOS – No Handler", traits: .fixedLayout(width: 480, height: 360)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.movieFile,
    handlers: [:]
  )
}

#Preview("iOS – No Selection", traits: .fixedLayout(width: 380, height: 500)) {
  ProjectDetailPane(selectedFile: nil, handlers: [:])
}

#Preview("iOS – With Handler", traits: .fixedLayout(width: 380, height: 500)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.fountainFile,
    handlers: [
      "fountain": { file in
        AnyView(PlainTextContentView(text: "INT. OFFICE - DAY\n\nA quiet room."))
      }
    ]
  )
}

#Preview("iOS – No Handler", traits: .fixedLayout(width: 380, height: 500)) {
  ProjectDetailPane(
    selectedFile: ProjectDetailPanePreviewFiles.movieFile,
    handlers: [:]
  )
}

/// Shared preview fixtures for ``ProjectDetailPane`` previews.
private enum ProjectDetailPanePreviewFiles {
  static let fountainFile = ProjectFile(
    name: "01-pilot.fountain",
    relativePath: "episodes/01-pilot.fountain",
    fileExtension: "fountain",
    isDirectory: false,
    modifiedDate: Date(),
    fileSize: 2_411_724
  )

  static let movieFile = ProjectFile(
    name: "reel.mov",
    relativePath: "assets/reel.mov",
    fileExtension: "mov",
    isDirectory: false,
    modifiedDate: Date(),
    fileSize: 512
  )
}

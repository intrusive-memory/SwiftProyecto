import SwiftUI

/// Displays summary metadata about the project directory a `ProjectWindow`
/// is browsing — title, file/folder counts, and (when available) author and
/// description sourced from `PROJECT.md`.
///
/// `ProjectHeader` is presentation-only: it never triggers discovery or
/// `PROJECT.md` loading itself. Callers (typically ``ProjectBrowserSidebar``,
/// WU3.5) pass in the already-loaded ``ProjectMetadata`` plus counts computed
/// from the discovered file tree.
///
/// ## Title Resolution
///
/// The displayed title prefers, in order: `metadata.title`, the `title`
/// initializer parameter, then the literal fallback `"Project"`.
///
/// ## Example
///
/// ```swift
/// ProjectHeader(
///   metadata: metadata,
///   fileCount: 42,
///   folderCount: 8,
///   title: directoryURL.lastPathComponent
/// )
/// ```
public struct ProjectHeader: View {

  /// Project metadata loaded from `PROJECT.md`, if present.
  private let metadata: ProjectMetadata?

  /// The number of files (non-directory entries) discovered in the project.
  private let fileCount: Int

  /// The number of folders (directory entries) discovered in the project.
  private let folderCount: Int

  /// A fallback title used when `metadata` is `nil` or has no title, such as
  /// the browsed directory's last path component.
  private let title: String?

  #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  public init(
    metadata: ProjectMetadata?,
    fileCount: Int,
    folderCount: Int,
    title: String? = nil
  ) {
    self.metadata = metadata
    self.fileCount = fileCount
    self.folderCount = folderCount
    self.title = title
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(displayTitle)
        .font(titleFont)
        .fontWeight(.bold)
        .lineLimit(2)
        .minimumScaleFactor(0.8)

      countsRow

      if let author = metadata?.author, !author.isEmpty {
        Label(author, systemImage: "person.fill")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if let description = metadata?.description, !description.isEmpty {
        Text(description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }
    }
    .padding(padding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }

  // MARK: - Subviews

  private var countsRow: some View {
    HStack(spacing: 16) {
      Label("\(fileCount) file\(fileCount == 1 ? "" : "s")", systemImage: "doc.fill")
      Label("\(folderCount) folder\(folderCount == 1 ? "" : "s")", systemImage: "folder.fill")
    }
    .font(.subheadline)
    .foregroundStyle(.secondary)
  }

  // MARK: - Derived values

  private var displayTitle: String {
    if let metadataTitle = metadata?.title, !metadataTitle.isEmpty {
      return metadataTitle
    }
    if let title, !title.isEmpty {
      return title
    }
    return "Project"
  }

  /// Responsive title size: larger on macOS and iPad-width layouts, more
  /// compact on iPhone-width (`.compact` horizontal size class) layouts.
  private var titleFont: Font {
    #if os(iOS)
      return horizontalSizeClass == .compact ? .title2 : .largeTitle
    #else
      return .largeTitle
    #endif
  }

  private var padding: EdgeInsets {
    #if os(iOS)
      EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
    #else
      EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
    #endif
  }
}

// MARK: - Previews

#Preview("macOS – Full Metadata") {
  ProjectHeader(
    metadata: ProjectMetadata(
      title: "Confessions",
      author: "Tom Stovall",
      description: "A serialized audio drama exploring memory, guilt, and forgiveness.",
      created: Date()
    ),
    fileCount: 42,
    folderCount: 8
  )
  .frame(width: 420)
}

#Preview("macOS – No Metadata") {
  ProjectHeader(
    metadata: nil,
    fileCount: 5,
    folderCount: 1,
    title: "untitled-project"
  )
  .frame(width: 420)
}

#Preview("iOS – Compact") {
  ProjectHeader(
    metadata: ProjectMetadata(
      title: "Mr. Mr. Charles",
      author: "Tom Stovall",
      description: "A podcast about a man named Charles.",
      created: Date()
    ),
    fileCount: 128,
    folderCount: 12
  )
  .frame(width: 320)
}

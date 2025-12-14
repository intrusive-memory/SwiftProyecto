//
//  ProjectModel.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation
import SwiftData

/// A screenplay project containing multiple screenplay files and metadata.
///
/// ProjectModel represents a folder-based project with a PROJECT.md manifest file,
/// screenplay files, and project-local SwiftData storage in a `.cache/` folder.
///
/// ## Project Structure
///
/// ```
/// my-project/
/// ├── PROJECT.md              ← Manifest (metadata from ProjectModel)
/// ├── .cache/                 ← SwiftData container (ProjectModel stored here)
/// ├── episode-01.fountain     ← Screenplay files (tracked in fileReferences)
/// └── season-02/
///     └── episode-01.fountain
/// ```
///
/// ## Lifecycle
///
/// 1. **Create**: User opens folder, PROJECT.md created, ProjectModel initialized
/// 2. **Discover**: Folder scanned for screenplay files, ProjectFileReferences created
/// 3. **Load**: User clicks "Load File", screenplay parsed and linked to ProjectFileReference
/// 4. **Sync**: Folder re-scanned, new/modified/missing files detected and updated
///
/// ## Usage
///
/// ```swift
/// let project = ProjectModel(
///     title: "My Series",
///     author: "Jane Showrunner"
/// )
/// project.season = 1
/// project.episodes = 12
/// modelContext.insert(project)
/// try modelContext.save()
/// ```
///
@Model
public final class ProjectModel {
    /// Unique identifier
    @Attribute(.unique) public var id: UUID

    /// Project title (from PROJECT.md front matter)
    public var title: String

    /// Project author (from PROJECT.md front matter)
    public var author: String

    /// Creation date (from PROJECT.md front matter)
    public var created: Date

    /// Optional project description
    public var projectDescription: String?

    /// Optional season number
    public var season: Int?

    /// Optional episode count
    public var episodes: Int?

    /// Optional genre
    public var genre: String?

    /// Optional tags
    public var tags: [String]?

    // MARK: - File Source Properties

    /// Type of file source (directory, git repository, package bundle)
    public var sourceType: FileSourceType

    /// Display name for the file source
    public var sourceName: String

    /// Root URL as string (for SwiftData persistence)
    ///
    /// Example: "file:///Users/jane/Documents/my-project"
    /// Use `fileSource()` to reconstruct the FileSource instance.
    public var sourceRootURL: String

    /// Security-scoped bookmark data for persistent access
    ///
    /// Stored as binary data. Use `fileSource()` to access files securely.
    public var sourceBookmarkData: Data?

    /// Last time project was synced with filesystem
    public var lastSyncDate: Date?

    /// Date when this project was last opened by the user
    ///
    /// Used to display recent items in welcome screens and "Open Recent" menus.
    /// Automatically updated when the project window is opened.
    ///
    /// - Note: A nil value indicates the project has never been opened (newly created).
    public var lastOpenedDate: Date?

    /// Raw PROJECT.md body content (markdown without front matter)
    ///
    /// This stores the project notes and description from PROJECT.md body.
    /// Front matter is stored in separate fields (title, author, etc.)
    public var projectMarkdownContent: String?

    /// All file references in this project (loaded and unloaded)
    ///
    /// Each ProjectFileReference represents a screenplay file discovered in the
    /// project folder. Files can be in various states (notLoaded, loaded, stale, etc.)
    @Relationship(deleteRule: .cascade)
    public var fileReferences: [ProjectFileReference]

    /// Create a new project.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (generated if not provided)
    ///   - title: Project title
    ///   - author: Project author
    ///   - created: Creation date (defaults to now)
    ///   - projectDescription: Optional description
    ///   - season: Optional season number
    ///   - episodes: Optional episode count
    ///   - genre: Optional genre
    ///   - tags: Optional tags
    ///   - sourceType: Type of file source
    ///   - sourceName: Display name for file source
    ///   - sourceRootURL: Root URL as string
    ///   - sourceBookmarkData: Security-scoped bookmark data
    ///   - lastSyncDate: Last sync date
    ///   - lastOpenedDate: Last opened date
    ///   - projectMarkdownContent: PROJECT.md body content
    public init(
        id: UUID = UUID(),
        title: String,
        author: String,
        created: Date = Date(),
        projectDescription: String? = nil,
        season: Int? = nil,
        episodes: Int? = nil,
        genre: String? = nil,
        tags: [String]? = nil,
        sourceType: FileSourceType,
        sourceName: String,
        sourceRootURL: String,
        sourceBookmarkData: Data? = nil,
        lastSyncDate: Date? = nil,
        lastOpenedDate: Date? = nil,
        projectMarkdownContent: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.created = created
        self.projectDescription = projectDescription
        self.season = season
        self.episodes = episodes
        self.genre = genre
        self.tags = tags
        self.sourceType = sourceType
        self.sourceName = sourceName
        self.sourceRootURL = sourceRootURL
        self.sourceBookmarkData = sourceBookmarkData
        self.lastSyncDate = lastSyncDate
        self.lastOpenedDate = lastOpenedDate
        self.projectMarkdownContent = projectMarkdownContent
        self.fileReferences = []
    }
}

// MARK: - File Source Reconstruction

public extension ProjectModel {
    /// Reconstructs a FileSource instance from stored properties.
    ///
    /// This computed property creates the appropriate FileSource implementation
    /// based on the sourceType, restoring the bookmark data for secure access.
    ///
    /// - Returns: FileSource instance (DirectoryFileSource or GitRepositoryFileSource)
    /// - Throws: Never throws - invalid data results in nil
    ///
    /// ## Usage
    ///
    /// ```swift
    /// if let source = project.fileSource() {
    ///     let files = try await source.discoverFiles()
    /// }
    /// ```
    func fileSource() -> FileSource? {
        guard let rootURL = URL(string: sourceRootURL) else {
            return nil
        }

        switch sourceType {
        case .directory:
            return DirectoryFileSource(
                url: rootURL,
                name: sourceName,
                bookmarkData: sourceBookmarkData
            )

        case .gitRepository:
            return try? GitRepositoryFileSource(
                url: rootURL,
                name: sourceName,
                bookmarkData: sourceBookmarkData
            )

        case .packageBundle:
            // TODO: Future implementation
            return nil
        }
    }
}

// MARK: - Convenience Properties

public extension ProjectModel {
    /// Number of files in project (loaded and unloaded)
    var totalFileCount: Int {
        return fileReferences.count
    }

    /// File references sorted by relative path
    var sortedFileReferences: [ProjectFileReference] {
        return fileReferences.sorted { $0.relativePath < $1.relativePath }
    }

    /// Display title with season/episode info if available
    var displayTitle: String {
        var title = self.title
        if let season = season {
            title += " - Season \(season)"
        }
        if let episodes = episodes {
            title += " (\(episodes) episodes)"
        }
        return title
    }
}

// MARK: - Queries

public extension ProjectModel {
    /// Get file reference by relative path
    ///
    /// - Parameter path: Relative path from project root
    /// - Returns: File reference if found, nil otherwise
    func fileReference(atPath path: String) -> ProjectFileReference? {
        return fileReferences.first { $0.relativePath == path }
    }

    /// Check if project needs sync (files may have changed)
    ///
    /// Returns true if:
    /// - Never synced before
    /// - Last sync was more than 1 hour ago
    var needsSync: Bool {
        guard let lastSync = lastSyncDate else { return true }

        // Check if synced more than 1 hour ago
        let hourAgo = Date().addingTimeInterval(-3600)
        return lastSync < hourAgo
    }

    /// Creates a hierarchical file tree from the project's file references.
    ///
    /// This method builds a tree structure suitable for displaying files in a
    /// hierarchical view (e.g., folder tree, outline view, etc.). The root node
    /// contains all files and directories.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let tree = project.fileTree()
    ///
    /// // Display tree
    /// for child in tree.sortedChildren {
    ///     if child.isDirectory {
    ///         print("📁 \(child.name)/")
    ///     } else {
    ///         print("📄 \(child.name)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Tree Structure
    ///
    /// Given files:
    /// - `README.md`
    /// - `Season 1/Episode 1.fountain`
    /// - `Season 1/Episode 2.fountain`
    ///
    /// Returns:
    /// ```
    /// Root (virtual)
    /// ├── README.md (file)
    /// └── Season 1/ (directory)
    ///     ├── Episode 1.fountain (file)
    ///     └── Episode 2.fountain (file)
    /// ```
    ///
    /// - Returns: Root node of the file tree
    func fileTree() -> FileNode {
        return FileNode.buildTree(from: fileReferences)
    }
}

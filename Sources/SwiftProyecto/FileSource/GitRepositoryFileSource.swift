import Foundation

/// A file source backed by a git repository on the local filesystem.
///
/// GitRepositoryFileSource extends DirectoryFileSource with git repository detection.
/// It provides the same file discovery and reading capabilities, but validates that
/// the directory contains a `.git/` folder.
///
/// ## Usage
///
/// ```swift
/// let source = try GitRepositoryFileSource(url: repoURL, name: "My Repo")
///
/// // Discover all files (respects same exclusions as DirectoryFileSource)
/// let files = try await source.discoverFiles()
///
/// // Read a specific file
/// let data = try await source.readFile(at: "script.fountain")
/// ```
///
/// ## Git Integration
///
/// This implementation provides **minimal git integration**:
/// - Validates `.git/` directory exists
/// - Uses same file exclusion patterns as DirectoryFileSource
/// - Does NOT perform git operations (use a git library for that)
/// - Does NOT track git status, branches, or commits
///
/// For git operations (status, commit, push, etc.), use a dedicated git library
/// like SwiftGit2 or shell commands.
public final class GitRepositoryFileSource: FileSource, @unchecked Sendable {
    /// Unique identifier
    public let id: UUID

    /// Display name
    public let name: String

    /// Always `.gitRepository`
    public let sourceType: FileSourceType = .gitRepository

    /// Root directory URL (must contain .git/)
    public let rootURL: URL

    /// Security-scoped bookmark data
    public var bookmarkData: Data?

    /// Files and directories to exclude from discovery
    ///
    /// Same exclusions as DirectoryFileSource, plus git-specific patterns.
    private let excludedNames: Set<String> = [
        ".git",
        ".svn",
        ".hg",
        ".cache",
        ".build",
        ".swiftpm",
        ".DS_Store",
        "Thumbs.db",
        "desktop.ini",
        ".Trash",
        "DerivedData"
    ]

    /// File patterns to exclude (PROJECT.md is handled separately)
    private let excludedPatterns: Set<String> = [
        "PROJECT.md"
    ]

    /// Creates a git repository file source.
    ///
    /// - Parameters:
    ///   - url: Root directory URL (must contain .git/)
    ///   - name: Display name (defaults to directory name)
    ///   - bookmarkData: Security-scoped bookmark data
    /// - Throws: FileSourceError.notGitRepository if .git/ not found
    public init(url: URL, name: String? = nil, bookmarkData: Data? = nil) throws {
        self.id = UUID()
        self.rootURL = url
        self.name = name ?? url.lastPathComponent
        self.bookmarkData = bookmarkData

        // Verify .git directory exists
        let gitDir = url.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        let gitExists = FileManager.default.fileExists(
            atPath: gitDir.path,
            isDirectory: &isDirectory
        )

        guard gitExists && isDirectory.boolValue else {
            throw FileSourceError.notGitRepository
        }
    }

    /// Discovers all files in the repository recursively.
    ///
    /// This method:
    /// - Walks the directory tree recursively
    /// - Excludes .git, system files, and build artifacts
    /// - Excludes PROJECT.md manifest
    /// - Returns relative paths from root
    /// - Includes modification dates and file sizes
    ///
    /// **Note:** This does NOT respect .gitignore. For .gitignore support,
    /// use a dedicated git library to query tracked files.
    ///
    /// - Returns: Array of discovered files
    /// - Throws: File system errors
    public func discoverFiles() async throws -> [DiscoveredFile] {
        var discovered: [DiscoveredFile] = []
        let fileManager = FileManager.default

        // Use BookmarkManager for security-scoped access
        try await BookmarkManager.withAccess(rootURL, bookmarkData: bookmarkData) { url in
            // Get directory enumerator
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                throw FileSourceError.permissionDenied(url.path)
            }

            for case let fileURL as URL in enumerator {
                // Check if it's a directory
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    // Skip excluded directories
                    if excludedNames.contains(fileURL.lastPathComponent) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                let filename = fileURL.lastPathComponent

                // Skip excluded files
                if excludedNames.contains(filename) || excludedPatterns.contains(filename) {
                    continue
                }

                // Calculate relative path
                guard let relativePath = calculateRelativePath(from: url, to: fileURL) else {
                    continue
                }

                // Get file metadata
                let metadata = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let modificationDate = metadata?.contentModificationDate
                let fileSize = metadata?.fileSize.map { Int64($0) }

                // Extract file extension
                let fileExtension = fileURL.pathExtension

                // Create discovered file
                let file = DiscoveredFile(
                    relativePath: relativePath,
                    filename: filename,
                    fileExtension: fileExtension,
                    modificationDate: modificationDate,
                    fileSize: fileSize
                )

                discovered.append(file)
            }
        }

        return discovered.sorted { $0.relativePath < $1.relativePath }
    }

    /// Reads the contents of a file at the given relative path.
    ///
    /// - Parameter relativePath: Path relative to repository root
    /// - Returns: File data
    /// - Throws: FileSourceError or I/O errors
    public func readFile(at relativePath: String) async throws -> Data {
        let fileURL = rootURL.appendingPathComponent(relativePath)

        return try await BookmarkManager.withAccess(rootURL, bookmarkData: bookmarkData) { _ in
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw FileSourceError.fileNotFound(relativePath)
            }

            do {
                return try Data(contentsOf: fileURL)
            } catch {
                throw FileSourceError.permissionDenied(relativePath)
            }
        }
    }

    /// Gets the modification date of a file.
    ///
    /// - Parameter relativePath: Path relative to repository root
    /// - Returns: Modification date, or nil if unavailable
    /// - Throws: FileSourceError if file doesn't exist
    public func modificationDate(for relativePath: String) throws -> Date? {
        let fileURL = rootURL.appendingPathComponent(relativePath)

        return try BookmarkManager.withAccess(rootURL, bookmarkData: bookmarkData) { _ in
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw FileSourceError.fileNotFound(relativePath)
            }

            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes?[.modificationDate] as? Date
        }
    }

    // MARK: - Private Helpers

    /// Calculates the relative path from root to target URL.
    private func calculateRelativePath(from root: URL, to target: URL) -> String? {
        let rootPath = root.standardizedFileURL.path
        let targetPath = target.standardizedFileURL.path

        guard targetPath.hasPrefix(rootPath) else {
            return nil
        }

        let relativePath = String(targetPath.dropFirst(rootPath.count))
        // Remove leading slash if present
        return relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
    }
}

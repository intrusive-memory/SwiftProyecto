import Foundation

/// A file source backed by a directory on the local filesystem.
///
/// DirectoryFileSource provides access to files in a directory, recursively
/// discovering all files while excluding system and build artifacts.
///
/// ## Usage
///
/// ```swift
/// let source = DirectoryFileSource(url: projectURL, name: "My Series")
///
/// // Discover all files
/// let files = try await source.discoverFiles()
///
/// // Read a specific file
/// let data = try await source.readFile(at: "Season 1/Episode 1.fountain")
/// ```
public final class DirectoryFileSource: FileSource, @unchecked Sendable {
    /// Unique identifier
    public let id: UUID

    /// Display name
    public let name: String

    /// Always `.directory`
    public let sourceType: FileSourceType = .directory

    /// Root directory URL
    public let rootURL: URL

    /// Security-scoped bookmark data
    public var bookmarkData: Data?

    /// Creates a directory file source with bookmark data.
    ///
    /// - Parameters:
    ///   - url: Root directory URL
    ///   - name: Display name (defaults to directory name)
    ///   - bookmarkData: Security-scoped bookmark data
    public init(url: URL, name: String? = nil, bookmarkData: Data? = nil) {
        self.id = UUID()
        self.rootURL = url
        self.name = name ?? url.lastPathComponent
        self.bookmarkData = bookmarkData
    }

    /// Files and directories to exclude from discovery
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

    /// Discovers all files in the directory recursively.
    ///
    /// This method:
    /// - Walks the directory tree recursively
    /// - Excludes system files and build artifacts
    /// - Excludes PROJECT.md manifest
    /// - Returns relative paths from root
    /// - Includes modification dates and file sizes
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
    /// - Parameter relativePath: Path relative to root directory
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
    /// - Parameter relativePath: Path relative to root directory
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

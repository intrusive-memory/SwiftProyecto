import Foundation

/// Represents the type of file source.
public enum FileSourceType: String, Codable, Sendable {
    /// A directory on the local filesystem
    case directory

    /// A git repository root directory
    case gitRepository

    /// A package bundle (e.g., .textbundle)
    case packageBundle
}

/// Represents a source of files that can be discovered and read.
///
/// FileSource provides an abstract interface for different types of file sources,
/// such as directories, git repositories, or package bundles. Each implementation
/// handles the specifics of discovering files and providing access to their contents.
///
/// ## Usage
///
/// ```swift
/// // Create a directory file source
/// let source = DirectoryFileSource(url: folderURL, name: "My Project")
///
/// // Discover files
/// let files = try await source.discoverFiles()
///
/// // Read a file
/// let data = try await source.readFile(at: "Episode 1.fountain")
/// ```
public protocol FileSource: Sendable {
    /// Unique identifier for this source instance
    var id: UUID { get }

    /// Human-readable name for display
    var name: String { get }

    /// The type of file source
    var sourceType: FileSourceType { get }

    /// Root URL for file operations
    var rootURL: URL { get }

    /// Security-scoped bookmark data for sandboxed access
    ///
    /// On macOS, this contains a security-scoped bookmark.
    /// On iOS, this contains a standard bookmark.
    var bookmarkData: Data? { get set }

    /// Discovers all files in this source.
    ///
    /// This method recursively walks the source and returns metadata about
    /// discovered files. It does not read file contents.
    ///
    /// **Implementation Notes:**
    /// - Exclude system files (.DS_Store, Thumbs.db)
    /// - Exclude version control directories (.git/, .svn/)
    /// - Exclude build artifacts (.cache/, .build/)
    /// - Return relative paths from the source root
    ///
    /// - Returns: Array of discovered files with metadata
    /// - Throws: Errors if discovery fails
    func discoverFiles() async throws -> [DiscoveredFile]

    /// Reads the contents of a file at the given relative path.
    ///
    /// - Parameter relativePath: Path relative to the source root
    /// - Returns: File data
    /// - Throws: Errors if file cannot be read
    func readFile(at relativePath: String) async throws -> Data

    /// Gets the modification date of a file.
    ///
    /// - Parameter relativePath: Path relative to the source root
    /// - Returns: Modification date, or nil if unavailable
    /// - Throws: Errors if file metadata cannot be read
    func modificationDate(for relativePath: String) throws -> Date?
}

/// Represents a file discovered in a file source.
///
/// DiscoveredFile contains metadata about a file without loading its contents.
/// It's designed to be lightweight for efficient file listing and filtering.
public struct DiscoveredFile: Identifiable, Hashable, Sendable {
    /// Unique identifier
    public let id: UUID

    /// Path relative to the source root
    public let relativePath: String

    /// Filename with extension
    public let filename: String

    /// File extension (without dot)
    public let fileExtension: String

    /// Last modification date
    public let modificationDate: Date?

    /// File size in bytes
    public let fileSize: Int64?

    /// Creates a discovered file.
    public init(
        id: UUID = UUID(),
        relativePath: String,
        filename: String,
        fileExtension: String,
        modificationDate: Date? = nil,
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.relativePath = relativePath
        self.filename = filename
        self.fileExtension = fileExtension
        self.modificationDate = modificationDate
        self.fileSize = fileSize
    }

    /// Path components of the relative path
    public var pathComponents: [String] {
        relativePath.split(separator: "/").map(String.init)
    }

    /// Directory containing this file (nil if in root)
    public var directory: String? {
        let components = pathComponents
        guard components.count > 1 else { return nil }
        return components.dropLast().joined(separator: "/")
    }

    /// Whether this file is in the root directory
    public var isInRoot: Bool {
        !relativePath.contains("/")
    }
}

/// Errors that can occur during file source operations.
public enum FileSourceError: LocalizedError {
    case notGitRepository
    case fileNotFound(String)
    case permissionDenied(String)
    case invalidPath(String)

    public var errorDescription: String? {
        switch self {
        case .notGitRepository:
            return "Directory is not a git repository (no .git folder found)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied accessing: \(path)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        }
    }
}

import Foundation

/// Defines the context in which a GuionDocument is being used.
///
/// This enum determines which SwiftData container strategy should be used:
/// - `singleFile`: App-wide container in ~/Library/Application Support
/// - `project`: Project-local container in <project>/.cache/
public enum DocumentContext: Sendable, Equatable {
    /// A single screenplay file opened directly (not part of a project folder)
    ///
    /// Uses the app-wide SwiftData container at:
    /// `~/Library/Application Support/com.intrusive-memory.Produciesta/default.store`
    case singleFile(URL)

    /// A screenplay file that is part of a project folder
    ///
    /// Uses a project-local SwiftData container at:
    /// `<projectRoot>/.cache/default.store`
    ///
    /// - Parameter projectRoot: The root folder containing PROJECT.md
    case project(projectRoot: URL)

    // MARK: - Convenience Properties

    /// The URL associated with this context
    public var url: URL {
        switch self {
        case .singleFile(let url):
            return url
        case .project(let projectRoot):
            return projectRoot
        }
    }

    /// Whether this context represents a project (vs single file)
    public var isProject: Bool {
        switch self {
        case .singleFile:
            return false
        case .project:
            return true
        }
    }

    /// The cache directory URL for this context
    ///
    /// - For single files: `~/Library/Application Support/com.intrusive-memory.Produciesta/`
    /// - For projects: `<projectRoot>/.cache/`
    public var cacheDirectoryURL: URL {
        switch self {
        case .singleFile:
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("com.intrusive-memory.Produciesta", isDirectory: true)
        case .project(let projectRoot):
            return projectRoot.appendingPathComponent(".cache", isDirectory: true)
        }
    }

    /// The SwiftData store URL for this context
    public var storeURL: URL {
        cacheDirectoryURL.appendingPathComponent("default.store")
    }
}

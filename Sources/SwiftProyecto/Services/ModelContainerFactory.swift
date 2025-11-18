import Foundation
import SwiftData
import SwiftCompartido

/// Factory for creating SwiftData ModelContainers with context-aware storage strategies.
///
/// This factory implements the dual container strategy:
/// - **Single File Context**: App-wide container in ~/Library/Application Support
/// - **Project Context**: Project-local container in <project>/.cache/
///
/// ## Usage
///
/// ```swift
/// // For a single file
/// let context = DocumentContext.singleFile(fileURL)
/// let container = try ModelContainerFactory.createContainer(for: context)
///
/// // For a project
/// let context = DocumentContext.project(projectRoot: folderURL)
/// let container = try ModelContainerFactory.createContainer(for: context)
/// ```
@MainActor
public final class ModelContainerFactory {

    /// Errors that can occur during container creation
    public enum ContainerError: LocalizedError {
        case cacheDirectoryCreationFailed(URL, Error)
        case containerCreationFailed(Error)
        case projectRootDoesNotExist(URL)

        public var errorDescription: String? {
            switch self {
            case .cacheDirectoryCreationFailed(let url, let error):
                return "Failed to create cache directory at \(url.path): \(error.localizedDescription)"
            case .containerCreationFailed(let error):
                return "Failed to create model container: \(error.localizedDescription)"
            case .projectRootDoesNotExist(let url):
                return "Project root does not exist: \(url.path)"
            }
        }
    }

    // MARK: - Container Creation

    /// Creates a SwiftData ModelContainer for the given document context.
    ///
    /// - Parameter context: The document context (single file or project)
    /// - Returns: A configured ModelContainer with the appropriate storage location
    /// - Throws: `ContainerError` if container creation fails
    public static func createContainer(for context: DocumentContext) throws -> ModelContainer {
        // Ensure cache directory exists
        try ensureCacheDirectoryExists(for: context)

        // Get the store URL
        let storeURL = context.storeURL

        // Create schema
        let schema = Schema([
            ProjectModel.self,
            ProjectFileReference.self,
            GuionDocumentModel.self,
            GuionElementModel.self,
            TypedDataStorage.self,
            TitlePageEntryModel.self,
            CustomOutlineElement.self
        ])

        // Create configuration
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL
        )

        // Create and return container
        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            throw ContainerError.containerCreationFailed(error)
        }
    }

    // MARK: - Private Helpers

    /// Ensures the cache directory exists for the given context
    private static func ensureCacheDirectoryExists(for context: DocumentContext) throws {
        let cacheURL = context.cacheDirectoryURL

        // For project context, verify project root exists
        if case .project(let projectRoot) = context {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: projectRoot.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw ContainerError.projectRootDoesNotExist(projectRoot)
            }
        }

        // Create cache directory if needed
        do {
            try FileManager.default.createDirectory(
                at: cacheURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw ContainerError.cacheDirectoryCreationFailed(cacheURL, error)
        }
    }

    // MARK: - Container Lifecycle

    /// Deletes the SwiftData store for a given context.
    ///
    /// This is useful for:
    /// - Resetting project state
    /// - Cleaning up after project deletion
    /// - Recovering from corrupted databases
    ///
    /// - Parameter context: The document context whose store should be deleted
    /// - Throws: File system errors if deletion fails
    public static func deleteStore(for context: DocumentContext) throws {
        let storeURL = context.storeURL
        let fileManager = FileManager.default

        // Delete main store file
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.removeItem(at: storeURL)
        }

        // Delete WAL files
        let walURL = storeURL.appendingPathExtension("wal")
        if fileManager.fileExists(atPath: walURL.path) {
            try fileManager.removeItem(at: walURL)
        }

        let shmURL = storeURL.appendingPathExtension("shm")
        if fileManager.fileExists(atPath: shmURL.path) {
            try fileManager.removeItem(at: shmURL)
        }
    }

    /// Checks if a SwiftData store exists for the given context
    ///
    /// - Parameter context: The document context to check
    /// - Returns: `true` if a store file exists, `false` otherwise
    public static func storeExists(for context: DocumentContext) -> Bool {
        FileManager.default.fileExists(atPath: context.storeURL.path)
    }
}

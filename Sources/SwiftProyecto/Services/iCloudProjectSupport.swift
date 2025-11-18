//
//  iCloudProjectSupport.swift
//  SwiftProyecto
//
//  Created on 2025-11-17.
//

import Foundation

#if os(iOS)
/// iOS-specific support for iCloud-based and local project management.
///
/// This class provides utilities for managing screenplay projects on iOS,
/// supporting both local (on-device) storage and iCloud Drive integration.
///
/// ## iCloud Container Structure
/// ```
/// iCloud Drive/
/// └── Produciesta/
///     └── Projects/
///         ├── MyProject/
///         │   ├── PROJECT.md
///         │   ├── episode-01.fountain
///         │   └── episode-02.fountain
///         └── AnotherProject/
/// ```
///
/// ## Local Storage Structure
/// ```
/// Documents/
/// └── Projects/
///     ├── MyProject/
///     │   ├── PROJECT.md
///     │   └── screenplay.fountain
///     └── AnotherProject/
/// ```
///
/// ## Usage
/// ```swift
/// let support = iCloudProjectSupport()
///
/// // Check iCloud availability
/// if support.isICloudAvailable {
///     // Create project in iCloud
///     let projectURL = try support.createICloudProjectFolder(named: "MyProject")
/// } else {
///     // Create project locally
///     let projectURL = try support.createLocalProjectFolder(named: "MyProject")
/// }
/// ```
@MainActor
public final class iCloudProjectSupport {

    // MARK: - Properties

    private let fileManager = FileManager.default

    // MARK: - Errors

    public enum iCloudError: LocalizedError {
        case iCloudNotAvailable
        case containerNotFound
        case projectFolderCreationFailed(Error)
        case fileCopyFailed(String, Error)
        case invalidSourceURL(URL)
        case invalidDestinationURL(URL)

        public var errorDescription: String? {
            switch self {
            case .iCloudNotAvailable:
                return "iCloud Drive is not available. Please enable iCloud in Settings."
            case .containerNotFound:
                return "iCloud container not found. Check app entitlements."
            case .projectFolderCreationFailed(let error):
                return "Failed to create project folder: \(error.localizedDescription)"
            case .fileCopyFailed(let filename, let error):
                return "Failed to copy file '\(filename)': \(error.localizedDescription)"
            case .invalidSourceURL(let url):
                return "Invalid source URL: \(url.path)"
            case .invalidDestinationURL(let url):
                return "Invalid destination URL: \(url.path)"
            }
        }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - iCloud Availability

    /// Checks if iCloud Drive is available and accessible.
    ///
    /// Returns `true` if:
    /// - User is signed into iCloud
    /// - iCloud Drive is enabled
    /// - App has iCloud entitlements configured
    ///
    /// - Returns: `true` if iCloud is available, `false` otherwise
    public var isICloudAvailable: Bool {
        return fileManager.ubiquityIdentityToken != nil
    }

    /// Gets the iCloud container URL for document storage.
    ///
    /// - Returns: The iCloud container URL, or `nil` if iCloud is not available
    public var iCloudContainerURL: URL? {
        return fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }

    // MARK: - Project Folder Access

    /// Gets or creates the Projects folder in iCloud Drive.
    ///
    /// The folder structure will be:
    /// ```
    /// iCloud Drive/Produciesta/Documents/Projects/
    /// ```
    ///
    /// - Returns: URL to the iCloud Projects folder
    /// - Throws: `iCloudError` if iCloud is unavailable or folder creation fails
    public func iCloudProjectsFolder() throws -> URL {
        guard isICloudAvailable else {
            throw iCloudError.iCloudNotAvailable
        }

        guard let containerURL = iCloudContainerURL else {
            throw iCloudError.containerNotFound
        }

        let projectsFolder = containerURL.appendingPathComponent("Projects")

        // Create folder if it doesn't exist
        if !fileManager.fileExists(atPath: projectsFolder.path) {
            do {
                try fileManager.createDirectory(
                    at: projectsFolder,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw iCloudError.projectFolderCreationFailed(error)
            }
        }

        return projectsFolder
    }

    /// Gets or creates the Projects folder in local Documents directory.
    ///
    /// The folder structure will be:
    /// ```
    /// Documents/Projects/
    /// ```
    ///
    /// - Returns: URL to the local Projects folder
    /// - Throws: `iCloudError` if folder creation fails
    public func localProjectsFolder() throws -> URL {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw iCloudError.containerNotFound
        }

        let projectsFolder = documentsURL.appendingPathComponent("Projects")

        // Create folder if it doesn't exist
        if !fileManager.fileExists(atPath: projectsFolder.path) {
            do {
                try fileManager.createDirectory(
                    at: projectsFolder,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw iCloudError.projectFolderCreationFailed(error)
            }
        }

        return projectsFolder
    }

    // MARK: - Project Creation

    /// Creates a new project folder in iCloud Drive.
    ///
    /// - Parameter name: The project folder name
    /// - Returns: URL to the created project folder
    /// - Throws: `iCloudError` if creation fails
    public func createICloudProjectFolder(named name: String) throws -> URL {
        let projectsFolder = try iCloudProjectsFolder()
        let projectFolder = projectsFolder.appendingPathComponent(name)

        guard !fileManager.fileExists(atPath: projectFolder.path) else {
            // Folder already exists, return it
            return projectFolder
        }

        do {
            try fileManager.createDirectory(
                at: projectFolder,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw iCloudError.projectFolderCreationFailed(error)
        }

        return projectFolder
    }

    /// Creates a new project folder in local Documents directory.
    ///
    /// - Parameter name: The project folder name
    /// - Returns: URL to the created project folder
    /// - Throws: `iCloudError` if creation fails
    public func createLocalProjectFolder(named name: String) throws -> URL {
        let projectsFolder = try localProjectsFolder()
        let projectFolder = projectsFolder.appendingPathComponent(name)

        guard !fileManager.fileExists(atPath: projectFolder.path) else {
            // Folder already exists, return it
            return projectFolder
        }

        do {
            try fileManager.createDirectory(
                at: projectFolder,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw iCloudError.projectFolderCreationFailed(error)
        }

        return projectFolder
    }

    // MARK: - File Operations

    /// Copies a file into a project folder (for import workflow).
    ///
    /// This is used when importing external screenplay files into a project.
    /// The file is copied (not moved) so the original remains intact.
    ///
    /// - Parameters:
    ///   - sourceURL: URL of the file to import
    ///   - projectURL: URL of the project folder
    ///   - replaceExisting: If `true`, replaces existing file with same name
    /// - Returns: URL of the copied file in the project folder
    /// - Throws: `iCloudError` if copy fails
    public func copyFileToProject(
        from sourceURL: URL,
        to projectURL: URL,
        replaceExisting: Bool = false
    ) throws -> URL {
        // Validate source exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw iCloudError.invalidSourceURL(sourceURL)
        }

        // Validate destination is a directory
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: projectURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw iCloudError.invalidDestinationURL(projectURL)
        }

        let destinationURL = projectURL.appendingPathComponent(sourceURL.lastPathComponent)

        // Handle existing file
        if fileManager.fileExists(atPath: destinationURL.path) {
            if replaceExisting {
                try fileManager.removeItem(at: destinationURL)
            } else {
                // File already exists, return existing URL
                return destinationURL
            }
        }

        // Copy file
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw iCloudError.fileCopyFailed(sourceURL.lastPathComponent, error)
        }

        return destinationURL
    }

    /// Copies a file from a project folder to an external location (for export workflow).
    ///
    /// This is used when exporting screenplay files from a project.
    /// The file is copied (not moved) so the project file remains intact.
    ///
    /// - Parameters:
    ///   - projectURL: URL of the project folder
    ///   - filename: Name of the file to export
    ///   - destinationURL: URL where the file should be copied
    ///   - replaceExisting: If `true`, replaces existing file at destination
    /// - Returns: URL of the copied file at the destination
    /// - Throws: `iCloudError` if copy fails
    public func copyFileFromProject(
        in projectURL: URL,
        filename: String,
        to destinationURL: URL,
        replaceExisting: Bool = false
    ) throws -> URL {
        let sourceURL = projectURL.appendingPathComponent(filename)

        // Validate source exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw iCloudError.invalidSourceURL(sourceURL)
        }

        // Handle existing file at destination
        if fileManager.fileExists(atPath: destinationURL.path) {
            if replaceExisting {
                try fileManager.removeItem(at: destinationURL)
            } else {
                // File already exists, return existing URL
                return destinationURL
            }
        }

        // Copy file
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw iCloudError.fileCopyFailed(filename, error)
        }

        return destinationURL
    }

    // MARK: - Project Discovery

    /// Lists all project folders in iCloud Drive.
    ///
    /// - Returns: Array of URLs to project folders
    /// - Throws: `iCloudError` if iCloud is unavailable
    public func discoverICloudProjects() throws -> [URL] {
        let projectsFolder = try iCloudProjectsFolder()
        return try discoverProjects(in: projectsFolder)
    }

    /// Lists all project folders in local Documents directory.
    ///
    /// - Returns: Array of URLs to project folders
    /// - Throws: `iCloudError` if access fails
    public func discoverLocalProjects() throws -> [URL] {
        let projectsFolder = try localProjectsFolder()
        return try discoverProjects(in: projectsFolder)
    }

    /// Lists all project folders in a given directory.
    ///
    /// A folder is considered a project if it contains a PROJECT.md file.
    ///
    /// - Parameter folder: URL of the folder to search
    /// - Returns: Array of URLs to project folders
    /// - Throws: `iCloudError` if enumeration fails
    private func discoverProjects(in folder: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: folder.path) else {
            return []
        }

        var projectURLs: [URL] = []

        let contents = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for url in contents {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            // Check if folder contains PROJECT.md
            let manifestURL = url.appendingPathComponent("PROJECT.md")
            if fileManager.fileExists(atPath: manifestURL.path) {
                projectURLs.append(url)
            }
        }

        return projectURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
#endif

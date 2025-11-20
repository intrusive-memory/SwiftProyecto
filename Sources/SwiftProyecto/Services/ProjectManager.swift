import Foundation
import SwiftData
import SwiftCompartido

/// Service for managing project lifecycle, file discovery, and synchronization.
///
/// ProjectManager handles:
/// - Creating new projects with PROJECT.md manifest
/// - Opening existing projects and loading metadata
/// - Discovering screenplay files in project folders
/// - Synchronizing file state with filesystem
/// - Loading and unloading individual files
///
/// ## Usage
///
/// ```swift
/// let manager = ProjectManager(modelContext: context)
///
/// // Create a new project
/// let project = try await manager.createProject(
///     at: projectURL,
///     title: "My Series",
///     author: "Jane Showrunner"
/// )
///
/// // Discover files in project folder
/// try await manager.discoverFiles(for: project)
///
/// // Load a specific file
/// try await manager.loadFile(fileReference, in: project)
/// ```
@MainActor
public final class ProjectManager {

    // MARK: - Properties

    private let modelContext: ModelContext
    private let fileManager: FileManager

    // MARK: - Errors

    public enum ProjectError: LocalizedError {
        case projectAlreadyExists(URL)
        case projectFolderNotFound(URL)
        case projectManifestNotFound(URL)
        case projectManifestInvalid(String)
        case fileNotFound(URL)
        case fileAlreadyLoaded(String)
        case unsupportedFileType(String)
        case bookmarkCreationFailed(Error)
        case bookmarkResolutionFailed(Error)
        case securityScopedAccessFailed(URL)
        case noBookmarkData
        case parsingFailed(String, Error)
        case saveError(Error)

        public var errorDescription: String? {
            switch self {
            case .projectAlreadyExists(let url):
                return "A project already exists at \(url.path)"
            case .projectFolderNotFound(let url):
                return "Project folder not found at \(url.path)"
            case .projectManifestNotFound(let url):
                return "PROJECT.md not found in \(url.path)"
            case .projectManifestInvalid(let reason):
                return "Invalid PROJECT.md: \(reason)"
            case .fileNotFound(let url):
                return "File not found at \(url.path)"
            case .fileAlreadyLoaded(let filename):
                return "File already loaded: \(filename)"
            case .unsupportedFileType(let ext):
                return "Unsupported file type: .\(ext)"
            case .bookmarkCreationFailed(let error):
                return "Failed to create security-scoped bookmark: \(error.localizedDescription)"
            case .bookmarkResolutionFailed(let error):
                return "Failed to resolve security-scoped bookmark: \(error.localizedDescription)"
            case .securityScopedAccessFailed(let url):
                return "Failed to start accessing security-scoped resource at \(url.path)"
            case .noBookmarkData:
                return "No security-scoped bookmark data available for project"
            case .parsingFailed(let filename, let error):
                return "Failed to parse \(filename): \(error.localizedDescription)"
            case .saveError(let error):
                return "Failed to save to SwiftData: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Initialization

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.fileManager = .default
    }

    // MARK: - Platform-Specific Bookmark Options

    /// Bookmark resolution options appropriate for the current platform.
    /// macOS uses security-scoped bookmarks, iOS uses standard bookmarks.
    private var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if os(macOS)
        return .withSecurityScope
        #else
        return []
        #endif
    }

    /// Bookmark creation options appropriate for the current platform.
    /// macOS uses security-scoped bookmarks, iOS uses standard bookmarks.
    private var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if os(macOS)
        return .withSecurityScope
        #else
        return .minimalBookmark
        #endif
    }

    // MARK: - Security-Scoped Access Helpers

    /// Performs an operation with security-scoped access to the project folder.
    ///
    /// This method:
    /// 1. Resolves the security-scoped bookmark
    /// 2. Handles stale bookmarks by recreating them
    /// 3. Starts accessing the security-scoped resource
    /// 4. Executes the operation
    /// 5. Stops accessing the resource (via defer)
    ///
    /// - Parameters:
    ///   - project: The project whose folder to access
    ///   - operation: The operation to perform with the folder URL
    /// - Returns: The result of the operation
    /// - Throws: ProjectError if bookmark resolution or access fails
    private func withSecurityScopedAccess<T>(
        to project: ProjectModel,
        operation: (URL) throws -> T
    ) throws -> T {
        guard let bookmarkData = project.folderBookmark else {
            throw ProjectError.noBookmarkData
        }

        var isStale = false
        let folderURL: URL
        do {
            folderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: bookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw ProjectError.bookmarkResolutionFailed(error)
        }

        // Handle stale bookmarks by recreating them
        if isStale {
            do {
                let newBookmark = try folderURL.bookmarkData(
                    options: bookmarkCreationOptions,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                project.folderBookmark = newBookmark
                try modelContext.save()
            } catch {
                throw ProjectError.bookmarkCreationFailed(error)
            }
        }

        // Start accessing security-scoped resource
        guard folderURL.startAccessingSecurityScopedResource() else {
            throw ProjectError.securityScopedAccessFailed(folderURL)
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        return try operation(folderURL)
    }

    /// Async version of withSecurityScopedAccess for async operations.
    private func withSecurityScopedAccess<T>(
        to project: ProjectModel,
        operation: (URL) async throws -> T
    ) async throws -> T {
        guard let bookmarkData = project.folderBookmark else {
            throw ProjectError.noBookmarkData
        }

        var isStale = false
        let folderURL: URL
        do {
            folderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: bookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw ProjectError.bookmarkResolutionFailed(error)
        }

        // Handle stale bookmarks by recreating them
        if isStale {
            do {
                let newBookmark = try folderURL.bookmarkData(
                    options: bookmarkCreationOptions,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                project.folderBookmark = newBookmark
                try modelContext.save()
            } catch {
                throw ProjectError.bookmarkCreationFailed(error)
            }
        }

        // Start accessing security-scoped resource
        guard folderURL.startAccessingSecurityScopedResource() else {
            throw ProjectError.securityScopedAccessFailed(folderURL)
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        return try await operation(folderURL)
    }

    // MARK: - Project Creation

    /// Creates a new project folder with PROJECT.md manifest.
    ///
    /// - Parameters:
    ///   - folderURL: The folder where the project should be created
    ///   - title: Project title
    ///   - author: Project author
    ///   - description: Optional project description
    ///   - season: Optional season number
    ///   - episodes: Optional episode count
    ///   - genre: Optional genre
    ///   - tags: Optional tags array
    /// - Returns: The created ProjectModel
    /// - Throws: ProjectError if creation fails
    public func createProject(
        at folderURL: URL,
        title: String,
        author: String,
        description: String? = nil,
        season: Int? = nil,
        episodes: Int? = nil,
        genre: String? = nil,
        tags: [String]? = nil
    ) throws -> ProjectModel {
        // Start accessing security-scoped resource
        // On macOS, the folderURL comes from NSOpenPanel and needs explicit access
        let didStartAccessing = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        // Check if folder already exists
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                // Folder exists - check if it already has PROJECT.md
                let manifestURL = folderURL.appendingPathComponent("PROJECT.md")
                if fileManager.fileExists(atPath: manifestURL.path) {
                    throw ProjectError.projectAlreadyExists(folderURL)
                }
            } else {
                throw ProjectError.projectAlreadyExists(folderURL)
            }
        } else {
            // Create project folder
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        // Create PROJECT.md front matter
        let frontMatter = ProjectFrontMatter(
            type: "project",
            title: title,
            author: author,
            created: Date(),
            description: description,
            season: season,
            episodes: episodes,
            genre: genre,
            tags: tags
        )

        // Generate PROJECT.md content
        let parser = ProjectMarkdownParser()
        let markdownContent = parser.generate(frontMatter: frontMatter, body: "")

        // Write PROJECT.md to disk
        let manifestURL = folderURL.appendingPathComponent("PROJECT.md")
        try markdownContent.write(to: manifestURL, atomically: true, encoding: .utf8)

        // Create security-scoped bookmark
        let bookmarkData: Data
        do {
            bookmarkData = try folderURL.bookmarkData(
                options: bookmarkCreationOptions,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw ProjectError.bookmarkCreationFailed(error)
        }

        // Create ProjectModel
        let project = ProjectModel(
            title: title,
            author: author,
            created: frontMatter.created,
            projectDescription: description,
            season: season,
            episodes: episodes,
            genre: genre,
            tags: tags,
            folderBookmark: bookmarkData,
            folderPath: folderURL.standardized.path,
            lastSyncDate: Date(),
            projectMarkdownContent: ""
        )

        // Save to SwiftData
        modelContext.insert(project)
        do {
            try modelContext.save()
        } catch {
            throw ProjectError.saveError(error)
        }

        return project
    }

    // MARK: - Project Opening

    /// Opens an existing project by reading its PROJECT.md manifest.
    ///
    /// - Parameter folderURL: The project folder containing PROJECT.md
    /// - Returns: The opened ProjectModel (or existing if already in SwiftData)
    /// - Throws: ProjectError if opening fails
    public func openProject(at folderURL: URL) throws -> ProjectModel {
        // Verify folder exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ProjectError.projectFolderNotFound(folderURL)
        }

        // Verify PROJECT.md exists
        let manifestURL = folderURL.appendingPathComponent("PROJECT.md")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ProjectError.projectManifestNotFound(folderURL)
        }

        // Check if project already exists in SwiftData
        let descriptor = FetchDescriptor<ProjectModel>()
        let existingProjects = try modelContext.fetch(descriptor)
        if let existing = existingProjects.first(where: { $0.folderPath == folderURL.path }) {
            return existing
        }

        // Parse PROJECT.md
        let parser = ProjectMarkdownParser()
        let (frontMatter, body): (ProjectFrontMatter, String)
        do {
            (frontMatter, body) = try parser.parse(fileURL: manifestURL)
        } catch {
            throw ProjectError.projectManifestInvalid(error.localizedDescription)
        }

        // Create security-scoped bookmark
        let bookmarkData: Data
        do {
            bookmarkData = try folderURL.bookmarkData(
                options: bookmarkCreationOptions,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw ProjectError.bookmarkCreationFailed(error)
        }

        // Create ProjectModel
        let project = ProjectModel(
            title: frontMatter.title,
            author: frontMatter.author,
            created: frontMatter.created,
            projectDescription: frontMatter.description,
            season: frontMatter.season,
            episodes: frontMatter.episodes,
            genre: frontMatter.genre,
            tags: frontMatter.tags,
            folderBookmark: bookmarkData,
            folderPath: folderURL.standardized.path,
            lastSyncDate: nil,
            projectMarkdownContent: body
        )

        // Save to SwiftData
        modelContext.insert(project)
        do {
            try modelContext.save()
        } catch {
            throw ProjectError.saveError(error)
        }

        return project
    }

    // MARK: - File Discovery

    /// Discovers all screenplay files in the project folder.
    ///
    /// Supported extensions: .fountain, .fdx, .highland, .md, .markdown, .textbundle, .docx, .odt, .rtf, .pdf
    ///
    /// - Parameter project: The project to discover files for
    /// - Throws: ProjectError if discovery fails
    public func discoverFiles(for project: ProjectModel) throws {
        // Use security-scoped access to enumerate folder
        try withSecurityScopedAccess(to: project) { folderURL in
            // Supported screenplay file extensions
            let supportedExtensions = [
                "fountain", "fdx", "highland",
                "md", "markdown", "textbundle",
                "docx", "odt", "rtf", "pdf"
            ]

            // Recursively find all files and calculate relative paths
            let enumerator = fileManager.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            guard let enumerator = enumerator else {
                throw ProjectError.projectFolderNotFound(folderURL)
            }

            var discoveredFiles: [(url: URL, relativePath: String)] = []
            var discoveredPaths: Set<String> = []

            // Use standardized paths for consistent comparison
            let baseComponents = folderURL.standardized.pathComponents

            for case let fileURL as URL in enumerator {
            // Skip .cache directory
            if fileURL.path.contains("/.cache") {
                continue
            }

            // Skip PROJECT.md
            if fileURL.lastPathComponent == "PROJECT.md" {
                continue
            }

            // Check if file (not directory)
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else {
                continue
            }

            // Check extension
            let ext = fileURL.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else {
                continue
            }

            // Calculate relative path using path components
            let fileComponents = fileURL.standardized.pathComponents
            guard fileComponents.count > baseComponents.count else {
                continue // File is not inside project folder
            }

            // Get components after the base path
            let relativeComponents = Array(fileComponents[baseComponents.count...])
            let relativePath = relativeComponents.joined(separator: "/")

            guard !relativePath.isEmpty else {
                continue
            }

            discoveredFiles.append((url: fileURL, relativePath: relativePath))
        }

        // Create or update file references
        for item in discoveredFiles {
            let relativePath = item.relativePath
            let fileURL = item.url

            let filename = fileURL.lastPathComponent
            let fileExtension = fileURL.pathExtension

            // Track discovered path
            discoveredPaths.insert(relativePath)

            // Get modification date
            let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            let modDate = resourceValues.contentModificationDate

            // Check if reference already exists
            if let existing = project.fileReference(atPath: relativePath) {
                // Update current modification date
                existing.lastKnownModificationDate = modDate

                // Check if file is stale (loaded but modified since load time)
                // Compare current disk mod date with the date when file was loaded
                if existing.isLoaded,
                   let loadedDate = existing.lastLoadedModificationDate,
                   let currentDate = modDate,
                   currentDate > loadedDate {
                    existing.loadingState = .stale
                }
            } else {
                // Create new reference
                let fileRef = ProjectFileReference(
                    relativePath: relativePath,
                    filename: filename,
                    fileExtension: fileExtension,
                    lastKnownModificationDate: modDate,
                    loadingState: .notLoaded
                )
                modelContext.insert(fileRef)
                project.fileReferences.append(fileRef)
            }
        }

            // Mark missing files (in SwiftData but not discovered on disk)
            for fileRef in project.fileReferences {
                if !discoveredPaths.contains(fileRef.relativePath) {
                    fileRef.loadingState = .missing
                }
            }
        } // End of withSecurityScopedAccess

        // Update last sync date
        project.lastSyncDate = Date()

        // Save changes
        do {
            try modelContext.save()
        } catch {
            throw ProjectError.saveError(error)
        }
    }

    // MARK: - File Loading

    /// Loads a screenplay file into SwiftData.
    ///
    /// - Parameters:
    ///   - fileReference: The file reference to load
    ///   - project: The project containing the file
    ///   - progress: Optional progress callback for parsing updates
    /// - Throws: ProjectError if loading fails
    public func loadFile(
        _ fileReference: ProjectFileReference,
        in project: ProjectModel,
        progress: OperationProgress? = nil
    ) async throws {
        // Verify file can be loaded
        guard fileReference.canLoad else {
            if fileReference.isLoaded {
                throw ProjectError.fileAlreadyLoaded(fileReference.filename)
            }
            throw ProjectError.unsupportedFileType(fileReference.fileExtension)
        }

        // Set loading state
        fileReference.loadingState = .loading
        try modelContext.save()

        do {
            // Use security-scoped access to read file
            try await withSecurityScopedAccess(to: project) { folderURL in
                let fileURL = folderURL.appendingPathComponent(fileReference.relativePath)

                // Verify file exists
                guard fileManager.fileExists(atPath: fileURL.path) else {
                    throw ProjectError.fileNotFound(fileURL)
                }

                // Parse file using SwiftCompartido
                let parsedCollection = try await GuionParsedElementCollection(
                    file: fileURL.path,
                    progress: progress
                )

                // Create GuionDocumentModel
                let document = GuionDocumentModel(
                    filename: fileReference.filename,
                    rawContent: nil,
                    suppressSceneNumbers: false
                )
                document.sourceFileBookmark = try fileURL.bookmarkData(
                    options: bookmarkCreationOptions,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                document.lastImportDate = Date()

                modelContext.insert(document)

                // Add parsed elements
                for (index, element) in parsedCollection.elements.enumerated() {
                    let elementModel = GuionElementModel(
                        from: element,
                        chapterIndex: 0,
                        orderIndex: index
                    )
                    document.elements.append(elementModel)
                    modelContext.insert(elementModel)
                }

                // Link to file reference
                fileReference.loadedDocument = document
                fileReference.loadingState = .loaded

                // Set both modification dates when loading
                let modDate = try fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                fileReference.lastKnownModificationDate = modDate
                fileReference.lastLoadedModificationDate = modDate

                // Save all changes
                try modelContext.save()
            } // End of withSecurityScopedAccess

        } catch let error as ProjectError {
            // Handle known ProjectErrors differently
            switch error {
            case .fileNotFound:
                // File not found - mark as missing
                fileReference.loadingState = .missing
                try modelContext.save()
                throw error
            default:
                // Other errors - mark as error
                fileReference.loadingState = .error
                fileReference.errorMessage = error.localizedDescription
                try modelContext.save()
                throw error
            }
        } catch {
            // Unknown errors - wrap in parsingFailed
            fileReference.loadingState = .error
            fileReference.errorMessage = error.localizedDescription
            try modelContext.save()
            throw ProjectError.parsingFailed(fileReference.filename, error)
        }
    }

    // MARK: - File Unloading

    /// Unloads a screenplay file from SwiftData while keeping the file reference.
    ///
    /// - Parameter fileReference: The file reference to unload
    /// - Throws: ProjectError if unloading fails
    public func unloadFile(_ fileReference: ProjectFileReference) throws {
        guard let document = fileReference.loadedDocument else {
            // Already unloaded
            return
        }

        // Delete the document (cascade deletes elements)
        modelContext.delete(document)

        // Update file reference
        fileReference.loadedDocument = nil
        fileReference.loadingState = .notLoaded

        // Save changes
        do {
            try modelContext.save()
        } catch {
            throw ProjectError.saveError(error)
        }
    }

    // MARK: - File Re-Import

    /// Re-imports a screenplay file, updating elements while preserving user data.
    ///
    /// This method re-parses the screenplay file from disk and intelligently updates
    /// the existing document. Unlike `reloadFile`, this method preserves:
    /// - Generated audio (TypedDataStorage) for unchanged elements
    /// - Custom elements (CustomOutlineElement) attached to scenes/sections
    /// - Character voice mappings
    ///
    /// ## Element Matching Strategy
    ///
    /// Elements are matched by their stable IDs. When an element with the same ID
    /// exists in both old and new parses:
    /// - The element's text content is updated
    /// - Generated audio and custom elements are preserved
    ///
    /// New elements are created fresh. Deleted elements (not in new parse) are removed.
    ///
    /// - Parameters:
    ///   - fileReference: The file reference to re-import
    ///   - project: The project containing the file
    ///   - progress: Optional progress callback for parsing updates
    /// - Throws: ProjectError if re-import fails
    public func reimportFile(
        _ fileReference: ProjectFileReference,
        in project: ProjectModel,
        progress: OperationProgress? = nil
    ) async throws {
        // If file not loaded, just load it normally
        guard let existingDocument = fileReference.loadedDocument else {
            try await loadFile(fileReference, in: project, progress: progress)
            return
        }

        // Set loading state
        fileReference.loadingState = .loading
        try modelContext.save()

        do {
            // Use security-scoped access to read file
            try await withSecurityScopedAccess(to: project) { folderURL in
                let fileURL = folderURL.appendingPathComponent(fileReference.relativePath)

                // Verify file exists
                guard fileManager.fileExists(atPath: fileURL.path) else {
                    throw ProjectError.fileNotFound(fileURL)
                }

                // Re-parse file using SwiftCompartido
                let parsedCollection = try await GuionParsedElementCollection(
                    file: fileURL.path,
                    progress: progress
                )

                // Create content hash for matching elements
                func elementHash(_ type: ElementType, _ text: String, _ sceneId: String?) -> String {
                    // Use sceneId for scene headings if available, otherwise use type+text
                    if type == .sceneHeading, let sceneId = sceneId {
                        return "scene:\(sceneId)"
                    }
                    return "\(type.description):\(text)"
                }

                // Build mapping of old elements by content hash
                var oldElementsByHash: [String: GuionElementModel] = [:]
                for element in existingDocument.elements {
                    let hash = elementHash(element.elementType, element.elementText, element.sceneId)
                    // For duplicates, prefer first occurrence
                    if oldElementsByHash[hash] == nil {
                        oldElementsByHash[hash] = element
                    }
                }

                // Track which old elements we've matched (to detect deletions)
                var matchedOldElements: Set<PersistentIdentifier> = []

                // Process new elements
                var updatedElements: [GuionElementModel] = []

                for (index, parsedElement) in parsedCollection.elements.enumerated() {
                    let hash = elementHash(parsedElement.elementType, parsedElement.elementText, parsedElement.sceneId)

                    if let existingElement = oldElementsByHash[hash] {
                        // Element matched by content - update it
                        existingElement.elementType = parsedElement.elementType
                        existingElement.elementText = parsedElement.elementText
                        existingElement.orderIndex = index
                        existingElement.sceneId = parsedElement.sceneId
                        existingElement.sceneNumber = parsedElement.sceneNumber
                        existingElement.isCentered = parsedElement.isCentered
                        existingElement.isDualDialogue = parsedElement.isDualDialogue
                        // Note: generatedContent and customElements are NOT touched
                        matchedOldElements.insert(existingElement.persistentModelID)
                        updatedElements.append(existingElement)
                    } else {
                        // New element - create it
                        let newElement = GuionElementModel(
                            from: parsedElement,
                            chapterIndex: 0,
                            orderIndex: index
                        )
                        modelContext.insert(newElement)
                        updatedElements.append(newElement)
                    }
                }

                // Remove elements that were deleted from file
                for oldElement in existingDocument.elements {
                    if !matchedOldElements.contains(oldElement.persistentModelID) {
                        // Element no longer in file - delete it (cascade deletes audio/custom elements)
                        modelContext.delete(oldElement)
                    }
                }

                // Update document's elements array
                existingDocument.elements = updatedElements

                // Update metadata
                existingDocument.lastImportDate = Date()

                // Set both modification dates to current disk value
                let modDate = try fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                fileReference.lastKnownModificationDate = modDate
                fileReference.lastLoadedModificationDate = modDate
                fileReference.loadingState = .loaded

                // Save all changes
                try modelContext.save()
            } // End of withSecurityScopedAccess

        } catch let error as ProjectError {
            // Handle known ProjectErrors
            switch error {
            case .fileNotFound:
                // File not found - mark as missing
                fileReference.loadingState = .missing
                try modelContext.save()
                throw error
            default:
                // Other errors - mark as error
                fileReference.loadingState = .error
                fileReference.errorMessage = error.localizedDescription
                try modelContext.save()
                throw error
            }
        } catch {
            // Unknown errors - wrap in parsingFailed
            fileReference.loadingState = .error
            fileReference.errorMessage = error.localizedDescription
            try modelContext.save()
            throw ProjectError.parsingFailed(fileReference.filename, error)
        }
    }

    // MARK: - Synchronization

    /// Synchronizes project file references with filesystem.
    ///
    /// This is an alias for `discoverFiles` for semantic clarity.
    ///
    /// - Parameter project: The project to synchronize
    /// - Throws: ProjectError if synchronization fails
    public func syncProject(_ project: ProjectModel) throws {
        try discoverFiles(for: project)
    }

    // MARK: - iOS-Specific Project Management

    #if os(iOS)
    /// Creates a new project in iCloud Drive (iOS only).
    ///
    /// This method creates a project folder in the app's iCloud container and
    /// initializes it with a PROJECT.md manifest. The project is automatically
    /// synced to iCloud Drive.
    ///
    /// - Parameters:
    ///   - title: Project title
    ///   - author: Project author
    ///   - description: Optional project description
    ///   - season: Optional season number
    ///   - episodes: Optional episode count
    ///   - genre: Optional genre
    ///   - tags: Optional tags
    /// - Returns: The created ProjectModel
    /// - Throws: ProjectError if creation fails
    public func createICloudProject(
        title: String,
        author: String,
        description: String? = nil,
        season: Int? = nil,
        episodes: Int? = nil,
        genre: String? = nil,
        tags: [String]? = nil
    ) async throws -> ProjectModel {
        let support = iCloudProjectSupport()

        // Create project folder in iCloud
        let projectURL = try support.createICloudProjectFolder(named: title)

        // Use the standard createProject method with the iCloud URL
        return try await createProject(
            at: projectURL,
            title: title,
            author: author,
            description: description,
            season: season,
            episodes: episodes,
            genre: genre,
            tags: tags
        )
    }

    /// Creates a new project in local Documents directory (iOS only).
    ///
    /// This method creates a project folder in the app's local Documents directory.
    /// The project is stored on-device and not synced to iCloud.
    ///
    /// - Parameters:
    ///   - title: Project title
    ///   - author: Project author
    ///   - description: Optional project description
    ///   - season: Optional season number
    ///   - episodes: Optional episode count
    ///   - genre: Optional genre
    ///   - tags: Optional tags
    /// - Returns: The created ProjectModel
    /// - Throws: ProjectError if creation fails
    public func createLocalProject(
        title: String,
        author: String,
        description: String? = nil,
        season: Int? = nil,
        episodes: Int? = nil,
        genre: String? = nil,
        tags: [String]? = nil
    ) async throws -> ProjectModel {
        let support = iCloudProjectSupport()

        // Create project folder locally
        let projectURL = try support.createLocalProjectFolder(named: title)

        // Use the standard createProject method with the local URL
        return try await createProject(
            at: projectURL,
            title: title,
            author: author,
            description: description,
            season: season,
            episodes: episodes,
            genre: genre,
            tags: tags
        )
    }

    /// Imports a screenplay file into a project by copying it (iOS only).
    ///
    /// This method copies an external screenplay file into the project folder,
    /// then loads it into SwiftData. The original file is not modified.
    ///
    /// This is the iOS workflow for importing files from the document picker.
    ///
    /// - Parameters:
    ///   - sourceURL: URL of the file to import
    ///   - project: The project to import into
    ///   - replaceExisting: If `true`, replaces existing file with same name
    /// - Returns: The created ProjectFileReference
    /// - Throws: ProjectError if import fails
    public func importFileToProject(
        from sourceURL: URL,
        into project: ProjectModel,
        replaceExisting: Bool = false
    ) async throws -> ProjectFileReference {
        let support = iCloudProjectSupport()

        // Resolve project folder URL from bookmark
        let projectURL = try resolveProjectURL(for: project)

        // Copy file into project folder
        let copiedURL = try support.copyFileToProject(
            from: sourceURL,
            to: projectURL,
            replaceExisting: replaceExisting
        )

        // Discover files to add the new file reference
        try discoverFiles(for: project)

        // Find the file reference for the copied file
        let filename = copiedURL.lastPathComponent
        guard let fileReference = project.fileReferences.first(where: { $0.filename == filename }) else {
            throw ProjectError.fileNotFound(copiedURL)
        }

        // Load the file
        try await loadFile(fileReference, in: project)

        return fileReference
    }

    /// Resolves the project folder URL from its bookmark.
    ///
    /// Helper method for iOS file operations.
    ///
    /// - Parameter project: The project model
    /// - Returns: Resolved URL to the project folder
    /// - Throws: ProjectError if resolution fails
    private func resolveProjectURL(for project: ProjectModel) throws -> URL {
        guard let bookmarkData = project.folderBookmark else {
            throw ProjectError.noBookmarkData
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: bookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // Recreate bookmark if stale
            if isStale {
                let newBookmark = try url.bookmarkData(
                    options: bookmarkCreationOptions,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                project.folderBookmark = newBookmark
                try modelContext.save()
            }

            return url
        } catch {
            throw ProjectError.bookmarkResolutionFailed(error)
        }
    }
    #endif
}

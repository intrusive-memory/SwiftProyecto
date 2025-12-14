import XCTest
import SwiftData
import Foundation
@testable import SwiftProyecto

@MainActor
final class ProjectServiceTests: XCTestCase {

    var tempDirectory: URL!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var projectService: ProjectService!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectManagerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Create in-memory model container
        let schema = Schema([
            ProjectModel.self,
            ProjectFileReference.self,
            GuionDocumentModel.self,
            GuionElementModel.self,
            TypedDataStorage.self,
            TitlePageEntryModel.self,
            CustomOutlineElement.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)

        // Create project service
        projectService = ProjectService(modelContext: modelContext)
    }

    override func tearDown() async throws {
        // Clean up temp directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        modelContainer = nil
        modelContext = nil
        projectService = nil

        try await super.tearDown()
    }

    // MARK: - Project Creation Tests

    func testCreateProject_Minimal() throws {
        let projectURL = tempDirectory.appendingPathComponent("MyProject")

        let project = try projectService.createProject(
            at: projectURL,
            title: "My Series",
            author: "Jane Showrunner"
        )

        // Verify project model
        XCTAssertEqual(project.title, "My Series")
        XCTAssertEqual(project.author, "Jane Showrunner")
        XCTAssertNotNil(project.created)
        XCTAssertNotNil(project.sourceBookmarkData)
        XCTAssertEqual(project.sourceType, .directory)
        XCTAssertEqual(project.sourceName, projectURL.lastPathComponent)
        XCTAssertEqual(project.sourceRootURL, projectURL.standardized.absoluteString)
        XCTAssertNotNil(project.lastSyncDate)

        // Verify folder was created
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)

        // Verify PROJECT.md was created
        let manifestURL = projectURL.appendingPathComponent("PROJECT.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path))

        // Verify PROJECT.md content
        let content = try String(contentsOf: manifestURL, encoding: .utf8)
        XCTAssertTrue(content.contains("title: My Series"))
        XCTAssertTrue(content.contains("author: Jane Showrunner"))
        XCTAssertTrue(content.contains("type: project"))

        // Verify saved to SwiftData
        let fetched = try modelContext.fetch(FetchDescriptor<ProjectModel>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "My Series")
    }

    func testCreateProject_Full() throws {
        let projectURL = tempDirectory.appendingPathComponent("FullProject")

        let project = try projectService.createProject(
            at: projectURL,
            title: "Complete Series",
            author: "John Producer",
            description: "A sci-fi epic",
            season: 2,
            episodes: 10,
            genre: "Science Fiction",
            tags: ["sci-fi", "drama"]
        )

        XCTAssertEqual(project.title, "Complete Series")
        XCTAssertEqual(project.author, "John Producer")
        XCTAssertEqual(project.projectDescription, "A sci-fi epic")
        XCTAssertEqual(project.season, 2)
        XCTAssertEqual(project.episodes, 10)
        XCTAssertEqual(project.genre, "Science Fiction")
        XCTAssertEqual(project.tags, ["sci-fi", "drama"])

        // Verify PROJECT.md includes all fields
        let manifestURL = projectURL.appendingPathComponent("PROJECT.md")
        let content = try String(contentsOf: manifestURL, encoding: .utf8)
        XCTAssertTrue(content.contains("season: 2"))
        XCTAssertTrue(content.contains("episodes: 10"))
        XCTAssertTrue(content.contains("genre: Science Fiction"))
    }

    func testCreateProject_AlreadyExists() throws {
        let projectURL = tempDirectory.appendingPathComponent("ExistingProject")

        // Create first time
        _ = try projectService.createProject(at: projectURL, title: "First", author: "Author")

        // Try to create again - should throw
        XCTAssertThrowsError(try projectService.createProject(at: projectURL, title: "Second", author: "Author")) { error in
            guard let projectError = error as? ProjectService.ProjectError else {
                XCTFail("Expected ProjectError, got \(error)")
                return
            }

            switch projectError {
            case .projectAlreadyExists:
                break // Expected
            default:
                XCTFail("Expected projectAlreadyExists, got \(projectError)")
            }
        }
    }

    // MARK: - Project Opening Tests

    func testOpenProject_ExistingManifest() throws {
        let projectURL = tempDirectory.appendingPathComponent("OpenProject")

        // Create project first
        let created = try projectService.createProject(
            at: projectURL,
            title: "Test Project",
            author: "Test Author",
            description: "Test description",
            season: 1
        )

        // Clear SwiftData
        modelContext.delete(created)
        try modelContext.save()

        // Verify it's gone
        let fetchedBefore = try modelContext.fetch(FetchDescriptor<ProjectModel>())
        XCTAssertEqual(fetchedBefore.count, 0)

        // Now open the project
        let opened = try projectService.openProject(at: projectURL)

        XCTAssertEqual(opened.title, "Test Project")
        XCTAssertEqual(opened.author, "Test Author")
        XCTAssertEqual(opened.projectDescription, "Test description")
        XCTAssertEqual(opened.season, 1)
        XCTAssertEqual(opened.sourceRootURL, projectURL.standardized.absoluteString)

        // Verify saved to SwiftData
        let fetchedAfter = try modelContext.fetch(FetchDescriptor<ProjectModel>())
        XCTAssertEqual(fetchedAfter.count, 1)
    }

    func testOpenProject_AlreadyInSwiftData() throws {
        let projectURL = tempDirectory.appendingPathComponent("CachedProject")

        // Create project
        let created = try projectService.createProject(
            at: projectURL,
            title: "Cached Project",
            author: "Author"
        )

        // Open again - should return existing instance
        let opened = try projectService.openProject(at: projectURL)

        XCTAssertEqual(opened.id, created.id)
        XCTAssertEqual(opened.title, "Cached Project")

        // Should still be only one in SwiftData
        let fetched = try modelContext.fetch(FetchDescriptor<ProjectModel>())
        XCTAssertEqual(fetched.count, 1)
    }

    func testOpenProject_FolderNotFound() throws {
        let nonExistentURL = tempDirectory.appendingPathComponent("DoesNotExist")

        XCTAssertThrowsError(try projectService.openProject(at: nonExistentURL)) { error in
            guard let projectError = error as? ProjectService.ProjectError else {
                XCTFail("Expected ProjectError")
                return
            }

            switch projectError {
            case .projectFolderNotFound:
                break // Expected
            default:
                XCTFail("Expected projectFolderNotFound")
            }
        }
    }

    func testOpenProject_AutoCreatesManifest() throws {
        // Changed from testOpenProject_ManifestNotFound
        // New behavior: openProject now auto-creates PROJECT.md if it doesn't exist
        let projectURL = tempDirectory.appendingPathComponent("NoManifest")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let manifestURL = projectURL.appendingPathComponent("PROJECT.md")
        XCTAssertFalse(FileManager.default.fileExists(atPath: manifestURL.path), "PROJECT.md should not exist yet")

        // Opening folder without PROJECT.md should auto-create it
        let project = try projectService.openProject(at: projectURL)

        // Verify PROJECT.md was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path), "PROJECT.md should have been created")

        // Verify project was created with folder name as title
        XCTAssertEqual(project.title, "NoManifest")
        XCTAssertEqual(project.sourceRootURL, projectURL.standardized.absoluteString)
    }

    // MARK: - File Discovery Tests

    func testDiscoverFiles_EmptyProject() throws {
        let projectURL = tempDirectory.appendingPathComponent("EmptyProject")
        let project = try projectService.createProject(at: projectURL, title: "Empty", author: "Author")

        // Discover files
        try projectService.discoverFiles(for: project)

        // Should have no file references
        XCTAssertEqual(project.fileReferences.count, 0)
        XCTAssertNotNil(project.lastSyncDate)
    }

    func testDiscoverFiles_WithScreenplays() throws {
        let projectURL = tempDirectory.appendingPathComponent("FilesProject")
        let project = try projectService.createProject(at: projectURL, title: "Files", author: "Author")

        // Create some screenplay files
        let file1URL = projectURL.appendingPathComponent("episode-01.fountain")
        try "INT. TEST - DAY\n\nAction.".write(to: file1URL, atomically: true, encoding: .utf8)

        let file2URL = projectURL.appendingPathComponent("episode-02.fountain")
        try "INT. TEST2 - DAY\n\nMore action.".write(to: file2URL, atomically: true, encoding: .utf8)

        // Create a subfolder with file
        let seasonURL = projectURL.appendingPathComponent("season-02")
        try FileManager.default.createDirectory(at: seasonURL, withIntermediateDirectories: true)
        let file3URL = seasonURL.appendingPathComponent("episode-01.fountain")
        try "INT. SEASON2 - DAY\n\nAction.".write(to: file3URL, atomically: true, encoding: .utf8)

        // Discover files
        try projectService.discoverFiles(for: project)

        // Should have 3 file references
        XCTAssertEqual(project.fileReferences.count, 3)

        // Verify file references
        let sorted = project.sortedFileReferences
        XCTAssertEqual(sorted[0].filename, "episode-01.fountain")
        XCTAssertEqual(sorted[0].relativePath, "episode-01.fountain")
        XCTAssertEqual(sorted[0].loadingState, .notLoaded)

        XCTAssertEqual(sorted[1].filename, "episode-02.fountain")
        XCTAssertEqual(sorted[1].relativePath, "episode-02.fountain")

        XCTAssertEqual(sorted[2].filename, "episode-01.fountain")
        XCTAssertEqual(sorted[2].relativePath, "season-02/episode-01.fountain")
    }

    func testDiscoverFiles_SkipsHiddenAndCache() throws {
        let projectURL = tempDirectory.appendingPathComponent("FilterProject")
        let project = try projectService.createProject(at: projectURL, title: "Filter", author: "Author")

        // Create visible file
        let visibleURL = projectURL.appendingPathComponent("visible.fountain")
        try "Content".write(to: visibleURL, atomically: true, encoding: .utf8)

        // Create .cache folder with file (should be skipped)
        let cacheURL = projectURL.appendingPathComponent(".cache")
        try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        let cacheFileURL = cacheURL.appendingPathComponent("cached.fountain")
        try "Cached content".write(to: cacheFileURL, atomically: true, encoding: .utf8)

        // Discover files
        try projectService.discoverFiles(for: project)

        // Should only have 1 file (not the cached one)
        XCTAssertEqual(project.fileReferences.count, 1)
        XCTAssertEqual(project.fileReferences.first?.filename, "visible.fountain")
    }

    func testDiscoverFiles_SupportedExtensions() throws {
        let projectURL = tempDirectory.appendingPathComponent("ExtProject")
        let project = try projectService.createProject(at: projectURL, title: "Ext", author: "Author")

        // Create files with various screenplay extensions
        let screenplayExtensions = ["fountain", "fdx", "md", "markdown", "pdf"]
        for ext in screenplayExtensions {
            let fileURL = projectURL.appendingPathComponent("file.\(ext)")
            try "Content".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // Create unsupported file
        let unsupportedURL = projectURL.appendingPathComponent("file.txt")
        try "Text content".write(to: unsupportedURL, atomically: true, encoding: .utf8)

        // Discover files with extension filter
        try projectService.discoverFiles(for: project, allowedExtensions: screenplayExtensions)

        // Should have 5 files (not the .txt)
        XCTAssertEqual(project.fileReferences.count, 5)

        let foundExtensions = Set(project.fileReferences.map { $0.fileExtension })
        XCTAssertEqual(foundExtensions, Set(screenplayExtensions))
    }

    func testDiscoverFiles_AllFiles() throws {
        let projectURL = tempDirectory.appendingPathComponent("AllFilesProject")
        let project = try projectService.createProject(at: projectURL, title: "AllFiles", author: "Author")

        // Create files with various extensions
        let allExtensions = ["fountain", "fdx", "md", "txt", "json"]
        for ext in allExtensions {
            let fileURL = projectURL.appendingPathComponent("file.\(ext)")
            try "Content".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // Discover ALL files (no filter)
        try projectService.discoverFiles(for: project, allowedExtensions: nil)

        // Should have all 5 files
        XCTAssertEqual(project.fileReferences.count, 5)

        let foundExtensions = Set(project.fileReferences.map { $0.fileExtension })
        XCTAssertEqual(foundExtensions, Set(allExtensions))
    }

    func testDiscoverFiles_MarksMissingFiles() throws {
        let projectURL = tempDirectory.appendingPathComponent("MissingProject")
        let project = try projectService.createProject(at: projectURL, title: "Missing", author: "Author")

        // Create file and discover
        let fileURL = projectURL.appendingPathComponent("temp.fountain")
        try "Content".write(to: fileURL, atomically: true, encoding: .utf8)
        try projectService.discoverFiles(for: project)

        XCTAssertEqual(project.fileReferences.count, 1)
        let fileRef = project.fileReferences.first!
        XCTAssertEqual(fileRef.loadingState, .notLoaded)

        // Delete file
        try FileManager.default.removeItem(at: fileURL)

        // Discover again
        try projectService.discoverFiles(for: project)

        // Should still have 1 reference but marked as missing
        XCTAssertEqual(project.fileReferences.count, 1)
        XCTAssertEqual(fileRef.loadingState, .missing)
    }

    // MARK: - File Loading Tests

    func testLoadFile_Success() async throws {
        let projectURL = tempDirectory.appendingPathComponent("LoadProject")
        let project = try projectService.createProject(at: projectURL, title: "Load", author: "Author")

        // Create a simple fountain file
        let fileURL = projectURL.appendingPathComponent("test.fountain")
        let fountainContent = """
        Title: Test Screenplay
        Author: Test Author

        INT. TEST LOCATION - DAY

        Action line here.

        CHARACTER
        Dialogue here.
        """
        try fountainContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // Discover files
        try projectService.discoverFiles(for: project)

        XCTAssertEqual(project.fileReferences.count, 1)
        let fileRef = project.fileReferences.first!

        // Load file
        try await projectService.loadFile(fileRef, in: project)

        // Verify loading state
        XCTAssertEqual(fileRef.loadingState, .loaded)
        XCTAssertNotNil(fileRef.loadedDocument)
        XCTAssertNil(fileRef.errorMessage)

        // Verify document was created
        let document = try XCTUnwrap(fileRef.loadedDocument)
        XCTAssertEqual(document.filename, "test.fountain")
        XCTAssertTrue(document.elements.count > 0)
    }

    func testLoadFile_FileNotFound() async throws {
        let projectURL = tempDirectory.appendingPathComponent("NotFoundProject")
        let project = try projectService.createProject(at: projectURL, title: "NotFound", author: "Author")

        // Create file reference manually (file doesn't exist)
        let fileRef = ProjectFileReference(
            relativePath: "nonexistent.fountain",
            filename: "nonexistent.fountain",
            fileExtension: "fountain"
        )
        modelContext.insert(fileRef)
        project.fileReferences.append(fileRef)
        try modelContext.save()

        // Try to load - should fail
        do {
            try await projectService.loadFile(fileRef, in: project)
            XCTFail("Expected fileNotFound error")
        } catch let error as ProjectService.ProjectError {
            switch error {
            case .fileNotFound:
                break // Expected
            default:
                XCTFail("Expected fileNotFound, got \(error)")
            }
        } catch {
            XCTFail("Expected ProjectError, got \(error)")
        }

        // Should be marked as missing
        XCTAssertEqual(fileRef.loadingState, .missing)
    }

    func testLoadFile_AlreadyLoaded() async throws {
        let projectURL = tempDirectory.appendingPathComponent("AlreadyLoadedProject")
        let project = try projectService.createProject(at: projectURL, title: "AlreadyLoaded", author: "Author")

        // Create and load file
        let fileURL = projectURL.appendingPathComponent("test.fountain")
        try "INT. TEST - DAY\n\nAction.".write(to: fileURL, atomically: true, encoding: .utf8)
        try projectService.discoverFiles(for: project)
        let fileRef = project.fileReferences.first!
        try await projectService.loadFile(fileRef, in: project)

        // Try to load again - should fail
        do {
            try await projectService.loadFile(fileRef, in: project)
            XCTFail("Expected fileAlreadyLoaded error")
        } catch let error as ProjectService.ProjectError {
            switch error {
            case .fileAlreadyLoaded:
                break // Expected
            default:
                XCTFail("Expected fileAlreadyLoaded, got \(error)")
            }
        } catch {
            XCTFail("Expected ProjectError, got \(error)")
        }
    }

    // MARK: - File Unloading Tests

    func testUnloadFile_Success() async throws {
        let projectURL = tempDirectory.appendingPathComponent("UnloadProject")
        let project = try projectService.createProject(at: projectURL, title: "Unload", author: "Author")

        // Create and load file
        let fileURL = projectURL.appendingPathComponent("test.fountain")
        try "INT. TEST - DAY\n\nAction.".write(to: fileURL, atomically: true, encoding: .utf8)
        try projectService.discoverFiles(for: project)
        let fileRef = project.fileReferences.first!
        try await projectService.loadFile(fileRef, in: project)

        XCTAssertTrue(fileRef.isLoaded)
        let documentID = fileRef.loadedDocument?.id

        // Unload file
        try projectService.unloadFile(fileRef)

        // Verify unloaded
        XCTAssertEqual(fileRef.loadingState, .notLoaded)
        XCTAssertNil(fileRef.loadedDocument)

        // Verify document was deleted
        if let documentID = documentID {
            let descriptor = FetchDescriptor<GuionDocumentModel>()
            let docs = try modelContext.fetch(descriptor)
            XCTAssertFalse(docs.contains { $0.id == documentID })
        }
    }

    func testUnloadFile_AlreadyUnloaded() throws {
        let projectURL = tempDirectory.appendingPathComponent("AlreadyUnloadedProject")
        let project = try projectService.createProject(at: projectURL, title: "AlreadyUnloaded", author: "Author")

        // Create file but don't load
        let fileURL = projectURL.appendingPathComponent("test.fountain")
        try "INT. TEST - DAY\n\nAction.".write(to: fileURL, atomically: true, encoding: .utf8)
        try projectService.discoverFiles(for: project)
        let fileRef = project.fileReferences.first!

        XCTAssertFalse(fileRef.isLoaded)

        // Unload (should not throw)
        XCTAssertNoThrow(try projectService.unloadFile(fileRef))
        XCTAssertEqual(fileRef.loadingState, .notLoaded)
    }

    // MARK: - Synchronization Tests

    func testSyncProject() throws {
        let projectURL = tempDirectory.appendingPathComponent("SyncProject")
        let project = try projectService.createProject(at: projectURL, title: "Sync", author: "Author")

        // Initial sync - no files
        try projectService.syncProject(project)
        XCTAssertEqual(project.fileReferences.count, 0)

        // Add files
        let file1URL = projectURL.appendingPathComponent("file1.fountain")
        try "Content 1".write(to: file1URL, atomically: true, encoding: .utf8)

        // Sync again
        try projectService.syncProject(project)
        XCTAssertEqual(project.fileReferences.count, 1)

        // Add more files
        let file2URL = projectURL.appendingPathComponent("file2.fountain")
        try "Content 2".write(to: file2URL, atomically: true, encoding: .utf8)

        // Sync again
        try projectService.syncProject(project)
        XCTAssertEqual(project.fileReferences.count, 2)

        // Verify lastSyncDate is updated
        XCTAssertNotNil(project.lastSyncDate)
    }

    // MARK: - Error Description Tests

    func testProjectErrorDescriptions() {
        let testURL = tempDirectory.appendingPathComponent("test.fountain")
        let testError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        let projectAlreadyExistsError = ProjectService.ProjectError.projectAlreadyExists(testURL)
        XCTAssertNotNil(projectAlreadyExistsError.errorDescription)
        XCTAssertTrue(projectAlreadyExistsError.errorDescription!.contains("already exists"))

        let projectFolderNotFoundError = ProjectService.ProjectError.projectFolderNotFound(testURL)
        XCTAssertNotNil(projectFolderNotFoundError.errorDescription)
        XCTAssertTrue(projectFolderNotFoundError.errorDescription!.contains("folder not found"))

        let projectManifestNotFoundError = ProjectService.ProjectError.projectManifestNotFound(testURL)
        XCTAssertNotNil(projectManifestNotFoundError.errorDescription)
        XCTAssertTrue(projectManifestNotFoundError.errorDescription!.contains("PROJECT.md"))

        let projectManifestInvalidError = ProjectService.ProjectError.projectManifestInvalid("Invalid YAML")
        XCTAssertNotNil(projectManifestInvalidError.errorDescription)
        XCTAssertTrue(projectManifestInvalidError.errorDescription!.contains("Invalid"))

        let fileNotFoundError = ProjectService.ProjectError.fileNotFound(testURL)
        XCTAssertNotNil(fileNotFoundError.errorDescription)
        XCTAssertTrue(fileNotFoundError.errorDescription!.contains("not found"))

        let fileAlreadyLoadedError = ProjectService.ProjectError.fileAlreadyLoaded("test.fountain")
        XCTAssertNotNil(fileAlreadyLoadedError.errorDescription)
        XCTAssertTrue(fileAlreadyLoadedError.errorDescription!.contains("already loaded"))

        let unsupportedFileTypeError = ProjectService.ProjectError.unsupportedFileType(".xyz")
        XCTAssertNotNil(unsupportedFileTypeError.errorDescription)
        XCTAssertTrue(unsupportedFileTypeError.errorDescription!.contains("Unsupported"))

        let bookmarkError = ProjectService.ProjectError.bookmarkCreationFailed(testError)
        XCTAssertNotNil(bookmarkError.errorDescription)
        XCTAssertTrue(bookmarkError.errorDescription!.contains("bookmark"))

        let bookmarkResolutionError = ProjectService.ProjectError.bookmarkResolutionFailed(testError)
        XCTAssertNotNil(bookmarkResolutionError.errorDescription)
        XCTAssertTrue(bookmarkResolutionError.errorDescription!.contains("resolve"))

        let securityScopedError = ProjectService.ProjectError.securityScopedAccessFailed(testURL)
        XCTAssertNotNil(securityScopedError.errorDescription)
        XCTAssertTrue(securityScopedError.errorDescription!.contains("security-scoped"))

        let noBookmarkDataError = ProjectService.ProjectError.noBookmarkData
        XCTAssertNotNil(noBookmarkDataError.errorDescription)
        XCTAssertTrue(noBookmarkDataError.errorDescription!.contains("bookmark data"))

        let parsingError = ProjectService.ProjectError.parsingFailed("test.fountain", testError)
        XCTAssertNotNil(parsingError.errorDescription)
        XCTAssertTrue(parsingError.errorDescription!.contains("parse"))

        let saveError = ProjectService.ProjectError.saveError(testError)
        XCTAssertNotNil(saveError.errorDescription)
        XCTAssertTrue(saveError.errorDescription!.contains("save"))
    }
}

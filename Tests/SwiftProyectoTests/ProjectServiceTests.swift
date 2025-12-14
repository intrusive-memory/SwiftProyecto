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
            ProjectFileReference.self
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

    func testDiscoverFiles_RemovesDeletedFiles() throws {
        let projectURL = tempDirectory.appendingPathComponent("DeletedProject")
        let project = try projectService.createProject(at: projectURL, title: "Deleted", author: "Author")

        // Create file and discover
        let fileURL = projectURL.appendingPathComponent("temp.fountain")
        try "Content".write(to: fileURL, atomically: true, encoding: .utf8)
        try projectService.discoverFiles(for: project)

        XCTAssertEqual(project.fileReferences.count, 1)

        // Delete file
        try FileManager.default.removeItem(at: fileURL)

        // Discover again - file should be removed from references
        try projectService.discoverFiles(for: project)

        // File reference should be removed since file no longer exists
        XCTAssertEqual(project.fileReferences.count, 0)
    }

    // MARK: - File Access Tests

    func testGetSecureURL_Success() throws {
        let projectURL = tempDirectory.appendingPathComponent("URLProject")
        let project = try projectService.createProject(at: projectURL, title: "URL", author: "Author")

        // Create a file
        let fileURL = projectURL.appendingPathComponent("test.fountain")
        let content = "INT. TEST - DAY\n\nAction line."
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // Discover files
        try projectService.discoverFiles(for: project)

        XCTAssertEqual(project.fileReferences.count, 1)
        let fileRef = project.fileReferences.first!

        // Get secure URL
        let secureURL = try projectService.getSecureURL(for: fileRef, in: project)

        // Verify URL points to the file
        XCTAssertTrue(FileManager.default.fileExists(atPath: secureURL.path))
        XCTAssertEqual(secureURL.lastPathComponent, "test.fountain")

        // Verify we can read from the URL
        let readContent = try String(contentsOf: secureURL, encoding: .utf8)
        XCTAssertEqual(readContent, content)
    }

    func testGetSecureURL_FileNotFound() throws {
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

        // Get URL - should succeed even if file doesn't exist
        // (Bookmark resolves to project directory, URL is constructed from relative path)
        let url = try projectService.getSecureURL(for: fileRef, in: project)

        // URL should point to the expected location
        XCTAssertEqual(url.lastPathComponent, "nonexistent.fountain")

        // File doesn't exist at this URL
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testGetSecureURL_NestedFile() throws {
        let projectURL = tempDirectory.appendingPathComponent("NestedProject")
        let project = try projectService.createProject(at: projectURL, title: "Nested", author: "Author")

        // Create nested directory and file
        let seasonURL = projectURL.appendingPathComponent("season-01")
        try FileManager.default.createDirectory(at: seasonURL, withIntermediateDirectories: true)
        let fileURL = seasonURL.appendingPathComponent("episode.fountain")
        try "Content".write(to: fileURL, atomically: true, encoding: .utf8)

        // Discover files
        try projectService.discoverFiles(for: project)

        let fileRef = try XCTUnwrap(project.fileReferences.first)
        XCTAssertEqual(fileRef.relativePath, "season-01/episode.fountain")

        // Get secure URL for nested file
        let secureURL = try projectService.getSecureURL(for: fileRef, in: project)
        XCTAssertTrue(FileManager.default.fileExists(atPath: secureURL.path))
        XCTAssertEqual(secureURL.lastPathComponent, "episode.fountain")
    }

    func testCreateFileBookmark_Success() throws {
        let projectURL = tempDirectory.appendingPathComponent("BookmarkProject")
        let project = try projectService.createProject(at: projectURL, title: "Bookmark", author: "Author")

        // Create a file
        let fileURL = projectURL.appendingPathComponent("test.fountain")
        try "Content".write(to: fileURL, atomically: true, encoding: .utf8)

        // Discover files
        try projectService.discoverFiles(for: project)
        let fileRef = try XCTUnwrap(project.fileReferences.first)

        // Initially no bookmark
        XCTAssertNil(fileRef.bookmarkData)

        // Create bookmark
        try projectService.createFileBookmark(for: fileRef, in: project)

        // Verify bookmark was created
        XCTAssertNotNil(fileRef.bookmarkData)
        XCTAssertTrue(fileRef.bookmarkData!.count > 0)
    }

    func testRefreshBookmark_Success() throws {
        let projectURL = tempDirectory.appendingPathComponent("RefreshProject")
        let project = try projectService.createProject(at: projectURL, title: "Refresh", author: "Author")

        // Create a file
        let fileURL = projectURL.appendingPathComponent("test.fountain")
        try "Content".write(to: fileURL, atomically: true, encoding: .utf8)

        // Discover files
        try projectService.discoverFiles(for: project)
        let fileRef = try XCTUnwrap(project.fileReferences.first)

        // Create initial bookmark
        try projectService.createFileBookmark(for: fileRef, in: project)
        XCTAssertNotNil(fileRef.bookmarkData)
        let originalBookmarkExists = fileRef.bookmarkData != nil

        // Refresh bookmark
        try projectService.refreshBookmark(for: fileRef, in: project)

        // Verify bookmark still exists after refresh
        XCTAssertNotNil(fileRef.bookmarkData)
        XCTAssertTrue(originalBookmarkExists)

        // Verify we can still resolve the bookmark
        let url = try projectService.getSecureURL(for: fileRef, in: project)
        XCTAssertEqual(url.lastPathComponent, "test.fountain")
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

        let saveError = ProjectService.ProjectError.saveError(testError)
        XCTAssertNotNil(saveError.errorDescription)
        XCTAssertTrue(saveError.errorDescription!.contains("save"))
    }
}

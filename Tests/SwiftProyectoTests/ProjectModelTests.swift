import XCTest
import SwiftData
@testable import SwiftProyecto

@MainActor
final class ProjectModelTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()

        let schema = Schema([
            ProjectModel.self,
            ProjectFileReference.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testMinimalInitialization() {
        let project = ProjectModel(
            title: "My Project",
            author: "John Doe",
            sourceType: .directory,
            sourceName: "MyProject",
            sourceRootURL: "file:///path/to/project"
        )

        XCTAssertNotNil(project.id)
        XCTAssertEqual(project.title, "My Project")
        XCTAssertEqual(project.author, "John Doe")
        XCTAssertNotNil(project.created)  // Should be set to Date()
        XCTAssertNil(project.projectDescription)
        XCTAssertNil(project.season)
        XCTAssertNil(project.episodes)
        XCTAssertNil(project.genre)
        XCTAssertNil(project.tags)
        XCTAssertEqual(project.sourceType, .directory)
        XCTAssertEqual(project.sourceName, "MyProject")
        XCTAssertEqual(project.sourceRootURL, "file:///path/to/project")
        XCTAssertNil(project.sourceBookmarkData)
        XCTAssertNil(project.lastSyncDate)
        XCTAssertNil(project.projectMarkdownContent)
        XCTAssertTrue(project.fileReferences.isEmpty)
    }

    func testFullInitialization() {
        let id = UUID()
        let created = Date()
        let bookmarkData = Data("bookmark".utf8)
        let sourceURL = "file:///Users/jane/Projects/my-series"

        let project = ProjectModel(
            id: id,
            title: "My Series",
            author: "Jane Showrunner",
            created: created,
            projectDescription: "A sci-fi series",
            season: 1,
            episodes: 12,
            genre: "Science Fiction",
            tags: ["sci-fi", "drama"],
            sourceType: .directory,
            sourceName: "my-series",
            sourceRootURL: sourceURL,
            sourceBookmarkData: bookmarkData,
            lastSyncDate: Date(),
            projectMarkdownContent: "# Notes\n\nProduction info"
        )

        XCTAssertEqual(project.id, id)
        XCTAssertEqual(project.title, "My Series")
        XCTAssertEqual(project.author, "Jane Showrunner")
        XCTAssertEqual(project.created, created)
        XCTAssertEqual(project.projectDescription, "A sci-fi series")
        XCTAssertEqual(project.season, 1)
        XCTAssertEqual(project.episodes, 12)
        XCTAssertEqual(project.genre, "Science Fiction")
        XCTAssertEqual(project.tags, ["sci-fi", "drama"])
        XCTAssertEqual(project.sourceType, .directory)
        XCTAssertEqual(project.sourceName, "my-series")
        XCTAssertEqual(project.sourceRootURL, sourceURL)
        XCTAssertEqual(project.sourceBookmarkData, bookmarkData)
        XCTAssertNotNil(project.lastSyncDate)
        XCTAssertEqual(project.projectMarkdownContent, "# Notes\n\nProduction info")
    }

    // MARK: - Convenience Property Tests

    func testFileCountProperties() {
        let project = ProjectModel(
            title: "Test",
            author: "Author",
            sourceType: .directory,
            sourceName: "Test",
            sourceRootURL: "file:///test"
        )

        // No files
        XCTAssertEqual(project.totalFileCount, 0)

        // Add files
        let file1 = ProjectFileReference(
            relativePath: "file1.fountain",
            filename: "file1.fountain",
            fileExtension: "fountain"
        )
        project.fileReferences.append(file1)

        XCTAssertEqual(project.totalFileCount, 1)

        // Add more files
        let file2 = ProjectFileReference(
            relativePath: "file2.fountain",
            filename: "file2.fountain",
            fileExtension: "fountain"
        )
        project.fileReferences.append(file2)

        XCTAssertEqual(project.totalFileCount, 2)

        // Verify file references are accessible
        XCTAssertEqual(project.fileReferences.count, 2)
        XCTAssertTrue(project.fileReferences.contains(where: { $0.filename == "file1.fountain" }))
        XCTAssertTrue(project.fileReferences.contains(where: { $0.filename == "file2.fountain" }))
    }

    func testDisplayTitle() {
        let project = ProjectModel(
            title: "My Project",
            author: "Author",
            sourceType: .directory,
            sourceName: "MyProject",
            sourceRootURL: "file:///test"
        )
        XCTAssertEqual(project.displayTitle, "My Project")

        project.season = 2
        XCTAssertEqual(project.displayTitle, "My Project - Season 2")

        project.episodes = 10
        XCTAssertEqual(project.displayTitle, "My Project - Season 2 (10 episodes)")

        let project2 = ProjectModel(
            title: "Another",
            author: "Author",
            sourceType: .directory,
            sourceName: "Another",
            sourceRootURL: "file:///another"
        )
        project2.episodes = 8
        XCTAssertEqual(project2.displayTitle, "Another (8 episodes)")
    }

    func testSortedFileReferences() {
        let project = ProjectModel(
            title: "Test",
            author: "Author",
            sourceType: .directory,
            sourceName: "Test",
            sourceRootURL: "file:///test"
        )

        let file1 = ProjectFileReference(relativePath: "z-file.fountain", filename: "z-file.fountain", fileExtension: "fountain")
        let file2 = ProjectFileReference(relativePath: "a-file.fountain", filename: "a-file.fountain", fileExtension: "fountain")
        let file3 = ProjectFileReference(relativePath: "m-file.fountain", filename: "m-file.fountain", fileExtension: "fountain")

        project.fileReferences.append(contentsOf: [file1, file2, file3])

        let sorted = project.sortedFileReferences
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].relativePath, "a-file.fountain")
        XCTAssertEqual(sorted[1].relativePath, "m-file.fountain")
        XCTAssertEqual(sorted[2].relativePath, "z-file.fountain")
    }

    // MARK: - Query Method Tests

    func testFileReferenceAtPath() {
        let project = ProjectModel(
            title: "Test",
            author: "Author",
            sourceType: .directory,
            sourceName: "Test",
            sourceRootURL: "file:///test"
        )

        let file1 = ProjectFileReference(relativePath: "file1.fountain", filename: "file1.fountain", fileExtension: "fountain")
        let file2 = ProjectFileReference(relativePath: "season-01/file2.fountain", filename: "file2.fountain", fileExtension: "fountain")

        project.fileReferences.append(contentsOf: [file1, file2])

        let found1 = project.fileReference(atPath: "file1.fountain")
        XCTAssertNotNil(found1)
        XCTAssertEqual(found1?.filename, "file1.fountain")

        let found2 = project.fileReference(atPath: "season-01/file2.fountain")
        XCTAssertNotNil(found2)
        XCTAssertEqual(found2?.filename, "file2.fountain")

        let notFound = project.fileReference(atPath: "nonexistent.fountain")
        XCTAssertNil(notFound)
    }

    func testNeedsSync() {
        let project = ProjectModel(
            title: "Test",
            author: "Author",
            sourceType: .directory,
            sourceName: "Test",
            sourceRootURL: "file:///test"
        )

        // Never synced
        XCTAssertTrue(project.needsSync)

        // Just synced
        project.lastSyncDate = Date()
        XCTAssertFalse(project.needsSync)

        // Synced more than 1 hour ago
        project.lastSyncDate = Date().addingTimeInterval(-3700)  // 1 hour + 100 seconds
        XCTAssertTrue(project.needsSync)
    }

    // MARK: - Relationship Tests

    func testFileReferenceRelationship() throws {
        let project = ProjectModel(
            title: "Test",
            author: "Author",
            sourceType: .directory,
            sourceName: "Test",
            sourceRootURL: "file:///test"
        )
        modelContext.insert(project)

        let fileRef = ProjectFileReference(
            relativePath: "test.fountain",
            filename: "test.fountain",
            fileExtension: "fountain"
        )
        modelContext.insert(fileRef)

        project.fileReferences.append(fileRef)
        try modelContext.save()

        // Verify bidirectional relationship
        XCTAssertEqual(project.fileReferences.count, 1)
        XCTAssertEqual(project.fileReferences.first?.id, fileRef.id)
        XCTAssertEqual(fileRef.project?.id, project.id)
    }

    func testCascadeDelete() throws {
        let project = ProjectModel(
            title: "Test",
            author: "Author",
            sourceType: .directory,
            sourceName: "Test",
            sourceRootURL: "file:///test"
        )
        modelContext.insert(project)

        let fileRef1 = ProjectFileReference(relativePath: "file1.fountain", filename: "file1.fountain", fileExtension: "fountain")
        let fileRef2 = ProjectFileReference(relativePath: "file2.fountain", filename: "file2.fountain", fileExtension: "fountain")

        modelContext.insert(fileRef1)
        modelContext.insert(fileRef2)

        project.fileReferences.append(contentsOf: [fileRef1, fileRef2])
        try modelContext.save()

        // Delete project should cascade to file references
        modelContext.delete(project)
        try modelContext.save()

        // File references should be deleted
        let allFileRefs = try modelContext.fetch(FetchDescriptor<ProjectFileReference>())

        XCTAssertTrue(allFileRefs.isEmpty, "File references should be cascade deleted when project is deleted")
    }

    // MARK: - SwiftData Persistence Tests

    func testPersistence() throws {
        let project = ProjectModel(
            title: "My Project",
            author: "Author",
            projectDescription: "Test project",
            season: 1,
            sourceType: .directory,
            sourceName: "MyProject",
            sourceRootURL: "file:///test/project"
        )

        modelContext.insert(project)
        try modelContext.save()

        // Fetch all
        let fetched = try modelContext.fetch(FetchDescriptor<ProjectModel>())

        XCTAssertEqual(fetched.count, 1)
        let fetchedProject = try XCTUnwrap(fetched.first)
        XCTAssertEqual(fetchedProject.title, "My Project")
        XCTAssertEqual(fetchedProject.author, "Author")
        XCTAssertEqual(fetchedProject.projectDescription, "Test project")
        XCTAssertEqual(fetchedProject.season, 1)
    }

    func testUpdate() throws {
        let project = ProjectModel(
            title: "Original",
            author: "Author",
            sourceType: .directory,
            sourceName: "Original",
            sourceRootURL: "file:///test/original"
        )

        modelContext.insert(project)
        try modelContext.save()

        let originalID = project.id

        // Update
        project.title = "Updated"
        project.season = 2
        project.episodes = 10
        try modelContext.save()

        // Fetch all
        let fetched = try modelContext.fetch(FetchDescriptor<ProjectModel>())

        let fetchedProject = try XCTUnwrap(fetched.first { $0.id == originalID })
        XCTAssertEqual(fetchedProject.title, "Updated")
        XCTAssertEqual(fetchedProject.season, 2)
        XCTAssertEqual(fetchedProject.episodes, 10)
    }

    // MARK: - FileTree Tests

    func testFileTree_EmptyProject() {
        let project = ProjectModel(
            title: "Empty",
            author: "Author",
            sourceType: .directory,
            sourceName: "Empty",
            sourceRootURL: "file:///test/empty"
        )

        let tree = project.fileTree()

        // Root node should exist with no children
        XCTAssertTrue(tree.isDirectory)
        XCTAssertEqual(tree.name, "")
        XCTAssertEqual(tree.path, "")
        XCTAssertTrue(tree.children.isEmpty)
        XCTAssertEqual(tree.fileCount, 0)
    }

    func testFileTree_SingleRootFile() {
        let project = ProjectModel(
            title: "SingleFile",
            author: "Author",
            sourceType: .directory,
            sourceName: "SingleFile",
            sourceRootURL: "file:///test/single"
        )

        let file = ProjectFileReference(
            relativePath: "script.fountain",
            filename: "script.fountain",
            fileExtension: "fountain"
        )
        project.fileReferences.append(file)

        let tree = project.fileTree()

        XCTAssertEqual(tree.children.count, 1)
        XCTAssertEqual(tree.children[0].name, "script.fountain")
        XCTAssertEqual(tree.children[0].path, "script.fountain")
        XCTAssertFalse(tree.children[0].isDirectory)
        XCTAssertEqual(tree.children[0].fileReferenceID, file.id)
        XCTAssertEqual(tree.fileCount, 1)
    }

    func testFileTree_NestedStructure() {
        let project = ProjectModel(
            title: "Nested",
            author: "Author",
            sourceType: .directory,
            sourceName: "Nested",
            sourceRootURL: "file:///test/nested"
        )

        // Create a realistic project structure
        let readme = ProjectFileReference(
            relativePath: "README.md",
            filename: "README.md",
            fileExtension: "md"
        )
        let s1e1 = ProjectFileReference(
            relativePath: "Season 1/Episode 1.fountain",
            filename: "Episode 1.fountain",
            fileExtension: "fountain"
        )
        let s1e2 = ProjectFileReference(
            relativePath: "Season 1/Episode 2.fountain",
            filename: "Episode 2.fountain",
            fileExtension: "fountain"
        )
        let s2e1 = ProjectFileReference(
            relativePath: "Season 2/Episode 1.fountain",
            filename: "Episode 1.fountain",
            fileExtension: "fountain"
        )

        project.fileReferences.append(contentsOf: [readme, s1e1, s1e2, s2e1])

        let tree = project.fileTree()

        // Root should have README.md and two season directories
        XCTAssertEqual(tree.children.count, 3)
        XCTAssertEqual(tree.fileCount, 4)
        XCTAssertEqual(tree.totalNodeCount, 7) // 1 root + 2 dirs + 4 files = 7

        // Find Season 1 directory
        let season1 = tree.children.first { $0.name == "Season 1" }
        XCTAssertNotNil(season1)
        XCTAssertTrue(season1!.isDirectory)
        XCTAssertEqual(season1!.path, "Season 1")
        XCTAssertEqual(season1!.children.count, 2)
        XCTAssertEqual(season1!.fileCount, 2)

        // Find Season 2 directory
        let season2 = tree.children.first { $0.name == "Season 2" }
        XCTAssertNotNil(season2)
        XCTAssertTrue(season2!.isDirectory)
        XCTAssertEqual(season2!.path, "Season 2")
        XCTAssertEqual(season2!.children.count, 1)
        XCTAssertEqual(season2!.fileCount, 1)

        // Verify README.md is at root
        let readmeNode = tree.children.first { $0.name == "README.md" }
        XCTAssertNotNil(readmeNode)
        XCTAssertFalse(readmeNode!.isDirectory)
        XCTAssertEqual(readmeNode!.fileReferenceID, readme.id)
    }

    func testFileTree_DeeplyNestedStructure() {
        let project = ProjectModel(
            title: "Deep",
            author: "Author",
            sourceType: .directory,
            sourceName: "Deep",
            sourceRootURL: "file:///test/deep"
        )

        let deepFile = ProjectFileReference(
            relativePath: "drafts/2024/season-01/episode-01/script.fountain",
            filename: "script.fountain",
            fileExtension: "fountain"
        )
        project.fileReferences.append(deepFile)

        let tree = project.fileTree()

        // Navigate down the tree
        XCTAssertEqual(tree.children.count, 1)

        let drafts = tree.children[0]
        XCTAssertEqual(drafts.name, "drafts")
        XCTAssertTrue(drafts.isDirectory)
        XCTAssertEqual(drafts.path, "drafts")

        let year = drafts.children[0]
        XCTAssertEqual(year.name, "2024")
        XCTAssertTrue(year.isDirectory)
        XCTAssertEqual(year.path, "drafts/2024")

        let season = year.children[0]
        XCTAssertEqual(season.name, "season-01")
        XCTAssertTrue(season.isDirectory)

        let episode = season.children[0]
        XCTAssertEqual(episode.name, "episode-01")
        XCTAssertTrue(episode.isDirectory)

        let script = episode.children[0]
        XCTAssertEqual(script.name, "script.fountain")
        XCTAssertFalse(script.isDirectory)
        XCTAssertEqual(script.fileReferenceID, deepFile.id)
    }

    func testFileTree_SortedChildren() {
        let project = ProjectModel(
            title: "Sorted",
            author: "Author",
            sourceType: .directory,
            sourceName: "Sorted",
            sourceRootURL: "file:///test/sorted"
        )

        // Add files in non-alphabetical order
        let fileZ = ProjectFileReference(relativePath: "z-file.fountain", filename: "z-file.fountain", fileExtension: "fountain")
        let fileA = ProjectFileReference(relativePath: "a-file.fountain", filename: "a-file.fountain", fileExtension: "fountain")
        let dirB = ProjectFileReference(relativePath: "b-folder/script.fountain", filename: "script.fountain", fileExtension: "fountain")

        project.fileReferences.append(contentsOf: [fileZ, fileA, dirB])

        let tree = project.fileTree()
        let sorted = tree.sortedChildren

        // Directories should come before files
        XCTAssertEqual(sorted.count, 3)
        XCTAssertTrue(sorted[0].isDirectory) // b-folder
        XCTAssertEqual(sorted[0].name, "b-folder")
        XCTAssertEqual(sorted[1].name, "a-file.fountain") // files sorted alphabetically
        XCTAssertEqual(sorted[2].name, "z-file.fountain")
    }

    func testFileTree_FindNode() {
        let project = ProjectModel(
            title: "Find",
            author: "Author",
            sourceType: .directory,
            sourceName: "Find",
            sourceRootURL: "file:///test/find"
        )

        let file = ProjectFileReference(
            relativePath: "season-01/episode-01.fountain",
            filename: "episode-01.fountain",
            fileExtension: "fountain"
        )
        project.fileReferences.append(file)

        let tree = project.fileTree()

        // Find directory
        let seasonNode = tree.findNode(atPath: "season-01")
        XCTAssertNotNil(seasonNode)
        XCTAssertTrue(seasonNode!.isDirectory)

        // Find file
        let fileNode = tree.findNode(atPath: "season-01/episode-01.fountain")
        XCTAssertNotNil(fileNode)
        XCTAssertFalse(fileNode!.isDirectory)
        XCTAssertEqual(fileNode!.fileReferenceID, file.id)

        // Non-existent path
        let notFound = tree.findNode(atPath: "does-not-exist")
        XCTAssertNil(notFound)
    }

    func testFileTree_AllFilesAndDirectories() {
        let project = ProjectModel(
            title: "AllNodes",
            author: "Author",
            sourceType: .directory,
            sourceName: "AllNodes",
            sourceRootURL: "file:///test/all"
        )

        let file1 = ProjectFileReference(relativePath: "root.fountain", filename: "root.fountain", fileExtension: "fountain")
        let file2 = ProjectFileReference(relativePath: "dir1/nested.fountain", filename: "nested.fountain", fileExtension: "fountain")
        let file3 = ProjectFileReference(relativePath: "dir1/subdir/deep.fountain", filename: "deep.fountain", fileExtension: "fountain")

        project.fileReferences.append(contentsOf: [file1, file2, file3])

        let tree = project.fileTree()

        // All files (excluding root node which is a directory)
        let allFiles = tree.allFiles
        XCTAssertEqual(allFiles.count, 3)
        XCTAssertTrue(allFiles.allSatisfy { !$0.isDirectory })

        // All directories (including root)
        let allDirs = tree.allDirectories
        XCTAssertEqual(allDirs.count, 3) // root, dir1, subdir
        XCTAssertTrue(allDirs.allSatisfy { $0.isDirectory })
    }

    // MARK: - FileSource Reconstruction Tests

    func testFileSource_DirectoryType() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("testFileSource-\(UUID().uuidString)")

        let project = ProjectModel(
            title: "Directory Project",
            author: "Author",
            sourceType: .directory,
            sourceName: "TestDir",
            sourceRootURL: tempDir.absoluteString
        )

        let source = project.fileSource()

        XCTAssertNotNil(source)
        XCTAssertTrue(source is DirectoryFileSource)
        XCTAssertEqual(source?.sourceType, .directory)
        XCTAssertEqual(source?.name, "TestDir")
        XCTAssertEqual(source?.rootURL, tempDir)
    }

    func testFileSource_DirectoryWithBookmark() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("testFileSource-\(UUID().uuidString)")
        let bookmarkData = Data("test-bookmark".utf8)

        let project = ProjectModel(
            title: "Directory Project",
            author: "Author",
            sourceType: .directory,
            sourceName: "TestDir",
            sourceRootURL: tempDir.absoluteString,
            sourceBookmarkData: bookmarkData
        )

        let source = project.fileSource() as? DirectoryFileSource

        XCTAssertNotNil(source)
        XCTAssertEqual(source?.bookmarkData, bookmarkData)
    }

    func testFileSource_GitRepositoryType() throws {
        // Create a temp directory with .git folder
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("testGitRepo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let project = ProjectModel(
            title: "Git Repo Project",
            author: "Author",
            sourceType: .gitRepository,
            sourceName: "TestRepo",
            sourceRootURL: tempDir.absoluteString
        )

        let source = project.fileSource()

        XCTAssertNotNil(source)
        XCTAssertTrue(source is GitRepositoryFileSource)
        XCTAssertEqual(source?.sourceType, .gitRepository)
        XCTAssertEqual(source?.name, "TestRepo")
        XCTAssertEqual(source?.rootURL, tempDir)
    }

    func testFileSource_GitRepositoryWithoutGitDir() {
        // Git source without .git directory returns nil
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("testNoGit-\(UUID().uuidString)")

        let project = ProjectModel(
            title: "No Git Project",
            author: "Author",
            sourceType: .gitRepository,
            sourceName: "NoGit",
            sourceRootURL: tempDir.absoluteString
        )

        // GitRepositoryFileSource throws if .git doesn't exist, so fileSource returns nil
        let source = project.fileSource()
        XCTAssertNil(source)
    }

    func testFileSource_PackageBundleType() {
        let project = ProjectModel(
            title: "Package Bundle Project",
            author: "Author",
            sourceType: .packageBundle,
            sourceName: "Bundle",
            sourceRootURL: "file:///test/bundle"
        )

        // Package bundle is not yet implemented, should return nil
        let source = project.fileSource()
        XCTAssertNil(source)
    }

    func testFileSource_EmptyURL() {
        let project = ProjectModel(
            title: "Empty URL Project",
            author: "Author",
            sourceType: .directory,
            sourceName: "Empty",
            sourceRootURL: ""
        )

        let source = project.fileSource()
        XCTAssertNil(source)
    }

    // MARK: - SortedFileReferences Edge Cases

    func testSortedFileReferences_EmptyProject() {
        let project = ProjectModel(
            title: "Empty",
            author: "Author",
            sourceType: .directory,
            sourceName: "Empty",
            sourceRootURL: "file:///test"
        )

        XCTAssertTrue(project.sortedFileReferences.isEmpty)
    }

    func testSortedFileReferences_NestedPaths() {
        let project = ProjectModel(
            title: "Nested",
            author: "Author",
            sourceType: .directory,
            sourceName: "Nested",
            sourceRootURL: "file:///test"
        )

        // Files with nested paths should sort by full relative path
        let file1 = ProjectFileReference(relativePath: "z/a.fountain", filename: "a.fountain", fileExtension: "fountain")
        let file2 = ProjectFileReference(relativePath: "a/z.fountain", filename: "z.fountain", fileExtension: "fountain")
        let file3 = ProjectFileReference(relativePath: "m.fountain", filename: "m.fountain", fileExtension: "fountain")

        project.fileReferences.append(contentsOf: [file1, file2, file3])

        let sorted = project.sortedFileReferences

        XCTAssertEqual(sorted[0].relativePath, "a/z.fountain")
        XCTAssertEqual(sorted[1].relativePath, "m.fountain")
        XCTAssertEqual(sorted[2].relativePath, "z/a.fountain")
    }
}

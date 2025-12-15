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
}

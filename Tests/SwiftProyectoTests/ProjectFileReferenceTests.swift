import XCTest
import SwiftData
@testable import SwiftProyecto

@MainActor
final class ProjectFileReferenceTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
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

    func testInitialization() {
        let fileRef = ProjectFileReference(
            relativePath: "episode-01.fountain",
            filename: "episode-01.fountain",
            fileExtension: "fountain"
        )

        XCTAssertNotNil(fileRef.id)
        XCTAssertEqual(fileRef.relativePath, "episode-01.fountain")
        XCTAssertEqual(fileRef.filename, "episode-01.fountain")
        XCTAssertEqual(fileRef.fileExtension, "fountain")
        XCTAssertNil(fileRef.lastKnownModificationDate)
        XCTAssertNil(fileRef.bookmarkData)
        XCTAssertNil(fileRef.project)
    }

    func testInitializationWithAllParameters() {
        let id = UUID()
        let modDate = Date()
        let bookmarkData = Data("bookmark".utf8)

        let fileRef = ProjectFileReference(
            id: id,
            relativePath: "season-01/episode-01.fountain",
            filename: "episode-01.fountain",
            fileExtension: "fountain",
            lastKnownModificationDate: modDate,
            bookmarkData: bookmarkData
        )

        XCTAssertEqual(fileRef.id, id)
        XCTAssertEqual(fileRef.relativePath, "season-01/episode-01.fountain")
        XCTAssertEqual(fileRef.filename, "episode-01.fountain")
        XCTAssertEqual(fileRef.fileExtension, "fountain")
        XCTAssertEqual(fileRef.lastKnownModificationDate, modDate)
        XCTAssertEqual(fileRef.bookmarkData, bookmarkData)
    }

    // MARK: - Convenience Property Tests

    func testDisplayNameWithPath() {
        // Root level file
        let rootFile = ProjectFileReference(
            relativePath: "episode-01.fountain",
            filename: "episode-01.fountain",
            fileExtension: "fountain"
        )
        XCTAssertEqual(rootFile.displayNameWithPath, "episode-01.fountain")

        // Single subfolder
        let subfolderFile = ProjectFileReference(
            relativePath: "season-01/episode-01.fountain",
            filename: "episode-01.fountain",
            fileExtension: "fountain"
        )
        XCTAssertEqual(subfolderFile.displayNameWithPath, "season-01 / episode-01.fountain")

        // Multiple subfolders
        let deepFile = ProjectFileReference(
            relativePath: "drafts/season-01/episode-01.fountain",
            filename: "episode-01.fountain",
            fileExtension: "fountain"
        )
        XCTAssertEqual(deepFile.displayNameWithPath, "drafts / season-01 / episode-01.fountain")
    }

    // MARK: - SwiftData Persistence Tests

    func testPersistence() throws {
        let bookmarkData = Data("bookmark".utf8)
        let fileRef = ProjectFileReference(
            relativePath: "test.fountain",
            filename: "test.fountain",
            fileExtension: "fountain",
            lastKnownModificationDate: Date(),
            bookmarkData: bookmarkData
        )

        // Insert
        modelContext.insert(fileRef)
        try modelContext.save()

        // Fetch all and verify
        let fetched = try modelContext.fetch(FetchDescriptor<ProjectFileReference>())

        XCTAssertEqual(fetched.count, 1)
        let fetchedRef = try XCTUnwrap(fetched.first)
        XCTAssertEqual(fetchedRef.relativePath, "test.fountain")
        XCTAssertEqual(fetchedRef.bookmarkData, bookmarkData)
    }

    func testUpdate() throws {
        let fileRef = ProjectFileReference(
            relativePath: "test.fountain",
            filename: "test.fountain",
            fileExtension: "fountain"
        )

        modelContext.insert(fileRef)
        try modelContext.save()

        let originalID = fileRef.id

        // Update with bookmark data
        let bookmarkData = Data("bookmark".utf8)
        fileRef.bookmarkData = bookmarkData
        fileRef.lastKnownModificationDate = Date()
        try modelContext.save()

        // Fetch all
        let fetched = try modelContext.fetch(FetchDescriptor<ProjectFileReference>())

        let fetchedRef = try XCTUnwrap(fetched.first { $0.id == originalID })
        XCTAssertEqual(fetchedRef.bookmarkData, bookmarkData)
        XCTAssertNotNil(fetchedRef.lastKnownModificationDate)
    }

    func testDelete() throws {
        let fileRef = ProjectFileReference(
            relativePath: "test.fountain",
            filename: "test.fountain",
            fileExtension: "fountain"
        )

        modelContext.insert(fileRef)
        try modelContext.save()

        // Delete
        modelContext.delete(fileRef)
        try modelContext.save()

        // Fetch should return empty
        let fetched = try modelContext.fetch(FetchDescriptor<ProjectFileReference>())

        XCTAssertTrue(fetched.isEmpty)
    }

}

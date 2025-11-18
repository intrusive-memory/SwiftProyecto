import XCTest
import SwiftData
import SwiftCompartido
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
            ProjectFileReference.self,
            GuionDocumentModel.self
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
        XCTAssertEqual(fileRef.loadingState, .notLoaded)
        XCTAssertNil(fileRef.errorMessage)
        XCTAssertNil(fileRef.loadedDocument)
        XCTAssertNil(fileRef.project)
    }

    func testInitializationWithAllParameters() {
        let id = UUID()
        let modDate = Date()

        let fileRef = ProjectFileReference(
            id: id,
            relativePath: "season-01/episode-01.fountain",
            filename: "episode-01.fountain",
            fileExtension: "fountain",
            lastKnownModificationDate: modDate,
            loadingState: .loaded,
            errorMessage: nil
        )

        XCTAssertEqual(fileRef.id, id)
        XCTAssertEqual(fileRef.relativePath, "season-01/episode-01.fountain")
        XCTAssertEqual(fileRef.filename, "episode-01.fountain")
        XCTAssertEqual(fileRef.fileExtension, "fountain")
        XCTAssertEqual(fileRef.lastKnownModificationDate, modDate)
        XCTAssertEqual(fileRef.loadingState, .loaded)
        XCTAssertNil(fileRef.errorMessage)
    }

    // MARK: - Convenience Property Tests

    func testIsLoaded() {
        let fileRef = ProjectFileReference(
            relativePath: "test.fountain",
            filename: "test.fountain",
            fileExtension: "fountain"
        )

        // Not loaded initially
        XCTAssertFalse(fileRef.isLoaded)

        // Set to loaded state but no document
        fileRef.loadingState = .loaded
        XCTAssertFalse(fileRef.isLoaded)

        // Add document
        let mockDoc = GuionDocumentModel(filename: "test.fountain", rawContent: nil, suppressSceneNumbers: false)
        modelContext.insert(mockDoc)
        fileRef.loadedDocument = mockDoc
        XCTAssertTrue(fileRef.isLoaded)

        // Change state to stale
        fileRef.loadingState = .stale
        XCTAssertFalse(fileRef.isLoaded)
    }

    func testCanOpen() {
        let fileRef = ProjectFileReference(
            relativePath: "test.fountain",
            filename: "test.fountain",
            fileExtension: "fountain"
        )

        // Cannot open when not loaded
        XCTAssertFalse(fileRef.canOpen)

        // Can open when loaded with document
        fileRef.loadingState = .loaded
        let mockDoc = GuionDocumentModel(filename: "test.fountain", rawContent: nil, suppressSceneNumbers: false)
        modelContext.insert(mockDoc)
        fileRef.loadedDocument = mockDoc
        XCTAssertTrue(fileRef.canOpen)

        // Can open when stale with document
        fileRef.loadingState = .stale
        XCTAssertTrue(fileRef.canOpen)

        // Cannot open with no document
        fileRef.loadedDocument = nil
        XCTAssertFalse(fileRef.canOpen)
    }

    func testCanLoad() {
        let fileRef = ProjectFileReference(
            relativePath: "test.fountain",
            filename: "test.fountain",
            fileExtension: "fountain"
        )

        // Can load when not loaded
        XCTAssertTrue(fileRef.canLoad)

        // Cannot load when loading
        fileRef.loadingState = .loading
        XCTAssertFalse(fileRef.canLoad)

        // Cannot load when loaded
        fileRef.loadingState = .loaded
        XCTAssertFalse(fileRef.canLoad)

        // Can load when stale
        fileRef.loadingState = .stale
        XCTAssertTrue(fileRef.canLoad)

        // Can load when error
        fileRef.loadingState = .error
        XCTAssertTrue(fileRef.canLoad)

        // Cannot load when missing
        fileRef.loadingState = .missing
        XCTAssertFalse(fileRef.canLoad)
    }

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
        let fileRef = ProjectFileReference(
            relativePath: "test.fountain",
            filename: "test.fountain",
            fileExtension: "fountain",
            lastKnownModificationDate: Date(),
            loadingState: .loaded
        )

        // Insert
        modelContext.insert(fileRef)
        try modelContext.save()

        // Fetch all and verify
        let fetched = try modelContext.fetch(FetchDescriptor<ProjectFileReference>())

        XCTAssertEqual(fetched.count, 1)
        let fetchedRef = try XCTUnwrap(fetched.first)
        XCTAssertEqual(fetchedRef.relativePath, "test.fountain")
        XCTAssertEqual(fetchedRef.loadingState, .loaded)
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

        // Update
        fileRef.loadingState = .loaded
        let mockDoc = GuionDocumentModel(filename: "test.fountain", rawContent: nil, suppressSceneNumbers: false)
        modelContext.insert(mockDoc)
        fileRef.loadedDocument = mockDoc
        try modelContext.save()

        // Fetch all
        let fetched = try modelContext.fetch(FetchDescriptor<ProjectFileReference>())

        let fetchedRef = try XCTUnwrap(fetched.first { $0.id == originalID })
        XCTAssertEqual(fetchedRef.loadingState, .loaded)
        XCTAssertNotNil(fetchedRef.loadedDocument)
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

    // MARK: - State Transition Tests

    func testStateTransitions() {
        let fileRef = ProjectFileReference(
            relativePath: "test.fountain",
            filename: "test.fountain",
            fileExtension: "fountain"
        )

        // notLoaded → loading
        XCTAssertEqual(fileRef.loadingState, .notLoaded)
        fileRef.loadingState = .loading
        XCTAssertEqual(fileRef.loadingState, .loading)

        // loading → loaded
        fileRef.loadingState = .loaded
        let mockDoc = GuionDocumentModel(filename: "test.fountain", rawContent: nil, suppressSceneNumbers: false)
        modelContext.insert(mockDoc)
        fileRef.loadedDocument = mockDoc
        XCTAssertEqual(fileRef.loadingState, .loaded)
        XCTAssertTrue(fileRef.isLoaded)

        // loaded → stale
        fileRef.loadingState = .stale
        XCTAssertEqual(fileRef.loadingState, .stale)
        XCTAssertFalse(fileRef.isLoaded)

        // stale → loading → loaded
        fileRef.loadingState = .loading
        fileRef.loadingState = .loaded
        XCTAssertTrue(fileRef.isLoaded)

        // loaded → missing
        fileRef.loadingState = .missing
        XCTAssertEqual(fileRef.loadingState, .missing)
        XCTAssertFalse(fileRef.canLoad)

        // Error state
        fileRef.loadingState = .error
        fileRef.errorMessage = "Parse failed"
        XCTAssertEqual(fileRef.loadingState, .error)
        XCTAssertEqual(fileRef.errorMessage, "Parse failed")
        XCTAssertTrue(fileRef.canLoad)  // Can retry after error
    }
}

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

    // MARK: - displayNameWithPath Edge Cases

    func testDisplayNameWithPath_VeryDeepNesting() {
        let fileRef = ProjectFileReference(
            relativePath: "a/b/c/d/e/f/deep.fountain",
            filename: "deep.fountain",
            fileExtension: "fountain"
        )

        XCTAssertEqual(fileRef.displayNameWithPath, "a / b / c / d / e / f / deep.fountain")
    }

    func testDisplayNameWithPath_SpecialCharactersInPath() {
        let fileRef = ProjectFileReference(
            relativePath: "Season 1 (2024)/Episode 1 - Pilot.fountain",
            filename: "Episode 1 - Pilot.fountain",
            fileExtension: "fountain"
        )

        XCTAssertEqual(fileRef.displayNameWithPath, "Season 1 (2024) / Episode 1 - Pilot.fountain")
    }

    func testDisplayNameWithPath_UnicodeCharacters() {
        let fileRef = ProjectFileReference(
            relativePath: "épisodes/日本語.fountain",
            filename: "日本語.fountain",
            fileExtension: "fountain"
        )

        XCTAssertEqual(fileRef.displayNameWithPath, "épisodes / 日本語.fountain")
    }

    // MARK: - Integration with FileNode

    func testFileReferenceInFileTree() throws {
        // Create a project with file references
        let project = ProjectModel(
            title: "Tree Test",
            author: "Author",
            sourceType: .directory,
            sourceName: "Tree",
            sourceRootURL: "file:///test"
        )
        modelContext.insert(project)

        let file1 = ProjectFileReference(
            relativePath: "script.fountain",
            filename: "script.fountain",
            fileExtension: "fountain"
        )
        let file2 = ProjectFileReference(
            relativePath: "season-01/episode-01.fountain",
            filename: "episode-01.fountain",
            fileExtension: "fountain"
        )

        modelContext.insert(file1)
        modelContext.insert(file2)
        project.fileReferences.append(contentsOf: [file1, file2])
        try modelContext.save()

        // Build tree and verify file reference lookup
        let tree = project.fileTree()

        // Find file node and verify it links back to file reference
        let scriptNode = tree.children.first { $0.name == "script.fountain" }
        XCTAssertNotNil(scriptNode)
        XCTAssertEqual(scriptNode?.fileReferenceID, file1.id)

        // Verify fileReference(in:) works
        let foundRef = scriptNode?.fileReference(in: project)
        XCTAssertNotNil(foundRef)
        XCTAssertEqual(foundRef?.id, file1.id)
        XCTAssertEqual(foundRef?.relativePath, "script.fountain")
    }

    func testFileReferenceInNestedTree() throws {
        let project = ProjectModel(
            title: "Nested Tree",
            author: "Author",
            sourceType: .directory,
            sourceName: "Nested",
            sourceRootURL: "file:///test"
        )
        modelContext.insert(project)

        let nestedFile = ProjectFileReference(
            relativePath: "drafts/v2/final.fountain",
            filename: "final.fountain",
            fileExtension: "fountain"
        )
        modelContext.insert(nestedFile)
        project.fileReferences.append(nestedFile)
        try modelContext.save()

        let tree = project.fileTree()

        // Navigate to the file
        let draftsNode = tree.children.first { $0.name == "drafts" }
        XCTAssertNotNil(draftsNode)
        XCTAssertTrue(draftsNode!.isDirectory)
        XCTAssertNil(draftsNode!.fileReferenceID) // Directories have no file reference

        let v2Node = draftsNode?.children.first { $0.name == "v2" }
        XCTAssertNotNil(v2Node)

        let finalNode = v2Node?.children.first { $0.name == "final.fountain" }
        XCTAssertNotNil(finalNode)
        XCTAssertEqual(finalNode?.fileReferenceID, nestedFile.id)

        // Verify lookup
        let foundRef = finalNode?.fileReference(in: project)
        XCTAssertEqual(foundRef?.relativePath, "drafts/v2/final.fountain")
    }

    // MARK: - File Extension Tests

    func testVariousFileExtensions() {
        let extensions = [
            ("fountain", "screenplay.fountain"),
            ("fdx", "script.fdx"),
            ("md", "notes.md"),
            ("markdown", "readme.markdown"),
            ("pdf", "export.pdf"),
            ("txt", "notes.txt"),
            ("json", "config.json"),
            ("xml", "data.xml")
        ]

        for (ext, filename) in extensions {
            let fileRef = ProjectFileReference(
                relativePath: filename,
                filename: filename,
                fileExtension: ext
            )

            XCTAssertEqual(fileRef.fileExtension, ext)
            XCTAssertEqual(fileRef.filename, filename)
        }
    }

    func testFileExtensionWithMultipleDots() {
        let fileRef = ProjectFileReference(
            relativePath: "backup.2024.01.15.fountain",
            filename: "backup.2024.01.15.fountain",
            fileExtension: "fountain"
        )

        XCTAssertEqual(fileRef.fileExtension, "fountain")
        XCTAssertEqual(fileRef.displayNameWithPath, "backup.2024.01.15.fountain")
    }

    // MARK: - Relationship Tests

    func testProjectRelationship() throws {
        let project = ProjectModel(
            title: "Relationship Test",
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

        // Before adding to project
        XCTAssertNil(fileRef.project)

        // Add to project
        project.fileReferences.append(fileRef)
        try modelContext.save()

        // After adding - inverse relationship should be set
        XCTAssertNotNil(fileRef.project)
        XCTAssertEqual(fileRef.project?.id, project.id)
    }

    func testMultipleFilesInProject() throws {
        let project = ProjectModel(
            title: "Multi-File Test",
            author: "Author",
            sourceType: .directory,
            sourceName: "Test",
            sourceRootURL: "file:///test"
        )
        modelContext.insert(project)

        let files = (1...5).map { i in
            ProjectFileReference(
                relativePath: "file\(i).fountain",
                filename: "file\(i).fountain",
                fileExtension: "fountain"
            )
        }

        for file in files {
            modelContext.insert(file)
            project.fileReferences.append(file)
        }
        try modelContext.save()

        XCTAssertEqual(project.fileReferences.count, 5)

        // All files should reference the same project
        for file in files {
            XCTAssertEqual(file.project?.id, project.id)
        }
    }
}

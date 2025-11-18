//
//  SingleFileManagerTests.swift
//  SwiftProyectoTests
//
//  Created on 2025-11-17.
//

import XCTest
import SwiftData
import Foundation
@testable import SwiftProyecto
@testable import SwiftCompartido

@MainActor
final class SingleFileManagerTests: XCTestCase {

    var tempDirectory: URL!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var manager: SingleFileManager!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SingleFileManagerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Create in-memory model container for testing
        let schema = Schema([
            ProjectModel.self,
            ProjectFileReference.self,
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
            TypedDataStorage.self,
            CustomOutlineElement.self
        ])
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)

        // Create manager
        manager = SingleFileManager(modelContext: modelContext)
    }

    override func tearDown() async throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTestFountainFile(named filename: String, content: String) throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent(filename)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    // MARK: - Import Tests

    func testImportFile_Success() async throws {
        // Create a test fountain file
        let fountainContent = """
        Title: Test Screenplay
        Author: Test Author

        = ACT ONE

        INT. TEST LOCATION - DAY

        ALICE
        Hello, world!
        """

        let fileURL = try createTestFountainFile(named: "test.fountain", content: fountainContent)

        // Import the file
        let document = try await manager.importFile(from: fileURL)

        // Verify document was created
        XCTAssertNotNil(document)
        XCTAssertEqual(document.filename, "test.fountain")
        XCTAssertNotNil(document.sourceFileBookmark)
        XCTAssertNotNil(document.lastImportDate)

        // Verify elements were created
        XCTAssertFalse(document.elements.isEmpty)

        // Verify title page was imported
        XCTAssertFalse(document.titlePage.isEmpty)
        let titleEntry = document.titlePage.first { $0.key == "TITLE" }
        XCTAssertEqual(titleEntry?.values.first, "Test Screenplay")

        // Verify document was saved to SwiftData
        let descriptor = FetchDescriptor<GuionDocumentModel>()
        let documents = try modelContext.fetch(descriptor)
        XCTAssertEqual(documents.count, 1)
        XCTAssertEqual(documents.first?.filename, "test.fountain")
    }

    func testImportFile_FileNotFound() async throws {
        let nonExistentURL = tempDirectory.appendingPathComponent("nonexistent.fountain")

        do {
            _ = try await manager.importFile(from: nonExistentURL)
            XCTFail("Expected fileNotFound error")
        } catch let error as SingleFileManager.SingleFileError {
            switch error {
            case .fileNotFound(let url):
                XCTAssertEqual(url, nonExistentURL)
            default:
                XCTFail("Expected fileNotFound error, got \(error)")
            }
        }
    }

    func testImportFile_MultipleFiles() async throws {
        // Create two different files
        let content1 = """
        Title: First Screenplay

        INT. LOCATION - DAY

        ALICE
        First dialogue.
        """

        let content2 = """
        Title: Second Screenplay

        INT. OTHER LOCATION - NIGHT

        BOB
        Second dialogue.
        """

        let file1 = try createTestFountainFile(named: "first.fountain", content: content1)
        let file2 = try createTestFountainFile(named: "second.fountain", content: content2)

        // Import both files
        let doc1 = try await manager.importFile(from: file1)
        let doc2 = try await manager.importFile(from: file2)

        // Verify both were imported
        XCTAssertEqual(doc1.filename, "first.fountain")
        XCTAssertEqual(doc2.filename, "second.fountain")

        // Verify both are in SwiftData
        let descriptor = FetchDescriptor<GuionDocumentModel>()
        let documents = try modelContext.fetch(descriptor)
        XCTAssertEqual(documents.count, 2)
    }

    // MARK: - Reload Tests

    func testReloadFile_Success() async throws {
        // Create and import initial file
        let initialContent = """
        Title: Initial Version

        INT. LOCATION - DAY

        ALICE
        Initial dialogue.
        """

        let fileURL = try createTestFountainFile(named: "test.fountain", content: initialContent)
        let document = try await manager.importFile(from: fileURL)

        // Verify initial state
        let initialElementCount = document.elements.count
        XCTAssertTrue(initialElementCount > 0)

        // Wait a moment to ensure modification date is different
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Modify the file
        let updatedContent = """
        Title: Updated Version

        INT. LOCATION - DAY

        ALICE
        Updated dialogue.

        BOB
        New character!
        """
        try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // Reload the file
        try await manager.reloadFile(document)

        // Verify document was updated
        XCTAssertNotNil(document.lastImportDate)

        // Verify elements were replaced
        let newElementCount = document.elements.count
        XCTAssertNotEqual(initialElementCount, newElementCount)

        // Verify title page was updated
        let titleEntry = document.titlePage.first { $0.key == "TITLE" }
        XCTAssertEqual(titleEntry?.values.first, "Updated Version")
    }

    func testReloadFile_FileNotFound() async throws {
        // Create and import file
        let content = "Title: Test\n\nINT. LOCATION - DAY"
        let fileURL = try createTestFountainFile(named: "test.fountain", content: content)
        let document = try await manager.importFile(from: fileURL)

        // Delete the source file
        try FileManager.default.removeItem(at: fileURL)

        // Try to reload
        do {
            try await manager.reloadFile(document)
            XCTFail("Expected error when file not found")
        } catch let error as SingleFileManager.SingleFileError {
            switch error {
            case .fileNotFound, .bookmarkResolutionFailed:
                break  // Expected - either is valid
            default:
                XCTFail("Expected fileNotFound or bookmarkResolutionFailed, got \(error)")
            }
        }
    }

    func testReloadFile_NoBookmark() async throws {
        // Create a document without a bookmark
        let document = GuionDocumentModel(
            filename: "test.fountain",
            rawContent: nil,
            suppressSceneNumbers: false
        )
        modelContext.insert(document)
        try modelContext.save()

        // Try to reload
        do {
            try await manager.reloadFile(document)
            XCTFail("Expected noBookmarkData error")
        } catch let error as SingleFileManager.SingleFileError {
            switch error {
            case .noBookmarkData:
                break  // Expected
            default:
                XCTFail("Expected noBookmarkData error, got \(error)")
            }
        }
    }

    // MARK: - Needs Reload Tests

    func testNeedsReload_NewDocument() throws {
        // Create document without lastImportDate
        let document = GuionDocumentModel(
            filename: "test.fountain",
            rawContent: nil,
            suppressSceneNumbers: false
        )
        modelContext.insert(document)

        // Should need reload if lastImportDate is nil
        XCTAssertTrue(try manager.needsReload(document))
    }

    func testNeedsReload_FileNotModified() async throws {
        // Create and import file
        let content = "Title: Test\n\nINT. LOCATION - DAY"
        let fileURL = try createTestFountainFile(named: "test.fountain", content: content)
        let document = try await manager.importFile(from: fileURL)

        // File hasn't been modified, should not need reload
        XCTAssertFalse(try manager.needsReload(document))
    }

    func testNeedsReload_FileModified() async throws {
        // Create and import file
        let content = "Title: Test\n\nINT. LOCATION - DAY"
        let fileURL = try createTestFountainFile(named: "test.fountain", content: content)
        let document = try await manager.importFile(from: fileURL)

        // Wait to ensure modification date is different
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Modify the file
        let updatedContent = "Title: Updated\n\nINT. NEW LOCATION - NIGHT"
        try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // Should need reload now
        XCTAssertTrue(try manager.needsReload(document))
    }

    func testNeedsReload_FileNotFound() async throws {
        // Create and import file
        let content = "Title: Test\n\nINT. LOCATION - DAY"
        let fileURL = try createTestFountainFile(named: "test.fountain", content: content)
        let document = try await manager.importFile(from: fileURL)

        // Delete the file
        try FileManager.default.removeItem(at: fileURL)

        // Should throw error when file is deleted
        XCTAssertThrowsError(try manager.needsReload(document)) { error in
            guard let singleFileError = error as? SingleFileManager.SingleFileError else {
                XCTFail("Expected SingleFileError")
                return
            }
            switch singleFileError {
            case .fileNotFound, .bookmarkResolutionFailed:
                break  // Expected - either is valid
            default:
                XCTFail("Expected fileNotFound or bookmarkResolutionFailed, got \(singleFileError)")
            }
        }
    }

    // MARK: - Bookmark Resolution Tests

    func testResolveBookmark_Success() async throws {
        // Create and import file
        let content = "Title: Test\n\nINT. LOCATION - DAY"
        let fileURL = try createTestFountainFile(named: "test.fountain", content: content)
        let document = try await manager.importFile(from: fileURL)

        // Resolve bookmark
        let resolvedURL = try manager.resolveBookmark(for: document)

        // Should resolve to the original file
        XCTAssertEqual(resolvedURL.lastPathComponent, fileURL.lastPathComponent)

        // Compare paths after resolving symlinks (macOS has /var -> /private/var symlink)
        let resolvedPath = resolvedURL.resolvingSymlinksInPath().standardized.path
        let originalPath = fileURL.resolvingSymlinksInPath().standardized.path
        XCTAssertEqual(resolvedPath, originalPath)
    }

    func testResolveBookmark_NoBookmarkData() throws {
        // Create document without bookmark
        let document = GuionDocumentModel(
            filename: "test.fountain",
            rawContent: nil,
            suppressSceneNumbers: false
        )
        modelContext.insert(document)

        // Should throw noBookmarkData error
        XCTAssertThrowsError(try manager.resolveBookmark(for: document)) { error in
            guard let singleFileError = error as? SingleFileManager.SingleFileError else {
                XCTFail("Expected SingleFileError")
                return
            }
            switch singleFileError {
            case .noBookmarkData:
                break  // Expected
            default:
                XCTFail("Expected noBookmarkData error, got \(singleFileError)")
            }
        }
    }

    // MARK: - Delete Tests

    func testDeleteDocument_Success() async throws {
        // Create and import file
        let content = "Title: Test\n\nINT. LOCATION - DAY"
        let fileURL = try createTestFountainFile(named: "test.fountain", content: content)
        let document = try await manager.importFile(from: fileURL)

        // Verify document exists
        var descriptor = FetchDescriptor<GuionDocumentModel>()
        var documents = try modelContext.fetch(descriptor)
        XCTAssertEqual(documents.count, 1)

        // Delete document
        try manager.deleteDocument(document)

        // Verify document was deleted from SwiftData
        descriptor = FetchDescriptor<GuionDocumentModel>()
        documents = try modelContext.fetch(descriptor)
        XCTAssertEqual(documents.count, 0)

        // Verify source file still exists on disk
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testDeleteDocument_ElementsCascade() async throws {
        // Create and import file
        let content = """
        Title: Test

        INT. LOCATION - DAY

        ALICE
        Hello!
        """
        let fileURL = try createTestFountainFile(named: "test.fountain", content: content)
        let document = try await manager.importFile(from: fileURL)

        // Verify elements exist
        XCTAssertFalse(document.elements.isEmpty)

        // Delete document
        try manager.deleteDocument(document)

        // Verify elements were also deleted (cascade)
        let elementDescriptor = FetchDescriptor<GuionElementModel>()
        let remainingElements = try modelContext.fetch(elementDescriptor)
        XCTAssertEqual(remainingElements.count, 0)
    }

    // MARK: - Integration Tests

    func testFullLifecycle() async throws {
        // 1. Import file
        let initialContent = """
        Title: Lifecycle Test

        INT. LOCATION - DAY

        ALICE
        Initial version.
        """
        let fileURL = try createTestFountainFile(named: "lifecycle.fountain", content: initialContent)
        let document = try await manager.importFile(from: fileURL)

        // Verify import
        XCTAssertEqual(document.filename, "lifecycle.fountain")
        XCTAssertFalse(document.elements.isEmpty)

        // 2. Check if reload needed (should be false)
        XCTAssertFalse(try manager.needsReload(document))

        // 3. Modify file
        try await Task.sleep(nanoseconds: 100_000_000)
        let updatedContent = """
        Title: Lifecycle Test - Updated

        INT. LOCATION - DAY

        ALICE
        Updated version.

        BOB
        New dialogue!
        """
        try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // 4. Check if reload needed (should be true)
        XCTAssertTrue(try manager.needsReload(document))

        // 5. Reload file
        try await manager.reloadFile(document)

        // Verify reload
        let titleEntry = document.titlePage.first { $0.key == "TITLE" }
        XCTAssertEqual(titleEntry?.values.first, "Lifecycle Test - Updated")

        // 6. Check if reload needed (should be false again)
        XCTAssertFalse(try manager.needsReload(document))

        // 7. Delete document
        try manager.deleteDocument(document)

        // Verify deletion
        let descriptor = FetchDescriptor<GuionDocumentModel>()
        let documents = try modelContext.fetch(descriptor)
        XCTAssertEqual(documents.count, 0)

        // Verify file still exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Error Description Tests

    func testSingleFileErrorDescriptions() {
        let testURL = tempDirectory.appendingPathComponent("test.fountain")
        let testError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        let fileNotFoundError = SingleFileManager.SingleFileError.fileNotFound(testURL)
        XCTAssertNotNil(fileNotFoundError.errorDescription)
        XCTAssertTrue(fileNotFoundError.errorDescription!.contains("File not found"))

        let fileAccessError = SingleFileManager.SingleFileError.fileAccessFailed(testURL)
        XCTAssertNotNil(fileAccessError.errorDescription)
        XCTAssertTrue(fileAccessError.errorDescription!.contains("Cannot access"))

        let bookmarkCreationError = SingleFileManager.SingleFileError.bookmarkCreationFailed(testError)
        XCTAssertNotNil(bookmarkCreationError.errorDescription)
        XCTAssertTrue(bookmarkCreationError.errorDescription!.contains("bookmark"))

        let bookmarkResolutionError = SingleFileManager.SingleFileError.bookmarkResolutionFailed(testError)
        XCTAssertNotNil(bookmarkResolutionError.errorDescription)
        XCTAssertTrue(bookmarkResolutionError.errorDescription!.contains("resolve"))

        let securityScopedError = SingleFileManager.SingleFileError.securityScopedAccessFailed(testURL)
        XCTAssertNotNil(securityScopedError.errorDescription)
        XCTAssertTrue(securityScopedError.errorDescription!.contains("security-scoped"))

        let noBookmarkDataError = SingleFileManager.SingleFileError.noBookmarkData
        XCTAssertNotNil(noBookmarkDataError.errorDescription)
        XCTAssertTrue(noBookmarkDataError.errorDescription!.contains("bookmark data"))

        let parsingError = SingleFileManager.SingleFileError.parsingFailed("test.fountain", testError)
        XCTAssertNotNil(parsingError.errorDescription)
        XCTAssertTrue(parsingError.errorDescription!.contains("Failed to parse"))

        let saveError = SingleFileManager.SingleFileError.saveError(testError)
        XCTAssertNotNil(saveError.errorDescription)
        XCTAssertTrue(saveError.errorDescription!.contains("save"))

        let documentNotFoundError = SingleFileManager.SingleFileError.documentNotFound
        XCTAssertNotNil(documentNotFoundError.errorDescription)
        XCTAssertTrue(documentNotFoundError.errorDescription!.contains("Document not found"))
    }
}

import XCTest
import Foundation
@testable import SwiftProyecto

final class BookmarkManagerTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        try await super.tearDown()
    }

    // MARK: - Bookmark Creation Tests

    func testCreateBookmark() throws {
        // Given: A valid directory URL
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        // When: Creating a bookmark
        let bookmarkData = try BookmarkManager.createBookmark(for: testDir)

        // Then: Bookmark data should be created
        XCTAssertFalse(bookmarkData.isEmpty, "Bookmark data should not be empty")
        XCTAssertGreaterThan(bookmarkData.count, 0, "Bookmark data should have content")
    }

    func testCreateBookmarkForFile() throws {
        // Given: A valid file URL
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        // When: Creating a bookmark for a file
        let bookmarkData = try BookmarkManager.createBookmark(for: testFile)

        // Then: Bookmark data should be created
        XCTAssertFalse(bookmarkData.isEmpty)
        XCTAssertGreaterThan(bookmarkData.count, 0)
    }

    func testCreateBookmarkForNonexistentPath() throws {
        // Given: A nonexistent path
        let nonexistentPath = tempDirectory.appendingPathComponent("nonexistent")

        // When/Then: Both macOS and iOS should fail for nonexistent paths
        // Security-scoped bookmarks require existing paths on both platforms
        XCTAssertThrowsError(try BookmarkManager.createBookmark(for: nonexistentPath)) { error in
            guard case BookmarkManager.BookmarkError.creationFailed = error else {
                XCTFail("Expected creationFailed error, got \(error)")
                return
            }
        }
    }

    // MARK: - Bookmark Resolution Tests

    func testResolveBookmark() throws {
        // Given: A bookmark for a valid directory
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let bookmarkData = try BookmarkManager.createBookmark(for: testDir)

        // When: Resolving the bookmark
        let (resolvedURL, isStale) = try BookmarkManager.resolveBookmark(bookmarkData)

        // Then: URL should be resolved and not stale
        // Note: Use standardizedFileURL to handle /private/var vs /var symlinks
        XCTAssertEqual(
            resolvedURL.standardizedFileURL.path,
            testDir.standardizedFileURL.path,
            "Resolved URL should match original"
        )
        XCTAssertFalse(isStale, "Fresh bookmark should not be stale")
    }

    func testResolveBookmarkWithInvalidData() {
        // Given: Invalid bookmark data
        let invalidData = Data([0x00, 0x01, 0x02])

        // When/Then: Resolving should throw
        XCTAssertThrowsError(try BookmarkManager.resolveBookmark(invalidData)) { error in
            guard case BookmarkManager.BookmarkError.resolutionFailed = error else {
                XCTFail("Expected resolutionFailed error, got \(error)")
                return
            }
        }
    }

    func testResolveBookmarkWithEmptyData() {
        // Given: Empty bookmark data
        let emptyData = Data()

        // When/Then: Resolving should throw
        XCTAssertThrowsError(try BookmarkManager.resolveBookmark(emptyData)) { error in
            guard case BookmarkManager.BookmarkError.resolutionFailed = error else {
                XCTFail("Expected resolutionFailed error, got \(error)")
                return
            }
        }
    }

    // MARK: - Refresh Tests

    func testRefreshIfNeededWithFreshBookmark() throws {
        // Given: A fresh bookmark
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        var bookmarkData = try BookmarkManager.createBookmark(for: testDir)
        let originalData = bookmarkData

        // When: Refreshing
        let resolvedURL = try BookmarkManager.refreshIfNeeded(&bookmarkData)

        // Then: URL should be correct and bookmark unchanged (not stale)
        XCTAssertEqual(
            resolvedURL.standardizedFileURL.path,
            testDir.standardizedFileURL.path
        )
        XCTAssertEqual(bookmarkData, originalData, "Fresh bookmark should not change")
    }

    func testRefreshIfNeededUpdatesStaleBookmark() throws {
        // Given: A bookmark
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        var bookmarkData = try BookmarkManager.createBookmark(for: testDir)

        // Note: It's difficult to force a stale bookmark in tests without actually moving
        // files or remounting volumes. This test verifies the API works correctly.
        // The stale detection is handled by the OS.

        // When: Refreshing
        let resolvedURL = try BookmarkManager.refreshIfNeeded(&bookmarkData)

        // Then: Should resolve successfully
        XCTAssertEqual(
            resolvedURL.standardizedFileURL.path,
            testDir.standardizedFileURL.path
        )
        XCTAssertFalse(bookmarkData.isEmpty)
    }

    // MARK: - Security-Scoped Access Tests

    func testWithAccessUsingURL() throws {
        // Given: A valid directory
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        // When: Executing operation with access
        let result = try BookmarkManager.withAccess(testDir) { url in
            // Then: Should be able to perform file operations
            return FileManager.default.fileExists(atPath: url.path)
        }

        XCTAssertTrue(result, "Should be able to access directory")
    }

    func testWithAccessUsingBookmark() throws {
        // Given: A bookmark for a directory
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let bookmarkData = try BookmarkManager.createBookmark(for: testDir)

        // When: Executing operation with bookmark access
        let result = try BookmarkManager.withAccess(testDir, bookmarkData: bookmarkData) { url in
            // Then: Should be able to perform file operations
            XCTAssertEqual(
                url.standardizedFileURL.path,
                testDir.standardizedFileURL.path,
                "URL should match original"
            )
            return FileManager.default.fileExists(atPath: url.path)
        }

        XCTAssertTrue(result)
    }

    func testWithAccessThrowsOperationError() throws {
        // Given: A valid directory
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        // When/Then: Operation that throws should propagate error
        struct TestError: Error {}

        XCTAssertThrowsError(
            try BookmarkManager.withAccess(testDir) { _ in
                throw TestError()
            }
        ) { error in
            XCTAssertTrue(error is TestError, "Should propagate operation error")
        }
    }

    func testWithAccessInvalidBookmark() {
        // Given: Invalid bookmark data
        let invalidBookmark = Data([0x00, 0x01, 0x02])

        // When/Then: Should throw bookmark error
        XCTAssertThrowsError(
            try BookmarkManager.withAccess(tempDirectory, bookmarkData: invalidBookmark) { _ in
                return "test"
            }
        ) { error in
            guard case BookmarkManager.BookmarkError.resolutionFailed = error else {
                XCTFail("Expected resolutionFailed error, got \(error)")
                return
            }
        }
    }

    // MARK: - Async Access Tests

    func testWithAccessAsyncUsingURL() async throws {
        // Given: A valid directory
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        // When: Executing async operation with access
        let result = try await BookmarkManager.withAccess(testDir) { url in
            // Simulate async work
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            return FileManager.default.fileExists(atPath: url.path)
        }

        // Then: Should complete successfully
        XCTAssertTrue(result)
    }

    func testWithAccessAsyncUsingBookmark() async throws {
        // Given: A bookmark for a directory
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let bookmarkData = try BookmarkManager.createBookmark(for: testDir)

        // When: Executing async operation with bookmark
        let result = try await BookmarkManager.withAccess(testDir, bookmarkData: bookmarkData) { url in
            try await Task.sleep(nanoseconds: 1_000_000)
            return FileManager.default.fileExists(atPath: url.path)
        }

        // Then: Should complete successfully
        XCTAssertTrue(result)
    }

    func testWithAccessAsyncThrowsOperationError() async throws {
        // Given: A valid directory
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        // When/Then: Async operation that throws should propagate error
        struct AsyncTestError: Error {}

        do {
            _ = try await BookmarkManager.withAccess(testDir) { _ in
                throw AsyncTestError()
            }
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is AsyncTestError, "Should propagate async operation error")
        }
    }

    // MARK: - File Operations Tests

    func testWithAccessReadFile() throws {
        // Given: A file with content
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        let expectedContent = "Hello, BookmarkManager!"
        try expectedContent.write(to: testFile, atomically: true, encoding: .utf8)
        let bookmarkData = try BookmarkManager.createBookmark(for: testFile)

        // When: Reading file with bookmark access
        let content = try BookmarkManager.withAccess(testFile, bookmarkData: bookmarkData) { url in
            try String(contentsOf: url, encoding: .utf8)
        }

        // Then: Content should match
        XCTAssertEqual(content, expectedContent)
    }

    func testWithAccessWriteFile() throws {
        // Given: A directory with bookmark
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let bookmarkData = try BookmarkManager.createBookmark(for: testDir)

        // When: Writing file with bookmark access
        let testContent = "Test content"
        try BookmarkManager.withAccess(testDir, bookmarkData: bookmarkData) { url in
            let fileURL = url.appendingPathComponent("output.txt")
            try testContent.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // Then: File should exist with correct content
        let outputFile = testDir.appendingPathComponent("output.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputFile.path))
        let readContent = try String(contentsOf: outputFile, encoding: .utf8)
        XCTAssertEqual(readContent, testContent)
    }

    func testWithAccessListDirectory() throws {
        // Given: A directory with files
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        try "file1".write(to: testDir.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "file2".write(to: testDir.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
        let bookmarkData = try BookmarkManager.createBookmark(for: testDir)

        // When: Listing directory with bookmark access
        let files = try BookmarkManager.withAccess(testDir, bookmarkData: bookmarkData) { url in
            try FileManager.default.contentsOfDirectory(atPath: url.path)
        }

        // Then: Should find both files
        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files.contains("file1.txt"))
        XCTAssertTrue(files.contains("file2.txt"))
    }

    // MARK: - Multiple Access Tests

    func testMultipleSequentialAccesses() throws {
        // Given: A directory with bookmark
        let testDir = tempDirectory.appendingPathComponent("test", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let bookmarkData = try BookmarkManager.createBookmark(for: testDir)

        // When: Performing multiple sequential accesses
        for i in 1...5 {
            try BookmarkManager.withAccess(testDir, bookmarkData: bookmarkData) { url in
                let file = url.appendingPathComponent("file\(i).txt")
                try "content\(i)".write(to: file, atomically: true, encoding: .utf8)
            }
        }

        // Then: All files should be created
        let files = try FileManager.default.contentsOfDirectory(atPath: testDir.path)
        XCTAssertEqual(files.count, 5)
    }

    func testNestedBookmarkAccess() throws {
        // Given: Parent and child directories
        let parentDir = tempDirectory.appendingPathComponent("parent", isDirectory: true)
        let childDir = parentDir.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: childDir, withIntermediateDirectories: true)

        let parentBookmark = try BookmarkManager.createBookmark(for: parentDir)
        let childBookmark = try BookmarkManager.createBookmark(for: childDir)

        // When: Accessing nested directories
        let parentExists = try BookmarkManager.withAccess(parentDir, bookmarkData: parentBookmark) { url in
            FileManager.default.fileExists(atPath: url.path)
        }

        let childExists = try BookmarkManager.withAccess(childDir, bookmarkData: childBookmark) { url in
            FileManager.default.fileExists(atPath: url.path)
        }

        // Then: Both should be accessible
        XCTAssertTrue(parentExists)
        XCTAssertTrue(childExists)
    }

    // MARK: - Error Description Tests

    func testBookmarkErrorDescriptions() {
        // Test all error descriptions are meaningful
        let errors: [(BookmarkManager.BookmarkError, String)] = [
            (.staleBookmark, "stale"),
            (.accessDenied, "access"),
            (.invalidBookmarkData, "invalid"),
            (.resolutionFailed(NSError(domain: "test", code: 1)), "resolve"),
            (.creationFailed(NSError(domain: "test", code: 2)), "create")
        ]

        for (error, keyword) in errors {
            let description = error.errorDescription ?? ""
            XCTAssertFalse(description.isEmpty, "Error description should not be empty")
            XCTAssertTrue(
                description.lowercased().contains(keyword),
                "Error description should contain '\(keyword)': \(description)"
            )
        }
    }
}

//
//  DirectoryFileSourceTests.swift
//  SwiftProyectoTests
//
//  Tests for DirectoryFileSource implementation.
//

import XCTest
import Foundation
@testable import SwiftProyecto

final class DirectoryFileSourceTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary test directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DirectoryFileSourceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization_WithDefaultName() {
        let source = DirectoryFileSource(url: tempDirectory)

        XCTAssertNotNil(source.id)
        XCTAssertEqual(source.name, tempDirectory.lastPathComponent)
        XCTAssertEqual(source.sourceType, .directory)
        XCTAssertEqual(source.rootURL, tempDirectory)
        XCTAssertNil(source.bookmarkData)
    }

    func testInitialization_WithCustomName() {
        let source = DirectoryFileSource(url: tempDirectory, name: "Custom Name")

        XCTAssertEqual(source.name, "Custom Name")
        XCTAssertEqual(source.rootURL, tempDirectory)
    }

    func testInitialization_WithBookmarkData() {
        let bookmarkData = Data("test-bookmark".utf8)
        let source = DirectoryFileSource(url: tempDirectory, bookmarkData: bookmarkData)

        XCTAssertEqual(source.bookmarkData, bookmarkData)
    }

    // MARK: - File Discovery Tests

    func testDiscoverFiles_EmptyDirectory() async throws {
        let source = DirectoryFileSource(url: tempDirectory)
        let files = try await source.discoverFiles()

        XCTAssertTrue(files.isEmpty, "Empty directory should return no files")
    }

    func testDiscoverFiles_SingleFile() async throws {
        // Create a test file
        let testFile = tempDirectory.appendingPathComponent("test.fountain")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)

        let source = DirectoryFileSource(url: tempDirectory)
        let files = try await source.discoverFiles()

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "test.fountain")
        XCTAssertEqual(files[0].relativePath, "test.fountain")
        XCTAssertEqual(files[0].fileExtension, "fountain")
        XCTAssertNotNil(files[0].modificationDate)
        XCTAssertNotNil(files[0].fileSize)
        XCTAssertTrue(files[0].isInRoot)
    }

    func testDiscoverFiles_MultipleFiles() async throws {
        // Create multiple test files
        let file1 = tempDirectory.appendingPathComponent("episode-01.fountain")
        let file2 = tempDirectory.appendingPathComponent("episode-02.fountain")
        let file3 = tempDirectory.appendingPathComponent("notes.txt")

        try "Episode 1".write(to: file1, atomically: true, encoding: .utf8)
        try "Episode 2".write(to: file2, atomically: true, encoding: .utf8)
        try "Notes".write(to: file3, atomically: true, encoding: .utf8)

        let source = DirectoryFileSource(url: tempDirectory)
        let files = try await source.discoverFiles()

        XCTAssertEqual(files.count, 3)

        // Verify files are sorted by relative path
        XCTAssertEqual(files[0].filename, "episode-01.fountain")
        XCTAssertEqual(files[1].filename, "episode-02.fountain")
        XCTAssertEqual(files[2].filename, "notes.txt")
    }

    func testDiscoverFiles_NestedDirectories() async throws {
        // Create nested directory structure
        let season1 = tempDirectory.appendingPathComponent("Season 1")
        let season2 = tempDirectory.appendingPathComponent("Season 2")

        try FileManager.default.createDirectory(at: season1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: season2, withIntermediateDirectories: true)

        let file1 = season1.appendingPathComponent("episode-01.fountain")
        let file2 = season1.appendingPathComponent("episode-02.fountain")
        let file3 = season2.appendingPathComponent("episode-01.fountain")

        try "S1E1".write(to: file1, atomically: true, encoding: .utf8)
        try "S1E2".write(to: file2, atomically: true, encoding: .utf8)
        try "S2E1".write(to: file3, atomically: true, encoding: .utf8)

        let source = DirectoryFileSource(url: tempDirectory)
        let files = try await source.discoverFiles()

        XCTAssertEqual(files.count, 3)

        // Verify relative paths include subdirectories
        XCTAssertEqual(files[0].relativePath, "Season 1/episode-01.fountain")
        XCTAssertEqual(files[1].relativePath, "Season 1/episode-02.fountain")
        XCTAssertEqual(files[2].relativePath, "Season 2/episode-01.fountain")

        // Verify directory information
        XCTAssertFalse(files[0].isInRoot)
        XCTAssertEqual(files[0].directory, "Season 1")
        XCTAssertEqual(files[2].directory, "Season 2")
    }

    func testDiscoverFiles_ExcludesSystemFiles() async throws {
        // Create files that should be excluded
        let dsStore = tempDirectory.appendingPathComponent(".DS_Store")
        let gitDir = tempDirectory.appendingPathComponent(".git")
        let cacheDir = tempDirectory.appendingPathComponent(".cache")
        let projectMd = tempDirectory.appendingPathComponent("PROJECT.md")
        let validFile = tempDirectory.appendingPathComponent("script.fountain")

        try "".write(to: dsStore, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try "project".write(to: projectMd, atomically: true, encoding: .utf8)
        try "script".write(to: validFile, atomically: true, encoding: .utf8)

        let source = DirectoryFileSource(url: tempDirectory)
        let files = try await source.discoverFiles()

        // Should only find the valid file
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "script.fountain")
    }

    func testDiscoverFiles_ExcludesHiddenFiles() async throws {
        // Create hidden and visible files
        let hiddenFile = tempDirectory.appendingPathComponent(".hidden.txt")
        let visibleFile = tempDirectory.appendingPathComponent("visible.txt")

        try "hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)
        try "visible".write(to: visibleFile, atomically: true, encoding: .utf8)

        let source = DirectoryFileSource(url: tempDirectory)
        let files = try await source.discoverFiles()

        // Should only find visible file
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "visible.txt")
    }

    // MARK: - Read File Tests

    func testReadFile_Success() async throws {
        let testContent = "INT. COFFEE SHOP - DAY\n\nJane enters."
        let testFile = tempDirectory.appendingPathComponent("script.fountain")
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)

        let source = DirectoryFileSource(url: tempDirectory)
        let data = try await source.readFile(at: "script.fountain")
        let readContent = String(data: data, encoding: .utf8)

        XCTAssertEqual(readContent, testContent)
    }

    func testReadFile_NestedPath() async throws {
        let subdir = tempDirectory.appendingPathComponent("season-1")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let testContent = "Episode 1 content"
        let testFile = subdir.appendingPathComponent("episode.fountain")
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)

        let source = DirectoryFileSource(url: tempDirectory)
        let data = try await source.readFile(at: "season-1/episode.fountain")
        let readContent = String(data: data, encoding: .utf8)

        XCTAssertEqual(readContent, testContent)
    }

    func testReadFile_FileNotFound() async throws {
        let source = DirectoryFileSource(url: tempDirectory)

        do {
            _ = try await source.readFile(at: "nonexistent.fountain")
            XCTFail("Expected FileSourceError.fileNotFound")
        } catch let error as FileSourceError {
            if case .fileNotFound(let path) = error {
                XCTAssertEqual(path, "nonexistent.fountain")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testReadFile_BinaryContent() async throws {
        // Test reading binary data
        let binaryData = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD])
        let testFile = tempDirectory.appendingPathComponent("binary.dat")
        try binaryData.write(to: testFile)

        let source = DirectoryFileSource(url: tempDirectory)
        let readData = try await source.readFile(at: "binary.dat")

        XCTAssertEqual(readData, binaryData)
    }

    // MARK: - Modification Date Tests

    func testModificationDate_Success() throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "content".write(to: testFile, atomically: true, encoding: .utf8)

        let source = DirectoryFileSource(url: tempDirectory)
        let modDate = try source.modificationDate(for: "test.txt")

        XCTAssertNotNil(modDate)

        // Modification date should be recent (within last minute)
        let now = Date()
        XCTAssertLessThan(now.timeIntervalSince(modDate!), 60)
    }

    func testModificationDate_FileNotFound() throws {
        let source = DirectoryFileSource(url: tempDirectory)

        do {
            _ = try source.modificationDate(for: "nonexistent.txt")
            XCTFail("Expected FileSourceError.fileNotFound")
        } catch let error as FileSourceError {
            if case .fileNotFound(let path) = error {
                XCTAssertEqual(path, "nonexistent.txt")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - DiscoveredFile Tests

    func testDiscoveredFile_PathComponents() {
        let file = DiscoveredFile(
            relativePath: "Season 1/Episode 2/script.fountain",
            filename: "script.fountain",
            fileExtension: "fountain"
        )

        XCTAssertEqual(file.pathComponents, ["Season 1", "Episode 2", "script.fountain"])
        XCTAssertEqual(file.directory, "Season 1/Episode 2")
        XCTAssertFalse(file.isInRoot)
    }

    func testDiscoveredFile_RootFile() {
        let file = DiscoveredFile(
            relativePath: "script.fountain",
            filename: "script.fountain",
            fileExtension: "fountain"
        )

        XCTAssertEqual(file.pathComponents, ["script.fountain"])
        XCTAssertNil(file.directory)
        XCTAssertTrue(file.isInRoot)
    }

    func testDiscoveredFile_Equality() {
        let file1 = DiscoveredFile(
            id: UUID(),
            relativePath: "test.txt",
            filename: "test.txt",
            fileExtension: "txt"
        )

        let file2 = DiscoveredFile(
            id: file1.id,
            relativePath: "test.txt",
            filename: "test.txt",
            fileExtension: "txt"
        )

        XCTAssertEqual(file1, file2)
    }

    // MARK: - Integration Tests

    func testDiscoverAndRead_Integration() async throws {
        // Create a project-like structure
        let season1 = tempDirectory.appendingPathComponent("Season 1")
        try FileManager.default.createDirectory(at: season1, withIntermediateDirectories: true)

        let episodes = [
            ("episode-01.fountain", "INT. SCENE 1"),
            ("episode-02.fountain", "INT. SCENE 2"),
            ("episode-03.fountain", "INT. SCENE 3")
        ]

        for (filename, content) in episodes {
            let fileURL = season1.appendingPathComponent(filename)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let source = DirectoryFileSource(url: tempDirectory)

        // Discover all files
        let discovered = try await source.discoverFiles()
        XCTAssertEqual(discovered.count, 3)

        // Read each discovered file
        for file in discovered {
            let data = try await source.readFile(at: file.relativePath)
            let content = String(data: data, encoding: .utf8)
            XCTAssertNotNil(content)
            XCTAssertTrue(content!.hasPrefix("INT. SCENE"))
        }
    }

    func testProjectModel_FileSourceReconstruction() async throws {
        // Create a test file
        let testFile = tempDirectory.appendingPathComponent("test.fountain")
        try "Test".write(to: testFile, atomically: true, encoding: .utf8)

        // Create a ProjectModel with DirectoryFileSource data
        let project = ProjectModel(
            title: "Test Project",
            author: "Test Author",
            sourceType: .directory,
            sourceName: tempDirectory.lastPathComponent,
            sourceRootURL: tempDirectory.absoluteString
        )

        // Reconstruct the file source
        guard let fileSource = project.fileSource() as? DirectoryFileSource else {
            XCTFail("Failed to reconstruct DirectoryFileSource")
            return
        }

        // Verify the source works
        XCTAssertEqual(fileSource.sourceType, .directory)
        XCTAssertEqual(fileSource.rootURL, tempDirectory)

        let files = try await fileSource.discoverFiles()
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "test.fountain")
    }
}

//
//  GitRepositoryFileSourceTests.swift
//  SwiftProyectoTests
//
//  Tests for GitRepositoryFileSource implementation.
//

import XCTest
import Foundation
@testable import SwiftProyecto

final class GitRepositoryFileSourceTests: XCTestCase {
    var tempDirectory: URL!
    var gitRepoDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary test directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitRepositoryFileSourceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Create a git repository directory
        gitRepoDirectory = tempDirectory.appendingPathComponent("test-repo")
        try FileManager.default.createDirectory(at: gitRepoDirectory, withIntermediateDirectories: true)

        // Create .git directory to simulate a git repo
        let gitDir = gitRepoDirectory.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization_ValidGitRepo() throws {
        let source = try GitRepositoryFileSource(url: gitRepoDirectory)

        XCTAssertNotNil(source.id)
        XCTAssertEqual(source.name, gitRepoDirectory.lastPathComponent)
        XCTAssertEqual(source.sourceType, .gitRepository)
        XCTAssertEqual(source.rootURL, gitRepoDirectory)
        XCTAssertNil(source.bookmarkData)
    }

    func testInitialization_WithCustomName() throws {
        let source = try GitRepositoryFileSource(url: gitRepoDirectory, name: "My Repo")

        XCTAssertEqual(source.name, "My Repo")
        XCTAssertEqual(source.rootURL, gitRepoDirectory)
    }

    func testInitialization_WithBookmarkData() throws {
        let bookmarkData = Data("test-bookmark".utf8)
        let source = try GitRepositoryFileSource(url: gitRepoDirectory, bookmarkData: bookmarkData)

        XCTAssertEqual(source.bookmarkData, bookmarkData)
    }

    func testInitialization_NotGitRepository() throws {
        // Create directory without .git
        let nonGitDir = tempDirectory.appendingPathComponent("not-git")
        try FileManager.default.createDirectory(at: nonGitDir, withIntermediateDirectories: true)

        XCTAssertThrowsError(try GitRepositoryFileSource(url: nonGitDir)) { error in
            guard let fileSourceError = error as? FileSourceError else {
                XCTFail("Expected FileSourceError, got \(error)")
                return
            }

            if case .notGitRepository = fileSourceError {
                // Expected error
            } else {
                XCTFail("Expected .notGitRepository error, got \(fileSourceError)")
            }
        }
    }

    func testInitialization_GitFileNotDirectory() throws {
        // Create .git as a file instead of directory
        let badGitDir = tempDirectory.appendingPathComponent("bad-repo")
        try FileManager.default.createDirectory(at: badGitDir, withIntermediateDirectories: true)

        let gitFile = badGitDir.appendingPathComponent(".git")
        try "not a directory".write(to: gitFile, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try GitRepositoryFileSource(url: badGitDir)) { error in
            guard let fileSourceError = error as? FileSourceError else {
                XCTFail("Expected FileSourceError, got \(error)")
                return
            }

            if case .notGitRepository = fileSourceError {
                // Expected error
            } else {
                XCTFail("Expected .notGitRepository error, got \(fileSourceError)")
            }
        }
    }

    // MARK: - File Discovery Tests

    func testDiscoverFiles_EmptyRepository() async throws {
        let source = try GitRepositoryFileSource(url: gitRepoDirectory)
        let files = try await source.discoverFiles()

        XCTAssertTrue(files.isEmpty, "Empty repository should return no files")
    }

    func testDiscoverFiles_SingleFile() async throws {
        // Create a test file
        let testFile = gitRepoDirectory.appendingPathComponent("script.fountain")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)

        let source = try GitRepositoryFileSource(url: gitRepoDirectory)
        let files = try await source.discoverFiles()

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "script.fountain")
        XCTAssertEqual(files[0].relativePath, "script.fountain")
        XCTAssertEqual(files[0].fileExtension, "fountain")
        XCTAssertNotNil(files[0].modificationDate)
        XCTAssertNotNil(files[0].fileSize)
    }

    func testDiscoverFiles_MultipleFiles() async throws {
        // Create multiple files
        let file1 = gitRepoDirectory.appendingPathComponent("episode-01.fountain")
        let file2 = gitRepoDirectory.appendingPathComponent("episode-02.fountain")
        let file3 = gitRepoDirectory.appendingPathComponent("README.md")

        try "Episode 1".write(to: file1, atomically: true, encoding: .utf8)
        try "Episode 2".write(to: file2, atomically: true, encoding: .utf8)
        try "Readme".write(to: file3, atomically: true, encoding: .utf8)

        let source = try GitRepositoryFileSource(url: gitRepoDirectory)
        let files = try await source.discoverFiles()

        XCTAssertEqual(files.count, 3)

        // Verify sorted by relative path
        XCTAssertEqual(files[0].filename, "README.md")
        XCTAssertEqual(files[1].filename, "episode-01.fountain")
        XCTAssertEqual(files[2].filename, "episode-02.fountain")
    }

    func testDiscoverFiles_NestedDirectories() async throws {
        // Create nested structure
        let season1 = gitRepoDirectory.appendingPathComponent("Season 1")
        let season2 = gitRepoDirectory.appendingPathComponent("Season 2")

        try FileManager.default.createDirectory(at: season1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: season2, withIntermediateDirectories: true)

        let file1 = season1.appendingPathComponent("episode-01.fountain")
        let file2 = season1.appendingPathComponent("episode-02.fountain")
        let file3 = season2.appendingPathComponent("episode-01.fountain")

        try "S1E1".write(to: file1, atomically: true, encoding: .utf8)
        try "S1E2".write(to: file2, atomically: true, encoding: .utf8)
        try "S2E1".write(to: file3, atomically: true, encoding: .utf8)

        let source = try GitRepositoryFileSource(url: gitRepoDirectory)
        let files = try await source.discoverFiles()

        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(files[0].relativePath, "Season 1/episode-01.fountain")
        XCTAssertEqual(files[1].relativePath, "Season 1/episode-02.fountain")
        XCTAssertEqual(files[2].relativePath, "Season 2/episode-01.fountain")
    }

    func testDiscoverFiles_ExcludesGitDirectory() async throws {
        // Create files in .git directory (should be excluded)
        let gitObjects = gitRepoDirectory.appendingPathComponent(".git/objects")
        try FileManager.default.createDirectory(at: gitObjects, withIntermediateDirectories: true)

        let gitFile = gitObjects.appendingPathComponent("test-object")
        try "git data".write(to: gitFile, atomically: true, encoding: .utf8)

        // Create valid file in root
        let validFile = gitRepoDirectory.appendingPathComponent("script.fountain")
        try "script".write(to: validFile, atomically: true, encoding: .utf8)

        let source = try GitRepositoryFileSource(url: gitRepoDirectory)
        let files = try await source.discoverFiles()

        // Should only find the valid file, not .git contents
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "script.fountain")
    }

    func testDiscoverFiles_ExcludesSystemFiles() async throws {
        // Create files that should be excluded
        let dsStore = gitRepoDirectory.appendingPathComponent(".DS_Store")
        let cacheDir = gitRepoDirectory.appendingPathComponent(".cache")
        let projectMd = gitRepoDirectory.appendingPathComponent("PROJECT.md")
        let validFile = gitRepoDirectory.appendingPathComponent("script.fountain")

        try "".write(to: dsStore, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try "project".write(to: projectMd, atomically: true, encoding: .utf8)
        try "script".write(to: validFile, atomically: true, encoding: .utf8)

        let source = try GitRepositoryFileSource(url: gitRepoDirectory)
        let files = try await source.discoverFiles()

        // Should only find the valid file
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "script.fountain")
    }

    func testDiscoverFiles_ExcludesHiddenFiles() async throws {
        // Create hidden and visible files
        let hiddenFile = gitRepoDirectory.appendingPathComponent(".hidden.txt")
        let visibleFile = gitRepoDirectory.appendingPathComponent("visible.txt")

        try "hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)
        try "visible".write(to: visibleFile, atomically: true, encoding: .utf8)

        let source = try GitRepositoryFileSource(url: gitRepoDirectory)
        let files = try await source.discoverFiles()

        // Should only find visible file
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "visible.txt")
    }

    // MARK: - Read File Tests

    func testReadFile_Success() async throws {
        let testContent = "INT. OFFICE - DAY\n\nJohn types code."
        let testFile = gitRepoDirectory.appendingPathComponent("script.fountain")
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)

        let source = try GitRepositoryFileSource(url: gitRepoDirectory)
        let data = try await source.readFile(at: "script.fountain")
        let readContent = String(data: data, encoding: .utf8)

        XCTAssertEqual(readContent, testContent)
    }

    func testReadFile_NestedPath() async throws {
        let subdir = gitRepoDirectory.appendingPathComponent("episodes")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let testContent = "Episode content"
        let testFile = subdir.appendingPathComponent("ep1.fountain")
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)

        let source = try GitRepositoryFileSource(url: gitRepoDirectory)
        let data = try await source.readFile(at: "episodes/ep1.fountain")
        let readContent = String(data: data, encoding: .utf8)

        XCTAssertEqual(readContent, testContent)
    }

    func testReadFile_FileNotFound() async throws {
        let source = try GitRepositoryFileSource(url: gitRepoDirectory)

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
        let testFile = gitRepoDirectory.appendingPathComponent("binary.dat")
        try binaryData.write(to: testFile)

        let source = try GitRepositoryFileSource(url: gitRepoDirectory)
        let readData = try await source.readFile(at: "binary.dat")

        XCTAssertEqual(readData, binaryData)
    }

    // MARK: - Modification Date Tests

    func testModificationDate_Success() throws {
        let testFile = gitRepoDirectory.appendingPathComponent("test.txt")
        try "content".write(to: testFile, atomically: true, encoding: .utf8)

        let source = try GitRepositoryFileSource(url: gitRepoDirectory)
        let modDate = try source.modificationDate(for: "test.txt")

        XCTAssertNotNil(modDate)

        // Modification date should be recent (within last minute)
        let now = Date()
        XCTAssertLessThan(now.timeIntervalSince(modDate!), 60)
    }

    func testModificationDate_FileNotFound() throws {
        let source = try GitRepositoryFileSource(url: gitRepoDirectory)

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

    // MARK: - Integration Tests

    func testDiscoverAndRead_Integration() async throws {
        // Create a realistic git repo structure
        let src = gitRepoDirectory.appendingPathComponent("src")
        let tests = gitRepoDirectory.appendingPathComponent("tests")

        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tests, withIntermediateDirectories: true)

        let files = [
            ("README.md", "# My Project"),
            ("src/main.fountain", "INT. MAIN SCENE"),
            ("src/scene2.fountain", "INT. SCENE 2"),
            ("tests/test.txt", "Test content")
        ]

        for (path, content) in files {
            let fileURL = gitRepoDirectory.appendingPathComponent(path)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let source = try GitRepositoryFileSource(url: gitRepoDirectory)

        // Discover all files
        let discovered = try await source.discoverFiles()
        XCTAssertEqual(discovered.count, 4)

        // Read each discovered file
        for file in discovered {
            let data = try await source.readFile(at: file.relativePath)
            let content = String(data: data, encoding: .utf8)
            XCTAssertNotNil(content)
            XCTAssertFalse(content!.isEmpty)
        }
    }

    func testProjectModel_GitRepositoryReconstruction() async throws {
        // Create a test file in the git repo
        let testFile = gitRepoDirectory.appendingPathComponent("test.fountain")
        try "Test".write(to: testFile, atomically: true, encoding: .utf8)

        // Create a ProjectModel with GitRepositoryFileSource data
        let project = ProjectModel(
            title: "Test Repo",
            author: "Test Author",
            sourceType: .gitRepository,
            sourceName: gitRepoDirectory.lastPathComponent,
            sourceRootURL: gitRepoDirectory.absoluteString
        )

        // Reconstruct the file source
        guard let fileSource = project.fileSource() as? GitRepositoryFileSource else {
            XCTFail("Failed to reconstruct GitRepositoryFileSource")
            return
        }

        // Verify the source works
        XCTAssertEqual(fileSource.sourceType, .gitRepository)
        XCTAssertEqual(fileSource.rootURL, gitRepoDirectory)

        let files = try await fileSource.discoverFiles()
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "test.fountain")
    }

    func testGitRepository_WithSubmodules() async throws {
        // Simulate a repo with submodules (.git is a file, not directory)
        // This is an edge case in git repos with submodules

        let submoduleRepo = tempDirectory.appendingPathComponent("submodule-repo")
        try FileManager.default.createDirectory(at: submoduleRepo, withIntermediateDirectories: true)

        // In a submodule, .git is a file pointing to parent's .git
        let gitFile = submoduleRepo.appendingPathComponent(".git")
        try "gitdir: ../parent/.git/modules/submodule".write(to: gitFile, atomically: true, encoding: .utf8)

        // This should fail because .git is not a directory
        XCTAssertThrowsError(try GitRepositoryFileSource(url: submoduleRepo)) { error in
            guard let fileSourceError = error as? FileSourceError else {
                XCTFail("Expected FileSourceError, got \(error)")
                return
            }

            if case .notGitRepository = fileSourceError {
                // Expected - we don't support submodule-style .git files yet
            } else {
                XCTFail("Expected .notGitRepository error, got \(fileSourceError)")
            }
        }
    }

    func testSourceTypeEnum() {
        // Verify FileSourceType enum has gitRepository case
        let source = FileSourceType.gitRepository
        XCTAssertEqual(source, .gitRepository)

        // Verify it's Codable
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try? encoder.encode(source)
        XCTAssertNotNil(encoded)

        let decoded = try? decoder.decode(FileSourceType.self, from: encoded!)
        XCTAssertEqual(decoded, .gitRepository)
    }
}

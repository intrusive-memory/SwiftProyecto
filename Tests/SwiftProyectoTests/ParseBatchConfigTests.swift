import XCTest
@testable import SwiftProyecto

final class ParseBatchConfigTests: XCTestCase {

    var tempDirectory: URL!
    var testProjectURL: URL!

    override func setUp() {
        super.setUp()

        // Create temporary test project
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ParseBatchTests-\(UUID().uuidString)")

        testProjectURL = tempDirectory.appendingPathComponent("test-project")

        try? FileManager.default.createDirectory(
            at: testProjectURL,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTestProject(
        title: String = "Test Series",
        author: String = "Test Author",
        episodesDir: String = "episodes",
        audioDir: String = "audio",
        filePattern: String = "*.fountain",
        exportFormat: String = "m4a",
        episodeCount: Int = 5
    ) throws {
        // Create PROJECT.md
        let projectMd = """
        ---
        type: project
        title: \(title)
        author: \(author)
        created: 2025-01-01T00:00:00Z
        season: 1
        episodes: \(episodeCount)
        genre: Drama
        tags: [test, sample]
        episodesDir: \(episodesDir)
        audioDir: \(audioDir)
        filePattern: \(filePattern)
        exportFormat: \(exportFormat)
        ---

        # Test Project

        This is a test project for unit testing.
        """

        try projectMd.write(
            to: testProjectURL.appendingPathComponent("PROJECT.md"),
            atomically: true,
            encoding: .utf8
        )

        // Create episodes directory
        let episodesDirURL = testProjectURL.appendingPathComponent(episodesDir)
        try FileManager.default.createDirectory(at: episodesDirURL, withIntermediateDirectories: true)

        // Create test episode files
        for i in 1...episodeCount {
            let episodeContent = """
            Title: Episode \(i)

            INT. TEST - DAY

            TEST CHARACTER
            This is episode \(i).
            """

            let filename = String(format: "%03d_episode_%02d.fountain", i, i)
            try episodeContent.write(
                to: episodesDirURL.appendingPathComponent(filename),
                atomically: true,
                encoding: .utf8
            )
        }

        // Create audio directory
        let audioDirURL = testProjectURL.appendingPathComponent(audioDir)
        try FileManager.default.createDirectory(at: audioDirURL, withIntermediateDirectories: true)
    }

    // MARK: - ParseBatchConfig Creation Tests

    func testParseBatchConfig_FromProjectPath() throws {
        try createTestProject()

        let config = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: nil
        )

        // Verify PROJECT.md metadata was parsed
        XCTAssertEqual(config.title, "Test Series")
        XCTAssertEqual(config.author, "Test Author")
        XCTAssertEqual(config.exportFormat, "m4a")

        // Verify directory resolution
        XCTAssertEqual(config.episodesDir, "episodes")
        XCTAssertEqual(config.audioDir, "audio")
        XCTAssertTrue(config.episodesDirURL.path.hasSuffix("/episodes"))
        XCTAssertTrue(config.audioDirURL.path.hasSuffix("/audio"))

        // Verify file patterns
        XCTAssertEqual(config.filePatterns, ["*.fountain"])

        // Verify files were discovered
        XCTAssertEqual(config.discoveredFiles.count, 5)
    }

    func testParseBatchConfig_CLIOverrides() throws {
        try createTestProject()

        let args = ParseBatchArguments(
            projectPath: testProjectURL.path,
            output: "custom-output",
            format: "mp3",
            skipExisting: true,
            resumeFrom: 2,
            regenerate: false,
            verbose: true
        )

        let config = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: args
        )

        // CLI overrides should take precedence
        XCTAssertEqual(config.audioDir, "custom-output")
        XCTAssertEqual(config.exportFormat, "mp3")
        XCTAssertTrue(config.skipExisting)
        XCTAssertEqual(config.resumeFrom, 2)
        XCTAssertFalse(config.regenerate)
        XCTAssertTrue(config.verbose)

        // PROJECT.md defaults should be used for non-overridden fields
        XCTAssertEqual(config.episodesDir, "episodes")
    }

    func testParseBatchConfig_NoArgs() throws {
        try createTestProject()

        // Test with nil args - all defaults from PROJECT.md
        let config = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: nil
        )

        XCTAssertEqual(config.episodesDir, "episodes")
        XCTAssertEqual(config.audioDir, "audio")
        XCTAssertEqual(config.exportFormat, "m4a")
        XCTAssertFalse(config.skipExisting)
        XCTAssertNil(config.resumeFrom)
        XCTAssertFalse(config.regenerate)
    }

    // MARK: - ParseFileIterator Tests

    func testParseFileIterator_BasicIteration() throws {
        try createTestProject(episodeCount: 3)

        let config = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: nil
        )
        var iterator = config.makeIterator()

        // Test first file
        guard let firstArgs = iterator.next() else {
            XCTFail("Iterator should yield at least one ParseCommandArguments")
            return
        }

        XCTAssertTrue(firstArgs.episodeFileURL.lastPathComponent.hasSuffix(".fountain"))
        XCTAssertTrue(firstArgs.episodeFileURL.path.contains("/episodes/"))
        XCTAssertTrue(firstArgs.outputURL.path.contains("/audio/"))
        XCTAssertTrue(firstArgs.outputURL.lastPathComponent.hasSuffix(".m4a"))
        XCTAssertEqual(firstArgs.exportFormat, "m4a")
        XCTAssertFalse(firstArgs.verbose)
        XCTAssertFalse(firstArgs.dryRun)

        // Verify output filename matches input
        let inputBase = firstArgs.episodeFileURL.deletingPathExtension().lastPathComponent
        let outputBase = firstArgs.outputURL.deletingPathExtension().lastPathComponent
        XCTAssertEqual(inputBase, outputBase)
    }

    func testParseFileIterator_IteratesAllFiles() throws {
        try createTestProject(episodeCount: 5)

        let config = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: nil
        )
        var iterator = config.makeIterator()

        var count = 0
        while let args = iterator.next() {
            count += 1

            // Validate each ParseCommandArguments
            XCTAssertNotNil(args.episodeFileURL)
            XCTAssertNotNil(args.outputURL)
            XCTAssertFalse(args.exportFormat.isEmpty)
        }

        XCTAssertEqual(count, 5, "Should iterate through all 5 episode files")
        XCTAssertEqual(iterator.currentFileIndex, 5)
    }

    func testParseFileIterator_Collect() throws {
        try createTestProject(episodeCount: 5)

        let config = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: nil
        )
        var iterator = config.makeIterator()

        let allArgs = iterator.collect()

        XCTAssertEqual(allArgs.count, 5)

        // Verify sorted order
        for i in 0..<allArgs.count - 1 {
            let current = allArgs[i].episodeFileURL.lastPathComponent
            let next = allArgs[i + 1].episodeFileURL.lastPathComponent
            XCTAssertLessThan(current, next, "Files should be sorted alphabetically")
        }
    }

    func testParseFileIterator_ResumeFrom() throws {
        try createTestProject(episodeCount: 5)

        let args = ParseBatchArguments(
            projectPath: testProjectURL.path,
            resumeFrom: 3
        )

        let config = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: args
        )
        var iterator = config.makeIterator()

        var count = 0
        while iterator.next() != nil {
            count += 1
        }

        // Should process 5 - 2 = 3 files (resumeFrom 3 means skip first 2)
        XCTAssertEqual(count, 3)
    }

    func testParseFileIterator_ResumeFromEdgeCases() throws {
        try createTestProject(episodeCount: 5)

        // Resume from 1 should process all files
        let args1 = ParseBatchArguments(
            projectPath: testProjectURL.path,
            resumeFrom: 1
        )
        let config1 = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: args1
        )
        var iterator1 = config1.makeIterator()
        XCTAssertEqual(iterator1.collect().count, 5)

        // Resume from beyond total should yield no files
        let args2 = ParseBatchArguments(
            projectPath: testProjectURL.path,
            resumeFrom: 10
        )
        let config2 = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: args2
        )
        var iterator2 = config2.makeIterator()
        XCTAssertEqual(iterator2.collect().count, 0)
    }

    // MARK: - ParseCommandArguments Validation Tests

    func testParseCommandArguments_Validation() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let episodeURL = tempDir.appendingPathComponent("test.fountain")
        let outputURL = tempDir.appendingPathComponent("test.m4a")

        // Create test file
        try "test content".write(to: episodeURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: episodeURL) }

        let args = ParseCommandArguments(
            episodeFileURL: episodeURL,
            outputURL: outputURL
        )

        // Should not throw - file exists
        XCTAssertNoThrow(try args.validate())

        // Test with non-existent file
        let invalidArgs = ParseCommandArguments(
            episodeFileURL: tempDir.appendingPathComponent("nonexistent.fountain"),
            outputURL: outputURL
        )

        XCTAssertThrowsError(try invalidArgs.validate()) { error in
            XCTAssertTrue(error.localizedDescription.contains("not found"))
        }
    }

    func testParseCommandArguments_MutuallyExclusiveValidation() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let episodeURL = tempDir.appendingPathComponent("test.fountain")
        let outputURL = tempDir.appendingPathComponent("test.m4a")

        try "test".write(to: episodeURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: episodeURL) }

        // Test verbose + quiet
        let args = ParseCommandArguments(
            episodeFileURL: episodeURL,
            outputURL: outputURL,
            verbose: true,
            quiet: true
        )

        XCTAssertThrowsError(try args.validate()) { error in
            XCTAssertTrue(error.localizedDescription.contains("Cannot use"))
        }
    }

    // MARK: - Filter Behavior Tests

    func testParseFileIterator_SkipExisting() throws {
        try createTestProject(episodeCount: 3)

        let config = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: ParseBatchArguments(
                projectPath: testProjectURL.path,
                skipExisting: true
            )
        )

        // Create audio directory and fake output file for first episode
        let audioDirURL = testProjectURL.appendingPathComponent("audio")
        var tempIterator = config.makeIterator()
        guard let firstArgs = tempIterator.next() else {
            XCTFail("Should have at least one file")
            return
        }

        try "fake audio".write(to: firstArgs.outputURL, atomically: true, encoding: .utf8)

        // Create new iterator to test skipExisting behavior
        var iterator = config.makeIterator()
        guard let afterSkip = iterator.next() else {
            XCTFail("Should have next file after skipping first")
            return
        }

        // Should be second file, not first
        XCTAssertNotEqual(afterSkip.episodeFileURL.lastPathComponent, "001_episode_01.fountain")
        XCTAssertEqual(afterSkip.episodeFileURL.lastPathComponent, "002_episode_02.fountain")
    }

    func testParseFileIterator_RegenerateOverridesSkipExisting() throws {
        try createTestProject(episodeCount: 3)

        let config = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: ParseBatchArguments(
                projectPath: testProjectURL.path,
                skipExisting: true,
                regenerate: true  // Should override skipExisting
            )
        )

        // Create fake output file for first episode
        var tempIterator = config.makeIterator()
        guard let firstArgs = tempIterator.next() else {
            XCTFail("Should have at least one file")
            return
        }

        try "fake audio".write(to: firstArgs.outputURL, atomically: true, encoding: .utf8)

        // Create new iterator
        var iterator = config.makeIterator()
        guard let afterRegenerate = iterator.next() else {
            XCTFail("Should have first file with regenerate")
            return
        }

        // With regenerate, should NOT skip existing file
        XCTAssertEqual(afterRegenerate.episodeFileURL.lastPathComponent, "001_episode_01.fountain")
    }

    // MARK: - Configuration Priority Tests

    func testConfigurationPriority_CLIOverridesProjectMd() throws {
        try createTestProject(
            audioDir: "default-audio",
            exportFormat: "m4a"
        )

        // CLI overrides both
        let args = ParseBatchArguments(
            projectPath: testProjectURL.path,
            output: "cli-override-audio",
            format: "mp3"
        )

        let config = try ParseBatchConfig.from(
            projectPath: testProjectURL.path,
            args: args
        )

        XCTAssertEqual(config.audioDir, "cli-override-audio", "CLI should override PROJECT.md audioDir")
        XCTAssertEqual(config.exportFormat, "mp3", "CLI should override PROJECT.md exportFormat")

        // Non-overridden field should use PROJECT.md value
        XCTAssertEqual(config.episodesDir, "episodes", "Should use PROJECT.md episodesDir")
    }

    // MARK: - Error Handling Tests

    func testParseBatchConfig_InvalidProjectPath() {
        let args = ParseBatchArguments(projectPath: "/nonexistent/path")

        XCTAssertThrowsError(
            try ParseBatchConfig.from(projectPath: "/nonexistent/path", args: args)
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("not found"))
        }
    }

    func testParseBatchConfig_MissingProjectMd() throws {
        // Create temp directory without PROJECT.md
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-project-md-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let args = ParseBatchArguments(projectPath: tempDir.path)

        XCTAssertThrowsError(
            try ParseBatchConfig.from(projectPath: tempDir.path, args: args)
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("PROJECT.md not found"))
        }
    }
}

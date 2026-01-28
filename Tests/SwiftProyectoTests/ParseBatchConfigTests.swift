import XCTest
@testable import SwiftProyecto

final class ParseBatchConfigTests: XCTestCase {

    var testProjectPath: String!

    override func setUp() {
        super.setUp()

        // Use podcast-meditations project as test fixture
        // Hardcoded for now - can be made relative later if needed
        testProjectPath = "/Users/stovak/Projects/podcast-meditations"
    }

    // MARK: - ParseBatchConfig Creation Tests

    func testParseBatchConfig_FromProjectPath() throws {
        // Skip if podcast-meditations doesn't exist
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        let args = ParseBatchArguments(
            projectPath: testProjectPath,
            format: "m4a"
        )

        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: args)

        // Verify PROJECT.md metadata was parsed
        XCTAssertEqual(config.title, "Podcast Meditations: Mindfulness and Self-Care")
        XCTAssertEqual(config.author, "Tom Stovall")
        XCTAssertEqual(config.exportFormat, "m4a")

        // Verify directory resolution
        XCTAssertEqual(config.episodesDir, "episodes")
        XCTAssertEqual(config.audioDir, "audio")
        XCTAssertTrue(config.episodesDirURL.path.hasSuffix("/episodes"))
        XCTAssertTrue(config.audioDirURL.path.hasSuffix("/audio"))

        // Verify file patterns
        XCTAssertEqual(config.filePatterns, ["*.fountain"])

        // Verify files were discovered
        XCTAssertEqual(config.discoveredFiles.count, 365)
    }

    func testParseBatchConfig_CLIOverrides() throws {
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        let args = ParseBatchArguments(
            projectPath: testProjectPath,
            output: "custom-output",
            format: "mp3",
            skipExisting: true,
            resumeFrom: 10,
            regenerate: false,
            verbose: true
        )

        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: args)

        // CLI overrides should take precedence
        XCTAssertEqual(config.audioDir, "custom-output")
        XCTAssertEqual(config.exportFormat, "mp3")
        XCTAssertTrue(config.skipExisting)
        XCTAssertEqual(config.resumeFrom, 10)
        XCTAssertFalse(config.regenerate)
        XCTAssertTrue(config.verbose)

        // PROJECT.md defaults should be used for non-overridden fields
        XCTAssertEqual(config.episodesDir, "episodes")
    }

    func testParseBatchConfig_NoArgs() throws {
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        // Test with nil args - all defaults from PROJECT.md
        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: nil)

        XCTAssertEqual(config.episodesDir, "episodes")
        XCTAssertEqual(config.audioDir, "audio")
        XCTAssertEqual(config.exportFormat, "m4a")
        XCTAssertFalse(config.skipExisting)
        XCTAssertNil(config.resumeFrom)
        XCTAssertFalse(config.regenerate)
    }

    // MARK: - ParseFileIterator Tests

    func testParseFileIterator_BasicIteration() throws {
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: nil)
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
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: nil)
        var iterator = config.makeIterator()

        var count = 0
        while let args = iterator.next() {
            count += 1

            // Validate each ParseCommandArguments
            XCTAssertNotNil(args.episodeFileURL)
            XCTAssertNotNil(args.outputURL)
            XCTAssertFalse(args.exportFormat.isEmpty)
        }

        XCTAssertEqual(count, 365, "Should iterate through all 365 episode files")
        XCTAssertEqual(iterator.currentFileIndex, 365)
    }

    func testParseFileIterator_Collect() throws {
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: nil)
        var iterator = config.makeIterator()

        let allArgs = iterator.collect()

        XCTAssertEqual(allArgs.count, 365)

        // Verify sorted order
        for i in 0..<allArgs.count - 1 {
            let current = allArgs[i].episodeFileURL.lastPathComponent
            let next = allArgs[i + 1].episodeFileURL.lastPathComponent
            XCTAssertLessThan(current, next, "Files should be sorted alphabetically")
        }
    }

    func testParseFileIterator_ResumeFrom() throws {
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        let args = ParseBatchArguments(
            projectPath: testProjectPath,
            resumeFrom: 10
        )

        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: args)
        var iterator = config.makeIterator()

        var count = 0
        while iterator.next() != nil {
            count += 1
        }

        // Should process 365 - 9 = 356 files (resumeFrom 10 means skip first 9)
        XCTAssertEqual(count, 356)
    }

    func testParseFileIterator_ResumeFromEdgeCases() throws {
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        // Resume from 1 should process all files
        let args1 = ParseBatchArguments(projectPath: testProjectPath, resumeFrom: 1)
        let config1 = try ParseBatchConfig.from(projectPath: testProjectPath, args: args1)
        var iterator1 = config1.makeIterator()
        XCTAssertEqual(iterator1.collect().count, 365)

        // Resume from beyond total should yield no files
        let args2 = ParseBatchArguments(projectPath: testProjectPath, resumeFrom: 500)
        let config2 = try ParseBatchConfig.from(projectPath: testProjectPath, args: args2)
        var iterator2 = config2.makeIterator()
        XCTAssertEqual(iterator2.collect().count, 0)
    }

    // MARK: - ParseCommandArguments Validation Tests

    func testParseCommandArguments_KnownValues() throws {
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: nil)
        var iterator = config.makeIterator()

        // Get first episode (001_january_01.fountain)
        guard let firstArgs = iterator.next() else {
            XCTFail("Should have at least one file")
            return
        }

        // Verify known values for first episode
        XCTAssertTrue(firstArgs.episodeFileURL.lastPathComponent == "001_january_01.fountain")
        XCTAssertTrue(firstArgs.outputURL.lastPathComponent == "001_january_01.m4a")
        XCTAssertEqual(firstArgs.exportFormat, "m4a")
        XCTAssertNil(firstArgs.castListURL)
        XCTAssertFalse(firstArgs.useCastList)
        XCTAssertFalse(firstArgs.verbose)
        XCTAssertFalse(firstArgs.quiet)
        XCTAssertFalse(firstArgs.dryRun)
    }

    func testParseCommandArguments_WithCastList() throws {
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        let castListPath = "/tmp/cast-list.json"
        let args = ParseBatchArguments(
            projectPath: testProjectPath,
            useCastList: true,
            castListPath: castListPath
        )

        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: args)
        var iterator = config.makeIterator()

        guard let firstArgs = iterator.next() else {
            XCTFail("Should have at least one file")
            return
        }

        XCTAssertTrue(firstArgs.useCastList)
        XCTAssertEqual(firstArgs.castListURL?.path, castListPath)
    }

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
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        // Create a temporary audio output directory
        let tempAudioDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audio-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempAudioDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempAudioDir) }

        let args = ParseBatchArguments(
            projectPath: testProjectPath,
            output: tempAudioDir.path,
            skipExisting: true
        )

        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: args)
        var iterator = config.makeIterator()

        // Create a fake output file for the first episode
        guard let firstArgs = iterator.next() else {
            XCTFail("Should have at least one file")
            return
        }

        try "fake audio".write(to: firstArgs.outputURL, atomically: true, encoding: .utf8)

        // Reset iterator to test skipExisting behavior
        iterator = config.makeIterator()

        // First file should be skipped since it exists
        guard let afterSkip = iterator.next() else {
            XCTFail("Should have next file after skipping first")
            return
        }

        // Should be second file, not first
        XCTAssertNotEqual(afterSkip.episodeFileURL.lastPathComponent, "001_january_01.fountain")
    }

    func testParseFileIterator_RegenerateOverridesSkipExisting() throws {
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        let tempAudioDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audio-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempAudioDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempAudioDir) }

        let args = ParseBatchArguments(
            projectPath: testProjectPath,
            output: tempAudioDir.path,
            skipExisting: true,
            regenerate: true  // Should override skipExisting
        )

        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: args)
        var iterator = config.makeIterator()

        // Create fake output file
        guard let firstArgs = iterator.next() else {
            XCTFail("Should have at least one file")
            return
        }

        try "fake audio".write(to: firstArgs.outputURL, atomically: true, encoding: .utf8)

        // Reset iterator
        iterator = config.makeIterator()

        // With regenerate, should NOT skip existing file
        guard let afterRegenerate = iterator.next() else {
            XCTFail("Should have first file with regenerate")
            return
        }

        // Should still be first file (not skipped)
        XCTAssertEqual(afterRegenerate.episodeFileURL.lastPathComponent, "001_january_01.fountain")
    }

    // MARK: - Configuration Priority Tests

    func testConfigurationPriority_CLIOverridesProjectMd() throws {
        guard FileManager.default.fileExists(atPath: testProjectPath) else {
            throw XCTSkip("Test project not found at \(testProjectPath ?? "nil")")
        }

        // PROJECT.md has: audioDir: "audio", exportFormat: "m4a"
        // CLI overrides both
        let args = ParseBatchArguments(
            projectPath: testProjectPath,
            output: "cli-override-audio",
            format: "mp3"
        )

        let config = try ParseBatchConfig.from(projectPath: testProjectPath, args: args)

        XCTAssertEqual(config.audioDir, "cli-override-audio", "CLI should override PROJECT.md audioDir")
        XCTAssertEqual(config.exportFormat, "mp3", "CLI should override PROJECT.md exportFormat")

        // Non-overridden field should use PROJECT.md value
        XCTAssertEqual(config.episodesDir, "episodes", "Should use PROJECT.md episodesDir")
    }

    // MARK: - Error Handling Tests

    func testParseBatchConfig_InvalidProjectPath() {
        let args = ParseBatchArguments(projectPath: "/nonexistent/path")

        XCTAssertThrowsError(try ParseBatchConfig.from(projectPath: "/nonexistent/path", args: args)) { error in
            XCTAssertTrue(error.localizedDescription.contains("not found"))
        }
    }

    func testParseBatchConfig_MissingProjectMd() throws {
        // Create temp directory without PROJECT.md
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-project-md-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let args = ParseBatchArguments(projectPath: tempDir.path)

        XCTAssertThrowsError(try ParseBatchConfig.from(projectPath: tempDir.path, args: args)) { error in
            XCTAssertTrue(error.localizedDescription.contains("PROJECT.md not found"))
        }
    }
}

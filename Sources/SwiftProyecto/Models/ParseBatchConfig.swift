//
//  ParseBatchConfig.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import Foundation

/// Batch configuration for audio generation, combining PROJECT.md metadata with CLI overrides.
/// Contains discovered files and provides an iterator to yield ParseCommandArguments for each file.
public struct ParseBatchConfig: Sendable, Codable, Equatable {
    // MARK: - Project Metadata

    /// Project title (from PROJECT.md)
    public var title: String

    /// Project author (from PROJECT.md)
    public var author: String

    // MARK: - Directory Configuration

    /// Absolute URL to project root
    public var projectURL: URL

    /// Relative path to episodes directory (from PROJECT.md or default "episodes")
    public var episodesDir: String

    /// Absolute URL to episodes directory
    public var episodesDirURL: URL

    /// Relative path to audio output directory (from PROJECT.md or default "audio")
    public var audioDir: String

    /// Absolute URL to audio output directory
    public var audioDirURL: URL

    // MARK: - File Discovery

    /// File patterns for discovering episode files
    /// Supports glob patterns (*.fountain) or explicit file names
    public var filePatterns: [String]

    /// Discovered episode files (absolute URLs)
    public var discoveredFiles: [URL]

    /// Audio export format (m4a, mp3, wav, etc.)
    public var exportFormat: String

    // MARK: - Hooks

    /// Shell command to run before generation (optional)
    public var preGenerateHook: String?

    /// Shell command to run after generation (optional)
    public var postGenerateHook: String?

    // MARK: - CLI Overrides (from ParseBatchArguments)

    /// Skip existing audio files
    public var skipExisting: Bool

    /// Resume from episode number
    public var resumeFrom: Int?

    /// Regenerate existing audio files (ignores skipExisting)
    public var regenerate: Bool

    /// Skip pre/post generation hooks
    public var skipHooks: Bool

    /// Use cast list for voice mappings
    public var useCastList: Bool

    /// Explicit cast list file path
    public var castListPath: String?

    /// Dry run - show what would be generated
    public var dryRun: Bool

    /// Verbose output
    public var verbose: Bool

    /// Quiet mode
    public var quiet: Bool

    /// Initialize with all configuration
    public init(
        title: String,
        author: String,
        projectURL: URL,
        episodesDir: String = "episodes",
        audioDir: String = "audio",
        filePatterns: [String] = ["*.fountain"],
        discoveredFiles: [URL] = [],
        exportFormat: String = "m4a",
        preGenerateHook: String? = nil,
        postGenerateHook: String? = nil,
        skipExisting: Bool = false,
        resumeFrom: Int? = nil,
        regenerate: Bool = false,
        skipHooks: Bool = false,
        useCastList: Bool = false,
        castListPath: String? = nil,
        dryRun: Bool = false,
        verbose: Bool = false,
        quiet: Bool = false
    ) {
        self.title = title
        self.author = author
        self.projectURL = projectURL
        self.episodesDir = episodesDir
        self.episodesDirURL = projectURL.appendingPathComponent(episodesDir)
        self.audioDir = audioDir
        self.audioDirURL = projectURL.appendingPathComponent(audioDir)
        self.filePatterns = filePatterns
        self.discoveredFiles = discoveredFiles
        self.exportFormat = exportFormat
        self.preGenerateHook = preGenerateHook
        self.postGenerateHook = postGenerateHook
        self.skipExisting = skipExisting
        self.resumeFrom = resumeFrom
        self.regenerate = regenerate
        self.skipHooks = skipHooks
        self.useCastList = useCastList
        self.castListPath = castListPath
        self.dryRun = dryRun
        self.verbose = verbose
        self.quiet = quiet
    }
}

// MARK: - Convenience

extension ParseBatchConfig {
    /// Should run pre-generate hook
    public var shouldRunPreGenerateHook: Bool {
        preGenerateHook != nil && !skipHooks
    }

    /// Should run post-generate hook
    public var shouldRunPostGenerateHook: Bool {
        postGenerateHook != nil && !skipHooks
    }

    /// Should skip an existing file
    public func shouldSkip(existingFile: URL) -> Bool {
        skipExisting && !regenerate && FileManager.default.fileExists(atPath: existingFile.path)
    }

    /// Cast list URL if specified
    public var castListURL: URL? {
        guard let path = castListPath else { return nil }
        let expandedPath = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expandedPath).standardizedFileURL
    }

    /// Create an iterator to yield ParseCommandArguments for each file
    public func makeIterator() -> ParseFileIterator {
        ParseFileIterator(batchConfig: self)
    }
}

//
//  ParseCommandArguments.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import Foundation

/// Command-line arguments for generating audio from a SINGLE screenplay file.
/// This is what the `generate` command accepts for per-file audio generation.
///
/// For batch generation from PROJECT.md, see ParseBatchArguments and ParseBatchConfig.
public struct ParseCommandArguments: Sendable, Codable, Equatable {
    /// Input screenplay file URL (absolute path)
    public var episodeFileURL: URL

    /// Output audio file URL (absolute path)
    public var outputURL: URL

    /// Audio export format (m4a, mp3, wav, etc.)
    public var exportFormat: String

    /// Optional cast list file URL (absolute path)
    public var castListURL: URL?

    /// Use cast list for voice mappings
    public var useCastList: Bool

    /// Verbose output
    public var verbose: Bool

    /// Quiet mode - minimal output
    public var quiet: Bool

    /// Dry run - show what would be generated
    public var dryRun: Bool

    /// Initialize with all arguments
    public init(
        episodeFileURL: URL,
        outputURL: URL,
        exportFormat: String = "m4a",
        castListURL: URL? = nil,
        useCastList: Bool = false,
        verbose: Bool = false,
        quiet: Bool = false,
        dryRun: Bool = false
    ) {
        self.episodeFileURL = episodeFileURL
        self.outputURL = outputURL
        self.exportFormat = exportFormat
        self.castListURL = castListURL
        self.useCastList = useCastList
        self.verbose = verbose
        self.quiet = quiet
        self.dryRun = dryRun
    }
}

// MARK: - Convenience

extension ParseCommandArguments {
    /// Expected output filename based on input file
    public var expectedOutputFilename: String {
        let inputFilename = episodeFileURL.deletingPathExtension().lastPathComponent
        return "\(inputFilename).\(exportFormat)"
    }

    /// Check if output file already exists
    public var outputExists: Bool {
        FileManager.default.fileExists(atPath: outputURL.path)
    }

    /// Validation
    public func validate() throws {
        if verbose && quiet {
            throw ValidationError.mutuallyExclusive("verbose", "quiet")
        }

        if useCastList && castListURL == nil {
            throw ValidationError.missingCastList
        }

        if !FileManager.default.fileExists(atPath: episodeFileURL.path) {
            throw ValidationError.episodeFileNotFound(episodeFileURL.path)
        }

        if let castListURL = castListURL, !FileManager.default.fileExists(atPath: castListURL.path) {
            throw ValidationError.castListNotFound(castListURL.path)
        }
    }

    /// Validation errors
    public enum ValidationError: LocalizedError {
        case mutuallyExclusive(String, String)
        case missingCastList
        case episodeFileNotFound(String)
        case castListNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .mutuallyExclusive(let flag1, let flag2):
                return "Cannot use --\(flag1) and --\(flag2) together"
            case .missingCastList:
                return "useCastList is true but castListURL is nil"
            case .episodeFileNotFound(let path):
                return "Episode file not found: \(path)"
            case .castListNotFound(let path):
                return "Cast list file not found: \(path)"
            }
        }
    }
}

//
//  ParseCommandArguments.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import Foundation

/// Command-line arguments for the PARSE/generate command.
/// These represent the raw arguments passed to the CLI or API.
public struct ParseCommandArguments: Sendable, Codable, Equatable {
    /// Project directory path (required)
    public var projectPath: String

    /// Output directory override (optional, -o/--output)
    public var output: String?

    /// Single episode file to process (optional, -e/--episode)
    public var episode: String?

    /// Audio format (optional, -f/--format, default: "m4a")
    public var format: String

    /// Skip existing audio files (optional, --skip-existing)
    public var skipExisting: Bool

    /// Resume from episode number (optional, --resume-from)
    public var resumeFrom: Int?

    /// Regenerate existing audio files (optional, --regenerate)
    public var regenerate: Bool

    /// Skip pre/post generation hooks (optional, --skip-hooks)
    public var skipHooks: Bool

    /// Use cast list for voice mappings (optional, --use-cast-list)
    public var useCastList: Bool

    /// Explicit cast list file path (optional, -c/--cast-list)
    public var castListPath: String?

    /// Dry run - show what would be generated (optional, --dry-run)
    public var dryRun: Bool

    /// Fail fast - stop on first error (optional, --fail-fast)
    public var failFast: Bool

    /// Verbose output (optional, --verbose)
    public var verbose: Bool

    /// Quiet mode - minimal output (optional, --quiet)
    public var quiet: Bool

    /// JSON output format (optional, --json)
    public var jsonOutput: Bool

    /// Initialize with all arguments
    public init(
        projectPath: String,
        output: String? = nil,
        episode: String? = nil,
        format: String = "m4a",
        skipExisting: Bool = false,
        resumeFrom: Int? = nil,
        regenerate: Bool = false,
        skipHooks: Bool = false,
        useCastList: Bool = false,
        castListPath: String? = nil,
        dryRun: Bool = false,
        failFast: Bool = false,
        verbose: Bool = false,
        quiet: Bool = false,
        jsonOutput: Bool = false
    ) {
        self.projectPath = projectPath
        self.output = output
        self.episode = episode
        self.format = format
        self.skipExisting = skipExisting
        self.resumeFrom = resumeFrom
        self.regenerate = regenerate
        self.skipHooks = skipHooks
        self.useCastList = useCastList
        self.castListPath = castListPath
        self.dryRun = dryRun
        self.failFast = failFast
        self.verbose = verbose
        self.quiet = quiet
        self.jsonOutput = jsonOutput
    }
}

// MARK: - Convenience

extension ParseCommandArguments {
    /// Resolved absolute project URL
    public var projectURL: URL {
        let path = (projectPath as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path).standardizedFileURL
    }

    /// Check if arguments are mutually exclusive
    public func validate() throws {
        if verbose && quiet {
            throw ValidationError.mutuallyExclusive("verbose", "quiet")
        }

        if skipExisting && regenerate {
            throw ValidationError.mutuallyExclusive("skip-existing", "regenerate")
        }

        if useCastList && castListPath != nil {
            throw ValidationError.mutuallyExclusive("use-cast-list", "cast-list")
        }
    }

    /// Validation errors
    public enum ValidationError: LocalizedError {
        case mutuallyExclusive(String, String)

        public var errorDescription: String? {
            switch self {
            case .mutuallyExclusive(let flag1, let flag2):
                return "Cannot use --\(flag1) and --\(flag2) together"
            }
        }
    }
}

//
//  ParseFileIterator.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import Foundation

/// Iterator that yields ParseCommandArguments for each discovered episode file.
/// Applies batch-level filters (skipExisting, resumeFrom) and generates per-file arguments.
public struct ParseFileIterator: IteratorProtocol, Sequence {
    private let batchConfig: ParseBatchConfig
    private var currentIndex: Int = 0
    private let filesToProcess: [URL]

    /// Initialize iterator from batch configuration
    public init(batchConfig: ParseBatchConfig) {
        self.batchConfig = batchConfig

        // Apply resumeFrom filter
        var files = batchConfig.discoveredFiles
        if let resumeFrom = batchConfig.resumeFrom, resumeFrom > 0 {
            let startIndex = Swift.min(resumeFrom - 1, files.count)
            files = Array(files.dropFirst(startIndex))
        }

        self.filesToProcess = files
    }

    /// Yield next ParseCommandArguments
    public mutating func next() -> ParseCommandArguments? {
        guard currentIndex < filesToProcess.count else {
            return nil
        }

        let episodeFileURL = filesToProcess[currentIndex]
        currentIndex += 1

        // Generate output URL
        let inputFilename = episodeFileURL.deletingPathExtension().lastPathComponent
        let outputFilename = "\(inputFilename).\(batchConfig.exportFormat)"
        let outputURL = batchConfig.audioDirURL.appendingPathComponent(outputFilename)

        // Check if should skip existing
        if batchConfig.shouldSkip(existingFile: outputURL) {
            // Skip this file, recurse to next
            return next()
        }

        // Build ParseCommandArguments
        let args = ParseCommandArguments(
            episodeFileURL: episodeFileURL,
            outputURL: outputURL,
            exportFormat: batchConfig.exportFormat,
            castListURL: batchConfig.castListURL,
            useCastList: batchConfig.useCastList,
            verbose: batchConfig.verbose,
            quiet: batchConfig.quiet,
            dryRun: batchConfig.dryRun
        )

        return args
    }
}

// MARK: - Convenience

extension ParseFileIterator {
    /// Total number of files to process (after resumeFrom filter)
    public var totalCount: Int {
        filesToProcess.count
    }

    /// Current file index (0-based)
    public var currentFileIndex: Int {
        currentIndex
    }

    /// Create an array of all ParseCommandArguments (consumes iterator)
    public mutating func collect() -> [ParseCommandArguments] {
        var results: [ParseCommandArguments] = []
        while let args = next() {
            results.append(args)
        }
        return results
    }
}

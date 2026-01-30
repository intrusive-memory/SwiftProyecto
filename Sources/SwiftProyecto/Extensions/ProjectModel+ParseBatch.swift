//
//  ProjectModel+ParseBatch.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import Foundation

extension ProjectModel {
    /// Create a ParseBatchConfig from this project, reading PROJECT.md and applying CLI overrides
    ///
    /// - Parameter args: Command-line arguments (optional, uses defaults if nil)
    /// - Returns: Fully resolved ParseBatchConfig ready for batch generation
    /// - Throws: If project path is not set, PROJECT.md doesn't exist, or is invalid
    public func parseBatchConfig(with args: ParseBatchArguments? = nil) throws -> ParseBatchConfig {
        // Get project root URL from sourceRootURL
        let projectURL = URL(string: sourceRootURL)?.standardizedFileURL
        guard let projectURL = projectURL else {
            throw ParseBatchConfigError.invalidProjectPath(sourceRootURL)
        }

        // Read PROJECT.md to get generation config
        let projectMdURL = projectURL.appendingPathComponent("PROJECT.md")
        guard FileManager.default.fileExists(atPath: projectMdURL.path) else {
            throw ParseBatchConfigError.projectMdNotFound(projectMdURL.path)
        }

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(fileURL: projectMdURL)

        // Resolve directories with CLI overrides taking precedence
        let episodesDir = frontMatter.resolvedEpisodesDir
        let audioDir: String
        if let output = args?.output {
            audioDir = output
        } else {
            audioDir = frontMatter.resolvedAudioDir
        }

        // Resolve export format with CLI override
        let exportFormat: String
        if let format = args?.format {
            exportFormat = format
        } else {
            exportFormat = frontMatter.resolvedExportFormat
        }

        // Normalize file patterns
        let filePatterns = frontMatter.resolvedFilePatterns

        // Build ParseBatchConfig
        var config = ParseBatchConfig(
            title: frontMatter.title,
            author: frontMatter.author,
            projectURL: projectURL,
            episodesDir: episodesDir,
            audioDir: audioDir,
            filePatterns: filePatterns,
            exportFormat: exportFormat,
            preGenerateHook: frontMatter.preGenerateHook,
            postGenerateHook: frontMatter.postGenerateHook,
            skipExisting: args?.skipExisting ?? false,
            resumeFrom: args?.resumeFrom,
            regenerate: args?.regenerate ?? false,
            skipHooks: args?.skipHooks ?? false,
            useCastList: args?.useCastList ?? false,
            castListPath: args?.castListPath,
            dryRun: args?.dryRun ?? false,
            verbose: args?.verbose ?? false,
            quiet: args?.quiet ?? false
        )

        // Discover files
        config.discoveredFiles = try discoverFiles(in: config.episodesDirURL, patterns: config.filePatterns)

        return config
    }

    /// Discover episode files based on patterns
    private func discoverFiles(in directory: URL, patterns: [String]) throws -> [URL] {
        var discovered: [URL] = []

        for pattern in patterns {
            if isGlobPattern(pattern) {
                // Use glob matching
                let matches = try glob(pattern: pattern, in: directory)
                discovered.append(contentsOf: matches)
            } else {
                // Explicit filename
                let fileURL = directory.appendingPathComponent(pattern)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    discovered.append(fileURL)
                }
            }
        }

        // Remove duplicates, sort naturally
        let unique = Array(Set(discovered))
        return unique.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func isGlobPattern(_ pattern: String) -> Bool {
        pattern.contains("*") || pattern.contains("?")
    }

    private func glob(pattern: String, in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var matches: [URL] = []
        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues?.isRegularFile == true {
                if matchesPattern(fileURL.lastPathComponent, pattern: pattern) {
                    matches.append(fileURL)
                }
            }
        }
        return matches
    }

    private func matchesPattern(_ filename: String, pattern: String) -> Bool {
        // Simple glob matching (*.fountain, *.fdx, etc.)
        if pattern.hasPrefix("*") && pattern.filter({ $0 == "*" }).count == 1 {
            let suffix = String(pattern.dropFirst())
            return filename.hasSuffix(suffix)
        }
        return filename == pattern
    }
}

// MARK: - Convenience Factory

extension ParseBatchConfig {
    /// Create a ParseBatchConfig from a project directory path, parsing PROJECT.md directly
    ///
    /// This is useful when you don't have a ProjectModel instance but just a path.
    ///
    /// - Parameters:
    ///   - projectPath: Path to project directory containing PROJECT.md
    ///   - args: Command-line arguments (optional)
    /// - Returns: Fully resolved ParseBatchConfig
    /// - Throws: If PROJECT.md doesn't exist or is invalid
    public static func from(projectPath: String, args: ParseBatchArguments? = nil) throws -> ParseBatchConfig {
        let expandedPath = (projectPath as NSString).expandingTildeInPath
        let projectURL = URL(fileURLWithPath: expandedPath).standardizedFileURL

        let projectMdURL = projectURL.appendingPathComponent("PROJECT.md")
        guard FileManager.default.fileExists(atPath: projectMdURL.path) else {
            throw ParseBatchConfigError.projectMdNotFound(projectMdURL.path)
        }

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(fileURL: projectMdURL)

        // Resolve directories with CLI overrides taking precedence
        let episodesDir = frontMatter.resolvedEpisodesDir
        let audioDir: String
        if let output = args?.output {
            audioDir = output
        } else {
            audioDir = frontMatter.resolvedAudioDir
        }

        // Resolve export format with CLI override
        let exportFormat: String
        if let format = args?.format {
            exportFormat = format
        } else {
            exportFormat = frontMatter.resolvedExportFormat
        }

        // Normalize file patterns
        let filePatterns = frontMatter.resolvedFilePatterns

        // Build ParseBatchConfig
        var config = ParseBatchConfig(
            title: frontMatter.title,
            author: frontMatter.author,
            projectURL: projectURL,
            episodesDir: episodesDir,
            audioDir: audioDir,
            filePatterns: filePatterns,
            exportFormat: exportFormat,
            preGenerateHook: frontMatter.preGenerateHook,
            postGenerateHook: frontMatter.postGenerateHook,
            skipExisting: args?.skipExisting ?? false,
            resumeFrom: args?.resumeFrom,
            regenerate: args?.regenerate ?? false,
            skipHooks: args?.skipHooks ?? false,
            useCastList: args?.useCastList ?? false,
            castListPath: args?.castListPath,
            dryRun: args?.dryRun ?? false,
            verbose: args?.verbose ?? false,
            quiet: args?.quiet ?? false
        )

        // Discover files
        config.discoveredFiles = try discoverFiles(in: config.episodesDirURL, patterns: config.filePatterns)

        return config
    }

    /// Discover episode files based on patterns
    private static func discoverFiles(in directory: URL, patterns: [String]) throws -> [URL] {
        var discovered: [URL] = []

        for pattern in patterns {
            if isGlobPattern(pattern) {
                // Use glob matching
                let matches = try glob(pattern: pattern, in: directory)
                discovered.append(contentsOf: matches)
            } else {
                // Explicit filename
                let fileURL = directory.appendingPathComponent(pattern)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    discovered.append(fileURL)
                }
            }
        }

        // Remove duplicates, sort naturally
        let unique = Array(Set(discovered))
        return unique.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private static func isGlobPattern(_ pattern: String) -> Bool {
        pattern.contains("*") || pattern.contains("?")
    }

    private static func glob(pattern: String, in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var matches: [URL] = []
        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues?.isRegularFile == true {
                if matchesPattern(fileURL.lastPathComponent, pattern: pattern) {
                    matches.append(fileURL)
                }
            }
        }
        return matches
    }

    private static func matchesPattern(_ filename: String, pattern: String) -> Bool {
        // Simple glob matching (*.fountain, *.fdx, etc.)
        if pattern.hasPrefix("*") && pattern.filter({ $0 == "*" }).count == 1 {
            let suffix = String(pattern.dropFirst())
            return filename.hasSuffix(suffix)
        }
        return filename == pattern
    }
}

// MARK: - Errors

public enum ParseBatchConfigError: LocalizedError {
    case invalidProjectPath(String)
    case projectMdNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidProjectPath(let path):
            return "Invalid project path: \(path)"
        case .projectMdNotFound(let path):
            return "PROJECT.md not found at: \(path)"
        }
    }
}

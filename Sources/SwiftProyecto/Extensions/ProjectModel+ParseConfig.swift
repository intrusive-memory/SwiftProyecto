//
//  ProjectModel+ParseConfig.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import Foundation

extension ProjectModel {
    /// Create a ParseConfig from this project, reading PROJECT.md and applying CLI overrides
    ///
    /// - Parameter args: Command-line arguments (optional, uses defaults if nil)
    /// - Returns: Fully resolved ParseConfig ready for generation
    /// - Throws: If project path is not set, PROJECT.md doesn't exist, or is invalid
    public func parseConfig(with args: ParseCommandArguments? = nil) throws -> ParseConfig {
        // Get project root URL from sourceRootURL
        let projectURL = URL(string: sourceRootURL)?.standardizedFileURL
        guard let projectURL = projectURL else {
            throw ParseConfigError.invalidProjectPath(sourceRootURL)
        }

        // Read PROJECT.md to get generation config
        let projectMdURL = projectURL.appendingPathComponent("PROJECT.md")
        guard FileManager.default.fileExists(atPath: projectMdURL.path) else {
            throw ParseConfigError.projectMdNotFound(projectMdURL.path)
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

        // Build ParseConfig
        return ParseConfig(
            title: frontMatter.title,
            author: frontMatter.author,
            projectURL: projectURL,
            episodesDir: episodesDir,
            audioDir: audioDir,
            filePatterns: filePatterns,
            exportFormat: exportFormat,
            preGenerateHook: frontMatter.preGenerateHook,
            postGenerateHook: frontMatter.postGenerateHook,
            singleEpisode: args?.episode,
            skipExisting: args?.skipExisting ?? false,
            resumeFrom: args?.resumeFrom,
            regenerate: args?.regenerate ?? false,
            skipHooks: args?.skipHooks ?? false,
            useCastList: args?.useCastList ?? false,
            castListPath: args?.castListPath,
            dryRun: args?.dryRun ?? false,
            failFast: args?.failFast ?? false,
            verbose: args?.verbose ?? false,
            quiet: args?.quiet ?? false,
            jsonOutput: args?.jsonOutput ?? false
        )
    }
}

// MARK: - Convenience Factory

extension ParseConfig {
    /// Create a ParseConfig from a project directory path, parsing PROJECT.md directly
    ///
    /// This is useful when you don't have a ProjectModel instance but just a path.
    ///
    /// - Parameters:
    ///   - projectPath: Path to project directory containing PROJECT.md
    ///   - args: Command-line arguments (optional)
    /// - Returns: Fully resolved ParseConfig
    /// - Throws: If PROJECT.md doesn't exist or is invalid
    public static func from(projectPath: String, args: ParseCommandArguments? = nil) throws -> ParseConfig {
        let expandedPath = (projectPath as NSString).expandingTildeInPath
        let projectURL = URL(fileURLWithPath: expandedPath).standardizedFileURL

        let projectMdURL = projectURL.appendingPathComponent("PROJECT.md")
        guard FileManager.default.fileExists(atPath: projectMdURL.path) else {
            throw ParseConfigError.projectMdNotFound(projectMdURL.path)
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

        // Build ParseConfig
        return ParseConfig(
            title: frontMatter.title,
            author: frontMatter.author,
            projectURL: projectURL,
            episodesDir: episodesDir,
            audioDir: audioDir,
            filePatterns: filePatterns,
            exportFormat: exportFormat,
            preGenerateHook: frontMatter.preGenerateHook,
            postGenerateHook: frontMatter.postGenerateHook,
            singleEpisode: args?.episode,
            skipExisting: args?.skipExisting ?? false,
            resumeFrom: args?.resumeFrom,
            regenerate: args?.regenerate ?? false,
            skipHooks: args?.skipHooks ?? false,
            useCastList: args?.useCastList ?? false,
            castListPath: args?.castListPath,
            dryRun: args?.dryRun ?? false,
            failFast: args?.failFast ?? false,
            verbose: args?.verbose ?? false,
            quiet: args?.quiet ?? false,
            jsonOutput: args?.jsonOutput ?? false
        )
    }
}

// MARK: - Errors

public enum ParseConfigError: LocalizedError {
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

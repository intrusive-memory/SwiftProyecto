//
//  DirectoryContext.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import Foundation
import SwiftCompartido

/// Context information gathered from analyzing a directory.
/// This is collected once and reused across all LLM queries.
struct DirectoryContext: Sendable {
    let directoryName: String
    let directoryPath: String
    let fileList: String
    let readmeExcerpt: String?
    let gitAuthor: String?
    let structure: String
    let fileCount: Int
    let detectedPatterns: [String]
    let screenplayFileCount: Int
}

/// Analyzes a directory and gathers context for LLM queries.
struct DirectoryAnalyzer {

    func analyze(_ directory: URL) async throws -> DirectoryContext {
        // Perform file system operations synchronously (local operation)
        let context = try gatherFileSystemContext(directory)

        // Perform git operations asynchronously (may involve process execution)
        let gitAuthor = try? await getGitAuthor(in: directory)

        return DirectoryContext(
            directoryName: context.directoryName,
            directoryPath: context.directoryPath,
            fileList: context.fileList,
            readmeExcerpt: context.readmeExcerpt,
            gitAuthor: gitAuthor,
            structure: context.structure,
            fileCount: context.fileCount,
            detectedPatterns: context.detectedPatterns,
            screenplayFileCount: context.screenplayFileCount
        )
    }

    private func gatherFileSystemContext(_ directory: URL) throws -> DirectoryContext {
        let fileManager = FileManager.default
        let folderName = directory.lastPathComponent

        // Gather file information
        var files: [String] = []
        var detectedExtensions: Set<String> = []
        var screenplayFileCount = 0

        if let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let relativePath = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")

                // Skip common build/cache directories
                let skipDirs = [".build", ".git", ".cache", "DerivedData", "node_modules", ".swiftpm"]
                if skipDirs.contains(where: { relativePath.hasPrefix($0) }) {
                    continue
                }

                // Skip PROJECT.md itself
                if relativePath == "PROJECT.md" {
                    continue
                }

                let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues?.isRegularFile == true {
                    files.append(relativePath)
                    let ext = fileURL.pathExtension.lowercased()
                    if !ext.isEmpty {
                        detectedExtensions.insert(ext)
                    }

                    // Count screenplay files using SwiftCompartido's supported extensions
                    // Note: We use supportedScreenplayExtensions (not supportedFileExtensions)
                    // to exclude platform-specific formats (PDF, Pandoc) from directory analysis
                    let screenplayExtensions = GuionParsedElementCollection.supportedScreenplayExtensions
                    if screenplayExtensions.contains(ext) {
                        screenplayFileCount += 1
                    } else if ext == "md" {
                        // Only count .md files NOT in root directory
                        if relativePath.contains("/") {
                            screenplayFileCount += 1
                        }
                    }
                }
            }
        }

        // Build file listing (limit to first 50 files for context)
        let limitedFiles = Array(files.prefix(50))
        let fileList = limitedFiles.joined(separator: "\n")
        let fileCount = files.count

        // Detect file patterns
        var patterns: [String] = []
        // Include all screenplay extensions plus audio formats and text
        let interestingExtensions = GuionParsedElementCollection.supportedScreenplayExtensions
            + ["txt", "mp3", "m4a", "wav", "aif"]
        for ext in interestingExtensions where detectedExtensions.contains(ext) {
            patterns.append("*.\(ext)")
        }

        // Read README.md if it exists
        var readmeContent: String?
        let readmeURL = directory.appendingPathComponent("README.md")
        if fileManager.fileExists(atPath: readmeURL.path) {
            readmeContent = try? String(contentsOf: readmeURL, encoding: .utf8)
            // Limit README content
            if let content = readmeContent, content.count > 2000 {
                readmeContent = String(content.prefix(2000)) + "\n... (truncated)"
            }
        }

        // Build structure summary
        let structure = buildStructureSummary(files: files)

        return DirectoryContext(
            directoryName: folderName,
            directoryPath: directory.path,
            fileList: fileList,
            readmeExcerpt: readmeContent,
            gitAuthor: nil,  // Will be set in analyze()
            structure: structure,
            fileCount: fileCount,
            detectedPatterns: patterns,
            screenplayFileCount: screenplayFileCount
        )
    }

    private func getGitAuthor(in directory: URL) async throws -> String? {
        let process = Process()
        process.currentDirectoryURL = directory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["config", "user.name"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        let author = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return author.isEmpty ? nil : author
    }

    private func buildStructureSummary(files: [String]) -> String {
        var directories = Set<String>()

        for file in files {
            let components = file.split(separator: "/")
            if components.count > 1 {
                directories.insert(String(components[0]))
            }
        }

        if directories.isEmpty {
            return "Flat structure (all files in root)"
        }

        return "Directories: \(directories.sorted().joined(separator: ", "))"
    }
}

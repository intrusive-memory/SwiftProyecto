//
//  ProjectDiscovery.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// Service for locating PROJECT.md files from any file or directory path.
///
/// `ProjectDiscovery` implements a search strategy that accounts for common
/// project directory structures, including the "episodes" subfolder pattern
/// used by podcast and screenplay projects.
///
/// ## Usage
///
/// ```swift
/// let discovery = ProjectDiscovery()
/// if let projectMdURL = discovery.findProjectMd(from: screenplayURL) {
///     let parser = ProjectMarkdownParser()
///     let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)
/// }
/// ```
public struct ProjectDiscovery: Sendable {

    /// Create a new ProjectDiscovery instance.
    public init() {}

    /// Find PROJECT.md file starting from a given file or directory.
    ///
    /// Searches for a PROJECT.md file using the following strategy:
    ///
    /// ## Search Order
    ///
    /// 1. If `startingFrom` is in an "episodes" folder (case-insensitive):
    ///    - Check parent directory first
    ///    - Example: `/project/episodes/script.fountain` -> `/project/PROJECT.md`
    ///
    /// 2. Check current directory:
    ///    - `/project/script.fountain` -> `/project/PROJECT.md`
    ///
    /// 3. Check parent directory (fallback):
    ///    - `/project/subdirectory/script.fountain` -> `/project/PROJECT.md`
    ///
    /// - Parameter startingFrom: A file or directory URL to start the search from.
    ///   If a file URL is provided, the search starts from the file's containing directory.
    /// - Returns: URL to the PROJECT.md file if found, or `nil` if no PROJECT.md exists
    ///   in any of the searched locations.
    public func findProjectMd(from startingFrom: URL) -> URL? {
        let fileManager = FileManager.default

        // Determine starting directory: if startingFrom is a file, use its parent
        var isDirectory: ObjCBool = false
        let startPath = startingFrom.path
        let startingDirectory: URL

        if fileManager.fileExists(atPath: startPath, isDirectory: &isDirectory), isDirectory.boolValue {
            startingDirectory = startingFrom
        } else {
            startingDirectory = startingFrom.deletingLastPathComponent()
        }

        // Check if we are in an "episodes" folder (case-insensitive)
        let currentFolderName = startingDirectory.lastPathComponent
        if currentFolderName.lowercased() == "episodes" {
            let parentDirectory = startingDirectory.deletingLastPathComponent()
            if let found = checkDirectory(parentDirectory) {
                return found
            }
        }

        // Check current directory
        if let found = checkDirectory(startingDirectory) {
            return found
        }

        // Check parent directory (fallback)
        let parentDirectory = startingDirectory.deletingLastPathComponent()
        if parentDirectory != startingDirectory {
            if let found = checkDirectory(parentDirectory) {
                return found
            }
        }

        return nil
    }

    /// Check if a directory contains a PROJECT.md file.
    ///
    /// - Parameter directory: The directory URL to check for a PROJECT.md file.
    /// - Returns: URL to the PROJECT.md file if it exists in the directory, or `nil`.
    private func checkDirectory(_ directory: URL) -> URL? {
        let projectMdURL = directory.appendingPathComponent("PROJECT.md")
        if FileManager.default.fileExists(atPath: projectMdURL.path) {
            return projectMdURL
        }
        return nil
    }
}

// MARK: - Cast Reading

extension ProjectDiscovery {

    /// Read the cast list from a PROJECT.md file.
    ///
    /// Parses the PROJECT.md file and extracts the cast list. Optionally filters
    /// to only return cast members that have a voice assigned for a specific provider.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let discovery = ProjectDiscovery()
    /// if let projectMd = discovery.findProjectMd(from: screenplayURL) {
    ///     // Read all cast members
    ///     let allCast = try discovery.readCast(from: projectMd)
    ///
    ///     // Read only cast members with Apple voices
    ///     let appleCast = try discovery.readCast(from: projectMd, filterByProvider: "apple")
    ///
    ///     // Read only cast members with ElevenLabs voices
    ///     let elevenCast = try discovery.readCast(from: projectMd, filterByProvider: "elevenlabs")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - projectMdURL: URL to the PROJECT.md file to read cast from.
    ///   - providerID: Optional provider name to filter by. When non-nil, only cast members
    ///     whose `voices` dictionary contains a key matching this provider are returned.
    ///     The comparison is case-sensitive (provider keys are conventionally lowercase).
    /// - Returns: Array of `CastMember` objects. Returns an empty array if the PROJECT.md
    ///   has no cast section or the cast is empty.
    /// - Throws: `ProjectMarkdownParser.ParserError` if the PROJECT.md file cannot be parsed.
    public func readCast(
        from projectMdURL: URL,
        filterByProvider providerID: String? = nil
    ) throws -> [CastMember] {
        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(fileURL: projectMdURL)

        guard let cast = frontMatter.cast, !cast.isEmpty else {
            return []
        }

        guard let providerID else {
            return cast
        }

        return cast.filter { $0.voices[providerID] != nil }
    }
}

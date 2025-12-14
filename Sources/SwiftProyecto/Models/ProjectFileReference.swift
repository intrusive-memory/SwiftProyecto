//
//  ProjectFileReference.swift
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
import SwiftData

/// A reference to a screenplay file within a project.
///
/// ProjectFileReference tracks discovered files in a project folder, storing their
/// metadata and providing security-scoped access. Files are discovered during project
/// sync operations and tracked for modification detection.
///
/// ## Usage
///
/// ```swift
/// let fileRef = ProjectFileReference(
///     relativePath: "season-01/episode-01.fountain",
///     filename: "episode-01.fountain",
///     fileExtension: "fountain"
/// )
/// project.fileReferences.append(fileRef)
///
/// // Get secure URL for file access
/// let url = try projectService.getSecureURL(for: fileRef, in: project)
/// ```
///
@Model
public final class ProjectFileReference {
    /// Unique identifier
    @Attribute(.unique) public var id: UUID

    /// Relative path from project root (e.g., "season-01/episode-01.fountain")
    public var relativePath: String

    /// Filename for display (e.g., "episode-01.fountain")
    public var filename: String

    /// File extension without dot (e.g., "fountain", "fdx", "md")
    public var fileExtension: String

    /// Last known file modification date from filesystem
    /// This is updated during every sync operation to reflect current disk state
    public var lastKnownModificationDate: Date?

    /// Security-scoped bookmark data for direct file access
    /// If nil, the file URL is constructed from project bookmark + relative path
    public var bookmarkData: Data?

    /// Parent project this file belongs to
    @Relationship(inverse: \ProjectModel.fileReferences)
    public var project: ProjectModel?

    /// Create a new project file reference.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (generated if not provided)
    ///   - relativePath: Path relative to project root
    ///   - filename: Display filename
    ///   - fileExtension: File extension without dot
    ///   - lastKnownModificationDate: Optional modification date
    ///   - bookmarkData: Optional security-scoped bookmark data
    public init(
        id: UUID = UUID(),
        relativePath: String,
        filename: String,
        fileExtension: String,
        lastKnownModificationDate: Date? = nil,
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.relativePath = relativePath
        self.filename = filename
        self.fileExtension = fileExtension
        self.lastKnownModificationDate = lastKnownModificationDate
        self.bookmarkData = bookmarkData
    }
}

// MARK: - Convenience Properties

public extension ProjectFileReference {
    /// Display name with folder context for disambiguation
    ///
    /// For files in root: "episode-01.fountain"
    /// For files in subfolders: "season-01 / episode-01.fountain"
    var displayNameWithPath: String {
        let components = relativePath.split(separator: "/")
        if components.count > 1 {
            let folderPath = components.dropLast().joined(separator: " / ")
            return "\(folderPath) / \(filename)"
        }
        return filename
    }
}

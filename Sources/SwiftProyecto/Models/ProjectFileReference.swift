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
/// ProjectFileReference tracks discovered files in a project folder, tracking their
/// loading state and metadata. Files can be loaded lazily - they appear in the project
/// file list but aren't imported to SwiftData until the user requests it.
///
/// ## File States
///
/// - **notLoaded**: File exists in folder but not in SwiftData (greyed out in UI)
/// - **loading**: File is currently being parsed
/// - **loaded**: File fully imported and available (linked to GuionDocumentModel)
/// - **stale**: File modified on disk since last load
/// - **missing**: File deleted from disk but still in SwiftData
/// - **error**: File failed to load
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
    public var lastKnownModificationDate: Date?

    /// Current loading state of the file
    public var loadingState: FileLoadingState

    /// Optional error message if loadingState is .error
    public var errorMessage: String?

    /// ID of the loaded GuionDocumentModel (if loaded)
    ///
    /// This is set when the file is successfully parsed and imported to SwiftData.
    /// It's nil for unloaded files.
    ///
    /// **Note**: In Phase 2, this will become a proper @Relationship to GuionDocumentModel
    /// when SwiftCompartido is added as a dependency.
    public var loadedDocumentID: UUID?

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
    ///   - loadingState: Initial loading state (defaults to .notLoaded)
    ///   - errorMessage: Optional error message
    public init(
        id: UUID = UUID(),
        relativePath: String,
        filename: String,
        fileExtension: String,
        lastKnownModificationDate: Date? = nil,
        loadingState: FileLoadingState = .notLoaded,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.relativePath = relativePath
        self.filename = filename
        self.fileExtension = fileExtension
        self.lastKnownModificationDate = lastKnownModificationDate
        self.loadingState = loadingState
        self.errorMessage = errorMessage
    }
}

// MARK: - Convenience Properties

public extension ProjectFileReference {
    /// Whether this file is currently loaded in SwiftData
    var isLoaded: Bool {
        return loadingState == .loaded && loadedDocumentID != nil
    }

    /// Whether this file can be opened for editing
    var canOpen: Bool {
        return loadingState.canOpen && loadedDocumentID != nil
    }

    /// Whether this file can be loaded
    var canLoad: Bool {
        return loadingState.canLoad
    }

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

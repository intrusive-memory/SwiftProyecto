//
//  FileNode.swift
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

/// Represents a node in a hierarchical file tree.
///
/// FileNode provides a tree structure for displaying files in a hierarchical view.
/// It can represent either a directory (with children) or a file (leaf node).
///
/// ## Usage
///
/// ```swift
/// // Get tree from project
/// let tree = project.fileTree()
///
/// // Display in UI
/// func displayNode(_ node: FileNode, indent: Int = 0) {
///     let prefix = String(repeating: "  ", count: indent)
///
///     if node.isDirectory {
///         print("\(prefix)📁 \(node.name)/")
///         for child in node.children {
///             displayNode(child, indent: indent + 1)
///         }
///     } else {
///         print("\(prefix)📄 \(node.name)")
///     }
/// }
/// ```
///
/// ## Tree Structure
///
/// Given files:
/// - `README.md`
/// - `Season 1/Episode 1.fountain`
/// - `Season 1/Episode 2.fountain`
/// - `Season 2/Episode 1.fountain`
///
/// The tree structure is:
/// ```
/// Root (virtual)
/// ├── README.md (file)
/// ├── Season 1/ (directory)
/// │   ├── Episode 1.fountain (file)
/// │   └── Episode 2.fountain (file)
/// └── Season 2/ (directory)
///     └── Episode 1.fountain (file)
/// ```
public struct FileNode: Identifiable, Hashable, Sendable {
    /// Unique identifier
    public let id: UUID

    /// Node name (filename or directory name)
    public let name: String

    /// Full path relative to project root
    public let path: String

    /// Whether this node represents a directory
    public let isDirectory: Bool

    /// Child nodes (empty for files)
    public let children: [FileNode]

    /// ID of the associated ProjectFileReference (nil for directories)
    public let fileReferenceID: UUID?

    /// Creates a file node.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (generated if not provided)
    ///   - name: Node name (filename or directory name)
    ///   - path: Full path relative to project root
    ///   - isDirectory: Whether this is a directory node
    ///   - children: Child nodes (default empty)
    ///   - fileReferenceID: ID of associated file reference (nil for directories)
    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isDirectory: Bool,
        children: [FileNode] = [],
        fileReferenceID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
        self.fileReferenceID = fileReferenceID
    }

    // MARK: - Computed Properties

    /// Whether this is a leaf node (file)
    public var isFile: Bool {
        !isDirectory
    }

    /// Number of direct children
    public var childCount: Int {
        children.count
    }

    /// Total number of files in this subtree (excluding directories)
    public var fileCount: Int {
        if isFile {
            return 1
        }
        return children.reduce(0) { $0 + $1.fileCount }
    }

    /// Total number of nodes in this subtree (including directories)
    public var totalNodeCount: Int {
        1 + children.reduce(0) { $0 + $1.totalNodeCount }
    }

    /// Children sorted by name (directories first, then files)
    public var sortedChildren: [FileNode] {
        children.sorted { lhs, rhs in
            // Directories come before files
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            // Within same type, sort alphabetically
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Tree Navigation

    /// Finds a node by path in this subtree.
    ///
    /// - Parameter path: Path to search for
    /// - Returns: Node if found, nil otherwise
    public func findNode(atPath path: String) -> FileNode? {
        if self.path == path {
            return self
        }

        for child in children {
            if let found = child.findNode(atPath: path) {
                return found
            }
        }

        return nil
    }

    /// All file nodes in this subtree (excludes directories).
    public var allFiles: [FileNode] {
        if isFile {
            return [self]
        }

        return children.flatMap { $0.allFiles }
    }

    /// All directory nodes in this subtree.
    public var allDirectories: [FileNode] {
        if isFile {
            return []
        }

        var directories = [self]
        for child in children {
            directories.append(contentsOf: child.allDirectories)
        }
        return directories
    }

    // MARK: - Hashable & Equatable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tree Building

public extension FileNode {
    /// Builds a file tree from a flat array of file references.
    ///
    /// This method creates a hierarchical tree structure from ProjectFileReferences.
    /// Each path component becomes a directory node, and files become leaf nodes.
    ///
    /// - Parameter fileReferences: Flat array of file references
    /// - Returns: Root node containing the tree structure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let files = [
    ///     ProjectFileReference(relativePath: "README.md", ...),
    ///     ProjectFileReference(relativePath: "Season 1/Episode 1.fountain", ...),
    ///     ProjectFileReference(relativePath: "Season 1/Episode 2.fountain", ...)
    /// ]
    ///
    /// let root = FileNode.buildTree(from: files)
    /// // root.children = [README.md, Season 1/]
    /// // root.children[1].children = [Episode 1.fountain, Episode 2.fountain]
    /// ```
    static func buildTree(from fileReferences: [ProjectFileReference]) -> FileNode {
        var root = FileNode(
            name: "",
            path: "",
            isDirectory: true,
            children: []
        )

        // Build tree by inserting each file
        for fileRef in fileReferences {
            insertFile(fileRef, into: &root)
        }

        return root
    }

    /// Inserts a file reference into the tree, creating intermediate directories as needed.
    private static func insertFile(
        _ fileRef: ProjectFileReference,
        pathComponents: [String],
        fullPath: String,
        into node: inout FileNode
    ) {
        guard !pathComponents.isEmpty else { return }

        if pathComponents.count == 1 {
            // Leaf node - this is the file itself
            let fileNode = FileNode(
                name: pathComponents[0],
                path: fullPath,
                isDirectory: false,
                fileReferenceID: fileRef.id
            )

            var newChildren = node.children
            newChildren.append(fileNode)
            node = FileNode(
                id: node.id,
                name: node.name,
                path: node.path,
                isDirectory: node.isDirectory,
                children: newChildren,
                fileReferenceID: node.fileReferenceID
            )
        } else {
            // Intermediate directory
            let dirName = pathComponents[0]
            let dirPath = node.path.isEmpty ? dirName : "\(node.path)/\(dirName)"

            // Find or create directory node
            var newChildren = node.children
            if let existingIndex = newChildren.firstIndex(where: { $0.name == dirName && $0.isDirectory }) {
                // Directory exists - recurse into it
                var existingDir = newChildren[existingIndex]

                let remainingComponents = Array(pathComponents.dropFirst())
                insertFile(fileRef, pathComponents: remainingComponents, fullPath: fullPath, into: &existingDir)
                newChildren[existingIndex] = existingDir
            } else {
                // Create new directory node
                var newDir = FileNode(
                    name: dirName,
                    path: dirPath,
                    isDirectory: true
                )

                let remainingComponents = Array(pathComponents.dropFirst())
                insertFile(fileRef, pathComponents: remainingComponents, fullPath: fullPath, into: &newDir)
                newChildren.append(newDir)
            }

            node = FileNode(
                id: node.id,
                name: node.name,
                path: node.path,
                isDirectory: node.isDirectory,
                children: newChildren,
                fileReferenceID: node.fileReferenceID
            )
        }
    }
}

// Helper to kick off the recursive insertion
private extension FileNode {
    static func insertFile(_ fileRef: ProjectFileReference, into node: inout FileNode) {
        let pathComponents = fileRef.relativePath.split(separator: "/").map(String.init)
        insertFile(fileRef, pathComponents: pathComponents, fullPath: fileRef.relativePath, into: &node)
    }
}

// MARK: - FileNode Extensions for ProjectFileReference Lookup

public extension FileNode {
    /// Finds the ProjectFileReference associated with this file node.
    ///
    /// - Parameter project: The project containing file references
    /// - Returns: The file reference if this is a file node, nil for directories
    func fileReference(in project: ProjectModel) -> ProjectFileReference? {
        guard let refID = fileReferenceID else { return nil }
        return project.fileReferences.first { $0.id == refID }
    }
}

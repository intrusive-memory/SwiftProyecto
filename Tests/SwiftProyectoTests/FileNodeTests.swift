//
//  FileNodeTests.swift
//  SwiftProyectoTests
//
//  Tests for FileNode tree structure and ProjectModel.fileTree() method.
//

import XCTest
import Foundation
import SwiftData
@testable import SwiftProyecto

final class FileNodeTests: XCTestCase {

    // MARK: - Basic Node Tests

    func testFileNode_FileInitialization() {
        let fileRef = ProjectFileReference(
            relativePath: "script.fountain",
            filename: "script.fountain",
            fileExtension: "fountain"
        )

        let node = FileNode(
            name: "script.fountain",
            path: "script.fountain",
            isDirectory: false,
            fileReferenceID: fileRef.id
        )

        XCTAssertNotNil(node.id)
        XCTAssertEqual(node.name, "script.fountain")
        XCTAssertEqual(node.path, "script.fountain")
        XCTAssertFalse(node.isDirectory)
        XCTAssertTrue(node.isFile)
        XCTAssertEqual(node.children.count, 0)
        XCTAssertNotNil(node.fileReferenceID)
        XCTAssertEqual(node.fileCount, 1)
        XCTAssertEqual(node.totalNodeCount, 1)
    }

    func testFileNode_DirectoryInitialization() {
        let node = FileNode(
            name: "Season 1",
            path: "Season 1",
            isDirectory: true
        )

        XCTAssertEqual(node.name, "Season 1")
        XCTAssertTrue(node.isDirectory)
        XCTAssertFalse(node.isFile)
        XCTAssertEqual(node.children.count, 0)
        XCTAssertNil(node.fileReferenceID)
        XCTAssertEqual(node.fileCount, 0)
        XCTAssertEqual(node.totalNodeCount, 1)
    }

    func testFileNode_DirectoryWithChildren() {
        let file1 = FileNode(
            name: "ep1.fountain",
            path: "Season 1/ep1.fountain",
            isDirectory: false
        )

        let file2 = FileNode(
            name: "ep2.fountain",
            path: "Season 1/ep2.fountain",
            isDirectory: false
        )

        let directory = FileNode(
            name: "Season 1",
            path: "Season 1",
            isDirectory: true,
            children: [file1, file2]
        )

        XCTAssertEqual(directory.childCount, 2)
        XCTAssertEqual(directory.fileCount, 2)
        XCTAssertEqual(directory.totalNodeCount, 3) // 1 dir + 2 files
    }

    // MARK: - Tree Building Tests

    func testBuildTree_EmptyArray() {
        let tree = FileNode.buildTree(from: [])

        XCTAssertTrue(tree.isDirectory)
        XCTAssertEqual(tree.children.count, 0)
        XCTAssertEqual(tree.fileCount, 0)
    }

    func testBuildTree_SingleRootFile() {
        let fileRef = ProjectFileReference(
            relativePath: "README.md",
            filename: "README.md",
            fileExtension: "md"
        )

        let tree = FileNode.buildTree(from: [fileRef])

        XCTAssertEqual(tree.children.count, 1)
        XCTAssertEqual(tree.children[0].name, "README.md")
        XCTAssertTrue(tree.children[0].isFile)
        XCTAssertEqual(tree.children[0].path, "README.md")
        XCTAssertEqual(tree.fileCount, 1)
    }

    func testBuildTree_MultipleRootFiles() {
        let files = [
            ProjectFileReference(relativePath: "README.md", filename: "README.md", fileExtension: "md"),
            ProjectFileReference(relativePath: "LICENSE.txt", filename: "LICENSE.txt", fileExtension: "txt"),
            ProjectFileReference(relativePath: "script.fountain", filename: "script.fountain", fileExtension: "fountain")
        ]

        let tree = FileNode.buildTree(from: files)

        XCTAssertEqual(tree.children.count, 3)
        XCTAssertEqual(tree.fileCount, 3)

        let names = tree.children.map { $0.name }.sorted()
        XCTAssertEqual(names, ["LICENSE.txt", "README.md", "script.fountain"])
    }

    func testBuildTree_SingleDirectory() {
        let files = [
            ProjectFileReference(relativePath: "Season 1/ep1.fountain", filename: "ep1.fountain", fileExtension: "fountain"),
            ProjectFileReference(relativePath: "Season 1/ep2.fountain", filename: "ep2.fountain", fileExtension: "fountain")
        ]

        let tree = FileNode.buildTree(from: files)

        XCTAssertEqual(tree.children.count, 1)

        let seasonDir = tree.children[0]
        XCTAssertEqual(seasonDir.name, "Season 1")
        XCTAssertTrue(seasonDir.isDirectory)
        XCTAssertEqual(seasonDir.path, "Season 1")
        XCTAssertEqual(seasonDir.children.count, 2)
        XCTAssertEqual(seasonDir.fileCount, 2)

        let fileNames = seasonDir.children.map { $0.name }.sorted()
        XCTAssertEqual(fileNames, ["ep1.fountain", "ep2.fountain"])
    }

    func testBuildTree_NestedDirectories() {
        let files = [
            ProjectFileReference(relativePath: "Season 1/Episode 1/script.fountain", filename: "script.fountain", fileExtension: "fountain"),
            ProjectFileReference(relativePath: "Season 1/Episode 2/script.fountain", filename: "script.fountain", fileExtension: "fountain"),
            ProjectFileReference(relativePath: "Season 2/Episode 1/script.fountain", filename: "script.fountain", fileExtension: "fountain")
        ]

        let tree = FileNode.buildTree(from: files)

        // Root should have 2 children: Season 1 and Season 2
        XCTAssertEqual(tree.children.count, 2)
        XCTAssertEqual(tree.fileCount, 3)
        XCTAssertEqual(tree.totalNodeCount, 9) // root + 2 seasons + 3 episodes + 3 files

        // Check Season 1
        let season1 = tree.children.first { $0.name == "Season 1" }
        XCTAssertNotNil(season1)
        XCTAssertTrue(season1!.isDirectory)
        XCTAssertEqual(season1!.children.count, 2)

        // Check Episode 1 in Season 1
        let ep1 = season1!.children.first { $0.name == "Episode 1" }
        XCTAssertNotNil(ep1)
        XCTAssertTrue(ep1!.isDirectory)
        XCTAssertEqual(ep1!.children.count, 1)
        XCTAssertEqual(ep1!.children[0].name, "script.fountain")
    }

    func testBuildTree_MixedStructure() {
        let files = [
            ProjectFileReference(relativePath: "README.md", filename: "README.md", fileExtension: "md"),
            ProjectFileReference(relativePath: "src/main.fountain", filename: "main.fountain", fileExtension: "fountain"),
            ProjectFileReference(relativePath: "src/scene2.fountain", filename: "scene2.fountain", fileExtension: "fountain"),
            ProjectFileReference(relativePath: "tests/test1.txt", filename: "test1.txt", fileExtension: "txt")
        ]

        let tree = FileNode.buildTree(from: files)

        // Root: README.md + src/ + tests/
        XCTAssertEqual(tree.children.count, 3)
        XCTAssertEqual(tree.fileCount, 4)

        // Check root-level file
        let readme = tree.children.first { $0.name == "README.md" }
        XCTAssertNotNil(readme)
        XCTAssertTrue(readme!.isFile)

        // Check src directory
        let srcDir = tree.children.first { $0.name == "src" }
        XCTAssertNotNil(srcDir)
        XCTAssertTrue(srcDir!.isDirectory)
        XCTAssertEqual(srcDir!.children.count, 2)
        XCTAssertEqual(srcDir!.fileCount, 2)
    }

    // MARK: - Tree Navigation Tests

    func testFindNode_FindsRootFile() {
        let fileRef = ProjectFileReference(relativePath: "README.md", filename: "README.md", fileExtension: "md")
        let tree = FileNode.buildTree(from: [fileRef])

        let found = tree.findNode(atPath: "README.md")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "README.md")
    }

    func testFindNode_FindsNestedFile() {
        let files = [
            ProjectFileReference(relativePath: "Season 1/Episode 1/script.fountain", filename: "script.fountain", fileExtension: "fountain")
        ]
        let tree = FileNode.buildTree(from: files)

        let found = tree.findNode(atPath: "Season 1/Episode 1/script.fountain")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "script.fountain")
        XCTAssertTrue(found!.isFile)
    }

    func testFindNode_FindsDirectory() {
        let files = [
            ProjectFileReference(relativePath: "Season 1/ep1.fountain", filename: "ep1.fountain", fileExtension: "fountain")
        ]
        let tree = FileNode.buildTree(from: files)

        let found = tree.findNode(atPath: "Season 1")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Season 1")
        XCTAssertTrue(found!.isDirectory)
    }

    func testFindNode_ReturnsNilForNonexistent() {
        let tree = FileNode.buildTree(from: [])
        let found = tree.findNode(atPath: "nonexistent.txt")
        XCTAssertNil(found)
    }

    func testAllFiles_ReturnsOnlyFiles() {
        let files = [
            ProjectFileReference(relativePath: "README.md", filename: "README.md", fileExtension: "md"),
            ProjectFileReference(relativePath: "src/main.fountain", filename: "main.fountain", fileExtension: "fountain"),
            ProjectFileReference(relativePath: "src/scene2.fountain", filename: "scene2.fountain", fileExtension: "fountain")
        ]
        let tree = FileNode.buildTree(from: files)

        let allFiles = tree.allFiles
        XCTAssertEqual(allFiles.count, 3)
        XCTAssertTrue(allFiles.allSatisfy { $0.isFile })

        let names = allFiles.map { $0.name }.sorted()
        XCTAssertEqual(names, ["README.md", "main.fountain", "scene2.fountain"])
    }

    func testAllDirectories_ReturnsOnlyDirectories() {
        let files = [
            ProjectFileReference(relativePath: "README.md", filename: "README.md", fileExtension: "md"),
            ProjectFileReference(relativePath: "src/main.fountain", filename: "main.fountain", fileExtension: "fountain"),
            ProjectFileReference(relativePath: "tests/test1.txt", filename: "test1.txt", fileExtension: "txt")
        ]
        let tree = FileNode.buildTree(from: files)

        let allDirs = tree.allDirectories
        // Should include: root + src + tests = 3
        XCTAssertEqual(allDirs.count, 3)
        XCTAssertTrue(allDirs.allSatisfy { $0.isDirectory })

        let names = allDirs.map { $0.name }.sorted()
        XCTAssertEqual(names, ["", "src", "tests"]) // "" is root
    }

    // MARK: - Sorted Children Tests

    func testSortedChildren_DirectoriesFirst() {
        let files = [
            ProjectFileReference(relativePath: "z-file.txt", filename: "z-file.txt", fileExtension: "txt"),
            ProjectFileReference(relativePath: "a-dir/file.txt", filename: "file.txt", fileExtension: "txt"),
            ProjectFileReference(relativePath: "m-file.txt", filename: "m-file.txt", fileExtension: "txt")
        ]
        let tree = FileNode.buildTree(from: files)

        let sorted = tree.sortedChildren
        XCTAssertEqual(sorted.count, 3)

        // First should be directory
        XCTAssertTrue(sorted[0].isDirectory)
        XCTAssertEqual(sorted[0].name, "a-dir")

        // Then files in alphabetical order
        XCTAssertTrue(sorted[1].isFile)
        XCTAssertEqual(sorted[1].name, "m-file.txt")

        XCTAssertTrue(sorted[2].isFile)
        XCTAssertEqual(sorted[2].name, "z-file.txt")
    }

    func testSortedChildren_AlphabeticalWithinType() {
        let files = [
            ProjectFileReference(relativePath: "zebra.txt", filename: "zebra.txt", fileExtension: "txt"),
            ProjectFileReference(relativePath: "apple.txt", filename: "apple.txt", fileExtension: "txt"),
            ProjectFileReference(relativePath: "middle.txt", filename: "middle.txt", fileExtension: "txt")
        ]
        let tree = FileNode.buildTree(from: files)

        let sorted = tree.sortedChildren
        let names = sorted.map { $0.name }
        XCTAssertEqual(names, ["apple.txt", "middle.txt", "zebra.txt"])
    }

    // MARK: - ProjectModel Integration Tests

    func testProjectModel_FileTree_Empty() {
        let project = ProjectModel(
            title: "Test",
            author: "Author",
            sourceType: .directory,
            sourceName: "Test",
            sourceRootURL: "file:///test"
        )

        let tree = project.fileTree()
        XCTAssertTrue(tree.isDirectory)
        XCTAssertEqual(tree.children.count, 0)
        XCTAssertEqual(tree.fileCount, 0)
    }

    func testProjectModel_FileTree_WithFiles() {
        let project = ProjectModel(
            title: "Test",
            author: "Author",
            sourceType: .directory,
            sourceName: "Test",
            sourceRootURL: "file:///test"
        )

        let file1 = ProjectFileReference(relativePath: "README.md", filename: "README.md", fileExtension: "md")
        let file2 = ProjectFileReference(relativePath: "Season 1/ep1.fountain", filename: "ep1.fountain", fileExtension: "fountain")
        let file3 = ProjectFileReference(relativePath: "Season 1/ep2.fountain", filename: "ep2.fountain", fileExtension: "fountain")

        project.fileReferences.append(contentsOf: [file1, file2, file3])

        let tree = project.fileTree()
        XCTAssertEqual(tree.children.count, 2) // README.md + Season 1/
        XCTAssertEqual(tree.fileCount, 3)

        // Check structure
        let season1 = tree.children.first { $0.name == "Season 1" }
        XCTAssertNotNil(season1)
        XCTAssertEqual(season1!.children.count, 2)
    }

    func testProjectModel_FileTree_ComplexStructure() {
        let project = ProjectModel(
            title: "Test",
            author: "Author",
            sourceType: .directory,
            sourceName: "Test",
            sourceRootURL: "file:///test"
        )

        // Create a complex file structure
        let files = [
            ProjectFileReference(relativePath: "README.md", filename: "README.md", fileExtension: "md"),
            ProjectFileReference(relativePath: "LICENSE.txt", filename: "LICENSE.txt", fileExtension: "txt"),
            ProjectFileReference(relativePath: "Season 1/Episode 1/script.fountain", filename: "script.fountain", fileExtension: "fountain"),
            ProjectFileReference(relativePath: "Season 1/Episode 1/notes.md", filename: "notes.md", fileExtension: "md"),
            ProjectFileReference(relativePath: "Season 1/Episode 2/script.fountain", filename: "script.fountain", fileExtension: "fountain"),
            ProjectFileReference(relativePath: "Season 2/Episode 1/script.fountain", filename: "script.fountain", fileExtension: "fountain"),
            ProjectFileReference(relativePath: "assets/logo.png", filename: "logo.png", fileExtension: "png")
        ]

        project.fileReferences.append(contentsOf: files)

        let tree = project.fileTree()

        // Verify structure
        XCTAssertEqual(tree.fileCount, 7)
        XCTAssertEqual(tree.children.count, 5) // README, LICENSE, Season 1, Season 2, assets

        // Verify Season 1
        let season1 = tree.findNode(atPath: "Season 1")
        XCTAssertNotNil(season1)
        XCTAssertEqual(season1!.fileCount, 3)

        // Verify Episode 1 in Season 1
        let ep1 = tree.findNode(atPath: "Season 1/Episode 1")
        XCTAssertNotNil(ep1)
        XCTAssertEqual(ep1!.fileCount, 2)

        // Verify specific file
        let script = tree.findNode(atPath: "Season 1/Episode 1/script.fountain")
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.isFile)
        XCTAssertNotNil(script!.fileReferenceID)

        // Verify file reference lookup
        let fileRef = script!.fileReference(in: project)
        XCTAssertNotNil(fileRef)
        XCTAssertEqual(fileRef!.filename, "script.fountain")
    }

    // MARK: - Edge Cases

    func testFileNode_HashableAndEquatable() {
        let id = UUID()
        let node1 = FileNode(id: id, name: "test.txt", path: "test.txt", isDirectory: false)
        let node2 = FileNode(id: id, name: "test.txt", path: "test.txt", isDirectory: false)

        XCTAssertEqual(node1, node2)
        XCTAssertEqual(node1.hashValue, node2.hashValue)

        // Different IDs should not be equal
        let node3 = FileNode(name: "test.txt", path: "test.txt", isDirectory: false)
        XCTAssertNotEqual(node1, node3)
    }

    func testFileNode_Sendable() {
        // Verify FileNode conforms to Sendable (compile-time check)
        let node = FileNode(name: "test", path: "test", isDirectory: false)

        // This should compile without warnings
        Task {
            let _ = node
        }
    }
}

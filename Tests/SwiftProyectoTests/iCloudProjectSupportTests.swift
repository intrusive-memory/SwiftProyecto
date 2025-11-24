//
//  iCloudProjectSupportTests.swift
//  SwiftProyecto
//
//  Created on 2025-11-17.
//

import XCTest
import Foundation
@testable import SwiftProyecto

#if os(iOS)
@MainActor
final class iCloudProjectSupportTests: XCTestCase {

    var tempDirectory: URL!
    var support: iCloudProjectSupport!

    override func setUp() async throws {
        try await super.setUp()

        // Clean up any leftover test projects from previous runs
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let projectsFolder = documentsURL.appendingPathComponent("Projects")
            if FileManager.default.fileExists(atPath: projectsFolder.path) {
                let contents = try? FileManager.default.contentsOfDirectory(atPath: projectsFolder.path)
                contents?.forEach { folder in
                    if folder.contains("Test") || folder.contains("Existing") {
                        let folderURL = projectsFolder.appendingPathComponent(folder)
                        try? FileManager.default.removeItem(at: folderURL)
                    }
                }
            }
        }

        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftProyectoiCloudTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        support = iCloudProjectSupport()
    }

    override func tearDown() async throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        // Clean up any test projects created in Documents/Projects
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let projectsFolder = documentsURL.appendingPathComponent("Projects")
            // Remove test folders (folders with "Test" or "Existing" in the name)
            if FileManager.default.fileExists(atPath: projectsFolder.path) {
                let contents = try? FileManager.default.contentsOfDirectory(atPath: projectsFolder.path)
                contents?.forEach { folder in
                    if folder.contains("Test") || folder.contains("Existing") {
                        let folderURL = projectsFolder.appendingPathComponent(folder)
                        try? FileManager.default.removeItem(at: folderURL)
                    }
                }
            }
        }

        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(support)
    }

    // MARK: - iCloud Availability Tests

    func testiCloudAvailability() {
        // Note: This test depends on the test environment
        // In simulator, iCloud may or may not be available
        _ = support.isICloudAvailable  // Should not crash
    }

    func testiCloudContainerURL() {
        // Should return nil or a valid URL depending on environment
        let containerURL = support.iCloudContainerURL
        if let url = containerURL {
            XCTAssertTrue(url.absoluteString.contains("Documents"))
        }
    }

    // MARK: - Local Projects Folder Tests

    func testLocalProjectsFolder() throws {
        let projectsFolder = try support.localProjectsFolder()

        XCTAssertNotNil(projectsFolder)
        XCTAssertTrue(projectsFolder.path.contains("Documents"))
        XCTAssertTrue(projectsFolder.path.contains("Projects"))

        // Verify folder was created
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectsFolder.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testLocalProjectsFolder_CreatesIfNotExists() throws {
        // Get the folder (creates it)
        let folder1 = try support.localProjectsFolder()

        // Get it again (should return same folder)
        let folder2 = try support.localProjectsFolder()

        XCTAssertEqual(folder1, folder2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder1.path))
    }

    // MARK: - Local Project Creation Tests

    func testCreateLocalProjectFolder() throws {
        let projectName = "TestLocalProject"
        let projectURL = try support.createLocalProjectFolder(named: projectName)

        XCTAssertNotNil(projectURL)
        XCTAssertTrue(projectURL.lastPathComponent == projectName)

        // Verify folder was created
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testCreateLocalProjectFolder_AlreadyExists() throws {
        let projectName = "ExistingProject"

        // Create first time
        let projectURL1 = try support.createLocalProjectFolder(named: projectName)

        // Create second time (should return existing folder)
        let projectURL2 = try support.createLocalProjectFolder(named: projectName)

        XCTAssertEqual(projectURL1, projectURL2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectURL1.path))
    }

    // MARK: - File Copy Tests

    func testCopyFileToProject() throws {
        // Create project folder
        let projectURL = tempDirectory.appendingPathComponent("CopyTestProject")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        // Create source file
        let sourceURL = tempDirectory.appendingPathComponent("source.fountain")
        let testContent = "Test screenplay content"
        try testContent.write(to: sourceURL, atomically: true, encoding: .utf8)

        // Copy file to project
        let copiedURL = try support.copyFileToProject(from: sourceURL, to: projectURL, replaceExisting: false)

        // Verify copied file exists in project
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedURL.path))
        XCTAssertEqual(copiedURL.lastPathComponent, "source.fountain")
        XCTAssertTrue(copiedURL.path.contains(projectURL.path))

        // Verify content matches
        let copiedContent = try String(contentsOf: copiedURL, encoding: .utf8)
        XCTAssertEqual(copiedContent, testContent)

        // Verify original still exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    func testCopyFileToProject_ReplaceExisting() throws {
        let projectURL = tempDirectory.appendingPathComponent("ReplaceTestProject")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        // Create source file
        let sourceURL = tempDirectory.appendingPathComponent("replace.fountain")
        try "Original content".write(to: sourceURL, atomically: true, encoding: .utf8)

        // Copy first time
        _ = try support.copyFileToProject(from: sourceURL, to: projectURL, replaceExisting: false)

        // Update source
        try "Updated content".write(to: sourceURL, atomically: true, encoding: .utf8)

        // Copy with replace
        let copiedURL = try support.copyFileToProject(from: sourceURL, to: projectURL, replaceExisting: true)

        // Verify updated content
        let copiedContent = try String(contentsOf: copiedURL, encoding: .utf8)
        XCTAssertEqual(copiedContent, "Updated content")
    }

    func testCopyFileToProject_SourceNotFound() throws {
        let projectURL = tempDirectory.appendingPathComponent("NoSourceProject")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let nonExistentURL = tempDirectory.appendingPathComponent("nonexistent.fountain")

        XCTAssertThrowsError(try support.copyFileToProject(from: nonExistentURL, to: projectURL)) { error in
            guard let iCloudError = error as? iCloudProjectSupport.iCloudError else {
                XCTFail("Expected iCloudError")
                return
            }

            if case .invalidSourceURL = iCloudError {
                // Expected error
            } else {
                XCTFail("Expected invalidSourceURL error")
            }
        }
    }

    func testCopyFileToProject_InvalidDestination() throws {
        let sourceURL = tempDirectory.appendingPathComponent("valid.fountain")
        try "Content".write(to: sourceURL, atomically: true, encoding: .utf8)

        let invalidDestination = tempDirectory.appendingPathComponent("nonexistent-project")

        XCTAssertThrowsError(try support.copyFileToProject(from: sourceURL, to: invalidDestination)) { error in
            guard let iCloudError = error as? iCloudProjectSupport.iCloudError else {
                XCTFail("Expected iCloudError")
                return
            }

            if case .invalidDestinationURL = iCloudError {
                // Expected error
            } else {
                XCTFail("Expected invalidDestinationURL error")
            }
        }
    }

    // MARK: - File Export Tests

    func testCopyFileFromProject() throws {
        // Create project with file
        let projectURL = tempDirectory.appendingPathComponent("ExportTestProject")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let projectFileURL = projectURL.appendingPathComponent("screenplay.fountain")
        let testContent = "Export test content"
        try testContent.write(to: projectFileURL, atomically: true, encoding: .utf8)

        // Export file
        let destinationURL = tempDirectory.appendingPathComponent("exported.fountain")
        let exportedURL = try support.copyFileFromProject(
            in: projectURL,
            filename: "screenplay.fountain",
            to: destinationURL,
            replaceExisting: false
        )

        // Verify exported file
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedURL.path))
        let exportedContent = try String(contentsOf: exportedURL, encoding: .utf8)
        XCTAssertEqual(exportedContent, testContent)

        // Verify original still exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectFileURL.path))
    }

    // MARK: - Project Discovery Tests

    func testDiscoverLocalProjects_Empty() throws {
        // Get or create local projects folder
        _ = try support.localProjectsFolder()

        // Discover projects (should be empty initially or contain only existing projects)
        let projects = try support.discoverLocalProjects()

        // Should not crash, returns array
        XCTAssertNotNil(projects)
    }

    func testDiscoverLocalProjects_WithProjects() throws {
        let projectsFolder = try support.localProjectsFolder()

        // Create test projects
        let project1URL = projectsFolder.appendingPathComponent("Project1")
        try FileManager.default.createDirectory(at: project1URL, withIntermediateDirectories: true)
        let manifest1URL = project1URL.appendingPathComponent("PROJECT.md")
        try "---\ntitle: Project 1\n---".write(to: manifest1URL, atomically: true, encoding: .utf8)

        let project2URL = projectsFolder.appendingPathComponent("Project2")
        try FileManager.default.createDirectory(at: project2URL, withIntermediateDirectories: true)
        let manifest2URL = project2URL.appendingPathComponent("PROJECT.md")
        try "---\ntitle: Project 2\n---".write(to: manifest2URL, atomically: true, encoding: .utf8)

        // Create folder without PROJECT.md (should be ignored)
        let nonProjectURL = projectsFolder.appendingPathComponent("NotAProject")
        try FileManager.default.createDirectory(at: nonProjectURL, withIntermediateDirectories: true)

        // Discover projects
        let projects = try support.discoverLocalProjects()

        // Should find at least our 2 test projects
        let testProjects = projects.filter { url in
            url.lastPathComponent == "Project1" || url.lastPathComponent == "Project2"
        }
        XCTAssertGreaterThanOrEqual(testProjects.count, 2)

        // Should not include non-project folder
        let nonProject = projects.first { $0.lastPathComponent == "NotAProject" }
        XCTAssertNil(nonProject)

        // Results should be sorted
        let projectNames = projects.map { $0.lastPathComponent }
        XCTAssertEqual(projectNames, projectNames.sorted())
    }

    // MARK: - Error Description Tests

    func testiCloudErrorDescriptions() {
        let testURL = tempDirectory.appendingPathComponent("test")
        let testError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        let iCloudNotAvailableError = iCloudProjectSupport.iCloudError.iCloudNotAvailable
        XCTAssertNotNil(iCloudNotAvailableError.errorDescription)
        XCTAssertTrue(iCloudNotAvailableError.errorDescription!.contains("iCloud"))

        let containerNotFoundError = iCloudProjectSupport.iCloudError.containerNotFound
        XCTAssertNotNil(containerNotFoundError.errorDescription)
        XCTAssertTrue(containerNotFoundError.errorDescription!.contains("container"))

        let projectFolderError = iCloudProjectSupport.iCloudError.projectFolderCreationFailed(testError)
        XCTAssertNotNil(projectFolderError.errorDescription)
        XCTAssertTrue(projectFolderError.errorDescription!.contains("create"))

        let fileCopyError = iCloudProjectSupport.iCloudError.fileCopyFailed("test.fountain", testError)
        XCTAssertNotNil(fileCopyError.errorDescription)
        XCTAssertTrue(fileCopyError.errorDescription!.contains("copy"))

        let invalidSourceError = iCloudProjectSupport.iCloudError.invalidSourceURL(testURL)
        XCTAssertNotNil(invalidSourceError.errorDescription)
        XCTAssertTrue(invalidSourceError.errorDescription!.contains("Invalid source"))

        let invalidDestinationError = iCloudProjectSupport.iCloudError.invalidDestinationURL(testURL)
        XCTAssertNotNil(invalidDestinationError.errorDescription)
        XCTAssertTrue(invalidDestinationError.errorDescription!.contains("Invalid destination"))
    }
}
#endif

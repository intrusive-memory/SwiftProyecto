import XCTest
import SwiftData
import Foundation
@testable import SwiftProyecto

@MainActor
final class ModelContainerFactoryTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftProyectoTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - Single File Container Tests

    func testCreateContainer_SingleFile() throws {
        let fileURL = tempDirectory.appendingPathComponent("test.fountain")
        let context = DocumentContext.singleFile(fileURL)

        let container = try ModelContainerFactory.createContainer(for: context)

        XCTAssertNotNil(container)
        // Verify the container was created with correct schema
        XCTAssertNoThrow(try container.mainContext.fetch(FetchDescriptor<ProjectModel>()))
    }

    func testSingleFileContainerLocation() throws {
        let fileURL = tempDirectory.appendingPathComponent("test.fountain")
        let context = DocumentContext.singleFile(fileURL)

        _ = try ModelContainerFactory.createContainer(for: context)

        // Verify store was created in Application Support
        let storeURL = context.storeURL
        XCTAssertTrue(storeURL.path.contains("Application Support"))
        XCTAssertTrue(storeURL.path.contains("com.intrusive-memory.Produciesta"))
    }

    // MARK: - Project Container Tests

    func testCreateContainer_Project() throws {
        // Create a project directory
        let projectURL = tempDirectory.appendingPathComponent("TestProject")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let context = DocumentContext.project(projectRoot: projectURL)

        let container = try ModelContainerFactory.createContainer(for: context)

        XCTAssertNotNil(container)
        // Verify the container was created with correct schema
        XCTAssertNoThrow(try container.mainContext.fetch(FetchDescriptor<ProjectModel>()))
    }

    func testProjectContainerLocation() throws {
        // Create a project directory
        let projectURL = tempDirectory.appendingPathComponent("TestProject")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let context = DocumentContext.project(projectRoot: projectURL)

        _ = try ModelContainerFactory.createContainer(for: context)

        // Verify store was created in .cache
        let cacheURL = projectURL.appendingPathComponent(".cache")
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheURL.path))

        let storeURL = cacheURL.appendingPathComponent("default.store")
        // Store might not exist yet if no data has been saved, but cache dir should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    func testProjectContainerFailsIfProjectRootDoesNotExist() throws {
        let nonExistentURL = tempDirectory.appendingPathComponent("DoesNotExist")
        let context = DocumentContext.project(projectRoot: nonExistentURL)

        XCTAssertThrowsError(try ModelContainerFactory.createContainer(for: context)) { error in
            guard let containerError = error as? ModelContainerFactory.ContainerError else {
                XCTFail("Expected ContainerError, got \(error)")
                return
            }

            switch containerError {
            case .projectRootDoesNotExist(let url):
                XCTAssertEqual(url, nonExistentURL)
            default:
                XCTFail("Expected projectRootDoesNotExist error, got \(containerError)")
            }
        }
    }

    // MARK: - Schema Tests

    func testContainerSchema() throws {
        let fileURL = tempDirectory.appendingPathComponent("test.fountain")
        let context = DocumentContext.singleFile(fileURL)

        let container = try ModelContainerFactory.createContainer(for: context)
        let modelContext = container.mainContext

        // Test that all expected models are in the schema
        XCTAssertNoThrow(try modelContext.fetch(FetchDescriptor<ProjectModel>()))
        XCTAssertNoThrow(try modelContext.fetch(FetchDescriptor<ProjectFileReference>()))
        // Note: We can't easily test GuionDocumentModel without creating one,
        // but if container creation succeeds, the schema is correct
    }

    // MARK: - Store Lifecycle Tests

    func testStoreExists_SingleFile() throws {
        let fileURL = tempDirectory.appendingPathComponent("test.fountain")
        let context = DocumentContext.singleFile(fileURL)

        // Initially, store should not exist (or we don't care)
        // After creating container and saving data, it should exist

        let container = try ModelContainerFactory.createContainer(for: context)
        let modelContext = container.mainContext

        // Create and save a project
        let project = ProjectModel(title: "Test", author: "Author")
        modelContext.insert(project)
        try modelContext.save()

        // Now store should exist
        XCTAssertTrue(ModelContainerFactory.storeExists(for: context))
    }

    func testStoreExists_Project() throws {
        let projectURL = tempDirectory.appendingPathComponent("TestProject")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let context = DocumentContext.project(projectRoot: projectURL)

        let container = try ModelContainerFactory.createContainer(for: context)
        let modelContext = container.mainContext

        // Create and save a project
        let project = ProjectModel(title: "Test", author: "Author")
        modelContext.insert(project)
        try modelContext.save()

        // Now store should exist
        XCTAssertTrue(ModelContainerFactory.storeExists(for: context))
    }

    func testDeleteStore_SingleFile() throws {
        let fileURL = tempDirectory.appendingPathComponent("test.fountain")
        let context = DocumentContext.singleFile(fileURL)

        let container = try ModelContainerFactory.createContainer(for: context)
        let modelContext = container.mainContext

        // Create and save data
        let project = ProjectModel(title: "Test", author: "Author")
        modelContext.insert(project)
        try modelContext.save()

        XCTAssertTrue(ModelContainerFactory.storeExists(for: context))

        // Delete store
        try ModelContainerFactory.deleteStore(for: context)

        // Store should be deleted
        XCTAssertFalse(ModelContainerFactory.storeExists(for: context))
    }

    func testDeleteStore_Project() throws {
        let projectURL = tempDirectory.appendingPathComponent("TestProject")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let context = DocumentContext.project(projectRoot: projectURL)

        let container = try ModelContainerFactory.createContainer(for: context)
        let modelContext = container.mainContext

        // Create and save data
        let project = ProjectModel(title: "Test", author: "Author")
        modelContext.insert(project)
        try modelContext.save()

        XCTAssertTrue(ModelContainerFactory.storeExists(for: context))

        // Delete store
        try ModelContainerFactory.deleteStore(for: context)

        // Store should be deleted
        XCTAssertFalse(ModelContainerFactory.storeExists(for: context))
    }

    func testDeleteStore_NonExistent() throws {
        let projectURL = tempDirectory.appendingPathComponent("TestProject")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let context = DocumentContext.project(projectRoot: projectURL)

        // Delete store that doesn't exist (should not throw)
        XCTAssertNoThrow(try ModelContainerFactory.deleteStore(for: context))
    }

    // MARK: - Integration Tests

    func testMultipleContainersForDifferentContexts() throws {
        // Create single file container
        let fileURL = tempDirectory.appendingPathComponent("test.fountain")
        let singleFileContext = DocumentContext.singleFile(fileURL)
        let singleFileContainer = try ModelContainerFactory.createContainer(for: singleFileContext)

        // Create project container
        let projectURL = tempDirectory.appendingPathComponent("TestProject")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        let projectContext = DocumentContext.project(projectRoot: projectURL)
        let projectContainer = try ModelContainerFactory.createContainer(for: projectContext)

        // Both should be independent
        XCTAssertNotNil(singleFileContainer)
        XCTAssertNotNil(projectContainer)

        // Save data to both
        let singleFileModelContext = singleFileContainer.mainContext
        let singleFileProject = ProjectModel(title: "Single File", author: "Author1")
        singleFileModelContext.insert(singleFileProject)
        try singleFileModelContext.save()

        let projectModelContext = projectContainer.mainContext
        let projectProject = ProjectModel(title: "Project", author: "Author2")
        projectModelContext.insert(projectProject)
        try projectModelContext.save()

        // Verify they are in different stores
        let singleFileProjects = try singleFileModelContext.fetch(FetchDescriptor<ProjectModel>())
        XCTAssertEqual(singleFileProjects.count, 1)
        XCTAssertEqual(singleFileProjects.first?.title, "Single File")

        let projectProjects = try projectModelContext.fetch(FetchDescriptor<ProjectModel>())
        XCTAssertEqual(projectProjects.count, 1)
        XCTAssertEqual(projectProjects.first?.title, "Project")
    }
}

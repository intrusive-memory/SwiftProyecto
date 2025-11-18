import XCTest
import Foundation
@testable import SwiftProyecto

final class DocumentContextTests: XCTestCase {

    // MARK: - Single File Context Tests

    func testSingleFileContext() {
        let fileURL = URL(fileURLWithPath: "/Users/test/screenplay.fountain")
        let context = DocumentContext.singleFile(fileURL)

        XCTAssertEqual(context.url, fileURL)
        XCTAssertFalse(context.isProject)
    }

    func testSingleFileCacheDirectory() {
        let fileURL = URL(fileURLWithPath: "/Users/test/screenplay.fountain")
        let context = DocumentContext.singleFile(fileURL)

        let cacheURL = context.cacheDirectoryURL

        // Should be in Application Support
        XCTAssertTrue(cacheURL.path.contains("Application Support"))
        XCTAssertTrue(cacheURL.path.contains("com.intrusive-memory.Produciesta"))
    }

    func testSingleFileStoreURL() {
        let fileURL = URL(fileURLWithPath: "/Users/test/screenplay.fountain")
        let context = DocumentContext.singleFile(fileURL)

        let storeURL = context.storeURL

        // Should be default.store in Application Support
        XCTAssertTrue(storeURL.path.contains("Application Support"))
        XCTAssertTrue(storeURL.path.contains("com.intrusive-memory.Produciesta"))
        XCTAssertTrue(storeURL.lastPathComponent == "default.store")
    }

    // MARK: - Project Context Tests

    func testProjectContext() {
        let projectURL = URL(fileURLWithPath: "/Users/test/MyProject")
        let context = DocumentContext.project(projectRoot: projectURL)

        XCTAssertEqual(context.url, projectURL)
        XCTAssertTrue(context.isProject)
    }

    func testProjectCacheDirectory() {
        let projectURL = URL(fileURLWithPath: "/Users/test/MyProject")
        let context = DocumentContext.project(projectRoot: projectURL)

        let cacheURL = context.cacheDirectoryURL

        // Should be .cache under project root
        XCTAssertEqual(cacheURL.path, "/Users/test/MyProject/.cache")
    }

    func testProjectStoreURL() {
        let projectURL = URL(fileURLWithPath: "/Users/test/MyProject")
        let context = DocumentContext.project(projectRoot: projectURL)

        let storeURL = context.storeURL

        // Should be default.store in .cache
        XCTAssertEqual(storeURL.path, "/Users/test/MyProject/.cache/default.store")
    }

    // MARK: - Equatable Tests

    func testEquality_SameContext() {
        let fileURL = URL(fileURLWithPath: "/Users/test/screenplay.fountain")
        let context1 = DocumentContext.singleFile(fileURL)
        let context2 = DocumentContext.singleFile(fileURL)

        XCTAssertEqual(context1, context2)
    }

    func testEquality_DifferentFiles() {
        let fileURL1 = URL(fileURLWithPath: "/Users/test/screenplay1.fountain")
        let fileURL2 = URL(fileURLWithPath: "/Users/test/screenplay2.fountain")
        let context1 = DocumentContext.singleFile(fileURL1)
        let context2 = DocumentContext.singleFile(fileURL2)

        XCTAssertNotEqual(context1, context2)
    }

    func testEquality_DifferentContextTypes() {
        let fileURL = URL(fileURLWithPath: "/Users/test/MyProject/screenplay.fountain")
        let projectURL = URL(fileURLWithPath: "/Users/test/MyProject")
        let singleFileContext = DocumentContext.singleFile(fileURL)
        let projectContext = DocumentContext.project(projectRoot: projectURL)

        XCTAssertNotEqual(singleFileContext, projectContext)
    }

    func testEquality_SameProject() {
        let projectURL = URL(fileURLWithPath: "/Users/test/MyProject")
        let context1 = DocumentContext.project(projectRoot: projectURL)
        let context2 = DocumentContext.project(projectRoot: projectURL)

        XCTAssertEqual(context1, context2)
    }

    func testEquality_DifferentProjects() {
        let projectURL1 = URL(fileURLWithPath: "/Users/test/Project1")
        let projectURL2 = URL(fileURLWithPath: "/Users/test/Project2")
        let context1 = DocumentContext.project(projectRoot: projectURL1)
        let context2 = DocumentContext.project(projectRoot: projectURL2)

        XCTAssertNotEqual(context1, context2)
    }
}

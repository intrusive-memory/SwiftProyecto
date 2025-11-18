import XCTest
@testable import SwiftProyecto

final class FileLoadingStateTests: XCTestCase {

    // MARK: - Display Properties Tests

    func testDisplayNames() {
        XCTAssertEqual(FileLoadingState.notLoaded.displayName, "Not Loaded")
        XCTAssertEqual(FileLoadingState.loading.displayName, "Loading...")
        XCTAssertEqual(FileLoadingState.loaded.displayName, "Loaded")
        XCTAssertEqual(FileLoadingState.stale.displayName, "Modified")
        XCTAssertEqual(FileLoadingState.missing.displayName, "Missing")
        XCTAssertEqual(FileLoadingState.error.displayName, "Error")
    }

    func testSystemIconNames() {
        XCTAssertEqual(FileLoadingState.notLoaded.systemIconName, "circle")
        XCTAssertEqual(FileLoadingState.loading.systemIconName, "arrow.clockwise.circle")
        XCTAssertEqual(FileLoadingState.loaded.systemIconName, "checkmark.circle.fill")
        XCTAssertEqual(FileLoadingState.stale.systemIconName, "exclamationmark.triangle.fill")
        XCTAssertEqual(FileLoadingState.missing.systemIconName, "xmark.circle.fill")
        XCTAssertEqual(FileLoadingState.error.systemIconName, "exclamationmark.octagon.fill")
    }

    // MARK: - Capability Tests

    func testCanOpen() {
        XCTAssertTrue(FileLoadingState.loaded.canOpen)
        XCTAssertTrue(FileLoadingState.stale.canOpen)

        XCTAssertFalse(FileLoadingState.notLoaded.canOpen)
        XCTAssertFalse(FileLoadingState.loading.canOpen)
        XCTAssertFalse(FileLoadingState.missing.canOpen)
        XCTAssertFalse(FileLoadingState.error.canOpen)
    }

    func testCanLoad() {
        XCTAssertTrue(FileLoadingState.notLoaded.canLoad)
        XCTAssertTrue(FileLoadingState.stale.canLoad)
        XCTAssertTrue(FileLoadingState.error.canLoad)

        XCTAssertFalse(FileLoadingState.loading.canLoad)
        XCTAssertFalse(FileLoadingState.loaded.canLoad)
        XCTAssertFalse(FileLoadingState.missing.canLoad)
    }

    func testShowsWarning() {
        XCTAssertTrue(FileLoadingState.stale.showsWarning)
        XCTAssertTrue(FileLoadingState.missing.showsWarning)
        XCTAssertTrue(FileLoadingState.error.showsWarning)

        XCTAssertFalse(FileLoadingState.notLoaded.showsWarning)
        XCTAssertFalse(FileLoadingState.loading.showsWarning)
        XCTAssertFalse(FileLoadingState.loaded.showsWarning)
    }

    // MARK: - Codable Tests

    func testCodable() throws {
        let states = FileLoadingState.allCases

        for state in states {
            // Encode
            let encoder = JSONEncoder()
            let data = try encoder.encode(state)

            // Decode
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(FileLoadingState.self, from: data)

            XCTAssertEqual(state, decoded)
        }
    }

    func testRawValues() {
        XCTAssertEqual(FileLoadingState.notLoaded.rawValue, "notLoaded")
        XCTAssertEqual(FileLoadingState.loading.rawValue, "loading")
        XCTAssertEqual(FileLoadingState.loaded.rawValue, "loaded")
        XCTAssertEqual(FileLoadingState.stale.rawValue, "stale")
        XCTAssertEqual(FileLoadingState.missing.rawValue, "missing")
        XCTAssertEqual(FileLoadingState.error.rawValue, "error")
    }

    // MARK: - All Cases Tests

    func testAllCases() {
        let allCases = FileLoadingState.allCases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.notLoaded))
        XCTAssertTrue(allCases.contains(.loading))
        XCTAssertTrue(allCases.contains(.loaded))
        XCTAssertTrue(allCases.contains(.stale))
        XCTAssertTrue(allCases.contains(.missing))
        XCTAssertTrue(allCases.contains(.error))
    }
}

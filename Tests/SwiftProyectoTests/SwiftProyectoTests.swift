import XCTest

@testable import SwiftProyecto

final class SwiftProyectoTests: XCTestCase {
  func testVersion() {
    XCTAssertEqual(SwiftProyecto.version, "4.1.1-dev")
  }

  func testExample() {
    // Placeholder test - will be replaced with real tests in Phase 1+
    XCTAssertTrue(true)
  }
}

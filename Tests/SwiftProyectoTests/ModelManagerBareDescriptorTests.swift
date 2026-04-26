import XCTest
import SwiftAcervo
@testable import SwiftProyecto

final class ModelManagerBareDescriptorTests: XCTestCase {
    func testBareDescriptorIsRegistered() async throws {
        let modelManager = ModelManager()  // Triggers registration side-effect
        let component = Acervo.component(LanguageModel.id)

        // Verify the descriptor is registered
        XCTAssertNotNil(component, "LanguageModel should be registered")
        XCTAssertEqual(component?.id, LanguageModel.id, "Component ID should match LanguageModel constant")
        XCTAssertEqual(component?.type, .languageModel, "Component type should be .languageModel")

        // Verify the bare descriptor pattern: repoId is set, minimumMemoryBytes is set
        XCTAssertEqual(component?.repoId, LanguageModel.repoId, "Component should have repoId")
        XCTAssertGreaterThan(component?.minimumMemoryBytes ?? 0, 0, "Component should have minimumMemoryBytes")

        // Hydration state may vary depending on test execution order,
        // but the descriptor must always be registered for ModelManager to work
    }
}

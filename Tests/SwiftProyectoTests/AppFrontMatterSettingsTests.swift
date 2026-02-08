import XCTest
@testable import SwiftProyecto

/// Tests for the AppFrontMatterSettings protocol.
///
/// Validates that:
/// - Protocol conformance works for simple and complex settings
/// - Settings are Codable (can be serialized/deserialized)
/// - Settings are Sendable (thread-safe for Swift 6)
/// - Section keys are accessible
/// - Optional fields encode/decode correctly
final class AppFrontMatterSettingsTests: XCTestCase {

    // MARK: - Test Settings Types

    /// Simple test settings with basic optional fields.
    private struct SimpleTestSettings: AppFrontMatterSettings {
        static let sectionKey = "simpletest"

        var name: String?
        var count: Int?
    }

    /// Complex test settings with nested types and enums.
    private struct ComplexTestSettings: AppFrontMatterSettings {
        static let sectionKey = "complextest"

        var theme: Theme?
        var config: Config?
        var tags: [String]?

        enum Theme: String, Codable, Sendable {
            case light
            case dark
        }

        struct Config: Codable, Sendable, Equatable {
            var enabled: Bool?
            var value: Int?
        }
    }

    // MARK: - Tests

    /// Test that SimpleTestSettings can be encoded and decoded.
    func testSimpleSettingsCodable() throws {
        let settings = SimpleTestSettings(name: "Test", count: 42)

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        // Decode from JSON
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SimpleTestSettings.self, from: data)

        // Verify values preserved
        XCTAssertEqual(decoded.name, "Test")
        XCTAssertEqual(decoded.count, 42)
    }

    /// Test that ComplexTestSettings can be encoded and decoded with nested types.
    func testComplexSettingsCodable() throws {
        let settings = ComplexTestSettings(
            theme: .dark,
            config: ComplexTestSettings.Config(enabled: true, value: 100),
            tags: ["tag1", "tag2", "tag3"]
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        // Decode from JSON
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ComplexTestSettings.self, from: data)

        // Verify nested types preserved
        XCTAssertEqual(decoded.theme, .dark)
        XCTAssertEqual(decoded.config?.enabled, true)
        XCTAssertEqual(decoded.config?.value, 100)
        XCTAssertEqual(decoded.tags, ["tag1", "tag2", "tag3"])
    }

    /// Test that static sectionKey property is accessible.
    func testSectionKeyAccessible() throws {
        // Verify section keys are accessible at type level
        XCTAssertEqual(SimpleTestSettings.sectionKey, "simpletest")
        XCTAssertEqual(ComplexTestSettings.sectionKey, "complextest")

        // Verify section keys are unique
        XCTAssertNotEqual(SimpleTestSettings.sectionKey, ComplexTestSettings.sectionKey)
    }

    /// Test that settings can be used in async contexts (Sendable conformance).
    func testSendableConformance() {
        // This test verifies that settings conform to Sendable by compiling.
        // If Sendable conformance was broken, this wouldn't compile.

        Task {
            let simple = SimpleTestSettings(name: "Async", count: 1)
            XCTAssertEqual(simple.name, "Async")

            let complex = ComplexTestSettings(
                theme: .light,
                config: nil,
                tags: []
            )
            XCTAssertEqual(complex.theme, .light)
        }
    }

    /// Test that optional fields encode as nil when not set.
    func testOptionalFieldsEncodeAsNil() throws {
        // Create settings with some nil fields
        let settings = SimpleTestSettings(name: "Test", count: nil)

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        // Convert to dictionary to inspect structure
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)

        // Verify that name is present
        XCTAssertNotNil(json?["name"])
        XCTAssertEqual(json?["name"] as? String, "Test")

        // Verify that count is either missing or null
        // (JSONEncoder may omit nil optionals or encode as null depending on settings)
        if let count = json?["count"] {
            XCTAssertTrue(count is NSNull, "Expected NSNull for nil optional, got \(type(of: count))")
        }

        // Decode back and verify nil is preserved
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SimpleTestSettings.self, from: data)
        XCTAssertEqual(decoded.name, "Test")
        XCTAssertNil(decoded.count)
    }

    /// Test that settings with all nil fields can be encoded and decoded.
    func testAllOptionalFieldsNil() throws {
        let settings = SimpleTestSettings(name: nil, count: nil)

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        // Decode from JSON
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SimpleTestSettings.self, from: data)

        // Verify all fields are nil
        XCTAssertNil(decoded.name)
        XCTAssertNil(decoded.count)
    }

    /// Test that complex settings with partial nil fields encode/decode correctly.
    func testComplexSettingsPartialNil() throws {
        let settings = ComplexTestSettings(
            theme: .dark,
            config: nil,  // Config is nil
            tags: ["tag1"]
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        // Decode from JSON
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ComplexTestSettings.self, from: data)

        // Verify values preserved and nil maintained
        XCTAssertEqual(decoded.theme, .dark)
        XCTAssertNil(decoded.config)
        XCTAssertEqual(decoded.tags, ["tag1"])
    }

    /// Test that enum values in settings encode/decode correctly.
    func testEnumFieldsCodable() throws {
        // Test both enum values
        for themeValue in [ComplexTestSettings.Theme.light, ComplexTestSettings.Theme.dark] {
            let settings = ComplexTestSettings(
                theme: themeValue,
                config: nil,
                tags: nil
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ComplexTestSettings.self, from: data)

            XCTAssertEqual(decoded.theme, themeValue)
        }
    }

    /// Test that nested structs in settings encode/decode correctly.
    func testNestedStructsCodable() throws {
        let config1 = ComplexTestSettings.Config(enabled: true, value: 50)
        let config2 = ComplexTestSettings.Config(enabled: false, value: nil)
        let config3 = ComplexTestSettings.Config(enabled: nil, value: 100)

        for config in [config1, config2, config3] {
            let settings = ComplexTestSettings(
                theme: nil,
                config: config,
                tags: nil
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ComplexTestSettings.self, from: data)

            XCTAssertEqual(decoded.config, config)
        }
    }

    /// Test that array fields in settings encode/decode correctly.
    func testArrayFieldsCodable() throws {
        let testCases: [[String]?] = [
            nil,
            [],
            ["single"],
            ["multiple", "tags", "here"]
        ]

        for tags in testCases {
            let settings = ComplexTestSettings(
                theme: nil,
                config: nil,
                tags: tags
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ComplexTestSettings.self, from: data)

            XCTAssertEqual(decoded.tags, tags)
        }
    }
}

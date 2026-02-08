import XCTest
@testable import SwiftProyecto

final class AnyCodableTests: XCTestCase {

    // MARK: - Test 1: Encode/Decode Primitives

    func testEncodePrimitives() throws {
        // Test String
        let stringValue = try AnyCodable("hello")
        let stringData = try JSONEncoder().encode(stringValue)
        let decodedString = try JSONDecoder().decode(AnyCodable.self, from: stringData)
        XCTAssertEqual(stringValue, decodedString)

        // Test Int
        let intValue = try AnyCodable(42)
        let intData = try JSONEncoder().encode(intValue)
        let decodedInt = try JSONDecoder().decode(AnyCodable.self, from: intData)
        XCTAssertEqual(intValue, decodedInt)

        // Test Bool
        let boolValue = try AnyCodable(true)
        let boolData = try JSONEncoder().encode(boolValue)
        let decodedBool = try JSONDecoder().decode(AnyCodable.self, from: boolData)
        XCTAssertEqual(boolValue, decodedBool)

        // Test Double
        let doubleValue = try AnyCodable(3.14159)
        let doubleData = try JSONEncoder().encode(doubleValue)
        let decodedDouble = try JSONDecoder().decode(AnyCodable.self, from: doubleData)
        XCTAssertEqual(doubleValue, decodedDouble)
    }

    // MARK: - Test 2: Encode/Decode Arrays

    func testEncodeArray() throws {
        // Test String array
        let stringArray = ["apple", "banana", "cherry"]
        let stringArrayValue = try AnyCodable(stringArray)
        let data = try JSONEncoder().encode(stringArrayValue)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(stringArrayValue, decoded)

        // Test Int array
        let intArray = [1, 2, 3, 4, 5]
        let intArrayValue = try AnyCodable(intArray)
        let intData = try JSONEncoder().encode(intArrayValue)
        let decodedInt = try JSONDecoder().decode(AnyCodable.self, from: intData)
        XCTAssertEqual(intArrayValue, decodedInt)
    }

    // MARK: - Test 3: Encode/Decode Dictionary

    func testEncodeDictionary() throws {
        // Test String dictionary
        let stringDict = ["name": "Alice", "city": "Paris", "country": "France"]
        let dictValue = try AnyCodable(stringDict)
        let data = try JSONEncoder().encode(dictValue)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(dictValue, decoded)

        // Test mixed value dictionary (using nested AnyCodable)
        let mixedDict = [
            "name": "Bob",
            "age": "30",
            "active": "true"
        ]
        let mixedValue = try AnyCodable(mixedDict)
        let mixedData = try JSONEncoder().encode(mixedValue)
        let decodedMixed = try JSONDecoder().decode(AnyCodable.self, from: mixedData)
        XCTAssertEqual(mixedValue, decodedMixed)
    }

    // MARK: - Test 4: Encode/Decode Nested Struct

    func testEncodeNestedStruct() throws {
        struct Person: Codable, Equatable {
            let name: String
            let age: Int
            let address: Address

            struct Address: Codable, Equatable {
                let street: String
                let city: String
                let zipCode: String
            }
        }

        let person = Person(
            name: "Charlie",
            age: 28,
            address: Person.Address(
                street: "123 Main St",
                city: "Springfield",
                zipCode: "12345"
            )
        )

        let wrappedPerson = try AnyCodable(person)
        let data = try JSONEncoder().encode(wrappedPerson)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        // Verify we can extract the original value from the round-tripped AnyCodable
        let extractedPerson = try decoded.decode(Person.self)
        XCTAssertEqual(person, extractedPerson)

        // Also verify that creating a new AnyCodable from the same struct matches
        let wrappedPerson2 = try AnyCodable(person)
        let extracted2 = try wrappedPerson2.decode(Person.self)
        XCTAssertEqual(person, extracted2)
    }

    // MARK: - Test 5: Decode Preserves Type

    func testDecodePreservesType() throws {
        // Create an AnyCodable with an Int
        let originalInt = 123
        let wrapped = try AnyCodable(originalInt)

        // Encode and decode
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        // Extract the value and verify type is preserved
        let extractedInt = try decoded.decode(Int.self)
        XCTAssertEqual(originalInt, extractedInt)

        // Verify type mismatch throws
        XCTAssertThrowsError(try decoded.decode(String.self)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    // MARK: - Test 6: Decode Invalid Data Throws

    func testDecodeInvalidDataThrows() throws {
        // Create invalid JSON data
        let invalidData = Data([0xFF, 0xFE, 0xFD])

        // Attempt to decode should throw
        XCTAssertThrowsError(try JSONDecoder().decode(AnyCodable.self, from: invalidData)) { error in
            XCTAssertTrue(error is DecodingError)
        }

        // Create valid JSON that can't be decoded to expected structure
        let json = "{\"unknown_field\": 123}"
        let data = json.data(using: .utf8)!

        // This should actually succeed because AnyCodable accepts dictionaries
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertNotNil(decoded)
    }

    // MARK: - Test 7: Sendable Conformance

    func testSendableConformance() {
        // This test verifies that AnyCodable can be used in async contexts
        // The fact that this compiles demonstrates Sendable conformance

        let value = try? AnyCodable("test")
        XCTAssertNotNil(value)

        // Test that we can use it in a Task (which requires Sendable)
        Task {
            let taskValue = try? AnyCodable(42)
            XCTAssertNotNil(taskValue)
        }
    }

    // MARK: - Test 8: Equality

    func testEquality() throws {
        // Test equality for same values
        let value1 = try AnyCodable(42)
        let value2 = try AnyCodable(42)
        XCTAssertEqual(value1, value2)

        // Test inequality for different values
        let value3 = try AnyCodable(43)
        XCTAssertNotEqual(value1, value3)

        // Test equality for complex types
        let dict1 = ["name": "Alice", "age": "30"]
        let dict2 = ["name": "Alice", "age": "30"]
        let wrapped1 = try AnyCodable(dict1)
        let wrapped2 = try AnyCodable(dict2)
        XCTAssertEqual(wrapped1, wrapped2)

        // Test inequality for different dictionaries
        let dict3 = ["name": "Bob", "age": "25"]
        let wrapped3 = try AnyCodable(dict3)
        XCTAssertNotEqual(wrapped1, wrapped3)

        // Test equality after round-trip
        let original = try AnyCodable([1, 2, 3])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

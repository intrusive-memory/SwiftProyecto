import XCTest
@testable import SwiftProyecto

final class FilePatternTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInit_SinglePattern() {
        let pattern = FilePattern("*.fountain")

        XCTAssertTrue(pattern.isSingle)
        XCTAssertEqual(pattern.patterns, ["*.fountain"])
    }

    func testInit_MultiplePatterns() {
        let pattern = FilePattern(["*.fountain", "*.fdx"])

        XCTAssertFalse(pattern.isSingle)
        XCTAssertEqual(pattern.patterns, ["*.fountain", "*.fdx"])
    }

    func testInit_SingleElementArray_CollapsesToSingle() {
        let pattern = FilePattern(["*.fountain"])

        XCTAssertTrue(pattern.isSingle)
        XCTAssertEqual(pattern.patterns, ["*.fountain"])
    }

    // MARK: - ExpressibleByStringLiteral Tests

    func testStringLiteral() {
        let pattern: FilePattern = "*.fountain"

        XCTAssertTrue(pattern.isSingle)
        XCTAssertEqual(pattern.patterns, ["*.fountain"])
    }

    // MARK: - ExpressibleByArrayLiteral Tests

    func testArrayLiteral_Multiple() {
        let pattern: FilePattern = ["*.fountain", "*.fdx", "*.highland"]

        XCTAssertFalse(pattern.isSingle)
        XCTAssertEqual(pattern.patterns, ["*.fountain", "*.fdx", "*.highland"])
    }

    func testArrayLiteral_Single() {
        let pattern: FilePattern = ["*.fountain"]

        XCTAssertTrue(pattern.isSingle)
        XCTAssertEqual(pattern.patterns, ["*.fountain"])
    }

    // MARK: - Codable Tests - Decoding

    func testDecode_SingleString() throws {
        let json = "\"*.fountain\""
        let data = json.data(using: .utf8)!

        let pattern = try JSONDecoder().decode(FilePattern.self, from: data)

        XCTAssertTrue(pattern.isSingle)
        XCTAssertEqual(pattern.patterns, ["*.fountain"])
    }

    func testDecode_Array() throws {
        let json = "[\"*.fountain\", \"*.fdx\"]"
        let data = json.data(using: .utf8)!

        let pattern = try JSONDecoder().decode(FilePattern.self, from: data)

        XCTAssertFalse(pattern.isSingle)
        XCTAssertEqual(pattern.patterns, ["*.fountain", "*.fdx"])
    }

    func testDecode_EmptyArray() throws {
        let json = "[]"
        let data = json.data(using: .utf8)!

        let pattern = try JSONDecoder().decode(FilePattern.self, from: data)

        XCTAssertEqual(pattern.patterns, [])
    }

    func testDecode_InvalidType_ThrowsError() {
        let json = "123"
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(FilePattern.self, from: data)) { error in
            guard let decodingError = error as? DecodingError else {
                XCTFail("Expected DecodingError")
                return
            }
            if case .typeMismatch = decodingError {
                // Expected
            } else {
                XCTFail("Expected typeMismatch error")
            }
        }
    }

    // MARK: - Codable Tests - Encoding

    func testEncode_SingleString() throws {
        let pattern: FilePattern = .single("*.fountain")

        let data = try JSONEncoder().encode(pattern)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertEqual(json, "\"*.fountain\"")
    }

    func testEncode_Array() throws {
        let pattern: FilePattern = .multiple(["*.fountain", "*.fdx"])

        let data = try JSONEncoder().encode(pattern)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertEqual(json, "[\"*.fountain\",\"*.fdx\"]")
    }

    // MARK: - Round-trip Tests

    func testRoundTrip_SingleString() throws {
        let original: FilePattern = .single("*.fountain")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FilePattern.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testRoundTrip_Array() throws {
        let original: FilePattern = .multiple(["*.fountain", "*.fdx", "*.highland"])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FilePattern.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Equatable Tests

    func testEquatable_SingleEqual() {
        let pattern1: FilePattern = .single("*.fountain")
        let pattern2: FilePattern = .single("*.fountain")

        XCTAssertEqual(pattern1, pattern2)
    }

    func testEquatable_SingleNotEqual() {
        let pattern1: FilePattern = .single("*.fountain")
        let pattern2: FilePattern = .single("*.fdx")

        XCTAssertNotEqual(pattern1, pattern2)
    }

    func testEquatable_MultipleEqual() {
        let pattern1: FilePattern = .multiple(["*.fountain", "*.fdx"])
        let pattern2: FilePattern = .multiple(["*.fountain", "*.fdx"])

        XCTAssertEqual(pattern1, pattern2)
    }

    func testEquatable_MultipleNotEqual_DifferentOrder() {
        let pattern1: FilePattern = .multiple(["*.fountain", "*.fdx"])
        let pattern2: FilePattern = .multiple(["*.fdx", "*.fountain"])

        // Order matters
        XCTAssertNotEqual(pattern1, pattern2)
    }

    func testEquatable_SingleVsMultiple() {
        let pattern1: FilePattern = .single("*.fountain")
        let pattern2: FilePattern = .multiple(["*.fountain"])

        // Different cases, even if same patterns
        XCTAssertNotEqual(pattern1, pattern2)
    }

    // MARK: - CustomStringConvertible Tests

    func testDescription_Single() {
        let pattern: FilePattern = .single("*.fountain")

        XCTAssertEqual(pattern.description, "*.fountain")
    }

    func testDescription_Multiple() {
        let pattern: FilePattern = .multiple(["*.fountain", "*.fdx"])

        XCTAssertEqual(pattern.description, "[*.fountain, *.fdx]")
    }

    // MARK: - Patterns Property Tests

    func testPatterns_Single() {
        let pattern: FilePattern = .single("*.fountain")

        XCTAssertEqual(pattern.patterns, ["*.fountain"])
    }

    func testPatterns_Multiple() {
        let pattern: FilePattern = .multiple(["file1.fountain", "file2.fountain", "file3.fountain"])

        XCTAssertEqual(pattern.patterns, ["file1.fountain", "file2.fountain", "file3.fountain"])
    }

    // MARK: - Edge Cases

    func testDecode_ArrayWithSingleElement() throws {
        let json = "[\"*.fountain\"]"
        let data = json.data(using: .utf8)!

        let pattern = try JSONDecoder().decode(FilePattern.self, from: data)

        // Decoding an array always results in .multiple, even for single element
        XCTAssertFalse(pattern.isSingle)
        XCTAssertEqual(pattern.patterns, ["*.fountain"])
    }

    func testPatternWithSpecialCharacters() {
        let pattern: FilePattern = "chapter-[0-9]*.fountain"

        XCTAssertEqual(pattern.patterns, ["chapter-[0-9]*.fountain"])
    }

    func testPatternWithPath() {
        let pattern: FilePattern = "episodes/*.fountain"

        XCTAssertEqual(pattern.patterns, ["episodes/*.fountain"])
    }

    func testExplicitFileList() {
        let pattern: FilePattern = .multiple([
            "00-prologue.fountain",
            "01-act-one.fountain",
            "02-act-two.fountain",
            "03-epilogue.fountain"
        ])

        XCTAssertEqual(pattern.patterns.count, 4)
        XCTAssertEqual(pattern.patterns[0], "00-prologue.fountain")
        XCTAssertEqual(pattern.patterns[3], "03-epilogue.fountain")
    }
}

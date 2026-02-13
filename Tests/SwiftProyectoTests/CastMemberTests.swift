import XCTest
@testable import SwiftProyecto

final class CastMemberTests: XCTestCase {

    // MARK: - Gender Enum Tests

    func testGender_RawValues() {
        XCTAssertEqual(Gender.male.rawValue, "M")
        XCTAssertEqual(Gender.female.rawValue, "F")
        XCTAssertEqual(Gender.nonBinary.rawValue, "NB")
        XCTAssertEqual(Gender.notSpecified.rawValue, "NS")
    }

    func testGender_DisplayNames() {
        XCTAssertEqual(Gender.male.displayName, "Male")
        XCTAssertEqual(Gender.female.displayName, "Female")
        XCTAssertEqual(Gender.nonBinary.displayName, "Non-Binary")
        XCTAssertEqual(Gender.notSpecified.displayName, "Not Specified")
    }

    func testGender_CaseIterable() {
        let allGenders = Gender.allCases
        XCTAssertEqual(allGenders.count, 4)
        XCTAssertTrue(allGenders.contains(.male))
        XCTAssertTrue(allGenders.contains(.female))
        XCTAssertTrue(allGenders.contains(.nonBinary))
        XCTAssertTrue(allGenders.contains(.notSpecified))
    }

    func testGender_Codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test encoding
        let maleData = try encoder.encode(Gender.male)
        let decoded = try decoder.decode(Gender.self, from: maleData)
        XCTAssertEqual(decoded, .male)

        // Test decoding from raw value
        let rawJSON = "\"NB\"".data(using: .utf8)!
        let nonBinary = try decoder.decode(Gender.self, from: rawJSON)
        XCTAssertEqual(nonBinary, .nonBinary)
    }

    // MARK: - Initialization Tests

    func testInitialization_Minimal() {
        let member = CastMember(character: "NARRATOR")

        XCTAssertEqual(member.character, "NARRATOR")
        XCTAssertNil(member.actor)
        XCTAssertNil(member.gender)
        XCTAssertEqual(member.voices, [:])
        XCTAssertEqual(member.id, "NARRATOR")
    }

    func testInitialization_WithGender() {
        let member = CastMember(
            character: "NARRATOR",
            gender: .male
        )

        XCTAssertEqual(member.character, "NARRATOR")
        XCTAssertNil(member.actor)
        XCTAssertEqual(member.gender, .male)
        XCTAssertEqual(member.voices, [:])
    }

    func testInitialization_WithAllFields() {
        let member = CastMember(
            character: "PROTAGONIST",
            actor: "Alex Jordan",
            gender: .nonBinary,
            voices: ["apple": "com.apple.voice.compact.en-US.Samantha"]
        )

        XCTAssertEqual(member.character, "PROTAGONIST")
        XCTAssertEqual(member.actor, "Alex Jordan")
        XCTAssertEqual(member.gender, .nonBinary)
        XCTAssertEqual(member.voices.count, 1)
    }

    func testInitialization_WithActor() {
        let member = CastMember(
            character: "LAO TZU",
            actor: "Jason Manino"
        )

        XCTAssertEqual(member.character, "LAO TZU")
        XCTAssertEqual(member.actor, "Jason Manino")
        XCTAssertEqual(member.voices, [:])
    }

    func testInitialization_WithVoices() {
        let member = CastMember(
            character: "COMMENTATOR",
            actor: "Sarah Mitchell",
            voices: [
                "apple": "com.apple.voice.compact.en-US.Samantha",
                "elevenlabs": "21m00Tcm4TlvDq8ikWAM"
            ]
        )

        XCTAssertEqual(member.character, "COMMENTATOR")
        XCTAssertEqual(member.actor, "Sarah Mitchell")
        XCTAssertEqual(member.voices.count, 2)
        XCTAssertEqual(member.voices["apple"], "com.apple.voice.compact.en-US.Samantha")
        XCTAssertEqual(member.voices["elevenlabs"], "21m00Tcm4TlvDq8ikWAM")
    }

    // MARK: - Convenience Properties

    func testHasVoices_True() {
        let member = CastMember(
            character: "NARRATOR",
            voices: ["apple": "com.apple.voice.compact.en-US.Aaron"]
        )

        XCTAssertTrue(member.hasVoices)
    }

    func testHasVoices_False() {
        let member = CastMember(character: "NARRATOR")

        XCTAssertFalse(member.hasVoices)
    }

    func testHasActor_True() {
        let member = CastMember(
            character: "LAO TZU",
            actor: "Tom Stovall"
        )

        XCTAssertTrue(member.hasActor)
    }

    func testHasActor_False() {
        let member = CastMember(character: "LAO TZU")

        XCTAssertFalse(member.hasActor)
    }

    func testHasActor_EmptyString() {
        let member = CastMember(
            character: "LAO TZU",
            actor: ""
        )

        XCTAssertFalse(member.hasActor)
    }

    // MARK: - voice(for:) Tests

    func testVoiceForProvider_Found() {
        let member = CastMember(
            character: "TEST",
            voices: [
                "apple": "com.apple.voice.compact.en-US.Aaron",
                "elevenlabs": "21m00Tcm4TlvDq8ikWAM"
            ]
        )
        XCTAssertEqual(member.voice(for: "apple"), "com.apple.voice.compact.en-US.Aaron")
        XCTAssertEqual(member.voice(for: "elevenlabs"), "21m00Tcm4TlvDq8ikWAM")
    }

    func testVoiceForProvider_NotFound() {
        let member = CastMember(
            character: "TEST",
            voices: ["apple": "voice1"]
        )
        XCTAssertNil(member.voice(for: "elevenlabs"))
    }

    func testVoiceForProvider_CaseInsensitive() {
        let member = CastMember(
            character: "TEST",
            voices: ["apple": "voice1"]
        )
        XCTAssertEqual(member.voice(for: "APPLE"), "voice1")
        XCTAssertEqual(member.voice(for: "Apple"), "voice1")
    }

    func testVoiceForProvider_EmptyVoices() {
        let member = CastMember(character: "TEST", voices: [:])
        XCTAssertNil(member.voice(for: "apple"))
    }

    // MARK: - providers Tests

    func testProviders_ReturnsSortedKeys() {
        let member = CastMember(
            character: "TEST",
            voices: [
                "elevenlabs": "voice2",
                "apple": "voice1",
                "qwen-tts": "voice3"
            ]
        )
        XCTAssertEqual(member.providers, ["apple", "elevenlabs", "qwen-tts"])
    }

    func testProviders_EmptyWhenNoVoices() {
        let member = CastMember(character: "TEST", voices: [:])
        XCTAssertEqual(member.providers, [])
    }

    func testProviders_SingleProvider() {
        let member = CastMember(
            character: "TEST",
            voices: ["apple": "voice1"]
        )
        XCTAssertEqual(member.providers, ["apple"])
    }

    // MARK: - Identity Tests

    func testID_BasedOnCharacter() {
        let member = CastMember(character: "BERNARD")

        XCTAssertEqual(member.id, "BERNARD")
    }

    func testID_ChangesWithCharacter() {
        var member = CastMember(character: "BERNARD")
        XCTAssertEqual(member.id, "BERNARD")

        member.character = "SYLVIA"
        XCTAssertEqual(member.id, "SYLVIA")
    }

    // MARK: - Equatable Tests

    func testEquatable_SameCharacter() {
        let member1 = CastMember(
            character: "NARRATOR",
            actor: "Tom Stovall",
            voices: ["apple": "com.apple.voice.compact.en-US.Aaron"]
        )
        let member2 = CastMember(
            character: "NARRATOR",
            actor: "Different Actor",
            voices: [:]
        )

        XCTAssertEqual(member1, member2) // Equal because character is same
    }

    func testEquatable_DifferentCharacter() {
        let member1 = CastMember(character: "NARRATOR")
        let member2 = CastMember(character: "LAO TZU")

        XCTAssertNotEqual(member1, member2)
    }

    // MARK: - Hashable Tests

    func testHashable_SameCharacter() {
        let member1 = CastMember(character: "NARRATOR", actor: "Actor 1")
        let member2 = CastMember(character: "NARRATOR", actor: "Actor 2")

        XCTAssertEqual(member1.hashValue, member2.hashValue)
    }

    func testHashable_SetDeduplication() {
        let member1 = CastMember(character: "NARRATOR", actor: "Actor 1")
        let member2 = CastMember(character: "NARRATOR", actor: "Actor 2")
        let member3 = CastMember(character: "LAO TZU")

        let set: Set<CastMember> = [member1, member2, member3]

        XCTAssertEqual(set.count, 2) // member1 and member2 deduplicated
        XCTAssertTrue(set.contains(where: { $0.character == "NARRATOR" }))
        XCTAssertTrue(set.contains(where: { $0.character == "LAO TZU" }))
    }

    // MARK: - Codable Tests

    func testCodable_EncodeAndDecode_Full() throws {
        let original = CastMember(
            character: "NARRATOR",
            actor: "Tom Stovall",
            gender: .male,
            voices: [
                "apple": "com.apple.voice.compact.en-US.Aaron",
                "elevenlabs": "21m00Tcm4TlvDq8ikWAM"
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CastMember.self, from: data)

        XCTAssertEqual(decoded.character, original.character)
        XCTAssertEqual(decoded.actor, original.actor)
        XCTAssertEqual(decoded.gender, original.gender)
        XCTAssertEqual(decoded.voices, original.voices)
    }

    func testCodable_EncodeAndDecode_Minimal() throws {
        let original = CastMember(character: "LAO TZU")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CastMember.self, from: data)

        XCTAssertEqual(decoded.character, "LAO TZU")
        XCTAssertNil(decoded.actor)
        XCTAssertNil(decoded.gender)
        XCTAssertEqual(decoded.voices, [:])
    }

    func testCodable_WithGender() throws {
        let original = CastMember(
            character: "ALEX",
            actor: "Jordan Smith",
            gender: .nonBinary
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CastMember.self, from: data)

        XCTAssertEqual(decoded.character, "ALEX")
        XCTAssertEqual(decoded.actor, "Jordan Smith")
        XCTAssertEqual(decoded.gender, .nonBinary)
    }

    // MARK: - Sendable Tests

    func testSendable() {
        Task {
            let member = CastMember(
                character: "CONCURRENT",
                actor: "Async Actor"
            )
            XCTAssertEqual(member.character, "CONCURRENT")
        }
    }

    // MARK: - Voice ID Format Tests (No Validation)

    func testVoiceIDs_ValidFormats() {
        let member = CastMember(
            character: "NARRATOR",
            voices: [
                "apple": "com.apple.voice.compact.en-US.Aaron",
                "elevenlabs": "21m00Tcm4TlvDq8ikWAM",
                "qwen-tts": "narrative-1",
                "custom-provider": "voice-123"
            ]
        )

        // All voice IDs accepted without validation
        XCTAssertEqual(member.voices.count, 4)
    }

    func testVoiceIDs_InvalidFormats_StillAccepted() {
        let member = CastMember(
            character: "NARRATOR",
            voices: [
                "provider1": "not-a-valid-uri",
                "provider2": "missing-provider/voice",
                "provider3": "",
                "provider4": "random-garbage-text"
            ]
        )

        // Invalid voice IDs are accepted (validation happens at generation time)
        XCTAssertEqual(member.voices.count, 4)
        XCTAssertEqual(member.voices["provider1"], "not-a-valid-uri")
    }

    // MARK: - Mutability Tests

    func testCharacter_Mutable() {
        var member = CastMember(character: "ORIGINAL")
        XCTAssertEqual(member.character, "ORIGINAL")

        member.character = "RENAMED"
        XCTAssertEqual(member.character, "RENAMED")
        XCTAssertEqual(member.id, "RENAMED") // ID updates
    }

    func testActor_Mutable() {
        var member = CastMember(character: "NARRATOR")
        XCTAssertNil(member.actor)

        member.actor = "Tom Stovall"
        XCTAssertEqual(member.actor, "Tom Stovall")
    }

    func testVoices_Mutable() {
        var member = CastMember(character: "NARRATOR")
        XCTAssertEqual(member.voices, [:])

        member.voices = ["apple": "com.apple.voice.compact.en-US.Aaron"]
        XCTAssertEqual(member.voices.count, 1)

        member.voices["elevenlabs"] = "21m00Tcm4TlvDq8ikWAM"
        XCTAssertEqual(member.voices.count, 2)
        XCTAssertEqual(member.voices["elevenlabs"], "21m00Tcm4TlvDq8ikWAM")
    }

    func testGender_Mutable() {
        var member = CastMember(character: "CHARACTER")
        XCTAssertNil(member.gender)

        member.gender = .male
        XCTAssertEqual(member.gender, .male)

        member.gender = .notSpecified
        XCTAssertEqual(member.gender, .notSpecified)

        member.gender = nil
        XCTAssertNil(member.gender)
    }
}

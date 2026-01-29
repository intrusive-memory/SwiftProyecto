import XCTest
@testable import SwiftProyecto

final class CastMemberTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization_Minimal() {
        let member = CastMember(character: "NARRATOR")

        XCTAssertEqual(member.character, "NARRATOR")
        XCTAssertNil(member.actor)
        XCTAssertEqual(member.voices, [])
        XCTAssertEqual(member.id, "NARRATOR")
    }

    func testInitialization_WithActor() {
        let member = CastMember(
            character: "LAO TZU",
            actor: "Jason Manino"
        )

        XCTAssertEqual(member.character, "LAO TZU")
        XCTAssertEqual(member.actor, "Jason Manino")
        XCTAssertEqual(member.voices, [])
    }

    func testInitialization_WithVoices() {
        let member = CastMember(
            character: "COMMENTATOR",
            actor: "Sarah Mitchell",
            voices: [
                "apple://en-US/Samantha",
                "elevenlabs://en/wise-elder"
            ]
        )

        XCTAssertEqual(member.character, "COMMENTATOR")
        XCTAssertEqual(member.actor, "Sarah Mitchell")
        XCTAssertEqual(member.voices.count, 2)
        XCTAssertEqual(member.voices[0], "apple://en-US/Samantha")
        XCTAssertEqual(member.voices[1], "elevenlabs://en/wise-elder")
    }

    // MARK: - Convenience Properties

    func testHasVoices_True() {
        let member = CastMember(
            character: "NARRATOR",
            voices: ["apple://en-US/Aaron"]
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

    func testPrimaryVoice_WithVoices() {
        let member = CastMember(
            character: "NARRATOR",
            voices: [
                "apple://en-US/Aaron",
                "elevenlabs://en/wise-elder"
            ]
        )

        XCTAssertEqual(member.primaryVoice, "apple://en-US/Aaron")
    }

    func testPrimaryVoice_NoVoices() {
        let member = CastMember(character: "NARRATOR")

        XCTAssertNil(member.primaryVoice)
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
            voices: ["apple://en-US/Aaron"]
        )
        let member2 = CastMember(
            character: "NARRATOR",
            actor: "Different Actor",
            voices: []
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
            voices: [
                "apple://en-US/Aaron",
                "elevenlabs://en/wise-elder"
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CastMember.self, from: data)

        XCTAssertEqual(decoded.character, original.character)
        XCTAssertEqual(decoded.actor, original.actor)
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
        XCTAssertEqual(decoded.voices, [])
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

    // MARK: - Voice URI Format Tests (No Validation)

    func testVoiceURIs_ValidFormats() {
        let member = CastMember(
            character: "NARRATOR",
            voices: [
                "apple://en-US/Aaron",
                "elevenlabs://en/wise-elder",
                "qwen://en/narrative-1",
                "custom-provider://voice-123"
            ]
        )

        // All URIs accepted without validation
        XCTAssertEqual(member.voices.count, 4)
    }

    func testVoiceURIs_InvalidFormats_StillAccepted() {
        let member = CastMember(
            character: "NARRATOR",
            voices: [
                "not-a-valid-uri",
                "missing-provider/voice",
                "",
                "random-garbage-text"
            ]
        )

        // Invalid URIs are accepted (validation happens at generation time)
        XCTAssertEqual(member.voices.count, 4)
        XCTAssertEqual(member.voices[0], "not-a-valid-uri")
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
        XCTAssertEqual(member.voices, [])

        member.voices = ["apple://en-US/Aaron"]
        XCTAssertEqual(member.voices.count, 1)

        member.voices.append("elevenlabs://en/wise-elder")
        XCTAssertEqual(member.voices.count, 2)
    }
}

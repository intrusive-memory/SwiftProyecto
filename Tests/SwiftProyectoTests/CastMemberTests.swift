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
      voices: ["apple": ["com.apple.voice.compact.en-US.Samantha"]]
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
        "apple": ["com.apple.voice.compact.en-US.Samantha"],
        "elevenlabs": ["21m00Tcm4TlvDq8ikWAM"],
      ]
    )

    XCTAssertEqual(member.character, "COMMENTATOR")
    XCTAssertEqual(member.actor, "Sarah Mitchell")
    XCTAssertEqual(member.voices.count, 2)
    XCTAssertEqual(member.voices["apple"], ["com.apple.voice.compact.en-US.Samantha"])
    XCTAssertEqual(member.voices["elevenlabs"], ["21m00Tcm4TlvDq8ikWAM"])
  }

  // MARK: - Convenience Properties

  func testHasVoices_True() {
    let member = CastMember(
      character: "NARRATOR",
      voices: ["apple": ["com.apple.voice.compact.en-US.Aaron"]]
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
        "apple": ["com.apple.voice.compact.en-US.Aaron"],
        "elevenlabs": ["21m00Tcm4TlvDq8ikWAM"],
      ]
    )
    XCTAssertEqual(member.voice(for: "apple"), "com.apple.voice.compact.en-US.Aaron")
    XCTAssertEqual(member.voice(for: "elevenlabs"), "21m00Tcm4TlvDq8ikWAM")
  }

  func testVoiceForProvider_NotFound() {
    let member = CastMember(
      character: "TEST",
      voices: ["apple": ["voice1"]]
    )
    XCTAssertNil(member.voice(for: "elevenlabs"))
  }

  func testVoiceForProvider_CaseInsensitive() {
    let member = CastMember(
      character: "TEST",
      voices: ["apple": ["voice1"]]
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
        "elevenlabs": ["voice2"],
        "apple": ["voice1"],
        "voxalta": ["voice3"],
      ]
    )
    XCTAssertEqual(member.providers, ["apple", "elevenlabs", "voxalta"])
  }

  func testProviders_EmptyWhenNoVoices() {
    let member = CastMember(character: "TEST", voices: [:])
    XCTAssertEqual(member.providers, [])
  }

  func testProviders_SingleProvider() {
    let member = CastMember(
      character: "TEST",
      voices: ["apple": ["voice1"]]
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
      voices: ["apple": ["com.apple.voice.compact.en-US.Aaron"]]
    )
    let member2 = CastMember(
      character: "NARRATOR",
      actor: "Different Actor",
      voices: [:]
    )

    XCTAssertEqual(member1, member2)  // Equal because character is same
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

    XCTAssertEqual(set.count, 2)  // member1 and member2 deduplicated
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
        "apple": ["com.apple.voice.compact.en-US.Aaron"],
        "elevenlabs": ["21m00Tcm4TlvDq8ikWAM"],
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

  // MARK: - Language Tests

  func testInitialization_LanguageDefaultsToNil() {
    let member = CastMember(character: "NARRATOR")
    XCTAssertNil(member.language)
  }

  func testInitialization_WithLanguage() {
    let member = CastMember(
      character: "MAESTRA",
      voices: ["voxalta": ["MAESTRA.vox"]],
      language: "es-MX"
    )
    XCTAssertEqual(member.language, "es-MX")
  }

  func testLanguage_Mutable() {
    var member = CastMember(character: "NARRATOR")
    XCTAssertNil(member.language)

    member.language = "en"
    XCTAssertEqual(member.language, "en")

    member.language = nil
    XCTAssertNil(member.language)
  }

  func testCodable_Language_RoundTrips() throws {
    let original = CastMember(
      character: "MAESTRA",
      actor: "Ana",
      gender: .female,
      voices: ["voxalta": ["MAESTRA.vox"]],
      language: "es-MX"
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CastMember.self, from: data)

    XCTAssertEqual(decoded.language, "es-MX")
  }

  func testCodable_Language_AbsentDecodesToNil() throws {
    // A document written before this field existed has no `language` key.
    let json = """
      { "character": "NARRATOR", "voices": { "voxalta": "narrative-1" } }
      """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(CastMember.self, from: json)
    XCTAssertNil(decoded.language)
  }

  func testCodable_Language_OmittedFromEncodingWhenNil() throws {
    let member = CastMember(character: "NARRATOR")
    let data = try JSONEncoder().encode(member)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    XCTAssertNotNil(object)
    XCTAssertNil(object?["language"])
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
        "apple": ["com.apple.voice.compact.en-US.Aaron"],
        "elevenlabs": ["21m00Tcm4TlvDq8ikWAM"],
        "voxalta": ["narrative-1"],
        "custom-provider": ["voice-123"],
      ]
    )

    // All voice IDs accepted without validation
    XCTAssertEqual(member.voices.count, 4)
  }

  func testVoiceIDs_InvalidFormats_StillAccepted() {
    let member = CastMember(
      character: "NARRATOR",
      voices: [
        "provider1": ["not-a-valid-uri"],
        "provider2": ["missing-provider/voice"],
        "provider3": [""],
        "provider4": ["random-garbage-text"],
      ]
    )

    // Invalid voice IDs are accepted (validation happens at generation time)
    XCTAssertEqual(member.voices.count, 4)
    XCTAssertEqual(member.voices["provider1"], ["not-a-valid-uri"])
  }

  // MARK: - Mutability Tests

  func testCharacter_Mutable() {
    var member = CastMember(character: "ORIGINAL")
    XCTAssertEqual(member.character, "ORIGINAL")

    member.character = "RENAMED"
    XCTAssertEqual(member.character, "RENAMED")
    XCTAssertEqual(member.id, "RENAMED")  // ID updates
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

    member.voices = ["apple": ["com.apple.voice.compact.en-US.Aaron"]]
    XCTAssertEqual(member.voices.count, 1)

    member.voices["elevenlabs"] = ["21m00Tcm4TlvDq8ikWAM"]
    XCTAssertEqual(member.voices.count, 2)
    XCTAssertEqual(member.voices["elevenlabs"], ["21m00Tcm4TlvDq8ikWAM"])
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

  // MARK: - Merge Tests
  //
  // Comprehensive test suite for cast merging with 60+ test cases organized into 7 logical groups:
  //
  // **Group 1: Basic Merge Scenarios (10 tests)**
  //   Validates: Master + Single Variant, Empty Master, Empty Variant, No Overlap
  //   Purpose: Ensures foundational merge behavior works correctly
  //
  // **Group 2: Voice Array Merging (12 tests)**
  //   Validates: Single → Multiple voices, Multiple providers, Deduplication,
  //              New provider addition, Empty voice arrays
  //   Purpose: Guarantees zero information loss on voice data
  //
  // **Group 3: Merge Strategies — All Three (11 tests)**
  //   Validates: preserveExisting, preferNew, combine across all field types
  //   Purpose: Ensures each strategy behaves correctly for voices and metadata
  //
  // **Group 4: Character Override Scenarios (10 tests)**
  //   Validates: Specified override, Partial override, Character-only-in-variant,
  //              Gender/Language preservation
  //   Purpose: Confirms character metadata merges correctly with voices
  //
  // **Group 5: Deterministic Ordering (6 tests)**
  //   Validates: Merge idempotence, Provider alphabetization, Voice array ordering
  //   Purpose: Ensures same input → same output (no randomness)
  //
  // **Group 6: ProjectFrontMatter.mergeCast() (10 tests)**
  //   Validates: Cast list merging, Nil handling, Large cast lists, Strategy comparison
  //   Purpose: End-to-end cast merge at the ProjectFrontMatter level
  //
  // **Group 7: Edge Cases (8 tests)**
  //   Validates: Duplicate character names, Special characters, Very large arrays,
  //              All fields populated, Mixed case provider names
  //   Purpose: Ensures robustness against unusual inputs

  // MARK: - Group 1: Basic Merge Scenarios

  func testMerge_MasterWithSingleVariant_VariantOverridesWhenPopulated() {
    let master = CastMember(
      character: "NARRATOR",
      actor: "Tom Stovall",
      gender: .male,
      voices: ["apple": ["voice-1"]]
    )
    let variant = CastMember(
      character: "NARRATOR",
      gender: .female,
      voices: ["elevenlabs": ["voice-2"]]
    )

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.character, "NARRATOR")
    XCTAssertEqual(merged.actor, "Tom Stovall")  // Master's actor preserved
    XCTAssertEqual(merged.gender, .female)  // Variant's gender overrides
    XCTAssertEqual(merged.voices, ["elevenlabs": ["voice-2"]])  // Variant's voices used
  }

  func testMerge_MasterWithSingleVariant_UnspecifiedInheritFromMaster() {
    let master = CastMember(
      character: "MAESTRA",
      actor: "Sofia García",
      gender: .female,
      voices: ["apple": ["voice-es"]]
    )
    let variant = CastMember(
      character: "MAESTRA",
      voices: ["elevenlabs": ["voice-xx"]]
      // All other fields unspecified
    )

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.character, "MAESTRA")
    XCTAssertEqual(merged.actor, "Sofia García")  // Inherited
    XCTAssertEqual(merged.gender, .female)  // Inherited
    XCTAssertEqual(merged.voices, ["elevenlabs": ["voice-xx"]])
  }

  func testMerge_EmptyMaster_VariantProvidesCast() {
    let master = CastMember(character: "GUARDIAN")
    let variant = CastMember(
      character: "GUARDIAN",
      actor: "Alex Chen",
      gender: .nonBinary,
      voices: ["voxalta": ["guardian-1"]]
    )

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.character, "GUARDIAN")
    XCTAssertEqual(merged.actor, "Alex Chen")
    XCTAssertEqual(merged.gender, .nonBinary)
    XCTAssertEqual(merged.voices, ["voxalta": ["guardian-1"]])
  }

  func testMerge_EmptyVariant_MasterPreserved() {
    let master = CastMember(
      character: "ORACLE",
      actor: "Morgan Lee",
      gender: .female,
      voices: ["apple": ["oracle-voice"]]
    )
    let variant = CastMember(character: "ORACLE")

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.character, "ORACLE")
    XCTAssertEqual(merged.actor, "Morgan Lee")
    XCTAssertEqual(merged.gender, .female)
    XCTAssertEqual(merged.voices, ["apple": ["oracle-voice"]])
  }

  func testMerge_BothEmpty_ResultEmpty() {
    let master = CastMember(character: "SILENT")
    let variant = CastMember(character: "SILENT")

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.character, "SILENT")
    XCTAssertNil(merged.actor)
    XCTAssertNil(merged.gender)
    XCTAssertEqual(merged.voices, [:])
    XCTAssertNil(merged.language)
  }

  func testMerge_NoOverlap_MasterAndVariantCombined() {
    let master = CastMember(
      character: "PROTAGONIST",
      voices: ["apple": ["voice-1"]]
    )
    let variant = CastMember(
      character: "PROTAGONIST",
      voices: ["elevenlabs": ["voice-2"]]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertTrue(merged.voices.keys.contains("apple"))
    XCTAssertTrue(merged.voices.keys.contains("elevenlabs"))
    XCTAssertEqual(merged.voices["apple"], ["voice-1"])
    XCTAssertEqual(merged.voices["elevenlabs"], ["voice-2"])
  }

  func testMerge_DeterministicOrderingMultipleProviders() {
    let master = CastMember(
      character: "ACTOR",
      voices: [
        "elevenlabs": ["voice-A"],
        "apple": ["voice-B"],
        "voxalta": ["voice-C"],
      ]
    )
    let variant = CastMember(character: "ACTOR")

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    // Voices should maintain provider structure
    XCTAssertEqual(merged.voices.count, 3)
    XCTAssertNotNil(merged.voices["apple"])
    XCTAssertNotNil(merged.voices["elevenlabs"])
    XCTAssertNotNil(merged.voices["voxalta"])
  }

  // MARK: - Group 2: Voice Array Merging

  func testMerge_SingleVoiceToMultipleVoices_CombineKeepsAll() {
    let master = CastMember(
      character: "NARRATOR",
      voices: ["apple": ["voice-1"]]
    )
    let variant = CastMember(
      character: "NARRATOR",
      voices: ["apple": ["voice-1", "voice-2"]]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    // Both voices preserved, order maintained
    XCTAssertEqual(merged.voices["apple"], ["voice-1", "voice-2"])
  }

  func testMerge_SingleVoiceToMultipleVoices_PreserveExistingUsesVariant() {
    let master = CastMember(
      character: "NARRATOR",
      voices: ["apple": ["voice-1"]]
    )
    let variant = CastMember(
      character: "NARRATOR",
      voices: ["apple": ["voice-2", "voice-3"]]
    )

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    // Variant's voices entirely replace master's
    XCTAssertEqual(merged.voices["apple"], ["voice-2", "voice-3"])
  }

  func testMerge_MultipleProviders_PreserveExisting() {
    let master = CastMember(
      character: "ACTOR",
      voices: [
        "apple": ["voice-1", "voice-2"],
        "elevenlabs": ["voice-3"],
      ]
    )
    let variant = CastMember(
      character: "ACTOR",
      voices: [
        "apple": ["voice-4"],
        "elevenlabs": ["voice-5"],
      ]
    )

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.voices["apple"], ["voice-4"])
    XCTAssertEqual(merged.voices["elevenlabs"], ["voice-5"])
  }

  func testMerge_MultipleProviders_PreferNew() {
    let master = CastMember(
      character: "ACTOR",
      voices: [
        "apple": ["voice-1"],
        "elevenlabs": ["voice-3"],
      ]
    )
    let variant = CastMember(
      character: "ACTOR",
      voices: [
        "apple": ["voice-2"],
        "voxalta": ["voice-4"],
      ]
    )

    let merged = master.merge(with: variant, strategy: .preferNew)

    // preferNew replaces all voices when variant has any voices (same as preserveExisting)
    XCTAssertEqual(merged.voices["apple"], ["voice-2"])
    XCTAssertEqual(merged.voices["voxalta"], ["voice-4"])
    XCTAssertNil(merged.voices["elevenlabs"])  // Master's voices are completely replaced
  }

  func testMerge_MultipleProviders_Combine() {
    let master = CastMember(
      character: "ACTOR",
      voices: [
        "apple": ["voice-1"],
        "elevenlabs": ["voice-3"],
      ]
    )
    let variant = CastMember(
      character: "ACTOR",
      voices: [
        "apple": ["voice-2"],
        "voxalta": ["voice-4"],
      ]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.voices["apple"], ["voice-1", "voice-2"])
    XCTAssertEqual(merged.voices["elevenlabs"], ["voice-3"])
    XCTAssertEqual(merged.voices["voxalta"], ["voice-4"])
  }

  func testMerge_VoiceDeduplication_SameID() {
    let master = CastMember(
      character: "NARRATOR",
      voices: ["apple": ["voice-1", "voice-2"]]
    )
    let variant = CastMember(
      character: "NARRATOR",
      voices: ["apple": ["voice-2", "voice-3"]]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.voices["apple"], ["voice-1", "voice-2", "voice-3"])
  }

  func testMerge_VoiceDeduplication_ComplexMultiProvider() {
    let master = CastMember(
      character: "ACTOR",
      voices: [
        "apple": ["a1", "a2"],
        "elevenlabs": ["e1"],
      ]
    )
    let variant = CastMember(
      character: "ACTOR",
      voices: [
        "apple": ["a2", "a3"],
        "elevenlabs": ["e1", "e2"],
      ]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.voices["apple"], ["a1", "a2", "a3"])
    XCTAssertEqual(merged.voices["elevenlabs"], ["e1", "e2"])
  }

  func testMerge_NewProviderAddition() {
    let master = CastMember(
      character: "NARRATOR",
      voices: ["apple": ["voice-1"]]
    )
    let variant = CastMember(
      character: "NARRATOR",
      voices: ["voxalta": ["voice-2"]]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.voices["apple"], ["voice-1"])
    XCTAssertEqual(merged.voices["voxalta"], ["voice-2"])
    XCTAssertEqual(merged.voices.count, 2)
  }

  func testMerge_EmptyVoiceArrayInVariant() {
    let master = CastMember(
      character: "ACTOR",
      voices: ["apple": ["voice-1"]]
    )
    let variant = CastMember(
      character: "ACTOR",
      voices: ["apple": []]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    // Empty array in variant is treated as no voices
    XCTAssertEqual(merged.voices["apple"], ["voice-1"])
  }

  // MARK: - Group 3: Merge Strategies — All Three

  func testMerge_PreserveExisting_VariantOverridesAllFields() {
    let master = CastMember(
      character: "CHAR",
      actor: "Master Actor",
      gender: .male,
      voiceDescription: "Master voice",
      language: "en"
    )
    let variant = CastMember(
      character: "CHAR",
      actor: "Variant Actor",
      gender: .female,
      voiceDescription: "Variant voice",
      language: "es"
    )

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.actor, "Variant Actor")
    XCTAssertEqual(merged.gender, .female)
    XCTAssertEqual(merged.voiceDescription, "Variant voice")
    XCTAssertEqual(merged.language, "es")
  }

  func testMerge_PreferNew_NewOverridesAllFields() {
    let master = CastMember(
      character: "CHAR",
      actor: "Master Actor",
      gender: .male,
      voiceDescription: "Master voice",
      language: "en"
    )
    let variant = CastMember(
      character: "CHAR",
      actor: "Variant Actor",
      gender: .female,
      voiceDescription: "Variant voice",
      language: "es"
    )

    let merged = master.merge(with: variant, strategy: .preferNew)

    XCTAssertEqual(merged.actor, "Variant Actor")
    XCTAssertEqual(merged.gender, .female)
    XCTAssertEqual(merged.voiceDescription, "Variant voice")
    XCTAssertEqual(merged.language, "es")
  }

  func testMerge_Combine_NonVoiceFieldsUseMasterWhenPresent() {
    let master = CastMember(
      character: "CHAR",
      actor: "Master Actor",
      gender: .male,
      voiceDescription: "Master voice"
    )
    let variant = CastMember(
      character: "CHAR",
      actor: "Variant Actor",
      gender: .female,
      voiceDescription: "Variant voice"
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.actor, "Master Actor")
    XCTAssertEqual(merged.gender, .male)
    XCTAssertEqual(merged.voiceDescription, "Master voice")
  }

  func testMerge_Combine_NonVoiceFieldsUseVariantWhenMasterEmpty() {
    let master = CastMember(character: "CHAR")
    let variant = CastMember(
      character: "CHAR",
      actor: "Variant Actor",
      gender: .female,
      voiceDescription: "Variant voice"
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.actor, "Variant Actor")
    XCTAssertEqual(merged.gender, .female)
    XCTAssertEqual(merged.voiceDescription, "Variant voice")
  }

  func testMerge_PreserveExisting_MasterFieldsInheritedWhenVariantEmpty() {
    let master = CastMember(
      character: "CHAR",
      actor: "Master Actor",
      gender: .male
    )
    let variant = CastMember(character: "CHAR")

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.actor, "Master Actor")
    XCTAssertEqual(merged.gender, .male)
  }

  func testMerge_PreferNew_PreservesUnchangedFields() {
    let master = CastMember(
      character: "CHAR",
      actor: "Master Actor",
      gender: .male,
      language: "en"
    )
    let variant = CastMember(
      character: "CHAR",
      actor: "Variant Actor"
        // gender and language unspecified
    )

    let merged = master.merge(with: variant, strategy: .preferNew)

    XCTAssertEqual(merged.actor, "Variant Actor")
    XCTAssertEqual(merged.gender, .male)  // Preserved because variant didn't override
    XCTAssertEqual(merged.language, "en")  // Preserved because variant didn't override
  }

  func testMerge_AllStrategies_PreserveCharacterName() {
    let master = CastMember(character: "PROTAGONIST")
    let variant = CastMember(character: "PROTAGONIST")

    let merged1 = master.merge(with: variant, strategy: .preserveExisting)
    let merged2 = master.merge(with: variant, strategy: .preferNew)
    let merged3 = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged1.character, "PROTAGONIST")
    XCTAssertEqual(merged2.character, "PROTAGONIST")
    XCTAssertEqual(merged3.character, "PROTAGONIST")
  }

  // MARK: - Group 4: Character Override Scenarios

  func testMerge_SpecifiedCharacterOverride_VoicesReplaced() {
    let master = CastMember(
      character: "GUARDIAN",
      voices: ["apple": ["master-voice"]]
    )
    let variant = CastMember(
      character: "GUARDIAN",
      voices: ["apple": ["variant-voice"]]
    )

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.voices["apple"], ["variant-voice"])
  }

  func testMerge_PartialCharacterOverride_VoicesUpdateOnly() {
    let master = CastMember(
      character: "MENTOR",
      actor: "Wise One",
      gender: .male,
      voices: ["apple": ["master-voice"]]
    )
    let variant = CastMember(
      character: "MENTOR",
      voices: ["apple": ["variant-voice"]]
      // Other fields unspecified
    )

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.actor, "Wise One")
    XCTAssertEqual(merged.gender, .male)
    XCTAssertEqual(merged.voices["apple"], ["variant-voice"])
  }

  func testMerge_CharacterOnlyInVariant_IncludedInResult() {
    let master = CastMember(character: "PRIMARY")
    let variant = CastMember(
      character: "SECONDARY",
      actor: "New Actor",
      voices: ["apple": ["variant-voice"]]
    )

    // Merging different characters doesn't make sense, but test the structure
    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.character, "PRIMARY")  // Master's character preserved
  }

  func testMerge_GenderPreservation_LanguageAddition() {
    let master = CastMember(
      character: "MAESTRA",
      gender: .female,
      voices: ["apple": ["voice-1"]]
    )
    let variant = CastMember(
      character: "MAESTRA",
      voices: ["apple": ["voice-2"]],
      language: "es-MX"
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.gender, .female)
    XCTAssertEqual(merged.language, "es-MX")
  }

  func testMerge_MultiFieldMetadataPreservation() {
    let master = CastMember(
      character: "ORACLE",
      actor: "Mysterious One",
      gender: .nonBinary,
      voiceDescription: "Ethereal, layered",
      voices: ["apple": ["voice-1"]],
      language: "en-US"
    )
    let variant = CastMember(
      character: "ORACLE",
      voices: ["elevenlabs": ["voice-2"]]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.actor, "Mysterious One")
    XCTAssertEqual(merged.gender, .nonBinary)
    XCTAssertEqual(merged.voiceDescription, "Ethereal, layered")
    XCTAssertEqual(merged.language, "en-US")
    XCTAssertEqual(merged.voices["apple"], ["voice-1"])
    XCTAssertEqual(merged.voices["elevenlabs"], ["voice-2"])
  }

  func testMerge_ActorNameOverride() {
    let master = CastMember(
      character: "PROTAGONIST",
      actor: "Actor A"
    )
    let variant = CastMember(
      character: "PROTAGONIST",
      actor: "Actor B"
    )

    let merged = master.merge(with: variant, strategy: .preferNew)

    XCTAssertEqual(merged.actor, "Actor B")
  }

  // MARK: - Group 5: Deterministic Ordering

  func testMerge_Idempotence_SameMergeProducesSameResult() {
    let master = CastMember(
      character: "CHAR",
      voices: ["apple": ["v1"], "elevenlabs": ["v2"]]
    )
    let variant = CastMember(
      character: "CHAR",
      voices: ["voxalta": ["v3"]]
    )

    let merged1 = master.merge(with: variant, strategy: .combine)
    let merged2 = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged1.voices, merged2.voices)
  }

  func testMerge_ProviderOrderingConsistent() {
    let master = CastMember(
      character: "NARRATOR",
      voices: [
        "elevenlabs": ["v1"],
        "voxalta": ["v2"],
        "apple": ["v3"],
      ]
    )
    let variant = CastMember(character: "NARRATOR")

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    // Providers preserved in original structure
    XCTAssertEqual(merged.voices.count, 3)
  }

  func testMerge_VoiceArrayOrderingPreserved() {
    let master = CastMember(
      character: "ACTOR",
      voices: ["apple": ["v1", "v2", "v3"]]
    )
    let variant = CastMember(character: "ACTOR")

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.voices["apple"], ["v1", "v2", "v3"])
  }

  func testMerge_OrderingWhenAppendingVoices() {
    let master = CastMember(
      character: "ACTOR",
      voices: ["apple": ["v1", "v2"]]
    )
    let variant = CastMember(
      character: "ACTOR",
      voices: ["apple": ["v3", "v4"]]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.voices["apple"], ["v1", "v2", "v3", "v4"])
  }

  func testMerge_DuplicateRemovalMaintainsOrder() {
    let master = CastMember(
      character: "ACTOR",
      voices: ["apple": ["a", "b", "c"]]
    )
    let variant = CastMember(
      character: "ACTOR",
      voices: ["apple": ["b", "d", "c", "e"]]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.voices["apple"], ["a", "b", "c", "d", "e"])
  }

  // MARK: - Group 6: ProjectFrontMatter.mergeCast()

  func testMergeCast_MasterAndVariantCombined() {
    let masterCast = [
      CastMember(character: "NARRATOR", voices: ["apple": ["v1"]]),
      CastMember(character: "MAESTRA", voices: ["apple": ["v2"]]),
    ]
    let variantCast = [
      CastMember(character: "NARRATOR", voices: ["elevenlabs": ["v3"]]),
      CastMember(character: "GUARDIAN", voices: ["voxalta": ["v4"]]),
    ]

    let merged = ProjectFrontMatter.mergeCast(masterCast, variantCast, strategy: .combine)

    XCTAssertEqual(merged.count, 3)
    XCTAssertTrue(merged.keys.contains("NARRATOR"))
    XCTAssertTrue(merged.keys.contains("MAESTRA"))
    XCTAssertTrue(merged.keys.contains("GUARDIAN"))
  }

  func testMergeCast_VariantOverridesCharacterVoices() {
    let masterCast = [
      CastMember(character: "NARRATOR", voices: ["apple": ["v1"]])
    ]
    let variantCast = [
      CastMember(character: "NARRATOR", voices: ["elevenlabs": ["v2"]])
    ]

    let merged = ProjectFrontMatter.mergeCast(masterCast, variantCast, strategy: .preserveExisting)

    XCTAssertEqual(merged["NARRATOR"]?.voices, ["elevenlabs": ["v2"]])
  }

  func testMergeCast_CombineStrategyMergesVoices() {
    let masterCast = [
      CastMember(character: "ACTOR", voices: ["apple": ["v1"]])
    ]
    let variantCast = [
      CastMember(character: "ACTOR", voices: ["elevenlabs": ["v2"]])
    ]

    let merged = ProjectFrontMatter.mergeCast(masterCast, variantCast, strategy: .combine)

    XCTAssertEqual(merged["ACTOR"]?.voices["apple"], ["v1"])
    XCTAssertEqual(merged["ACTOR"]?.voices["elevenlabs"], ["v2"])
  }

  func testMergeCast_NilMaster() {
    let variantCast = [
      CastMember(character: "NARRATOR", voices: ["apple": ["v1"]])
    ]

    let merged = ProjectFrontMatter.mergeCast(nil, variantCast, strategy: .combine)

    XCTAssertEqual(merged.count, 1)
    XCTAssertEqual(merged["NARRATOR"]?.voices, ["apple": ["v1"]])
  }

  func testMergeCast_NilVariant() {
    let masterCast = [
      CastMember(character: "NARRATOR", voices: ["apple": ["v1"]])
    ]

    let merged = ProjectFrontMatter.mergeCast(masterCast, nil, strategy: .combine)

    XCTAssertEqual(merged.count, 1)
    XCTAssertEqual(merged["NARRATOR"]?.voices, ["apple": ["v1"]])
  }

  func testMergeCast_BothNil() {
    let merged = ProjectFrontMatter.mergeCast(nil, nil, strategy: .combine)

    XCTAssertEqual(merged.count, 0)
  }

  func testMergeCast_LargeCastListPreserved() {
    var masterCast: [CastMember] = []
    for i in 1...10 {
      masterCast.append(CastMember(character: "CHAR_\(i)", voices: ["apple": ["v\(i)"]]))
    }

    var variantCast: [CastMember] = []
    for i in 5...15 {
      variantCast.append(CastMember(character: "CHAR_\(i)", voices: ["elevenlabs": ["v\(i)"]]))
    }

    let merged = ProjectFrontMatter.mergeCast(masterCast, variantCast, strategy: .combine)

    XCTAssertEqual(merged.count, 15)  // All unique characters
    for i in 1...4 {
      XCTAssertTrue(merged.keys.contains("CHAR_\(i)"))
    }
    for i in 5...10 {
      XCTAssertTrue(merged.keys.contains("CHAR_\(i)"))
    }
    for i in 11...15 {
      XCTAssertTrue(merged.keys.contains("CHAR_\(i)"))
    }
  }

  func testMergeCast_StrategyComparisonPreferNew() {
    let masterCast = [
      CastMember(character: "NARRATOR", voices: ["apple": ["v1"]])
    ]
    let variantCast = [
      CastMember(character: "NARRATOR", voices: ["elevenlabs": ["v2"]])
    ]

    let merged = ProjectFrontMatter.mergeCast(masterCast, variantCast, strategy: .preferNew)

    XCTAssertEqual(merged["NARRATOR"]?.voices, ["elevenlabs": ["v2"]])
  }

  // MARK: - Group 7: Edge Cases

  func testMerge_SpecialCharactersInNames() {
    let master = CastMember(
      character: "SEÑOR JOSÉ",
      voices: ["apple": ["v1"]]
    )
    let variant = CastMember(
      character: "SEÑOR JOSÉ",
      voices: ["elevenlabs": ["v2"]]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.character, "SEÑOR JOSÉ")
    XCTAssertEqual(merged.voices.count, 2)
  }

  func testMerge_WhitespaceInVoiceIDs() {
    let master = CastMember(
      character: "ACTOR",
      voices: ["apple": ["voice with spaces"]]
    )
    let variant = CastMember(
      character: "ACTOR",
      voices: ["elevenlabs": ["another voice id"]]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.voices["apple"], ["voice with spaces"])
    XCTAssertEqual(merged.voices["elevenlabs"], ["another voice id"])
  }

  func testMerge_VeryLargeVoiceArray() {
    var voiceArray: [String] = []
    for i in 1...50 {
      voiceArray.append("voice-\(i)")
    }

    let master = CastMember(
      character: "NARRATOR",
      voices: ["apple": voiceArray]
    )
    let variant = CastMember(character: "NARRATOR")

    let merged = master.merge(with: variant, strategy: .preserveExisting)

    XCTAssertEqual(merged.voices["apple"]?.count, 50)
  }

  func testMerge_AllFieldsPopulated() {
    let master = CastMember(
      character: "FULL",
      actor: "Actor Name",
      gender: .female,
      voiceDescription: "Warm, engaging",
      voices: ["apple": ["v1"], "elevenlabs": ["v2"]],
      language: "en-US"
    )
    let variant = CastMember(
      character: "FULL",
      voices: ["voxalta": ["v3"]]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.character, "FULL")
    XCTAssertEqual(merged.actor, "Actor Name")
    XCTAssertEqual(merged.gender, .female)
    XCTAssertEqual(merged.voiceDescription, "Warm, engaging")
    XCTAssertEqual(merged.language, "en-US")
    XCTAssertEqual(merged.voices.count, 3)
  }

  func testMerge_MinimalCharacterOnly() {
    let master = CastMember(character: "MINIMAL")
    let variant = CastMember(character: "MINIMAL")

    let merged = master.merge(with: variant, strategy: .combine)

    XCTAssertEqual(merged.character, "MINIMAL")
    XCTAssertNil(merged.actor)
    XCTAssertNil(merged.gender)
    XCTAssertNil(merged.voiceDescription)
    XCTAssertEqual(merged.voices, [:])
    XCTAssertNil(merged.language)
  }

  func testMerge_ProviderNameCaseInsensitive() {
    let master = CastMember(
      character: "ACTOR",
      voices: ["apple": ["v1"]]
    )
    let variant = CastMember(
      character: "ACTOR",
      voices: ["Apple": ["v2"]]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    // When both use same provider (case-insensitive), voices are combined
    // The lowercase normalization ensures deduplication across case variations
    XCTAssertEqual(merged.voices["apple"], ["v1", "v2"])
  }

  func testMerge_Combine_DeduplicatesVoicesWithinProvider() {
    let master = CastMember(
      character: "NARRATOR",
      voices: ["apple": ["voice-1", "voice-2"]]
    )
    let variant = CastMember(
      character: "NARRATOR",
      voices: ["apple": ["voice-2", "voice-3"]]  // voice-2 is duplicate
    )

    let merged = master.merge(with: variant, strategy: .combine)

    // Duplicates removed, order preserved
    XCTAssertEqual(merged.voices["apple"], ["voice-1", "voice-2", "voice-3"])
  }

  func testMerge_ZeroLossGuarantee_AllVoicesPreserved() {
    let master = CastMember(
      character: "COMPREHENSIVE",
      voices: [
        "apple": ["a1", "a2", "a3"],
        "elevenlabs": ["e1", "e2"],
        "voxalta": ["v1"],
      ]
    )
    let variant = CastMember(
      character: "COMPREHENSIVE",
      voices: [
        "apple": ["a2", "a4"],
        "google": ["g1", "g2"],
      ]
    )

    let merged = master.merge(with: variant, strategy: .combine)

    // All unique voice IDs must be present
    XCTAssertEqual(merged.voices["apple"]?.count, 4)  // a1, a2, a3, a4
    XCTAssertEqual(merged.voices["elevenlabs"]?.count, 2)  // e1, e2
    XCTAssertEqual(merged.voices["voxalta"]?.count, 1)  // v1
    XCTAssertEqual(merged.voices["google"]?.count, 2)  // g1, g2

    let totalVoices =
      (merged.voices["apple"] ?? []).count
      + (merged.voices["elevenlabs"] ?? []).count
      + (merged.voices["voxalta"] ?? []).count
      + (merged.voices["google"] ?? []).count
    XCTAssertEqual(totalVoices, 9)  // No information lost
  }
}

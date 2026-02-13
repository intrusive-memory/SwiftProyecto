//
//  CastMember.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// Gender specification for character roles.
///
/// Used to specify the expected or preferred gender for a character role,
/// or to indicate that gender is not a factor for the role.
public enum Gender: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    /// Male
    case male = "M"

    /// Female
    case female = "F"

    /// Non-binary
    case nonBinary = "NB"

    /// Not specified - role doesn't depend on character's gender
    case notSpecified = "NS"

    /// Display name for UI presentation
    public var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .nonBinary: return "Non-Binary"
        case .notSpecified: return "Not Specified"
        }
    }
}

/// A character-to-voice mapping for audio generation.
///
/// Maps screenplay characters to human actors and TTS voice identifiers for
/// audio generation. Voices are specified as key/value pairs where the key is
/// the provider name and the value is the voice identifier.
///
/// ## Voice Resolution
///
/// The appropriate voice is selected based on the enabled TTS provider.
/// If no voice is specified for the active provider, the default voice is used.
///
/// ## Example
///
/// ```swift
/// let narrator = CastMember(
///     character: "NARRATOR",
///     actor: "Tom Stovall",
///     gender: .male,
///     voices: [
///         "apple": "com.apple.voice.compact.en-US.Aaron",
///         "elevenlabs": "21m00Tcm4TlvDq8ikWAM",
///         "qwen-tts": "narrative-1"
///     ]
/// )
/// ```
///
/// ## YAML Representation
///
/// ```yaml
/// cast:
///   - character: NARRATOR
///     actor: Tom Stovall
///     gender: M
///     voices:
///       apple: com.apple.voice.compact.en-US.Aaron
///       elevenlabs: 21m00Tcm4TlvDq8ikWAM
/// ```
public struct CastMember: Codable, Sendable, Equatable, Hashable, Identifiable {

    /// Character name (as it appears in .fountain CHARACTER elements)
    /// Example: "NARRATOR", "LAO TZU", "COMMENTATOR"
    /// This is mutable to allow character renaming
    public var character: String

    /// Optional actor/voice artist name (for credits/reference)
    /// Example: "Tom Stovall", "Jason Manino"
    public var actor: String?

    /// Optional gender specification for the character role
    /// Defaults to .notSpecified if not provided
    public var gender: Gender?

    /// Optional description of the desired voice characteristics for this character.
    /// Used by CastMatcher to guide TTS voice selection.
    /// Example: "Deep, warm baritone with measured pacing and gravitas"
    public var voiceDescription: String?

    /// Dictionary of voice identifiers by provider.
    /// Keys are provider names (e.g., "apple", "elevenlabs"), values are voice identifiers.
    ///
    /// Examples:
    /// - "apple": "com.apple.voice.compact.en-US.Aaron"
    /// - "elevenlabs": "21m00Tcm4TlvDq8ikWAM"
    /// - "qwen-tts": "narrative-1"
    ///
    /// Invalid voice identifiers are permitted and will be handled at generation time.
    public var voices: [String: String]

    /// Unique identifier based on character name
    public var id: String { character }

    /// Create a new cast member
    public init(
        character: String,
        actor: String? = nil,
        gender: Gender? = nil,
        voiceDescription: String? = nil,
        voices: [String: String] = [:]
    ) {
        self.character = character
        self.actor = actor
        self.gender = gender
        self.voiceDescription = voiceDescription
        self.voices = voices
    }

    // MARK: - Convenience

    /// Returns true if at least one voice is assigned
    public var hasVoices: Bool {
        !voices.isEmpty
    }

    /// Returns true if actor name is assigned
    public var hasActor: Bool {
        actor != nil && !(actor?.isEmpty ?? true)
    }

    /// Get voice identifier for a specific provider.
    ///
    /// Performs case-insensitive lookup of the provider name.
    ///
    /// - Parameter provider: Provider name (e.g., "apple", "elevenlabs")
    /// - Returns: Voice identifier if found, nil otherwise
    ///
    /// ## Example
    ///
    /// ```swift
    /// let member = CastMember(
    ///     character: "NARRATOR",
    ///     voices: [
    ///         "apple": "com.apple.voice.premium.en-US.Aaron",
    ///         "elevenlabs": "21m00Tcm4TlvDq8ikWAM"
    ///     ]
    /// )
    /// if let appleVoice = member.voice(for: "apple") {
    ///     print(appleVoice) // "com.apple.voice.premium.en-US.Aaron"
    /// }
    /// ```
    public func voice(for provider: String) -> String? {
        voices[provider.lowercased()]
    }

    /// Array of all provider names that have voices assigned.
    ///
    /// Returns provider names sorted alphabetically.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let member = CastMember(
    ///     character: "NARRATOR",
    ///     voices: [
    ///         "elevenlabs": "21m00Tcm4TlvDq8ikWAM",
    ///         "apple": "com.apple.voice.premium.en-US.Aaron"
    ///     ]
    /// )
    /// print(member.providers) // ["apple", "elevenlabs"]
    /// ```
    public var providers: [String] {
        Array(voices.keys).sorted()
    }

    // MARK: - Equatable & Hashable

    /// Two cast members are equal if they have the same character name
    public static func == (lhs: CastMember, rhs: CastMember) -> Bool {
        lhs.character == rhs.character
    }

    /// Hash based on character name only
    public func hash(into hasher: inout Hasher) {
        hasher.combine(character)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case character
        case actor
        case gender
        case voiceDescription
        case voices
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        character = try container.decode(String.self, forKey: .character)
        actor = try container.decodeIfPresent(String.self, forKey: .actor)
        gender = try container.decodeIfPresent(Gender.self, forKey: .gender)
        voiceDescription = try container.decodeIfPresent(String.self, forKey: .voiceDescription)
        voices = try container.decodeIfPresent([String: String].self, forKey: .voices) ?? [:]
    }
}

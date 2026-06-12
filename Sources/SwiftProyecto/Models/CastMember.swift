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
///         "voxalta": "narrative-1"
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
  /// - "voxalta": "narrative-1"
  ///
  /// Invalid voice identifiers are permitted and will be handled at generation time.
  public var voices: [String: String]

  /// Optional per-language voice prompt overrides.
  /// Keys are BCP-47 language tags (lowercased), values are voice prompt strings.
  ///
  /// Examples:
  /// - "en": "man with a deep baritone"
  /// - "es": "hombre con voz grave"
  /// - "fr": "homme avec une voix grave"
  ///
  /// Use `voicePrompt(forLanguage:)` to resolve with fallback logic.
  public var voicePrompts: [String: String]?

  /// Unique identifier based on character name
  public var id: String { character }

  /// Create a new cast member
  public init(
    character: String,
    actor: String? = nil,
    gender: Gender? = nil,
    voiceDescription: String? = nil,
    voices: [String: String] = [:],
    voicePrompts: [String: String]? = nil
  ) {
    self.character = character
    self.actor = actor
    self.gender = gender
    self.voiceDescription = voiceDescription
    self.voices = voices
    self.voicePrompts = voicePrompts
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

  /// Returns the appropriate voice prompt string for a given BCP-47 language tag.
  ///
  /// Resolution order (first non-nil result wins):
  /// 1. Exact normalized key lookup in `voicePrompts` (trimmed, lowercased)
  /// 2. Base-language key lookup (e.g., "es" from "es-MX")
  /// 3. `voiceDescription` fallback
  /// 4. `nil` if nothing is available
  ///
  /// An empty or whitespace-only `language` string is treated as a miss and
  /// falls through to `voiceDescription`.
  ///
  /// - Parameter language: BCP-47 language tag (case-insensitive, e.g., "es-MX", "EN", "fr")
  /// - Returns: The resolved voice prompt string, or nil if none is available
  ///
  /// ## Example
  ///
  /// ```swift
  /// let member = CastMember(
  ///     character: "NARRATOR",
  ///     voiceDescription: "warm narrator",
  ///     voicePrompts: ["es": "hombre", "en": "man"]
  /// )
  /// member.voicePrompt(forLanguage: "es")    // "hombre"
  /// member.voicePrompt(forLanguage: "es-MX") // "hombre" (base fallback)
  /// member.voicePrompt(forLanguage: "ES")    // "hombre" (case-insensitive)
  /// member.voicePrompt(forLanguage: "fr")    // "warm narrator" (voiceDescription fallback)
  /// member.voicePrompt(forLanguage: "")      // "warm narrator" (empty → voiceDescription)
  /// ```
  public func voicePrompt(forLanguage language: String) -> String? {
    let normalized = language.trimmingCharacters(in: .whitespaces).lowercased()

    if !normalized.isEmpty, let prompts = voicePrompts {
      // 1. Exact normalized key
      if let exact = prompts[normalized] {
        return exact
      }

      // 2. Base-language key (e.g., "es" from "es-mx")
      let base = String(
        normalized.split(separator: "-", maxSplits: 1).first ?? Substring(normalized))
      if base != normalized, let baseMatch = prompts[base] {
        return baseMatch
      }
    }

    // 3. voiceDescription fallback
    return voiceDescription
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
    case voicePrompt
    case voiceDescription
    case voices
    case voicePrompts
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    character = try container.decode(String.self, forKey: .character)
    actor = try container.decodeIfPresent(String.self, forKey: .actor)
    gender = try container.decodeIfPresent(Gender.self, forKey: .gender)
    // Support both "voicePrompt" (preferred) and "voiceDescription" (legacy)
    voiceDescription =
      try container.decodeIfPresent(String.self, forKey: .voicePrompt)
      ?? container.decodeIfPresent(String.self, forKey: .voiceDescription)
    voices = try container.decodeIfPresent([String: String].self, forKey: .voices) ?? [:]
    voicePrompts = try container.decodeIfPresent([String: String].self, forKey: .voicePrompts)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(character, forKey: .character)
    try container.encodeIfPresent(actor, forKey: .actor)
    try container.encodeIfPresent(gender, forKey: .gender)
    try container.encodeIfPresent(voiceDescription, forKey: .voicePrompt)
    try container.encode(voices, forKey: .voices)
    try container.encodeIfPresent(voicePrompts, forKey: .voicePrompts)
  }
}

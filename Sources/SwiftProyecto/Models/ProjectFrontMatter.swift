//
//  ProjectFrontMatter.swift
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

/// Metadata extracted from PROJECT.md front matter.
///
/// PROJECT.md files use YAML front matter to store project metadata. This struct
/// provides a strongly-typed representation of that metadata.
///
/// ## Example PROJECT.md
///
/// ```markdown
/// ---
/// type: project
/// title: My Series
/// author: Jane Showrunner
/// created: 2025-11-17T10:30:00Z
/// description: A multi-episode series
/// season: 1
/// episodes: 12
/// genre: Science Fiction
/// tags: [sci-fi, drama]
/// ---
///
/// # Project Notes
///
/// Additional production notes go here...
/// ```
///
public struct ProjectFrontMatter: Codable, Sendable, Equatable {
  /// Type identifier - must be "project"
  public let type: String

  /// Project title (required)
  public let title: String

  /// Project author (required)
  public let author: String

  /// Creation date (required)
  public let created: Date

  /// Optional project description
  public let description: String?

  /// Optional season number
  public let season: Int?

  /// Optional episode count
  public let episodes: Int?

  /// Optional genre
  public let genre: String?

  /// Optional tags
  public let tags: [String]?

  // MARK: - Generation Configuration Fields

  /// Relative path to episode/screenplay files (default: "episodes")
  public let episodesDir: String?

  /// Relative path for audio output (default: "audio")
  public let audioDir: String?

  /// Glob pattern(s) or explicit file list for file discovery
  public let filePattern: FilePattern?

  /// Audio export format (default: "m4a")
  public let exportFormat: String?

  // MARK: - Cast List

  /// Character-to-voice mappings for audio generation
  /// Maps screenplay characters to actors and TTS voice URIs
  public let cast: [CastMember]?

  // MARK: - Hook Fields

  /// Shell command to run BEFORE generation
  public let preGenerateHook: String?

  /// Shell command to run AFTER generation
  public let postGenerateHook: String?

  // MARK: - TTS Configuration

  /// Optional text-to-speech generation configuration
  public let tts: TTSConfig?

  // MARK: - App-Specific Settings Storage

  /// Storage for app-specific settings sections.
  /// Keys are app section identifiers, values are type-erased settings.
  /// Internal access allows extensions to read and modify within the module.
  internal var appSections: [String: AnyCodable] = [:]

  /// Create a new ProjectFrontMatter instance.
  ///
  /// - Parameters:
  ///   - type: Type identifier (should always be "project")
  ///   - title: Project title
  ///   - author: Project author
  ///   - created: Creation date
  ///   - description: Optional project description
  ///   - season: Optional season number
  ///   - episodes: Optional episode count
  ///   - genre: Optional genre
  ///   - tags: Optional tags
  ///   - episodesDir: Relative path to episode files (default: "episodes")
  ///   - audioDir: Relative path for audio output (default: "audio")
  ///   - filePattern: Glob pattern(s) for file discovery
  ///   - exportFormat: Audio export format (default: "m4a")
  ///   - cast: Character-to-voice mappings for audio generation
  ///   - preGenerateHook: Shell command to run before generation
  ///   - postGenerateHook: Shell command to run after generation
  ///   - tts: Optional TTS generation configuration
  ///   - appSections: App-specific settings sections (default: empty)
  public init(
    type: String = "project",
    title: String,
    author: String,
    created: Date = Date(),
    description: String? = nil,
    season: Int? = nil,
    episodes: Int? = nil,
    genre: String? = nil,
    tags: [String]? = nil,
    episodesDir: String? = nil,
    audioDir: String? = nil,
    filePattern: FilePattern? = nil,
    exportFormat: String? = nil,
    cast: [CastMember]? = nil,
    preGenerateHook: String? = nil,
    postGenerateHook: String? = nil,
    tts: TTSConfig? = nil,
    appSections: [String: AnyCodable] = [:]
  ) {
    self.type = type
    self.title = title
    self.author = author
    self.created = created
    self.description = description
    self.season = season
    self.episodes = episodes
    self.genre = genre
    self.tags = tags
    self.episodesDir = episodesDir
    self.audioDir = audioDir
    self.filePattern = filePattern
    self.exportFormat = exportFormat
    self.cast = cast
    self.preGenerateHook = preGenerateHook
    self.postGenerateHook = postGenerateHook
    self.tts = tts
    self.appSections = appSections
  }

  // MARK: - Custom Codable Implementation

  private enum KnownCodingKeys: String, CodingKey, CaseIterable {
    case type, title, author, created, description, season
    case episodes, genre, tags, episodesDir, audioDir
    case filePattern, exportFormat, cast
    case preGenerateHook, postGenerateHook, tts
  }

  private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
      self.stringValue = stringValue
      self.intValue = nil
    }

    init?(intValue: Int) {
      self.stringValue = "\(intValue)"
      self.intValue = intValue
    }
  }

  public func encode(to encoder: Encoder) throws {
    // Encode all known fields
    var container = encoder.container(keyedBy: KnownCodingKeys.self)
    try container.encode(type, forKey: .type)
    try container.encode(title, forKey: .title)
    try container.encode(author, forKey: .author)
    try container.encode(created, forKey: .created)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(season, forKey: .season)
    try container.encodeIfPresent(episodes, forKey: .episodes)
    try container.encodeIfPresent(genre, forKey: .genre)
    try container.encodeIfPresent(tags, forKey: .tags)
    try container.encodeIfPresent(episodesDir, forKey: .episodesDir)
    try container.encodeIfPresent(audioDir, forKey: .audioDir)
    try container.encodeIfPresent(filePattern, forKey: .filePattern)
    try container.encodeIfPresent(exportFormat, forKey: .exportFormat)
    try container.encodeIfPresent(cast, forKey: .cast)
    try container.encodeIfPresent(preGenerateHook, forKey: .preGenerateHook)
    try container.encodeIfPresent(postGenerateHook, forKey: .postGenerateHook)
    try container.encodeIfPresent(tts, forKey: .tts)

    // Encode appSections at root level (if not empty)
    if !appSections.isEmpty {
      var rootContainer = encoder.container(keyedBy: DynamicCodingKey.self)
      for (key, value) in appSections {
        try rootContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
      }
    }
  }

  public init(from decoder: Decoder) throws {
    // Decode known fields
    let container = try decoder.container(keyedBy: KnownCodingKeys.self)
    type = try container.decode(String.self, forKey: .type)
    title = try container.decode(String.self, forKey: .title)
    author = try container.decode(String.self, forKey: .author)
    created = try container.decode(Date.self, forKey: .created)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    season = try container.decodeIfPresent(Int.self, forKey: .season)
    episodes = try container.decodeIfPresent(Int.self, forKey: .episodes)
    genre = try container.decodeIfPresent(String.self, forKey: .genre)
    tags = try container.decodeIfPresent([String].self, forKey: .tags)
    episodesDir = try container.decodeIfPresent(String.self, forKey: .episodesDir)
    audioDir = try container.decodeIfPresent(String.self, forKey: .audioDir)
    filePattern = try container.decodeIfPresent(FilePattern.self, forKey: .filePattern)
    exportFormat = try container.decodeIfPresent(String.self, forKey: .exportFormat)
    cast = try container.decodeIfPresent([CastMember].self, forKey: .cast)
    preGenerateHook = try container.decodeIfPresent(String.self, forKey: .preGenerateHook)
    postGenerateHook = try container.decodeIfPresent(String.self, forKey: .postGenerateHook)
    tts = try container.decodeIfPresent(TTSConfig.self, forKey: .tts)

    // Collect remaining keys into appSections
    let rootContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
    var sections: [String: AnyCodable] = [:]
    for key in rootContainer.allKeys {
      // Skip known keys
      if !KnownCodingKeys.allCases.contains(where: { $0.stringValue == key.stringValue }) {
        sections[key.stringValue] = try rootContainer.decode(AnyCodable.self, forKey: key)
      }
    }
    self.appSections = sections
  }
}

// MARK: - Validation

extension ProjectFrontMatter {
  /// Validate that this front matter represents a valid project.
  ///
  /// - Returns: `true` if type is "project" and required fields are present
  public var isValid: Bool {
    return type.lowercased() == "project"
      && !title.isEmpty
      && !author.isEmpty
  }
}

// MARK: - Convenience Accessors with Defaults

extension ProjectFrontMatter {
  /// Resolved episodes directory, defaulting to "episodes" if not specified.
  public var resolvedEpisodesDir: String {
    episodesDir ?? "episodes"
  }

  /// Resolved audio directory, defaulting to "audio" if not specified.
  public var resolvedAudioDir: String {
    audioDir ?? "audio"
  }

  /// Resolved file patterns, defaulting to ["*.fountain"] if not specified.
  public var resolvedFilePatterns: [String] {
    filePattern?.patterns ?? ["*.fountain"]
  }

  /// Resolved export format, defaulting to "m4a" if not specified.
  public var resolvedExportFormat: String {
    exportFormat ?? "m4a"
  }

  /// Returns true if a TTS configuration is present.
  public var hasTTSConfig: Bool {
    tts != nil
  }

  /// Returns true if any generation configuration fields are set.
  public var hasGenerationConfig: Bool {
    episodesDir != nil || audioDir != nil || filePattern != nil || exportFormat != nil
      || preGenerateHook != nil || postGenerateHook != nil
  }
}

// MARK: - Path Normalization

extension ProjectFrontMatter {

  /// Returns a copy with path-valued fields (`episodesDir`, `audioDir`) made
  /// relative to `baseDirectory` — the directory that contains (or will contain)
  /// PROJECT.md.
  ///
  /// PROJECT.md is intended to be portable: all paths it references must be
  /// interpreted relative to the file itself. This helper enforces that at the
  /// write boundary. It:
  /// - Leaves already-relative paths (no leading `/` or `~`) unchanged.
  /// - Expands leading `~` to the user's home directory, then makes it relative.
  /// - Strips the `baseDirectory` prefix from absolute paths that live inside it.
  /// - Falls back to a `../`-style traversal for absolute paths outside the base.
  ///
  /// `filePattern` (glob), `preGenerateHook`, and `postGenerateHook` (shell
  /// commands) are intentionally not touched — they are not file paths.
  ///
  /// - Parameter baseDirectory: The directory containing PROJECT.md.
  /// - Returns: A new `ProjectFrontMatter` with path fields normalized.
  public func normalizingPaths(relativeTo baseDirectory: URL) -> ProjectFrontMatter {
    ProjectFrontMatter(
      type: type,
      title: title,
      author: author,
      created: created,
      description: description,
      season: season,
      episodes: episodes,
      genre: genre,
      tags: tags,
      episodesDir: episodesDir.map { Self.makeRelative($0, to: baseDirectory) },
      audioDir: audioDir.map { Self.makeRelative($0, to: baseDirectory) },
      filePattern: filePattern,
      exportFormat: exportFormat,
      cast: cast,
      preGenerateHook: preGenerateHook,
      postGenerateHook: postGenerateHook,
      tts: tts,
      appSections: appSections
    )
  }

  /// Convert a single path string to a path relative to `baseDirectory`.
  /// Relative inputs pass through unchanged.
  static func makeRelative(_ path: String, to baseDirectory: URL) -> String {
    if path.isEmpty { return path }

    // Expand leading ~ to absolute before deciding how to relativize.
    let expanded: String
    if path.hasPrefix("~") {
      expanded = NSString(string: path).expandingTildeInPath
    } else {
      expanded = path
    }

    // Non-absolute paths are already relative to PROJECT.md — leave alone.
    guard expanded.hasPrefix("/") else { return path }

    let baseStandardized = baseDirectory.standardizedFileURL.path
    let targetStandardized = URL(fileURLWithPath: expanded).standardizedFileURL.path

    if targetStandardized == baseStandardized {
      return "."
    }
    let prefix = baseStandardized.hasSuffix("/") ? baseStandardized : baseStandardized + "/"
    if targetStandardized.hasPrefix(prefix) {
      return String(targetStandardized.dropFirst(prefix.count))
    }

    // Path lies outside baseDirectory — build a ../-style traversal.
    let baseComponents = baseStandardized.split(separator: "/").map(String.init)
    let targetComponents = targetStandardized.split(separator: "/").map(String.init)
    var commonCount = 0
    while commonCount < baseComponents.count,
      commonCount < targetComponents.count,
      baseComponents[commonCount] == targetComponents[commonCount]
    {
      commonCount += 1
    }
    let ups = Array(repeating: "..", count: baseComponents.count - commonCount)
    let downs = Array(targetComponents[commonCount...])
    let joined = (ups + downs).joined(separator: "/")
    return joined.isEmpty ? "." : joined
  }
}

// MARK: - Cast Mutation Helpers

extension ProjectFrontMatter {

  /// Create a copy of this front matter with the cast list replaced.
  ///
  /// Returns a new `ProjectFrontMatter` instance with all fields preserved
  /// except the cast, which is replaced with the provided value.
  ///
  /// **Warning**: This replaces the entire cast list. If you need to update
  /// voices for a single provider while preserving other providers' voices,
  /// use ``mergingCast(_:forProvider:)`` instead.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// let newCast = [CastMember(character: "NARRATOR", voices: ["apple": "voice-id"])]
  /// let updated = frontMatter.withCast(newCast)
  /// ```
  ///
  /// - Parameter cast: The new cast list, or `nil` to remove the cast section entirely.
  /// - Returns: A new `ProjectFrontMatter` with the updated cast.
  public func withCast(_ cast: [CastMember]?) -> ProjectFrontMatter {
    ProjectFrontMatter(
      type: type,
      title: title,
      author: author,
      created: created,
      description: description,
      season: season,
      episodes: episodes,
      genre: genre,
      tags: tags,
      episodesDir: episodesDir,
      audioDir: audioDir,
      filePattern: filePattern,
      exportFormat: exportFormat,
      cast: cast,
      preGenerateHook: preGenerateHook,
      postGenerateHook: postGenerateHook,
      tts: tts,
      appSections: appSections
    )
  }

  /// Merge cast member voices for a specific provider, preserving all other provider voices.
  ///
  /// This is the **safe** way to update cast voices. For each character in `newCast`:
  /// - If the character already exists in the current cast, the voice for `providerID`
  ///   is updated (or added), while all other provider voices are preserved.
  /// - If the character does not exist in the current cast, it is added as-is.
  ///
  /// Characters in the existing cast that are not present in `newCast` are preserved unchanged.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// // Existing cast has ElevenLabs voice for NARRATOR
  /// // newCast has Apple voice for NARRATOR
  /// let updated = frontMatter.mergingCast(newCast, forProvider: "apple")
  /// // Result: NARRATOR has both ElevenLabs and Apple voices
  /// ```
  ///
  /// ## Example
  ///
  /// ```yaml
  /// # Before: Has ElevenLabs voice
  /// cast:
  ///   - character: NARRATOR
  ///     voices:
  ///       elevenlabs: 21m00Tcm4TlvDq8ikWAM
  ///
  /// # After mergingCast with Apple provider:
  /// cast:
  ///   - character: NARRATOR
  ///     voices:
  ///       apple: com.apple.voice.premium.en-US.Aaron
  ///       elevenlabs: 21m00Tcm4TlvDq8ikWAM
  /// ```
  ///
  /// - Parameters:
  ///   - newCast: The cast members with voices to merge in. Only the voice for `providerID`
  ///     is extracted from each member.
  ///   - providerID: The provider whose voices are being updated (e.g., "apple", "elevenlabs").
  /// - Returns: A new `ProjectFrontMatter` with the merged cast.
  public func mergingCast(_ newCast: [CastMember], forProvider providerID: String)
    -> ProjectFrontMatter
  {
    let existingCast = cast ?? []

    // Build a lookup of existing cast by character name
    var mergedByCharacter: [String: CastMember] = [:]
    for member in existingCast {
      mergedByCharacter[member.character] = member
    }

    // Merge in new cast voices for the specified provider
    for newMember in newCast {
      if var existing = mergedByCharacter[newMember.character] {
        // Character exists: update only the specified provider's voice
        if let newVoice = newMember.voices[providerID] {
          existing.voices[providerID] = newVoice
        }
        mergedByCharacter[newMember.character] = existing
      } else {
        // New character: add it as-is
        mergedByCharacter[newMember.character] = newMember
      }
    }

    // Preserve original ordering: existing characters first, then new ones
    var result: [CastMember] = []
    var seen: Set<String> = []

    // Add existing characters in their original order (with merged voices)
    for member in existingCast {
      if let merged = mergedByCharacter[member.character] {
        result.append(merged)
        seen.insert(member.character)
      }
    }

    // Add new characters that were not in the existing cast
    for newMember in newCast where !seen.contains(newMember.character) {
      if let merged = mergedByCharacter[newMember.character] {
        result.append(merged)
        seen.insert(newMember.character)
      }
    }

    return withCast(result)
  }
}

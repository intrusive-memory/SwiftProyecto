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

/// Project type classification for PROJECT.md files.
///
/// Distinguishes between individual season projects and multi-season
/// overview/master documents.
public enum ProjectType: String, Codable, Sendable {
  /// Single season project
  case project

  /// Multi-season overview or master document
  case overview
}

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

  /// Last update date (optional, defaults to today on generation)
  public let updated: Date?

  /// Optional project description
  public let description: String?

  /// Backward-compat accessor for v3-style season number (computed from seasons[0]).
  public var season: Int? {
    seasons?.first?.number
  }

  /// Backward-compat accessor for v3-style episode count (computed from seasons[0]).
  public var episodes: Int? {
    seasons?.first?.episodes
  }

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

  /// Optional path to intro file (project-resolved: relative to the project root)
  public let introFile: String?

  /// Optional path to outro file (project-resolved: relative to the project root)
  public let outroFile: String?

  // MARK: - Hook Fields

  /// Shell command to run BEFORE generation
  public let preGenerateHook: String?

  /// Shell command to run AFTER generation
  public let postGenerateHook: String?

  // MARK: - TTS Configuration

  /// Optional text-to-speech generation configuration
  public let tts: TTSConfig?

  // MARK: - v4.0.0 Multi-Season / Multi-Language Fields

  /// Schema version identifier as declared by the parsed document
  /// (nil for v3.x and earlier; see ``ProjectSchemaVersion``)
  public let schemaVersion: Int?

  /// Project type: "project" for single season, "overview" for multi-season master
  public let projectType: String?

  /// Array of season definitions (for overview documents)
  public let seasons: [SeasonDefinition]?

  /// Array of language definitions (for overview documents)
  public let languages: [LanguageDefinition]?

  /// Array of variant references (for overview documents)
  public let variants: [VariantReference]?

  /// Template string for episode path resolution
  /// Example: "episodes/<language>/<season>/<episode>.<ext>"
  public let episodePath: String?

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
  ///   - season: Deprecated; use seasons array instead
  ///   - episodes: Deprecated; use seasons array instead
  ///   - genre: Optional genre
  ///   - tags: Optional tags
  ///   - episodesDir: Relative path to episode files (default: "episodes")
  ///   - audioDir: Relative path for audio output (default: "audio")
  ///   - filePattern: Glob pattern(s) for file discovery
  ///   - exportFormat: Audio export format (default: "m4a")
  ///   - introFile: Path to intro file (project-resolved: relative to the project root)
  ///   - outroFile: Path to outro file (project-resolved: relative to the project root)
  ///   - preGenerateHook: Shell command to run before generation
  ///   - postGenerateHook: Shell command to run after generation
  ///   - tts: Optional TTS generation configuration
  ///   - schemaVersion: Schema version identifier (4 for v4.0.0, nil for v3.x)
  ///   - projectType: Project type ("project" or "overview")
  ///   - seasons: Array of season definitions
  ///   - languages: Array of language definitions
  ///   - variants: Array of variant references
  ///   - episodePath: Template string for episode paths
  ///   - appSections: App-specific settings sections (default: empty)
  public init(
    type: String = "project",
    title: String,
    author: String,
    created: Date = Date(),
    updated: Date? = nil,
    description: String? = nil,
    season: Int? = nil,
    episodes: Int? = nil,
    genre: String? = nil,
    tags: [String]? = nil,
    episodesDir: String? = nil,
    audioDir: String? = nil,
    filePattern: FilePattern? = nil,
    exportFormat: String? = nil,
    introFile: String? = nil,
    outroFile: String? = nil,
    preGenerateHook: String? = nil,
    postGenerateHook: String? = nil,
    tts: TTSConfig? = nil,
    schemaVersion: Int? = nil,
    projectType: String? = nil,
    seasons: [SeasonDefinition]? = nil,
    languages: [LanguageDefinition]? = nil,
    variants: [VariantReference]? = nil,
    episodePath: String? = nil,
    appSections: [String: AnyCodable] = [:]
  ) {
    self.type = type
    self.title = title
    self.author = author
    self.created = created
    self.updated = updated
    self.description = description
    self.genre = genre
    self.tags = tags
    self.episodesDir = episodesDir
    self.audioDir = audioDir
    self.filePattern = filePattern
    self.exportFormat = exportFormat
    self.introFile = introFile
    self.outroFile = outroFile
    self.preGenerateHook = preGenerateHook
    self.postGenerateHook = postGenerateHook
    self.tts = tts
    self.schemaVersion = schemaVersion
    self.projectType = projectType

    var finalSeasons = seasons
    if finalSeasons == nil && (season != nil || episodes != nil) {
      var migratedSeasons: [SeasonDefinition] = []
      if let seasonNum = season {
        let episodeCount = episodes ?? 0
        let seasonDef = SeasonDefinition(number: seasonNum, episodes: episodeCount)
        migratedSeasons.append(seasonDef)
      }
      finalSeasons = migratedSeasons.isEmpty ? nil : migratedSeasons
    }
    self.seasons = finalSeasons

    self.languages = languages
    self.variants = variants
    self.episodePath = episodePath
    self.appSections = appSections
  }

  // MARK: - Custom Codable Implementation

  private enum KnownCodingKeys: String, CodingKey, CaseIterable {
    case type, title, author, created, updated, description, season
    case episodes, genre, tags, episodesDir, audioDir
    case filePattern, exportFormat, introFile, outroFile
    case preGenerateHook, postGenerateHook, tts
    case schemaVersion, projectType, seasons, languages, variants, episodePath
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
    var container = encoder.container(keyedBy: KnownCodingKeys.self)
    try container.encode(type, forKey: .type)
    try container.encode(title, forKey: .title)
    try container.encode(author, forKey: .author)
    try container.encode(created, forKey: .created)
    try container.encodeIfPresent(updated, forKey: .updated)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(genre, forKey: .genre)
    try container.encodeIfPresent(tags, forKey: .tags)
    try container.encodeIfPresent(episodesDir, forKey: .episodesDir)
    try container.encodeIfPresent(audioDir, forKey: .audioDir)
    try container.encodeIfPresent(filePattern, forKey: .filePattern)
    try container.encodeIfPresent(exportFormat, forKey: .exportFormat)
    try container.encodeIfPresent(introFile, forKey: .introFile)
    try container.encodeIfPresent(outroFile, forKey: .outroFile)
    try container.encodeIfPresent(preGenerateHook, forKey: .preGenerateHook)
    try container.encodeIfPresent(postGenerateHook, forKey: .postGenerateHook)
    try container.encodeIfPresent(tts, forKey: .tts)

    try container.encode(ProjectSchemaVersion.current, forKey: .schemaVersion)
    try container.encodeIfPresent(projectType, forKey: .projectType)
    try container.encodeIfPresent(seasons, forKey: .seasons)

    try container.encodeIfPresent(languages, forKey: .languages)
    try container.encodeIfPresent(variants, forKey: .variants)
    try container.encodeIfPresent(episodePath, forKey: .episodePath)

    if !appSections.isEmpty {
      var rootContainer = encoder.container(keyedBy: DynamicCodingKey.self)
      for (key, value) in appSections {
        try rootContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
      }
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: KnownCodingKeys.self)

    type = try container.decode(String.self, forKey: .type)
    title = try container.decode(String.self, forKey: .title)
    author = try container.decode(String.self, forKey: .author)
    created = try container.decode(Date.self, forKey: .created)
    updated = try container.decodeIfPresent(Date.self, forKey: .updated)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    genre = try container.decodeIfPresent(String.self, forKey: .genre)
    tags = try container.decodeIfPresent([String].self, forKey: .tags)
    episodesDir = try container.decodeIfPresent(String.self, forKey: .episodesDir)
    audioDir = try container.decodeIfPresent(String.self, forKey: .audioDir)
    filePattern = try container.decodeIfPresent(FilePattern.self, forKey: .filePattern)
    exportFormat = try container.decodeIfPresent(String.self, forKey: .exportFormat)
    introFile = try container.decodeIfPresent(String.self, forKey: .introFile)
    outroFile = try container.decodeIfPresent(String.self, forKey: .outroFile)
    preGenerateHook = try container.decodeIfPresent(String.self, forKey: .preGenerateHook)
    postGenerateHook = try container.decodeIfPresent(String.self, forKey: .postGenerateHook)
    tts = try container.decodeIfPresent(TTSConfig.self, forKey: .tts)

    let decodedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
    schemaVersion = decodedSchemaVersion

    projectType = try container.decodeIfPresent(String.self, forKey: .projectType)
    languages = try container.decodeIfPresent([LanguageDefinition].self, forKey: .languages)
    variants = try container.decodeIfPresent([VariantReference].self, forKey: .variants)
    episodePath = try container.decodeIfPresent(String.self, forKey: .episodePath)

    let v3Season = try container.decodeIfPresent(Int.self, forKey: .season)
    let v3Episodes = try container.decodeIfPresent(Int.self, forKey: .episodes)
    let decodedSeasons = try container.decodeIfPresent([SeasonDefinition].self, forKey: .seasons)

    if decodedSeasons == nil {
      var migratedSeasons: [SeasonDefinition] = []
      if let seasonNum = v3Season {
        let episodeCount = v3Episodes ?? 0
        let seasonDef = SeasonDefinition(number: seasonNum, episodes: episodeCount)
        migratedSeasons.append(seasonDef)
      }
      seasons = migratedSeasons.isEmpty ? nil : migratedSeasons
    } else {
      seasons = decodedSeasons
    }

    let rootContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
    var sections: [String: AnyCodable] = [:]
    for key in rootContainer.allKeys {
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
  /// Checks that type is "project" and required fields are present.
  /// Season information is optional.
  ///
  /// - Returns: `true` if type is "project" and title/author are non-empty
  public var isValid: Bool {
    return type.lowercased() == "project"
      && !title.isEmpty
      && !author.isEmpty
  }
}

// MARK: - Version Detection & Backward Compatibility

extension ProjectFrontMatter {

  /// Detect the schema version of this ProjectFrontMatter.
  /// - Returns: the declared `schemaVersion`, or 3 when the document
  ///   predates schema versioning (see ``ProjectSchemaVersion``)
  public func detectedSchemaVersion() -> Int {
    schemaVersion ?? 3
  }

  /// Returns true if this was originally a v3.x format file.
  /// Note: Internally normalized to the current schema, but this tracks the origin.
  public var isLegacyV3Format: Bool {
    schemaVersion == nil
  }

  /// Returns true when the parsed document carried a legacy `cast:` block.
  ///
  /// Since schema v5, `cast:` is not a declared key — a roster found in an
  /// older PROJECT.md is swept into the unknown-key store and preserved on
  /// write (structurally intact; a full re-emit reformats and relocates it).
  /// This flag is the migration trigger: the `proyecto`
  /// CLI uses it to decide when to hand the block to `reparto import` and,
  /// only after the produced CAST.md is verified, remove it from this file.
  public var hasLegacyCastKey: Bool {
    appSections["cast"] != nil
  }

  /// The `character:` names found in a legacy `cast:` block, in document order.
  ///
  /// This is deliberately the *only* reading SwiftProyecto ever does of a
  /// legacy cast block — just enough for the CLI's post-`reparto import`
  /// verification that every character survived the transfer. The block is
  /// otherwise opaque; SwiftProyecto no longer models cast (that is
  /// SwiftReparto's domain).
  public var legacyCastCharacterNames: [String] {
    struct LegacyCastEntry: Codable {
      let character: String?
    }
    guard let castValue = appSections["cast"],
      let members = try? castValue.decode([LegacyCastEntry].self)
    else { return [] }
    return members.compactMap(\.character)
  }

  /// Returns a copy with the legacy `cast:` block removed from the
  /// unknown-key store.
  ///
  /// Callers must only use this after cast data has been verifiably migrated
  /// to CAST.md — dropping the block without that verification is exactly the
  /// data loss the preservation mechanism exists to prevent.
  public func removingLegacyCastKey() -> ProjectFrontMatter {
    var copy = self
    copy.appSections["cast"] = nil
    return copy
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
      updated: updated,
      description: description,
      genre: genre,
      tags: tags,
      episodesDir: episodesDir.map { Self.makeRelative($0, to: baseDirectory) },
      audioDir: audioDir.map { Self.makeRelative($0, to: baseDirectory) },
      filePattern: filePattern,
      exportFormat: exportFormat,
      introFile: introFile.map { Self.makeRelative($0, to: baseDirectory) },
      outroFile: outroFile.map { Self.makeRelative($0, to: baseDirectory) },
      preGenerateHook: preGenerateHook,
      postGenerateHook: postGenerateHook,
      tts: tts,
      schemaVersion: schemaVersion,
      projectType: projectType,
      seasons: seasons,
      languages: languages,
      variants: variants,
      episodePath: episodePath,
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

// MARK: - Intro/Outro Asset Information

/// Information about intro and outro assets for a project or variant.
///
/// Tracks both the resolved file paths and whether files exist on disk.
/// Missing files generate warnings but don't block generation (non-blocking).
///
/// ## Usage
///
/// ```swift
/// let assets = frontMatter.resolvedIntroOutroAssets(
///   forSeason: 1,
///   withMaster: masterFrontMatter,
///   episodesDir: "episodes",
///   baseDirectory: projectURL
/// )
///
/// if let intro = assets.introPath {
///   print("Intro file: \(intro)")
/// }
/// if assets.isIntroMissing {
///   print("Warning: Intro file specified but not found")
/// }
/// ```
public struct IntroOutroAssets: Sendable, Equatable {
  /// Resolved path to intro file, relative to episodesDir
  /// nil if not specified at any level
  public let introPath: String?

  /// Resolved path to outro file, relative to episodesDir
  /// nil if not specified at any level
  public let outroPath: String?

  /// True if intro file is specified in PROJECT but doesn't exist on disk
  /// Used for warnings (non-blocking)
  public let isIntroMissing: Bool

  /// True if outro file is specified in PROJECT but doesn't exist on disk
  /// Used for warnings (non-blocking)
  public let isOutroMissing: Bool

  /// Create a new IntroOutroAssets instance
  public init(
    introPath: String? = nil,
    outroPath: String? = nil,
    isIntroMissing: Bool = false,
    isOutroMissing: Bool = false
  ) {
    self.introPath = introPath
    self.outroPath = outroPath
    self.isIntroMissing = isIntroMissing
    self.isOutroMissing = isOutroMissing
  }
}

// MARK: - Intro/Outro Resolution

extension ProjectFrontMatter {

  /// Resolve the intro file using the property hierarchy.
  ///
  /// Resolves the path using: variant > season > master > none
  ///
  /// - Parameters:
  ///   - forSeason: Season number (for looking up season-level override)
  ///   - withMaster: Master ProjectFrontMatter (for inheritance)
  ///
  /// - Returns: Resolved intro file path (relative to episodesDir), or nil if unspecified
  public func resolvedIntroFile(
    forSeason season: Int,
    withMaster master: ProjectFrontMatter
  ) -> String? {
    // Resolve hierarchy: self > season > master > nil
    if let introFile = introFile {
      return introFile
    }

    if let seasonDef = master.seasons?.first(where: { $0.number == season }) {
      if let introFile = seasonDef.introFile {
        return introFile
      }
    }

    return master.introFile
  }

  /// Resolve the outro file using the property hierarchy.
  ///
  /// Resolves the path using: variant > season > master > none
  ///
  /// - Parameters:
  ///   - forSeason: Season number (for looking up season-level override)
  ///   - withMaster: Master ProjectFrontMatter (for inheritance)
  ///
  /// - Returns: Resolved outro file path (relative to episodesDir), or nil if unspecified
  public func resolvedOutroFile(
    forSeason season: Int,
    withMaster master: ProjectFrontMatter
  ) -> String? {
    // Resolve hierarchy: self > season > master > nil
    if let outroFile = outroFile {
      return outroFile
    }

    if let seasonDef = master.seasons?.first(where: { $0.number == season }) {
      if let outroFile = seasonDef.outroFile {
        return outroFile
      }
    }

    return master.outroFile
  }

  /// Combined resolution of both intro and outro files.
  ///
  /// - Parameters:
  ///   - forSeason: Season number
  ///   - withMaster: Master ProjectFrontMatter
  ///   - episodesDir: Directory containing episodes (for relative path interpretation)
  ///   - baseDirectory: Base directory for file existence checks
  ///
  /// - Returns: IntroOutroAssets with resolved paths and missing file flags
  public func resolvedIntroOutroAssets(
    forSeason season: Int,
    withMaster master: ProjectFrontMatter,
    episodesDir: String,
    baseDirectory: URL
  ) -> IntroOutroAssets {
    // Resolve intro and outro paths using hierarchy
    let introPath = resolvedIntroFile(forSeason: season, withMaster: master)
    let outroPath = resolvedOutroFile(forSeason: season, withMaster: master)

    // Check if files exist on disk
    let isIntroMissing: Bool
    if let intro = introPath {
      let introURL = baseDirectory.appendingPathComponent(episodesDir).appendingPathComponent(intro)
      isIntroMissing = !FileManager.default.fileExists(atPath: introURL.path)
    } else {
      isIntroMissing = false
    }

    let isOutroMissing: Bool
    if let outro = outroPath {
      let outroURL = baseDirectory.appendingPathComponent(episodesDir).appendingPathComponent(outro)
      isOutroMissing = !FileManager.default.fileExists(atPath: outroURL.path)
    } else {
      isOutroMissing = false
    }

    return IntroOutroAssets(
      introPath: introPath,
      outroPath: outroPath,
      isIntroMissing: isIntroMissing,
      isOutroMissing: isOutroMissing
    )
  }
}

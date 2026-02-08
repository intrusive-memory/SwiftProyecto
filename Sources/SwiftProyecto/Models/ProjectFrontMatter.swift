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
    /// Internal access allows extensions to read, private(set) prevents external modification.
    internal private(set) var appSections: [String: AnyCodable] = [:]

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

public extension ProjectFrontMatter {
    /// Validate that this front matter represents a valid project.
    ///
    /// - Returns: `true` if type is "project" and required fields are present
    var isValid: Bool {
        return type.lowercased() == "project"
            && !title.isEmpty
            && !author.isEmpty
    }
}

// MARK: - Convenience Accessors with Defaults

public extension ProjectFrontMatter {
    /// Resolved episodes directory, defaulting to "episodes" if not specified.
    var resolvedEpisodesDir: String {
        episodesDir ?? "episodes"
    }

    /// Resolved audio directory, defaulting to "audio" if not specified.
    var resolvedAudioDir: String {
        audioDir ?? "audio"
    }

    /// Resolved file patterns, defaulting to ["*.fountain"] if not specified.
    var resolvedFilePatterns: [String] {
        filePattern?.patterns ?? ["*.fountain"]
    }

    /// Resolved export format, defaulting to "m4a" if not specified.
    var resolvedExportFormat: String {
        exportFormat ?? "m4a"
    }

    /// Returns true if a TTS configuration is present.
    var hasTTSConfig: Bool {
        tts != nil
    }

    /// Returns true if any generation configuration fields are set.
    var hasGenerationConfig: Bool {
        episodesDir != nil ||
            audioDir != nil ||
            filePattern != nil ||
            exportFormat != nil ||
            preGenerateHook != nil ||
            postGenerateHook != nil
    }
}

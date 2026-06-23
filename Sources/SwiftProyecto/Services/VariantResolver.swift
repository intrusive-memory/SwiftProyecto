//
//  VariantResolver.swift
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

/// Service for resolving variant properties using hierarchy-based inheritance.
///
/// The resolution hierarchy is: variant > season > master > default
///
/// Properties cascade downward: if a variant doesn't specify a property,
/// it inherits from the season definition, then from the master.
///
/// This service is critical for multi-season, multi-language projects where
/// properties can be defined at any level and inherited downward with zero
/// information loss.
public class VariantResolver {
  /// Resolves a single property at a specific level using the hierarchy.
  ///
  /// Uses a closure-based approach to extract the property from each level,
  /// checking in order: variant → season → master → default.
  ///
  /// - Parameters:
  ///   - property: A closure that extracts the property from ProjectFrontMatter
  ///   - variant: The variant (lowest level)
  ///   - season: The season definition (middle level)
  ///   - master: The master project (highest level)
  ///   - default: The default value if property is unspecified at all levels
  ///
  /// - Returns: The property value from the lowest level where it's specified,
  ///           or the default if unspecified at all levels
  public static func resolveProperty<T>(
    _ property: (ProjectFrontMatter) -> T?,
    variant: ProjectFrontMatter,
    season: SeasonDefinition?,
    master: ProjectFrontMatter,
    default: T? = nil
  ) -> T? {
    // Check variant first (highest priority)
    if let value = property(variant) {
      return value
    }

    // Check master (since SeasonDefinition doesn't have a generic getter,
    // seasonal property overrides are handled separately in resolve())
    if let value = property(master) {
      return value
    }

    // Return default
    return `default`
  }

  /// Resolves a full ProjectFrontMatter by merging variant, season, and master.
  ///
  /// Returns a new ProjectFrontMatter with all properties resolved using
  /// hierarchy-based inheritance:
  /// - variant > season > master > default
  ///
  /// Special handling for cast: uses zero-loss merge strategy where:
  /// - Specified characters use variant/season values
  /// - Unspecified characters inherit from master
  /// - All voice information is preserved
  ///
  /// - Parameters:
  ///   - variant: The variant PROJECT.md (may be incomplete)
  ///   - master: The master PROJECT.md (complete reference)
  ///   - season: The season number (for looking up in master's seasons[])
  ///
  /// - Returns: A new ProjectFrontMatter with all properties resolved
  public static func resolve(
    variant: ProjectFrontMatter,
    withMaster master: ProjectFrontMatter,
    forSeason season: Int
  ) -> ProjectFrontMatter {
    // Find the season definition in master.seasons[] matching the season number
    let seasonDef = master.seasons?.first { $0.number == season }

    // Helper to check if a value is "effectively nil" (nil or empty collection)
    func isEffectivelyNil<T>(_ value: T?) -> Bool {
      if let collection = value as? (any Collection) {
        return collection.isEmpty
      }
      return value == nil
    }

    // Resolve simple properties with hierarchy: variant > season > master > default
    let resolvedDescription = variant.description ?? seasonDef?.description ?? master.description
    let resolvedGenre = variant.genre ?? master.genre
    let resolvedTags = isEffectivelyNil(variant.tags)
      ? master.tags
      : variant.tags

    // Resolve generation configuration properties
    let resolvedEpisodesDir = variant.episodesDir
      ?? seasonDef?.episodesDir
      ?? master.episodesDir
    let resolvedAudioDir = variant.audioDir
      ?? master.audioDir
    let resolvedFilePattern = variant.filePattern
      ?? seasonDef?.filePattern
      ?? master.filePattern
    let resolvedExportFormat = variant.exportFormat ?? master.exportFormat

    // Resolve hook commands - hierarchy: variant > master (no season-level override)
    let resolvedPreGenerateHook = variant.preGenerateHook ?? master.preGenerateHook
    let resolvedPostGenerateHook = variant.postGenerateHook ?? master.postGenerateHook

    // Resolve TTS configuration
    let resolvedTTS = variant.tts ?? seasonDef?.tts ?? master.tts

    // Resolve intro/outro files - hierarchy: variant > season > master > nil
    let resolvedIntroFile = variant.introFile
      ?? seasonDef?.introFile
      ?? master.introFile
    let resolvedOutroFile = variant.outroFile
      ?? seasonDef?.outroFile
      ?? master.outroFile

    // Resolve cast with special merge logic
    let resolvedCast = resolveCast(
      variant: variant.cast,
      seasonCast: seasonDef?.cast,
      masterCast: master.cast
    )

    // Create and return the resolved ProjectFrontMatter
    return ProjectFrontMatter(
      type: variant.type,
      title: master.title,  // Immutable: always from master
      author: master.author,  // Immutable: always from master
      created: master.created,  // Immutable: always from master
      description: resolvedDescription,
      genre: resolvedGenre,
      tags: resolvedTags,
      episodesDir: resolvedEpisodesDir,
      audioDir: resolvedAudioDir,
      filePattern: resolvedFilePattern,
      exportFormat: resolvedExportFormat,
      introFile: resolvedIntroFile,
      outroFile: resolvedOutroFile,
      cast: resolvedCast,
      preGenerateHook: resolvedPreGenerateHook,
      postGenerateHook: resolvedPostGenerateHook,
      tts: resolvedTTS,
      schemaVersion: master.schemaVersion,
      projectType: variant.projectType ?? master.projectType,
      seasons: master.seasons,  // Preserve master's season definitions
      languages: master.languages,  // Preserve master's language definitions
      variants: master.variants,  // Preserve master's variant references
      episodePath: variant.episodePath ?? master.episodePath,
      appSections: variant.appSections.isEmpty ? master.appSections : variant.appSections
    )
  }

  // MARK: - Cast Resolution

  /// Resolves cast with zero-loss merge strategy.
  ///
  /// Implements cast inheritance where:
  /// - Characters specified in variant override master/season
  /// - Characters in season override master
  /// - Characters only in master are inherited
  /// - All voice information is preserved (zero-loss guarantee)
  ///
  /// - Parameters:
  ///   - variant: Cast members defined at variant level (lowest)
  ///   - seasonCast: Cast members defined at season level (middle)
  ///   - masterCast: Cast members defined at master level (highest)
  ///
  /// - Returns: Array of cast members with all levels resolved
  private static func resolveCast(
    variant: [CastMember]?,
    seasonCast: [CastMember]?,
    masterCast: [CastMember]?
  ) -> [CastMember]? {
    // If no cast at any level, return nil
    guard masterCast != nil || seasonCast != nil || variant != nil else {
      return nil
    }

    // Build a dictionary keyed by character name, starting from master
    var resolvedByCharacter: [String: CastMember] = [:]

    // Add all master cast members
    if let master = masterCast {
      for member in master {
        resolvedByCharacter[member.character] = member
      }
    }

    // Merge in season cast using combine strategy (preserves all voices)
    if let season = seasonCast {
      for seasonMember in season {
        if let masterMember = resolvedByCharacter[seasonMember.character] {
          // Character exists in master: merge using combine strategy
          resolvedByCharacter[seasonMember.character] = masterMember.merge(
            with: seasonMember,
            strategy: .combine
          )
        } else {
          // New character at season level: add as-is
          resolvedByCharacter[seasonMember.character] = seasonMember
        }
      }
    }

    // Merge in variant cast using combine strategy (preserves all voices)
    if let variantCast = variant {
      for variantMember in variantCast {
        if let existingMember = resolvedByCharacter[variantMember.character] {
          // Character exists: merge using combine strategy
          resolvedByCharacter[variantMember.character] = existingMember.merge(
            with: variantMember,
            strategy: .combine
          )
        } else {
          // New character at variant level: add as-is
          resolvedByCharacter[variantMember.character] = variantMember
        }
      }
    }

    // Preserve ordering: master first, then season, then variant
    var result: [CastMember] = []
    var seen: Set<String> = []

    // Add master cast in original order (with merged content)
    if let master = masterCast {
      for member in master {
        if let resolved = resolvedByCharacter[member.character] {
          result.append(resolved)
          seen.insert(member.character)
        }
      }
    }

    // Add season-only cast in original season order
    if let season = seasonCast {
      for member in season where !seen.contains(member.character) {
        if let resolved = resolvedByCharacter[member.character] {
          result.append(resolved)
          seen.insert(member.character)
        }
      }
    }

    // Add variant-only cast in original variant order
    if let variantCast = variant {
      for member in variantCast where !seen.contains(member.character) {
        if let resolved = resolvedByCharacter[member.character] {
          result.append(resolved)
          seen.insert(member.character)
        }
      }
    }

    return result.isEmpty ? nil : result
  }
}

// MARK: - Instance Method Extension

extension ProjectFrontMatter {
  /// Resolve this variant by inheriting properties from a master ProjectFrontMatter.
  ///
  /// This method assumes the current ProjectFrontMatter represents a variant
  /// (e.g., language-specific or season-specific child) and merges its properties
  /// with the master's using hierarchy-based inheritance.
  ///
  /// The resolution hierarchy is:
  /// 1. Variant properties (if specified)
  /// 2. Season-level properties (if season is defined)
  /// 3. Master properties (fallback)
  /// 4. Default values (if none specified)
  ///
  /// ## Example
  ///
  /// ```swift
  /// let master = ProjectFrontMatter(
  ///   title: "My Series",
  ///   author: "Jane Doe",
  ///   created: Date(),
  ///   audioDir: "master-audio",
  ///   seasons: [SeasonDefinition(number: 1, episodes: 12, audioDir: "season1-audio")]
  /// )
  ///
  /// let variant = ProjectFrontMatter(
  ///   title: "Variant",
  ///   author: "Jane Doe",
  ///   created: Date(),
  ///   audioDir: "variant-audio"
  /// )
  ///
  /// let resolved = variant.resolve(withMaster: master, forSeason: 1)
  /// // result.audioDir == "variant-audio"
  /// // result.title == "My Series" (from master)
  /// ```
  ///
  /// - Parameters:
  ///   - master: The master ProjectFrontMatter to inherit from
  ///   - season: The season number for looking up season-level overrides
  ///
  /// - Returns: A new ProjectFrontMatter with properties fully resolved
  public func resolve(withMaster master: ProjectFrontMatter, forSeason season: Int) -> ProjectFrontMatter {
    VariantResolver.resolve(variant: self, withMaster: master, forSeason: season)
  }
}

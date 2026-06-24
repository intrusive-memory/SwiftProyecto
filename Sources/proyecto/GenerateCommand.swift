//
//  GenerateCommand.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import ArgumentParser
import Foundation
import SwiftProyecto

/// Generate output files for a PROJECT.md file with multi-season support.
///
/// Detects v4.0.0 schema and iterates over seasons[] array, generating
/// output for each season with proper property resolution using the
/// variant resolution hierarchy: variant > season > master > default.
struct GenerateCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "generate",
    abstract: "Generate output files for a PROJECT.md with multi-season support",
    discussion: """
      Generates output files (intro/outro) for a PROJECT.md file.

      For v4.0.0 multi-season projects, iterates over all seasons and generates
      season-specific output using hierarchy-based property resolution.

      For v3.x single-season projects, generates output for the single season.

      Examples:
        proyecto generate                                    # Generate for current directory
        proyecto generate /path/to/project                   # Generate for specific directory
        proyecto generate --season 2                         # Generate only season 2
        proyecto generate --language es                      # Generate only Spanish variant
        proyecto generate --season 2 --language es           # Generate season 2 in Spanish
        proyecto generate --intro-only                       # Generate intro files only
        proyecto generate --season 1 --outro-only            # Generate outro only for season 1
        proyecto generate --list                             # List variants (v4 only)
      """
  )

  @Argument(
    help:
      "Path to directory containing PROJECT.md or path to PROJECT.md file (default: current directory)"
  )
  var path: String?

  @Option(
    name: .long,
    help: "Limit generation to specific season number (optional)"
  )
  var season: Int?

  @Option(
    name: .long,
    help: "Limit generation to specific language variant (e.g., 'en', 'es')"
  )
  var language: String?

  @Flag(
    name: .long,
    help: "Generate intro files only (skip episodes and outro)"
  )
  var introOnly: Bool = false

  @Flag(
    name: .long,
    help: "Generate outro files only (skip episodes and intro)"
  )
  var outroOnly: Bool = false

  @Flag(name: .shortAndLong, help: "Suppress progress output")
  var quiet: Bool = false

  @Flag(name: .shortAndLong, help: "Show verbose output with resolved properties per season")
  var verbose: Bool = false

  @Flag(
    name: .long,
    help: "List variants with episode counts, intro/outro presence, and status (v4 schema only)"
  )
  var list: Bool = false

  mutating func run() async throws {
    // Validate flag combinations
    if introOnly && outroOnly {
      throw ValidationError("Cannot use both --intro-only and --outro-only")
    }

    // If --list flag is specified, show variants and exit
    if list {
      try await showVariantsList()
      return
    }

    // Resolve path
    let inputPath = path ?? FileManager.default.currentDirectoryPath
    let inputURL = URL(fileURLWithPath: inputPath).standardizedFileURL

    // Determine if path is a directory or file
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDir) else {
      throw GenerateError.directoryNotFound(inputURL.path)
    }

    // Get PROJECT.md file URL
    let projectMdURL: URL
    if isDir.boolValue {
      projectMdURL = inputURL.appendingPathComponent("PROJECT.md")
    } else if inputURL.lastPathComponent == "PROJECT.md" {
      projectMdURL = inputURL
    } else {
      throw GenerateError.invalidPath(
        "Path must be a directory containing PROJECT.md or a PROJECT.md file")
    }

    // Check if PROJECT.md exists
    guard FileManager.default.fileExists(atPath: projectMdURL.path) else {
      throw GenerateError.projectMdNotFound(projectMdURL.path)
    }

    // Parse the project file
    let parser = ProjectMarkdownParser()
    do {
      let (projectFrontMatter, _) = try parser.parse(fileURL: projectMdURL)

      if !quiet {
        print("Generating output for: \(projectMdURL.path)")
      }

      // Detect schema version and get seasons to process
      let isV4 = projectFrontMatter.schemaVersion == 4
      let projectDirectory = projectMdURL.deletingLastPathComponent()

      // Get seasons to process
      let seasonsToProcess = try getSeasonsTogenerate(
        from: projectFrontMatter,
        requestedSeason: season,
        requestedLanguage: language,
        isV4: isV4
      )

      if seasonsToProcess.isEmpty {
        throw GenerateError.noSeasonsFound(
          season != nil
            ? "No season found with number \(season!)"
            : "No seasons defined in PROJECT.md"
        )
      }

      if !quiet {
        let seasonStr = seasonsToProcess.map { String($0.number) }.joined(separator: ", ")
        print("ℹ Seasons to generate: \(seasonStr)")
      }

      // Generate output for each season
      var successCount = 0
      for seasonDef in seasonsToProcess {
        do {
          try await generateForSeason(
            season: seasonDef,
            project: projectFrontMatter,
            projectDirectory: projectDirectory,
            isV4: isV4,
            quiet: quiet,
            verbose: verbose
          )
          successCount += 1
        } catch {
          if !quiet {
            print("✗ Failed to generate season \(seasonDef.number): \(error.localizedDescription)")
          }
          throw GenerateError.seasonGenerationFailed(seasonDef.number, error)
        }
      }

      if !quiet {
        print("✓ Generated output for \(successCount) season(s)")
      }

    } catch let error as ProjectMarkdownParser.ParserError {
      throw GenerateError.parseError(
        "Failed to parse PROJECT.md: \(error.localizedDescription)")
    } catch {
      throw error
    }
  }

  // MARK: - Helper Methods

  /// Determine which seasons to process based on project version and filters.
  private func getSeasonsTogenerate(
    from project: ProjectFrontMatter,
    requestedSeason: Int?,
    requestedLanguage: String?,
    isV4: Bool
  ) throws -> [SeasonDefinition] {
    // Validate language filter if provided
    if let langCode = requestedLanguage {
      // Check if language exists in the project
      let availableLanguages = project.languages?.map { $0.code } ?? []
      let availableVariants = project.variants?.map { $0.language } ?? []
      let knownLanguages = Set(availableLanguages + availableVariants)

      if !knownLanguages.isEmpty && !knownLanguages.contains(langCode) {
        throw GenerateError.languageNotFound(langCode, availableLanguages: Array(knownLanguages))
      }
    }

    // For v4.0.0 multi-season projects
    if isV4, let seasons = project.seasons, !seasons.isEmpty {
      if let requested = requestedSeason {
        // Filter to specific season
        guard let seasonDef = seasons.first(where: { $0.number == requested }) else {
          throw GenerateError.seasonNotFound(requested)
        }
        return [seasonDef]
      }
      // Return all seasons
      return seasons
    }

    // For v3.x backward compatibility, create a synthetic season from season/episodes fields
    let seasonNum = project.season ?? 1
    let episodeCount = project.episodes ?? 0
    let seasonDef = SeasonDefinition(number: seasonNum, episodes: episodeCount)

    if let requested = requestedSeason {
      // Check if requested season matches the single v3 season
      if requested == seasonNum {
        return [seasonDef]
      } else {
        throw GenerateError.seasonNotFound(requested)
      }
    }
    return [seasonDef]
  }

  /// Generate output for a specific season.
  private func generateForSeason(
    season: SeasonDefinition,
    project: ProjectFrontMatter,
    projectDirectory: URL,
    isV4: Bool,
    quiet: Bool,
    verbose: Bool
  ) async throws {
    if !quiet {
      print("Generating season \(season.number)...", terminator: "")
    }

    // For v4.0.0, resolve properties per season using VariantResolver
    let resolvedProject: ProjectFrontMatter
    if isV4 {
      // Create a variant that inherits from the master
      let variant = ProjectFrontMatter(
        type: project.type,
        title: project.title,
        author: project.author,
        created: project.created
      )
      resolvedProject = variant.resolve(withMaster: project, forSeason: season.number)
    } else {
      resolvedProject = project
    }

    // Get resolved intro/outro paths from the project
    let introFile = resolvedProject.introFile ?? season.introFile
    let outroFile = resolvedProject.outroFile ?? season.outroFile

    // Generate intro file if specified and not --outro-only
    if !outroOnly, let intro = introFile {
      try await generateIntroFile(
        path: intro,
        season: season,
        project: resolvedProject,
        projectDirectory: projectDirectory,
        quiet: quiet
      )
      if !quiet {
        print(" ✓ intro", terminator: "")
      }
    }

    // Generate outro file if specified and not --intro-only
    if !introOnly, let outro = outroFile {
      try await generateOutroFile(
        path: outro,
        season: season,
        project: resolvedProject,
        projectDirectory: projectDirectory,
        quiet: quiet
      )
      if !quiet {
        print(" ✓ outro", terminator: "")
      }
    }

    if !quiet {
      print()  // Newline after season generation
    }

    if verbose {
      printSeasonDetails(season: season, resolvedProject: resolvedProject)
    }
  }

  /// Generate intro file for a season.
  private func generateIntroFile(
    path: String,
    season: SeasonDefinition,
    project: ProjectFrontMatter,
    projectDirectory: URL,
    quiet: Bool
  ) async throws {
    // Build full path relative to project directory
    let introURL = projectDirectory.appendingPathComponent(path)

    // For now, create placeholder. Real implementation would use LLM or external tool
    let placeholderContent = """
      ---
      type: fountain
      title: \(project.title) - Season \(season.number) Intro
      ---

      # Season \(season.number) Intro

      [Intro content will be generated here]
      """

    // Create parent directories if needed
    try FileManager.default.createDirectory(
      at: introURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )

    try placeholderContent.write(to: introURL, atomically: true, encoding: .utf8)
  }

  /// Generate outro file for a season.
  private func generateOutroFile(
    path: String,
    season: SeasonDefinition,
    project: ProjectFrontMatter,
    projectDirectory: URL,
    quiet: Bool
  ) async throws {
    // Build full path relative to project directory
    let outroURL = projectDirectory.appendingPathComponent(path)

    // For now, create placeholder. Real implementation would use LLM or external tool
    let placeholderContent = """
      ---
      type: fountain
      title: \(project.title) - Season \(season.number) Outro
      ---

      # Season \(season.number) Outro

      [Outro content will be generated here]
      """

    // Create parent directories if needed
    try FileManager.default.createDirectory(
      at: outroURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )

    try placeholderContent.write(to: outroURL, atomically: true, encoding: .utf8)
  }

  /// Print resolved properties for a season (verbose mode).
  private func printSeasonDetails(
    season: SeasonDefinition,
    resolvedProject: ProjectFrontMatter
  ) {
    print("  Season \(season.number) resolved properties:")
    print("    - Title: \(resolvedProject.title)")
    print("    - Author: \(resolvedProject.author)")
    print("    - Episodes: \(season.episodes)")
    if let desc = resolvedProject.description {
      print("    - Description: \(desc.prefix(60))...")
    }
    if let episodesDir = resolvedProject.episodesDir {
      print("    - Episodes Dir: \(episodesDir)")
    }
    if let audioDir = resolvedProject.audioDir {
      print("    - Audio Dir: \(audioDir)")
    }
  }

  /// Show variants list grouped by season then language.
  private func showVariantsList() async throws {
    // Resolve path
    let inputPath = path ?? FileManager.default.currentDirectoryPath
    let inputURL = URL(fileURLWithPath: inputPath).standardizedFileURL

    // Determine if path is a directory or file
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDir) else {
      throw GenerateError.directoryNotFound(inputURL.path)
    }

    // Get PROJECT.md file URL
    let projectMdURL: URL
    if isDir.boolValue {
      projectMdURL = inputURL.appendingPathComponent("PROJECT.md")
    } else if inputURL.lastPathComponent == "PROJECT.md" {
      projectMdURL = inputURL
    } else {
      throw GenerateError.invalidPath(
        "Path must be a directory containing PROJECT.md or a PROJECT.md file")
    }

    // Check if PROJECT.md exists
    guard FileManager.default.fileExists(atPath: projectMdURL.path) else {
      throw GenerateError.projectMdNotFound(projectMdURL.path)
    }

    // Parse the project file
    let parser = ProjectMarkdownParser()
    do {
      let (projectFrontMatter, _) = try parser.parse(fileURL: projectMdURL)

      // Verify this is a v4 schema project
      guard projectFrontMatter.schemaVersion == 4 else {
        throw GenerateError.parseError(
          "--list is only available for v4.0.0 schema projects (schemaVersion: 4)")
      }

      // Print title and project info
      print("\(projectFrontMatter.title)")
      print("Author: \(projectFrontMatter.author)")
      if let desc = projectFrontMatter.description {
        print("Description: \(desc)")
      }
      print("")

      // Group variants by season, then by language
      var variantsBySeasonAndLanguage: [Int: [String: VariantInfo]] = [:]

      if let variants = projectFrontMatter.variants {
        for variant in variants {
          if variantsBySeasonAndLanguage[variant.season] == nil {
            variantsBySeasonAndLanguage[variant.season] = [:]
          }
          variantsBySeasonAndLanguage[variant.season]?[variant.language] = VariantInfo(
            variant: variant,
            episodeCount: nil
          )
        }
      }

      // Add season-level information
      if let seasons = projectFrontMatter.seasons {
        for season in seasons {
          if variantsBySeasonAndLanguage[season.number] == nil {
            variantsBySeasonAndLanguage[season.number] = [:]
          }
          // Add a default entry if no variants exist for this season
          if variantsBySeasonAndLanguage[season.number]?.isEmpty ?? true {
            variantsBySeasonAndLanguage[season.number]?[""] = VariantInfo(
              variant: nil,
              episodeCount: season.episodes
            )
          } else {
            // Update episode count for existing variants
            if var seasonVariants = variantsBySeasonAndLanguage[season.number] {
              for language in seasonVariants.keys {
                if var info = seasonVariants[language] {
                  info.episodeCount = season.episodes
                  seasonVariants[language] = info
                }
              }
              variantsBySeasonAndLanguage[season.number] = seasonVariants
            }
          }
        }
      }

      // Sort and print results
      let sortedSeasons = variantsBySeasonAndLanguage.keys.sorted()

      if sortedSeasons.isEmpty {
        print("No seasons or variants found in PROJECT.md")
        return
      }

      for seasonNum in sortedSeasons {
        let variants = variantsBySeasonAndLanguage[seasonNum] ?? [:]
        let seasonTitle = projectFrontMatter.seasons?
          .first(where: { $0.number == seasonNum })?
          .title ?? ""
        let seasonTitleStr = seasonTitle.isEmpty ? "" : " (\(seasonTitle))"

        print("Season \(seasonNum)\(seasonTitleStr):")

        // Sort languages alphabetically (empty language code goes first)
        let sortedLanguages = variants.keys.sorted { a, b in
          if a.isEmpty { return true }
          if b.isEmpty { return false }
          return a < b
        }

        for language in sortedLanguages {
          guard let info = variants[language] else { continue }

          let langLabel = language.isEmpty ? "Default" : "Language \(language)"
          let episodeCount = info.episodeCount ?? 0
          let episodeLabel = episodeCount == 1 ? "episode" : "episodes"

          // Check intro/outro presence
          let hasIntro = info.variant?.introFile != nil
          let hasOutro = info.variant?.outroFile != nil
          let introStatus = hasIntro ? "✓" : "✗"
          let outroStatus = hasOutro ? "✓" : "✗"

          // Get status - format the VariantStatus enum value
          let statusStr: String
          if let status = info.variant?.status {
            switch status {
            case .published:
              statusStr = "published"
            case .inProgress:
              statusStr = "in_progress"
            case .draft:
              statusStr = "draft"
            case .obsolete:
              statusStr = "obsolete"
            }
          } else {
            statusStr = "no status"
          }

          print("  \(langLabel): \(episodeCount) \(episodeLabel) (intro: \(introStatus), outro: \(outroStatus)) [\(statusStr)]")
        }
        print("")
      }

    } catch let error as ProjectMarkdownParser.ParserError {
      throw GenerateError.parseError(
        "Failed to parse PROJECT.md: \(error.localizedDescription)")
    } catch {
      throw error
    }
  }

  /// Helper struct for variant information
  private struct VariantInfo {
    var variant: VariantReference?
    var episodeCount: Int?
  }
}

// MARK: - Errors

enum GenerateError: LocalizedError {
  case directoryNotFound(String)
  case projectMdNotFound(String)
  case invalidPath(String)
  case parseError(String)
  case seasonNotFound(Int)
  case languageNotFound(String, availableLanguages: [String])
  case noSeasonsFound(String)
  case seasonGenerationFailed(Int, Error)

  var errorDescription: String? {
    switch self {
    case .directoryNotFound(let path):
      return "Directory not found: \(path)"
    case .projectMdNotFound(let path):
      return "PROJECT.md not found: \(path)"
    case .invalidPath(let message):
      return message
    case .parseError(let message):
      return "Parse error: \(message)"
    case .seasonNotFound(let seasonNum):
      return "Season \(seasonNum) not found in PROJECT.md"
    case .languageNotFound(let langCode, let availableLanguages):
      if availableLanguages.isEmpty {
        return "Language '\(langCode)' not found: no languages defined in PROJECT.md"
      } else {
        return "Language '\(langCode)' not found. Available: \(availableLanguages.joined(separator: ", "))"
      }
    case .noSeasonsFound(let message):
      return message
    case .seasonGenerationFailed(let seasonNum, let error):
      return "Failed to generate season \(seasonNum): \(error.localizedDescription)"
    }
  }
}

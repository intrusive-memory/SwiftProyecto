//
//  ProyectoCLI.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import ArgumentParser
import Foundation
import SwiftAcervo
import SwiftProyecto

/// PROJECT.md generator CLI using local LLM inference.
@main
struct ProyectoCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "proyecto",
    abstract: "Generate and manage PROJECT.md files using local LLM inference",
    discussion: """
      Proyecto analyzes a directory structure and uses Apple's on-device Foundation Models
      to generate PROJECT.md metadata files for podcast and screenplay projects.

      The generated PROJECT.md contains YAML frontmatter with:
        - title, author, description, genre, tags
        - episodesDir, audioDir, filePattern, exportFormat
        - Optional hooks for pre/post generation scripts

      Examples:
        proyecto init                     # Analyze current directory
        proyecto init /path/to/project    # Analyze specific directory
        proyecto init --author "Jane Doe" # Override author field
        proyecto init --update            # Update existing PROJECT.md
        proyecto validate                 # Validate PROJECT.md in current directory
        proyecto validate /path/to/dir    # Validate PROJECT.md in specific directory
        proyecto generate                 # Generate output for current directory
        proyecto generate --season 2      # Generate output for season 2 only
        proyecto generate --intro-only    # Generate intro files only
      """,
    version: SwiftProyecto.version,
    subcommands: [
      InitCommand.self, DownloadCommand.self, RolesCommand.self, ValidateCommand.self,
      GenerateCommand.self, VariantsCommand.self, InfoCommand.self, GenerateProjectCommand.self,
    ],
    defaultSubcommand: InitCommand.self
  )
}

// MARK: - Validate Command

struct ValidateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Validate a PROJECT.md file",
    discussion: """
      Validates the structure and content of a PROJECT.md file.

      Checks for:
        - Valid YAML front matter delimiters (---)
        - Required fields (type, title, author, created)
        - Valid date formats (ISO 8601)
        - Proper YAML syntax

      Examples:
        proyecto validate                       # Validate PROJECT.md in current directory
        proyecto validate /path/to/project      # Validate PROJECT.md in specific directory
        proyecto validate /path/to/PROJECT.md   # Validate specific file
        proyecto validate --verbose             # Show parsed metadata on success
      """
  )

  @Argument(
    help:
      "Path to directory containing PROJECT.md or path to PROJECT.md file (default: current directory)"
  )
  var path: String?

  @Flag(name: .shortAndLong, help: "Show parsed metadata on successful validation")
  var verbose: Bool = false

  mutating func run() throws {
    // Resolve path
    let inputPath = path ?? FileManager.default.currentDirectoryPath
    let inputURL = URL(fileURLWithPath: inputPath).standardizedFileURL

    // Determine if path is a directory or file
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDir) else {
      throw ProyectoError.directoryNotFound(inputURL.path)
    }

    // Get PROJECT.md file URL
    let projectMdURL: URL
    if isDir.boolValue {
      projectMdURL = inputURL.appendingPathComponent("PROJECT.md")
    } else if inputURL.lastPathComponent == "PROJECT.md" {
      projectMdURL = inputURL
    } else {
      throw ValidationError("Path must be a directory containing PROJECT.md or a PROJECT.md file")
    }

    // Check if PROJECT.md exists
    guard FileManager.default.fileExists(atPath: projectMdURL.path) else {
      throw ProyectoError.projectMdNotFound(projectMdURL.path)
    }

    // Parse the file
    let parser = ProjectMarkdownParser()
    do {
      let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)

      // Create validator and validate
      let validator = ProjectValidator()
      let result = validator.validate(frontMatter)

      // Display header
      print("✓ Validating: \(projectMdURL.path)")

      // Display schema and file type info
      let schemaVersionStr = result.metadata.schemaVersion == 4 ? "v4.0.0" : "v3.x"
      print("ℹ Schema version: \(schemaVersionStr)")
      print("ℹ File type: \(result.metadata.fileType)")

      // Display counts if present
      if let seasonCount = result.metadata.seasonCount, seasonCount > 0 {
        let seasonStr =
          result.metadata.seasonNumbers.map { $0.map(String.init).joined(separator: ", ") } ?? ""
        print("ℹ Seasons: \(seasonCount) (IDs: \(seasonStr))")
      }

      if let languageCount = result.metadata.languageCount, languageCount > 0 {
        let langStr = result.metadata.languageCodes.map { $0.joined(separator: ", ") } ?? ""
        print("ℹ Languages: \(languageCount) (\(langStr))")
      }

      if let variantCount = result.metadata.variantCount, variantCount > 0 {
        print("ℹ Variants: \(variantCount)")
      }

      // Check validation result
      if result.isValid {
        print("✓ VALID PROJECT")
        print()

        // Show warnings if any
        if !result.warnings.isEmpty {
          print("⚠ Warnings:")
          for warning in result.warnings {
            print("  - \(warning)")
          }
          print()
        }

        // Show verbose metadata if requested
        if verbose {
          print("Parsed metadata:")
          print("  Type: \(frontMatter.type)")
          print("  Title: \(frontMatter.title)")
          print("  Author: \(frontMatter.author)")

          let dateFormatter = DateFormatter()
          dateFormatter.dateStyle = .medium
          dateFormatter.timeStyle = .none
          print("  Created: \(dateFormatter.string(from: frontMatter.created))")

          if let description = frontMatter.description {
            print("  Description: \(description.prefix(80))\(description.count > 80 ? "..." : "")")
          }
          if let season = frontMatter.season {
            print("  Season: \(season)")
          }
          if let episodes = frontMatter.episodes {
            print("  Episodes: \(episodes)")
          }
          if let genre = frontMatter.genre {
            print("  Genre: \(genre)")
          }
          if let tags = frontMatter.tags {
            print("  Tags: \(tags.joined(separator: ", "))")
          }
          if let episodesDir = frontMatter.episodesDir {
            print("  Episodes Directory: \(episodesDir)")
          }
          if let audioDir = frontMatter.audioDir {
            print("  Audio Directory: \(audioDir)")
          }
          if let filePattern = frontMatter.filePattern {
            print("  File Pattern: \(filePattern)")
          }
          if let exportFormat = frontMatter.exportFormat {
            print("  Export Format: \(exportFormat)")
          }
          if let cast = frontMatter.cast, !cast.isEmpty {
            print("  Cast: \(cast.count) member(s)")
          }
          if frontMatter.tts != nil {
            print("  TTS Configuration: present")
          }
          if frontMatter.preGenerateHook != nil {
            print("  Pre-generate Hook: present")
          }
          if frontMatter.postGenerateHook != nil {
            print("  Post-generate Hook: present")
          }

          print()
          print("Body content: \(body.isEmpty ? "empty" : "\(body.count) characters")")
        }
      } else {
        // Validation failed
        print("✗ VALIDATION FAILED:")
        print()

        // Show all errors
        for error in result.errors {
          print("  - \(error)")
        }

        // Show warnings too
        if !result.warnings.isEmpty {
          print()
          print("⚠ Warnings:")
          for warning in result.warnings {
            print("  - \(warning)")
          }
        }

        throw ExitCode.validationFailure
      }

    } catch let error as ProjectMarkdownParser.ParserError {
      // Parser error - show detailed error
      print("✗ Validating: \(projectMdURL.path)")
      print()
      print("✗ PARSE ERROR:")
      print("  - \(error.localizedDescription)")
      throw ExitCode.validationFailure

    } catch {
      // Other errors
      print("✗ Validating: \(projectMdURL.path)")
      print()
      print("✗ ERROR:")
      print("  - \(error.localizedDescription)")
      throw ExitCode.failure
    }
  }
}

// MARK: - Init Command

struct InitCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "init",
    abstract: "Analyze a directory and generate PROJECT.md",
    discussion: """
      Analyzes the directory structure, README.md, and file patterns to generate
      a PROJECT.md file with appropriate metadata using local LLM inference.

      Behavior with existing PROJECT.md:
        - Default: Error if PROJECT.md exists (prevents accidental overwrites)
        - --force: Completely replace existing PROJECT.md
        - --update: Preserve created date, body content, and hooks; update other fields

      The LLM analyzes:
        - Folder name and structure
        - README.md content (if present)
        - File patterns (*.fountain, *.mp3, etc.)

      Examples:
        proyecto init                        # Analyze current directory
        proyecto init /path/to/podcast       # Analyze specific directory
        proyecto init --author "Tom Stovall" # Override detected author
        proyecto init --update               # Update existing, preserve created/body/hooks
        proyecto init --force                # Overwrite existing completely
        proyecto init --model ~/Models/Phi3  # Use specific local model
      """
  )

  @Argument(help: "Directory to analyze (default: current directory)")
  var directory: String?

  @Option(name: .long, help: "Override the author field (skip LLM detection)")
  var author: String?

  @Option(name: .long, help: "Max tokens to generate per section (default: 65536)")
  var maxTokens: Int = IterativeProjectGenerator.defaultMaxTokens

  @Flag(name: .long, help: "Update existing PROJECT.md, preserving created date, body, and hooks")
  var update: Bool = false

  @Flag(name: .long, help: "Overwrite existing PROJECT.md completely (destructive)")
  var force: Bool = false

  @Flag(name: .shortAndLong, help: "Suppress progress output")
  var quiet: Bool = false

  mutating func run() async throws {
    // Validate flags
    if update && force {
      throw ValidationError("Cannot use both --update and --force. Choose one.")
    }

    // Resolve directory
    let directoryPath = directory ?? FileManager.default.currentDirectoryPath
    let directoryURL = URL(fileURLWithPath: directoryPath).standardizedFileURL

    // Check if directory exists
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDir),
      isDir.boolValue
    else {
      throw ProyectoError.directoryNotFound(directoryURL.path)
    }

    // Check for existing PROJECT.md
    let projectMdURL = directoryURL.appendingPathComponent("PROJECT.md")
    let existingProjectMd = FileManager.default.fileExists(atPath: projectMdURL.path)

    // Parse existing PROJECT.md if updating
    var existingFrontMatter: ProjectFrontMatter?
    var existingBody: String = ""

    if existingProjectMd {
      if !update && !force {
        throw ProyectoError.projectMdExists(projectMdURL.path)
      }

      if update {
        let parser = ProjectMarkdownParser()
        do {
          let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)
          existingFrontMatter = frontMatter
          existingBody = body
          if !quiet {
            print("Updating existing PROJECT.md (preserving created, body, hooks)")
          }
        } catch {
          throw ProyectoError.parseError(
            "Failed to parse existing PROJECT.md: \(error.localizedDescription)")
        }
      }
    }

    if !quiet {
      print("Analyzing directory: \(directoryURL.path)")
    }

    // Use iterative generator
    let generator = IterativeProjectGenerator(
      authorOverride: author,
      maxTokens: maxTokens
    )

    let showProgress = !quiet
    let generatedFrontMatter = try await generator.generate(for: directoryURL) { section, message in
      if showProgress {
        print("[\(section.displayName)] \(message)")
      }
    }

    // Merge with existing if updating
    let frontMatter: ProjectFrontMatter
    if let existing = existingFrontMatter {
      frontMatter = ProjectFrontMatter(
        type: "project",
        title: generatedFrontMatter.title,
        author: generatedFrontMatter.author,
        created: existing.created,  // Preserve original created date
        description: generatedFrontMatter.description,
        season: existing.season ?? generatedFrontMatter.season,  // Preserve existing if set
        episodes: generatedFrontMatter.episodes,  // ALWAYS use actual file count
        genre: generatedFrontMatter.genre,
        tags: generatedFrontMatter.tags,
        episodesDir: generatedFrontMatter.episodesDir,
        audioDir: generatedFrontMatter.audioDir,
        filePattern: generatedFrontMatter.filePattern,
        exportFormat: generatedFrontMatter.exportFormat,
        preGenerateHook: existing.preGenerateHook,  // Preserve hooks
        postGenerateHook: existing.postGenerateHook  // Preserve hooks
      )
    } else {
      frontMatter = generatedFrontMatter
    }

    let parser = ProjectMarkdownParser()
    let normalizedFrontMatter = frontMatter.normalizingPaths(relativeTo: directoryURL)
    let content = parser.generate(frontMatter: normalizedFrontMatter, body: existingBody)

    // Write the file
    try content.write(to: projectMdURL, atomically: true, encoding: .utf8)

    if !quiet {
      if update {
        print("\nUpdated: \(projectMdURL.path)")
      } else {
        print("\nGenerated: \(projectMdURL.path)")
      }
      print("\nPROJECT.md contents:")
      print("---")
      print(content)
    }
  }
}

// MARK: - Variants Command

struct VariantsCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "variants",
    abstract: "List all language/season variants from a PROJECT.md",
    discussion: """
      Lists all variants defined in a master PROJECT.md file (v4.0.0 schema only).

      Shows variant status (published|in_progress|draft|obsolete), episode counts,
      intro/outro file presence, and file paths.

      Results can be grouped by language or season.

      Examples:
        proyecto variants                 # List variants in current directory
        proyecto variants /path/to/dir    # List variants in specific directory
        proyecto variants /path/to/dir --group language  # Group by language
        proyecto variants --verbose       # Show detailed metadata
      """
  )

  @Argument(
    help:
      "Path to directory containing PROJECT.md or path to PROJECT.md file (default: current directory)"
  )
  var path: String?

  @Option(
    name: .long,
    help: "Group results by 'season' (default) or 'language'"
  )
  var group: String = "season"

  @Flag(name: .shortAndLong, help: "Show verbose output with detailed variant info")
  var verbose: Bool = false

  mutating func run() throws {
    // Resolve path
    let inputPath = path ?? FileManager.default.currentDirectoryPath
    let inputURL = URL(fileURLWithPath: inputPath).standardizedFileURL

    // Determine if path is a directory or file
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDir) else {
      throw ProyectoError.directoryNotFound(inputURL.path)
    }

    // Get PROJECT.md file URL
    let projectMdURL: URL
    if isDir.boolValue {
      projectMdURL = inputURL.appendingPathComponent("PROJECT.md")
    } else if inputURL.lastPathComponent == "PROJECT.md" {
      projectMdURL = inputURL
    } else {
      throw ProyectoError.invalidPath(
        "Path must be a directory containing PROJECT.md or a PROJECT.md file")
    }

    // Check if PROJECT.md exists
    guard FileManager.default.fileExists(atPath: projectMdURL.path) else {
      throw ProyectoError.projectMdNotFound(projectMdURL.path)
    }

    // Parse the file
    let parser = ProjectMarkdownParser()
    do {
      let (projectFrontMatter, _) = try parser.parse(fileURL: projectMdURL)

      // Verify this is a v4 schema project
      guard projectFrontMatter.schemaVersion == 4 else {
        throw ProyectoError.parseError(
          "variants command is only available for v4.0.0 schema projects (schemaVersion: 4)")
      }

      // Print project header
      print("✓ \(projectFrontMatter.title)")
      print("Author: \(projectFrontMatter.author)")
      if let desc = projectFrontMatter.description {
        print("Description: \(desc)")
      }
      print("")

      // Get variants and organize
      let variants = projectFrontMatter.variants ?? []

      if variants.isEmpty {
        print("No variants found in this PROJECT.md")
        return
      }

      // Validate group option
      let groupBy = group.lowercased()
      guard ["season", "language"].contains(groupBy) else {
        throw ProyectoError.parseError(
          "Invalid --group option '\(group)'. Must be 'season' or 'language'.")
      }

      if groupBy == "season" {
        displayVariantsBySeason(variants, verbose: verbose)
      } else {
        displayVariantsByLanguage(variants, verbose: verbose)
      }

    } catch let error as ProjectMarkdownParser.ParserError {
      throw ProyectoError.parseError(
        "Failed to parse PROJECT.md: \(error.localizedDescription)")
    } catch {
      throw error
    }
  }

  private func displayVariantsBySeason(
    _ variants: [VariantReference],
    verbose: Bool
  ) {
    // Group by season
    var variantsBySeason: [Int: [VariantReference]] = [:]
    for variant in variants {
      if variantsBySeason[variant.season] == nil {
        variantsBySeason[variant.season] = []
      }
      variantsBySeason[variant.season]?.append(variant)
    }

    // Sort seasons
    let sortedSeasons = variantsBySeason.keys.sorted()

    for seasonNum in sortedSeasons {
      let seasonVariants = (variantsBySeason[seasonNum] ?? []).sorted { a, b in
        a.language < b.language
      }

      print("Season \(seasonNum):")
      for variant in seasonVariants {
        let status = variant.status?.rawValue ?? "—"
        let intro = variant.introFile.map { "intro: \($0)" } ?? ""
        let outro = variant.outroFile.map { "outro: \($0)" } ?? ""
        let extra = [intro, outro].filter { !$0.isEmpty }.joined(separator: ", ")
        let extraStr = extra.isEmpty ? "" : " (\(extra))"

        print("  \(variant.language): \(status) — \(variant.path)\(extraStr)")

        if verbose {
          print("    Status: \(status)")
          print("    Path: \(variant.path)")
          if let intro = variant.introFile {
            print("    Intro: \(intro)")
          }
          if let outro = variant.outroFile {
            print("    Outro: \(outro)")
          }
        }
      }
      print("")
    }
  }

  private func displayVariantsByLanguage(
    _ variants: [VariantReference],
    verbose: Bool
  ) {
    // Group by language
    var variantsByLanguage: [String: [VariantReference]] = [:]
    for variant in variants {
      if variantsByLanguage[variant.language] == nil {
        variantsByLanguage[variant.language] = []
      }
      variantsByLanguage[variant.language]?.append(variant)
    }

    // Sort languages
    let sortedLanguages = variantsByLanguage.keys.sorted()

    for language in sortedLanguages {
      let languageVariants = (variantsByLanguage[language] ?? []).sorted { a, b in
        a.season < b.season
      }

      print("Language \(language):")
      for variant in languageVariants {
        let status = variant.status?.rawValue ?? "—"
        let intro = variant.introFile.map { "intro: \($0)" } ?? ""
        let outro = variant.outroFile.map { "outro: \($0)" } ?? ""
        let extra = [intro, outro].filter { !$0.isEmpty }.joined(separator: ", ")
        let extraStr = extra.isEmpty ? "" : " (\(extra))"

        print(
          "  S\(String(format: "%02d", variant.season)): \(status) — \(variant.path)\(extraStr)")

        if verbose {
          print("    Status: \(status)")
          print("    Path: \(variant.path)")
          if let intro = variant.introFile {
            print("    Intro: \(intro)")
          }
          if let outro = variant.outroFile {
            print("    Outro: \(outro)")
          }
        }
      }
      print("")
    }
  }
}

// MARK: - Info Command

struct InfoCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "info",
    abstract: "Show PROJECT.md file type and metadata",
    discussion: """
      Displays detailed information about a PROJECT.md file, including:
        - File type (project, master, variant)
        - Schema version (v3.x or v4.0.0)
        - Seasons and languages defined
        - Master vs variant status
        - Variant references (if applicable)

      Examples:
        proyecto info                        # Show info for PROJECT.md in current directory
        proyecto info /path/to/dir           # Show info for specific directory
        proyecto info /path/to/PROJECT.md    # Show info for specific file
        proyecto info --verbose              # Show detailed metadata
      """
  )

  @Argument(
    help:
      "Path to directory containing PROJECT.md or path to PROJECT.md file (default: current directory)"
  )
  var path: String?

  @Flag(name: .shortAndLong, help: "Show verbose detailed metadata")
  var verbose: Bool = false

  mutating func run() throws {
    // Resolve path
    let inputPath = path ?? FileManager.default.currentDirectoryPath
    let inputURL = URL(fileURLWithPath: inputPath).standardizedFileURL

    // Determine if path is a directory or file
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDir) else {
      throw ProyectoError.directoryNotFound(inputURL.path)
    }

    // Get PROJECT.md file URL
    let projectMdURL: URL
    if isDir.boolValue {
      projectMdURL = inputURL.appendingPathComponent("PROJECT.md")
    } else if inputURL.lastPathComponent == "PROJECT.md" {
      projectMdURL = inputURL
    } else {
      throw ProyectoError.invalidPath(
        "Path must be a directory containing PROJECT.md or a PROJECT.md file")
    }

    // Check if PROJECT.md exists
    guard FileManager.default.fileExists(atPath: projectMdURL.path) else {
      throw ProyectoError.projectMdNotFound(projectMdURL.path)
    }

    // Parse the file
    let parser = ProjectMarkdownParser()
    do {
      let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)

      // Run validation to get metadata
      let validator = ProjectValidator()
      let result = validator.validate(frontMatter)

      // Display header
      print("✓ PROJECT.md Info: \(projectMdURL.path)")
      print("")

      // Schema version
      let schemaVersionStr = frontMatter.schemaVersion == 4 ? "v4.0.0" : "v3.x"
      print("Schema Version: \(schemaVersionStr)")

      // File type
      print("File Type: \(result.metadata.fileType)")

      // Project type
      if let projectType = frontMatter.projectType {
        print("Project Type: \(projectType)")
      } else {
        print("Project Type: \(frontMatter.type)")
      }

      // Master vs variant detection
      let isMaster = result.metadata.fileType == "master"
      print("Master/Variant: \(isMaster ? "Master (overview)" : "Variant/Project")")

      print("")

      // Seasons
      if let seasonCount = result.metadata.seasonCount, seasonCount > 0 {
        let seasonStr =
          result.metadata.seasonNumbers.map { $0.map(String.init).joined(separator: ", ") } ?? ""
        print("Seasons: \(seasonCount) (IDs: \(seasonStr))")
      } else if let season = frontMatter.season {
        print("Season: \(season)")
      }

      // Languages
      if let languageCount = result.metadata.languageCount, languageCount > 0 {
        let langStr = result.metadata.languageCodes.map { $0.joined(separator: ", ") } ?? ""
        print("Languages: \(languageCount) (\(langStr))")
      }

      // Variants
      if let variantCount = result.metadata.variantCount, variantCount > 0 {
        print("Variants: \(variantCount)")
      }

      // Episodes
      if let episodes = frontMatter.episodes {
        print("Episodes: \(episodes)")
      } else if let seasonCount = result.metadata.seasonCount, seasonCount > 0 {
        let totalEpisodes = frontMatter.seasons?.reduce(0) { $0 + ($1.episodes ?? 0) } ?? 0
        print("Total Episodes: \(totalEpisodes)")
      }

      print("")

      if verbose {
        print("Detailed Metadata:")
        print("  Title: \(frontMatter.title)")
        print("  Author: \(frontMatter.author)")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        print("  Created: \(dateFormatter.string(from: frontMatter.created))")

        if let description = frontMatter.description {
          print("  Description: \(description.prefix(80))\(description.count > 80 ? "..." : "")")
        }

        if let genre = frontMatter.genre {
          print("  Genre: \(genre)")
        }

        if let tags = frontMatter.tags, !tags.isEmpty {
          print("  Tags: \(tags.joined(separator: ", "))")
        }

        print("")
        print("Body Content: \(body.isEmpty ? "empty" : "\(body.count) characters")")

        // Show validation results
        if !result.warnings.isEmpty {
          print("")
          print("⚠ Warnings:")
          for warning in result.warnings {
            print("  - \(warning)")
          }
        }
      }

    } catch let error as ProjectMarkdownParser.ParserError {
      throw ProyectoError.parseError(
        "Failed to parse PROJECT.md: \(error.localizedDescription)")
    } catch {
      throw error
    }
  }
}

// MARK: - Errors

enum ProyectoError: LocalizedError {
  case directoryNotFound(String)
  case projectMdExists(String)
  case projectMdNotFound(String)
  case parseError(String)
  case llmError(String)
  case invalidPath(String)

  var errorDescription: String? {
    switch self {
    case .directoryNotFound(let path):
      return "Directory not found: \(path)"
    case .projectMdExists(let path):
      return "PROJECT.md already exists at \(path). Use --update to merge or --force to overwrite."
    case .projectMdNotFound(let path):
      return "PROJECT.md not found: \(path)"
    case .parseError(let message):
      return "Parse error: \(message)"
    case .llmError(let message):
      return "LLM error: \(message)"
    case .invalidPath(let message):
      return message
    }
  }
}

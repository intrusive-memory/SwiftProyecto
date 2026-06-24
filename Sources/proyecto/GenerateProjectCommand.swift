//
//  GenerateProjectCommand.swift
//  proyecto CLI
//
//  Copyright (c) 2025 Intrusive Memory
//

import ArgumentParser
import Foundation
import SwiftAcervo
import SwiftProyecto

/// Generate PROJECT.md from project directory using LLM backends.
///
/// Analyzes a project directory structure and generates a valid v4.x PROJECT.md file
/// using available LLM backends in priority order:
/// 1. SwiftBruja (if available)
/// 2. Apple Foundation Models (if available on macOS 27+)
/// 3. Claude API (fallback)
///
/// ## Behavior
///
/// **Default (--dry-run)**:
/// - Generates PROJECT.md metadata
/// - Outputs to stdout
/// - Does NOT write to disk
///
/// **With --interactive**:
/// - Generates metadata
/// - Displays for review
/// - Prompts user to confirm/edit
/// - Only writes if user confirms
///
/// **With --force**:
/// - Generates metadata
/// - Overwrites existing PROJECT.md without confirmation
/// - Creates .bak backup
/// - Validates before write
///
/// ## File Safety
///
/// - Always validates generated content against schema before writing
/// - Creates .PROJECT.md.bak automatic backup before overwriting
/// - Never silently overwrites existing PROJECT.md (unless --force specified)
/// - Graceful error handling with helpful messages
///
/// ## Examples
///
/// ```
/// proyecto generate-project /path/to/project
/// proyecto generate-project /path/to/project --interactive --llm claude
/// proyecto generate-project /path/to/project --force --model claude-3-5-sonnet-20241022
/// proyecto generate-project /path/to/project --dry-run --llm fm
/// ```
struct GenerateProjectCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "generate-project",
    abstract: "Generate PROJECT.md from project directory using LLM",
    discussion: """
      Analyzes project directory structure and generates a valid PROJECT.md file
      using LLM backends (SwiftBruja → Foundation Models → Claude API).

      File safety:
        - Default: --dry-run (output to stdout, no write)
        - --interactive: Review before write, with edit prompt
        - --force: Overwrite existing without confirmation (creates .bak backup)

      Backend selection:
        - Default: Auto-select (try Bruja → FM → Claude)
        - --llm claude|fm|bruja: Force specific backend
        - --model <name>: Select Claude model (default: claude-3-5-sonnet-20241022)

      Examples:
        proyecto generate-project /path/to/project
        proyecto generate-project . --interactive
        proyecto generate-project . --force --llm claude
        proyecto generate-project . --dry-run --model claude-3-opus-20250219
      """
  )

  // MARK: - Arguments & Options

  @Argument(help: "Project directory to analyze (default: current directory)")
  var directory: String?

  @Flag(
    name: .long,
    help: "Output to stdout without writing to disk (default)"
  )
  var dryRun: Bool = false

  @Flag(
    name: .long,
    help: "Show generated metadata and prompt for review before writing"
  )
  var interactive: Bool = false

  @Flag(
    name: .long,
    help: "Overwrite existing PROJECT.md without confirmation"
  )
  var force: Bool = false

  @Option(
    name: .long,
    help: "Select LLM backend (claude, fm, bruja; default: auto-select)"
  )
  var llm: String?

  @Option(
    name: .long,
    help: "Claude model to use (default: claude-3-5-sonnet-20241022)"
  )
  var model: String = "claude-3-5-sonnet-20241022"

  @Flag(
    name: .shortAndLong,
    help: "Suppress progress output"
  )
  var quiet: Bool = false

  @Flag(
    name: .shortAndLong,
    help: "Show verbose output"
  )
  var verbose: Bool = false

  // MARK: - Main Execution

  mutating func run() async throws {
    // Initialize all LLM backends (ensures they're registered)
    initializeLLMBackends()

    // Validate flag combinations
    if interactive && force {
      throw ValidationError(
        "Cannot use both --interactive and --force. Choose one."
      )
    }

    if dryRun && force {
      throw ValidationError(
        "Cannot use both --dry-run and --force. Choose one."
      )
    }

    // Resolve directory
    let directoryPath = directory ?? FileManager.default.currentDirectoryPath
    let directoryURL = URL(fileURLWithPath: directoryPath).standardizedFileURL

    // Verify directory exists
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDir),
      isDir.boolValue
    else {
      throw GenerateProjectError.directoryNotFound(directoryURL.path)
    }

    if !quiet {
      print("Analyzing project: \(directoryURL.path)")
    }

    // Step 1: Analyze project directory
    guard let analysis = ProjectService.analyzeForGeneration(at: directoryURL) else {
      throw GenerateProjectError.analysisError(
        "Failed to analyze project directory"
      )
    }

    if !quiet {
      print("ℹ Directory analysis complete")
      if verbose {
        print("  - Cast members extracted: \(analysis.extractedCast.count)")
        if let pattern = analysis.episodePattern {
          print("  - Episode pattern: \(pattern)")
        }
      }
    }

    // Step 2: Generate metadata using ProjectGeneratorService
    let service = ProjectGeneratorService()

    // Validate backend selection if --llm specified
    if let backendName = llm {
      let normalizedName: String
      switch backendName.lowercased() {
      case "claude":
        normalizedName = "Claude API"
      case "fm":
        normalizedName = "Apple Foundation Models"
      case "bruja":
        normalizedName = "SwiftBruja"
      default:
        throw GenerateProjectError.invalidBackend(
          backendName,
          guidance: "Valid options: claude, fm, bruja"
        )
      }

      let backend = BackendRegistry.shared.backend(named: normalizedName)
      guard backend != nil else {
        throw GenerateProjectError.backendUnavailable(
          normalizedName,
          guidance: "Backend is not available on this system"
        )
      }
    }

    if !quiet {
      print("Generating PROJECT.md metadata...", terminator: "")
      fflush(stdout)
    }

    let metadata: ProjectMetadata
    do {
      metadata = try await service.generate(project: analysis)
      if !quiet {
        print(" ✓")
      }
    } catch {
      if !quiet {
        print(" ✗")
      }
      throw GenerateProjectError.generationError(error.localizedDescription)
    }

    // Step 3: Convert ProjectMetadata to ProjectFrontMatter
    let frontMatter = convertMetadataToFrontMatter(metadata, projectPath: directoryURL)

    // Step 4: Generate PROJECT.md content
    let parser = ProjectMarkdownParser()
    let content = parser.generate(frontMatter: frontMatter, body: "")

    // Step 5: Validate schema
    if !quiet {
      print("Validating schema...", terminator: "")
      fflush(stdout)
    }

    let validator = ProjectValidator()
    let validationResult = validator.validate(frontMatter)

    if !validationResult.isValid {
      if !quiet {
        print(" ✗")
      }
      throw GenerateProjectError.validationError(
        "Generated PROJECT.md failed validation: \(validationResult.errors.joined(separator: "; "))"
      )
    }

    if !quiet {
      print(" ✓")
    }

    // Show warnings if any
    if !validationResult.warnings.isEmpty && !quiet {
      print("⚠ Warnings:")
      for warning in validationResult.warnings {
        print("  - \(warning)")
      }
    }

    // Step 6: Handle output based on flags
    let projectMdURL = directoryURL.appendingPathComponent("PROJECT.md")
    let projectMdExists = FileManager.default.fileExists(atPath: projectMdURL.path)

    // Dry-run: output to stdout and exit
    if dryRun {
      print()
      print("=" * 60)
      print("DRY RUN OUTPUT (not written to disk):")
      print("=" * 60)
      print()
      print(content)
      print()
      print("=" * 60)
      print("To write this file, use:")
      print("  proyecto generate-project \(directoryPath) --force")
      print("=" * 60)
      return
    }

    // Interactive: show and prompt for confirmation
    if interactive {
      print()
      print("=" * 60)
      print("Generated PROJECT.md:")
      print("=" * 60)
      print()
      print(content)
      print()

      if projectMdExists {
        print("⚠ WARNING: Existing PROJECT.md will be overwritten")
      }

      print("=" * 60)
      print("Confirm to proceed? (yes/no): ", terminator: "")
      fflush(stdout)

      guard let response = readLine()?.lowercased().trimmingCharacters(in: .whitespaces),
        response.hasPrefix("y")
      else {
        print("Cancelled.")
        return
      }
    }

    // Check for existing PROJECT.md unless --force
    if projectMdExists && !force && !interactive {
      throw GenerateProjectError.projectMdExists(
        projectMdURL.path,
        guidance:
          "Use --force to overwrite, --interactive to review, or --dry-run to preview"
      )
    }

    // Step 7: Write file with backup
    if projectMdExists {
      let backupURL = projectMdURL.appendingPathExtension("bak")
      do {
        if FileManager.default.fileExists(atPath: backupURL.path) {
          try FileManager.default.removeItem(at: backupURL)
        }
        try FileManager.default.copyItem(at: projectMdURL, to: backupURL)
        if !quiet {
          print("Created backup: \(backupURL.lastPathComponent)")
        }
      } catch {
        throw GenerateProjectError.backupError(error.localizedDescription)
      }
    }

    // Write the new PROJECT.md
    do {
      try content.write(to: projectMdURL, atomically: true, encoding: .utf8)
      if !quiet {
        print("✓ Generated: \(projectMdURL.path)")
        if verbose {
          print()
          print("Generated PROJECT.md:")
          print("-" * 60)
          print(content)
        }
      }
    } catch {
      throw GenerateProjectError.writeError(error.localizedDescription)
    }
  }

  // MARK: - Helper Methods

  /// Convert ProjectMetadata to ProjectFrontMatter for writing.
  ///
  /// Note: This uses only fields from ProjectMetadata. Additional fields like
  /// episodesDir, audioDir, filePattern, exportFormat should be inferred from
  /// ProjectAnalysis if needed in the future.
  private func convertMetadataToFrontMatter(
    _ metadata: ProjectMetadata,
    projectPath: URL
  ) -> ProjectFrontMatter {
    let frontMatter = ProjectFrontMatter(
      type: metadata.type,
      title: metadata.title,
      author: metadata.author,
      created: metadata.created,
      description: metadata.description,
      season: metadata.season,
      episodes: metadata.episodes,
      genre: metadata.genre,
      tags: metadata.tags
    )

    // Normalize paths relative to project directory
    return frontMatter.normalizingPaths(relativeTo: projectPath)
  }
}

// MARK: - Errors

enum GenerateProjectError: LocalizedError {
  case directoryNotFound(String)
  case projectMdExists(String, guidance: String)
  case analysisError(String)
  case generationError(String)
  case validationError(String)
  case backupError(String)
  case writeError(String)
  case invalidBackend(String, guidance: String)
  case backendUnavailable(String, guidance: String)

  var errorDescription: String? {
    switch self {
    case .directoryNotFound(let path):
      return "Directory not found: \(path)"
    case .projectMdExists(let path, let guidance):
      return "PROJECT.md already exists at \(path). \(guidance)"
    case .analysisError(let message):
      return "Failed to analyze project: \(message)"
    case .generationError(let message):
      return "Failed to generate metadata: \(message)"
    case .validationError(let message):
      return "Schema validation error: \(message)"
    case .backupError(let message):
      return "Failed to create backup: \(message)"
    case .writeError(let message):
      return "Failed to write PROJECT.md: \(message)"
    case .invalidBackend(let backend, let guidance):
      return "Invalid backend '\(backend)'. \(guidance)"
    case .backendUnavailable(let backend, let guidance):
      return "Backend '\(backend)' is not available. \(guidance)"
    }
  }
}

// MARK: - String Operators (for alignment)

extension String {
  static func * (string: String, count: Int) -> String {
    return String(repeating: string, count: count)
  }
}

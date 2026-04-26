//
//  ProyectoCLI.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import ArgumentParser
import Foundation
import SwiftAcervo
import SwiftBruja
import SwiftProyecto

/// PROJECT.md generator CLI using local LLM inference.
@main
struct ProyectoCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "proyecto",
    abstract: "Generate and manage PROJECT.md files using local LLM inference",
    discussion: """
      Proyecto analyzes a directory structure and uses a local LLM to generate
      PROJECT.md metadata files for podcast and screenplay projects.

      The generated PROJECT.md contains YAML frontmatter with:
        - title, author, description, genre, tags
        - episodesDir, audioDir, filePattern, exportFormat
        - Optional hooks for pre/post generation scripts

      Examples:
        proyecto init                     # Analyze current directory
        proyecto init /path/to/project    # Analyze specific directory
        proyecto init --author "Jane Doe" # Override author field
        proyecto init --update            # Update existing PROJECT.md
        proyecto download                 # Download default LLM model
        proyecto validate                 # Validate PROJECT.md in current directory
        proyecto validate /path/to/dir    # Validate PROJECT.md in specific directory
      """,
    version: SwiftProyecto.version,
    subcommands: [InitCommand.self, DownloadCommand.self, ValidateCommand.self],
    defaultSubcommand: InitCommand.self
  )
}

// MARK: - Download Command

struct DownloadCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "download",
    abstract: "Download an LLM model for use with proyecto",
    discussion: """
      Downloads a model from Cloudflare R2 CDN for local LLM inference.
      Models are stored in ~/Library/SharedModels/

      The default model is optimized for PROJECT.md generation:
        qwen2.5-7b-instruct-4bit (Qwen2.5 7B Instruct, 4-bit quantized, ~4 GB)

      Examples:
        proyecto download                   # Download default model (qwen2.5-7b-instruct-4bit)
        proyecto download --force           # Re-download even if exists
      """
  )

  @Flag(name: .long, help: "Force re-download even if model already exists locally")
  var force: Bool = false

  @Flag(name: .shortAndLong, help: "Suppress progress output")
  var quiet: Bool = false

  mutating func run() async throws {
    let showProgress = !quiet

    // Initialize ModelManager to register components with Acervo
    _ = ModelManager()

    let componentId = LanguageModel.id

    if showProgress {
      print("Downloading model: \(LanguageModel.displayName)")
      print("Component ID: \(componentId)")
      print("Destination: \(Acervo.sharedModelsDirectory.path)")
    }

    do {
      try await Acervo.ensureComponentReady(componentId) { progress in
        if showProgress {
          let percent = progress.overallProgress
          let percentInt = Int(percent * 100)
          print(
            "\rDownloading \(progress.fileName): \(percentInt)% (\(progress.fileIndex + 1)/\(progress.totalFiles) files)",
            terminator: ""
          )
          fflush(stdout)
        }
      }

      if showProgress {
        print("\n✅ Download complete!")
        print("Model available at: \(Acervo.sharedModelsDirectory.appendingPathComponent(Acervo.slugify(componentId)).path)")
      }
    } catch let error as AcervoError {
      print("\n❌ Download failed: \(error.localizedDescription)")
      throw ExitCode.failure
    } catch {
      print("\n❌ Download failed: \(error.localizedDescription)")
      throw ExitCode.failure
    }
  }
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

    // Parse and validate
    let parser = ProjectMarkdownParser()
    do {
      let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)

      // Success!
      print("✅ Valid PROJECT.md: \(projectMdURL.path)")
      print()

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

    } catch let error as ProjectMarkdownParser.ParserError {
      // Validation failed - show detailed error
      print("❌ Invalid PROJECT.md: \(projectMdURL.path)")
      print()
      print("Error: \(error.localizedDescription)")
      throw ExitCode.validationFailure

    } catch {
      // Other errors
      print("❌ Failed to validate PROJECT.md: \(projectMdURL.path)")
      print()
      print("Error: \(error.localizedDescription)")
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

  @Option(name: .long, help: "Model path or HuggingFace ID for LLM inference")
  var model: String = LanguageModel.repoId

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
      model: model,
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

// MARK: - Errors

enum ProyectoError: LocalizedError {
  case directoryNotFound(String)
  case projectMdExists(String)
  case projectMdNotFound(String)
  case parseError(String)
  case llmError(String)

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
    }
  }
}

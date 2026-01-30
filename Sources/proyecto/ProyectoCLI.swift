//
//  ProyectoCLI.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import ArgumentParser
import Foundation
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
            """,
        version: "2.3.0",
        subcommands: [InitCommand.self, DownloadCommand.self],
        defaultSubcommand: InitCommand.self
    )
}

// MARK: - Download Command

struct DownloadCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download an LLM model for use with proyecto",
        discussion: """
            Downloads a model from HuggingFace for local LLM inference.
            Models are stored in ~/Library/Caches/intrusive-memory/Models/LLM/

            The default model is optimized for PROJECT.md generation:
              mlx-community/Phi-3-mini-4k-instruct-4bit (~2.15 GB)

            Examples:
              proyecto download                                    # Download default model
              proyecto download --model "mlx-community/Llama-3-8B" # Download specific model
              proyecto download --force                            # Re-download even if exists
            """
    )

    @Option(name: .long, help: "HuggingFace model ID to download (default: \(Bruja.defaultModel))")
    var model: String = Bruja.defaultModel

    @Flag(name: .long, help: "Force re-download even if model already exists locally")
    var force: Bool = false

    @Flag(name: .shortAndLong, help: "Suppress progress output")
    var quiet: Bool = false

    mutating func run() async throws {
        let showProgress = !quiet

        if showProgress {
            print("Downloading model: \(model)")
            print("Destination: \(Bruja.defaultModelsDirectory.path)")
        }

        try await Bruja.download(model: model, force: force) { progress in
            if showProgress {
                let percent = Int(progress * 100)
                print("\rProgress: \(percent)%", terminator: "")
                fflush(stdout)
            }
        }

        if showProgress {
            print("\nDownload complete!")
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
    var model: String = Bruja.defaultModel

    @Option(name: .long, help: "Override the author field (skip LLM detection)")
    var author: String?

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
              isDir.boolValue else {
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
                    throw ProyectoError.parseError("Failed to parse existing PROJECT.md: \(error.localizedDescription)")
                }
            }
        }

        if !quiet {
            print("Analyzing directory: \(directoryURL.path)")
        }

        // Use iterative generator
        let generator = IterativeProjectGenerator(
            model: model,
            authorOverride: author
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
                episodes: existing.episodes ?? generatedFrontMatter.episodes,  // Preserve existing if set
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
        let content = parser.generate(frontMatter: frontMatter, body: existingBody)

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
    case parseError(String)
    case llmError(String)

    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .projectMdExists(let path):
            return "PROJECT.md already exists at \(path). Use --update to merge or --force to overwrite."
        case .parseError(let message):
            return "Parse error: \(message)"
        case .llmError(let message):
            return "LLM error: \(message)"
        }
    }
}

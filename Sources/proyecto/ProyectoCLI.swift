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
        version: "2.0.1",
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
            Models are stored in ~/Library/Application Support/SwiftBruja/Models/

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

        // Analyze the directory
        let analysis = try analyzeDirectory(at: directoryURL)

        if !quiet {
            print("Found \(analysis.fileCount) files")
            print("Querying LLM for project metadata...")
        }

        // Query the LLM
        let metadata = try await queryLLMForMetadata(
            analysis: analysis,
            model: model,
            authorOverride: author
        )

        // Generate PROJECT.md - merge with existing if updating
        let frontMatter = ProjectFrontMatter(
            type: "project",
            title: metadata.title,
            author: author ?? metadata.author,
            created: existingFrontMatter?.created ?? Date(),  // Preserve original created date
            description: metadata.description,
            season: existingFrontMatter?.season,  // Preserve if exists
            episodes: existingFrontMatter?.episodes,  // Preserve if exists
            genre: metadata.genre,
            tags: metadata.tags,
            episodesDir: metadata.episodesDir,
            audioDir: metadata.audioDir,
            filePattern: metadata.filePattern.map { FilePattern($0) },
            exportFormat: metadata.exportFormat,
            preGenerateHook: existingFrontMatter?.preGenerateHook,  // Preserve hooks
            postGenerateHook: existingFrontMatter?.postGenerateHook  // Preserve hooks
        )

        let parser = ProjectMarkdownParser()
        let content = parser.generate(frontMatter: frontMatter, body: existingBody)

        // Write the file
        try content.write(to: projectMdURL, atomically: true, encoding: .utf8)

        if !quiet {
            if update {
                print("Updated: \(projectMdURL.path)")
            } else {
                print("Generated: \(projectMdURL.path)")
            }
            print("\nPROJECT.md contents:")
            print("---")
            print(content)
        }
    }
}

// MARK: - Directory Analysis

struct DirectoryAnalysis: Sendable {
    let folderName: String
    let folderPath: String
    let fileListing: String
    let readmeContent: String?
    let fileCount: Int
    let detectedPatterns: [String]
}

func analyzeDirectory(at url: URL) throws -> DirectoryAnalysis {
    let fileManager = FileManager.default
    let folderName = url.lastPathComponent

    // Get file listing
    var files: [String] = []
    var detectedExtensions: Set<String> = []

    if let enumerator = fileManager.enumerator(
        at: url,
        includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) {
        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")

            // Skip common build/cache directories
            let skipDirs = [".build", ".git", ".cache", "DerivedData", "node_modules", ".swiftpm"]
            if skipDirs.contains(where: { relativePath.hasPrefix($0) }) {
                continue
            }

            // Skip PROJECT.md itself
            if relativePath == "PROJECT.md" {
                continue
            }

            let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues?.isRegularFile == true {
                files.append(relativePath)
                let ext = fileURL.pathExtension.lowercased()
                if !ext.isEmpty {
                    detectedExtensions.insert(ext)
                }
            }
        }
    }

    // Build file listing (limit to first 50 files for prompt)
    let limitedFiles = Array(files.prefix(50))
    let fileListing = limitedFiles.joined(separator: "\n")
    let fileCount = files.count

    // Detect file patterns
    var patterns: [String] = []
    let interestingExtensions = ["fountain", "fdx", "md", "txt", "mp3", "m4a", "wav", "aif"]
    for ext in interestingExtensions where detectedExtensions.contains(ext) {
        patterns.append("*.\(ext)")
    }

    // Try to read README.md if it exists
    var readmeContent: String?
    let readmeURL = url.appendingPathComponent("README.md")
    if fileManager.fileExists(atPath: readmeURL.path) {
        readmeContent = try? String(contentsOf: readmeURL, encoding: .utf8)
        // Limit README content
        if let content = readmeContent, content.count > 2000 {
            readmeContent = String(content.prefix(2000)) + "\n... (truncated)"
        }
    }

    return DirectoryAnalysis(
        folderName: folderName,
        folderPath: url.path,
        fileListing: fileListing,
        readmeContent: readmeContent,
        fileCount: fileCount,
        detectedPatterns: patterns
    )
}

// MARK: - LLM Query

struct LLMProjectMetadata: Codable, Sendable {
    let title: String
    let author: String
    let description: String
    let genre: String
    let tags: [String]
    let episodesDir: String
    let audioDir: String
    let filePattern: String?
    let exportFormat: String
}

func queryLLMForMetadata(
    analysis: DirectoryAnalysis,
    model: String,
    authorOverride: String?
) async throws -> LLMProjectMetadata {
    let systemPrompt = """
        You are a podcast/screenplay project metadata analyzer. Given a folder structure,
        generate metadata for a PROJECT.md file.

        Output ONLY valid, complete JSON with these exact fields:
        {
          "title": "Project Title",
          "author": "Author Name or Unknown",
          "description": "Brief 1-2 sentence description",
          "genre": "Genre",
          "tags": ["tag1", "tag2", "tag3"],
          "episodesDir": "episodes",
          "audioDir": "audio",
          "filePattern": "*.fountain",
          "exportFormat": "m4a"
        }

        Rules:
        - title: infer from folder name or content, use title case
        - author: detect from README or content, use "Unknown" if not found
        - description: brief 1-2 sentence project description
        - genre: one of "Philosophy", "Education", "Entertainment", "Drama", "Science Fiction"
        - tags: exactly 3-5 relevant keywords as an array
        - episodesDir: detected episodes/scripts folder, default "episodes"
        - audioDir: detected audio folder, default "audio"
        - filePattern: detected file pattern like "*.fountain", or null
        - exportFormat: default "m4a"

        CRITICAL: Output ONLY the JSON object. No markdown, no explanation, no extra text.
        The JSON must be complete and valid - do not truncate any fields.
        """

    // Build a concise prompt (limit file listing to avoid overwhelming the model)
    let limitedFileListing = analysis.fileListing
        .split(separator: "\n")
        .prefix(30)  // Limit to first 30 files
        .joined(separator: "\n")

    var userPrompt = """
        Folder: \(analysis.folderName)
        Total files: \(analysis.fileCount)
        Sample files:
        \(limitedFileListing)
        """

    if let readme = analysis.readmeContent {
        // Limit README to 1000 chars for concise prompt
        let limitedReadme = String(readme.prefix(1000))
        userPrompt += "\n\nREADME:\n\(limitedReadme)"
    }

    if !analysis.detectedPatterns.isEmpty {
        userPrompt += "\n\nFile patterns: \(analysis.detectedPatterns.joined(separator: ", "))"
    }

    userPrompt += "\n\nGenerate the JSON metadata object."

    let metadata: LLMProjectMetadata = try await Bruja.query(
        userPrompt,
        as: LLMProjectMetadata.self,
        model: model,
        temperature: 0.3,
        maxTokens: 4096,
        system: systemPrompt
    )

    return metadata
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

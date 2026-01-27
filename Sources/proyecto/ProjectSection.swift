//
//  ProjectSection.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import Foundation

/// Sections of PROJECT.md metadata that are generated iteratively.
enum ProjectSection: String, CaseIterable, Sendable {
    case title
    case author
    case description
    case genre
    case tags
    case season
    case episodes
    case config

    /// Short display name for progress reporting
    var displayName: String {
        switch self {
        case .title: return "Title"
        case .author: return "Author"
        case .description: return "Description"
        case .genre: return "Genre"
        case .tags: return "Tags"
        case .season: return "Season"
        case .episodes: return "Episodes"
        case .config: return "Generation Config"
        }
    }

    /// Returns the system prompt template for this section.
    /// Placeholders like {directory}, {files}, etc. will be replaced with actual values.
    func systemPrompt(for context: DirectoryContext, previousResults: [ProjectSection: Any]) -> String {
        switch self {
        case .title:
            return """
            You are analyzing a project directory to suggest a title.

            Analyze the folder name, file names, and README to suggest a concise, descriptive title.
            Use title case (capitalize major words).
            Maximum 60 characters.

            Respond with ONLY the title text, no quotes, no explanation, no extra text.
            """

        case .author:
            return """
            You are analyzing a project directory to determine the author.

            Check:
            - Git config author name (if available)
            - README.md author attribution
            - File metadata or copyright notices

            Respond with ONLY the author's name, or "Unknown" if unclear.
            No quotes, no explanation, no extra text.
            """

        case .description:
            let title = previousResults[.title] as? String ?? "this project"
            return """
            You are writing a brief description for a project titled "\(title)".

            Write a concise 1-2 sentence description based on:
            - The project title
            - File structure and patterns
            - README content (if available)

            The description should explain what this project is about.
            Respond with ONLY the description text, no quotes, no explanation.
            """

        case .genre:
            let title = previousResults[.title] as? String ?? "this project"
            return """
            You are categorizing a project titled "\(title)".

            Based on the title, description, and file patterns, suggest a single genre.

            Common genres:
            - Philosophy
            - Education
            - Entertainment
            - Drama
            - Science Fiction
            - Comedy
            - Documentary
            - Thriller

            Respond with ONLY the genre name, no explanation.
            """

        case .tags:
            let title = previousResults[.title] as? String ?? "this project"
            let description = previousResults[.description] as? String ?? ""
            let genre = previousResults[.genre] as? String ?? ""
            return """
            You are generating tags for a project.

            Title: \(title)
            Description: \(description)
            Genre: \(genre)

            Generate 3-5 relevant tags that describe this project.
            Tags should be lowercase, single words or short phrases.

            Respond with ONLY a comma-separated list of tags.
            Example: screenplay, podcast, fiction, season-1
            """

        case .season:
            return """
            You are determining if this is a multi-season project.

            Analyze the folder name and file structure to detect:
            - Season numbers (e.g., "Season 1", "S01", "season-2")
            - Episode numbering schemes (e.g., "s01e01", "1x01")

            If a season is detected, respond with ONLY the season number (e.g., "1", "2").
            If this is not a seasonal project, respond with ONLY the word "none".
            No explanation, no extra text.
            """

        case .episodes:
            return """
            You are counting episode files in this project.

            Look for screenplay or audio files that represent episodes.
            Common patterns:
            - *.fountain files
            - *.fdx files
            - Numbered files (episode-1.txt, ep01.fountain, etc.)

            Count the total number of episode files.

            Respond with ONLY a number (e.g., "10", "24").
            If no episodes detected, respond with ONLY the word "none".
            No explanation, no extra text.
            """

        case .config:
            return """
            You are analyzing the project structure to suggest generation configuration.

            Analyze the directory structure and suggest:
            1. episodesDir: The directory containing episode scripts (default: "episodes")
            2. audioDir: The directory for generated audio files (default: "audio")
            3. filePattern: File pattern to match episode files (e.g., "*.fountain", "*.fdx")
            4. exportFormat: Audio format for export (default: "m4a", alternatives: "mp3", "wav")

            Respond with ONLY a valid JSON object, no markdown, no explanation:
            {"episodesDir": "...", "audioDir": "...", "filePattern": "...", "exportFormat": "..."}

            Example response:
            {"episodesDir": "scripts", "audioDir": "output", "filePattern": "*.fountain", "exportFormat": "m4a"}
            """
        }
    }

    /// Returns the user prompt with context information.
    func userPrompt(for context: DirectoryContext) -> String {
        let baseInfo = """
        Directory: \(context.directoryName)
        Path: \(context.directoryPath)
        Total files: \(context.fileCount)
        Structure: \(context.structure)
        """

        var prompt = baseInfo

        // Add file listing for relevant sections
        switch self {
        case .title, .season, .episodes, .config:
            prompt += "\n\nSample files:\n\(context.fileList)"
        default:
            break
        }

        // Add README for relevant sections
        if let readme = context.readmeExcerpt, [.title, .author, .description, .genre].contains(self) {
            prompt += "\n\nREADME excerpt:\n\(readme)"
        }

        // Add git author for author section
        if self == .author, let gitAuthor = context.gitAuthor {
            prompt += "\n\nGit author: \(gitAuthor)"
        }

        // Add detected patterns for config section
        if self == .config, !context.detectedPatterns.isEmpty {
            prompt += "\n\nDetected file patterns: \(context.detectedPatterns.joined(separator: ", "))"
        }

        return prompt
    }
}

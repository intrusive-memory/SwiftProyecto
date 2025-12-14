//
//  ProjectMarkdownParser.swift
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

/// Parser for PROJECT.md files with YAML front matter.
///
/// Parses markdown files with YAML front matter delimited by `---`:
///
/// ```markdown
/// ---
/// type: project
/// title: My Project
/// author: Jane Doe
/// ---
///
/// # Body content
/// ```
///
public struct ProjectMarkdownParser {

    public enum ParserError: LocalizedError {
        case noFrontMatter
        case invalidYAML(String)
        case missingRequiredField(String)
        case invalidDateFormat(String)

        public var errorDescription: String? {
            switch self {
            case .noFrontMatter:
                return "No YAML front matter found (must be delimited by ---)"
            case .invalidYAML(let message):
                return "Invalid YAML: \(message)"
            case .missingRequiredField(let field):
                return "Missing required field: \(field)"
            case .invalidDateFormat(let value):
                return "Invalid date format: \(value)"
            }
        }
    }

    public init() {}

    /// Parse a PROJECT.md file.
    ///
    /// - Parameter fileURL: URL to the PROJECT.md file
    /// - Returns: Tuple of (frontMatter, bodyContent)
    /// - Throws: ParserError if parsing fails
    public func parse(fileURL: URL) throws -> (ProjectFrontMatter, String) {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return try parse(content: content)
    }

    /// Parse PROJECT.md content string.
    ///
    /// - Parameter content: The markdown content with YAML front matter
    /// - Returns: Tuple of (frontMatter, bodyContent)
    /// - Throws: ParserError if parsing fails
    public func parse(content: String) throws -> (ProjectFrontMatter, String) {
        // Split into lines
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

        // Find front matter delimiters
        guard let firstDelimiter = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            throw ParserError.noFrontMatter
        }

        guard let secondDelimiter = lines[(firstDelimiter + 1)...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            throw ParserError.noFrontMatter
        }

        // Extract YAML front matter
        let yamlLines = lines[(firstDelimiter + 1)..<secondDelimiter]
        let yamlContent = yamlLines.joined(separator: "\n")

        // Extract body content
        let bodyLines = lines[(secondDelimiter + 1)...]
        let bodyContent = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse YAML
        let frontMatter = try parseYAML(yamlContent)

        return (frontMatter, bodyContent)
    }

    /// Generate PROJECT.md content from front matter and body.
    ///
    /// - Parameters:
    ///   - frontMatter: The project metadata
    ///   - body: Optional body content
    /// - Returns: Complete PROJECT.md content string
    public func generate(frontMatter: ProjectFrontMatter, body: String = "") -> String {
        var yaml = "---\n"
        yaml += "type: \(frontMatter.type)\n"
        yaml += "title: \(frontMatter.title)\n"
        yaml += "author: \(frontMatter.author)\n"
        yaml += "created: \(ISO8601DateFormatter().string(from: frontMatter.created))\n"

        if let description = frontMatter.description {
            yaml += "description: \(description)\n"
        }
        if let season = frontMatter.season {
            yaml += "season: \(season)\n"
        }
        if let episodes = frontMatter.episodes {
            yaml += "episodes: \(episodes)\n"
        }
        if let genre = frontMatter.genre {
            yaml += "genre: \(genre)\n"
        }
        if let tags = frontMatter.tags {
            yaml += "tags: [\(tags.joined(separator: ", "))]\n"
        }

        yaml += "---\n"

        if !body.isEmpty {
            yaml += "\n\(body)\n"
        }

        return yaml
    }

    // MARK: - Private Helpers

    private func parseYAML(_ yaml: String) throws -> ProjectFrontMatter {
        var fields: [String: String] = [:]

        for line in yaml.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Split on first colon
            guard let colonIndex = trimmed.firstIndex(of: ":") else {
                continue
            }

            let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)

            fields[key] = value
        }

        // Extract required fields
        guard let type = fields["type"] else {
            throw ParserError.missingRequiredField("type")
        }
        guard let title = fields["title"] else {
            throw ParserError.missingRequiredField("title")
        }
        guard let author = fields["author"] else {
            throw ParserError.missingRequiredField("author")
        }

        // Parse date
        let created: Date
        if let createdString = fields["created"] {
            let formatter = ISO8601DateFormatter()
            guard let date = formatter.date(from: createdString) else {
                throw ParserError.invalidDateFormat(createdString)
            }
            created = date
        } else {
            created = Date()
        }

        // Parse optional fields
        let description = fields["description"]
        let season = fields["season"].flatMap { Int($0) }
        let episodes = fields["episodes"].flatMap { Int($0) }
        let genre = fields["genre"]

        // Parse tags (simple array format: [tag1, tag2])
        let tags: [String]? = fields["tags"].flatMap { value in
            // Remove brackets and split by comma
            let cleaned = value
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            return cleaned.isEmpty ? nil : cleaned
        }

        return ProjectFrontMatter(
            type: type,
            title: title,
            author: author,
            created: created,
            description: description,
            season: season,
            episodes: episodes,
            genre: genre,
            tags: tags
        )
    }
}

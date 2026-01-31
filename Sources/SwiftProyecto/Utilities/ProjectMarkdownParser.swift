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
import Universal

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
        yaml += "type: \(escapeYAMLString(frontMatter.type))\n"
        yaml += "title: \(escapeYAMLString(frontMatter.title))\n"
        yaml += "author: \(escapeYAMLString(frontMatter.author))\n"
        yaml += "created: \(ISO8601DateFormatter().string(from: frontMatter.created))\n"

        if let description = frontMatter.description {
            yaml += "description: \(escapeYAMLString(description))\n"
        }
        if let season = frontMatter.season {
            yaml += "season: \(season)\n"
        }
        if let episodes = frontMatter.episodes {
            yaml += "episodes: \(episodes)\n"
        }
        if let genre = frontMatter.genre {
            yaml += "genre: \(escapeYAMLString(genre))\n"
        }
        if let tags = frontMatter.tags {
            yaml += "tags: [\(tags.map { escapeYAMLString($0) }.joined(separator: ", "))]\n"
        }

        // Generation configuration fields
        if let episodesDir = frontMatter.episodesDir {
            yaml += "episodesDir: \(escapeYAMLString(episodesDir))\n"
        }
        if let audioDir = frontMatter.audioDir {
            yaml += "audioDir: \(escapeYAMLString(audioDir))\n"
        }
        if let filePattern = frontMatter.filePattern {
            yaml += "filePattern: \(formatFilePattern(filePattern))\n"
        }
        if let exportFormat = frontMatter.exportFormat {
            yaml += "exportFormat: \(escapeYAMLString(exportFormat))\n"
        }

        // Cast list
        if let cast = frontMatter.cast, !cast.isEmpty {
            yaml += "cast:\n"
            for member in cast {
                yaml += "  - character: \(escapeYAMLString(member.character))\n"
                if let actor = member.actor {
                    yaml += "    actor: \(escapeYAMLString(actor))\n"
                }
                if !member.voices.isEmpty {
                    yaml += "    voices:\n"
                    for voice in member.voices {
                        yaml += "      - \(escapeYAMLString(voice))\n"
                    }
                }
            }
        }

        // Hook fields
        if let preGenerateHook = frontMatter.preGenerateHook {
            yaml += "preGenerateHook: \(escapeYAMLString(preGenerateHook))\n"
        }
        if let postGenerateHook = frontMatter.postGenerateHook {
            yaml += "postGenerateHook: \(escapeYAMLString(postGenerateHook))\n"
        }

        // TTS configuration
        if let tts = frontMatter.tts {
            yaml += "tts:\n"
            if let providerId = tts.providerId {
                yaml += "  providerId: \(escapeYAMLString(providerId))\n"
            }
            if let voiceId = tts.voiceId {
                yaml += "  voiceId: \(escapeYAMLString(voiceId))\n"
            }
            if let languageCode = tts.languageCode {
                yaml += "  languageCode: \(escapeYAMLString(languageCode))\n"
            }
            if let voiceURI = tts.voiceURI {
                yaml += "  voiceURI: \(escapeYAMLString(voiceURI))\n"
            }
        }

        yaml += "---\n"

        if !body.isEmpty {
            yaml += "\n\(body)\n"
        }

        return yaml
    }

    /// Generate YAML for an app section.
    private func generateAppSectionYAML(key: String, value: AnyCodable) throws -> String {
        // Decode AnyCodable to get the actual value
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        // Generate YAML for this section
        var yaml = "\(key):\n"
        yaml += generateYAMLValue(jsonObject, indent: 1)
        return yaml
    }

    /// Recursively generate YAML for a value with proper indentation.
    private func generateYAMLValue(_ value: Any, indent: Int) -> String {
        let indentStr = String(repeating: "  ", count: indent)

        if let dict = value as? [String: Any] {
            var yaml = ""
            for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
                if let nestedDict = val as? [String: Any] {
                    yaml += "\(indentStr)\(key):\n"
                    yaml += generateYAMLValue(nestedDict, indent: indent + 1)
                } else if let array = val as? [Any] {
                    yaml += "\(indentStr)\(key):\n"
                    for item in array {
                        if let itemDict = item as? [String: Any] {
                            yaml += "\(indentStr)  -\n"
                            for (k, v) in itemDict.sorted(by: { $0.key < $1.key }) {
                                yaml += "\(indentStr)    \(k): \(formatYAMLPrimitive(v))\n"
                            }
                        } else {
                            yaml += "\(indentStr)  - \(formatYAMLPrimitive(item))\n"
                        }
                    }
                } else {
                    yaml += "\(indentStr)\(key): \(formatYAMLPrimitive(val))\n"
                }
            }
            return yaml
        } else if let array = value as? [Any] {
            var yaml = ""
            for item in array {
                yaml += "\(indentStr)- \(formatYAMLPrimitive(item))\n"
            }
            return yaml
        } else {
            return "\(indentStr)\(formatYAMLPrimitive(value))\n"
        }
    }

    /// Format a primitive value for YAML output.
    private func formatYAMLPrimitive(_ value: Any) -> String {
        if let string = value as? String {
            return escapeYAMLString(string)
        } else if let number = value as? NSNumber {
            // Check if it's a boolean (NSNumber can represent bools)
            if CFBooleanGetTypeID() == CFGetTypeID(number as CFTypeRef) {
                return number.boolValue ? "true" : "false"
            }
            return "\(number)"
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let int = value as? Int {
            return "\(int)"
        } else if let double = value as? Double {
            return "\(double)"
        } else {
            return escapeYAMLString("\(value)")
        }
    }

    /// Format a FilePattern for YAML output.
    private func formatFilePattern(_ pattern: FilePattern) -> String {
        switch pattern {
        case .single(let value):
            return "\"\(value)\""
        case .multiple(let values):
            return "[\(values.map { "\"\($0)\"" }.joined(separator: ", "))]"
        }
    }

    /// Safely escape a string for YAML output.
    ///
    /// Determines if a string needs quoting and applies appropriate escaping:
    /// - Strings with special characters (quotes, colons, etc.) are quoted
    /// - Double quotes inside strings are escaped
    /// - Empty strings and strings with leading/trailing whitespace are quoted
    ///
    /// - Parameter string: The string to escape
    /// - Returns: A YAML-safe string representation
    private func escapeYAMLString(_ string: String) -> String {
        // Empty strings need quotes
        if string.isEmpty {
            return "\"\""
        }

        // Check if string needs quoting
        let needsQuoting = string.contains(where: { char in
            // YAML special characters that require quoting
            "\"':{}[],&*#?|<>=!%@`".contains(char)
        }) || string.hasPrefix("@") || string.hasPrefix("%") ||
           string.hasPrefix(" ") || string.hasSuffix(" ") ||
           string.contains("\n") || string.contains("\t")

        if !needsQuoting {
            return string
        }

        // Use double quotes and escape internal double quotes
        let escaped = string.replacingOccurrences(of: "\\", with: "\\\\")
                           .replacingOccurrences(of: "\"", with: "\\\"")
                           .replacingOccurrences(of: "\n", with: "\\n")
                           .replacingOccurrences(of: "\t", with: "\\t")

        return "\"\(escaped)\""
    }

    // MARK: - Private Helpers

    private func parseYAML(_ yaml: String) throws -> ProjectFrontMatter {
        do {
            // Parse YAML to native structure
            let yamlData = try YAML.parse(Data(yaml.utf8))

            // Convert to JSON for Decodable
            let json = try yamlData.json()

            // Decode to ProjectFrontMatter using UNIVERSAL's Decodable extension
            let options = JSONDecodingOptions(dateDecodingStrategy: .iso8601)
            return try ProjectFrontMatter(json: json, options: options)

        } catch let error as DecodingError {
            // Handle missing required fields
            switch error {
            case .keyNotFound(let key, _):
                throw ParserError.missingRequiredField(key.stringValue)
            case .dataCorrupted(let context):
                throw ParserError.invalidYAML(context.debugDescription)
            case .typeMismatch(_, let context):
                throw ParserError.invalidYAML(context.debugDescription)
            case .valueNotFound(let type, let context):
                throw ParserError.invalidYAML("Missing value of type \(type): \(context.debugDescription)")
            @unknown default:
                throw ParserError.invalidYAML(error.localizedDescription)
            }
        } catch {
            throw ParserError.invalidYAML(error.localizedDescription)
        }
    }
}

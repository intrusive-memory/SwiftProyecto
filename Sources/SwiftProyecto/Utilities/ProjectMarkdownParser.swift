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
    guard
      let firstDelimiter = lines.firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == "---"
      })
    else {
      throw ParserError.noFrontMatter
    }

    guard
      let secondDelimiter = lines[(firstDelimiter + 1)...].firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == "---"
      })
    else {
      throw ParserError.noFrontMatter
    }

    // Extract YAML front matter
    let yamlLines = lines[(firstDelimiter + 1)..<secondDelimiter]
    let yamlContent = yamlLines.joined(separator: "\n")

    // Extract body content
    let bodyLines = lines[(secondDelimiter + 1)...]
    let bodyContent = bodyLines.joined(separator: "\n").trimmingCharacters(
      in: .whitespacesAndNewlines)

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
    if let updated = frontMatter.updated {
      yaml += "updated: \(ISO8601DateFormatter().string(from: updated))\n"
    }

    if let description = frontMatter.description {
      yaml += "description: \(escapeYAMLString(description))\n"
    }
    if let genre = frontMatter.genre {
      yaml += "genre: \(escapeYAMLString(genre))\n"
    }
    if let tags = frontMatter.tags {
      yaml += "tags: [\(tags.map { escapeYAMLString($0) }.joined(separator: ", "))]\n"
    }

    // Versioned schema fields
    yaml += "schemaVersion: \(ProjectSchemaVersion.current)\n"
    if let projectType = frontMatter.projectType {
      yaml += "projectType: \(escapeYAMLString(projectType))\n"
    }
    if let seasons = frontMatter.seasons, !seasons.isEmpty {
      yaml += "seasons:\n"
      for season in seasons {
        yaml += "  - number: \(season.number)\n"
        if let title = season.title {
          yaml += "    title: \(escapeYAMLString(title))\n"
        }
        if let description = season.description {
          yaml += "    description: \(escapeYAMLString(description))\n"
        }
        yaml += "    episodes: \(season.episodes)\n"
        if let releaseDate = season.releaseDate {
          yaml += "    releaseDate: \(ISO8601DateFormatter().string(from: releaseDate))\n"
        }
        if let episodesDir = season.episodesDir {
          yaml += "    episodesDir: \(escapeYAMLString(episodesDir))\n"
        }
      }
    }
    if let languages = frontMatter.languages, !languages.isEmpty {
      yaml += "languages:\n"
      for language in languages {
        yaml += "  - code: \(escapeYAMLString(language.code))\n"
        yaml += "    name: \(escapeYAMLString(language.name))\n"
        if let locale = language.locale {
          yaml += "    locale: \(escapeYAMLString(locale))\n"
        }
      }
    }
    if let variants = frontMatter.variants, !variants.isEmpty {
      yaml += "variants:\n"
      for variant in variants {
        yaml += "  - season: \(variant.season)\n"
        yaml += "    language: \(escapeYAMLString(variant.language))\n"
        yaml += "    path: \(escapeYAMLString(variant.path))\n"
        if let status = variant.status {
          yaml += "    status: \(status.rawValue)\n"
        }
      }
    }
    if let episodePath = frontMatter.episodePath {
      yaml += "episodePath: \(escapeYAMLString(episodePath))\n"
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

    // Intro/outro asset references.
    //
    // These are known top-level keys (see ``ProjectFrontMatter/KnownCodingKeys``),
    // so they are NOT captured by the `appSections` catch-all on decode. They must
    // therefore be emitted explicitly here, or a full-frontmatter re-emit would
    // silently drop them on write-back (issue intrusive-memory/SwiftEchada#55).
    if let introFile = frontMatter.introFile {
      yaml += "introFile: \(escapeYAMLString(introFile))\n"
    }
    if let outroFile = frontMatter.outroFile {
      yaml += "outroFile: \(escapeYAMLString(outroFile))\n"
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
      if let model = tts.model {
        yaml += "  model: \(escapeYAMLString(model))\n"
      }
      if let actionLineVoice = tts.actionLineVoice {
        yaml += "  actionLineVoice: \(escapeYAMLString(actionLineVoice))\n"
      }
    }

    // App-specific settings sections (at root level)
    if !frontMatter.appSections.isEmpty {
      for (key, value) in frontMatter.appSections.sorted(by: { $0.key < $1.key }) {
        yaml += try! generateAppSectionYAML(key: key, value: value)
      }
    }

    yaml += "---\n"

    if !body.isEmpty {
      yaml += "\n\(body)\n"
    }

    return yaml
  }

  /// Surgically remove the top-level `cast:` block from existing PROJECT.md
  /// text, leaving every other byte untouched.
  ///
  /// This is the lossless removal path used by cast migration (schema v5).
  /// Rather than re-emitting the whole frontmatter from the typed model —
  /// which reorders keys, drops comments, and (historically) silently deleted
  /// any key the hand-rolled emitter forgot (issue
  /// intrusive-memory/SwiftEchada#55, #44) — it performs a line-span deletion
  /// of just the `cast:` subtree. Intro/outro keys, inline comments, unknown
  /// top-level keys, key ordering, and spacing are all byte-identical by
  /// construction.
  ///
  /// **Callers must only invoke this after the cast data has been verifiably
  /// migrated to CAST.md** (via `reparto import`). Removing the block without
  /// that verification is exactly the data loss the preservation mechanism
  /// exists to prevent.
  ///
  /// Algorithm:
  /// 1. Locate the `---` … `---` frontmatter delimiters.
  /// 2. Find the top-level `cast:` key (column 0) and consume the run of
  ///    more-indented lines belonging to it. Blank lines and column-0 comments
  ///    interior to the block are consumed too — only the next column-0 key (or
  ///    the closing `---`) ends it. Trailing blanks/comments stay outside.
  /// 3. Delete exactly those lines.
  ///
  /// - Parameter original: The complete, original PROJECT.md file text.
  /// - Returns: New file text identical to `original` except the `cast:` block
  ///   is gone. If there is no top-level `cast:` key, `original` is returned
  ///   unchanged.
  /// - Throws: ``ParserError/noFrontMatter`` if no `---` … `---` block is found.
  public func removingCastBlock(in original: String) throws -> String {
    var lines = original.components(separatedBy: "\n")

    let (firstDelim, secondDelim) = try frontMatterDelimiters(in: lines)

    // Find the top-level `cast:` key at column 0 within the frontmatter.
    var castStart: Int?
    for index in (firstDelim + 1)..<secondDelim {
      let line = lines[index]
      guard let first = line.first, first != " ", first != "\t" else { continue }
      let key = line.prefix(while: { $0 != ":" })
      if key == "cast" {
        castStart = index
        break
      }
    }

    guard let start = castStart else { return original }

    // Consume the run of lines belonging to the block.
    //
    // A blank line does NOT end the block. Hand-maintained project files
    // routinely separate cast entries with one, and treating a blank as the
    // terminator left every entry after it in place but still indented — YAML
    // then parsed the orphans as a malformed document. Column-0 comments are
    // treated the same way, for the same reason.
    //
    // Blanks and comments are therefore scanned past *tentatively*: `end`
    // only advances to cover them once a further indented line proves they
    // were interior to the block. Trailing blanks and comments stay outside,
    // since they separate `cast:` from whatever follows rather than belonging
    // to it.
    var end = start + 1
    var scan = end
    while scan < secondDelim {
      let line = lines[scan]
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty || trimmed.hasPrefix("#") {
        scan += 1
        continue
      }
      guard let first = line.first, first == " " || first == "\t" else { break }
      scan += 1
      end = scan
    }
    lines.removeSubrange(start..<end)

    return lines.joined(separator: "\n")
  }

  /// Surgically set the top-level `schemaVersion:` line in existing PROJECT.md
  /// text, leaving every other byte untouched.
  ///
  /// Used by cast migration to stamp ``ProjectSchemaVersion/current`` onto a
  /// legacy document without paying the full re-emit's costs (key reordering,
  /// comment loss). If the document already declares a `schemaVersion:`, that
  /// line is replaced in place; otherwise the line is inserted immediately
  /// after the opening `---`.
  ///
  /// - Parameters:
  ///   - original: The complete, original PROJECT.md file text.
  ///   - version: The version to stamp (defaults to
  ///     ``ProjectSchemaVersion/current``).
  /// - Returns: New file text identical to `original` except for the
  ///   `schemaVersion:` line.
  /// - Throws: ``ParserError/noFrontMatter`` if no `---` … `---` block is found.
  public func stampingSchemaVersion(
    in original: String, to version: Int = ProjectSchemaVersion.current
  ) throws -> String {
    var lines = original.components(separatedBy: "\n")

    let (firstDelim, secondDelim) = try frontMatterDelimiters(in: lines)

    for index in (firstDelim + 1)..<secondDelim {
      let line = lines[index]
      guard let first = line.first, first != " ", first != "\t" else { continue }
      if line.prefix(while: { $0 != ":" }) == "schemaVersion" {
        lines[index] = "schemaVersion: \(version)"
        return lines.joined(separator: "\n")
      }
    }

    lines.insert("schemaVersion: \(version)", at: firstDelim + 1)
    return lines.joined(separator: "\n")
  }

  /// Locate the `---` … `---` front-matter delimiter line indices.
  private func frontMatterDelimiters(in lines: [String]) throws -> (Int, Int) {
    guard
      let firstDelim = lines.firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == "---"
      })
    else {
      throw ParserError.noFrontMatter
    }
    guard
      let secondDelim = lines[(firstDelim + 1)...].firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == "---"
      })
    else {
      throw ParserError.noFrontMatter
    }
    return (firstDelim, secondDelim)
  }

  /// Generate YAML for an app section.
  private func generateAppSectionYAML(key: String, value: AnyCodable) throws -> String {
    // Decode AnyCodable to get the actual value
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    // `.fragmentsAllowed` so an unknown top-level key holding a *scalar* (e.g.
    // `episodes_index: episodes/index.json`) round-trips instead of crashing.
    // These scalar unknown keys are exactly the #44/#55 loss class.
    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])

    // Nested collections descend under a `key:` header; scalars render inline.
    if jsonObject is [String: Any] || jsonObject is [Any] {
      var yaml = "\(key):\n"
      yaml += generateYAMLValue(jsonObject, indent: 1)
      return yaml
    } else {
      return "\(key): \(formatYAMLPrimitive(jsonObject))\n"
    }
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
    let needsQuoting =
      string.contains(where: { char in
        // YAML special characters that require quoting
        "\"':{}[],&*#?|<>=!%@`".contains(char)
      }) || string.hasPrefix("@") || string.hasPrefix("%") || string.hasPrefix(" ")
      || string.hasSuffix(" ") || string.contains("\n") || string.contains("\t")

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

// MARK: - File Writing

extension ProjectMarkdownParser {

  /// Write PROJECT.md content to a file on disk.
  ///
  /// Generates the PROJECT.md content from the provided front matter and body,
  /// then writes it atomically to the specified URL. Atomic writes ensure that
  /// the file is either fully written or not modified at all, preventing corruption.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// let parser = ProjectMarkdownParser()
  /// let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)
  ///
  /// // Modify front matter as needed
  /// let updated = frontMatter.mergingCast(newCast, forProvider: "apple")
  ///
  /// // Write back to disk
  /// try parser.write(frontMatter: updated, body: body, to: projectMdURL)
  /// ```
  ///
  /// - Parameters:
  ///   - frontMatter: The project metadata to serialize.
  ///   - body: The body content to include after the YAML front matter.
  ///   - url: The file URL to write to. The file will be created if it does not exist,
  ///     or overwritten if it does.
  /// - Throws: An error if the file cannot be written to the specified URL.
  public func write(
    frontMatter: ProjectFrontMatter,
    body: String,
    to url: URL
  ) throws {
    let content = generate(frontMatter: frontMatter, body: body)
    try content.write(to: url, atomically: true, encoding: .utf8)
  }
}

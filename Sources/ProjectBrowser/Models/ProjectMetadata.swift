import Foundation

/// Descriptive metadata about the project directory being browsed,
/// typically sourced from a `PROJECT.md` file at the root of the directory.
///
/// ``ProjectHeader`` (WU3) displays this metadata above the file tree.
///
/// ## Example
///
/// ```swift
/// let metadata = ProjectMetadata(
///   title: "Confessions",
///   author: "Tom Stovall",
///   description: "A serialized audio drama.",
///   created: Date()
/// )
/// ```
public struct ProjectMetadata: Codable, Hashable, Equatable, Sendable {

  /// The project's display title.
  public let title: String

  /// The project's author, if known.
  public let author: String?

  /// A short description of the project, if provided.
  public let description: String?

  /// The date the project was created, if known.
  public let created: Date?

  public init(
    title: String,
    author: String? = nil,
    description: String? = nil,
    created: Date? = nil
  ) {
    self.title = title
    self.author = author
    self.description = description
    self.created = created
  }
}

// MARK: - Loading from PROJECT.md

extension ProjectMetadata {

  /// Errors that can occur while loading ``ProjectMetadata`` from a
  /// `PROJECT.md` file.
  public enum LoadError: Error, Equatable, Sendable {
    /// `PROJECT.md` was found but could not be decoded as UTF-8 text.
    case invalidEncoding
    /// `PROJECT.md` was found but has no YAML front matter (no leading
    /// `---` delimiter), or the front matter block was never closed.
    case missingFrontMatter
    /// The YAML front matter did not contain a `title` field, which is
    /// required to construct ``ProjectMetadata``.
    case missingTitle
  }

  /// Looks for a `PROJECT.md` file directly inside `rootURL` and, if
  /// present, parses its YAML front matter into a ``ProjectMetadata``.
  ///
  /// Only a small, dependency-free subset of YAML is supported — simple
  /// `key: value` pairs (optionally quoted) between a pair of `---`
  /// delimiters at the top of the file. This is sufficient for the
  /// `title` / `author` / `description` / `created` fields consumed by
  /// `ProjectHeader`; anything beyond that (nested structures, lists,
  /// multi-line scalars) is ignored.
  ///
  /// - Parameter rootURL: The project's root directory.
  /// - Returns: The parsed metadata, or `nil` if `PROJECT.md` does not
  ///   exist in `rootURL`.
  /// - Throws: ``LoadError`` if `PROJECT.md` exists but cannot be read as
  ///   UTF-8 text, has no YAML front matter, or is missing the required
  ///   `title` field.
  public static func load(from rootURL: URL) async throws -> ProjectMetadata? {
    let fileURL = rootURL.appendingPathComponent("PROJECT.md")

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return nil
    }

    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch {
      // Treat IO errors (permissions, races with concurrent deletion,
      // etc.) the same as "no PROJECT.md" so a single unreadable file
      // doesn't crash the browser.
      return nil
    }

    guard let text = String(data: data, encoding: .utf8) else {
      throw LoadError.invalidEncoding
    }

    let fields = try parseFrontMatter(text)

    guard let title = fields["title"] else {
      throw LoadError.missingTitle
    }

    return ProjectMetadata(
      title: title,
      author: fields["author"],
      description: fields["description"],
      created: fields["created"].flatMap(parseDate)
    )
  }

  // MARK: - Private parsing helpers

  /// Extracts the raw key/value pairs from the YAML front matter block at
  /// the top of `text` (the region between the first and second `---`
  /// lines).
  private static func parseFrontMatter(_ text: String) throws -> [String: String] {
    var lines = text.components(separatedBy: .newlines)[...]

    // Skip any leading blank lines before the opening delimiter.
    while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
      lines.removeFirst()
    }

    guard let opening = lines.first,
      opening.trimmingCharacters(in: .whitespaces) == "---"
    else {
      throw LoadError.missingFrontMatter
    }
    lines.removeFirst()

    var body: [Substring] = []
    var closed = false
    for line in lines {
      if line.trimmingCharacters(in: .whitespaces) == "---" {
        closed = true
        break
      }
      body.append(Substring(line))
    }

    guard closed else {
      throw LoadError.missingFrontMatter
    }

    var fields: [String: String] = [:]
    for rawLine in body {
      guard let (key, value) = parseKeyValue(String(rawLine)) else {
        continue
      }
      fields[key] = value
    }
    return fields
  }

  /// Parses a single `key: value` line, supporting both quoted and
  /// unquoted scalar values. Returns `nil` for blank lines, comments, or
  /// lines that aren't simple scalar assignments (e.g. list items or
  /// nested mapping keys), which are silently skipped rather than
  /// treated as fatal parse errors.
  private static func parseKeyValue(_ line: String) -> (key: String, value: String)? {
    let trimmedLine = line.trimmingCharacters(in: .whitespaces)

    guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else {
      return nil
    }

    // Skip lines that are indented (nested mappings/lists) or that start
    // a list item — only top-level scalar keys are supported.
    guard !line.hasPrefix(" "), !line.hasPrefix("\t"), !trimmedLine.hasPrefix("-") else {
      return nil
    }

    guard let colonIndex = trimmedLine.firstIndex(of: ":") else {
      return nil
    }

    let key = trimmedLine[trimmedLine.startIndex..<colonIndex]
      .trimmingCharacters(in: .whitespaces)
    guard !key.isEmpty else {
      return nil
    }

    var value = trimmedLine[trimmedLine.index(after: colonIndex)...]
      .trimmingCharacters(in: .whitespaces)

    value = unquote(value)

    return (key, value)
  }

  /// Strips a single layer of matching single or double quotes from
  /// `value`, if present.
  private static func unquote(_ value: String) -> String {
    guard value.count >= 2 else {
      return value
    }
    if value.hasPrefix("\"") && value.hasSuffix("\"") {
      return String(value.dropFirst().dropLast())
    }
    if value.hasPrefix("'") && value.hasSuffix("'") {
      return String(value.dropFirst().dropLast())
    }
    return value
  }

  /// Parses a `created` value using ISO 8601, falling back to a
  /// `yyyy-MM-dd` date-only format (common in hand-written front matter).
  private static func parseDate(_ value: String) -> Date? {
    guard !value.isEmpty else {
      return nil
    }

    let iso8601 = ISO8601DateFormatter()
    if let date = iso8601.date(from: value) {
      return date
    }

    iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso8601.date(from: value) {
      return date
    }

    let dateOnlyFormatter = DateFormatter()
    dateOnlyFormatter.calendar = Calendar(identifier: .iso8601)
    dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")
    dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
    return dateOnlyFormatter.date(from: value)
  }
}

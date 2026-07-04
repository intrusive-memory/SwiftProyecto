//
//  RolesCommand.swift
//  proyecto CLI
//
//  Copyright (c) 2025 Intrusive Memory
//

import ArgumentParser
import Foundation
import FoundationModels
import SwiftProyecto

#if canImport(Darwin)
  import Darwin
#endif

/// Extract speaking roles from one or more screenplays using the local model.
///
/// Ingests a single screenplay, a directory of screenplays, or a filespec glob,
/// runs an on-device Foundation Models query (Apple's system language model, via
/// guided generation) against each script **sequentially**, compiles a
/// project-wide deduplicated list of speaking roles, and stores it in the `cast:`
/// list of the project's `PROJECT.md` front matter.
///
/// Existing cast entries (with their actor/voice/gender assignments) are
/// preserved; only newly-discovered roles are appended.
///
/// ## Examples
///
/// ```
/// proyecto roles                          # discover *.fountain under PROJECT.md dir
/// proyecto roles episode.fountain         # a single screenplay
/// proyecto roles 'episodes/*.fountain'    # a glob (quote it so the shell doesn't expand)
/// proyecto roles ./scripts --dry-run      # a directory, preview without writing
/// ```
struct RolesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "roles",
    abstract: "Extract speaking roles from screenplays with the local model into PROJECT.md",
    discussion: """
      Reads a screenplay (or every screenplay matched by a glob / found in a
      directory), asks the local language model to identify the speaking roles in
      each, and compiles a project-wide cast list stored under `cast:` in
      PROJECT.md.

      Model:
        Uses Apple's on-device Foundation Models system model with guided
        generation. Requires Apple Intelligence to be enabled; nothing is
        downloaded and no data leaves the device.

      Input resolution (the optional argument):
        - omitted        -> discover *.fountain recursively under --project-dir
        - a file         -> that single screenplay
        - a directory    -> *.fountain found recursively within it
        - a glob         -> every matching file (quote it: 'episodes/*.fountain')

      Merge behavior:
        Existing cast members keep their actor/voice/gender assignments; only
        roles not already present are appended. Use --dry-run to preview.

      Examples:
        proyecto roles
        proyecto roles episode.fountain
        proyecto roles 'episodes/*.fountain' --dry-run
        proyecto roles ./scripts --project-dir .
      """
  )

  @Argument(
    help: "Screenplay file, directory, or glob to scan (default: *.fountain under --project-dir)")
  var input: String?

  @Option(name: .long, help: "Directory containing PROJECT.md (default: current directory)")
  var projectDir: String?

  @Flag(name: .long, help: "Print the compiled roles without writing PROJECT.md")
  var dryRun: Bool = false

  @Flag(name: .shortAndLong, help: "Suppress progress output")
  var quiet: Bool = false

  /// Structured result the on-device model is guided to return per screenplay.
  ///
  /// Marked `@Generable` so Foundation Models fills in a well-formed `roles`
  /// array via constrained sampling — there is no raw JSON string to hand-parse.
  @Generable(description: "The speaking roles found in a single screenplay")
  struct RoleList {
    @Guide(
      description:
        "Every distinct speaking character's name in uppercase, deduplicated, excluding scene headings and transitions"
    )
    let roles: [String]
  }

  func run() async throws {
    let showProgress = !quiet
    let fm = FileManager.default

    // Warn on macOS 26: Foundation Models shipped with an underpowered core model.
    // macOS 27 includes a larger, more accurate 3m model. Results on 26 will be less accurate.
    if #available(macOS 27, *) {
      // Running on macOS 27+, no warning needed
    } else {
      if showProgress {
        print("""
          ⚠ Warning: You are running on macOS 26, which ships with an underpowered \
          Foundation Model. For more accurate results, upgrade to macOS 27 or later, \
          which includes a larger 3m model optimized for this task.
          """)
      }
    }

    // Resolve where PROJECT.md lives.
    let projectDirURL: URL = {
      if let projectDir { return URL(fileURLWithPath: projectDir).standardizedFileURL }
      if let input {
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: input, isDirectory: &isDir), isDir.boolValue {
          return URL(fileURLWithPath: input).standardizedFileURL
        }
      }
      return URL(fileURLWithPath: fm.currentDirectoryPath)
    }()
    let projectMdURL = projectDirURL.appendingPathComponent("PROJECT.md")

    // Resolve the list of screenplay files to process.
    let scripts = try resolveScripts(input: input, projectDir: projectDirURL)
    guard !scripts.isEmpty else {
      throw RolesError.noScripts(input ?? projectDirURL.path)
    }
    if showProgress {
      print("Found \(scripts.count) screenplay\(scripts.count == 1 ? "" : "s") to scan")
    }

    // Role extraction runs entirely on-device via Apple's Foundation Models
    // system model with guided generation — no model download, no MLX, no
    // network. Fail fast if Apple Intelligence is unavailable so the user fixes
    // the configuration instead of silently getting only the regex pre-pass.
    guard SystemLanguageModel.default.isAvailable else {
      throw RolesError.appleIntelligenceUnavailable
    }

    // Process each screenplay sequentially, accumulating a project-wide list.
    // Dedup case-insensitively while preserving first-seen casing and order.
    var compiled: [String] = []
    var seen = Set<String>()
    let extractor = CastExtractor()

    for (index, script) in scripts.enumerated() {
      let label = script.lastPathComponent
      if showProgress {
        print("[\(index + 1)/\(scripts.count)] \(label): querying model...")
      }

      guard let text = try? String(contentsOf: script, encoding: .utf8) else {
        if showProgress { print("  ⚠ skipped (not readable as UTF-8 text)") }
        continue
      }

      let candidates = extractor.extractCast(from: text)
      let roles: [String]
      do {
        // A fresh session per screenplay keeps each extraction independent and
        // avoids accumulating prior scripts in the context window.
        let session = LanguageModelSession(instructions: Self.systemPrompt)
        let response = try await session.respond(
          to: Self.userPrompt(script: text, candidates: candidates),
          generating: RoleList.self,
          options: GenerationOptions(temperature: 0.2)
        )
        roles = response.content.roles
      } catch {
        // Fall back to the deterministic extractor so one bad script doesn't
        // sink the whole run — but be loud about it.
        if showProgress {
          print("  ⚠ model query failed (\(error.localizedDescription)); using regex extraction")
        }
        roles = candidates
      }

      var added = 0
      for role in roles {
        let name = role.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { continue }
        let key = name.uppercased()
        if seen.insert(key).inserted {
          compiled.append(name)
          added += 1
        }
      }
      if showProgress {
        print("  ✓ \(roles.count) role(s) found, \(added) new (running total: \(compiled.count))")
      }
    }

    guard !compiled.isEmpty else {
      throw RolesError.noRoles
    }

    if showProgress {
      print("\nProject-wide speaking roles (\(compiled.count)):")
      for role in compiled { print("  - \(role)") }
    }

    if dryRun {
      if showProgress { print("\n(dry run — PROJECT.md not modified)") }
      return
    }

    // Merge into PROJECT.md front matter.
    guard fm.fileExists(atPath: projectMdURL.path) else {
      throw RolesError.projectMdMissing(projectMdURL.path)
    }
    let parser = ProjectMarkdownParser()
    var (frontMatter, body) = try parser.parse(fileURL: projectMdURL)

    let existing = frontMatter.cast ?? []
    var existingKeys = Set(existing.map { $0.character.uppercased() })
    var mergedCast = existing
    var appended = 0
    for role in compiled where existingKeys.insert(role.uppercased()).inserted {
      mergedCast.append(CastMember(character: role))
      appended += 1
    }
    frontMatter.cast = mergedCast

    // Back up before overwriting, matching the other write commands.
    let backupURL = projectMdURL.appendingPathExtension("bak")
    if fm.fileExists(atPath: backupURL.path) {
      try fm.removeItem(at: backupURL)
    }
    try fm.copyItem(at: projectMdURL, to: backupURL)

    let content = parser.generate(frontMatter: frontMatter, body: body)
    try content.write(to: projectMdURL, atomically: true, encoding: .utf8)

    if showProgress {
      print(
        "\n✓ Updated \(projectMdURL.path): \(appended) new role(s) added, "
          + "\(mergedCast.count) total in cast (backup: \(backupURL.lastPathComponent))")
    }
  }

  // MARK: - Prompts

  private static let systemPrompt = """
    You are a script supervisor. Given a screenplay, identify the SPEAKING roles:
    characters who are given at least one line of dialogue. Use the character's
    name exactly as it appears in the dialogue cue, in uppercase. Merge
    continuation variants like "(CONT'D)", "(V.O.)", "(O.S.)" into the base name.
    Exclude scene headings, transitions, and characters who are only mentioned but
    never speak. Return every speaking role you find, with no duplicates.
    """

  private static func userPrompt(script: String, candidates: [String]) -> String {
    // Keep the script excerpt bounded; the candidate list is derived from the
    // FULL text so completeness does not depend on the excerpt length.
    let excerpt = String(script.prefix(24_000))
    let candidateBlock =
      candidates.isEmpty ? "(none detected)" : candidates.joined(separator: ", ")
    return """
      Extract the speaking roles from the following screenplay.

      A regex pre-pass detected these candidate character cues (may include false
      positives or miss some): \(candidateBlock)

      List every distinct speaking role you find.

      SCREENPLAY:
      \(excerpt)
      """
  }

  // MARK: - Script Resolution

  private func resolveScripts(input: String?, projectDir: URL) throws -> [URL] {
    let fm = FileManager.default

    guard let input else {
      // No input: discover *.fountain recursively under the project directory.
      return Self.discoverFountain(in: projectDir)
    }

    // A glob pattern?
    if input.contains(where: { "*?[{".contains($0) }) {
      return Self.expandGlob(input)
        .map { URL(fileURLWithPath: $0).standardizedFileURL }
        .filter { !$0.hasDirectoryPath }
        .sorted { $0.path < $1.path }
    }

    // A directory or a single file?
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: input, isDirectory: &isDir) else {
      throw RolesError.inputNotFound(input)
    }
    if isDir.boolValue {
      return Self.discoverFountain(in: URL(fileURLWithPath: input).standardizedFileURL)
    }
    return [URL(fileURLWithPath: input).standardizedFileURL]
  }

  /// Recursively find `.fountain` files under a directory, sorted by path.
  private static func discoverFountain(in directory: URL) -> [URL] {
    let fm = FileManager.default
    guard
      let enumerator = fm.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles])
    else { return [] }

    var results: [URL] = []
    for case let url as URL in enumerator where url.pathExtension.lowercased() == "fountain" {
      results.append(url.standardizedFileURL)
    }
    return results.sorted { $0.path < $1.path }
  }

  /// Expand a shell-style glob using the C `glob(3)` facility.
  private static func expandGlob(_ pattern: String) -> [String] {
    #if canImport(Darwin)
      var g = glob_t()
      defer { globfree(&g) }
      let flags = GLOB_TILDE | GLOB_BRACE | GLOB_MARK
      guard glob(pattern, flags, nil, &g) == 0 else { return [] }
      var results: [String] = []
      for i in 0..<Int(g.gl_pathc) {
        if let cString = g.gl_pathv[i] {
          results.append(String(cString: cString))
        }
      }
      return results
    #else
      return []
    #endif
  }
}

// MARK: - Errors

enum RolesError: LocalizedError {
  case noScripts(String)
  case inputNotFound(String)
  case noRoles
  case projectMdMissing(String)
  case appleIntelligenceUnavailable

  var errorDescription: String? {
    switch self {
    case .noScripts(let where_):
      return "No screenplays found to scan at: \(where_)"
    case .inputNotFound(let path):
      return "Input not found: \(path)"
    case .noRoles:
      return "No speaking roles were extracted from the provided screenplays."
    case .projectMdMissing(let path):
      return "PROJECT.md not found at \(path). Run 'proyecto init' first to create it."
    case .appleIntelligenceUnavailable:
      return """
        Apple Intelligence is not available on this device. 'proyecto roles' uses \
        the on-device Foundation Model to identify speaking roles, so you must \
        have Apple Intelligence enabled on a supported Apple silicon Mac \
        (System Settings ▸ Apple Intelligence & Siri).
        """
    }
  }
}

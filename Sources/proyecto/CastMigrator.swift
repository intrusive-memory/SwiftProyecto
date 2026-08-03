//
//  CastMigrator.swift
//  proyecto
//
//  Migrates a legacy `cast:` block out of PROJECT.md into CAST.md, via the
//  external `reparto` binary, with verify-before-strip data safety.
//

import ArgumentParser
import Foundation
import SwiftProyecto

/// Migrates a legacy `cast:` block out of a PROJECT.md into CAST.md.
///
/// Since schema v5, `cast:` is not a declared PROJECT.md key — a production's
/// cast lives in CAST.md, owned by SwiftReparto. This type is the one place
/// that moves the data, and it never models it: extraction is delegated to
/// `reparto import` (one of CAST.md's two sanctioned writers), and PROJECT.md
/// is rewritten **only after the transfer is verified**, in this exact order:
///
/// 1. `reparto import <PROJECT.md>` must exit 0 (never `--force` on the
///    auto-migration path — an existing CAST.md is a human's file, not ours
///    to overwrite).
/// 2. `reparto validate <CAST.md>` must exit 0.
/// 3. Every `character:` name from the legacy block must appear in the
///    produced CAST.md.
/// 4. Only then: PROJECT.md is backed up to `PROJECT.md.bak`, the `cast:`
///    span is removed byte-surgically, and `schemaVersion:` is stamped to
///    ``ProjectSchemaVersion/current``. No full re-emit — every other byte
///    of the file survives.
///
/// Any failure or refused precondition leaves PROJECT.md byte-for-byte
/// untouched.
struct CastMigrator {

  /// What a migration attempt did.
  enum Outcome {
    /// The legacy block was migrated; PROJECT.md was rewritten.
    case migrated(characters: Int, castMdPath: String)
    /// The document has no legacy `cast:` block — nothing to migrate.
    case nothingToDo
    /// A precondition refused the migration; PROJECT.md is untouched.
    case refused(reason: String)
  }

  enum MigrationError: LocalizedError {
    case importFailed(exitCode: Int32, stderr: String)
    case validationFailed(castMdPath: String, stderr: String)
    case characterMissing(name: String, castMdPath: String)

    var errorDescription: String? {
      switch self {
      case .importFailed(let code, let stderr):
        let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return "reparto import failed (exit \(code))\(detail.isEmpty ? "" : ": \(detail)")"
      case .validationFailed(let path, let stderr):
        let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return
          "reparto wrote \(path) but it failed validation"
          + "\(detail.isEmpty ? "" : ": \(detail)") — PROJECT.md was NOT modified"
      case .characterMissing(let name, let path):
        return
          "character \(name) from PROJECT.md's cast: block was not found in \(path) "
          + "after import — PROJECT.md was NOT modified"
      }
    }
  }

  /// Exit code `reparto import` uses for "destination already exists".
  private static let repartoExitDestinationExists: Int32 = 2

  let quiet: Bool

  /// Attempt to migrate `projectMdURL`'s legacy cast block into a sibling
  /// CAST.md.
  ///
  /// - Parameters:
  ///   - projectMdURL: The PROJECT.md to migrate.
  ///   - force: Forward `--force` to `reparto import`, overwriting an
  ///     existing CAST.md. Only the explicit `proyecto migrate --force`
  ///     path may set this; auto-migration never does.
  ///   - dryRun: Verify all preconditions and run `reparto import --dry-run`,
  ///     but write nothing anywhere.
  /// - Returns: The ``Outcome``.
  /// - Throws: ``MigrationError`` when the transfer itself fails mid-flight —
  ///   states where CAST.md may exist but PROJECT.md is guaranteed untouched.
  func migrate(projectMdURL: URL, force: Bool = false, dryRun: Bool = false) throws -> Outcome {
    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: projectMdURL)

    guard frontMatter.hasLegacyCastKey else {
      return .nothingToDo
    }

    let originalText = try String(contentsOf: projectMdURL, encoding: .utf8)

    // A season-level `cast:` is a second, indented cast location that
    // `reparto import` (which reads only the top-level key) would not
    // migrate. Refuse rather than strip a file whose cast data we could
    // not have fully transferred.
    if hasSeasonLevelCast(in: originalText) {
      return .refused(
        reason: """
          a season-level `cast:` block was detected. `reparto import` migrates only \
          the top-level cast; migrate the season cast by hand, then re-run.
          """)
    }

    let runner: RepartoRunner
    do {
      runner = try RepartoRunner.locateOrThrow()
    } catch {
      return .refused(reason: error.localizedDescription)
    }

    let projectDir = projectMdURL.deletingLastPathComponent()
    let castMdURL = projectDir.appendingPathComponent("CAST.md")

    // 1. reparto import — the sanctioned CAST.md writer.
    var importArgs = ["import", projectMdURL.path]
    if force { importArgs.append("--force") }
    if dryRun { importArgs.append("--dry-run") }
    let importResult = try runner.run(importArgs, currentDirectory: projectDir)

    if importResult.status == Self.repartoExitDestinationExists {
      return .refused(
        reason: """
          \(castMdURL.path) already exists. Overwriting it could destroy a \
          hand-curated roster, so auto-migration never does. Reconcile the two \
          by hand, or run `proyecto migrate --force` to let `reparto import` \
          overwrite it.
          """)
    }
    guard importResult.status == 0 else {
      throw MigrationError.importFailed(
        exitCode: importResult.status, stderr: importResult.stderr)
    }

    let characterNames = frontMatter.legacyCastCharacterNames

    if dryRun {
      return .migrated(characters: characterNames.count, castMdPath: castMdURL.path)
    }

    // 2. The produced CAST.md must itself parse.
    let validateResult = try runner.run(
      ["validate", castMdURL.path], currentDirectory: projectDir)
    guard validateResult.status == 0 else {
      throw MigrationError.validationFailed(
        castMdPath: castMdURL.path, stderr: validateResult.stderr)
    }

    // 3. Every character from the legacy block must have survived the
    //    transfer. A name containing a single quote may re-emit YAML-escaped
    //    (' doubled), so both spellings are accepted.
    let castText = try String(contentsOf: castMdURL, encoding: .utf8)
    for name in characterNames {
      let escaped = name.replacingOccurrences(of: "'", with: "''")
      guard castText.contains(name) || castText.contains(escaped) else {
        throw MigrationError.characterMissing(name: name, castMdPath: castMdURL.path)
      }
    }

    // 4. Verified — now, and only now, rewrite PROJECT.md (backup first).
    let backupURL = projectDir.appendingPathComponent("PROJECT.md.bak")
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: backupURL.path) {
      try fileManager.removeItem(at: backupURL)
    }
    try fileManager.copyItem(at: projectMdURL, to: backupURL)

    var newText = try parser.removingCastBlock(in: originalText)
    newText = try parser.stampingSchemaVersion(in: newText)
    try newText.write(to: projectMdURL, atomically: true, encoding: .utf8)

    return .migrated(characters: characterNames.count, castMdPath: castMdURL.path)
  }

  /// Attempt auto-migration ahead of a command that will fully rewrite
  /// PROJECT.md, and refuse to let the rewrite proceed while a legacy
  /// `cast:` block remains.
  ///
  /// Full re-emit paths (`init --update`, `generate-project`) cannot
  /// guarantee a legacy block's shape survives, so proceeding un-migrated
  /// risks exactly the data loss the verify-then-strip rule forbids. When
  /// migration cannot complete, the *command* is aborted, not the data.
  func ensureMigratedBeforeRewrite(projectMdURL: URL) throws {
    let outcome = try migrate(projectMdURL: projectMdURL)
    switch outcome {
    case .nothingToDo:
      return
    case .migrated(let characters, let castMdPath):
      if !quiet {
        print("Migrated \(characters) cast member(s) from PROJECT.md to \(castMdPath)")
      }
    case .refused(let reason):
      throw ValidationError(
        """
        PROJECT.md carries a legacy `cast:` block that could not be migrated to \
        CAST.md: \(reason)
        Rewriting PROJECT.md before the cast is safely in CAST.md risks losing it, \
        so nothing was written. Run `proyecto migrate` once the blocker is resolved.
        """)
    }
  }

  /// Detect an indented (season-level) `cast:` key inside the front matter.
  private func hasSeasonLevelCast(in text: String) -> Bool {
    var insideFrontMatter = false
    for line in text.components(separatedBy: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed == "---" {
        if insideFrontMatter { return false }
        insideFrontMatter = true
        continue
      }
      guard insideFrontMatter else { continue }
      if trimmed == "cast:" || trimmed.hasPrefix("cast: ") {
        if let first = line.first, first == " " || first == "\t" {
          return true
        }
      }
    }
    return false
  }
}

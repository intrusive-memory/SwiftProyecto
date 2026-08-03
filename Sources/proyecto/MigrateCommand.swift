//
//  MigrateCommand.swift
//  proyecto
//
//  `proyecto migrate` — move a legacy `cast:` block into CAST.md and stamp
//  the current PROJECT.md schema version.
//

import ArgumentParser
import Foundation
import SwiftProyecto

struct MigrateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "migrate",
    abstract: "Migrate a legacy PROJECT.md to the current schema",
    discussion: """
      Migrates a PROJECT.md that predates schema v\(ProjectSchemaVersion.current) \
      to the current schema. Today that means one thing: a legacy `cast:` block \
      is moved into CAST.md — via `reparto import`, the sanctioned CAST.md \
      writer — and PROJECT.md is rewritten without it, stamped \
      `schemaVersion: \(ProjectSchemaVersion.current)`.

      PROJECT.md is only rewritten AFTER the transfer is verified: the import \
      must succeed, the produced CAST.md must validate, and every character \
      from the legacy block must be present in it. Any failure leaves \
      PROJECT.md byte-for-byte untouched. The rewrite is surgical (only the \
      `cast:` span and the `schemaVersion:` line change) and a PROJECT.md.bak \
      backup is written first.

      Requires the `reparto` binary (brew install intrusive-memory/tap/reparto).

      Examples:
        proyecto migrate                  # Migrate PROJECT.md in current directory
        proyecto migrate /path/to/show    # Migrate a specific project
        proyecto migrate --dry-run        # Report what would happen, write nothing
        proyecto migrate --force          # Let reparto overwrite an existing CAST.md
      """
  )

  @Argument(help: "Project directory or PROJECT.md path (default: current directory)")
  var path: String?

  @Flag(name: .long, help: "Overwrite an existing CAST.md (forwarded to reparto import)")
  var force: Bool = false

  @Flag(name: .long, help: "Verify and report without writing anything")
  var dryRun: Bool = false

  @Flag(name: .shortAndLong, help: "Suppress non-error output")
  var quiet: Bool = false

  func run() throws {
    let inputPath = path ?? FileManager.default.currentDirectoryPath
    var projectMdURL = URL(fileURLWithPath: inputPath).standardizedFileURL

    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: projectMdURL.path, isDirectory: &isDir) else {
      throw ProyectoError.invalidPath(projectMdURL.path)
    }
    if isDir.boolValue {
      projectMdURL.appendPathComponent("PROJECT.md")
    }
    guard FileManager.default.fileExists(atPath: projectMdURL.path) else {
      throw ProyectoError.projectMdNotFound(projectMdURL.path)
    }

    let migrator = CastMigrator(quiet: quiet)
    let outcome = try migrator.migrate(
      projectMdURL: projectMdURL, force: force, dryRun: dryRun)

    switch outcome {
    case .nothingToDo:
      if !quiet {
        print("Nothing to migrate: no legacy `cast:` block in \(projectMdURL.path)")
      }
    case .migrated(let characters, let castMdPath):
      if !quiet {
        if dryRun {
          print("Would migrate \(characters) cast member(s) to \(castMdPath) (dry run)")
        } else {
          print("Migrated \(characters) cast member(s) to \(castMdPath)")
          print("Rewrote \(projectMdURL.path) (schemaVersion: \(ProjectSchemaVersion.current))")
          print("Backup at \(projectMdURL.path).bak")
        }
      }
    case .refused(let reason):
      throw ValidationError("Migration refused: \(reason)")
    }
  }
}

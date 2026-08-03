//
//  ProyectoCLIMigrateTests.swift
//  SwiftProyecto
//
//  Copyright (c) 2026 Intrusive Memory
//
//  Integration tests for `proyecto migrate` (schema v5 cast egress).
//
//  These tests drive the real `proyecto` binary AND the real external
//  `reparto` binary (SwiftReparto's CLI, the sanctioned CAST.md writer).
//  Each test is gated with XCTSkipUnless on both binaries being locatable,
//  so the suite skips cleanly on machines/CI runners without them.
//

import Foundation
import XCTest

final class ProyectoCLIMigrateTests: XCTestCase {

  var tempDirectory: URL!
  var proyectoBinary: URL!

  override func setUp() {
    super.setUp()

    tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MigrateTests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    proyectoBinary = findProyectoBinary()
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: tempDirectory)
    super.tearDown()
  }

  // MARK: - Binary Location

  /// Find the proyecto binary in the build products directory.
  ///
  /// Same pattern as ProyectoCLIValidateTests.findProyectoBinary().
  private func findProyectoBinary() -> URL {
    // Preferred: the `proyecto` executable built by the same scheme lives in the
    // SAME build-products directory as this test bundle. Resolving it relative to
    // the test bundle guarantees we exercise THIS build's binary and never a
    // stale one from another checkout/worktree (a `find ... | head -1` over all
    // DerivedData dirs is nondeterministic when multiple checkouts exist).
    let testBundleDir = Bundle(for: type(of: self)).bundleURL.deletingLastPathComponent()
    let colocated = testBundleDir.appendingPathComponent("proyecto")
    if FileManager.default.fileExists(atPath: colocated.path) {
      return colocated
    }

    // Check common build locations
    let possiblePaths = [
      // Local bin directory (after make install)
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("bin/proyecto"),
      // .build directory (swift build)
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".build/arm64-apple-macosx/debug/proyecto"),
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".build/x86_64-apple-macosx/debug/proyecto"),
    ]

    // First try to find in DerivedData using shell expansion
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [
      "-c",
      "find ~/Library/Developer/Xcode/DerivedData/SwiftProyecto-* -name proyecto -type f 2>/dev/null | head -1",
    ]

    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    process.waitUntilExit()

    if let data = try? pipe.fileHandleForReading.readToEnd(),
      let path = String(data: data, encoding: .utf8)?.trimmingCharacters(
        in: .whitespacesAndNewlines),
      !path.isEmpty
    {
      return URL(fileURLWithPath: path)
    }

    // Fall back to other locations
    for path in possiblePaths {
      if FileManager.default.fileExists(atPath: path.path) {
        return path
      }
    }

    // If not found, return a placeholder; tests skip via XCTSkipUnless.
    return URL(fileURLWithPath: "/tmp/proyecto-not-found")
  }

  /// Locate the external `reparto` binary: PATH first, then the standard
  /// Homebrew and local install locations (mirrors RepartoRunner.locate).
  private func findRepartoBinary() -> URL? {
    var candidates: [String] = []
    if let path = ProcessInfo.processInfo.environment["PATH"] {
      candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/reparto" })
    }
    candidates.append("/opt/homebrew/bin/reparto")
    candidates.append("/usr/local/bin/reparto")

    let fileManager = FileManager.default
    for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
      return URL(fileURLWithPath: candidate)
    }
    return nil
  }

  /// Skip unless both the proyecto binary and reparto are available.
  private func skipUnlessBinariesAvailable() throws {
    try XCTSkipUnless(
      FileManager.default.fileExists(atPath: proyectoBinary.path),
      "proyecto binary not found; run 'make build' first")
    try XCTSkipUnless(
      findRepartoBinary() != nil,
      "reparto binary not found on PATH, /opt/homebrew/bin, or /usr/local/bin")
  }

  // MARK: - Helpers

  /// Execute `proyecto migrate` with the given arguments.
  private func runMigrate(arguments: [String] = []) -> (
    exitCode: Int32, stdout: String, stderr: String
  ) {
    let process = Process()
    process.executableURL = proyectoBinary
    process.arguments = ["migrate"] + arguments

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try? process.run()
    process.waitUntilExit()

    let stdoutData = try? stdoutPipe.fileHandleForReading.readToEnd()
    let stderrData = try? stderrPipe.fileHandleForReading.readToEnd()

    let stdout = stdoutData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    let stderr = stderrData.flatMap { String(data: $0, encoding: .utf8) } ?? ""

    return (process.terminationStatus, stdout, stderr)
  }

  private var projectMdURL: URL { tempDirectory.appendingPathComponent("PROJECT.md") }
  private var castMdURL: URL { tempDirectory.appendingPathComponent("CAST.md") }
  private var backupURL: URL { tempDirectory.appendingPathComponent("PROJECT.md.bak") }

  /// A legacy (pre-v5) PROJECT.md carrying a two-member `cast:` block.
  private func writeCastBearingProjectMd() throws {
    let content = """
      ---
      type: project
      title: Migration Test Project
      author: Test Author
      created: 2025-01-01T00:00:00Z
      cast:
        - character: NARRATOR
          actor: Tom Stovall
          voicePrompt: Deep, warm baritone
        - character: LAO TZU
          actor: Jason Manino
      episodesDir: episodes
      ---

      # Migration Test Project

      Body content that must survive migration untouched.
      """
    try content.write(to: projectMdURL, atomically: true, encoding: .utf8)
  }

  // MARK: - Tests

  func testMigrate_CastBearingProject_WritesCastMdAndStripsProjectMd() throws {
    try skipUnlessBinariesAvailable()
    try writeCastBearingProjectMd()

    let result = runMigrate(arguments: [tempDirectory.path])

    XCTAssertEqual(
      result.exitCode, 0,
      "Expected exit 0; stdout: \(result.stdout) stderr: \(result.stderr)")

    // CAST.md was created by reparto and contains every character.
    XCTAssertTrue(FileManager.default.fileExists(atPath: castMdURL.path), "CAST.md not created")
    let castText = try String(contentsOf: castMdURL, encoding: .utf8)
    XCTAssertTrue(castText.contains("NARRATOR"))
    XCTAssertTrue(castText.contains("LAO TZU"))

    // PROJECT.md was stripped and stamped v5.
    let projectText = try String(contentsOf: projectMdURL, encoding: .utf8)
    XCTAssertFalse(projectText.contains("cast:"), "cast: block should be gone from PROJECT.md")
    XCTAssertFalse(projectText.contains("NARRATOR"))
    XCTAssertTrue(projectText.contains("schemaVersion: 5"), "PROJECT.md should be stamped v5")
    // The surgical rewrite preserves everything else.
    XCTAssertTrue(projectText.contains("episodesDir: episodes"))
    XCTAssertTrue(projectText.contains("Body content that must survive migration untouched."))

    // A backup of the original was written.
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: backupURL.path), "PROJECT.md.bak not written")
    let backupText = try String(contentsOf: backupURL, encoding: .utf8)
    XCTAssertTrue(backupText.contains("cast:"), "Backup should hold the pre-migration content")
  }

  func testMigrate_SecondRun_IsIdempotent() throws {
    try skipUnlessBinariesAvailable()
    try writeCastBearingProjectMd()

    let first = runMigrate(arguments: [tempDirectory.path])
    XCTAssertEqual(first.exitCode, 0, "First run should succeed: \(first.stderr)")

    let migratedProject = try String(contentsOf: projectMdURL, encoding: .utf8)
    let migratedCast = try String(contentsOf: castMdURL, encoding: .utf8)

    let second = runMigrate(arguments: [tempDirectory.path])
    XCTAssertEqual(second.exitCode, 0, "Second run should succeed: \(second.stderr)")
    XCTAssertTrue(
      second.stdout.contains("Nothing to migrate"),
      "Second run should report nothing to migrate; stdout: \(second.stdout)")

    // Nothing changed on the second pass.
    XCTAssertEqual(try String(contentsOf: projectMdURL, encoding: .utf8), migratedProject)
    XCTAssertEqual(try String(contentsOf: castMdURL, encoding: .utf8), migratedCast)
  }

  func testMigrate_ExistingCastMd_RefusesAndLeavesProjectMdUntouched() throws {
    try skipUnlessBinariesAvailable()
    try writeCastBearingProjectMd()

    // A pre-existing CAST.md is a human's file; auto-migration must refuse.
    let existingCast = """
      ---
      type: cast
      cast:
        - character: HAND CURATED
      ---
      """
    try existingCast.write(to: castMdURL, atomically: true, encoding: .utf8)

    let originalProject = try String(contentsOf: projectMdURL, encoding: .utf8)

    let result = runMigrate(arguments: [tempDirectory.path])

    XCTAssertNotEqual(result.exitCode, 0, "Expected non-zero exit when CAST.md already exists")
    XCTAssertTrue(
      result.stderr.contains("already exists") || result.stdout.contains("already exists"),
      "Expected refusal message about the existing CAST.md; stderr: \(result.stderr)")

    // Byte-for-byte untouched, both files.
    XCTAssertEqual(try String(contentsOf: projectMdURL, encoding: .utf8), originalProject)
    XCTAssertEqual(try String(contentsOf: castMdURL, encoding: .utf8), existingCast)
    XCTAssertFalse(FileManager.default.fileExists(atPath: backupURL.path))
  }

  func testMigrate_DryRun_WritesNothing() throws {
    try skipUnlessBinariesAvailable()
    try writeCastBearingProjectMd()

    let originalProject = try String(contentsOf: projectMdURL, encoding: .utf8)

    let result = runMigrate(arguments: [tempDirectory.path, "--dry-run"])

    XCTAssertEqual(
      result.exitCode, 0,
      "Expected exit 0 for dry run; stderr: \(result.stderr)")
    XCTAssertTrue(
      result.stdout.contains("Would migrate 2 cast member(s)"),
      "Expected dry-run report; stdout: \(result.stdout)")

    // Nothing was written anywhere.
    XCTAssertFalse(FileManager.default.fileExists(atPath: castMdURL.path), "CAST.md was written")
    XCTAssertFalse(FileManager.default.fileExists(atPath: backupURL.path), ".bak was written")
    XCTAssertEqual(try String(contentsOf: projectMdURL, encoding: .utf8), originalProject)
  }

  func testMigrate_NoCastBlock_NothingToDo() throws {
    try skipUnlessBinariesAvailable()
    let content = """
      ---
      type: project
      title: Already Clean
      author: Test Author
      created: 2025-01-01T00:00:00Z
      ---
      """
    try content.write(to: projectMdURL, atomically: true, encoding: .utf8)

    let result = runMigrate(arguments: [tempDirectory.path])

    XCTAssertEqual(result.exitCode, 0)
    XCTAssertTrue(result.stdout.contains("Nothing to migrate"))
    XCTAssertFalse(FileManager.default.fileExists(atPath: castMdURL.path))
    XCTAssertEqual(try String(contentsOf: projectMdURL, encoding: .utf8), content)
  }
}

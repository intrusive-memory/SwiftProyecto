//
//  RepartoRunner.swift
//  proyecto
//
//  Locates and runs the external `reparto` binary (SwiftReparto's CLI).
//

import Foundation

/// Locates and runs the external `reparto` binary.
///
/// SwiftProyecto deliberately declares no package dependency on SwiftReparto —
/// cast is SwiftReparto's domain, and the recorded consumer contract keeps this
/// package out of it. The `reparto` *binary* is therefore a runtime dependency
/// of the migration path only: when it is absent, migration is refused and the
/// PROJECT.md is left byte-for-byte untouched. It is never treated as
/// "proceed without cast extraction."
struct RepartoRunner {

  /// A completed `reparto` invocation.
  struct Result {
    let status: Int32
    let stdout: String
    let stderr: String
  }

  enum RunnerError: LocalizedError {
    /// No `reparto` binary could be found on PATH or in the Homebrew/standard
    /// install locations.
    case binaryNotFound

    var errorDescription: String? {
      switch self {
      case .binaryNotFound:
        return """
          The `reparto` binary is required to migrate a legacy `cast:` block into \
          CAST.md, but it was not found. Install it with:
            brew install intrusive-memory/tap/reparto
          """
      }
    }
  }

  /// The resolved binary location.
  let binaryURL: URL

  /// Locate `reparto` on PATH, falling back to the standard Homebrew and
  /// local install locations.
  ///
  /// - Returns: The binary's URL, or nil when it is not installed.
  static func locate(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> URL? {
    var candidates: [String] = []
    if let path = environment["PATH"] {
      candidates.append(
        contentsOf: path.split(separator: ":").map { "\($0)/reparto" })
    }
    // PATH may be minimal under launchd/CI; always try the standard installs.
    candidates.append("/opt/homebrew/bin/reparto")
    candidates.append("/usr/local/bin/reparto")

    let fileManager = FileManager.default
    for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
      return URL(fileURLWithPath: candidate)
    }
    return nil
  }

  /// Locate `reparto` or throw ``RunnerError/binaryNotFound``.
  static func locateOrThrow() throws -> RepartoRunner {
    guard let url = locate() else {
      throw RunnerError.binaryNotFound
    }
    return RepartoRunner(binaryURL: url)
  }

  /// Run `reparto` with the given arguments and wait for completion.
  ///
  /// Never throws on a non-zero exit — callers decide what each exit code
  /// means (`reparto` documents 0/1/2/3/4 in `reparto --help`).
  func run(
    _ arguments: [String], currentDirectory: URL? = nil
  ) throws -> Result {
    let process = Process()
    process.executableURL = binaryURL
    process.arguments = arguments
    if let currentDirectory {
      process.currentDirectoryURL = currentDirectory
    }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    // Drain before waiting so a large stdout cannot deadlock the pipe.
    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    return Result(
      status: process.terminationStatus,
      stdout: String(data: stdoutData, encoding: .utf8) ?? "",
      stderr: String(data: stderrData, encoding: .utf8) ?? ""
    )
  }
}

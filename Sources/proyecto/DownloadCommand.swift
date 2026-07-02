//
//  DownloadCommand.swift
//  proyecto CLI
//
//  Copyright (c) 2025 Intrusive Memory
//

import ArgumentParser
import Foundation
import SwiftAcervo
import SwiftProyecto

/// Download the canonical language model from the intrusive-memory CDN.
///
/// Ensures the model that Proyecto depends on
/// (`mlx-community/Qwen2.5-7B-Instruct-4bit`) is present in the shared models
/// cache, fetching it from the CDN via SwiftAcervo when it is not already
/// cached locally. If the model is already present and verified, the command
/// returns immediately without downloading.
///
/// ## Examples
///
/// ```
/// proyecto download            # Download the model if not already cached
/// proyecto download --force    # Re-verify/re-fetch even if cached
/// proyecto download --quiet    # Suppress progress output
/// ```
struct DownloadCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "download",
    abstract: "Download the canonical language model from the CDN if not cached",
    discussion: """
      Ensures the language model Proyecto depends on is available in the shared
      models cache, downloading it from the intrusive-memory CDN via SwiftAcervo
      when it is not already cached locally.

      The model is verified by SHA-256 after download. If it is already present
      and valid, the command exits immediately without re-downloading (unless
      --force is given).

      Examples:
        proyecto download            # Download the model if missing
        proyecto download --force    # Re-fetch/verify even if already cached
        proyecto download --quiet    # Suppress progress output
      """
  )

  @Flag(name: .long, help: "Re-fetch and verify the model even if it is already cached")
  var force: Bool = false

  @Flag(name: .shortAndLong, help: "Suppress progress output")
  var quiet: Bool = false

  func run() async throws {
    let manager = ModelManager()
    let descriptor = await manager.modelDescriptor() ?? LanguageModel
    let showProgress = !quiet

    // Fast path: already cached and not forcing a re-fetch.
    if !force, await manager.isModelReady() {
      if showProgress {
        print("✓ \(descriptor.displayName) already cached (\(descriptor.repoId))")
      }
      return
    }

    if showProgress {
      print("Downloading \(descriptor.displayName) from CDN (\(descriptor.repoId))...")
    }

    // ensureModelReady is idempotent: it no-ops when the model is already
    // present and verified, so --force simply routes through the same call to
    // re-run verification and fill any missing files.
    try await manager.ensureModelReady { progress in
      guard showProgress else { return }
      let pct = Int((progress.overallProgress * 100).rounded())
      let file = progress.fileName
      // Carriage-return in place so the progress line updates rather than scrolls.
      FileHandle.standardError.write(
        Data("\r  [\(pct)%] \(file)\u{1B}[K".utf8)
      )
    }

    if showProgress {
      // Terminate the in-place progress line.
      FileHandle.standardError.write(Data("\n".utf8))
      print("✓ \(descriptor.displayName) ready")
    }
  }
}

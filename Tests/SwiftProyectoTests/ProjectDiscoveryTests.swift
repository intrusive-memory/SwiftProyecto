//
//  ProjectDiscoveryTests.swift
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
import Testing

@testable import SwiftProyecto

// MARK: - Test Helpers

/// Creates a temporary directory structure for testing ProjectDiscovery.
private func makeTestProject(
  withEpisodesFolderName episodesFolderName: String? = nil,
  projectMdInParent: Bool = true,
  projectMdInCurrent: Bool = false,
  cast: [CastMember]? = nil
) throws -> (projectDir: URL, cleanUp: () -> Void) {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("ProjectDiscoveryTests-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

  let projectMdContent = makeProjectMdContent(cast: cast)

  if projectMdInParent {
    let projectMdURL = tempDir.appendingPathComponent("PROJECT.md")
    try projectMdContent.write(to: projectMdURL, atomically: true, encoding: .utf8)
  }

  if let folderName = episodesFolderName {
    let episodesDir = tempDir.appendingPathComponent(folderName)
    try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)

    if projectMdInCurrent {
      let innerProjectMd = episodesDir.appendingPathComponent("PROJECT.md")
      try projectMdContent.write(to: innerProjectMd, atomically: true, encoding: .utf8)
    }

    // Create a dummy file in the episodes folder
    let dummyFile = episodesDir.appendingPathComponent("script.fountain")
    try "INT. OFFICE - DAY".write(to: dummyFile, atomically: true, encoding: .utf8)
  }

  let cleanUp: () -> Void = {
    _ = try? FileManager.default.removeItem(at: tempDir)
  }

  return (tempDir, cleanUp)
}

private func makeProjectMdContent(cast: [CastMember]? = nil) -> String {
  var content = "---\n"
  content += "type: project\n"
  content += "title: Test Project\n"
  content += "author: Test Author\n"
  content += "created: 2025-11-17T10:30:00Z\n"

  if let cast, !cast.isEmpty {
    content += "cast:\n"
    for member in cast {
      content += "  - character: \(member.character)\n"
      if let actor = member.actor {
        content += "    actor: \(actor)\n"
      }
      if let gender = member.gender {
        content += "    gender: \(gender.rawValue)\n"
      }
      if let desc = member.voiceDescription {
        content += "    voiceDescription: \"\(desc)\"\n"
      }
      if !member.voices.isEmpty {
        content += "    voices:\n"
        for (provider, voiceId) in member.voices.sorted(by: { $0.key < $1.key }) {
          content += "      \(provider): \(voiceId)\n"
        }
      }
    }
  }

  content += "---\n\n# Test Project Notes\n"
  return content
}

// MARK: - Episodes Folder Tests

@Suite("ProjectDiscovery - Episodes Folder Detection")
struct ProjectDiscoveryEpisodesFolderTests {

  @Test("Find PROJECT.md from episodes folder (parent location)")
  func findFromEpisodesFolder() throws {
    let (projectDir, cleanUp) = try makeTestProject(withEpisodesFolderName: "episodes")
    defer { cleanUp() }

    let discovery = ProjectDiscovery()
    let scriptURL =
      projectDir
      .appendingPathComponent("episodes")
      .appendingPathComponent("script.fountain")

    let result = discovery.findProjectMd(from: scriptURL)
    #expect(result != nil)
    #expect(result?.lastPathComponent == "PROJECT.md")
    #expect(result?.deletingLastPathComponent().lastPathComponent == projectDir.lastPathComponent)
  }

  @Test("Episodes folder case-insensitive: EPISODES")
  func findFromUppercaseEpisodesFolder() throws {
    let (projectDir, cleanUp) = try makeTestProject(withEpisodesFolderName: "EPISODES")
    defer { cleanUp() }

    let discovery = ProjectDiscovery()
    let scriptURL =
      projectDir
      .appendingPathComponent("EPISODES")
      .appendingPathComponent("script.fountain")

    let result = discovery.findProjectMd(from: scriptURL)
    #expect(result != nil)
    #expect(result?.lastPathComponent == "PROJECT.md")
  }

  @Test("Episodes folder case-insensitive: Episodes")
  func findFromMixedCaseEpisodesFolder() throws {
    let (projectDir, cleanUp) = try makeTestProject(withEpisodesFolderName: "Episodes")
    defer { cleanUp() }

    let discovery = ProjectDiscovery()
    let scriptURL =
      projectDir
      .appendingPathComponent("Episodes")
      .appendingPathComponent("script.fountain")

    let result = discovery.findProjectMd(from: scriptURL)
    #expect(result != nil)
    #expect(result?.lastPathComponent == "PROJECT.md")
  }

  @Test("Prefers episodes parent over current directory when both have PROJECT.md")
  func prefersEpisodesParent() throws {
    let (projectDir, cleanUp) = try makeTestProject(
      withEpisodesFolderName: "episodes",
      projectMdInParent: true,
      projectMdInCurrent: true
    )
    defer { cleanUp() }

    let discovery = ProjectDiscovery()
    let scriptURL =
      projectDir
      .appendingPathComponent("episodes")
      .appendingPathComponent("script.fountain")

    let result = discovery.findProjectMd(from: scriptURL)
    #expect(result != nil)
    // Should find the parent directory's PROJECT.md, not the episodes one
    #expect(result?.deletingLastPathComponent().lastPathComponent == projectDir.lastPathComponent)
  }
}

// MARK: - Directory Tests

@Suite("ProjectDiscovery - Directory Navigation")
struct ProjectDiscoveryDirectoryTests {

  @Test("Find PROJECT.md in current directory")
  func findInCurrentDirectory() throws {
    let (projectDir, cleanUp) = try makeTestProject()
    defer { cleanUp() }

    let discovery = ProjectDiscovery()

    // Create a file in the project directory
    let fileURL = projectDir.appendingPathComponent("notes.txt")
    try "notes".write(to: fileURL, atomically: true, encoding: .utf8)

    let result = discovery.findProjectMd(from: fileURL)
    #expect(result != nil)
    #expect(result?.lastPathComponent == "PROJECT.md")
  }

  @Test("Find PROJECT.md in parent directory")
  func findInParentDirectory() throws {
    let (projectDir, cleanUp) = try makeTestProject(withEpisodesFolderName: "scripts")
    defer { cleanUp() }

    let discovery = ProjectDiscovery()
    let scriptURL =
      projectDir
      .appendingPathComponent("scripts")
      .appendingPathComponent("script.fountain")

    let result = discovery.findProjectMd(from: scriptURL)
    #expect(result != nil)
    #expect(result?.lastPathComponent == "PROJECT.md")
  }

  @Test("Return nil when PROJECT.md not found")
  func returnNilWhenNotFound() throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("ProjectDiscoveryTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let discovery = ProjectDiscovery()
    let fileURL = tempDir.appendingPathComponent("notes.txt")
    try "notes".write(to: fileURL, atomically: true, encoding: .utf8)

    let result = discovery.findProjectMd(from: fileURL)
    #expect(result == nil)
  }

  @Test("Starting from directory instead of file")
  func startFromDirectory() throws {
    let (projectDir, cleanUp) = try makeTestProject()
    defer { cleanUp() }

    let discovery = ProjectDiscovery()
    let result = discovery.findProjectMd(from: projectDir)
    #expect(result != nil)
    #expect(result?.lastPathComponent == "PROJECT.md")
  }
}

// MARK: - Cast Reading Tests

@Suite("ProjectDiscovery - Cast Reading")
struct ProjectDiscoveryCastReadingTests {

  @Test("Read cast from PROJECT.md returns all members")
  func readAllCast() throws {
    let cast = [
      CastMember(
        character: "NARRATOR", actor: "Tom", voices: ["apple": "voice-1", "elevenlabs": "voice-2"]),
      CastMember(character: "LAO TZU", actor: "Jason", voices: ["apple": "voice-3"]),
    ]
    let (projectDir, cleanUp) = try makeTestProject(cast: cast)
    defer { cleanUp() }

    let discovery = ProjectDiscovery()
    let projectMdURL = projectDir.appendingPathComponent("PROJECT.md")
    let result = try discovery.readCast(from: projectMdURL)

    #expect(result.count == 2)
    #expect(result[0].character == "NARRATOR")
    #expect(result[1].character == "LAO TZU")
  }

  @Test("Read cast filtered by provider")
  func readCastFilteredByProvider() throws {
    let cast = [
      CastMember(character: "NARRATOR", voices: ["apple": "voice-1", "elevenlabs": "voice-2"]),
      CastMember(character: "LAO TZU", voices: ["elevenlabs": "voice-3"]),
    ]
    let (projectDir, cleanUp) = try makeTestProject(cast: cast)
    defer { cleanUp() }

    let discovery = ProjectDiscovery()
    let projectMdURL = projectDir.appendingPathComponent("PROJECT.md")

    let appleOnly = try discovery.readCast(from: projectMdURL, filterByProvider: "apple")
    #expect(appleOnly.count == 1)
    #expect(appleOnly[0].character == "NARRATOR")

    let elevenOnly = try discovery.readCast(from: projectMdURL, filterByProvider: "elevenlabs")
    #expect(elevenOnly.count == 2)
  }

  @Test("Read cast returns empty array when no cast")
  func readCastReturnsEmptyWhenNoCast() throws {
    let (projectDir, cleanUp) = try makeTestProject(cast: nil)
    defer { cleanUp() }

    let discovery = ProjectDiscovery()
    let projectMdURL = projectDir.appendingPathComponent("PROJECT.md")
    let result = try discovery.readCast(from: projectMdURL)
    #expect(result.isEmpty)
  }

  @Test("Read cast handles PROJECT.md with no cast key in YAML")
  func readCastHandlesNoCastKey() throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("ProjectDiscoveryTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let content = """
      ---
      type: project
      title: Minimal Project
      author: Test Author
      created: 2025-11-17T10:30:00Z
      ---

      # Notes
      """
    let projectMdURL = tempDir.appendingPathComponent("PROJECT.md")
    try content.write(to: projectMdURL, atomically: true, encoding: .utf8)

    let discovery = ProjectDiscovery()
    let result = try discovery.readCast(from: projectMdURL)
    #expect(result.isEmpty)
  }
}

// MARK: - Cast Merging Tests

@Suite("ProjectFrontMatter - Cast Merging")
struct ProjectFrontMatterCastMergingTests {

  @Test("Merge cast preserves existing provider voices")
  func mergePreservesOtherProviderVoices() {
    let existingCast = [
      CastMember(
        character: "NARRATOR", actor: "Tom", gender: .male,
        voiceDescription: "Deep baritone",
        voices: ["elevenlabs": "el-voice-1"])
    ]
    let frontMatter = ProjectFrontMatter(
      title: "Test", author: "Author", cast: existingCast
    )

    let newCast = [
      CastMember(character: "NARRATOR", voices: ["apple": "apple-voice-1"])
    ]

    let merged = frontMatter.mergingCast(newCast, forProvider: "apple")

    #expect(merged.cast?.count == 1)
    let narrator = merged.cast![0]
    // ElevenLabs voice must be preserved
    #expect(narrator.voices["elevenlabs"] == "el-voice-1")
    // Apple voice must be added
    #expect(narrator.voices["apple"] == "apple-voice-1")
  }

  @Test("Merge cast updates voices for specified provider")
  func mergeUpdatesSpecifiedProvider() {
    let existingCast = [
      CastMember(character: "NARRATOR", voices: ["apple": "old-apple-voice"])
    ]
    let frontMatter = ProjectFrontMatter(
      title: "Test", author: "Author", cast: existingCast
    )

    let newCast = [
      CastMember(character: "NARRATOR", voices: ["apple": "new-apple-voice"])
    ]

    let merged = frontMatter.mergingCast(newCast, forProvider: "apple")
    #expect(merged.cast?[0].voices["apple"] == "new-apple-voice")
  }

  @Test("Merge cast adds new characters not in existing cast")
  func mergeAddsNewCharacters() {
    let existingCast = [
      CastMember(character: "NARRATOR", voices: ["apple": "voice-1"])
    ]
    let frontMatter = ProjectFrontMatter(
      title: "Test", author: "Author", cast: existingCast
    )

    let newCast = [
      CastMember(character: "NARRATOR", voices: ["apple": "voice-1"]),
      CastMember(character: "LAO TZU", actor: "Jason", voices: ["apple": "voice-2"]),
    ]

    let merged = frontMatter.mergingCast(newCast, forProvider: "apple")
    #expect(merged.cast?.count == 2)
    #expect(merged.cast?[0].character == "NARRATOR")
    #expect(merged.cast?[1].character == "LAO TZU")
    #expect(merged.cast?[1].voices["apple"] == "voice-2")
  }

  @Test("Merge cast preserves character metadata from existing cast")
  func mergePreservesExistingMetadata() {
    let existingCast = [
      CastMember(
        character: "NARRATOR", actor: "Tom Stovall", gender: .male,
        voiceDescription: "Deep, warm baritone",
        voices: ["elevenlabs": "el-voice-1"])
    ]
    let frontMatter = ProjectFrontMatter(
      title: "Test", author: "Author", cast: existingCast
    )

    let newCast = [
      CastMember(character: "NARRATOR", voices: ["apple": "apple-voice-1"])
    ]

    let merged = frontMatter.mergingCast(newCast, forProvider: "apple")
    let narrator = merged.cast![0]

    // Metadata must be preserved from existing cast
    #expect(narrator.actor == "Tom Stovall")
    #expect(narrator.gender == .male)
    #expect(narrator.voiceDescription == "Deep, warm baritone")
  }

  @Test("Merge cast with empty existing cast")
  func mergeWithEmptyExistingCast() {
    let frontMatter = ProjectFrontMatter(
      title: "Test", author: "Author", cast: nil
    )

    let newCast = [
      CastMember(character: "NARRATOR", voices: ["apple": "voice-1"])
    ]

    let merged = frontMatter.mergingCast(newCast, forProvider: "apple")
    #expect(merged.cast?.count == 1)
    #expect(merged.cast?[0].character == "NARRATOR")
  }

  @Test("withCast replaces entire cast")
  func withCastReplaces() {
    let existingCast = [
      CastMember(character: "NARRATOR", voices: ["apple": "voice-1"]),
      CastMember(character: "LAO TZU", voices: ["apple": "voice-2"]),
    ]
    let frontMatter = ProjectFrontMatter(
      title: "Test", author: "Author", cast: existingCast
    )

    let newCast = [CastMember(character: "COMMENTATOR", voices: ["apple": "voice-3"])]
    let updated = frontMatter.withCast(newCast)

    #expect(updated.cast?.count == 1)
    #expect(updated.cast?[0].character == "COMMENTATOR")
    // Other fields preserved
    #expect(updated.title == "Test")
    #expect(updated.author == "Author")
  }

  @Test("withCast nil removes cast")
  func withCastNilRemoves() {
    let frontMatter = ProjectFrontMatter(
      title: "Test", author: "Author",
      cast: [CastMember(character: "NARRATOR")]
    )

    let updated = frontMatter.withCast(nil)
    #expect(updated.cast == nil)
  }
}

// MARK: - Write Tests

@Suite("ProjectMarkdownParser - Write")
struct ProjectMarkdownParserWriteTests {

  @Test("Write creates file on disk with correct content")
  func writeCreatesFile() throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("ProjectDiscoveryTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let parser = ProjectMarkdownParser()
    let frontMatter = ProjectFrontMatter(
      title: "Write Test", author: "Test Author",
      cast: [CastMember(character: "NARRATOR", voices: ["apple": "voice-1"])]
    )

    let url = tempDir.appendingPathComponent("PROJECT.md")
    try parser.write(frontMatter: frontMatter, body: "# Notes", to: url)

    #expect(FileManager.default.fileExists(atPath: url.path))

    // Verify round-trip: read back
    let (readBack, body) = try parser.parse(fileURL: url)
    #expect(readBack.title == "Write Test")
    #expect(readBack.author == "Test Author")
    #expect(readBack.cast?.count == 1)
    #expect(readBack.cast?[0].character == "NARRATOR")
    #expect(body.contains("# Notes"))
  }
}

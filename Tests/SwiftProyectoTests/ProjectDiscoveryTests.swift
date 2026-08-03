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
  projectMdInCurrent: Bool = false
) throws -> (projectDir: URL, cleanUp: () -> Void) {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("ProjectDiscoveryTests-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

  let projectMdContent = makeProjectMdContent()

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

private func makeProjectMdContent() -> String {
  var content = "---\n"
  content += "type: project\n"
  content += "title: Test Project\n"
  content += "author: Test Author\n"
  content += "created: 2025-11-17T10:30:00Z\n"
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
      title: "Write Test", author: "Test Author"
    )

    let url = tempDir.appendingPathComponent("PROJECT.md")
    try parser.write(frontMatter: frontMatter, body: "# Notes", to: url)

    #expect(FileManager.default.fileExists(atPath: url.path))

    // Verify round-trip: read back
    let (readBack, body) = try parser.parse(fileURL: url)
    #expect(readBack.title == "Write Test")
    #expect(readBack.author == "Test Author")
    #expect(body.contains("# Notes"))
  }
}

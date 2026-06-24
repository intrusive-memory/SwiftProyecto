//
//  VariantIndexerTests.swift
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

/// Create a master PROJECT.md file with variants array
private func makeMasterProjectContent(
  title: String = "Master Series",
  author: String = "Author Name",
  variants: [VariantReference] = []
) -> String {
  var content = "---\n"
  content += "type: overview\n"
  content += "title: \(title)\n"
  content += "author: \(author)\n"
  content += "created: 2025-11-17T10:30:00Z\n"

  // Extract unique seasons from variants for the master's seasons array
  let uniqueSeasons = Set(variants.map { $0.season }).sorted()
  if !uniqueSeasons.isEmpty {
    content += "seasons:\n"
    for season in uniqueSeasons {
      content += "  - number: \(season)\n"
      content += "    episodes: 10\n"
    }
  }

  if !variants.isEmpty {
    content += "variants:\n"
    for variant in variants {
      content += "  - season: \(variant.season)\n"
      content += "    language: \(variant.language)\n"
      content += "    path: \(variant.path)\n"
      if let status = variant.status {
        content += "    status: \(status.rawValue)\n"
      }
      if let introFile = variant.introFile {
        content += "    introFile: \(introFile)\n"
      }
      if let outroFile = variant.outroFile {
        content += "    outroFile: \(outroFile)\n"
      }
    }
  }

  content += "---\n\n# Master Project Notes\n"
  return content
}

/// Create a variant PROJECT.md file
private func makeVariantProjectContent(
  title: String = "Variant Project",
  author: String = "Author Name",
  language: String? = nil,
  season: Int? = nil,
  audioDir: String? = nil
) -> String {
  var content = "---\n"
  content += "type: project\n"
  content += "title: \(title)\n"
  content += "author: \(author)\n"
  content += "created: 2025-11-17T10:30:00Z\n"

  if let language = language {
    content += "languages:\n"
    content += "  - code: \(language)\n"
    content += "    name: \(language.uppercased())\n"
  }

  if let season = season {
    content += "seasons:\n"
    content += "  - number: \(season)\n"
    content += "    episodes: 10\n"
  }

  if let audioDir = audioDir {
    content += "audioDir: \(audioDir)\n"
  }

  content += "---\n\n# Variant Project Notes\n"
  return content
}

/// Create a test master project with variants
private func makeTestMasterProject(
  variants: [(season: Int, language: String, audioDir: String?)] = []
) throws -> (masterDir: URL, cleanUp: () -> Void) {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("VariantIndexerTests-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

  // Create variant references
  var variantRefs: [VariantReference] = []
  for (season, language, _) in variants {
    let path = "projects/s\(String(format: "%02d", season))_\(language)/PROJECT.md"
    let ref = VariantReference(
      season: season,
      language: language,
      path: path
    )
    variantRefs.append(ref)
  }

  // Create master PROJECT.md
  let masterContent = makeMasterProjectContent(variants: variantRefs)
  let masterPath = tempDir.appendingPathComponent("PROJECT.md")
  try masterContent.write(to: masterPath, atomically: true, encoding: .utf8)

  // Create variant PROJECT.md files
  for (season, language, audioDir) in variants {
    let variantDir =
      tempDir
      .appendingPathComponent("projects")
      .appendingPathComponent("s\(String(format: "%02d", season))_\(language)")

    try FileManager.default.createDirectory(at: variantDir, withIntermediateDirectories: true)

    let variantContent = makeVariantProjectContent(
      title: "Series - \(language.uppercased()) S\(season)",
      language: language,
      season: season,
      audioDir: audioDir
    )

    let variantPath = variantDir.appendingPathComponent("PROJECT.md")
    try variantContent.write(to: variantPath, atomically: true, encoding: .utf8)
  }

  let cleanUp: () -> Void = {
    _ = try? FileManager.default.removeItem(at: tempDir)
  }

  return (tempDir, cleanUp)
}

// MARK: - VariantIndexer Tests

@Suite("VariantIndexer - Basic Operations")
struct VariantIndexerBasicTests {

  @Test("Create indexer with master")
  func createIndexer() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject()
    defer { cleanUp() }

    let parser = ProjectMarkdownParser()
    let masterPath = masterDir.appendingPathComponent("PROJECT.md")
    let (master, _) = try parser.parse(fileURL: masterPath)

    let indexer = VariantIndexer(master: master, masterDirectory: masterDir)
    #expect(indexer.master.title == "Master Series")
    #expect(indexer.languages == [])
  }

  @Test("Load single variant")
  func loadSingleVariant() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject(
      variants: [(season: 1, language: "es", audioDir: "audio_es")]
    )
    defer { cleanUp() }

    let parser = ProjectMarkdownParser()
    let masterPath = masterDir.appendingPathComponent("PROJECT.md")
    let (master, _) = try parser.parse(fileURL: masterPath)

    let indexer = VariantIndexer(master: master, masterDirectory: masterDir)
    try indexer.loadVariants()

    #expect(indexer.languages == ["es"])
    #expect(indexer.seasons(for: "es") == [1])

    let variant = indexer.variant(for: "es", season: 1)
    #expect(variant != nil)
    #expect(variant?.languages?.count == 1)
    #expect(variant?.languages?.first?.code == "es")
  }

  @Test("Load two variants (2 languages, 1 season)")
  func loadTwoVariants() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject(
      variants: [
        (season: 1, language: "en", audioDir: "audio_en"),
        (season: 1, language: "es", audioDir: "audio_es"),
      ]
    )
    defer { cleanUp() }

    let parser = ProjectMarkdownParser()
    let masterPath = masterDir.appendingPathComponent("PROJECT.md")
    let (master, _) = try parser.parse(fileURL: masterPath)

    let indexer = VariantIndexer(master: master, masterDirectory: masterDir)
    try indexer.loadVariants()

    #expect(indexer.languages.sorted() == ["en", "es"])
    #expect(indexer.seasons(for: "en") == [1])
    #expect(indexer.seasons(for: "es") == [1])

    let enVariant = indexer.variant(for: "en", season: 1)
    let esVariant = indexer.variant(for: "es", season: 1)

    #expect(enVariant != nil)
    #expect(esVariant != nil)
    #expect(enVariant?.languages?.first?.code == "en")
    #expect(esVariant?.languages?.first?.code == "es")
  }

  @Test("Load four variants (2 languages × 2 seasons)")
  func loadFourVariants() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject(
      variants: [
        (season: 1, language: "en", audioDir: "audio_s01_en"),
        (season: 1, language: "es", audioDir: "audio_s01_es"),
        (season: 2, language: "en", audioDir: "audio_s02_en"),
        (season: 2, language: "es", audioDir: "audio_s02_es"),
      ]
    )
    defer { cleanUp() }

    let parser = ProjectMarkdownParser()
    let masterPath = masterDir.appendingPathComponent("PROJECT.md")
    let (master, _) = try parser.parse(fileURL: masterPath)

    let indexer = VariantIndexer(master: master, masterDirectory: masterDir)
    try indexer.loadVariants()

    #expect(indexer.languages.sorted() == ["en", "es"])
    #expect(indexer.seasons(for: "en").sorted() == [1, 2])
    #expect(indexer.seasons(for: "es").sorted() == [1, 2])

    // Verify all combinations
    #expect(indexer.variant(for: "en", season: 1) != nil)
    #expect(indexer.variant(for: "en", season: 2) != nil)
    #expect(indexer.variant(for: "es", season: 1) != nil)
    #expect(indexer.variant(for: "es", season: 2) != nil)

    // Verify missing combinations return nil
    #expect(indexer.variant(for: "fr", season: 1) == nil)
    #expect(indexer.variant(for: "en", season: 3) == nil)
  }
}

@Suite("VariantIndexer - Query Operations")
struct VariantIndexerQueryTests {

  @Test("Get all variants for a language")
  func getAllVariantsForLanguage() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject(
      variants: [
        (season: 1, language: "es", audioDir: nil),
        (season: 2, language: "es", audioDir: nil),
      ]
    )
    defer { cleanUp() }

    let parser = ProjectMarkdownParser()
    let masterPath = masterDir.appendingPathComponent("PROJECT.md")
    let (master, _) = try parser.parse(fileURL: masterPath)

    let indexer = VariantIndexer(master: master, masterDirectory: masterDir)
    try indexer.loadVariants()

    let variants = indexer.variants(for: "es")
    #expect(variants != nil)
    #expect(variants?.count == 2)
    #expect(variants?[1] != nil)
    #expect(variants?[2] != nil)
  }

  @Test("Get all variants as flat array")
  func getAllVariantsAsArray() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject(
      variants: [
        (season: 1, language: "en", audioDir: nil),
        (season: 1, language: "es", audioDir: nil),
        (season: 2, language: "en", audioDir: nil),
      ]
    )
    defer { cleanUp() }

    let parser = ProjectMarkdownParser()
    let masterPath = masterDir.appendingPathComponent("PROJECT.md")
    let (master, _) = try parser.parse(fileURL: masterPath)

    let indexer = VariantIndexer(master: master, masterDirectory: masterDir)
    try indexer.loadVariants()

    let allVariants = indexer.allVariants()
    #expect(allVariants.count == 3)
  }

  @Test("Language list is sorted")
  func languageListSorted() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject(
      variants: [
        (season: 1, language: "fr", audioDir: nil),
        (season: 1, language: "en", audioDir: nil),
        (season: 1, language: "es", audioDir: nil),
      ]
    )
    defer { cleanUp() }

    let parser = ProjectMarkdownParser()
    let masterPath = masterDir.appendingPathComponent("PROJECT.md")
    let (master, _) = try parser.parse(fileURL: masterPath)

    let indexer = VariantIndexer(master: master, masterDirectory: masterDir)
    try indexer.loadVariants()

    #expect(indexer.languages == ["en", "es", "fr"])
  }

  @Test("Season list is sorted for language")
  func seasonListSorted() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject(
      variants: [
        (season: 3, language: "en", audioDir: nil),
        (season: 1, language: "en", audioDir: nil),
        (season: 2, language: "en", audioDir: nil),
      ]
    )
    defer { cleanUp() }

    let parser = ProjectMarkdownParser()
    let masterPath = masterDir.appendingPathComponent("PROJECT.md")
    let (master, _) = try parser.parse(fileURL: masterPath)

    let indexer = VariantIndexer(master: master, masterDirectory: masterDir)
    try indexer.loadVariants()

    #expect(indexer.seasons(for: "en") == [1, 2, 3])
  }
}

@Suite("VariantIndexer - Error Handling")
struct VariantIndexerErrorTests {

  @Test("Missing variant file throws error")
  func missingVariantFileError() throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("VariantIndexerTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { _ = try? FileManager.default.removeItem(at: tempDir) }

    // Create master with reference to non-existent variant
    let variantRef = VariantReference(
      season: 1,
      language: "es",
      path: "projects/s01_es/PROJECT.md"
    )

    let masterContent = makeMasterProjectContent(variants: [variantRef])
    let masterPath = tempDir.appendingPathComponent("PROJECT.md")
    try masterContent.write(to: masterPath, atomically: true, encoding: .utf8)

    let parser = ProjectMarkdownParser()
    let (master, _) = try parser.parse(fileURL: masterPath)

    let indexer = VariantIndexer(master: master, masterDirectory: tempDir)

    // Should throw error when trying to load non-existent variant
    do {
      try indexer.loadVariants()
      #expect(Bool(false), "Expected error but none was thrown")
    } catch let error as VariantIndexError {
      guard case .variantFileNotFound = error else {
        #expect(Bool(false), "Expected variantFileNotFound error")
        return
      }
    }
  }
}

// MARK: - ProjectDiscovery Variant Discovery Tests

@Suite("ProjectDiscovery - Variant Discovery")
struct ProjectDiscoveryVariantTests {

  @Test("Find variants from master file")
  func findVariantsFromMaster() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject(
      variants: [
        (season: 1, language: "en", audioDir: nil),
        (season: 1, language: "es", audioDir: nil),
      ]
    )
    defer { cleanUp() }

    let masterPath = masterDir.appendingPathComponent("PROJECT.md")

    let variants = try ProjectDiscovery.findVariants(from: masterPath)
    #expect(variants.count == 2)
  }

  @Test("Find variants with 4 combinations")
  func findVariantsMultiLanguageMultiSeason() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject(
      variants: [
        (season: 1, language: "en", audioDir: nil),
        (season: 1, language: "es", audioDir: nil),
        (season: 2, language: "en", audioDir: nil),
        (season: 2, language: "es", audioDir: nil),
      ]
    )
    defer { cleanUp() }

    let masterPath = masterDir.appendingPathComponent("PROJECT.md")

    let variants = try ProjectDiscovery.findVariants(from: masterPath)
    #expect(variants.count == 4)
  }

  @Test("Load specific variant by reference")
  func loadSpecificVariant() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject(
      variants: [
        (season: 1, language: "en", audioDir: "audio_en"),
        (season: 1, language: "es", audioDir: "audio_es"),
      ]
    )
    defer { cleanUp() }

    let masterPath = masterDir.appendingPathComponent("PROJECT.md")

    let variantRef = VariantReference(
      season: 1,
      language: "es",
      path: "projects/s01_es/PROJECT.md"
    )

    let resolved = try ProjectDiscovery.loadVariant(reference: variantRef, from: masterPath)

    // The resolved variant should inherit master's seasons and have access to season 1
    #expect(resolved.seasons?.count == 1)
    #expect(resolved.seasons?.first?.number == 1)
    // The variant's audioDir should be preserved
    #expect(resolved.audioDir == "audio_es")
  }

  @Test("Variant not master file error")
  func variantNotMasterFileError() throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("ProjectDiscoveryTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { _ = try? FileManager.default.removeItem(at: tempDir) }

    // Create a regular project file (not master)
    let projectContent = makeVariantProjectContent()
    let projectPath = tempDir.appendingPathComponent("PROJECT.md")
    try projectContent.write(to: projectPath, atomically: true, encoding: .utf8)

    // Should throw error because it's not a master file
    do {
      try ProjectDiscovery.findVariants(from: projectPath)
      #expect(Bool(false), "Expected error but none was thrown")
    } catch let error as VariantIndexError {
      guard case .notAMasterFile = error else {
        #expect(Bool(false), "Expected notAMasterFile error")
        return
      }
    }
  }
}

@Suite("ProjectDiscovery - Variant Property Resolution")
struct ProjectDiscoveryVariantResolutionTests {

  @Test("Variant inherits properties from master")
  func variantInheritsFromMaster() throws {
    let (masterDir, cleanUp) = try makeTestMasterProject(
      variants: [(season: 1, language: "es", audioDir: nil)]
    )
    defer { cleanUp() }

    let masterPath = masterDir.appendingPathComponent("PROJECT.md")

    let variantRef = VariantReference(
      season: 1,
      language: "es",
      path: "projects/s01_es/PROJECT.md"
    )

    let resolved = try ProjectDiscovery.loadVariant(reference: variantRef, from: masterPath)

    // Title should come from master
    #expect(resolved.title == "Master Series")
    // Author should come from master
    #expect(resolved.author == "Author Name")
  }

  @Test("Variant property overrides master property")
  func variantOverridesMaster() throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("ProjectDiscoveryTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { _ = try? FileManager.default.removeItem(at: tempDir) }

    // Create master with audioDir
    let variantRef = VariantReference(
      season: 1,
      language: "es",
      path: "projects/s01_es/PROJECT.md"
    )

    let masterContent = makeMasterProjectContent(variants: [variantRef])
    let masterPath = tempDir.appendingPathComponent("PROJECT.md")
    try masterContent.write(to: masterPath, atomically: true, encoding: .utf8)

    // Create variant with different audioDir
    let variantDir =
      tempDir
      .appendingPathComponent("projects")
      .appendingPathComponent("s01_es")
    try FileManager.default.createDirectory(at: variantDir, withIntermediateDirectories: true)

    let variantContent = makeVariantProjectContent(
      language: "es",
      season: 1,
      audioDir: "variant-audio"
    )
    let variantPath = variantDir.appendingPathComponent("PROJECT.md")
    try variantContent.write(to: variantPath, atomically: true, encoding: .utf8)

    let resolved = try ProjectDiscovery.loadVariant(reference: variantRef, from: masterPath)

    // audioDir should come from variant
    #expect(resolved.audioDir == "variant-audio")
  }
}

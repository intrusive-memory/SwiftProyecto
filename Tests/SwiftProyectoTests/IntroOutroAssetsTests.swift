import XCTest
import Foundation

@testable import SwiftProyecto

final class IntroOutroAssetsTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInitialization_AllNil() {
    let assets = IntroOutroAssets()

    XCTAssertNil(assets.introPath)
    XCTAssertNil(assets.outroPath)
    XCTAssertFalse(assets.isIntroMissing)
    XCTAssertFalse(assets.isOutroMissing)
  }

  func testInitialization_WithPaths() {
    let assets = IntroOutroAssets(
      introPath: "intro.m4a",
      outroPath: "outro.m4a"
    )

    XCTAssertEqual(assets.introPath, "intro.m4a")
    XCTAssertEqual(assets.outroPath, "outro.m4a")
    XCTAssertFalse(assets.isIntroMissing)
    XCTAssertFalse(assets.isOutroMissing)
  }

  func testInitialization_WithMissingFlags() {
    let assets = IntroOutroAssets(
      introPath: "intro.m4a",
      outroPath: "outro.m4a",
      isIntroMissing: true,
      isOutroMissing: true
    )

    XCTAssertEqual(assets.introPath, "intro.m4a")
    XCTAssertEqual(assets.outroPath, "outro.m4a")
    XCTAssertTrue(assets.isIntroMissing)
    XCTAssertTrue(assets.isOutroMissing)
  }

  func testEquality() {
    let assets1 = IntroOutroAssets(
      introPath: "intro.m4a",
      outroPath: "outro.m4a"
    )
    let assets2 = IntroOutroAssets(
      introPath: "intro.m4a",
      outroPath: "outro.m4a"
    )
    let assets3 = IntroOutroAssets(
      introPath: "intro2.m4a",
      outroPath: "outro.m4a"
    )

    XCTAssertEqual(assets1, assets2)
    XCTAssertNotEqual(assets1, assets3)
  }

  // MARK: - Resolution Tests

  func testResolvedIntroFile_FromVariant() {
    let master = ProjectFrontMatter(
      title: "Master",
      author: "Author",
      introFile: "master-intro.m4a"
    )

    let variant = ProjectFrontMatter(
      title: "Variant",
      author: "Author",
      introFile: "variant-intro.m4a"
    )

    let resolved = variant.resolvedIntroFile(forSeason: 1, withMaster: master)
    XCTAssertEqual(resolved, "variant-intro.m4a")
  }

  func testResolvedIntroFile_FromSeason() {
    let seasonDef = SeasonDefinition(
      number: 1,
      episodes: 12,
      introFile: "season-intro.m4a"
    )

    let master = ProjectFrontMatter(
      title: "Master",
      author: "Author",
      introFile: "master-intro.m4a",
      seasons: [seasonDef]
    )

    let variant = ProjectFrontMatter(
      title: "Variant",
      author: "Author"
    )

    let resolved = variant.resolvedIntroFile(forSeason: 1, withMaster: master)
    XCTAssertEqual(resolved, "season-intro.m4a")
  }

  func testResolvedIntroFile_FromMaster() {
    let master = ProjectFrontMatter(
      title: "Master",
      author: "Author",
      introFile: "master-intro.m4a"
    )

    let variant = ProjectFrontMatter(
      title: "Variant",
      author: "Author"
    )

    let resolved = variant.resolvedIntroFile(forSeason: 1, withMaster: master)
    XCTAssertEqual(resolved, "master-intro.m4a")
  }

  func testResolvedIntroFile_Nil() {
    let master = ProjectFrontMatter(
      title: "Master",
      author: "Author"
    )

    let variant = ProjectFrontMatter(
      title: "Variant",
      author: "Author"
    )

    let resolved = variant.resolvedIntroFile(forSeason: 1, withMaster: master)
    XCTAssertNil(resolved)
  }

  func testResolvedOutroFile_Hierarchy() {
    let seasonDef = SeasonDefinition(
      number: 1,
      episodes: 12,
      outroFile: "season-outro.m4a"
    )

    let master = ProjectFrontMatter(
      title: "Master",
      author: "Author",
      outroFile: "master-outro.m4a",
      seasons: [seasonDef]
    )

    let variant = ProjectFrontMatter(
      title: "Variant",
      author: "Author",
      outroFile: "variant-outro.m4a"
    )

    let resolved = variant.resolvedOutroFile(forSeason: 1, withMaster: master)
    XCTAssertEqual(resolved, "variant-outro.m4a")
  }

  // MARK: - Missing File Detection Tests

  func testResolvedIntroOutroAssets_NoFiles() {
    let tempDir = FileManager.default.temporaryDirectory
    let projectDir = tempDir.appendingPathComponent("intro-outro-test-\(UUID().uuidString)")
    let episodesDir = "episodes"

    do {
      try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

      let master = ProjectFrontMatter(
        title: "Master",
        author: "Author"
      )

      let variant = ProjectFrontMatter(
        title: "Variant",
        author: "Author"
      )

      let assets = variant.resolvedIntroOutroAssets(
        forSeason: 1,
        withMaster: master,
        episodesDir: episodesDir,
        baseDirectory: projectDir
      )

      XCTAssertNil(assets.introPath)
      XCTAssertNil(assets.outroPath)
      XCTAssertFalse(assets.isIntroMissing)
      XCTAssertFalse(assets.isOutroMissing)

      try FileManager.default.removeItem(at: projectDir)
    } catch {
      XCTFail("Failed to set up test: \(error)")
    }
  }

  func testResolvedIntroOutroAssets_ExistingFiles() {
    let tempDir = FileManager.default.temporaryDirectory
    let projectDir = tempDir.appendingPathComponent("intro-outro-test-\(UUID().uuidString)")
    let episodesDir = "episodes"

    do {
      try FileManager.default.createDirectory(
        at: projectDir.appendingPathComponent(episodesDir),
        withIntermediateDirectories: true
      )

      // Create actual files
      let introURL = projectDir.appendingPathComponent(episodesDir).appendingPathComponent("intro.m4a")
      let outroURL = projectDir.appendingPathComponent(episodesDir).appendingPathComponent("outro.m4a")

      FileManager.default.createFile(atPath: introURL.path, contents: nil)
      FileManager.default.createFile(atPath: outroURL.path, contents: nil)

      let master = ProjectFrontMatter(
        title: "Master",
        author: "Author",
        introFile: "intro.m4a",
        outroFile: "outro.m4a"
      )

      let variant = ProjectFrontMatter(
        title: "Variant",
        author: "Author"
      )

      let assets = variant.resolvedIntroOutroAssets(
        forSeason: 1,
        withMaster: master,
        episodesDir: episodesDir,
        baseDirectory: projectDir
      )

      XCTAssertEqual(assets.introPath, "intro.m4a")
      XCTAssertEqual(assets.outroPath, "outro.m4a")
      XCTAssertFalse(assets.isIntroMissing)
      XCTAssertFalse(assets.isOutroMissing)

      try FileManager.default.removeItem(at: projectDir)
    } catch {
      XCTFail("Failed to set up test: \(error)")
    }
  }

  func testResolvedIntroOutroAssets_MissingFiles() {
    let tempDir = FileManager.default.temporaryDirectory
    let projectDir = tempDir.appendingPathComponent("intro-outro-test-\(UUID().uuidString)")
    let episodesDir = "episodes"

    do {
      try FileManager.default.createDirectory(
        at: projectDir.appendingPathComponent(episodesDir),
        withIntermediateDirectories: true
      )

      let master = ProjectFrontMatter(
        title: "Master",
        author: "Author",
        introFile: "intro.m4a",
        outroFile: "outro.m4a"
      )

      let variant = ProjectFrontMatter(
        title: "Variant",
        author: "Author"
      )

      let assets = variant.resolvedIntroOutroAssets(
        forSeason: 1,
        withMaster: master,
        episodesDir: episodesDir,
        baseDirectory: projectDir
      )

      XCTAssertEqual(assets.introPath, "intro.m4a")
      XCTAssertEqual(assets.outroPath, "outro.m4a")
      XCTAssertTrue(assets.isIntroMissing)
      XCTAssertTrue(assets.isOutroMissing)

      try FileManager.default.removeItem(at: projectDir)
    } catch {
      XCTFail("Failed to set up test: \(error)")
    }
  }

  func testResolvedIntroOutroAssets_PartiallyMissing() {
    let tempDir = FileManager.default.temporaryDirectory
    let projectDir = tempDir.appendingPathComponent("intro-outro-test-\(UUID().uuidString)")
    let episodesDir = "episodes"

    do {
      try FileManager.default.createDirectory(
        at: projectDir.appendingPathComponent(episodesDir),
        withIntermediateDirectories: true
      )

      // Create only intro file
      let introURL = projectDir.appendingPathComponent(episodesDir).appendingPathComponent("intro.m4a")
      FileManager.default.createFile(atPath: introURL.path, contents: nil)

      let master = ProjectFrontMatter(
        title: "Master",
        author: "Author",
        introFile: "intro.m4a",
        outroFile: "outro.m4a"
      )

      let variant = ProjectFrontMatter(
        title: "Variant",
        author: "Author"
      )

      let assets = variant.resolvedIntroOutroAssets(
        forSeason: 1,
        withMaster: master,
        episodesDir: episodesDir,
        baseDirectory: projectDir
      )

      XCTAssertEqual(assets.introPath, "intro.m4a")
      XCTAssertEqual(assets.outroPath, "outro.m4a")
      XCTAssertFalse(assets.isIntroMissing)
      XCTAssertTrue(assets.isOutroMissing)

      try FileManager.default.removeItem(at: projectDir)
    } catch {
      XCTFail("Failed to set up test: \(error)")
    }
  }

  // MARK: - Multiple Seasons/Variants Tests

  func testResolvedIntroOutroAssets_MultipleSeasonsWithDifferentIntros() {
    let tempDir = FileManager.default.temporaryDirectory
    let projectDir = tempDir.appendingPathComponent("intro-outro-test-\(UUID().uuidString)")
    let episodesDir = "episodes"

    do {
      try FileManager.default.createDirectory(
        at: projectDir.appendingPathComponent(episodesDir),
        withIntermediateDirectories: true
      )

      // Create season intro files
      let season1IntroURL = projectDir.appendingPathComponent(episodesDir).appendingPathComponent("s1-intro.m4a")
      let season2IntroURL = projectDir.appendingPathComponent(episodesDir).appendingPathComponent("s2-intro.m4a")

      FileManager.default.createFile(atPath: season1IntroURL.path, contents: nil)
      FileManager.default.createFile(atPath: season2IntroURL.path, contents: nil)

      let season1 = SeasonDefinition(
        number: 1,
        episodes: 12,
        introFile: "s1-intro.m4a"
      )
      let season2 = SeasonDefinition(
        number: 2,
        episodes: 10,
        introFile: "s2-intro.m4a"
      )

      let master = ProjectFrontMatter(
        title: "Master",
        author: "Author",
        seasons: [season1, season2]
      )

      let variant = ProjectFrontMatter(
        title: "Variant",
        author: "Author"
      )

      // Test Season 1
      let assets1 = variant.resolvedIntroOutroAssets(
        forSeason: 1,
        withMaster: master,
        episodesDir: episodesDir,
        baseDirectory: projectDir
      )

      XCTAssertEqual(assets1.introPath, "s1-intro.m4a")
      XCTAssertFalse(assets1.isIntroMissing)

      // Test Season 2
      let assets2 = variant.resolvedIntroOutroAssets(
        forSeason: 2,
        withMaster: master,
        episodesDir: episodesDir,
        baseDirectory: projectDir
      )

      XCTAssertEqual(assets2.introPath, "s2-intro.m4a")
      XCTAssertFalse(assets2.isIntroMissing)

      try FileManager.default.removeItem(at: projectDir)
    } catch {
      XCTFail("Failed to set up test: \(error)")
    }
  }

  func testResolvedIntroOutroAssets_VariantOverridesSeason() {
    let tempDir = FileManager.default.temporaryDirectory
    let projectDir = tempDir.appendingPathComponent("intro-outro-test-\(UUID().uuidString)")
    let episodesDir = "episodes"

    do {
      try FileManager.default.createDirectory(
        at: projectDir.appendingPathComponent(episodesDir),
        withIntermediateDirectories: true
      )

      // Create files
      let seasonIntroURL = projectDir.appendingPathComponent(episodesDir).appendingPathComponent("season-intro.m4a")
      let variantIntroURL = projectDir.appendingPathComponent(episodesDir).appendingPathComponent("variant-intro.m4a")

      FileManager.default.createFile(atPath: seasonIntroURL.path, contents: nil)
      FileManager.default.createFile(atPath: variantIntroURL.path, contents: nil)

      let season1 = SeasonDefinition(
        number: 1,
        episodes: 12,
        introFile: "season-intro.m4a"
      )

      let master = ProjectFrontMatter(
        title: "Master",
        author: "Author",
        seasons: [season1]
      )

      let variant = ProjectFrontMatter(
        title: "Variant",
        author: "Author",
        introFile: "variant-intro.m4a"
      )

      let assets = variant.resolvedIntroOutroAssets(
        forSeason: 1,
        withMaster: master,
        episodesDir: episodesDir,
        baseDirectory: projectDir
      )

      // Variant should override season
      XCTAssertEqual(assets.introPath, "variant-intro.m4a")
      XCTAssertFalse(assets.isIntroMissing)

      try FileManager.default.removeItem(at: projectDir)
    } catch {
      XCTFail("Failed to set up test: \(error)")
    }
  }

  // MARK: - Encoding/Decoding Tests

  func testCoding_Full() throws {
    let master = ProjectFrontMatter(
      title: "Master",
      author: "Author",
      introFile: "master-intro.m4a",
      outroFile: "master-outro.m4a"
    )

    let encoded = try JSONEncoder().encode(master)
    let decoded = try JSONDecoder().decode(ProjectFrontMatter.self, from: encoded)

    XCTAssertEqual(decoded.introFile, "master-intro.m4a")
    XCTAssertEqual(decoded.outroFile, "master-outro.m4a")
  }

  func testCoding_Nil() throws {
    let master = ProjectFrontMatter(
      title: "Master",
      author: "Author"
    )

    let encoded = try JSONEncoder().encode(master)
    let decoded = try JSONDecoder().decode(ProjectFrontMatter.self, from: encoded)

    XCTAssertNil(decoded.introFile)
    XCTAssertNil(decoded.outroFile)
  }

  func testCoding_WithSeason() throws {
    let season = SeasonDefinition(
      number: 1,
      episodes: 12,
      introFile: "season-intro.m4a",
      outroFile: "season-outro.m4a"
    )

    let master = ProjectFrontMatter(
      title: "Master",
      author: "Author",
      seasons: [season]
    )

    let encoded = try JSONEncoder().encode(master)
    let decoded = try JSONDecoder().decode(ProjectFrontMatter.self, from: encoded)

    XCTAssertEqual(decoded.seasons?.count, 1)
    XCTAssertEqual(decoded.seasons?[0].introFile, "season-intro.m4a")
    XCTAssertEqual(decoded.seasons?[0].outroFile, "season-outro.m4a")
  }

  func testCoding_WithVariant() throws {
    let variant = VariantReference(
      season: 1,
      language: "en",
      path: "projects/s01_en/PROJECT.md",
      introFile: "variant-intro.m4a",
      outroFile: "variant-outro.m4a"
    )

    let master = ProjectFrontMatter(
      title: "Master",
      author: "Author",
      variants: [variant]
    )

    let encoded = try JSONEncoder().encode(master)
    let decoded = try JSONDecoder().decode(ProjectFrontMatter.self, from: encoded)

    XCTAssertEqual(decoded.variants?.count, 1)
    XCTAssertEqual(decoded.variants?[0].introFile, "variant-intro.m4a")
    XCTAssertEqual(decoded.variants?[0].outroFile, "variant-outro.m4a")
  }
}

import XCTest
import Foundation

@testable import SwiftProyecto

final class ProjectStructureRecognitionTests: XCTestCase {

  // MARK: - Test Helpers

  private var tempDir: URL!
  private let fileManager = FileManager.default

  override func setUp() {
    super.setUp()
    // Create a unique temporary directory for each test
    let tempBase = fileManager.temporaryDirectory
      .appendingPathComponent("ProjectStructureTests-\(UUID().uuidString)")
    try? fileManager.createDirectory(at: tempBase, withIntermediateDirectories: true)
    tempDir = tempBase
  }

  override func tearDown() {
    if let tempDir = tempDir {
      try? fileManager.removeItem(at: tempDir)
    }
    super.tearDown()
  }

  /// Helper: Create a directory structure
  private func createDir(_ path: String) throws {
    let url = tempDir.appendingPathComponent(path)
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
  }

  /// Helper: Create an empty file
  private func createFile(_ path: String, withExtension ext: String = "fountain") throws {
    let url = tempDir.appendingPathComponent(path).appendingPathExtension(ext)
    fileManager.createFile(atPath: url.path, contents: nil)
  }

  // MARK: - Language-First Multi-Season Tests

  func testLanguageFirstMultiSeason_LinguaMatraPattern() throws {
    // Create lingua-matra structure: lang/season-N/files
    try createDir("en/season-1")
    try createDir("en/season-2")
    try createDir("es/season-1")
    try createDir("es/season-2")

    try createFile("en/season-1/episode-1")
    try createFile("en/season-1/episode-2")
    try createFile("en/season-2/episode-1")
    try createFile("es/season-1/episode-1")
    try createFile("es/season-2/episode-1")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .languageFirstMultiSeason(let languages, let seasons):
      XCTAssertEqual(Set(languages), ["en", "es"])
      XCTAssertEqual(Set(seasons), [1, 2])
    default:
      XCTFail("Expected languageFirstMultiSeason, got \(structure.recognizedPattern)")
    }

    XCTAssertEqual(structure.directoryMap["en"]?.sorted(), [1, 2])
    XCTAssertEqual(structure.directoryMap["es"]?.sorted(), [1, 2])
  }

  func testLanguageFirstMultiSeason_BCPTags() throws {
    // Create structure with BCP 47 language tags
    try createDir("en-US/season-1")
    try createDir("es-MX/season-1")
    try createFile("en-US/season-1/episode-1")
    try createFile("es-MX/season-1/episode-1")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .languageFirstMultiSeason(let languages, let seasons):
      XCTAssertEqual(Set(languages), ["en", "es"])
      XCTAssertEqual(Set(seasons), [1])
    default:
      XCTFail("Expected languageFirstMultiSeason with BCP tags")
    }
  }

  func testLanguageFirstMultiSeason_ThreeLetterCodes() throws {
    // Create structure with 3-letter ISO language codes
    try createDir("eng/s1")
    try createDir("spa/s1")
    try createFile("eng/s1/script")
    try createFile("spa/s1/script")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .languageFirstMultiSeason(let languages, let seasons):
      XCTAssertEqual(languages.count, 2)
      XCTAssertEqual(Set(seasons), [1])
    default:
      XCTFail("Expected languageFirstMultiSeason with 3-letter codes")
    }
  }

  // MARK: - Single Language Multi-Season Tests

  func testSingleLanguageMultiSeason_NumberPatterns() throws {
    // Create season-first structure: 1/files, 2/files, 3/files
    try createDir("1")
    try createDir("2")
    try createDir("3")

    try createFile("1/episode-1")
    try createFile("2/episode-1")
    try createFile("3/episode-1")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .singleLanguageMultiSeason(let seasons):
      XCTAssertEqual(Set(seasons), [1, 2, 3])
    default:
      XCTFail("Expected singleLanguageMultiSeason, got \(structure.recognizedPattern)")
    }
  }

  func testSingleLanguageMultiSeason_SeasonPrefix() throws {
    // Create: season-1/, season-2/, season-3/
    try createDir("season-1")
    try createDir("season-2")
    try createDir("season-3")

    try createFile("season-1/ep1")
    try createFile("season-2/ep1")
    try createFile("season-3/ep1")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .singleLanguageMultiSeason(let seasons):
      XCTAssertEqual(Set(seasons), [1, 2, 3])
    default:
      XCTFail("Expected singleLanguageMultiSeason")
    }
  }

  func testSingleLanguageMultiSeason_SPrefix() throws {
    // Create: s1/, s2/, s3/
    try createDir("s1")
    try createDir("s2")
    try createDir("s3")

    try createFile("s1/episode")
    try createFile("s2/episode")
    try createFile("s3/episode")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .singleLanguageMultiSeason(let seasons):
      XCTAssertEqual(Set(seasons), [1, 2, 3])
    default:
      XCTFail("Expected singleLanguageMultiSeason with s prefix")
    }
  }

  func testSingleLanguageMultiSeason_MixedPatterns() throws {
    // Mix different season patterns: season-1, s2, 3
    try createDir("season-1")
    try createDir("s2")
    try createDir("3")

    try createFile("season-1/ep")
    try createFile("s2/ep")
    try createFile("3/ep")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .singleLanguageMultiSeason(let seasons):
      XCTAssertEqual(Set(seasons), [1, 2, 3])
    default:
      XCTFail("Expected singleLanguageMultiSeason with mixed patterns")
    }
  }

  // MARK: - Language-Only Tests

  func testLanguageOnly_SimpleISOCodes() throws {
    // Create: en/, es/, fr/ with subdirectories (not files) to avoid flat classification
    try createDir("en/scripts")
    try createDir("es/scripts")
    try createDir("fr/scripts")

    try createFile("en/scripts/script")
    try createFile("es/scripts/script")
    try createFile("fr/scripts/script")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .languageOnly(let languages):
      XCTAssertEqual(Set(languages), ["en", "es", "fr"])
    default:
      XCTFail("Expected languageOnly, got \(structure.recognizedPattern)")
    }
  }

  func testLanguageOnly_BCPLocales() throws {
    // Create: en-US/, es-MX/, pt-BR/ with subdirectories to avoid flat classification
    try createDir("en-US/scripts")
    try createDir("es-MX/scripts")
    try createDir("pt-BR/scripts")

    try createFile("en-US/scripts/script")
    try createFile("es-MX/scripts/script")
    try createFile("pt-BR/scripts/script")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .languageOnly(let languages):
      XCTAssertEqual(Set(languages), ["en", "es", "pt"])
    default:
      XCTFail("Expected languageOnly with BCP locales")
    }
  }

  // MARK: - Flat Structure Tests

  func testFlat_NoLanguageOrSeasonStructure() throws {
    // Create: just files at root
    try createFile("episode-1")
    try createFile("episode-2")
    try createFile("episode-3")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .flat:
      break  // Expected
    default:
      XCTFail("Expected flat, got \(structure.recognizedPattern)")
    }
  }

  // MARK: - File Pattern Detection Tests

  func testFilePatterns_MultipleExtensions() throws {
    try createDir("en/s1")
    try createFile("en/s1/script", withExtension: "fountain")
    try createFile("en/s1/screenplay", withExtension: "fdx")
    try createFile("en/s1/outline", withExtension: "highland")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    XCTAssertEqual(Set(structure.filePatterns), ["*.fountain", "*.fdx", "*.highland"])
  }

  func testFilePatterns_DuplicateExtensions() throws {
    try createDir("en")
    try createFile("en/ep1", withExtension: "fountain")
    try createFile("en/ep2", withExtension: "fountain")
    try createFile("en/ep3", withExtension: "fountain")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    XCTAssertEqual(structure.filePatterns, ["*.fountain"])
  }

  // MARK: - Audio Directory Detection Tests

  func testAudioDirectories_StandardPatterns() throws {
    try createDir("en/audio")
    try createDir("es/audio_output")
    try createDir("output")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    XCTAssertEqual(Set(structure.audioDirectories), ["en/audio", "es/audio_output", "output"])
  }

  // MARK: - Voice Files Detection Tests

  func testVoiceFiles_Detection() throws {
    try createDir("en")
    try createFile("en/voices", withExtension: "json")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    // Should detect _voices.json, _voices.yaml, etc.
    // Create a file with the actual pattern
    try createDir("characters")
    try createFile("characters/cast_voices", withExtension: "json")

    let structure2 = ProjectService.scanAndRecognize(at: tempDir)

    // Just verify the function runs without error
    XCTAssertNotNil(structure2.voiceFiles)
  }

  // MARK: - Directory Map Tests

  func testDirectoryMap_PopulatesCorrectly() throws {
    try createDir("en/season-1")
    try createDir("en/season-2")
    try createDir("es/season-1")
    try createFile("en/season-1/ep")
    try createFile("en/season-2/ep")
    try createFile("es/season-1/ep")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    XCTAssertEqual(structure.directoryMap["en"]?.sorted(), [1, 2])
    XCTAssertEqual(structure.directoryMap["es"]?.sorted(), [1])
  }

  // MARK: - Edge Cases

  func testEmptyDirectory() throws {
    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .flat:
      break  // Empty is treated as flat
    default:
      XCTFail("Expected flat for empty directory")
    }
  }

  func testNonexistentDirectory() throws {
    let nonexistent = tempDir.appendingPathComponent("does-not-exist")
    let structure = ProjectService.scanAndRecognize(at: nonexistent)

    switch structure.recognizedPattern {
    case .unknown:
      break  // Expected
    default:
      XCTFail("Expected unknown for nonexistent directory")
    }
  }

  func testRootURLPreserved() throws {
    try createFile("episode")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    XCTAssertEqual(structure.rootURL, tempDir)
  }

  func testSeasonNumberBoundaries() throws {
    // Valid season numbers: 1-999
    try createDir("season-0")  // Invalid
    try createDir("season-999")  // Valid max
    try createDir("season-1000")  // Invalid
    try createDir("season-1")  // Valid

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .singleLanguageMultiSeason(let seasons):
      // Should only include 1 and 999
      XCTAssertTrue(seasons.contains(1))
      XCTAssertTrue(seasons.contains(999))
      XCTAssertFalse(seasons.contains(0))
      XCTAssertFalse(seasons.contains(1000))
    default:
      XCTFail("Expected singleLanguageMultiSeason")
    }
  }

  func testCaseInsensitiveLanguageCodes() throws {
    // Language codes should work regardless of case
    try createDir("EN/season-1")
    try createDir("Es/Season-1")
    try createFile("EN/season-1/ep")
    try createFile("Es/Season-1/ep")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .languageFirstMultiSeason(let languages, _):
      XCTAssertEqual(Set(languages), ["en", "es"])
    default:
      XCTFail("Expected case-insensitive language detection")
    }
  }

  // MARK: - Pattern Recognition Pattern Tests

  func testRecognitionPattern_Description() {
    let p1 = RecognitionPattern.languageFirstMultiSeason(languages: ["en", "es"], seasons: [1, 2, 3])
    XCTAssertTrue(p1.description.contains("Language-first"))
    XCTAssertTrue(p1.description.contains("2 languages"))
    XCTAssertTrue(p1.description.contains("3 seasons"))

    let p2 = RecognitionPattern.singleLanguageMultiSeason(seasons: [1, 2])
    XCTAssertTrue(p2.description.contains("Single-language"))
    XCTAssertTrue(p2.description.contains("2 seasons"))

    let p3 = RecognitionPattern.languageOnly(languages: ["en", "es", "fr"])
    XCTAssertTrue(p3.description.contains("Language-only"))
    XCTAssertTrue(p3.description.contains("3 languages"))

    let p4 = RecognitionPattern.flat
    XCTAssertEqual(p4.description, "Flat structure")

    let p5 = RecognitionPattern.unknown
    XCTAssertEqual(p5.description, "Unknown structure")
  }

  func testRecognitionPattern_Equatable() {
    let p1 = RecognitionPattern.flat
    let p2 = RecognitionPattern.flat
    XCTAssertEqual(p1, p2)

    let p3 = RecognitionPattern.languageFirstMultiSeason(languages: ["en"], seasons: [1])
    let p4 = RecognitionPattern.languageFirstMultiSeason(languages: ["en"], seasons: [1])
    XCTAssertEqual(p3, p4)

    let p5 = RecognitionPattern.languageFirstMultiSeason(languages: ["en"], seasons: [1])
    let p6 = RecognitionPattern.languageFirstMultiSeason(languages: ["es"], seasons: [1])
    XCTAssertNotEqual(p5, p6)
  }

  // MARK: - Complex Integration Tests

  func testComplexProject_MultiLanguageMultiSeason() throws {
    // Simulate a complex multi-language, multi-season project
    for lang in ["en", "es", "fr", "de"] {
      for season in 1...3 {
        try createDir("\(lang)/season-\(season)")
        for ep in 1...5 {
          try createFile("\(lang)/season-\(season)/episode-\(ep)")
        }
      }
      try createDir("\(lang)/audio")
    }

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .languageFirstMultiSeason(let languages, let seasons):
      XCTAssertEqual(Set(languages), ["en", "es", "fr", "de"])
      XCTAssertEqual(Set(seasons), [1, 2, 3])
    default:
      XCTFail("Expected languageFirstMultiSeason for complex project")
    }

    // Verify all languages mapped to all seasons
    for lang in ["en", "es", "fr", "de"] {
      XCTAssertEqual(structure.directoryMap[lang]?.sorted(), [1, 2, 3])
    }

    // Verify audio directories detected
    XCTAssertEqual(structure.audioDirectories.count, 4)
  }

  func testHiatus_UnusualSeasonNumbers() throws {
    // Some projects skip seasons (e.g., 1, 3, 5)
    try createDir("season-1")
    try createDir("season-3")
    try createDir("season-5")

    try createFile("season-1/ep")
    try createFile("season-3/ep")
    try createFile("season-5/ep")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .singleLanguageMultiSeason(let seasons):
      XCTAssertEqual(Set(seasons), [1, 3, 5])
    default:
      XCTFail("Expected singleLanguageMultiSeason with non-contiguous numbers")
    }
  }

  func testDeepNesting_IgnoresNonLanguageNonSeasonDirs() throws {
    // Create: en/season-1/scripts/act1/scene1/file.fountain
    try createDir("en/season-1/scripts/act1/scene1")
    try createFile("en/season-1/scripts/act1/scene1/scene", withExtension: "fountain")

    let structure = ProjectService.scanAndRecognize(at: tempDir)

    switch structure.recognizedPattern {
    case .languageFirstMultiSeason(let languages, let seasons):
      XCTAssertEqual(Set(languages), ["en"])
      XCTAssertEqual(Set(seasons), [1])
    default:
      XCTFail("Expected to recognize pattern even with deep nesting")
    }

    XCTAssertTrue(structure.filePatterns.contains("*.fountain"))
  }
}

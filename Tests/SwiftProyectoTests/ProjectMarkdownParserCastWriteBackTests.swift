//
//  ProjectMarkdownParserCastWriteBackTests.swift
//  SwiftProyecto
//
//  Golden round-trip coverage for the surgical, minimal-diff cast write-back
//  (`replacingCastBlock`) introduced to fix the PROJECT.md data-loss bug
//  (issue intrusive-memory/SwiftEchada#55, same root cause as #44).
//

import XCTest

@testable import SwiftProyecto

final class ProjectMarkdownParserCastWriteBackTests: XCTestCase {

  var parser: ProjectMarkdownParser!

  override func setUp() {
    super.setUp()
    parser = ProjectMarkdownParser()
  }

  override func tearDown() {
    parser = nil
    super.tearDown()
  }

  /// A rich PROJECT.md fixture that exercises every survival case from the plan:
  /// `introFile`/`outroFile` (known keys NOT in the appSections catch-all), inline
  /// comments, an unknown top-level key (`episodes_index`), a `tts` block, and a
  /// deliberately non-alphabetical key order.
  private let goldenFixture = """
    ---
    type: project
    title: Granville
    author: Tom Stovall
    created: 2026-01-01T00:00:00Z
    # Intro/outro asset references live BELOW cast in this file on purpose,
    # to prove the surgical splice does not reorder or drop them.
    genre: comedy
    tts:
      providerId: voxalta
      model: 1.7b
    cast:
      - character: NARRATOR
        actor: Tom Stovall
        gender: M
        voicePrompt: Deep warm baritone with gravitas
        voices:
          voxalta: NARRATOR
      - character: PREDATOR_MOM
        gender: F
        voicePrompt: Sharp predatory sing-song menace
        voices:
          voxalta: PREDATOR_MOM
    introFile: intro.fountain
    outroFile: outro.fountain
    episodes_index: episodes/index.json
    ---

    # Granville

    Body content that must survive untouched.
    """

  /// Replace one cast member's `voices` and assert:
  /// (a) introFile/outroFile/unknown key survive,
  /// (b) every non-cast line is byte-identical,
  /// (c) only the intended `voices:` lines changed.
  func testReplacingCastBlock_ReplacesVoices_PreservesEverythingElse() throws {
    let (frontMatter, _) = try parser.parse(content: goldenFixture)
    var cast = try XCTUnwrap(frontMatter.cast)

    // Sanity: the fixture parsed the keys we care about.
    XCTAssertEqual(frontMatter.introFile, "intro.fountain")
    XCTAssertEqual(frontMatter.outroFile, "outro.fountain")
    XCTAssertEqual(
      try frontMatter.appSections["episodes_index"]?.decode(String.self), "episodes/index.json")

    // Mutate PREDATOR_MOM's voxalta voice (single -> single, new id).
    let idx = try XCTUnwrap(cast.firstIndex(where: { $0.character == "PREDATOR_MOM" }))
    cast[idx].voices = ["voxalta": ["PREDATOR_MOM_2"]]

    let updated = try parser.replacingCastBlock(in: goldenFixture, with: cast)

    // (a) Survival of the previously-dropped / catch-all-excluded keys.
    XCTAssertTrue(
      updated.contains("\nintroFile: intro.fountain\n"),
      "introFile must survive surgical cast write-back")
    XCTAssertTrue(
      updated.contains("\noutroFile: outro.fountain\n"),
      "outroFile must survive surgical cast write-back")
    XCTAssertTrue(
      updated.contains("\nepisodes_index: episodes/index.json\n"),
      "unknown top-level key must survive surgical cast write-back")
    XCTAssertTrue(updated.contains("# Intro/outro asset references"), "comments must survive")
    XCTAssertTrue(updated.contains("providerId: voxalta"), "tts block must survive")

    // Re-parse to confirm the intended change landed.
    let (updatedFM, _) = try parser.parse(content: updated)
    let updatedMember = try XCTUnwrap(updatedFM.cast?.first(where: { $0.character == "PREDATOR_MOM" }))
    XCTAssertEqual(updatedMember.voices["voxalta"], ["PREDATOR_MOM_2"])
    XCTAssertEqual(updatedFM.introFile, "intro.fountain")
    XCTAssertEqual(updatedFM.outroFile, "outro.fountain")
    XCTAssertEqual(
      try updatedFM.appSections["episodes_index"]?.decode(String.self), "episodes/index.json")

    // (b) + (c) Byte-level diff: the ONLY changed line must be the voxalta voice
    // value under PREDATOR_MOM. Every other line is byte-identical. (The fixture's
    // cast block is already in canonical generator form — no comma-quoting drift —
    // so re-rendering the block touches nothing but the edited voice id.)
    let originalLines = goldenFixture.components(separatedBy: "\n")
    let updatedLines = updated.components(separatedBy: "\n")
    XCTAssertEqual(
      originalLines.count, updatedLines.count,
      "line count must be unchanged (single-voice -> single-voice edit)")

    var changed: [(Int, String, String)] = []
    for (old, new) in zip(originalLines, updatedLines) where old != new {
      changed.append((0, old, new))
    }
    XCTAssertEqual(changed.count, 1, "exactly one line should differ; got \(changed)")
    XCTAssertEqual(changed.first?.1, "      voxalta: PREDATOR_MOM")
    XCTAssertEqual(changed.first?.2, "      voxalta: PREDATOR_MOM_2")
  }

  /// The no-existing-cast-block insert case: a fixture with no `cast:` gets one
  /// appended just before the closing `---`, leaving all other lines intact.
  func testReplacingCastBlock_InsertsWhenNoCastBlockExists() throws {
    let noCast = """
      ---
      type: project
      title: Granville
      author: Tom Stovall
      created: 2026-01-01T00:00:00Z
      introFile: intro.fountain
      outroFile: outro.fountain
      ---

      # Body
      """
    let cast = [
      CastMember(character: "NARRATOR", voices: ["voxalta": ["NARRATOR"]])
    ]
    let updated = try parser.replacingCastBlock(in: noCast, with: cast)

    XCTAssertTrue(updated.contains("cast:\n"), "a cast block must be inserted")
    XCTAssertTrue(updated.contains("  - character: NARRATOR"))
    XCTAssertTrue(updated.contains("\nintroFile: intro.fountain\n"))
    XCTAssertTrue(updated.contains("\noutroFile: outro.fountain\n"))

    let (fm, body) = try parser.parse(content: updated)
    XCTAssertEqual(fm.cast?.count, 1)
    XCTAssertEqual(fm.cast?.first?.character, "NARRATOR")
    XCTAssertEqual(fm.introFile, "intro.fountain")
    XCTAssertEqual(body, "# Body")
  }

  /// Belt-and-suspenders: `generate()` itself must now emit introFile/outroFile
  /// so a freshly generated file is not born without them.
  func testGenerate_EmitsIntroAndOutroFile() throws {
    let (frontMatter, body) = try parser.parse(content: goldenFixture)
    let regenerated = parser.generate(frontMatter: frontMatter, body: body)

    XCTAssertTrue(
      regenerated.contains("introFile: intro.fountain"),
      "generate() must emit introFile (fresh-file safety net)")
    XCTAssertTrue(
      regenerated.contains("outroFile: outro.fountain"),
      "generate() must emit outroFile (fresh-file safety net)")

    // Round-trip through generate() preserves the values.
    let (rt, _) = try parser.parse(content: regenerated)
    XCTAssertEqual(rt.introFile, "intro.fountain")
    XCTAssertEqual(rt.outroFile, "outro.fountain")
  }

  /// Multi-voice replacement changes the line count but still leaves all
  /// non-cast lines byte-identical.
  func testReplacingCastBlock_MultiVoice_PreservesNonCastLines() throws {
    let (frontMatter, _) = try parser.parse(content: goldenFixture)
    var cast = try XCTUnwrap(frontMatter.cast)
    let idx = try XCTUnwrap(cast.firstIndex(where: { $0.character == "NARRATOR" }))
    cast[idx].voices = ["voxalta": ["NARRATOR", "NARRATOR_ALT"]]

    let updated = try parser.replacingCastBlock(in: goldenFixture, with: cast)

    // Non-cast content is fully preserved.
    for key in ["introFile: intro.fountain", "outroFile: outro.fountain", "episodes_index: episodes/index.json", "providerId: voxalta"] {
      XCTAssertTrue(updated.contains(key), "\(key) must survive")
    }
    let (fm, _) = try parser.parse(content: updated)
    let narrator = try XCTUnwrap(fm.cast?.first(where: { $0.character == "NARRATOR" }))
    XCTAssertEqual(narrator.voices["voxalta"], ["NARRATOR", "NARRATOR_ALT"])
  }
}

import XCTest

@testable import SwiftProyecto

final class VariantResolverTests: XCTestCase {

  // MARK: - Setup Helpers

  func makeMasterProjectFrontMatter(
    title: String = "Master Project",
    author: String = "Jane Showrunner",
    description: String? = "Master description",
    genre: String? = "Science Fiction",
    tags: [String]? = ["sci-fi", "drama"],
    episodesDir: String? = "master-episodes",
    audioDir: String? = "master-audio",
    filePattern: FilePattern? = nil,
    exportFormat: String? = nil,
    cast: [CastMember]? = nil,
    tts: TTSConfig? = nil,
    seasons: [SeasonDefinition]? = nil
  ) -> ProjectFrontMatter {
    ProjectFrontMatter(
      type: "project",
      title: title,
      author: author,
      created: Date(),
      description: description,
      genre: genre,
      tags: tags,
      episodesDir: episodesDir,
      audioDir: audioDir,
      filePattern: filePattern,
      exportFormat: exportFormat,
      cast: cast,
      tts: tts,
      schemaVersion: 4,
      projectType: "overview",
      seasons: seasons
    )
  }

  func makeVariantProjectFrontMatter(
    title: String = "Variant",
    author: String = "Jane Showrunner",
    description: String? = nil,
    genre: String? = nil,
    tags: [String]? = nil,
    episodesDir: String? = nil,
    audioDir: String? = nil,
    filePattern: FilePattern? = nil,
    exportFormat: String? = nil,
    cast: [CastMember]? = nil,
    tts: TTSConfig? = nil,
    episodePath: String? = nil
  ) -> ProjectFrontMatter {
    ProjectFrontMatter(
      type: "project",
      title: title,
      author: author,
      created: Date(),
      description: description,
      genre: genre,
      tags: tags,
      episodesDir: episodesDir,
      audioDir: audioDir,
      filePattern: filePattern,
      exportFormat: exportFormat,
      cast: cast,
      tts: tts,
      schemaVersion: 4,
      projectType: "project",
      episodePath: episodePath
    )
  }

  // MARK: - Property Resolution Tests

  func testResolve_VariantOnly_ReturnsVariantProperty() {
    let master = makeMasterProjectFrontMatter(audioDir: "master-audio")
    let variant = makeVariantProjectFrontMatter(audioDir: "variant-audio")

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertEqual(resolved.audioDir, "variant-audio")
  }

  func testResolve_VariantEmpty_InheritFromMaster() {
    let master = makeMasterProjectFrontMatter(audioDir: "master-audio")
    let variant = makeVariantProjectFrontMatter(audioDir: nil)

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertEqual(resolved.audioDir, "master-audio")
  }

  func testResolve_SeasonOverride_PreferredOverMaster() {
    let seasonDef = SeasonDefinition(
      number: 1,
      episodes: 12,
      episodesDir: "season1-episodes"
    )
    let master = makeMasterProjectFrontMatter(
      audioDir: "master-audio",
      seasons: [seasonDef]
    )
    let variant = makeVariantProjectFrontMatter(audioDir: nil)

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    // Since season doesn't have audioDir, should fall back to master
    XCTAssertEqual(resolved.audioDir, "master-audio")
  }

  func testResolve_VariantOverridesAll() {
    let seasonDef = SeasonDefinition(
      number: 1,
      episodes: 12,
      episodesDir: "season1-episodes"
    )
    let master = makeMasterProjectFrontMatter(
      audioDir: "master-audio",
      seasons: [seasonDef]
    )
    let variant = makeVariantProjectFrontMatter(audioDir: "variant-audio")

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertEqual(resolved.audioDir, "variant-audio")
  }

  func testResolve_ImmutableFields_AlwaysFromMaster() {
    let master = makeMasterProjectFrontMatter(
      title: "Master Title",
      author: "Master Author"
    )
    let variant = makeVariantProjectFrontMatter(
      title: "Variant Title",
      author: "Variant Author"
    )

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertEqual(resolved.title, "Master Title")
    XCTAssertEqual(resolved.author, "Master Author")
  }

  func testResolve_Description_ResolvedFromHierarchy() {
    let seasonDef = SeasonDefinition(
      number: 1,
      description: "Season 1 description",
      episodes: 12
    )
    let master = makeMasterProjectFrontMatter(
      description: "Master description",
      seasons: [seasonDef]
    )

    // Test: variant overrides all
    let variant1 = makeVariantProjectFrontMatter(description: "Variant description")
    let resolved1 = variant1.resolve(withMaster: master, forSeason: 1)
    XCTAssertEqual(resolved1.description, "Variant description")

    // Test: season overrides master
    let variant2 = makeVariantProjectFrontMatter(description: nil)
    let resolved2 = variant2.resolve(withMaster: master, forSeason: 1)
    XCTAssertEqual(resolved2.description, "Season 1 description")

    // Test: master when season not defined
    let masterNoSeason = makeMasterProjectFrontMatter(
      description: "Master description",
      seasons: nil
    )
    let variant3 = makeVariantProjectFrontMatter(description: nil)
    let resolved3 = variant3.resolve(withMaster: masterNoSeason, forSeason: 1)
    XCTAssertEqual(resolved3.description, "Master description")
  }

  // MARK: - Cast Inheritance Tests

  func testResolve_CastInheritance_VariantSpecified() {
    let masterCast = [
      CastMember(
        character: "NARRATOR",
        voices: ["apple": ["voice1"]]
      ),
      CastMember(
        character: "MAESTRA",
        voices: ["apple": ["voice2"]]
      ),
    ]
    let master = makeMasterProjectFrontMatter(cast: masterCast)

    let variantCast = [
      CastMember(
        character: "NARRATOR",
        voices: ["elevenlabs": ["voice3"]]
      )
    ]
    let variant = makeVariantProjectFrontMatter(cast: variantCast)

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertNotNil(resolved.cast)
    XCTAssertEqual(resolved.cast?.count, 2)

    // Find NARRATOR in resolved cast
    if let narrator = resolved.cast?.first(where: { $0.character == "NARRATOR" }) {
      XCTAssertTrue(narrator.voices.keys.contains("apple"))
      XCTAssertTrue(narrator.voices.keys.contains("elevenlabs"))
      // Voice combination: variant's elevenlabs + master's apple
      XCTAssertEqual(narrator.voices["apple"], ["voice1"])
      XCTAssertEqual(narrator.voices["elevenlabs"], ["voice3"])
    } else {
      XCTFail("NARRATOR not found in resolved cast")
    }

    // Find MAESTRA in resolved cast (should be inherited)
    if let maestra = resolved.cast?.first(where: { $0.character == "MAESTRA" }) {
      XCTAssertEqual(maestra.voices["apple"], ["voice2"])
      XCTAssertEqual(maestra.voices.keys.count, 1)
    } else {
      XCTFail("MAESTRA not found in resolved cast")
    }
  }

  func testResolve_CastInheritance_UnspecifiedCharactersInherit() {
    let masterCast = [
      CastMember(
        character: "NARRATOR",
        actor: "Tom Stovall",
        voices: ["apple": ["voice1"]]
      ),
      CastMember(
        character: "MAESTRA",
        voices: ["apple": ["voice2"]]
      ),
    ]
    let master = makeMasterProjectFrontMatter(cast: masterCast)

    let variantCast = [
      CastMember(
        character: "NARRATOR",
        voices: ["elevenlabs": ["voice3"]]
      )
    ]
    let variant = makeVariantProjectFrontMatter(cast: variantCast)

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertNotNil(resolved.cast)
    XCTAssertEqual(resolved.cast?.count, 2)

    // NARRATOR should have both voices (merged)
    if let narrator = resolved.cast?.first(where: { $0.character == "NARRATOR" }) {
      XCTAssertEqual(narrator.voices.keys.count, 2)
      XCTAssertTrue(narrator.voices.keys.contains("apple"))
      XCTAssertTrue(narrator.voices.keys.contains("elevenlabs"))
    } else {
      XCTFail("NARRATOR not found")
    }

    // MAESTRA should be inherited unchanged
    if let maestra = resolved.cast?.first(where: { $0.character == "MAESTRA" }) {
      XCTAssertEqual(maestra.voices["apple"], ["voice2"])
      XCTAssertEqual(maestra.voices.keys.count, 1)
    } else {
      XCTFail("MAESTRA not found")
    }
  }

  func testResolve_CastInheritance_SeasonOverrideMaster() {
    let masterCast = [
      CastMember(
        character: "NARRATOR",
        voices: ["apple": ["master-voice"]]
      )
    ]
    let seasonCast = [
      CastMember(
        character: "NARRATOR",
        voices: ["elevenlabs": ["season-voice"]]
      )
    ]
    let seasonDef = SeasonDefinition(
      number: 1,
      episodes: 12,
      cast: seasonCast
    )
    let master = makeMasterProjectFrontMatter(
      cast: masterCast,
      seasons: [seasonDef]
    )

    let variantCast = [
      CastMember(
        character: "NARRATOR",
        voices: ["voxalta": ["variant-voice"]]
      )
    ]
    let variant = makeVariantProjectFrontMatter(cast: variantCast)

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertNotNil(resolved.cast)
    if let narrator = resolved.cast?.first(where: { $0.character == "NARRATOR" }) {
      // All three should be present (zero-loss merge)
      XCTAssertEqual(narrator.voices.keys.count, 3)
      XCTAssertEqual(narrator.voices["apple"], ["master-voice"])
      XCTAssertEqual(narrator.voices["elevenlabs"], ["season-voice"])
      XCTAssertEqual(narrator.voices["voxalta"], ["variant-voice"])
    } else {
      XCTFail("NARRATOR not found")
    }
  }

  func testResolve_CastInheritance_NilCastAtAllLevels() {
    let master = makeMasterProjectFrontMatter(cast: nil)
    let variant = makeVariantProjectFrontMatter(cast: nil)

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertNil(resolved.cast)
  }

  func testResolve_CastInheritance_NewCharacterAtVariantLevel() {
    let masterCast = [
      CastMember(
        character: "NARRATOR",
        voices: ["apple": ["voice1"]]
      )
    ]
    let master = makeMasterProjectFrontMatter(cast: masterCast)

    let variantCast = [
      CastMember(
        character: "NEW_CHARACTER",
        voices: ["elevenlabs": ["voice2"]]
      )
    ]
    let variant = makeVariantProjectFrontMatter(cast: variantCast)

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertNotNil(resolved.cast)
    XCTAssertEqual(resolved.cast?.count, 2)

    // Check both characters are present
    let characters = resolved.cast?.map { $0.character } ?? []
    XCTAssertTrue(characters.contains("NARRATOR"))
    XCTAssertTrue(characters.contains("NEW_CHARACTER"))
  }

  // MARK: - TTS Configuration Tests

  func testResolve_TTSConfig_VariantOverridesAll() {
    let masterTTS = TTSConfig(providerId: "apple", voiceId: "master-voice")
    let seasonTTS = TTSConfig(providerId: "elevenlabs", voiceId: "season-voice")
    let seasonDef = SeasonDefinition(
      number: 1,
      episodes: 12,
      tts: seasonTTS
    )
    let master = makeMasterProjectFrontMatter(
      tts: masterTTS,
      seasons: [seasonDef]
    )

    let variantTTS = TTSConfig(providerId: "voxalta", voiceId: "variant-voice")
    let variant = makeVariantProjectFrontMatter(tts: variantTTS)

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertEqual(resolved.tts?.providerId, "voxalta")
    XCTAssertEqual(resolved.tts?.voiceId, "variant-voice")
  }

  func testResolve_TTSConfig_SeasonOverridesMaster() {
    let masterTTS = TTSConfig(providerId: "apple", voiceId: "master-voice")
    let seasonTTS = TTSConfig(providerId: "elevenlabs", voiceId: "season-voice")
    let seasonDef = SeasonDefinition(
      number: 1,
      episodes: 12,
      tts: seasonTTS
    )
    let master = makeMasterProjectFrontMatter(
      tts: masterTTS,
      seasons: [seasonDef]
    )

    let variant = makeVariantProjectFrontMatter(tts: nil)

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertEqual(resolved.tts?.providerId, "elevenlabs")
    XCTAssertEqual(resolved.tts?.voiceId, "season-voice")
  }

  // MARK: - Complex Integration Tests

  func testResolve_MultipleProperties_FullHierarchy() {
    let seasonDef = SeasonDefinition(
      number: 1,
      description: "Season 1",
      episodes: 12
    )
    let master = makeMasterProjectFrontMatter(
      title: "Master Series",
      author: "Master Author",
      description: "Master description",
      genre: "Drama",
      audioDir: "master-audio",
      seasons: [seasonDef]
    )

    let variant = makeVariantProjectFrontMatter(
      title: "Variant",  // Should be ignored
      author: "Variant Author",  // Should be ignored
      description: "Variant description",  // Should override
      audioDir: nil  // Should fall through to master
    )

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    // Immutable fields from master
    XCTAssertEqual(resolved.title, "Master Series")
    XCTAssertEqual(resolved.author, "Master Author")

    // Description: variant overrides
    XCTAssertEqual(resolved.description, "Variant description")

    // Audio dir: falls through to master (season doesn't have audioDir)
    XCTAssertEqual(resolved.audioDir, "master-audio")

    // Genre: from master (no override)
    XCTAssertEqual(resolved.genre, "Drama")
  }

  func testResolve_InstanceMethod_Delegates() {
    let master = makeMasterProjectFrontMatter(
      title: "Master",
      audioDir: "master-audio"
    )
    let variant = makeVariantProjectFrontMatter(
      audioDir: "variant-audio"
    )

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertEqual(resolved.audioDir, "variant-audio")
    XCTAssertEqual(resolved.title, "Master")
  }

  // MARK: - Schema Preservation Tests

  func testResolve_PreservesSchemaVersion() {
    let master = makeMasterProjectFrontMatter()
    let variant = makeVariantProjectFrontMatter()

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertEqual(resolved.schemaVersion, 4)
  }

  func testResolve_PreservesSeasonDefinitions() {
    let seasonDef = SeasonDefinition(number: 1, episodes: 12)
    let master = makeMasterProjectFrontMatter(seasons: [seasonDef])
    let variant = makeVariantProjectFrontMatter()

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertNotNil(resolved.seasons)
    XCTAssertEqual(resolved.seasons?.count, 1)
    XCTAssertEqual(resolved.seasons?.first?.number, 1)
  }

  // MARK: - Edge Cases

  func testResolve_NoSeasonFound_ReturnsOnlyMaster() {
    let master = makeMasterProjectFrontMatter(seasons: nil)
    let variant = makeVariantProjectFrontMatter()

    let resolved = variant.resolve(withMaster: master, forSeason: 99)

    XCTAssertEqual(resolved.title, master.title)
    XCTAssertEqual(resolved.author, master.author)
  }

  func testResolve_EmptyCastLists() {
    let master = makeMasterProjectFrontMatter(cast: [])
    let variant = makeVariantProjectFrontMatter(cast: [])

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertNil(resolved.cast)
  }

  func testResolve_VariantAppSections_PreferredOverMaster() throws {
    let masterSections = [
      "app1": try AnyCodable(["setting": "master"])
    ]
    let master = makeMasterProjectFrontMatter()
    var masterWithSections = master
    masterWithSections.appSections = masterSections

    let variantSections = [
      "app1": try AnyCodable(["setting": "variant"])
    ]
    var variant = makeVariantProjectFrontMatter()
    variant.appSections = variantSections

    let resolved = variant.resolve(withMaster: masterWithSections, forSeason: 1)

    XCTAssertFalse(resolved.appSections.isEmpty)
    if let appSection = resolved.appSections["app1"] {
      do {
        let dict = try appSection.decode([String: String].self)
        XCTAssertEqual(dict["setting"], "variant")
      } catch {
        XCTFail("Could not decode variant app section: \(error)")
      }
    }
  }

  // MARK: - Intro/Outro Resolution Tests

  func testResolve_IntroOutro_VariantOverridesMaster() {
    let master = makeMasterProjectFrontMatter(
      title: "Master",
      author: "Author"
    )
    var masterWithIntroOutro = master
    masterWithIntroOutro = ProjectFrontMatter(
      type: master.type,
      title: master.title,
      author: master.author,
      created: master.created,
      description: master.description,
      genre: master.genre,
      tags: master.tags,
      episodesDir: master.episodesDir,
      audioDir: master.audioDir,
      filePattern: master.filePattern,
      exportFormat: master.exportFormat,
      introFile: "master-intro.m4a",
      outroFile: "master-outro.m4a",
      cast: master.cast,
      preGenerateHook: master.preGenerateHook,
      postGenerateHook: master.postGenerateHook,
      tts: master.tts,
      schemaVersion: master.schemaVersion,
      projectType: master.projectType,
      seasons: master.seasons,
      languages: master.languages,
      variants: master.variants,
      episodePath: master.episodePath,
      appSections: master.appSections
    )

    var variant = makeVariantProjectFrontMatter(
      title: "Variant",
      author: "Author"
    )
    variant = ProjectFrontMatter(
      type: variant.type,
      title: variant.title,
      author: variant.author,
      created: variant.created,
      description: variant.description,
      genre: variant.genre,
      tags: variant.tags,
      episodesDir: variant.episodesDir,
      audioDir: variant.audioDir,
      filePattern: variant.filePattern,
      exportFormat: variant.exportFormat,
      introFile: "variant-intro.m4a",
      outroFile: "variant-outro.m4a",
      cast: variant.cast,
      preGenerateHook: variant.preGenerateHook,
      postGenerateHook: variant.postGenerateHook,
      tts: variant.tts,
      schemaVersion: variant.schemaVersion,
      projectType: variant.projectType,
      seasons: variant.seasons,
      languages: variant.languages,
      variants: variant.variants,
      episodePath: variant.episodePath,
      appSections: variant.appSections
    )

    let resolved = variant.resolve(withMaster: masterWithIntroOutro, forSeason: 1)

    XCTAssertEqual(resolved.introFile, "variant-intro.m4a")
    XCTAssertEqual(resolved.outroFile, "variant-outro.m4a")
  }

  func testResolve_IntroOutro_SeasonOverridesMaster() {
    let seasonDef = SeasonDefinition(
      number: 1,
      episodes: 12,
      introFile: "season-intro.m4a",
      outroFile: "season-outro.m4a"
    )

    var master = makeMasterProjectFrontMatter(
      title: "Master",
      author: "Author",
      seasons: [seasonDef]
    )
    master = ProjectFrontMatter(
      type: master.type,
      title: master.title,
      author: master.author,
      created: master.created,
      description: master.description,
      genre: master.genre,
      tags: master.tags,
      episodesDir: master.episodesDir,
      audioDir: master.audioDir,
      filePattern: master.filePattern,
      exportFormat: master.exportFormat,
      introFile: "master-intro.m4a",
      outroFile: "master-outro.m4a",
      cast: master.cast,
      preGenerateHook: master.preGenerateHook,
      postGenerateHook: master.postGenerateHook,
      tts: master.tts,
      schemaVersion: master.schemaVersion,
      projectType: master.projectType,
      seasons: master.seasons,
      languages: master.languages,
      variants: master.variants,
      episodePath: master.episodePath,
      appSections: master.appSections
    )

    let variant = makeVariantProjectFrontMatter(title: "Variant", author: "Author")

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertEqual(resolved.introFile, "season-intro.m4a")
    XCTAssertEqual(resolved.outroFile, "season-outro.m4a")
  }

  func testResolve_IntroOutro_VariantOverridesSeason() {
    let seasonDef = SeasonDefinition(
      number: 1,
      episodes: 12,
      introFile: "season-intro.m4a",
      outroFile: "season-outro.m4a"
    )

    var master = makeMasterProjectFrontMatter(
      title: "Master",
      author: "Author",
      seasons: [seasonDef]
    )
    master = ProjectFrontMatter(
      type: master.type,
      title: master.title,
      author: master.author,
      created: master.created,
      description: master.description,
      genre: master.genre,
      tags: master.tags,
      episodesDir: master.episodesDir,
      audioDir: master.audioDir,
      filePattern: master.filePattern,
      exportFormat: master.exportFormat,
      introFile: "master-intro.m4a",
      outroFile: "master-outro.m4a",
      cast: master.cast,
      preGenerateHook: master.preGenerateHook,
      postGenerateHook: master.postGenerateHook,
      tts: master.tts,
      schemaVersion: master.schemaVersion,
      projectType: master.projectType,
      seasons: master.seasons,
      languages: master.languages,
      variants: master.variants,
      episodePath: master.episodePath,
      appSections: master.appSections
    )

    var variant = makeVariantProjectFrontMatter(title: "Variant", author: "Author")
    variant = ProjectFrontMatter(
      type: variant.type,
      title: variant.title,
      author: variant.author,
      created: variant.created,
      description: variant.description,
      genre: variant.genre,
      tags: variant.tags,
      episodesDir: variant.episodesDir,
      audioDir: variant.audioDir,
      filePattern: variant.filePattern,
      exportFormat: variant.exportFormat,
      introFile: "variant-intro.m4a",
      outroFile: "variant-outro.m4a",
      cast: variant.cast,
      preGenerateHook: variant.preGenerateHook,
      postGenerateHook: variant.postGenerateHook,
      tts: variant.tts,
      schemaVersion: variant.schemaVersion,
      projectType: variant.projectType,
      seasons: variant.seasons,
      languages: variant.languages,
      variants: variant.variants,
      episodePath: variant.episodePath,
      appSections: variant.appSections
    )

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertEqual(resolved.introFile, "variant-intro.m4a")
    XCTAssertEqual(resolved.outroFile, "variant-outro.m4a")
  }

  func testResolve_IntroOutro_InheritFromMaster() {
    var master = makeMasterProjectFrontMatter(
      title: "Master",
      author: "Author"
    )
    master = ProjectFrontMatter(
      type: master.type,
      title: master.title,
      author: master.author,
      created: master.created,
      description: master.description,
      genre: master.genre,
      tags: master.tags,
      episodesDir: master.episodesDir,
      audioDir: master.audioDir,
      filePattern: master.filePattern,
      exportFormat: master.exportFormat,
      introFile: "master-intro.m4a",
      outroFile: "master-outro.m4a",
      cast: master.cast,
      preGenerateHook: master.preGenerateHook,
      postGenerateHook: master.postGenerateHook,
      tts: master.tts,
      schemaVersion: master.schemaVersion,
      projectType: master.projectType,
      seasons: master.seasons,
      languages: master.languages,
      variants: master.variants,
      episodePath: master.episodePath,
      appSections: master.appSections
    )

    let variant = makeVariantProjectFrontMatter(title: "Variant", author: "Author")

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertEqual(resolved.introFile, "master-intro.m4a")
    XCTAssertEqual(resolved.outroFile, "master-outro.m4a")
  }

  func testResolve_IntroOutro_AllNil() {
    let master = makeMasterProjectFrontMatter(title: "Master", author: "Author")
    let variant = makeVariantProjectFrontMatter(title: "Variant", author: "Author")

    let resolved = variant.resolve(withMaster: master, forSeason: 1)

    XCTAssertNil(resolved.introFile)
    XCTAssertNil(resolved.outroFile)
  }

  func testResolve_IntroOutro_DifferentSeasons() {
    let season1 = SeasonDefinition(
      number: 1,
      episodes: 12,
      introFile: "s1-intro.m4a",
      outroFile: "s1-outro.m4a"
    )
    let season2 = SeasonDefinition(
      number: 2,
      episodes: 10,
      introFile: "s2-intro.m4a",
      outroFile: "s2-outro.m4a"
    )

    let master = makeMasterProjectFrontMatter(
      title: "Master",
      author: "Author",
      seasons: [season1, season2]
    )

    let variant = makeVariantProjectFrontMatter(title: "Variant", author: "Author")

    // Test Season 1
    let resolvedSeason1 = variant.resolve(withMaster: master, forSeason: 1)
    XCTAssertEqual(resolvedSeason1.introFile, "s1-intro.m4a")
    XCTAssertEqual(resolvedSeason1.outroFile, "s1-outro.m4a")

    // Test Season 2
    let resolvedSeason2 = variant.resolve(withMaster: master, forSeason: 2)
    XCTAssertEqual(resolvedSeason2.introFile, "s2-intro.m4a")
    XCTAssertEqual(resolvedSeason2.outroFile, "s2-outro.m4a")
  }
}

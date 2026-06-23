import XCTest

@testable import SwiftProyecto

final class EpisodePathResolverTests: XCTestCase {

  // MARK: - Basic Resolution Tests

  func testResolveLanguageFirst() {
    let template = "episodes/<language>/<season>/<episode>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(result, "episodes/es/1/5.fountain")
  }

  func testResolveSeasonFirst() {
    let template = "episodes/<season>/<language>/<episode>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(result, "episodes/1/es/5.fountain")
  }

  func testResolveFlatStructure() {
    let template = "episodes/<episode>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(result, "episodes/5.fountain")
  }

  func testResolveLanguageOnly() {
    let template = "episodes/<language>/<episode>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(result, "episodes/es/5.fountain")
  }

  func testResolveCustomPattern() {
    let template = "content/<language>/s<season>/ep<episode>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "fr",
      season: 2,
      episode: 10,
      ext: "m4a"
    )
    XCTAssertEqual(result, "content/fr/s2/ep10.m4a")
  }

  // MARK: - Variable Extraction Tests

  func testExtractVariablesFromLanguageFirst() {
    let template = "episodes/<language>/<season>/<episode>.<ext>"
    let variables = EpisodePathResolver.extractVariables(from: template)
    XCTAssertEqual(Set(variables), Set(["language", "season", "episode", "ext"]))
  }

  func testExtractVariablesFromFlat() {
    let template = "episodes/<episode>.<ext>"
    let variables = EpisodePathResolver.extractVariables(from: template)
    XCTAssertEqual(Set(variables), Set(["episode", "ext"]))
  }

  func testExtractVariablesWithCustomPattern() {
    let template = "content/<language>/s<season>/ep<episode>.<ext>"
    let variables = EpisodePathResolver.extractVariables(from: template)
    XCTAssertEqual(Set(variables), Set(["language", "season", "episode", "ext"]))
  }

  func testExtractVariablesNoVariables() {
    let template = "episodes/fixed/path"
    let variables = EpisodePathResolver.extractVariables(from: template)
    XCTAssertEqual(variables.count, 0)
  }

  func testExtractVariablesMaintainsOrder() {
    let template = "<language>-<season>-<episode>"
    let variables = EpisodePathResolver.extractVariables(from: template)
    XCTAssertEqual(variables, ["language", "season", "episode"])
  }

  // MARK: - Template Validation Tests

  func testValidateKnownVariables() {
    let template = "episodes/<language>/<season>/<episode>.<ext>"
    let (isValid, invalidVars) = EpisodePathResolver.validateTemplate(template)
    XCTAssertTrue(isValid)
    XCTAssertEqual(invalidVars.count, 0)
  }

  func testValidateWithUnknownVariable() {
    let template = "episodes/<language>/<unknown>/<episode>.<ext>"
    let (isValid, invalidVars) = EpisodePathResolver.validateTemplate(template)
    XCTAssertTrue(isValid)  // Still valid (warnings, not errors)
    XCTAssertEqual(invalidVars, ["unknown"])
  }

  func testValidateMultipleUnknownVariables() {
    let template = "episodes/<language>/<unknown1>/<unknown2>.<ext>"
    let (isValid, invalidVars) = EpisodePathResolver.validateTemplate(template)
    XCTAssertTrue(isValid)
    XCTAssertEqual(Set(invalidVars), Set(["unknown1", "unknown2"]))
  }

  func testValidateNoVariables() {
    let template = "episodes/fixed/path"
    let (isValid, invalidVars) = EpisodePathResolver.validateTemplate(template)
    XCTAssertTrue(isValid)
    XCTAssertEqual(invalidVars.count, 0)
  }

  // MARK: - Case Sensitivity Tests

  func testVariablesCaseSensitive() {
    let template = "episodes/<Language>/<SEASON>/<EPISODE>.<EXT>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    // Variables shouldn't match (case-sensitive), so they remain unchanged
    XCTAssertEqual(result, "episodes/<Language>/<SEASON>/<EPISODE>.<EXT>")
  }

  func testExtractVariablesCaseSensitive() {
    let template = "episodes/<Language>/<season>/<Episode>"
    let variables = EpisodePathResolver.extractVariables(from: template)
    XCTAssertEqual(Set(variables), Set(["Language", "season", "Episode"]))
  }

  func testValidateCaseSensitive() {
    let template = "episodes/<Language>/<season>"
    let (isValid, invalidVars) = EpisodePathResolver.validateTemplate(template)
    XCTAssertTrue(isValid)
    // "Language" and "season" don't match known variables exactly
    XCTAssertEqual(invalidVars, ["Language"])
  }

  // MARK: - Edge Cases

  func testResolveWithMultiDigitNumbers() {
    let template = "episodes/<season>/<episode>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 10,
      episode: 123,
      ext: "fountain"
    )
    XCTAssertEqual(result, "episodes/10/123.fountain")
  }

  func testResolveWithLeadingZeros() {
    let template = "episodes/<season>/<episode>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 01,
      episode: 005,
      ext: "fountain"
    )
    // Leading zeros in literals are lost in integer conversion
    XCTAssertEqual(result, "episodes/1/5.fountain")
  }

  func testResolveWithDifferentLanguages() {
    let template = "episodes/<language>/<episode>.<ext>"

    let es = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(es, "episodes/es/5.fountain")

    let fr = EpisodePathResolver.resolve(
      template: template,
      language: "fr",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(fr, "episodes/fr/5.fountain")

    let en = EpisodePathResolver.resolve(
      template: template,
      language: "en",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(en, "episodes/en/5.fountain")
  }

  func testResolveWithDifferentExtensions() {
    let template = "episodes/<episode>.<ext>"

    let fountain = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(fountain, "episodes/5.fountain")

    let m4a = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "m4a"
    )
    XCTAssertEqual(m4a, "episodes/5.m4a")

    let fdx = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fdx"
    )
    XCTAssertEqual(fdx, "episodes/5.fdx")
  }

  func testResolveWithUnicodeLanguageCode() {
    let template = "episodes/<language>/<episode>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "zh",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(result, "episodes/zh/5.fountain")
  }

  // MARK: - Common Production Patterns

  func testPatternLanguageFirstMultiSeason() {
    let template = "episodes/<language>/<season>/<episode>.<ext>"

    let es1 = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(es1, "episodes/es/1/5.fountain")

    let es2 = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 2,
      episode: 3,
      ext: "fountain"
    )
    XCTAssertEqual(es2, "episodes/es/2/3.fountain")

    let fr1 = EpisodePathResolver.resolve(
      template: template,
      language: "fr",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(fr1, "episodes/fr/1/5.fountain")
  }

  func testPatternSeasonFirstMultiSeason() {
    let template = "episodes/<season>/<language>/<episode>.<ext>"

    let s1es = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(s1es, "episodes/1/es/5.fountain")

    let s2es = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 2,
      episode: 3,
      ext: "fountain"
    )
    XCTAssertEqual(s2es, "episodes/2/es/3.fountain")

    let s1fr = EpisodePathResolver.resolve(
      template: template,
      language: "fr",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(s1fr, "episodes/1/fr/5.fountain")
  }

  func testPatternFlatSingleLanguage() {
    let template = "episodes/<episode>.<ext>"

    for episode in [1, 5, 10, 100] {
      let result = EpisodePathResolver.resolve(
        template: template,
        language: "en",
        season: 1,
        episode: episode,
        ext: "fountain"
      )
      XCTAssertEqual(result, "episodes/\(episode).fountain")
    }
  }

  func testPatternLanguageOnlyNoSeasons() {
    let template = "episodes/<language>/<episode>.<ext>"

    let es = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(es, "episodes/es/5.fountain")

    let fr = EpisodePathResolver.resolve(
      template: template,
      language: "fr",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(fr, "episodes/fr/5.fountain")
  }

  // MARK: - Complex Custom Patterns

  func testCustomPatternWithPrefixes() {
    let template = "content/<language>/season<season>/episode<episode>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(result, "content/es/season1/episode5.fountain")
  }

  func testCustomPatternWithUnderscores() {
    let template = "<language>_s<season>_e<episode>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(result, "es_s1_e5.fountain")
  }

  func testCustomPatternComplex() {
    let template = "productions/<language>/series_s<season>/<episode>_full.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "fr",
      season: 3,
      episode: 42,
      ext: "m4a"
    )
    XCTAssertEqual(result, "productions/fr/series_s3/42_full.m4a")
  }

  // MARK: - Unrecognized Variables (Warning Cases)

  func testUnknownVariableResolvedAsRemaining() {
    let template = "episodes/<language>/<unknown>/<episode>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    // Unknown variable remains unchanged
    XCTAssertEqual(result, "episodes/es/<unknown>/5.fountain")
  }

  func testMultipleUnknownVariablesRemaining() {
    let template = "episodes/<lang1>/<unknown>/<ep2>.<ext>"
    let result = EpisodePathResolver.resolve(
      template: template,
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    // Only known variables are replaced
    XCTAssertEqual(result, "episodes/<lang1>/<unknown>/<ep2>.fountain")
  }

  // MARK: - Empty and Nil Edge Cases

  func testEmptyTemplate() {
    let result = EpisodePathResolver.resolve(
      template: "",
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(result, "")
  }

  func testTemplateWithOnlyPath() {
    let result = EpisodePathResolver.resolve(
      template: "fixed/path/structure",
      language: "es",
      season: 1,
      episode: 5,
      ext: "fountain"
    )
    XCTAssertEqual(result, "fixed/path/structure")
  }

  func testExtractVariablesFromEmpty() {
    let variables = EpisodePathResolver.extractVariables(from: "")
    XCTAssertEqual(variables.count, 0)
  }
}

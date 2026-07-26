import AVFoundation
import XCTest
import Foundation

@testable import ProjectBrowser

/// Unit tests for the audio player's testable surface: the pure
/// ``AudioTimeFormatter`` and the safety/lifecycle guards on
/// ``AudioPlayerController``.
///
/// Historically the audio player had **zero** test coverage. These cover the
/// paths that previously crashed or misbehaved: NaN/negative duration
/// formatting, seek/toggle guards before the asset is ready, idempotent
/// teardown, and the unreadable-asset error path — without requiring a real
/// decodable audio fixture (which would be slow and flaky in CI).

// MARK: - AudioTimeFormatter

final class AudioTimeFormatterTests: XCTestCase {

  func testNonFiniteInputReturnsZero() {
    XCTAssertEqual(AudioTimeFormatter.string(from: .nan), "0:00")
    XCTAssertEqual(AudioTimeFormatter.string(from: .infinity), "0:00")
    XCTAssertEqual(AudioTimeFormatter.string(from: -.infinity), "0:00")
  }

  func testNegativeInputReturnsZero() {
    XCTAssertEqual(AudioTimeFormatter.string(from: -1), "0:00")
    XCTAssertEqual(AudioTimeFormatter.string(from: -3600), "0:00")
  }

  func testSubMinuteZeroPadsSeconds() {
    XCTAssertEqual(AudioTimeFormatter.string(from: 0), "0:00")
    XCTAssertEqual(AudioTimeFormatter.string(from: 5), "0:05")
    XCTAssertEqual(AudioTimeFormatter.string(from: 59), "0:59")
  }

  func testMinutesAndSeconds() {
    XCTAssertEqual(AudioTimeFormatter.string(from: 65), "1:05")
    XCTAssertEqual(AudioTimeFormatter.string(from: 600), "10:00")
    XCTAssertEqual(AudioTimeFormatter.string(from: 3599), "59:59")
  }

  func testHoursUseZeroPaddedMinutesAndSeconds() {
    XCTAssertEqual(AudioTimeFormatter.string(from: 3600), "1:00:00")
    XCTAssertEqual(AudioTimeFormatter.string(from: 3661), "1:01:01")
    XCTAssertEqual(AudioTimeFormatter.string(from: 45296), "12:34:56")
  }

  func testFractionalSecondsAreTruncated() {
    XCTAssertEqual(AudioTimeFormatter.string(from: 65.9), "1:05")
    XCTAssertEqual(AudioTimeFormatter.string(from: 0.99), "0:00")
  }
}

// MARK: - AudioPlayerController

@MainActor
final class AudioPlayerControllerTests: XCTestCase {

  /// A URL that does not point at any real asset. The controller kicks off its
  /// asset load on a detached `Task`, which does not run while a synchronous
  /// `@MainActor` test body holds the main actor — so for the synchronous
  /// guard tests the player is still un-initialised, which is exactly the
  /// pre-ready state we want to prove is safe.
  private var missingURL: URL {
    URL(fileURLWithPath: "/dev/null/does-not-exist.m4a")
  }

  func testFreshControllerStartsUnreadyAndEmpty() {
    let controller = AudioPlayerController(url: missingURL)
    XCTAssertFalse(controller.isReady)
    XCTAssertFalse(controller.isPlaying)
    XCTAssertNil(controller.currentTime)
    XCTAssertNil(controller.duration)
    XCTAssertNil(controller.error)
  }

  func testSeekBeforeReadyIsASafeNoOp() {
    let controller = AudioPlayerController(url: missingURL)
    controller.seek(to: 0.5)
    // Guard returns before flipping isSeeking; nothing to seek, no crash.
    XCTAssertFalse(controller.isSeeking)
  }

  func testSeekRejectsNonFiniteOrZeroDuration() {
    let controller = AudioPlayerController(url: missingURL)

    controller.duration = .nan
    controller.seek(to: 0.5)
    XCTAssertFalse(controller.isSeeking)

    controller.duration = 0
    controller.seek(to: 0.5)
    XCTAssertFalse(controller.isSeeking)

    controller.duration = .infinity
    controller.seek(to: 0.5)
    XCTAssertFalse(controller.isSeeking)
  }

  // MARK: - Scrub / playback separation
  //
  // Regression cover for the seek feedback loop: the slider used to seek in
  // response to `seekPosition` changing, so the periodic time observer's own
  // writes (10×/sec) each triggered a sample-accurate seek back to a stale
  // timestamp — audible skipping throughout playback.

  func testScrubbingStateTogglesOnlyOnChange() {
    let controller = AudioPlayerController(url: missingURL)
    XCTAssertFalse(controller.isScrubbing)

    controller.setScrubbing(true)
    XCTAssertTrue(controller.isScrubbing)

    // Redundant begins must not re-enter or flip anything.
    controller.setScrubbing(true)
    XCTAssertTrue(controller.isScrubbing)

    controller.setScrubbing(false)
    XCTAssertFalse(controller.isScrubbing)
  }

  func testEndingAScrubBeforeReadyDoesNotSeek() {
    let controller = AudioPlayerController(url: missingURL)
    controller.seekPosition = 0.75
    controller.setScrubbing(true)
    controller.setScrubbing(false)
    // The release-time seek still has to run the readiness guard.
    XCTAssertFalse(controller.isSeeking)
    XCTAssertFalse(controller.isScrubbing)
  }

  func testDisplayTimeFollowsThumbWhileScrubbingAndPlaybackOtherwise() {
    let controller = AudioPlayerController(url: missingURL)
    controller.duration = 100
    controller.currentTime = 10

    // Not scrubbing: the label reports playback position.
    XCTAssertEqual(controller.displayTime, 10)

    // Scrubbing: the label follows the thumb, so it agrees with the drag.
    controller.setScrubbing(true)
    controller.seekPosition = 0.4
    XCTAssertEqual(controller.displayTime, 40)

    controller.setScrubbing(false)
    XCTAssertEqual(controller.displayTime, 10)
  }

  func testDisplayTimeFallsBackToPlaybackOnNonFiniteDuration() {
    let controller = AudioPlayerController(url: missingURL)
    controller.currentTime = 7
    controller.duration = .nan
    controller.setScrubbing(true)
    controller.seekPosition = 0.5
    // A NaN duration must not produce a NaN label.
    XCTAssertEqual(controller.displayTime, 7)
  }

  func testTogglePlayPauseBeforeReadyIsANoOp() {
    let controller = AudioPlayerController(url: missingURL)
    controller.togglePlayPause()
    XCTAssertFalse(controller.isPlaying)
  }

  func testStopIsIdempotent() {
    let controller = AudioPlayerController(url: missingURL)
    // Two stops must not crash (no double time-observer removal) and must
    // leave the controller in a clean, un-armed state.
    controller.stop()
    controller.stop()
    XCTAssertFalse(controller.isPlaying)
    XCTAssertFalse(controller.isReady)
  }

  func testUnreadableAssetSurfacesErrorAndNeverArmsPlayback() async throws {
    // Write junk bytes to a .m4a so AVURLAsset cannot produce a usable
    // duration — exercising the real async error path end to end.
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("AudioPlayerControllerTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let fileURL = dir.appendingPathComponent("junk.m4a")
    try Data("this is not a real audio file".utf8).write(to: fileURL)

    let controller = AudioPlayerController(url: fileURL)

    // Poll (generously) for the detached asset load to fail and surface an
    // error rather than crashing or arming playback with a bogus duration.
    let deadline = Date().addingTimeInterval(5)
    while controller.error == nil, Date() < deadline {
      try await Task.sleep(nanoseconds: 50_000_000)
    }

    XCTAssertNotNil(controller.error, "An unreadable asset must surface an error")
    XCTAssertFalse(controller.isReady, "An unreadable asset must never arm playback")
  }
}

// MARK: - VTT Parser

final class VTTParserTests: XCTestCase {

  func testParseSimpleVTT() {
    let vtt = """
      WEBVTT

      00:00:00.500 --> 00:00:07.000
      Caption text line one

      00:00:14.000 --> 00:00:18.000
      Caption text line two
      """

    let cues = VTTParser.parse(content: vtt)
    XCTAssertEqual(cues.count, 2)

    XCTAssertEqual(cues[0].startTime, 0.5, accuracy: 0.001)
    XCTAssertEqual(cues[0].endTime, 7.0, accuracy: 0.001)
    XCTAssertEqual(cues[0].text, "Caption text line one")

    XCTAssertEqual(cues[1].startTime, 14.0, accuracy: 0.001)
    XCTAssertEqual(cues[1].endTime, 18.0, accuracy: 0.001)
    XCTAssertEqual(cues[1].text, "Caption text line two")
  }

  func testParseVTTWithMultilineText() {
    let vtt = """
      WEBVTT

      00:00:00.000 --> 00:00:10.000
      Line one
      Line two
      Line three
      """

    let cues = VTTParser.parse(content: vtt)
    XCTAssertEqual(cues.count, 1)
    XCTAssertEqual(cues[0].text, "Line one\nLine two\nLine three")
  }

  func testParseVTTWithHoursFormat() {
    let vtt = """
      WEBVTT

      01:00:00.500 --> 01:00:07.000
      Caption text
      """

    let cues = VTTParser.parse(content: vtt)
    XCTAssertEqual(cues.count, 1)
    XCTAssertEqual(cues[0].startTime, 3600.5, accuracy: 0.001)
    XCTAssertEqual(cues[0].endTime, 3607.0, accuracy: 0.001)
  }

  func testCueActivityCheck() {
    let cue = VTTCue(startTime: 10.0, endTime: 20.0, text: "Test")

    XCTAssertFalse(cue.isActive(at: 9.99))
    XCTAssertTrue(cue.isActive(at: 10.0))
    XCTAssertTrue(cue.isActive(at: 15.0))
    XCTAssertFalse(cue.isActive(at: 20.0))
    XCTAssertFalse(cue.isActive(at: 20.01))
  }

  func testParseVTTSkipsEmptyLines() {
    let vtt = """
      WEBVTT


      00:00:00.000 --> 00:00:05.000
      First caption


      00:00:05.000 --> 00:00:10.000
      Second caption
      """

    let cues = VTTParser.parse(content: vtt)
    XCTAssertEqual(cues.count, 2)
    XCTAssertEqual(cues[0].text, "First caption")
    XCTAssertEqual(cues[1].text, "Second caption")
  }
}

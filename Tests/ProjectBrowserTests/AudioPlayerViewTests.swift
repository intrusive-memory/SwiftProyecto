import AVFoundation
import XCTest

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

import AVFoundation
import SwiftUI

public struct AudioPlayerView: View {
  private let file: ProjectFile
  private let directoryURL: URL

  @StateObject private var controller: AudioPlayerController

  public init(file: ProjectFile, directoryURL: URL) {
    self.file = file
    self.directoryURL = directoryURL
    _controller = StateObject(
      wrappedValue: AudioPlayerController(
        url: directoryURL.appendingPathComponent(file.relativePath)
      ))
  }

  public var body: some View {
    VStack(spacing: 20) {
      Spacer()

      VStack(spacing: 12) {
        Image(systemName: "waveform")
          .font(.system(size: 48))
          .foregroundStyle(.secondary)

        Text(file.displayName)
          .font(.headline)
          .lineLimit(2)
          .multilineTextAlignment(.center)

        if let duration = controller.duration {
          Text(formatTime(duration))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding()

      Spacer()

      VStack(spacing: 12) {
        if let currentTime = controller.currentTime, let duration = controller.duration {
          VStack(spacing: 8) {
            Slider(value: $controller.seekPosition, in: 0...1)
              .onChange(of: controller.seekPosition) { oldValue, newValue in
                if !controller.isSeeking {
                  controller.seek(to: newValue)
                }
              }

            HStack {
              Text(formatTime(currentTime))
              Spacer()
              Text(formatTime(duration))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
          }
        } else {
          ProgressView()
            .frame(height: 4)
        }

        HStack(spacing: 24) {
          Button {
            controller.togglePlayPause()
          } label: {
            Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
              .font(.system(size: 24))
          }
          .buttonStyle(.plain)
          .disabled(!controller.isReady)

          Spacer()

          HStack(spacing: 12) {
            Image(systemName: "speaker.wave.2.fill")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)

            Slider(value: $controller.volume, in: 0...1)
              .frame(maxWidth: 100)

            Image(systemName: "speaker.wave.3.fill")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding()

      if let error = controller.error {
        VStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 24))
            .foregroundStyle(.red)

          Text("Playback Error")
            .font(.subheadline)
            .fontWeight(.semibold)

          Text(error)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
    // Semantic, colour-scheme-adaptive background. A hardcoded light value
    // (e.g. `Color(white: 0.95)`) leaves the adaptive `.primary`/`.secondary`
    // foregrounds invisible in dark mode.
    .background(.background)
    .navigationTitle(file.displayName)
    .onDisappear {
      controller.stop()
    }
  }

  private func formatTime(_ seconds: Double) -> String {
    AudioTimeFormatter.string(from: seconds)
  }
}

// MARK: - AudioTimeFormatter

/// Formats a duration in seconds as `m:ss` (or `h:mm:ss` once past an hour),
/// guarding against non-finite or negative input. Factored out of
/// ``AudioPlayerView`` (where it was a private method) so the formatting logic
/// can be unit-tested without standing up a view or an `AVPlayer`.
enum AudioTimeFormatter {
  static func string(from seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
      return String(format: "%d:%02d", minutes, secs)
    }
  }
}

// MARK: - AudioPlayerController

@MainActor
final class AudioPlayerController: NSObject, ObservableObject {
  nonisolated private let url: URL
  private var player: AVPlayer?
  // Observer tokens are only ever assigned/read on the main actor, but the
  // nonisolated `deinit` backstop must release them too — `nonisolated(unsafe)`
  // permits that (deinit has exclusive access) since the token types aren't
  // Sendable.
  nonisolated(unsafe) private var timeObserver: Any?
  nonisolated(unsafe) private var endObserver: NSObjectProtocol?

  @Published var isPlaying = false
  @Published var isReady = false
  @Published var currentTime: Double?
  @Published var duration: Double?
  @Published var error: String?
  @Published var seekPosition: Double = 0
  @Published var volume: Float = 1.0 {
    didSet {
      player?.volume = volume
    }
  }

  var isSeeking = false

  nonisolated init(url: URL) {
    self.url = url
    super.init()
    Task { @MainActor in
      self.setupPlayer()
    }
  }

  private func setupPlayer() {
    let asset = AVURLAsset(url: url)
    let playerItem = AVPlayerItem(asset: asset)
    player = AVPlayer(playerItem: playerItem)
    player?.volume = volume

    // Block-based observation (not selector-based): `AVPlayerItemDidPlayToEndTime`
    // can be posted on an arbitrary queue, so hop to the main actor before
    // touching @Published state rather than mutating it off-actor.
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.handlePlaybackEnded() }
    }

    Task {
      do {
        let loaded = try await asset.load(.duration).seconds
        // A non-finite or zero duration (unreadable / malformed / indefinite
        // asset) would make the seek slider build NaN CMTimes and crash on
        // drag — surface it as an error instead of arming playback.
        guard loaded.isFinite, loaded > 0 else {
          self.error = "Audio has no readable duration."
          return
        }
        self.duration = loaded
        self.isReady = true
      } catch {
        self.error = "Failed to load audio: \(error.localizedDescription)"
      }
    }

    addTimeObserver()
  }

  private func addTimeObserver() {
    guard let player else { return }

    timeObserver = player.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
      queue: .main
    ) { [weak self] time in
      DispatchQueue.main.async {
        self?.currentTime = time.seconds
        if let duration = self?.duration, duration > 0 {
          self?.seekPosition = time.seconds / duration
        }
      }
    }
  }

  func togglePlayPause() {
    guard isReady else { return }

    if isPlaying {
      player?.pause()
    } else {
      player?.play()
    }
    isPlaying.toggle()
  }

  func seek(to fraction: Double) {
    guard let player, let duration, duration.isFinite, duration > 0 else { return }

    let clamped = min(max(fraction, 0), 1)
    isSeeking = true
    let targetTime = CMTime(seconds: duration * clamped, preferredTimescale: 600)
    player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
      DispatchQueue.main.async {
        self?.isSeeking = false
      }
    }
  }

  /// Tears the player down. Idempotent: nils each resource as it is released
  /// so a second call (e.g. `onDisappear` after an explicit stop) is a no-op
  /// and never double-removes the periodic time observer.
  func stop() {
    player?.pause()
    isPlaying = false
    isReady = false

    if let timeObserver {
      player?.removeTimeObserver(timeObserver)
      self.timeObserver = nil
    }
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
      self.endObserver = nil
    }
    player = nil
  }

  private func handlePlaybackEnded() {
    isPlaying = false
    seekPosition = 0
    currentTime = 0
    player?.seek(to: .zero)
  }

  deinit {
    // Backstop for the case where `stop()` (driven by the view's onDisappear)
    // never ran — otherwise the periodic time observer and the end-of-item
    // observer leak. Removing the time observer needs the player it was
    // registered on, so both are released here together.
    if let timeObserver {
      player?.removeTimeObserver(timeObserver)
    }
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
    }
  }
}

#Preview("AudioPlayerView – Ready", traits: .fixedLayout(width: 480, height: 320)) {
  AudioPlayerView(
    file: ProjectFile(
      name: "intro.m4a",
      relativePath: "audio/intro.m4a",
      fileExtension: "m4a",
      isDirectory: false,
      modifiedDate: Date()
    ),
    directoryURL: FileManager.default.temporaryDirectory
  )
}

#Preview("AudioPlayerView – iOS", traits: .fixedLayout(width: 380, height: 500)) {
  AudioPlayerView(
    file: ProjectFile(
      name: "theme.mp3",
      relativePath: "audio/theme.mp3",
      fileExtension: "mp3",
      isDirectory: false,
      modifiedDate: Date()
    ),
    directoryURL: FileManager.default.temporaryDirectory
  )
}

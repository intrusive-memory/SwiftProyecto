import SwiftUI
import AVFoundation

public struct AudioPlayerView: View {
  private let file: ProjectFile
  private let directoryURL: URL

  @StateObject private var controller: AudioPlayerController

  public init(file: ProjectFile, directoryURL: URL) {
    self.file = file
    self.directoryURL = directoryURL
    _controller = StateObject(wrappedValue: AudioPlayerController(
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
    .background(Color(white: 0.95))
    .navigationTitle(file.displayName)
    .onDisappear {
      controller.stop()
    }
  }

  private func formatTime(_ seconds: Double) -> String {
    guard !seconds.isNaN, !seconds.isInfinite else { return "0:00" }
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
  private var timeObserver: Any?

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

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(playerItemDidReachEnd),
      name: .AVPlayerItemDidPlayToEndTime,
      object: playerItem
    )

    Task {
      do {
        let duration = try await asset.load(.duration)
        self.duration = duration.seconds
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
    guard let player, let duration else { return }

    isSeeking = true
    let targetTime = CMTime(seconds: duration * fraction, preferredTimescale: 600)
    player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
      DispatchQueue.main.async {
        self?.isSeeking = false
      }
    }
  }

  func stop() {
    player?.pause()
    isPlaying = false

    if let timeObserver {
      player?.removeTimeObserver(timeObserver)
    }

    NotificationCenter.default.removeObserver(self)
  }

  @objc private func playerItemDidReachEnd() {
    isPlaying = false
    seekPosition = 0
    currentTime = 0
    player?.seek(to: .zero)
  }

  deinit {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      NotificationCenter.default.removeObserver(self)
      if let timeObserver = self.timeObserver {
        self.player?.removeTimeObserver(timeObserver)
      }
      self.player?.pause()
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

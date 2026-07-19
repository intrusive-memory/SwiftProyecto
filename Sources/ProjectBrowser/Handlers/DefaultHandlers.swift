import SwiftUI

/// Provides default file type handlers for common file formats.
public enum DefaultHandlers {
  /// Common image file extensions: jpg, jpeg, png, gif, webp, tiff, tif, bmp, heic, heif.
  public static let imageExtensions = [
    "jpg", "jpeg", "png", "gif", "webp", "tiff", "tif", "bmp", "heic", "heif",
  ]

  /// Common audio file extensions: mp3, m4a, aac, wav, flac, ogg, opus, wma, alac, aiff.
  public static let audioExtensions = [
    "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "wma", "alac", "aiff",
  ]

  /// Creates an image file handler for the given directory.
  ///
  /// Returns a `FileTypeHandler` that renders image files via ``ImageContentView``.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let imageHandler = DefaultHandlers.imageHandler(directoryURL: projectURL)
  /// handlers.append(imageHandler)
  /// ```
  ///
  /// - Parameter directoryURL: The project directory containing the image file.
  /// - Returns: A `FileTypeHandler` for image files.
  public static func imageHandler(for extension: String, directoryURL: URL) -> FileTypeHandler {
    FileTypeHandler(fileExtension: `extension`) { file in
      AnyView(ImageContentView(file: file, directoryURL: directoryURL))
    }
  }

  /// Creates a dictionary of default image handlers for all common image extensions.
  ///
  /// ## Example
  ///
  /// ```swift
  /// var handlers = DefaultHandlers.imageHandlers(directoryURL: projectURL)
  /// handlers["fountain"] = { file in AnyView(ScreenplayView(file: file)) }
  ///
  /// ProjectWindow(
  ///   directoryURL: projectURL,
  ///   handlers: handlers
  /// )
  /// ```
  ///
  /// - Parameter directoryURL: The project directory containing image files.
  /// - Returns: A dictionary mapping image extensions to their handlers.
  public static func imageHandlers(directoryURL: URL) -> [String: (ProjectFile) -> AnyView] {
    var handlers: [String: (ProjectFile) -> AnyView] = [:]
    for ext in imageExtensions {
      let handler = imageHandler(for: ext, directoryURL: directoryURL)
      handlers[ext] = handler.viewBuilder
    }
    return handlers
  }

  /// Creates an audio file handler for the given directory.
  ///
  /// Returns a `FileTypeHandler` that renders audio files via ``AudioPlayerView``.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let audioHandler = DefaultHandlers.audioHandler(for: "mp3", directoryURL: projectURL)
  /// handlers["mp3"] = audioHandler.viewBuilder
  /// ```
  ///
  /// - Parameters:
  ///   - extension: The audio file extension (without the leading dot).
  ///   - directoryURL: The project directory containing the audio file.
  /// - Returns: A `FileTypeHandler` for audio files.
  public static func audioHandler(for extension: String, directoryURL: URL) -> FileTypeHandler {
    FileTypeHandler(fileExtension: `extension`) { file in
      AnyView(AudioPlayerView(file: file, directoryURL: directoryURL))
    }
  }

  /// Creates a dictionary of default audio handlers for all common audio extensions.
  ///
  /// ## Example
  ///
  /// ```swift
  /// var handlers = DefaultHandlers.audioHandlers(directoryURL: projectURL)
  /// handlers.merge(DefaultHandlers.imageHandlers(directoryURL: projectURL)) { _, new in new }
  ///
  /// ProjectWindow(
  ///   directoryURL: projectURL,
  ///   handlers: handlers
  /// )
  /// ```
  ///
  /// - Parameter directoryURL: The project directory containing audio files.
  /// - Returns: A dictionary mapping audio extensions to their handlers.
  public static func audioHandlers(directoryURL: URL) -> [String: (ProjectFile) -> AnyView] {
    var handlers: [String: (ProjectFile) -> AnyView] = [:]
    for ext in audioExtensions {
      let handler = audioHandler(for: ext, directoryURL: directoryURL)
      handlers[ext] = handler.viewBuilder
    }
    return handlers
  }

  /// Creates a combined dictionary of all default handlers (image + audio).
  ///
  /// ## Example
  ///
  /// ```swift
  /// var handlers = DefaultHandlers.allHandlers(directoryURL: projectURL)
  /// handlers["fountain"] = { file in AnyView(ScreenplayView(file: file)) }
  ///
  /// ProjectWindow(
  ///   directoryURL: projectURL,
  ///   handlers: handlers
  /// )
  /// ```
  ///
  /// - Parameter directoryURL: The project directory containing media files.
  /// - Returns: A dictionary mapping image and audio extensions to their handlers.
  public static func allHandlers(directoryURL: URL) -> [String: (ProjectFile) -> AnyView] {
    var handlers = imageHandlers(directoryURL: directoryURL)
    handlers.merge(audioHandlers(directoryURL: directoryURL)) { _, new in new }
    return handlers
  }
}

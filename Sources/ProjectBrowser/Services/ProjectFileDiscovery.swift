import Foundation

/// Recursively scans a directory and builds the flat list of ``ProjectFile``
/// entries used by `ProjectWindow`.
///
/// `ProjectFileDiscovery` only inspects filesystem metadata — name,
/// extension, directory-ness, modification date. It never reads file
/// contents; those are loaded lazily elsewhere via a consumer's
/// `FileLoaderCallback`.
///
/// The returned array is a **flattened, depth-first** walk of the directory
/// tree: within each directory, entries are split into folders and files,
/// each group sorted alphabetically (case-insensitive, locale-aware), with
/// folders first. Every folder is immediately followed by its own
/// recursively-flattened children before the walk moves on to the folder's
/// next sibling. This keeps a directory's contents grouped together while
/// still producing a single flat array.
///
/// ## Example
///
/// ```swift
/// let files = try await ProjectFileDiscovery.discover(at: projectRoot)
/// ```
public enum ProjectFileDiscovery {

  /// Filesystem entry names that are always excluded from discovery,
  /// regardless of where they appear in the tree.
  static let ignoredNames: Set<String> = [
    ".git",
    ".build",
    "node_modules",
    ".swiftpm",
    ".DS_Store",
  ]

  /// Filesystem entry name suffixes that are always excluded from
  /// discovery. Matches apply to the entry's last path component, so an
  /// entire `.xcodeproj` bundle (and everything inside it) is skipped
  /// without ever being descended into.
  static let ignoredSuffixes: [String] = [
    ".xcodeproj",
    ".xcworkspace",
    ".swiftdeps",
  ]

  /// Directory extensions (without the leading dot) that discovery presents
  /// as **package bundles** by default: a single leaf ``ProjectFile`` with
  /// ``ProjectFile/isBundle`` set, never descended into.
  ///
  /// - `dossier`: a Personaje character dossier (`characters/SHANE.dossier/`).
  /// - `textbundle`: the TextBundle package format.
  ///
  /// Independently of this list, any directory the filesystem itself marks
  /// as a package (`URLResourceValues.isPackage`, which macOS sets for
  /// directories whose extension an installed app has registered as a
  /// package type) is also treated as a bundle. Pass your own set to
  /// ``discover(at:bundleExtensions:)`` to widen or narrow the default.
  public static let defaultBundleExtensions: Set<String> = [
    "dossier",
    "textbundle",
  ]

  /// Recursively scans `rootURL` and returns every file and directory found
  /// beneath it, excluding default-ignored paths and symlinks.
  ///
  /// Directories whose extension is in `bundleExtensions`, or that the
  /// filesystem reports as packages, are returned as one leaf entry each —
  /// ``ProjectFile/isBundle`` is `true`, ``ProjectFile/isDirectory`` is
  /// `false`, the extension is kept — and their contents are not scanned.
  /// They sort with the files at their level, not with the folders.
  ///
  /// - Parameters:
  ///   - rootURL: The directory to scan. Must exist and be a directory;
  ///     `rootURL` itself is not included in the result, only its contents.
  ///   - bundleExtensions: Directory extensions to present as bundles.
  ///     Defaults to ``defaultBundleExtensions``; pass `[]` to rely on the
  ///     filesystem's package flag alone. Matching ignores case.
  /// - Returns: A flat array of ``ProjectFile``, directories before files at
  ///   each level, alphabetical within each group, in depth-first order.
  /// - Throws: Any error `FileManager` throws while reading `rootURL`
  ///   itself (for example, if it does not exist or is not a directory).
  public static func discover(
    at rootURL: URL,
    bundleExtensions: Set<String> = defaultBundleExtensions
  ) async throws -> [ProjectFile] {
    let standardizedRoot = rootURL.standardizedFileURL
    let normalizedBundleExtensions = Set(bundleExtensions.map { $0.lowercased() })
    return try scanDirectory(
      at: standardizedRoot, root: standardizedRoot, bundleExtensions: normalizedBundleExtensions)
  }

  /// Whether a directory at `url` should be presented as a package bundle,
  /// given the filesystem's own package flag and the configured extensions.
  ///
  /// Only directories can be bundles; a plain file whose extension happens
  /// to be in `bundleExtensions` is still a file.
  static func isBundle(
    _ url: URL, values: URLResourceValues, bundleExtensions: Set<String>
  ) -> Bool {
    guard values.isDirectory == true else { return false }
    if values.isPackage == true { return true }
    let ext = url.pathExtension.lowercased()
    return !ext.isEmpty && bundleExtensions.contains(ext)
  }

  // MARK: - Private

  private static let resourceKeys: [URLResourceKey] = [
    .isDirectoryKey,
    .isPackageKey,
    .isSymbolicLinkKey,
    .contentModificationDateKey,
    .fileSizeKey,
  ]
  private static let resourceKeySet = Set(resourceKeys)

  /// Scans the immediate contents of `directoryURL`, then recurses into any
  /// subdirectories found. `root` is threaded through unchanged so relative
  /// paths are always computed against the original discovery root.
  ///
  /// - Note: Failures while listing a *subdirectory* (permissions, races
  ///   with concurrent deletion, etc.) are swallowed and treated as "no
  ///   children" so one unreadable folder doesn't abort the whole scan.
  ///   Failures reading `rootURL` itself are not swallowed by ``discover``.
  private static func scanDirectory(
    at directoryURL: URL, root: URL, bundleExtensions: Set<String>
  ) throws -> [ProjectFile] {
    let fileManager = FileManager.default

    let children = try fileManager.contentsOfDirectory(
      at: directoryURL,
      includingPropertiesForKeys: resourceKeys,
      options: []
    )

    var directoryEntries: [(url: URL, values: URLResourceValues)] = []
    var fileEntries: [(url: URL, values: URLResourceValues, isBundle: Bool)] = []

    for childURL in children {
      guard let values = try? childURL.resourceValues(forKeys: resourceKeySet) else {
        continue
      }

      // Never follow or include symlinks.
      if values.isSymbolicLink == true {
        continue
      }

      if isIgnored(childURL) {
        continue
      }

      if isBundle(childURL, values: values, bundleExtensions: bundleExtensions) {
        // A package is a leaf: it sorts with the files and is never scanned.
        fileEntries.append((childURL, values, true))
      } else if values.isDirectory == true {
        directoryEntries.append((childURL, values))
      } else {
        fileEntries.append((childURL, values, false))
      }
    }

    directoryEntries.sort { orderedAscending($0.url, $1.url) }
    fileEntries.sort { orderedAscending($0.url, $1.url) }

    var results: [ProjectFile] = []
    results.reserveCapacity(directoryEntries.count + fileEntries.count)

    for (childURL, values) in directoryEntries {
      results.append(
        makeProjectFile(url: childURL, values: values, root: root, isDirectory: true))
      if let childResults = try? scanDirectory(
        at: childURL, root: root, bundleExtensions: bundleExtensions)
      {
        results.append(contentsOf: childResults)
      }
    }

    for (childURL, values, isBundle) in fileEntries {
      results.append(
        makeProjectFile(
          url: childURL, values: values, root: root, isDirectory: false, isBundle: isBundle))
    }

    return results
  }

  private static func orderedAscending(_ lhs: URL, _ rhs: URL) -> Bool {
    lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
  }

  private static func isIgnored(_ url: URL) -> Bool {
    let name = url.lastPathComponent
    if ignoredNames.contains(name) {
      return true
    }
    for suffix in ignoredSuffixes where name.hasSuffix(suffix) {
      return true
    }
    return false
  }

  private static func makeProjectFile(
    url: URL,
    values: URLResourceValues,
    root: URL,
    isDirectory: Bool,
    isBundle: Bool = false
  ) -> ProjectFile {
    let name = url.lastPathComponent
    let relative = relativePath(of: url, relativeTo: root)
    let ext = isDirectory ? nil : (url.pathExtension.isEmpty ? nil : url.pathExtension)
    let modified = values.contentModificationDate ?? Date(timeIntervalSince1970: 0)
    // A bundle is a directory on disk; `fileSize` is meaningless for it.
    let size = (isDirectory || isBundle) ? nil : values.fileSize.map(Int64.init)

    return ProjectFile(
      name: name,
      relativePath: relative,
      fileExtension: ext,
      isDirectory: isDirectory,
      modifiedDate: modified,
      fileSize: size,
      isBundle: isBundle
    )
  }

  private static func relativePath(of url: URL, relativeTo root: URL) -> String {
    let rootPath = root.standardizedFileURL.path
    let fullPath = url.standardizedFileURL.path

    guard fullPath.hasPrefix(rootPath) else {
      return url.lastPathComponent
    }

    var relative = String(fullPath.dropFirst(rootPath.count))
    if relative.hasPrefix("/") {
      relative.removeFirst()
    }
    return relative
  }
}

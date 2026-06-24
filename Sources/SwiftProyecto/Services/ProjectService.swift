import Foundation
import SwiftData

/// Service for managing project lifecycle, file discovery, and security-scoped access.
///
/// ProjectService handles:
/// - Creating new projects with PROJECT.md manifest
/// - Opening existing projects and loading metadata
/// - Discovering files in project folders
/// - Synchronizing file state with filesystem
/// - Providing security-scoped URLs for file access
///
/// ## Usage
///
/// ```swift
/// let service = ProjectService(modelContext: context)
///
/// // Create a new project
/// let project = try await service.createProject(
///     at: projectURL,
///     title: "My Series",
///     author: "Jane Showrunner"
/// )
///
/// // Discover files in project folder
/// try service.discoverFiles(for: project)
///
/// // Get secure URL for a file (for parsing by the app)
/// let url = try service.getSecureURL(for: fileReference, in: project)
/// ```
@MainActor
public final class ProjectService {

  // MARK: - Properties

  private let modelContext: ModelContext
  private let fileManager: FileManager

  // MARK: - Errors

  public enum ProjectError: LocalizedError {
    case projectAlreadyExists(URL)
    case projectFolderNotFound(URL)
    case projectManifestNotFound(URL)
    case projectManifestInvalid(String)
    case fileNotFound(URL)
    case bookmarkCreationFailed(Error)
    case bookmarkResolutionFailed(Error)
    case securityScopedAccessFailed(URL)
    case noBookmarkData
    case saveError(Error)

    public var errorDescription: String? {
      switch self {
      case .projectAlreadyExists(let url):
        return "A project already exists at \(url.path)"
      case .projectFolderNotFound(let url):
        return "Project folder not found at \(url.path)"
      case .projectManifestNotFound(let url):
        return "PROJECT.md not found in \(url.path)"
      case .projectManifestInvalid(let reason):
        return "Invalid PROJECT.md: \(reason)"
      case .fileNotFound(let url):
        return "File not found at \(url.path)"
      case .bookmarkCreationFailed(let error):
        return "Failed to create security-scoped bookmark: \(error.localizedDescription)"
      case .bookmarkResolutionFailed(let error):
        return "Failed to resolve security-scoped bookmark: \(error.localizedDescription)"
      case .securityScopedAccessFailed(let url):
        return "Failed to start accessing security-scoped resource at \(url.path)"
      case .noBookmarkData:
        return "No security-scoped bookmark data available for project"
      case .saveError(let error):
        return "Failed to save to SwiftData: \(error.localizedDescription)"
      }
    }
  }

  // MARK: - Initialization

  public init(modelContext: ModelContext) {
    self.modelContext = modelContext
    self.fileManager = .default
  }

  // MARK: - Security-Scoped Access Helpers

  /// Performs an operation with security-scoped access to the project folder.
  ///
  /// This method uses `BookmarkManager` to handle bookmark resolution,
  /// stale bookmark recreation, and security-scoped resource access.
  ///
  /// - Parameters:
  ///   - project: The project whose folder to access
  ///   - operation: The operation to perform with the folder URL
  /// - Returns: The result of the operation
  /// - Throws: ProjectError if bookmark resolution or access fails
  private func withSecurityScopedAccess<T>(
    to project: ProjectModel,
    operation: (URL) throws -> T
  ) throws -> T {
    guard var bookmarkData = project.sourceBookmarkData else {
      throw ProjectError.noBookmarkData
    }

    do {
      // Resolve and refresh bookmark if stale
      let folderURL = try BookmarkManager.refreshIfNeeded(&bookmarkData)

      // Update bookmark if it was refreshed
      if bookmarkData != project.sourceBookmarkData {
        project.sourceBookmarkData = bookmarkData
        try modelContext.save()
      }

      // Execute operation with security-scoped access
      return try BookmarkManager.withAccess(
        folderURL, bookmarkData: bookmarkData, operation: operation)

    } catch let error as BookmarkManager.BookmarkError {
      // Map BookmarkManager errors to ProjectManager errors
      switch error {
      case .resolutionFailed(let underlyingError):
        throw ProjectError.bookmarkResolutionFailed(underlyingError)
      case .creationFailed(let underlyingError):
        throw ProjectError.bookmarkCreationFailed(underlyingError)
      case .accessDenied:
        // Get URL for error message
        if let url = try? BookmarkManager.resolveBookmark(bookmarkData).url {
          throw ProjectError.securityScopedAccessFailed(url)
        }
        throw error
      default:
        throw error
      }
    }
  }

  /// Async version of withSecurityScopedAccess for async operations.
  private func withSecurityScopedAccess<T>(
    to project: ProjectModel,
    operation: (URL) async throws -> T
  ) async throws -> T {
    guard var bookmarkData = project.sourceBookmarkData else {
      throw ProjectError.noBookmarkData
    }

    do {
      // Resolve and refresh bookmark if stale
      let folderURL = try BookmarkManager.refreshIfNeeded(&bookmarkData)

      // Update bookmark if it was refreshed
      if bookmarkData != project.sourceBookmarkData {
        project.sourceBookmarkData = bookmarkData
        try modelContext.save()
      }

      // Execute operation with security-scoped access
      // Note: Manual implementation to avoid Swift 6 concurrency issues with nonisolated closures
      #if os(macOS)
        guard folderURL.startAccessingSecurityScopedResource() else {
          throw ProjectError.securityScopedAccessFailed(folderURL)
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }
      #endif

      return try await operation(folderURL)

    } catch let error as BookmarkManager.BookmarkError {
      // Map BookmarkManager errors to ProjectManager errors
      switch error {
      case .resolutionFailed(let underlyingError):
        throw ProjectError.bookmarkResolutionFailed(underlyingError)
      case .creationFailed(let underlyingError):
        throw ProjectError.bookmarkCreationFailed(underlyingError)
      case .accessDenied:
        // Get URL for error message
        if let url = try? BookmarkManager.resolveBookmark(bookmarkData).url {
          throw ProjectError.securityScopedAccessFailed(url)
        }
        throw error
      default:
        throw error
      }
    }
  }

  // MARK: - Project Creation

  /// Creates a new project folder with PROJECT.md manifest.
  ///
  /// - Parameters:
  ///   - folderURL: The folder where the project should be created
  ///   - title: Project title
  ///   - author: Project author
  ///   - description: Optional project description
  ///   - season: Optional season number
  ///   - episodes: Optional episode count
  ///   - genre: Optional genre
  ///   - tags: Optional tags array
  /// - Returns: The created ProjectModel
  /// - Throws: ProjectError if creation fails
  public func createProject(
    at folderURL: URL,
    title: String,
    author: String,
    description: String? = nil,
    season: Int? = nil,
    episodes: Int? = nil,
    genre: String? = nil,
    tags: [String]? = nil
  ) throws -> ProjectModel {
    // Use BookmarkManager for security-scoped access
    let bookmarkData: Data
    do {
      bookmarkData = try BookmarkManager.withAccess(folderURL) { url in
        // Check if folder already exists
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
          if isDirectory.boolValue {
            // Folder exists - check if it already has PROJECT.md
            let manifestURL = url.appendingPathComponent("PROJECT.md")
            if fileManager.fileExists(atPath: manifestURL.path) {
              throw ProjectError.projectAlreadyExists(url)
            }
          } else {
            throw ProjectError.projectAlreadyExists(url)
          }
        } else {
          // Create project folder
          try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }

        // Create PROJECT.md front matter
        let frontMatter = ProjectFrontMatter(
          type: "project",
          title: title,
          author: author,
          created: Date(),
          description: description,
          season: season,
          episodes: episodes,
          genre: genre,
          tags: tags
        )

        // Generate PROJECT.md content
        let parser = ProjectMarkdownParser()
        let normalizedFrontMatter = frontMatter.normalizingPaths(relativeTo: url)
        let markdownContent = parser.generate(frontMatter: normalizedFrontMatter, body: "")

        // Write PROJECT.md to disk
        let manifestURL = url.appendingPathComponent("PROJECT.md")
        try markdownContent.write(to: manifestURL, atomically: true, encoding: .utf8)

        // Create and return security-scoped bookmark
        return try BookmarkManager.createBookmark(for: url)
      }
    } catch let error as BookmarkManager.BookmarkError {
      switch error {
      case .creationFailed(let underlyingError):
        throw ProjectError.bookmarkCreationFailed(underlyingError)
      case .accessDenied:
        throw ProjectError.securityScopedAccessFailed(folderURL)
      default:
        throw error
      }
    }

    // Create ProjectModel
    let project = ProjectModel(
      title: title,
      author: author,
      created: Date(),
      projectDescription: description,
      season: season,
      episodes: episodes,
      genre: genre,
      tags: tags,
      sourceType: .directory,
      sourceName: folderURL.lastPathComponent,
      sourceRootURL: folderURL.standardized.absoluteString,
      sourceBookmarkData: bookmarkData,
      lastSyncDate: Date(),
      projectMarkdownContent: ""
    )

    // Save to SwiftData
    modelContext.insert(project)
    do {
      try modelContext.save()
    } catch {
      throw ProjectError.saveError(error)
    }

    return project
  }

  // MARK: - Project Opening

  /// Opens a project folder, creating PROJECT.md if it doesn't exist.
  ///
  /// If PROJECT.md doesn't exist, it will be created with the folder name as the title.
  /// If the project already exists in SwiftData, the existing project is returned.
  ///
  /// - Parameter folderURL: The project folder (may or may not contain PROJECT.md)
  /// - Returns: The opened ProjectModel (or existing if already in SwiftData)
  /// - Throws: ProjectError if opening fails
  public func openProject(at folderURL: URL) throws -> ProjectModel {
    // Verify folder exists
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw ProjectError.projectFolderNotFound(folderURL)
    }

    // Check if project already exists in SwiftData
    let descriptor = FetchDescriptor<ProjectModel>()
    let existingProjects = try modelContext.fetch(descriptor)
    let folderURLString = folderURL.standardized.absoluteString
    if let existing = existingProjects.first(where: { $0.sourceRootURL == folderURLString }) {
      return existing
    }

    // Check if PROJECT.md exists
    let manifestURL = folderURL.appendingPathComponent("PROJECT.md")
    let manifestExists = fileManager.fileExists(atPath: manifestURL.path)

    // If PROJECT.md doesn't exist, create it with folder name as title
    if !manifestExists {
      let folderName = folderURL.lastPathComponent
      // Use system user name, or "Unknown" if unavailable
      let authorName = NSFullUserName().isEmpty ? "Unknown" : NSFullUserName()
      let frontMatter = ProjectFrontMatter(
        type: "project",
        title: folderName,
        author: authorName,
        created: Date(),
        description: nil,
        season: nil,
        episodes: nil,
        genre: nil,
        tags: nil
      )

      // Generate PROJECT.md content
      let parser = ProjectMarkdownParser()
      let normalizedFrontMatter = frontMatter.normalizingPaths(relativeTo: folderURL)
      let markdownContent = parser.generate(frontMatter: normalizedFrontMatter, body: "")

      // Write PROJECT.md to disk
      do {
        try markdownContent.write(to: manifestURL, atomically: true, encoding: .utf8)
      } catch {
        throw ProjectError.saveError(error)
      }
    }

    // Parse PROJECT.md (now guaranteed to exist)
    let parser = ProjectMarkdownParser()
    let (frontMatter, body): (ProjectFrontMatter, String)
    do {
      (frontMatter, body) = try parser.parse(fileURL: manifestURL)
    } catch {
      throw ProjectError.projectManifestInvalid(error.localizedDescription)
    }

    // Create security-scoped bookmark using BookmarkManager
    let bookmarkData: Data
    do {
      bookmarkData = try BookmarkManager.createBookmark(for: folderURL)
    } catch let error as BookmarkManager.BookmarkError {
      switch error {
      case .creationFailed(let underlyingError):
        throw ProjectError.bookmarkCreationFailed(underlyingError)
      default:
        throw error
      }
    }

    // Create ProjectModel
    let project = ProjectModel(
      title: frontMatter.title,
      author: frontMatter.author,
      created: frontMatter.created,
      projectDescription: frontMatter.description,
      season: frontMatter.season,
      episodes: frontMatter.episodes,
      genre: frontMatter.genre,
      tags: frontMatter.tags,
      sourceType: .directory,
      sourceName: folderURL.lastPathComponent,
      sourceRootURL: folderURL.standardized.absoluteString,
      sourceBookmarkData: bookmarkData,
      lastSyncDate: nil,
      projectMarkdownContent: body
    )

    // Save to SwiftData
    modelContext.insert(project)
    do {
      try modelContext.save()
    } catch {
      throw ProjectError.saveError(error)
    }

    return project
  }

  // MARK: - File Discovery

  /// Discovers files in the project folder.
  ///
  /// - Parameters:
  ///   - project: The project to discover files for
  ///   - allowedExtensions: Optional array of file extensions to filter by (e.g., ["fountain", "fdx"]). If nil, discovers ALL files.
  /// - Throws: ProjectError if discovery fails
  public func discoverFiles(for project: ProjectModel, allowedExtensions: [String]? = nil)
    async throws
  {
    // Get FileSource from project
    guard let fileSource = project.fileSource() else {
      throw ProjectError.noBookmarkData
    }

    // Delegate to FileSource for discovery
    let allFiles = try await fileSource.discoverFiles()

    // Filter by allowed extensions if provided
    let discoveredFiles: [DiscoveredFile]
    if let allowedExtensions = allowedExtensions {
      discoveredFiles = allFiles.filter { file in
        allowedExtensions.contains(file.fileExtension.lowercased())
      }
    } else {
      discoveredFiles = allFiles
    }

    // Track discovered paths for cleanup
    let discoveredPaths = Set(discoveredFiles.map { $0.relativePath })

    // Create or update file references
    for discoveredFile in discoveredFiles {
      // Check if reference already exists
      if let existing = project.fileReference(atPath: discoveredFile.relativePath) {
        // Update modification date
        existing.lastKnownModificationDate = discoveredFile.modificationDate
      } else {
        // Create new reference
        let fileRef = ProjectFileReference(
          relativePath: discoveredFile.relativePath,
          filename: discoveredFile.filename,
          fileExtension: discoveredFile.fileExtension,
          lastKnownModificationDate: discoveredFile.modificationDate
        )
        modelContext.insert(fileRef)
        project.fileReferences.append(fileRef)
      }
    }

    // Remove file references for files that no longer exist
    let referencesToRemove = project.fileReferences.filter {
      !discoveredPaths.contains($0.relativePath)
    }
    for fileRef in referencesToRemove {
      project.fileReferences.removeAll { $0.id == fileRef.id }
      modelContext.delete(fileRef)
    }

    // Update last sync date
    project.lastSyncDate = Date()

    // Save changes
    do {
      try modelContext.save()
    } catch {
      throw ProjectError.saveError(error)
    }
  }

  // MARK: - Bookmark Management

  /// Gets a security-scoped URL for a file reference.
  ///
  /// This method tries file-level bookmark first, then falls back to
  /// project bookmark + relative path construction.
  ///
  /// - Parameters:
  ///   - fileReference: The file reference to get URL for
  ///   - project: The project containing the file
  /// - Returns: Security-scoped URL for the file
  /// - Throws: ProjectError if URL cannot be resolved
  public func getSecureURL(
    for fileReference: ProjectFileReference,
    in project: ProjectModel
  ) throws -> URL {
    // Try file-level bookmark first
    if let fileBookmark = fileReference.bookmarkData {
      do {
        let result = try BookmarkManager.resolveBookmark(fileBookmark)
        return result.url
      } catch {
        // File bookmark stale or invalid, fall through to project bookmark
      }
    }

    // Fall back to project bookmark + relative path
    guard let projectBookmark = project.sourceBookmarkData else {
      throw ProjectError.noBookmarkData
    }

    do {
      let result = try BookmarkManager.resolveBookmark(projectBookmark)
      let projectURL = result.url
      return projectURL.appendingPathComponent(fileReference.relativePath)
    } catch {
      throw ProjectError.bookmarkResolutionFailed(error)
    }
  }

  /// Refreshes a stale file bookmark.
  ///
  /// - Parameters:
  ///   - fileReference: The file reference whose bookmark to refresh
  ///   - project: The project containing the file
  /// - Throws: ProjectError if refresh fails
  public func refreshBookmark(
    for fileReference: ProjectFileReference,
    in project: ProjectModel
  ) throws {
    let url = try getSecureURL(for: fileReference, in: project)

    do {
      let newBookmark = try BookmarkManager.createBookmark(for: url)
      fileReference.bookmarkData = newBookmark
      try modelContext.save()
    } catch {
      throw ProjectError.bookmarkCreationFailed(error)
    }
  }

  /// Creates a security-scoped bookmark for a specific file.
  ///
  /// - Parameters:
  ///   - fileReference: The file reference to create bookmark for
  ///   - project: The project containing the file
  /// - Throws: ProjectError if bookmark creation fails
  public func createFileBookmark(
    for fileReference: ProjectFileReference,
    in project: ProjectModel
  ) throws {
    let url = try getSecureURL(for: fileReference, in: project)

    do {
      let bookmark = try BookmarkManager.createBookmark(for: url)
      fileReference.bookmarkData = bookmark
      try modelContext.save()
    } catch {
      throw ProjectError.bookmarkCreationFailed(error)
    }
  }

  // MARK: - Synchronization

  /// Synchronizes project file references with filesystem.
  ///
  /// This is an alias for `discoverFiles` for semantic clarity.
  ///
  /// - Parameter project: The project to synchronize
  /// - Throws: ProjectError if synchronization fails
  public func syncProject(_ project: ProjectModel) async throws {
    try await discoverFiles(for: project)
  }

}

// MARK: - Cast List Discovery

extension ProjectService {
  /// Discover characters from .fountain files in project directory.
  ///
  /// Parses all .fountain files in the project and extracts unique CHARACTER elements
  /// to build a cast list. Actor names and voice URIs are left empty for manual entry.
  ///
  /// - Parameter project: The project to discover characters in
  /// - Returns: Array of CastMember with discovered characters
  /// - Throws: ProjectError if discovery fails
  ///
  /// ## Example
  /// ```swift
  /// let castList = try await projectService.discoverCastList(for: project)
  /// // Returns: [CastMember(character: "NARRATOR"), CastMember(character: "LAO TZU")]
  /// ```
  ///
  /// ## Merging with Existing Cast
  ///
  /// This method does NOT merge with existing cast lists. To preserve user-entered
  /// actor names and voice URIs, merge manually:
  ///
  /// ```swift
  /// let discovered = try await projectService.discoverCastList(for: project)
  /// let existing = frontMatter.cast ?? []
  /// let merged = mergeExistingCast(discovered: discovered, existing: existing)
  /// ```
  public func discoverCastList(for project: ProjectModel) async throws -> [CastMember] {
    // Get all .fountain files in project
    let fountainFiles = project.fileReferences.filter { $0.fileExtension == "fountain" }

    guard !fountainFiles.isEmpty else {
      return []
    }

    var discoveredCharacters = Set<String>()

    // Parse each .fountain file for CHARACTER elements
    for fileRef in fountainFiles {
      let fileURL = try getSecureURL(for: fileRef, in: project)

      do {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let characters = extractCharacters(from: content)
        discoveredCharacters.formUnion(characters)
      } catch {
        // Skip files that can't be read
        continue
      }
    }

    // Convert to sorted CastMember array
    return
      discoveredCharacters
      .sorted()
      .map { CastMember(character: $0) }
  }

  /// Extract CHARACTER elements from .fountain file content.
  ///
  /// Uses a simple line-based parser to find character names. A line is considered
  /// a character if it:
  /// - Is all uppercase (with optional parenthetical)
  /// - Is not a transition (doesn't end with TO:)
  /// - Is not scene heading (doesn't start with INT/EXT/EST)
  /// - Is not empty or whitespace only
  ///
  /// - Parameter content: The .fountain file content
  /// - Returns: Set of unique character names
  private func extractCharacters(from content: String) -> Set<String> {
    var characters = Set<String>()
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      // Skip empty lines
      guard !trimmed.isEmpty else { continue }

      // CHARACTER lines are typically all uppercase
      // Remove parentheticals like "(CONT'D)" or "(V.O.)"
      let withoutParenthetical = trimmed.replacingOccurrences(
        of: "\\s*\\([^)]+\\)",
        with: "",
        options: .regularExpression
      ).trimmingCharacters(in: .whitespaces)

      // Must be all uppercase
      guard withoutParenthetical == withoutParenthetical.uppercased() else { continue }

      // Skip transitions (END WITH "TO:")
      guard !withoutParenthetical.hasSuffix("TO:") else { continue }

      // Skip scene headings
      guard !withoutParenthetical.hasPrefix("INT."),
        !withoutParenthetical.hasPrefix("EXT."),
        !withoutParenthetical.hasPrefix("EST."),
        !withoutParenthetical.hasPrefix("INT/EXT")
      else { continue }

      // Skip lines that are likely action (contain lowercase)
      guard trimmed == trimmed.uppercased() else { continue }

      // This is likely a character name
      characters.insert(withoutParenthetical)
    }

    return characters
  }
}

// MARK: - Cast List Merging Helper

extension ProjectService {
  /// Merge discovered characters with existing cast, preserving user edits.
  ///
  /// - Parameters:
  ///   - discovered: Newly discovered characters from .fountain files
  ///   - existing: Existing cast list from PROJECT.md
  /// - Returns: Merged cast list with preserved actor/voice data
  ///
  /// ## Merge Strategy
  ///
  /// - Characters in both lists: Keep existing actor/voices
  /// - Characters only in discovered: Add as new (empty actor/voices)
  /// - Characters only in existing: Keep (user may have manually added)
  public func mergeCastLists(discovered: [CastMember], existing: [CastMember]) -> [CastMember] {
    var merged = [String: CastMember]()

    // Start with existing cast (preserves user edits)
    for member in existing {
      merged[member.character] = member
    }

    // Add new characters from discovered
    for member in discovered {
      if merged[member.character] == nil {
        merged[member.character] = member
      }
    }

    // Return sorted by character name
    return merged.values.sorted { $0.character < $1.character }
  }

  // MARK: - Directory Scanning and Pattern Recognition

  /// Scans a project directory and recognizes its organizational structure.
  ///
  /// This method recursively scans the given directory to detect how episodes are organized,
  /// identifying:
  /// - Language codes in directory names (ISO 639-1)
  /// - Season patterns (season-1, s1, 1, etc.)
  /// - File types present (*.fountain, *.fdx, *.highland, etc.)
  /// - Audio output directories
  /// - Voice configuration files
  ///
  /// Based on the scan, it classifies the structure as one of:
  /// - **languageFirstMultiSeason**: `lang/season/*.fountain`
  /// - **singleLanguageMultiSeason**: `season/*.fountain`
  /// - **languageOnly**: `lang/*.fountain`
  /// - **flat**: `*.fountain`
  /// - **unknown**: Unrecognized pattern
  ///
  /// ## Example
  ///
  /// ```swift
  /// let structure = ProjectService.scanAndRecognize(at: projectURL)
  /// switch structure.recognizedPattern {
  /// case .languageFirstMultiSeason(let langs, let seasons):
  ///   print("Found \(langs.count) languages and \(seasons.count) seasons")
  /// default:
  ///   print("Pattern: \(structure.recognizedPattern.description)")
  /// }
  /// ```
  ///
  /// - Parameter rootURL: The root directory to scan
  /// - Returns: A ProjectStructure describing the detected organization
  public nonisolated static func scanAndRecognize(at rootURL: URL) -> ProjectStructure {
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: rootURL.path) else {
      return ProjectStructure(rootURL: rootURL, recognizedPattern: .unknown)
    }

    var directoryMap: [String: [Int]] = [:]
    var filePatterns: Set<String> = []
    var audioDirectories: Set<String> = []
    var voiceFiles: Set<String> = []

    // Recursively scan the directory tree
    scanDirectory(
      at: rootURL,
      relativePath: "",
      fileManager: fileManager,
      directoryMap: &directoryMap,
      filePatterns: &filePatterns,
      audioDirectories: &audioDirectories,
      voiceFiles: &voiceFiles
    )

    // Determine the recognized pattern based on scan results
    let pattern = classifyPattern(
      directoryMap: directoryMap,
      filePatterns: Array(filePatterns)
    )

    return ProjectStructure(
      rootURL: rootURL,
      directoryMap: directoryMap,
      filePatterns: Array(filePatterns).sorted(),
      audioDirectories: Array(audioDirectories).sorted(),
      voiceFiles: Array(voiceFiles).sorted(),
      recognizedPattern: pattern
    )
  }

  /// Recursively scans a directory, collecting metadata about structure.
  ///
  /// This is a private helper that walks the directory tree and extracts:
  /// - Languages (directory names matching ISO 639-1 codes)
  /// - Seasons (directory names with season patterns)
  /// - File extensions
  /// - Known audio/config directories
  private nonisolated static func scanDirectory(
    at url: URL,
    relativePath: String,
    fileManager: FileManager,
    directoryMap: inout [String: [Int]],
    filePatterns: inout Set<String>,
    audioDirectories: inout Set<String>,
    voiceFiles: inout Set<String>
  ) {
    guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    else {
      return
    }

    for item in contents {
      let fileName = item.lastPathComponent
      let newRelativePath = relativePath.isEmpty ? fileName : "\(relativePath)/\(fileName)"

      // Check if this is a directory
      if let isDir = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir {
        // Check for audio directory patterns
        if isAudioDirectory(fileName) {
          audioDirectories.insert(newRelativePath)
        }

        // Try to parse as language code or season number
        if let languageCode = parseLanguageCode(fileName) {
          // Recursively scan the language directory for seasons
          scanLanguageDirectory(
            at: item,
            languageCode: languageCode,
            fileManager: fileManager,
            directoryMap: &directoryMap,
            filePatterns: &filePatterns,
            audioDirectories: &audioDirectories,
            voiceFiles: &voiceFiles
          )
        } else if let seasonNumber = parseSeasonNumber(fileName) {
          // Found a season directory at root level
          if directoryMap[""] == nil {
            directoryMap[""] = []
          }
          if !directoryMap[""]!.contains(seasonNumber) {
            directoryMap[""]!.append(seasonNumber)
          }
          // Recursively scan the season directory
          scanDirectory(
            at: item,
            relativePath: newRelativePath,
            fileManager: fileManager,
            directoryMap: &directoryMap,
            filePatterns: &filePatterns,
            audioDirectories: &audioDirectories,
            voiceFiles: &voiceFiles
          )
        } else {
          // Regular directory, recurse
          scanDirectory(
            at: item,
            relativePath: newRelativePath,
            fileManager: fileManager,
            directoryMap: &directoryMap,
            filePatterns: &filePatterns,
            audioDirectories: &audioDirectories,
            voiceFiles: &voiceFiles
          )
        }
      } else {
        // It's a file - extract extension
        let ext = item.pathExtension.lowercased()
        if !ext.isEmpty && isScriptFileType(ext) {
          filePatterns.insert("*.\(ext)")
        }

        // Check for voice/config files
        if isVoiceConfigFile(fileName) {
          voiceFiles.insert(newRelativePath)
        }
      }
    }
  }

  /// Scans a language directory looking for seasons.
  ///
  /// When we find a directory matching a language code, we look inside for season patterns.
  private nonisolated static func scanLanguageDirectory(
    at url: URL,
    languageCode: String,
    fileManager: FileManager,
    directoryMap: inout [String: [Int]],
    filePatterns: inout Set<String>,
    audioDirectories: inout Set<String>,
    voiceFiles: inout Set<String>
  ) {
    guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    else {
      return
    }

    var seasonsInLanguage: [Int] = []

    for item in contents {
      guard let isDir = try? item.resourceValues(forKeys: [URLResourceKey.isDirectoryKey]).isDirectory, isDir else {
        // File in language directory
        let fileName = item.lastPathComponent
        let ext = item.pathExtension.lowercased()
        if !ext.isEmpty && isScriptFileType(ext) {
          filePatterns.insert("*.\(ext)")
        }
        if isVoiceConfigFile(fileName) {
          voiceFiles.insert("\(languageCode)/\(fileName)")
        }
        continue
      }

      let dirName = item.lastPathComponent

      if let seasonNumber = parseSeasonNumber(dirName) {
        if !seasonsInLanguage.contains(seasonNumber) {
          seasonsInLanguage.append(seasonNumber)
        }
        // Recursively scan season directory for files
        scanDirectory(
          at: item,
          relativePath: "\(languageCode)/\(dirName)",
          fileManager: fileManager,
          directoryMap: &directoryMap,
          filePatterns: &filePatterns,
          audioDirectories: &audioDirectories,
          voiceFiles: &voiceFiles
        )
      } else if isAudioDirectory(dirName) {
        audioDirectories.insert("\(languageCode)/\(dirName)")
      } else {
        // Unknown subdirectory, still scan for files
        scanDirectory(
          at: item,
          relativePath: "\(languageCode)/\(dirName)",
          fileManager: fileManager,
          directoryMap: &directoryMap,
          filePatterns: &filePatterns,
          audioDirectories: &audioDirectories,
          voiceFiles: &voiceFiles
        )
      }
    }

    // Always add the language to the map, even if it has no seasons
    // This allows us to distinguish language-only structures from flat structures
    if !seasonsInLanguage.isEmpty {
      directoryMap[languageCode] = seasonsInLanguage.sorted()
    } else {
      // Even with no seasons, we track the language with an empty season list
      directoryMap[languageCode] = []
    }
  }

  /// Classifies the directory structure into a RecognitionPattern.
  ///
  /// Classification logic:
  /// 1. If multiple languages with seasons each → languageFirstMultiSeason
  /// 2. If single language with multiple seasons → singleLanguageMultiSeason
  /// 3. If multiple languages, no seasons → languageOnly
  /// 4. If no language/season structure detected → flat
  private nonisolated static func classifyPattern(
    directoryMap: [String: [Int]],
    filePatterns: [String]
  ) -> RecognitionPattern {
    // If directory map is empty, structure is flat
    if directoryMap.isEmpty {
      return .flat
    }

    // Extract root-level seasons (stored with empty string key)
    let rootSeasons = directoryMap[""] ?? []

    // Get all languages (non-empty keys)
    let languages = directoryMap.keys.filter { !$0.isEmpty }.sorted()

    // Count how many language directories have seasons
    let languagesWithSeasons = languages.filter { language in
      let seasons = directoryMap[language] ?? []
      return !seasons.isEmpty
    }

    // Classification logic
    if !languages.isEmpty && !languagesWithSeasons.isEmpty {
      // We have multiple languages, each with seasons
      let allSeasons = Set(languagesWithSeasons.flatMap { directoryMap[$0] ?? [] })
      return .languageFirstMultiSeason(
        languages: languages,
        seasons: Array(allSeasons).sorted()
      )
    } else if !rootSeasons.isEmpty && languages.isEmpty {
      // We have seasons at root, no language separation
      return .singleLanguageMultiSeason(seasons: rootSeasons)
    } else if !languages.isEmpty && languagesWithSeasons.isEmpty {
      // We have languages but no season structure within them
      return .languageOnly(languages: languages)
    } else {
      // Can't classify
      return .unknown
    }
  }

  /// Parses a directory name as a language code (ISO 639-1 or similar).
  ///
  /// Recognizes:
  /// - Two-letter codes: "en", "es", "fr", "de", etc.
  /// - BCP 47 language tags: "en-US", "es-MX", "pt-BR", etc.
  /// - Three-letter codes: "eng", "spa", "fra", etc.
  private nonisolated static func parseLanguageCode(_ dirName: String) -> String? {
    let lowercased = dirName.lowercased()

    // Common ISO 639-1 language codes (2 letters)
    let iso639_1 = [
      "aa", "ab", "ae", "af", "ak", "am", "an", "ar", "as", "av", "ay", "az",
      "ba", "be", "bg", "bh", "bi", "bm", "bn", "bo", "br", "bs",
      "ca", "ce", "ch", "co", "cr", "cs", "cu", "cv", "cy",
      "da", "de", "dv", "dz",
      "ee", "el", "en", "eo", "es", "et", "eu",
      "fa", "ff", "fi", "fj", "fo", "fr", "fy",
      "ga", "gd", "gl", "gn", "gu", "gv",
      "ha", "he", "hi", "ho", "hr", "ht", "hu", "hy", "hz",
      "ia", "id", "ie", "ig", "ii", "ik", "io", "is", "it", "iu",
      "ja", "jv",
      "ka", "kg", "ki", "kj", "kk", "kl", "km", "kn", "ko", "kr", "ks", "ku", "kv", "kw", "ky",
      "la", "lb", "lg", "li", "ln", "lo", "lt", "lu", "lv",
      "mg", "mh", "mi", "mk", "ml", "mn", "mr", "ms", "mt", "my",
      "na", "nb", "nd", "ne", "ng", "nl", "nn", "no", "nr", "nv", "ny",
      "oc", "oj", "om", "or", "os",
      "pa", "pi", "pl", "ps", "pt",
      "qu",
      "rm", "rn", "ro", "ru", "rw",
      "sa", "sc", "sd", "se", "sg", "si", "sk", "sl", "sm", "sn", "so", "sq", "sr", "ss", "st", "su", "sv", "sw",
      "ta", "te", "tg", "th", "ti", "tk", "tl", "tn", "to", "tr", "ts", "tt", "tw", "ty",
      "ug", "uk", "ur", "uz",
      "ve", "vi", "vo",
      "wa", "wo",
      "xh",
      "yi", "yo",
      "za", "zh", "zu"
    ]

    if iso639_1.contains(lowercased) {
      return lowercased
    }

    // Check for BCP 47 language tags (e.g., "en-US", "zh-Hans")
    if lowercased.count > 2 && lowercased.contains("-") {
      let parts = lowercased.split(separator: "-").map(String.init)
      if parts.count >= 2 && iso639_1.contains(parts[0]) {
        return parts[0]  // Return the language code part
      }
    }

    // Check for 3-letter ISO 639-2/3 codes (simplified check)
    if lowercased.count == 3 && lowercased.allSatisfy({ $0.isLetter }) {
      return lowercased
    }

    return nil
  }

  /// Parses a directory name as a season number.
  ///
  /// Recognizes patterns like:
  /// - "season-1", "season-01", "season1"
  /// - "s1", "s01"
  /// - "1", "01" (just numbers, must be 1-2 digits)
  private nonisolated static func parseSeasonNumber(_ dirName: String) -> Int? {
    let lowercased = dirName.lowercased()

    // Pattern: "season-N" or "seasonN"
    if lowercased.hasPrefix("season") {
      let remainder = String(lowercased.dropFirst(6))  // Remove "season"
      let numberStr = remainder.hasPrefix("-") ? String(remainder.dropFirst()) : remainder
      if let number = Int(numberStr), number > 0, number < 1000 {
        return number
      }
    }

    // Pattern: "s" or "s0" prefix
    if lowercased.hasPrefix("s") {
      let remainder = String(lowercased.dropFirst())
      if let number = Int(remainder), number > 0, number < 1000 {
        return number
      }
    }

    // Pattern: just a number (1-3 digits, 1-999)
    if let number = Int(lowercased), number > 0, number < 1000 {
      // Only match if it's all digits
      if dirName.allSatisfy({ $0.isNumber }) {
        return number
      }
    }

    return nil
  }

  /// Checks if a directory name looks like an audio output directory.
  private nonisolated static func isAudioDirectory(_ dirName: String) -> Bool {
    let lowercased = dirName.lowercased()
    return lowercased == "audio" || lowercased == "audio_output" || lowercased == "output"
  }

  /// Checks if a file extension is a script file type.
  private nonisolated static func isScriptFileType(_ ext: String) -> Bool {
    let scriptExtensions = ["fountain", "fdx", "highland", "md", "txt"]
    return scriptExtensions.contains(ext.lowercased())
  }

  /// Checks if a filename looks like a voice/narrator configuration file.
  private nonisolated static func isVoiceConfigFile(_ fileName: String) -> Bool {
    let lowercased = fileName.lowercased()
    return lowercased.hasSuffix("_voices.json")
      || lowercased.hasSuffix("_voices.yaml")
      || lowercased.hasSuffix("_voices.yml")
      || lowercased.hasSuffix("_narrators.json")
  }
}

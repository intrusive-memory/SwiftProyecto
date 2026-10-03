//
//  FileCoordinationManager.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// Coordinates concurrent writes to PROJECT.md across multiple applications.
///
/// When multiple apps (e.g., Personaje and Vinetas) need to write different sections
/// of a PROJECT.md file, this manager ensures:
/// - Only one write happens at a time (via NSFileCoordinator)
/// - Each app's changes are preserved without overwriting others' fields
/// - Owned fields are updated while non-owned fields are preserved
///
/// ## Field Ownership Model
///
/// Each app declares which top-level keys it owns via ``OwnedFields``.
/// - **Personaje** owns: `personaje`, `style.artStyle`
/// - **Vinetas** owns: `projects`, `sequences`, `style.palette`, `style.wardrobe`
///
/// ## Usage
///
/// ```swift
/// let coordinator = FileCoordinationManager()
/// let owned = OwnedFields(appName: "personaje",
///                         keys: ["personaje", "style"])
/// try coordinator.coordinatedWrite(fileURL: projectURL, ownedFields: owned) { mutable in
///     mutable.description = "Updated description"
///     // Changes to "personaje" field are written; others are preserved
/// }
/// ```
///
public struct FileCoordinationManager {
  /// Declares which fields an app owns and can modify.
  public struct OwnedFields {
    /// The app identifier (e.g., "personaje", "vinetas")
    public let appName: String

    /// Top-level keys the app is allowed to modify (e.g., ["personaje", "style"])
    public let keys: [String]

    /// Nested field paths for partial ownership (e.g., ["style.artStyle"])
    /// Used when an app owns only specific sub-fields of a top-level key.
    public let nestedPaths: [String]

    /// Create an OwnedFields configuration.
    ///
    /// - Parameters:
    ///   - appName: Application identifier
    ///   - keys: Top-level keys this app owns
    ///   - nestedPaths: Optional nested field paths for partial ownership
    public init(appName: String, keys: [String], nestedPaths: [String] = []) {
      self.appName = appName
      self.keys = keys
      self.nestedPaths = nestedPaths
    }
  }

  public init() {}

  /// Performs a coordinated write to a PROJECT.md file with field preservation.
  ///
  /// - Parameters:
  ///   - fileURL: URL to the PROJECT.md file
  ///   - ownedFields: Fields this app is allowed to modify
  ///   - block: Closure that modifies the mutable ProjectFrontMatter
  /// - Throws: NSFileCoordinator errors, parsing errors, or writing errors
  ///
  /// This method:
  /// 1. Acquires an exclusive write lock via NSFileCoordinator
  /// 2. Reads the current PROJECT.md file
  /// 3. Preserves non-owned fields from the existing document
  /// 4. Allows the block to modify owned fields
  /// 5. Writes the merged result back to disk
  ///
  /// Non-owned fields are never overwritten, preventing data loss when
  /// multiple apps write concurrently or sequentially.
  public func coordinatedWrite(
    fileURL: URL,
    ownedFields: OwnedFields,
    block: (inout ProjectFrontMatter) throws -> Void
  ) throws {
    let coordinator = NSFileCoordinator()
    var coordinationError: NSError?
    var operationError: Error?

    coordinator.coordinate(
      writingItemAt: fileURL,
      options: .forMerging,
      error: &coordinationError
    ) { newURL in
      do {
        // Read existing file content
        let parser = ProjectMarkdownParser()
        let (existing, body) = try parser.parse(fileURL: newURL)

        // Create mutable copy starting with existing data
        var mutable = existing

        // Apply the block's modifications to owned fields
        try block(&mutable)

        // Merge: preserve non-owned fields from existing document
        let merged = mergePreservingNonOwnedFields(
          modified: mutable,
          existing: existing,
          ownedBy: ownedFields
        )

        // Write the merged result
        try parser.write(frontMatter: merged, body: body, to: newURL)
      } catch {
        operationError = error
      }
    }

    if let error = coordinationError {
      throw error
    }

    if let error = operationError {
      throw error
    }
  }


  // MARK: - Private Helpers

  /// Merge a modified ProjectFrontMatter with an existing one,
  /// preserving non-owned fields from the existing document.
  ///
  /// - Parameters:
  ///   - modified: The ProjectFrontMatter after block modifications
  ///   - existing: The original ProjectFrontMatter read from disk
  ///   - ownedBy: The OwnedFields configuration declaring what this app owns
  /// - Returns: A merged ProjectFrontMatter with owned fields updated and non-owned preserved
  private func mergePreservingNonOwnedFields(
    modified: ProjectFrontMatter,
    existing: ProjectFrontMatter,
    ownedBy: OwnedFields
  ) -> ProjectFrontMatter {
    // Start with modified as the base, then restore non-owned sections
    var result = modified

    // Restore non-owned app sections
    for (key, value) in existing.appSections {
      if !ownedBy.keys.contains(key) {
        result.appSections[key] = value
      }
    }

    // Handle style: field merging if it's not fully owned
    if !ownedBy.keys.contains("style") && !ownedBy.nestedPaths.isEmpty {
      // If style isn't fully owned but some nested paths are,
      // preserve non-owned style fields
      let mergedStyle: Style?
      if let existingStyle = existing.style, let modifiedStyle = modified.style {
        mergedStyle = mergeStylePreservingNonOwnedFields(
          modified: modifiedStyle,
          existing: existingStyle,
          ownedPaths: ownedBy.nestedPaths
        )
      } else if existing.style != nil && modified.style == nil {
        // Preserve existing style if app didn't modify it
        mergedStyle = existing.style
      } else {
        mergedStyle = modified.style
      }

      // Create a new ProjectFrontMatter with the merged style
      result = ProjectFrontMatter(
        type: result.type,
        title: result.title,
        author: result.author,
        created: result.created,
        updated: result.updated,
        description: result.description,
        genre: result.genre,
        tags: result.tags,
        episodesDir: result.episodesDir,
        audioDir: result.audioDir,
        filePattern: result.filePattern,
        exportFormat: result.exportFormat,
        introFile: result.introFile,
        outroFile: result.outroFile,
        preGenerateHook: result.preGenerateHook,
        postGenerateHook: result.postGenerateHook,
        tts: result.tts,
        style: mergedStyle,
        schemaVersion: result.schemaVersion,
        projectType: result.projectType,
        seasons: result.seasons,
        languages: result.languages,
        variants: result.variants,
        episodePath: result.episodePath,
        appSections: result.appSections
      )
    }

    return result
  }

  /// Merge a modified Style with an existing one, preserving non-owned fields.
  ///
  /// - Parameters:
  ///   - modified: The modified Style
  ///   - existing: The original Style from disk
  ///   - ownedPaths: Nested paths this app owns (e.g., ["style.artStyle"])
  /// - Returns: A merged Style with owned fields updated and non-owned preserved
  private func mergeStylePreservingNonOwnedFields(
    modified: Style,
    existing: Style,
    ownedPaths: [String]
  ) -> Style {
    let ownsArtStyle = ownedPaths.contains("style.artStyle")
    let ownsPalette = ownedPaths.contains("style.palette")
    let ownsWardrobe = ownedPaths.contains("style.wardrobe")

    return Style(
      artStyle: ownsArtStyle ? modified.artStyle : existing.artStyle,
      palette: ownsPalette ? modified.palette : existing.palette,
      wardrobe: ownsWardrobe ? modified.wardrobe : existing.wardrobe
    )
  }
}

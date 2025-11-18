//
//  SingleFileManager.swift
//  SwiftProyecto
//
//  Created on 2025-11-17.
//

import Foundation
import SwiftData
import SwiftCompartido

/// Service for managing single screenplay files in the app-wide container.
///
/// SingleFileManager provides operations for importing, reloading, and managing
/// individual screenplay files that are not part of a project. Files are stored
/// in the app-wide SwiftData container located in Application Support.
///
/// ## Usage
/// ```swift
/// let manager = SingleFileManager(modelContext: modelContext)
///
/// // Import a file
/// let document = try await manager.importFile(from: fileURL)
///
/// // Reload a file
/// try await manager.reloadFile(document)
///
/// // Check if file needs reload
/// if manager.needsReload(document) {
///     try await manager.reloadFile(document)
/// }
/// ```
@MainActor
public final class SingleFileManager {

    // MARK: - Properties

    private let modelContext: ModelContext
    private let fileManager = FileManager.default

    // MARK: - Errors

    public enum SingleFileError: LocalizedError {
        case fileNotFound(URL)
        case fileAccessFailed(URL)
        case bookmarkCreationFailed(Error)
        case bookmarkResolutionFailed(Error)
        case securityScopedAccessFailed(URL)
        case noBookmarkData
        case parsingFailed(String, Error)
        case saveError(Error)
        case documentNotFound

        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let url):
                return "File not found: \(url.lastPathComponent)"
            case .fileAccessFailed(let url):
                return "Cannot access file: \(url.lastPathComponent)"
            case .bookmarkCreationFailed(let error):
                return "Failed to create security-scoped bookmark: \(error.localizedDescription)"
            case .bookmarkResolutionFailed(let error):
                return "Failed to resolve security-scoped bookmark: \(error.localizedDescription)"
            case .securityScopedAccessFailed(let url):
                return "Failed to access security-scoped resource: \(url.lastPathComponent)"
            case .noBookmarkData:
                return "No bookmark data available for file"
            case .parsingFailed(let filename, let error):
                return "Failed to parse \(filename): \(error.localizedDescription)"
            case .saveError(let error):
                return "Failed to save to SwiftData: \(error.localizedDescription)"
            case .documentNotFound:
                return "Document not found in SwiftData"
            }
        }
    }

    // MARK: - Initialization

    /// Creates a new SingleFileManager with the specified model context.
    ///
    /// - Parameter modelContext: The SwiftData model context for the app-wide container.
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - File Operations

    /// Imports a screenplay file into the app-wide SwiftData container.
    ///
    /// This method:
    /// 1. Creates a security-scoped bookmark for the file
    /// 2. Parses the file using SwiftCompartido
    /// 3. Creates a GuionDocumentModel with all elements
    /// 4. Saves to SwiftData
    ///
    /// - Parameter fileURL: URL of the file to import (must have security scope access)
    /// - Returns: The created GuionDocumentModel
    /// - Throws: SingleFileError if import fails
    public func importFile(from fileURL: URL) async throws -> GuionDocumentModel {
        // Verify file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw SingleFileError.fileNotFound(fileURL)
        }

        // Create security-scoped bookmark
        let bookmarkData: Data
        do {
            bookmarkData = try fileURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw SingleFileError.bookmarkCreationFailed(error)
        }

        // Parse the file
        let parsedCollection: GuionParsedElementCollection
        do {
            parsedCollection = try await GuionParsedElementCollection(file: fileURL.path)
        } catch {
            throw SingleFileError.parsingFailed(fileURL.lastPathComponent, error)
        }

        // Create document model
        let document = GuionDocumentModel(
            filename: fileURL.lastPathComponent,
            rawContent: nil,
            suppressSceneNumbers: false
        )
        document.sourceFileBookmark = bookmarkData
        document.lastImportDate = Date()

        // Insert document
        modelContext.insert(document)

        // Create and insert elements
        var chapterIndex = 0
        var positionInChapter = 0

        for parsedElement in parsedCollection.elements {
            // Track chapters (section level 1)
            if case .sectionHeading(let level) = parsedElement.elementType, level == 1 {
                chapterIndex += 1
                positionInChapter = 0
            }

            let element = GuionElementModel(
                from: parsedElement,
                chapterIndex: chapterIndex,
                orderIndex: positionInChapter
            )

            document.elements.append(element)
            modelContext.insert(element)
            positionInChapter += 1
        }

        // Copy title page if present
        for dictionary in parsedCollection.titlePage {
            for (key, values) in dictionary {
                let titlePageEntry = TitlePageEntryModel(key: key, values: values)
                document.titlePage.append(titlePageEntry)
                modelContext.insert(titlePageEntry)
            }
        }

        // Save to SwiftData
        do {
            try modelContext.save()
        } catch {
            throw SingleFileError.saveError(error)
        }

        return document
    }

    /// Reloads a document from its source file, replacing all elements.
    ///
    /// This method:
    /// 1. Resolves the security-scoped bookmark
    /// 2. Re-parses the file
    /// 3. Deletes old elements
    /// 4. Creates new elements from the parsed content
    /// 5. Updates lastImportDate
    ///
    /// - Parameter document: The document to reload
    /// - Throws: SingleFileError if reload fails
    public func reloadFile(_ document: GuionDocumentModel) async throws {
        // Resolve bookmark to get file URL
        let fileURL = try resolveBookmark(for: document)

        // Start security-scoped access
        guard fileURL.startAccessingSecurityScopedResource() else {
            throw SingleFileError.securityScopedAccessFailed(fileURL)
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }

        // Verify file still exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw SingleFileError.fileNotFound(fileURL)
        }

        // Parse the file
        let parsedCollection: GuionParsedElementCollection
        do {
            parsedCollection = try await GuionParsedElementCollection(file: fileURL.path)
        } catch {
            throw SingleFileError.parsingFailed(fileURL.lastPathComponent, error)
        }

        // Delete existing elements
        for element in document.elements {
            modelContext.delete(element)
        }
        document.elements.removeAll()

        // Delete existing title page
        for entry in document.titlePage {
            modelContext.delete(entry)
        }
        document.titlePage.removeAll()

        // Create new elements
        var chapterIndex = 0
        var positionInChapter = 0

        for parsedElement in parsedCollection.elements {
            // Track chapters (section level 1)
            if case .sectionHeading(let level) = parsedElement.elementType, level == 1 {
                chapterIndex += 1
                positionInChapter = 0
            }

            let element = GuionElementModel(
                from: parsedElement,
                chapterIndex: chapterIndex,
                orderIndex: positionInChapter
            )

            document.elements.append(element)
            modelContext.insert(element)
            positionInChapter += 1
        }

        // Copy new title page if present
        for dictionary in parsedCollection.titlePage {
            for (key, values) in dictionary {
                let titlePageEntry = TitlePageEntryModel(key: key, values: values)
                document.titlePage.append(titlePageEntry)
                modelContext.insert(titlePageEntry)
            }
        }

        // Update import date
        document.lastImportDate = Date()

        // Save changes
        do {
            try modelContext.save()
        } catch {
            throw SingleFileError.saveError(error)
        }
    }

    /// Checks if a document needs to be reloaded because the source file has been modified.
    ///
    /// - Parameter document: The document to check
    /// - Returns: True if the file has been modified since last import, false otherwise
    /// - Throws: SingleFileError if file cannot be accessed
    public func needsReload(_ document: GuionDocumentModel) throws -> Bool {
        guard let lastImportDate = document.lastImportDate else {
            // If we've never imported, we need to reload
            return true
        }

        // Resolve bookmark
        let fileURL = try resolveBookmark(for: document)

        // Start security-scoped access
        guard fileURL.startAccessingSecurityScopedResource() else {
            throw SingleFileError.securityScopedAccessFailed(fileURL)
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }

        // Check if file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw SingleFileError.fileNotFound(fileURL)
        }

        // Get file modification date
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        guard let modificationDate = attributes[.modificationDate] as? Date else {
            return true  // Can't determine, assume needs reload
        }

        // Compare dates (file modified after last import = needs reload)
        return modificationDate > lastImportDate
    }

    /// Resolves the source file URL from a document's security-scoped bookmark.
    ///
    /// - Parameter document: The document containing the bookmark
    /// - Returns: The resolved file URL
    /// - Throws: SingleFileError if bookmark cannot be resolved
    public func resolveBookmark(for document: GuionDocumentModel) throws -> URL {
        guard let bookmarkData = document.sourceFileBookmark else {
            throw SingleFileError.noBookmarkData
        }

        var isStale = false
        let fileURL: URL
        do {
            fileURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw SingleFileError.bookmarkResolutionFailed(error)
        }

        // If bookmark is stale, recreate it
        if isStale {
            do {
                let newBookmark = try fileURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                document.sourceFileBookmark = newBookmark
                try modelContext.save()
            } catch {
                throw SingleFileError.bookmarkCreationFailed(error)
            }
        }

        return fileURL
    }

    /// Deletes a document and all its associated data from SwiftData.
    ///
    /// Note: This does NOT delete the source file from disk.
    ///
    /// - Parameter document: The document to delete
    /// - Throws: SingleFileError if deletion fails
    public func deleteDocument(_ document: GuionDocumentModel) throws {
        modelContext.delete(document)

        do {
            try modelContext.save()
        } catch {
            throw SingleFileError.saveError(error)
        }
    }
}

import Foundation

/// Utility for managing security-scoped bookmarks across platforms.
///
/// BookmarkManager provides centralized bookmark handling for both macOS (security-scoped)
/// and iOS (standard bookmarks). It handles:
/// - Creating platform-appropriate bookmarks
/// - Resolving bookmarks with stale detection
/// - Refreshing stale bookmarks automatically
/// - Executing operations with security-scoped access
///
/// ## Platform Differences
///
/// **macOS:**
/// - Uses `.withSecurityScope` option for sandboxed access
/// - Requires `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`
///
/// **iOS:**
/// - Uses standard bookmarks (no security scope)
/// - No explicit resource access calls required
///
/// ## Usage
///
/// ```swift
/// // Create bookmark
/// let bookmarkData = try BookmarkManager.createBookmark(for: folderURL)
///
/// // Resolve bookmark
/// let (url, isStale) = try BookmarkManager.resolveBookmark(bookmarkData)
///
/// // Refresh if stale
/// if isStale {
///     bookmarkData = try BookmarkManager.createBookmark(for: url)
/// }
///
/// // Execute operation with access
/// let result = try BookmarkManager.withAccess(url, bookmarkData: bookmarkData) { url in
///     // Perform file operations
/// }
/// ```
public enum BookmarkManager {

    // MARK: - Errors

    public enum BookmarkError: LocalizedError {
        case staleBookmark
        case accessDenied
        case invalidBookmarkData
        case resolutionFailed(Error)
        case creationFailed(Error)

        public var errorDescription: String? {
            switch self {
            case .staleBookmark:
                return "Bookmark data is stale and needs to be recreated"
            case .accessDenied:
                return "Failed to access security-scoped resource"
            case .invalidBookmarkData:
                return "Invalid bookmark data provided"
            case .resolutionFailed(let error):
                return "Failed to resolve bookmark: \(error.localizedDescription)"
            case .creationFailed(let error):
                return "Failed to create bookmark: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Platform-Specific Options

    /// Bookmark creation options appropriate for the current platform.
    private static var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if os(macOS)
        return .withSecurityScope
        #else
        return .minimalBookmark
        #endif
    }

    /// Bookmark resolution options appropriate for the current platform.
    private static var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if os(macOS)
        return .withSecurityScope
        #else
        return []
        #endif
    }

    // MARK: - Public Methods

    /// Creates a security-scoped bookmark for the given URL.
    ///
    /// On macOS, creates a security-scoped bookmark suitable for sandboxed apps.
    /// On iOS, creates a standard bookmark.
    ///
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: Bookmark data that can be stored and later resolved
    /// - Throws: `BookmarkError.creationFailed` if bookmark creation fails
    public static func createBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: bookmarkCreationOptions,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw BookmarkError.creationFailed(error)
        }
    }

    /// Resolves a bookmark to a URL, detecting if the bookmark is stale.
    ///
    /// A stale bookmark means the file system has changed in a way that requires
    /// the bookmark to be recreated (e.g., file moved, volume remounted).
    ///
    /// - Parameter data: The bookmark data to resolve
    /// - Returns: A tuple containing the resolved URL and a boolean indicating if stale
    /// - Throws: `BookmarkError.resolutionFailed` if bookmark cannot be resolved
    public static func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: bookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        } catch {
            throw BookmarkError.resolutionFailed(error)
        }
    }

    /// Resolves a bookmark and automatically refreshes it if stale.
    ///
    /// This is a convenience method that combines `resolveBookmark` and `createBookmark`.
    /// If the bookmark is stale, it creates a new bookmark and updates the parameter.
    ///
    /// - Parameter bookmarkData: An inout parameter containing the bookmark data.
    ///                          Will be updated with fresh bookmark if stale.
    /// - Returns: The resolved URL (same whether bookmark was stale or not)
    /// - Throws: `BookmarkError` if resolution or recreation fails
    public static func refreshIfNeeded(_ bookmarkData: inout Data) throws -> URL {
        let (url, isStale) = try resolveBookmark(bookmarkData)

        if isStale {
            bookmarkData = try createBookmark(for: url)
        }

        return url
    }

    /// Executes an operation with security-scoped access to a URL.
    ///
    /// This method:
    /// 1. Resolves the bookmark (if provided) or uses the URL directly
    /// 2. Starts accessing the security-scoped resource (macOS only)
    /// 3. Executes the operation
    /// 4. Stops accessing the resource (via defer)
    ///
    /// **Note:** On iOS, security-scoped access calls are no-ops but this method
    /// still provides a consistent API across platforms.
    ///
    /// - Parameters:
    ///   - url: The URL to access. If `bookmarkData` is provided, this is ignored.
    ///   - bookmarkData: Optional bookmark data to resolve first
    ///   - operation: The operation to perform with access to the URL
    /// - Returns: The result of the operation
    /// - Throws: `BookmarkError` if access fails, or any error thrown by the operation
    public static func withAccess<T>(
        _ url: URL,
        bookmarkData: Data? = nil,
        operation: (URL) throws -> T
    ) throws -> T {
        // Resolve bookmark if provided
        let resolvedURL: URL
        if let data = bookmarkData {
            let (bookmarkURL, _) = try resolveBookmark(data)
            resolvedURL = bookmarkURL
        } else {
            resolvedURL = url
        }

        // Start accessing security-scoped resource (macOS only, returns true on iOS)
        #if os(macOS)
        guard resolvedURL.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied
        }
        defer { resolvedURL.stopAccessingSecurityScopedResource() }
        #endif

        return try operation(resolvedURL)
    }

    /// Async version of `withAccess` for asynchronous operations.
    ///
    /// See `withAccess(_:bookmarkData:operation:)` for details.
    ///
    /// - Parameters:
    ///   - url: The URL to access. If `bookmarkData` is provided, this is ignored.
    ///   - bookmarkData: Optional bookmark data to resolve first
    ///   - operation: The async operation to perform with access to the URL
    /// - Returns: The result of the operation
    /// - Throws: `BookmarkError` if access fails, or any error thrown by the operation
    ///
    /// - Note: This method is nonisolated to allow use from actor-isolated contexts.
    ///         The caller is responsible for ensuring thread safety.
    nonisolated public static func withAccess<T>(
        _ url: URL,
        bookmarkData: Data? = nil,
        operation: (URL) async throws -> T
    ) async throws -> T {
        // Resolve bookmark if provided
        let resolvedURL: URL
        if let data = bookmarkData {
            let (bookmarkURL, _) = try resolveBookmark(data)
            resolvedURL = bookmarkURL
        } else {
            resolvedURL = url
        }

        // Start accessing security-scoped resource (macOS only, returns true on iOS)
        #if os(macOS)
        guard resolvedURL.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied
        }
        defer { resolvedURL.stopAccessingSecurityScopedResource() }
        #endif

        return try await operation(resolvedURL)
    }
}

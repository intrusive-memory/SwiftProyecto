//
//  FileLoadingState.swift
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

/// Represents the loading state of a screenplay file within a project.
///
/// Files in projects can be in various states depending on whether they've been
/// imported to SwiftData, whether the file has been modified externally, etc.
///
/// ## State Transitions
///
/// ```
/// notLoaded → loading → loaded
///                ↓         ↓
///              error    stale → loading → loaded
///                         ↓
///                      missing
/// ```
///
/// ## Usage
///
/// ```swift
/// var fileRef = ProjectFileReference(...)
/// fileRef.loadingState = .notLoaded
///
/// // User clicks "Load File"
/// fileRef.loadingState = .loading
///
/// do {
///     try await loadFile(fileRef)
///     fileRef.loadingState = .loaded
/// } catch {
///     fileRef.loadingState = .error
/// }
/// ```
///
public enum FileLoadingState: String, Codable, Sendable, CaseIterable {
    /// File discovered in project folder but not yet imported to SwiftData
    case notLoaded

    /// File is currently being parsed and imported
    case loading

    /// File has been fully imported to SwiftData and is available for editing
    case loaded

    /// File was modified on disk after being loaded (needs reload)
    case stale

    /// File no longer exists in project folder but is still in SwiftData
    case missing

    /// File failed to load due to parse error or other issue
    case error
}

// MARK: - Display Properties

public extension FileLoadingState {
    /// Human-readable description of the state
    var displayName: String {
        switch self {
        case .notLoaded:
            return "Not Loaded"
        case .loading:
            return "Loading..."
        case .loaded:
            return "Loaded"
        case .stale:
            return "Modified"
        case .missing:
            return "Missing"
        case .error:
            return "Error"
        }
    }

    /// System icon name for the state
    var systemIconName: String {
        switch self {
        case .notLoaded:
            return "circle"
        case .loading:
            return "arrow.clockwise.circle"
        case .loaded:
            return "checkmark.circle.fill"
        case .stale:
            return "exclamationmark.triangle.fill"
        case .missing:
            return "xmark.circle.fill"
        case .error:
            return "exclamationmark.octagon.fill"
        }
    }

    /// Whether the file can be opened for editing
    var canOpen: Bool {
        switch self {
        case .loaded, .stale:
            return true
        case .notLoaded, .loading, .missing, .error:
            return false
        }
    }

    /// Whether the file can be loaded
    var canLoad: Bool {
        switch self {
        case .notLoaded, .stale, .error:
            return true
        case .loading, .loaded, .missing:
            return false
        }
    }

    /// Whether the file should show a warning indicator
    var showsWarning: Bool {
        switch self {
        case .stale, .missing, .error:
            return true
        case .notLoaded, .loading, .loaded:
            return false
        }
    }
}

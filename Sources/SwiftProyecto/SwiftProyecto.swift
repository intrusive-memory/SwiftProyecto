// SwiftProyecto - Project Management for Screenplay Applications
// Copyright (c) 2025 Intrusive Memory

import Foundation

/// SwiftProyecto provides data models and services for managing screenplay projects.
///
/// SwiftProyecto handles:
/// - Project metadata management via PROJECT.md manifest files
/// - File discovery and state tracking (loaded, unloaded, stale, missing)
/// - Dual SwiftData container strategy (app-wide vs project-local)
/// - Project lifecycle operations (create, open, sync, load files)
///
/// ## Topics
///
/// ### Getting Started
/// - ``ProjectModel``
/// - ``ProjectFileReference``
/// - ``FileLoadingState``
///
/// ### Services
/// - ``ProjectService``
/// - ``ModelContainerFactory``
public struct SwiftProyecto {
    /// The current version of SwiftProyecto
    public static let version = "2.5.0"

    /// Private initializer - SwiftProyecto is a namespace
    private init() {}
}

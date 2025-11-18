# Changelog

All notable changes to SwiftProyecto will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Phase 2: Container Strategy (In Progress)

#### Planned
- DocumentContext enum for single-file vs project context
- ModelContainerFactory for dual container selection
- SwiftCompartido dependency integration
- GuionDocumentModel relationship integration

---

## [0.2.0] - 2025-11-17

### Phase 1: SwiftData Models (Complete)

#### Added
- **FileLoadingState** enum with 6 states (notLoaded, loading, loaded, stale, missing, error)
  - Display properties (displayName, systemIconName)
  - Capability flags (canOpen, canLoad, showsWarning)
  - Full Codable support
- **ProjectFileReference** SwiftData model
  - File discovery and state tracking
  - Bidirectional relationship to ProjectModel
  - Convenience properties for querying
  - Display name with path context
- **ProjectModel** SwiftData model
  - Complete project metadata (title, author, created, description, etc.)
  - Optional fields (season, episodes, genre, tags)
  - Security-scoped folder bookmark storage
  - Cascade delete for file references
  - Query methods (file counts, filtering, sorting)
  - Sync detection logic

#### Tests
- 32 tests total, all passing (100%)
- FileLoadingStateTests: 8 tests
- ProjectFileReferenceTests: 10 tests
- ProjectModelTests: 12 tests
- Test coverage: ~95%

#### Development
- Swift 6.2 compatibility
- iOS 26.0+ and macOS 26.0+ support
- Full SwiftData persistence
- Zero compiler warnings

---

## [0.1.0] - 2025-11-17

### Phase 0: Foundation (Complete)

#### Added
- Initial package structure with Package.swift
- MIT license
- README.md with project overview
- CONTRIBUTING.md guidelines
- .gitignore for Swift projects
- Placeholder source files and tests
- GitHub repository at intrusive-memory/SwiftProyecto
- Documentation directory with implementation strategy

#### Development
- Package builds successfully with Swift 6.2
- Basic tests pass (version check, placeholder test)
- Repository published to GitHub

[Unreleased]: https://github.com/intrusive-memory/SwiftProyecto/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/intrusive-memory/SwiftProyecto/releases/tag/v0.2.0
[0.1.0]: https://github.com/intrusive-memory/SwiftProyecto/releases/tag/v0.1.0

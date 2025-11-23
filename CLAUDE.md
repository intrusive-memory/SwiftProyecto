# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftProyecto is a Swift package for project and file management in screenplay applications. It provides models and services for:
- Project folder management with lazy file loading
- File discovery and synchronization
- Security-scoped bookmark handling
- Integration with SwiftCompartido for screenplay parsing

**Platforms**: iOS 26.0+, macOS 26.0+

## Development Workflow

**⚠️ CRITICAL: See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for complete development workflow.**

This project follows a **strict branch-based workflow**:

### Quick Reference

- **Development branch**: `development` (all work happens here)
- **Main branch**: `main` (protected, PR-only)
- **Workflow**: `development` → PR → CI passes → Merge → Tag → Release
- **NEVER** commit directly to `main`
- **NEVER** delete the `development` branch

**See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for:**
- Complete branch strategy
- Commit message conventions
- PR creation templates
- Tagging and release process
- Version numbering (semver)
- Emergency hotfix procedures

## Core Architecture

### Project Models

- **ProjectModel**: SwiftData model representing a screenplay project folder
- **ProjectFileReference**: Lazy-loaded file references with loading states
- **FileLoadingState**: Tracks whether files are loaded, stale, or missing

### Services

- **ProjectManager**: Main service for project operations
  - File discovery and synchronization
  - Lazy loading of screenplay files
  - Security-scoped resource access
- **iCloudProjectSupport**: iCloud integration
- **SingleFileManager**: Single document workflow support
- **ModelContainerFactory**: SwiftData container creation

### Lazy Loading Pattern

Files are discovered but NOT loaded until explicitly requested:

```swift
let project = ProjectModel(title: "My Series")
try projectManager.syncProject(project)  // Discovers files

// Files are NOT loaded yet - only metadata stored
for fileRef in project.fileReferences {
    print(fileRef.filename)  // ✅ Available
    print(fileRef.loadedDocument)  // ❌ nil until loaded
}

// Load file on demand
try await projectManager.loadFile(fileRef, in: project)
print(fileRef.loadedDocument)  // ✅ Now available
```

## Dependencies

- **SwiftCompartido**: Screenplay parsing and SwiftData models
- **GRMustache.swift**: Template rendering (future feature)

## Important Notes

- This library is **Apple Silicon-only** (arm64)
- Requires macOS 26.0+ or iOS 26.0+
- All files use security-scoped bookmarks for sandboxed access
- SwiftData models use cascade delete for cleanup

## Related Projects

- **SwiftCompartido**: Shared screenplay models and parsers
- **SwiftHablare**: TTS and voice provider integration
- **produciesta**: macOS/iOS application using these libraries

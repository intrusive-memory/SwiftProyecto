# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftProyecto is a Swift package for **file discovery and project metadata management** in screenplay applications. It provides:
- Project folder management and file discovery
- PROJECT.md metadata parsing and generation
- Security-scoped bookmark handling
- File tree building for navigation UIs

**What SwiftProyecto Does**:
- ✅ Discovers screenplay files in folders/git repos
- ✅ Manages PROJECT.md metadata
- ✅ Provides security-scoped URLs for file access
- ✅ Builds hierarchical file trees

**What SwiftProyecto Does NOT Do**:
- ❌ Parse screenplay files (use SwiftCompartido)
- ❌ Store document models (apps handle integration)
- ❌ Display UI (provides data only)

**Platforms**: iOS 26.0+, macOS 26.0+

---

## ⚠️ CRITICAL: Platform Version Enforcement

**This library ONLY supports iOS 26.0+ and macOS 26.0+. NEVER add code that supports older platforms.**

### Rules for Platform Versions

1. **NEVER add `@available` attributes** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `@available(iOS 15.0, macOS 12.0, *)`
   - ✅ CORRECT: No `@available` needed (package enforces iOS 26/macOS 26)

2. **NEVER add `#available` runtime checks** for versions below iOS 26.0 or macOS 26.0
   - ❌ WRONG: `if #available(iOS 15.0, *) { ... }`
   - ✅ CORRECT: No runtime checks needed (package enforces minimum versions)

3. **Platform-specific code is OK** (macOS vs iOS differences)
   - ✅ CORRECT: `#if os(macOS)` or `#if canImport(AppKit)`
   - ✅ CORRECT: `#if canImport(UIKit)`
   - ❌ WRONG: Checking for specific OS versions below 26

4. **Package.swift must always specify iOS 26 and macOS 26**
   ```swift
   platforms: [
       .iOS(.v26),
       .macOS(.v26)
   ]
   ```

**DO NOT lower the platform requirements. Apps using this library must update their deployment targets to iOS 26+ and macOS 26+.**

---

## Development Workflow

**⚠️ CRITICAL: See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for complete development workflow.**

This project follows a **strict branch-based workflow**:

### Quick Reference

- **Development branch**: `development` (all work happens here)
- **Main branch**: `main` (protected, PR-only)
- **Workflow**: `development` → PR → CI passes → Merge → Tag → Release
- **NEVER** commit directly to `main`
- **NEVER** delete the `development` branch

### CI/CD Requirements

**Main branch is protected:**
- Direct pushes blocked (PRs only)
- No PR review required
- GitHub Actions must pass before merge:
  - Code Quality: Linting and code checks
  - iOS Unit Tests: Unit tests on iOS Simulator
  - macOS Unit Tests: Unit tests on macOS
- Performance tests run after unit tests (informational only, don't block)
- **Tests ONLY run on pull requests** (not on push to development)

**Development branch is NOT protected:**
- Work happens directly on `development`
- No CI checks required for pushes to `development`
- CI only runs when creating PR from `development` to `main`

**See [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) for:**
- Complete branch strategy
- Commit message conventions
- PR creation templates
- Tagging and release process
- Version numbering (semver)
- Emergency hotfix procedures

### Branch Protection Configuration

**⚠️ IMPORTANT: When tests are changed or renamed, branch protections must be evaluated.**

The `main` branch has required status checks that must pass before PRs can be merged. These checks are configured in GitHub repository settings and must match the actual CI workflow job names.

**When to Update Branch Protections:**
- ✅ When CI workflow job names change
- ✅ When test jobs are added or removed
- ✅ When platforms are added or removed (iOS, macOS)
- ✅ When test structure is reorganized

**How to Update Branch Protections:**

View current protections:
```bash
gh api repos/intrusive-memory/SwiftProyecto/branches/main/protection/required_status_checks
```

Update required checks:
```bash
gh api --method PATCH repos/intrusive-memory/SwiftProyecto/branches/main/protection/required_status_checks \
  -H "Accept: application/vnd.github.v3+json" \
  --input - <<'EOF'
{
  "strict": true,
  "contexts": [
    "Code Quality",
    "iOS Unit Tests",
    "macOS Unit Tests"
  ]
}
EOF
```

**Best Practices:**
- Keep branch protection checks minimal but essential
- Align check names exactly with CI workflow job names
- Document protection changes in PR descriptions
- Test protection changes by creating a test PR

---

## Core Architecture

### Project Models

**ProjectModel** - SwiftData model representing a screenplay project folder
- Stores PROJECT.md metadata (title, author, season, episodes, etc.)
- References discovered files via `fileReferences` relationship
- Provides file tree building via `fileTree()` method
- Manages security-scoped bookmark for project folder

**ProjectFileReference** - SwiftData model for discovered files
- Tracks file metadata (path, name, extension, modification date)
- Optional security-scoped bookmark for file-level access
- No relationship to document models (apps manage that)

**ProjectFrontMatter** - Codable struct for PROJECT.md metadata
- YAML front matter representation
- Required fields: type, title, author, created
- Optional metadata fields: description, season, episodes, genre, tags
- Optional generation config: episodesDir, audioDir, filePattern, exportFormat
- Optional hooks: preGenerateHook, postGenerateHook
- Convenience accessors: resolvedEpisodesDir, resolvedAudioDir, resolvedFilePatterns, resolvedExportFormat

**FilePattern** - Flexible file pattern type for generation config
- Accepts single string or array of strings
- Normalizes to array via `.patterns` property
- Supports glob patterns (e.g., "*.fountain") and explicit file lists
- Codable with automatic string/array detection

**FileNode** - Hierarchical tree structure for file navigation
- Built from flat ProjectFileReference array
- Supports folders and files
- Used for navigation UIs (OutlineGroup, List, etc.)

### Services

**ProjectService** - Main service for project operations (@MainActor)
- **File Discovery**: `discoverFiles(for:allowedExtensions:)`
- **Project Management**: `createProject(at:title:author:...)`, `openProject(at:)`
- **Bookmark Management**: `getSecureURL(for:in:)`, `refreshBookmark(for:in:)`, `createFileBookmark(for:in:)`
- **PROJECT.md**: Reads/writes project metadata files

**ModelContainerFactory** - SwiftData container creation
- Creates containers for project metadata only
- Schema: `ProjectModel`, `ProjectFileReference`
- Supports both app-wide and project-local storage

**FileSource Protocol** - Abstraction for file discovery
- Protocol for discovering files from different source types
- Implementations: `DirectoryFileSource`, `GitRepositoryFileSource`
- Handles file enumeration, filtering, and metadata extraction
- ProjectService delegates discovery to FileSource implementations

**DirectoryFileSource** - Local directory file discovery
- Discovers files in a local directory recursively
- Excludes system files (.DS_Store, Thumbs.db, etc.)
- Excludes build artifacts (.build, .cache, DerivedData)
- Excludes PROJECT.md from file listings

**GitRepositoryFileSource** - Git repository file discovery
- Extends DirectoryFileSource with git repository validation
- Validates `.git/` directory exists
- Same exclusion patterns as DirectoryFileSource
- Does NOT perform git operations (use git library for that)

**ProjectMarkdownParser** - YAML front matter parser using UNIVERSAL
- Parses PROJECT.md files with YAML front matter (delimited by `---`)
- Generates PROJECT.md content from ProjectFrontMatter
- Uses UNIVERSAL library for spec-compliant YAML parsing
- Properly handles quoted strings, colons in values, complex arrays, and ISO8601 dates
- Supports lazy loading: parse PROJECT.md only when needed
- Two parsing methods: `parse(fileURL:)` and `parse(content:)`
- Returns tuple of `(ProjectFrontMatter, String)` - front matter and body content

**BookmarkManager** - Security-scoped bookmark utilities
- Cross-platform (macOS/iOS)
- Handles bookmark creation, resolution, refresh
- Platform-specific: macOS uses `.withSecurityScope`, iOS uses `.minimalBookmark`

### PROJECT.md Parsing Pattern

SwiftProyecto uses **lazy loading** for PROJECT.md parsing. Metadata is only parsed when needed:

```swift
// 1. Parse PROJECT.md from file URL
let parser = ProjectMarkdownParser()
let (frontMatter, body) = try parser.parse(fileURL: projectURL.appendingPathComponent("PROJECT.md"))

// 2. Or parse from string content (for in-memory operations)
let content = """
---
type: project
title: My Series
author: Jane Doe
created: 2025-11-17T10:30:00Z
season: 1
episodes: 12
genre: Science Fiction
tags: [sci-fi, drama]
episodesDir: scripts
audioDir: output
filePattern: "*.fountain"
exportFormat: m4a
preGenerateHook: "./scripts/prepare.sh"
postGenerateHook: "./scripts/upload.sh"
---

# Production Notes
Additional notes here...
"""
let (frontMatter, body) = try parser.parse(content: content)

// 3. Access front matter fields
print(frontMatter.title)       // "My Series"
print(frontMatter.author)      // "Jane Doe"
print(frontMatter.season)      // Optional(1)
print(frontMatter.episodes)    // Optional(12)
print(frontMatter.tags)        // Optional(["sci-fi", "drama"])
print(body)                    // "# Production Notes\nAdditional notes here..."

// 4. Access generation config with defaults
print(frontMatter.resolvedEpisodesDir)   // "scripts" (or "episodes" if nil)
print(frontMatter.resolvedAudioDir)      // "output" (or "audio" if nil)
print(frontMatter.resolvedFilePatterns)  // ["*.fountain"]
print(frontMatter.resolvedExportFormat)  // "m4a"
print(frontMatter.preGenerateHook)       // Optional("./scripts/prepare.sh")

// 5. Generate PROJECT.md content
let newFrontMatter = ProjectFrontMatter(
    title: "New Project",
    author: "John Writer",
    season: 2,
    episodes: 10,
    episodesDir: "episodes",
    audioDir: "audio",
    filePattern: .multiple(["*.fountain", "*.fdx"]),
    exportFormat: "m4a"
)
let markdown = parser.generate(frontMatter: newFrontMatter, body: "# Notes")
// Produces valid PROJECT.md with YAML front matter
```

**Key Points**:
- **Lazy**: PROJECT.md is only parsed when you call `parse()`, not automatically on project open
- **Stateless**: ProjectMarkdownParser is a stateless utility - no caching, just pure parsing
- **YAML Front Matter**: Must be delimited by `---` markers
- **Required Fields**: `type`, `title`, `author`, `created` (validated during parsing)
- **Optional Metadata Fields**: `description`, `season`, `episodes`, `genre`, `tags`
- **Optional Generation Config**: `episodesDir`, `audioDir`, `filePattern`, `exportFormat`
- **Optional Hooks**: `preGenerateHook`, `postGenerateHook`
- **Date Format**: ISO8601 format for `created` field (e.g., `2025-11-17T10:30:00Z`)
- **Error Handling**: Throws `ProjectMarkdownParser.ParserError` with detailed error messages
- **Backward Compatible**: All new fields are optional with sensible defaults

### File Discovery Pattern

SwiftProyecto discovers files and parses PROJECT.md metadata but does NOT load screenplay documents:

```swift
// 1. Open/create project (automatically parses PROJECT.md)
let projectService = ProjectService(modelContext: context)
let project = try await projectService.openProject(at: folderURL)
// Project metadata is now available (title, author, season, etc.)

// 2. Discover files (lazy - call when needed)
try await projectService.discoverFiles(for: project)

// 3. Access PROJECT.md metadata (already parsed during openProject)
print(project.title)       // From PROJECT.md front matter
print(project.author)      // From PROJECT.md front matter
print(project.season)      // Optional field

// 4. Get security-scoped URL for a screenplay file
let fileRef = project.fileReferences.first!
let url = try projectService.getSecureURL(for: fileRef, in: project)

// 5. App parses screenplay file (using SwiftCompartido or other parser)
let parsed = try await GuionParsedElementCollection(file: url.path)

// 6. App stores document (apps manage integration)
let document = await GuionDocumentModel.from(parsed, in: context)

// 7. (Optional) Manually parse or regenerate PROJECT.md
let parser = ProjectMarkdownParser()
let projectMdURL = folderURL.appendingPathComponent("PROJECT.md")
let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)
```

---

## Dependencies

**Current**:
- **UNIVERSAL** (v5.2.7): Zero-dependency YAML/JSON/XML parser for PROJECT.md parsing
  - Spec-compliant YAML parsing
  - Handles quoted strings, colons in values, complex arrays
  - Used by ProjectMarkdownParser

**Removed** (v2.0+):
- ~~SwiftCompartido~~ - Apps integrate directly
- ~~GRMustache.swift~~ - Template rendering was never used, removed in v2.0

---

## Integration with Apps

### Recommended Pattern

Apps should create an integration layer (e.g., `DocumentRegistry` in Produciesta) that links SwiftProyecto files to SwiftCompartido documents:

```swift
@Model
class DocumentRegistry {
    var projectID: UUID?
    var fileReferenceID: UUID?
    var fileURL: URL
    @Relationship var document: GuionDocumentModel?
}

// Usage
let url = try projectService.getSecureURL(for: fileRef, in: project)
let parsed = try await GuionParsedElementCollection(file: url.path)
let document = await GuionDocumentModel.from(parsed, in: context)

let registry = DocumentRegistry(
    fileURL: url,
    projectID: project.id,
    fileReferenceID: fileRef.id,
    document: document
)
context.insert(registry)
```

See `.claude/REFACTORING_PLAN.md` for complete Produciesta integration guide.

---

## Important Notes

- This library is **Apple Silicon-only** (arm64)
- Requires macOS 26.0+ or iOS 26.0+
- All files use security-scoped bookmarks for sandboxed access
- SwiftData models use cascade delete for cleanup
- Library is **standalone** - no dependency on SwiftCompartido

---

## Related Projects

- **SwiftCompartido**: Screenplay parsing and SwiftData document models
- **SwiftHablare**: TTS and voice provider integration
- **Produciesta**: macOS/iOS application integrating these libraries


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
- Optional fields: description, season, episodes, genre, tags

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
- Parses PROJECT.md files with YAML front matter
- Generates PROJECT.md content from ProjectFrontMatter
- Uses UNIVERSAL library for spec-compliant YAML parsing
- Properly handles quoted strings, colons in values, and complex arrays

**BookmarkManager** - Security-scoped bookmark utilities
- Cross-platform (macOS/iOS)
- Handles bookmark creation, resolution, refresh
- Platform-specific: macOS uses `.withSecurityScope`, iOS uses `.minimalBookmark`

### File Discovery Pattern

SwiftProyecto discovers files but does NOT load them:

```swift
// 1. Open/create project
let projectService = ProjectService(modelContext: context)
let project = try await projectService.openProject(at: folderURL)

// 2. Discover files
try await projectService.discoverFiles(for: project)

// 3. Get security-scoped URL for a file
let fileRef = project.fileReferences.first!
let url = try projectService.getSecureURL(for: fileRef, in: project)

// 4. App parses file (using SwiftCompartido or other parser)
let parsed = try await GuionParsedElementCollection(file: url.path)

// 5. App stores document (apps manage integration)
let document = await GuionDocumentModel.from(parsed, in: context)
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

---

## 📝 NOTE: Activating in Produciesta

**Current Status** (2025-12-14): Phase 2 integration code exists in Produciesta but is **temporarily disabled** with `#if false` blocks.

### To Enable SwiftProyecto Integration in Produciesta:

1. **Remove `#if false` blocks** from:
   - `Produciesta/Views/DocumentLoader.swift`
   - `Produciesta/Views/ProjectBrowserView.swift`
   - `Produciesta/Views/ProjectFileTreeView.swift`

2. **Uncomment SwiftProyecto** in `ProduciestaApp.swift`:
   ```swift
   // Change this:
   // import SwiftProyecto

   // To this:
   import SwiftProyecto

   // And uncomment in schema:
   Schema([
       // ... existing models
       ProjectModel.self,
       ProjectFileReference.self,
       DocumentRegistry.self
   ])
   ```

3. **Add "Open Folder" to WelcomeView**:
   - Implement folder picker (NSOpenPanel/UIDocumentPickerViewController)
   - Call `ProjectService.openProject(at:)` and `discoverFiles(for:)`
   - Navigate to `ProjectBrowserView`

4. **Update Navigation**:
   - Add `.project(ProjectModel)` route to AppRoute enum
   - Wire up in MacOSNavigationRoot and IOSNavigationRoot

5. **Test**:
   - Open folder
   - Browse file tree
   - Load documents
   - Verify caching via DocumentRegistry

See `Produciesta/.claude/PHASE2_IMPLEMENTATION.md` for complete details.

**Why Disabled**: Waiting for SwiftProyecto v2.0 to be merged and released before activating in Produciesta.

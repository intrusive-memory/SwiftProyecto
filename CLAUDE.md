# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftProyecto is a Swift package for project and file management in screenplay applications. It provides models and services for:
- Project folder management with lazy file loading
- File discovery and synchronization
- Security-scoped bookmark handling
- Integration with SwiftCompartido for screenplay parsing

**Platforms**: iOS 26.0+, macOS 26.0+

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
- Tests run on:
  - Pull requests targeting `main`
  - Pushes to `main` (after PR merge)
  - Can be triggered manually via GitHub Actions UI

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

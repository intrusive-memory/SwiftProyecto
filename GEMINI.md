# Gemini-Specific Agent Instructions

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation.

This file contains instructions specific to Google Gemini agents working on SwiftProyecto.

---

## Quick Reference

**Project**: SwiftProyecto - Swift package for extensible, agentic discovery of content projects
**Purpose**: Enables AI agents to understand content projects in a single pass via PROJECT.md metadata
**Platforms**: iOS 26.0+, macOS 26.0+
**Current Version**: 3.0.0

**Universal Documentation**: See [AGENTS.md](AGENTS.md) for:
- Product overview and architecture
- Core models and services
- Integration patterns
- Dependencies and related projects
- proyecto CLI documentation

---

## Gemini-Specific Build Tools

### Use Standard CLI Tools

**Gemini does not have access to MCP servers**, so use standard command-line tools for all operations.

### Building SwiftProyecto

**Use xcodebuild for building and testing:**

```bash
# Build the package
xcodebuild build -scheme SwiftProyecto -destination 'platform=macOS'

# Run tests
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'

# Clean build artifacts
xcodebuild clean -scheme SwiftProyecto
```

**⚠️ IMPORTANT**: Do NOT use `swift build` or `swift test` for this project. The proyecto CLI requires Metal shader compilation which only works with xcodebuild.

### Building proyecto CLI

**Use the Makefile (recommended):**

```bash
# Debug build with Metal shaders
make install

# Release build with Metal shaders
make release

# Run the CLI
./bin/proyecto --version
./bin/proyecto init /path/to/project
```

**Manual xcodebuild (if not using Makefile):**

```bash
# Build for macOS Apple Silicon
xcodebuild -scheme proyecto -destination 'platform=macOS,arch=arm64' build

# The binary will be in DerivedData
# Find it: ~/Library/Developer/Xcode/DerivedData/SwiftProyecto-*/Build/Products/Debug/proyecto
```

---

## Gemini-Specific Workflows

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'

# Run specific test class
xcodebuild test -scheme SwiftProyecto \
  -destination 'platform=macOS' \
  -only-testing:SwiftProyectoTests/ProjectServiceTests

# Verbose test output
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS' | xcpretty
```

### Checking Test Coverage

```bash
# Generate code coverage
xcodebuild test -scheme SwiftProyecto \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES

# View coverage report
open ~/Library/Developer/Xcode/DerivedData/SwiftProyecto-*/Logs/Test/*.xcresult
```

### Creating a Release

Follow standard git workflow:

```bash
# 1. On development branch
git checkout development
git pull origin development

# 2. Bump version in Sources/SwiftProyecto/SwiftProyecto.swift
# Edit: public static let version = "X.Y.Z"

# 3. Update documentation
# Edit AGENTS.md, CLAUDE.md, GEMINI.md, README.md

# 4. Commit changes
git add .
git commit -m "Bump version to X.Y.Z and update documentation"
git push origin development

# 5. Create PR to main
gh pr create --base main --head development --title "Release vX.Y.Z"

# 6. After PR is merged to main
git checkout main
git pull origin main

# 7. Tag the release
git tag -a vX.Y.Z -m "Release vX.Y.Z: Description"
git push origin vX.Y.Z

# 8. Create GitHub release
gh release create vX.Y.Z --title "vX.Y.Z: Title" --notes "Release notes"
```

---

## Gemini-Specific Critical Rules

1. **Use standard CLI tools** - No MCP server access, use xcodebuild directly
2. **NEVER use `swift build` or `swift test`** - Use xcodebuild instead (required for Metal shaders)
3. **Follow Xcode best practices** - Standard xcodebuild workflows
4. **Test on macOS** - Ensure tests pass on platform=macOS destination
5. **Check git status** - Always verify working tree state before committing

---

## Common Gemini Tasks

### Add a New Test

```bash
# 1. Create test file (if needed)
# Tests/SwiftProyectoTests/NewFeatureTests.swift

# 2. Run new tests
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'

# 3. Verify test count increased
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS' 2>&1 | \
  grep "Test Suite.*passed"
```

### Fix a Bug

```bash
# 1. Read the relevant source files
# 2. Make changes
# 3. Run tests to verify fix
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'

# 4. Commit with descriptive message
git add .
git commit -m "fix: description of bug fix"
```

### Update Documentation

```bash
# 1. Edit AGENTS.md (universal docs)
# 2. Edit CLAUDE.md (Claude-specific)
# 3. Edit GEMINI.md (Gemini-specific)
# 4. Edit README.md (user-facing)
# 5. Commit changes
git add *.md
git commit -m "docs: update documentation"
```

---

## Future Gemini Integrations

**Placeholder for future Gemini-specific integrations:**

- Gemini API integration patterns (when available)
- Gemini Code Assist workflows (when applicable)
- Gemini-specific automation tools

**Note**: Currently, Gemini uses standard CLI tools. As Gemini-specific APIs and tools become available, they will be documented here.

---

**Last Updated**: 2026-02-14 (v3.0.0)

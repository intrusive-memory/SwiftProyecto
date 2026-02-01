# Claude-Specific Agent Instructions

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation.

For detailed project documentation, architecture, and development guidelines, see **[AGENTS.md](AGENTS.md)**.

## Quick Reference

**Project**: SwiftProyecto - Swift package for file discovery and project metadata management in screenplay applications

**Platforms**: iOS 26.0+, macOS 26.0+

**Key Components**:
- Project folder management and file discovery
- PROJECT.md metadata parsing and generation
- Security-scoped bookmark handling
- File tree building for navigation UIs
- `proyecto` CLI for AI-powered PROJECT.md generation

**Important Notes**:
- ⚠️ ONLY supports iOS 26.0+ and macOS 26.0+ (NEVER add code for older platforms)
- ⚠️ `proyecto` CLI MUST be built with `xcodebuild`, NOT `swift build` (requires Metal shaders)
- See [AGENTS.md](AGENTS.md) for complete development workflow, architecture, and integration patterns

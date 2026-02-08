# Claude-Specific Agent Instructions

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation.

For detailed project documentation, architecture, and development guidelines, see **[AGENTS.md](AGENTS.md)**.

## Quick Reference

**Project**: SwiftProyecto - Swift package for **extensible, agentic discovery** of content projects

**Purpose**: Enables AI coding agents to understand content projects in a single pass by providing structured PROJECT.md metadata containing project intent, composition, settings, and utilities.

**Platforms**: iOS 26.0+, macOS 26.0+

**Key Components**:
- **Agentic Discovery**: Structured PROJECT.md front matter for AI agent consumption
- **Project Metadata**: Machine-readable intent, composition, and generation settings
- **App Settings Extension**: Type-safe, namespaced app-specific settings (v2.6.0+)
- **File Discovery**: Recursive file enumeration in folders/git repos
- **Secure Access**: Security-scoped bookmark handling
- **Hierarchical Structure**: FileNode trees for navigation
- **proyecto CLI**: LLM-powered PROJECT.md generation from directory analysis

**Why This Exists**:
AI agents need multiple utilities and passes to understand content projects. SwiftProyecto solves this by storing settings, utilities, intent, and composition in PROJECT.md front matter, enabling single-pass comprehension.

**Important Notes**:
- ⚠️ ONLY supports iOS 26.0+ and macOS 26.0+ (NEVER add code for older platforms)
- ⚠️ `proyecto` CLI MUST be built with `xcodebuild`, NOT `swift build` (requires Metal shaders)
- See [AGENTS.md](AGENTS.md) for complete development workflow, architecture, and integration patterns

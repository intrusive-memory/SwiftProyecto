# Claude-Specific Agent Instructions

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation.

This file contains instructions specific to Claude Code agents working on SwiftProyecto.

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

## Claude-Specific Build Preferences

### CRITICAL: Use xcodebuild for Swift Projects

**ALWAYS use `xcodebuild` instead of `swift build` or `swift test`** for building and testing Swift packages and Xcode projects.

**Why xcodebuild over swift build:**
- ✅ Better integration with Xcode toolchain
- ✅ Supports Metal shader compilation (required for proyecto CLI)
- ✅ Proper handling of platform-specific code
- ✅ Compatible with MCP server automation

**Examples:**
```bash
# ❌ DON'T use swift build/test
swift build
swift test

# ✅ DO use xcodebuild (or XcodeBuildMCP tools)
xcodebuild build -scheme SwiftProyecto -destination 'platform=macOS'
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'
```

**For proyecto CLI specifically:**
- MUST use `make install` or `make release` (uses xcodebuild under the hood)
- MUST NOT use `swift build` (Metal shaders won't compile)
- See AGENTS.md § Building for details

---

## MCP Server Configuration

### XcodeBuildMCP

**CRITICAL**: XcodeBuildMCP is installed and should be used for ALL Xcode operations instead of direct `xcodebuild` or `xcrun` commands.

**Available Operations:**
- **Building**: `build_sim`, `build_device`, `build_macos`, `build_run_sim`, `build_run_macos`
- **Testing**: `test_sim`, `test_device`, `test_macos`
- **Swift Packages**: `swift_package_build`, `swift_package_test`, `swift_package_run`, `swift_package_clean`
- **Simulator Management**: `list_sims`, `boot_sim`, `open_sim`, `install_app_sim`, `launch_app_sim`
- **Project Info**: `discover_projs`, `list_schemes`, `show_build_settings`
- **Utilities**: `clean`, `get_app_bundle_id`, `screenshot`, `describe_ui`

**Usage Pattern:**
```swift
// ❌ DON'T use direct xcodebuild
xcodebuild -scheme SwiftProyecto -destination 'platform=macOS' build

// ✅ DO use XcodeBuildMCP tools
// "Build SwiftProyecto package for macOS"
// Tool: swift_package_build with scheme parameter
```

**Benefits:**
- Structured output instead of parsing xcodebuild text
- Built-in error handling and retry logic
- Automatic scheme and destination discovery
- Better CI/CD integration

### App Store Connect MCP

**Available for App Store metrics, TestFlight, and Xcode Cloud CI/CD monitoring.**

**Available Operations:**
- **Apps**: `list_apps`, `get_app` - App metadata
- **Xcode Cloud**: `get_xcode_cloud_summary`, `get_xcode_cloud_workflows`, `get_xcode_cloud_builds` - CI/CD monitoring
- **TestFlight**: `get_testflight_metrics`, `get_beta_testers`
- **Reviews**: `get_customer_reviews`, `get_review_metrics`
- **Financial**: `get_sales_report`, `get_revenue_metrics`

**Usage for SwiftProyecto:**
- Not directly applicable (library, not app)
- Useful for apps that depend on SwiftProyecto (Produciesta, etc.)

---

## Claude-Specific Critical Rules

1. **ALWAYS use XcodeBuildMCP tools** instead of direct `xcodebuild` commands
2. **NEVER use `swift build` or `swift test`** - use `xcodebuild` or XcodeBuildMCP equivalents
3. **Use MCP servers for automation** - Leverage XcodeBuildMCP for all build/test operations
4. **Follow global Claude patterns** - Communication style, security, CI/CD workflows from `~/.claude/CLAUDE.md`

---

## Global Claude Settings

**Your global Claude instructions**: `~/.claude/CLAUDE.md`

**Key patterns from global settings:**
- Communication: Complete candor, flag risks directly
- Security: NEVER expose secrets or environment variables
- Swift Build: ALWAYS use xcodebuild (matches this project's requirements)
- CI/CD: GitHub Actions with macos-26+ runners, iPhone 17/iOS 26.1 simulators
- MCP Servers: XcodeBuildMCP and App Store Connect MCP available

---

## Common Claude-Specific Workflows

### Running Tests

**Using XcodeBuildMCP:**
```
Use swift_package_test tool with:
- scheme: SwiftProyecto
- destination: platform=macOS
```

**Using xcodebuild directly:**
```bash
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'
```

### Building proyecto CLI

**Using Makefile (recommended):**
```bash
make release  # Uses xcodebuild, includes Metal shaders
```

**Manual xcodebuild:**
```bash
xcodebuild -scheme proyecto -destination 'platform=macOS,arch=arm64' build
```

### Creating a Release

Follow the ship-swift-library skill workflow:
1. Version bump on development
2. Run `/organize-agent-docs` (this skill)
3. Update README.md
4. Merge PR to main
5. Tag on main
6. Create GitHub release

See [AGENTS.md § Development Workflow](.AGENTS.md#development-workflow) for complete git workflow.

---

**Last Updated**: 2026-02-14 (v3.0.0)

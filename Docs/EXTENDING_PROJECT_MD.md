# Extending PROJECT.md with App-Specific Settings

**SwiftProyecto 3.0+**

This guide explains how to extend PROJECT.md frontmatter with your own app-specific settings using the `AppFrontMatterSettings` protocol.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Step-by-Step Guide](#step-by-step-guide)
- [Complete Example](#complete-example)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

---

## Overview

PROJECT.md uses **YAML frontmatter** for metadata. SwiftProyecto provides a **plugin architecture** that allows apps to define their own settings sections without modifying the library.

### What You Get

✅ **Namespaced settings** - Your app's settings live under a unique key
✅ **Type-safe** - Full Codable support with compile-time checking
✅ **No coupling** - SwiftProyecto doesn't need to know about your app
✅ **Backward compatible** - Old PROJECT.md files work without app sections
✅ **Extensible** - Multiple apps can store settings in the same PROJECT.md

### Example

```yaml
---
# Generic PROJECT.md metadata
type: project
title: "My Screenplay"
author: "John Doe"

# Your app's settings (namespaced)
myapp:
  theme: "dark"
  exportFormat: "pdf"
  autoSave: true
---

# Project Description
...
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ SwiftProyecto (Generic Library)                            │
│                                                             │
│  protocol AppFrontMatterSettings: Codable {                │
│    static var sectionKey: String { get }                   │
│  }                                                          │
│                                                             │
│  struct ProjectFrontMatter {                               │
│    var title: String?                                      │
│    private var appSections: [String: AnyCodable]           │
│                                                             │
│    func settings<T>(for: T.Type) -> T?                     │
│    mutating func setSettings<T>(_ settings: T)             │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ conforms to
                            │
┌─────────────────────────────────────────────────────────────┐
│ Your App                                                    │
│                                                             │
│  struct MyAppSettings: AppFrontMatterSettings {            │
│    static let sectionKey = "myapp"                         │
│    var theme: String?                                      │
│    var exportFormat: String?                               │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
```

**Key Points:**
- SwiftProyecto never imports your app
- Your app imports SwiftProyecto and defines settings
- Settings are stored as type-erased `AnyCodable` internally
- Type safety is restored when you read your settings

---

## Quick Start

### 1. Define Your Settings

```swift
import SwiftProyecto

struct MyAppSettings: AppFrontMatterSettings {
    static let sectionKey = "myapp"  // YAML key

    var theme: String?
    var autoSave: Bool?
    var exportFormat: String?
}
```

### 2. Read Settings

```swift
let parser = ProjectMarkdownParser()
let (frontMatter, _) = try parser.parse(fileURL: projectURL)

if let settings = try frontMatter.settings(for: MyAppSettings.self) {
    print("Theme: \(settings.theme ?? "default")")
}
```

### 3. Write Settings

```swift
var frontMatter = ProjectFrontMatter(title: "My Project")

let settings = MyAppSettings(
    theme: "dark",
    autoSave: true,
    exportFormat: "pdf"
)
try frontMatter.setSettings(settings)

let content = parser.generate(frontMatter: frontMatter, body: "# Description")
try content.write(to: projectURL, atomically: true, encoding: .utf8)
```

---

## Step-by-Step Guide

### Step 1: Import SwiftProyecto

Add SwiftProyecto to your package dependencies:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftProyecto", from: "3.0.0")
]
```

Import in your files:

```swift
import SwiftProyecto
```

### Step 2: Define Your Settings Struct

Create a struct conforming to `AppFrontMatterSettings`:

```swift
/// My app's PROJECT.md settings
struct MyAppSettings: AppFrontMatterSettings {
    // REQUIRED: Unique key for YAML section
    static let sectionKey = "myapp"

    // Your app's settings (all optional recommended)
    var theme: String?
    var autoSave: Bool?
    var windowSize: WindowSize?
    var recentFiles: [String]?

    // Nested types are fine
    struct WindowSize: Codable, Hashable, Sendable {
        var width: Double
        var height: Double
    }
}
```

**Requirements:**
- ✅ Must conform to `AppFrontMatterSettings`
- ✅ Must define `static let sectionKey: String`
- ✅ All properties must be `Codable`
- ✅ Must be `Sendable` for Swift 6 concurrency
- ✅ Section key should be unique (use your app name)

### Step 3: Reading Settings

```swift
func loadSettings(from projectURL: URL) throws -> MyAppSettings? {
    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: projectURL)

    // Returns nil if settings don't exist
    return try frontMatter.settings(for: MyAppSettings.self)
}
```

**Error Handling:**

```swift
do {
    if let settings = try loadSettings(from: url) {
        print("✅ Loaded: \(settings)")
    } else {
        print("ℹ️ No settings found (using defaults)")
    }
} catch {
    print("❌ Failed to parse PROJECT.md: \(error)")
}
```

### Step 4: Writing Settings

```swift
func saveSettings(_ settings: MyAppSettings, to projectURL: URL) throws {
    let parser = ProjectMarkdownParser()

    // Parse existing PROJECT.md
    let (frontMatter, body) = try parser.parse(fileURL: projectURL)

    // Update settings
    var updatedFrontMatter = frontMatter
    try updatedFrontMatter.setSettings(settings)

    // Write back
    let content = parser.generate(frontMatter: updatedFrontMatter, body: body)
    try content.write(to: projectURL, atomically: true, encoding: .utf8)
}
```

**Preserving Other Settings:**

The plugin architecture preserves other app sections automatically:

```swift
// PROJECT.md has both myapp and otherapp sections
// Updating myapp settings preserves otherapp section unchanged
var frontMatter = try parser.parse(fileURL: url).frontMatter
try frontMatter.setSettings(myAppSettings)  // otherapp section untouched
```

### Step 5: Check if Settings Exist

```swift
let (frontMatter, _) = try parser.parse(fileURL: url)

if frontMatter.hasSettings(for: MyAppSettings.self) {
    print("Settings exist")
} else {
    print("No settings - first run or legacy project")
}
```

---

## Complete Example

### Podcast App Settings

```swift
import Foundation
import SwiftProyecto

/// Settings for a podcast narration app
struct PodcastAppSettings: AppFrontMatterSettings {
    static let sectionKey = "podcast"

    // Audio settings
    var sampleRate: Int?
    var bitRate: Int?
    var format: AudioFormat?

    // Chapters
    var chapters: [Chapter]?

    // Export
    var includeMetadata: Bool?
    var coverArtPath: String?

    enum AudioFormat: String, Codable {
        case mp3
        case aac
        case flac
    }

    struct Chapter: Codable, Hashable, Sendable {
        var title: String
        var startTime: Double
        var endTime: Double
    }
}
```

**Resulting YAML:**

```yaml
---
type: project
title: "My Podcast"

podcast:
  sampleRate: 44100
  bitRate: 128
  format: "mp3"
  chapters:
    - title: "Introduction"
      startTime: 0
      endTime: 120
    - title: "Chapter 1"
      startTime: 120
      endTime: 600
  includeMetadata: true
  coverArtPath: "assets/cover.jpg"
---
```

### Usage in App

```swift
// Create new project with settings
func createProject(title: String, settings: PodcastAppSettings) throws {
    let projectURL = URL(fileURLWithPath: "PROJECT.md")

    var frontMatter = ProjectFrontMatter(
        type: "project",
        title: title
    )
    try frontMatter.setSettings(settings)

    let parser = ProjectMarkdownParser()
    let content = parser.generate(
        frontMatter: frontMatter,
        body: "# My Podcast\n\nDescription here."
    )

    try content.write(to: projectURL, atomically: true, encoding: .utf8)
}

// Load existing project settings
func loadProject(from url: URL) throws -> PodcastAppSettings {
    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: url)

    if let settings = try frontMatter.settings(for: PodcastAppSettings.self) {
        return settings
    } else {
        // Return defaults for legacy projects
        return PodcastAppSettings(
            sampleRate: 44100,
            bitRate: 128,
            format: .mp3,
            includeMetadata: true
        )
    }
}
```

---

## Best Practices

### 1. Choose a Unique Section Key

```swift
// ✅ GOOD: Descriptive, unique key
static let sectionKey = "produciesta"
static let sectionKey = "podcast-narrator"
static let sectionKey = "screenplay-tools"

// ❌ BAD: Generic, might collide
static let sectionKey = "settings"
static let sectionKey = "config"
static let sectionKey = "app"
```

### 2. Make All Fields Optional

```swift
// ✅ GOOD: Optional fields for graceful degradation
struct MyAppSettings: AppFrontMatterSettings {
    var theme: String?
    var version: Int?
}

// ❌ BAD: Required fields break backward compat
struct MyAppSettings: AppFrontMatterSettings {
    var theme: String  // Old projects will fail to parse
}
```

### 3. Provide Sensible Defaults

```swift
extension MyAppSettings {
    static var `default`: Self {
        MyAppSettings(
            theme: "light",
            autoSave: true,
            exportFormat: "pdf"
        )
    }
}

// Usage
let settings = try frontMatter.settings(for: MyAppSettings.self) ?? .default
```

### 4. Version Your Settings

```swift
struct MyAppSettings: AppFrontMatterSettings {
    static let sectionKey = "myapp"

    var version: Int?  // Track schema version
    var theme: String?

    // Migration helper
    func migrated() -> Self {
        guard let version = version else {
            // Version 1: no version field
            return MyAppSettings(version: 2, theme: theme ?? "light")
        }

        if version == 1 {
            // Migrate v1 → v2
            return MyAppSettings(version: 2, theme: theme)
        }

        return self
    }
}
```

### 5. Use Enums for Constrained Values

```swift
// ✅ GOOD: Type-safe with validation
enum Theme: String, Codable {
    case light
    case dark
    case auto
}

var theme: Theme?

// ❌ BAD: Stringly-typed, no validation
var theme: String?  // Could be "ligt" (typo), "purple" (invalid)
```

### 6. Preserve Existing Settings

```swift
func updateTheme(to newTheme: String, in projectURL: URL) throws {
    let parser = ProjectMarkdownParser()
    let (frontMatter, body) = try parser.parse(fileURL: projectURL)

    // Get existing settings (or defaults)
    var settings = try frontMatter.settings(for: MyAppSettings.self) ?? .default

    // Update only the theme field
    settings.theme = newTheme

    // Write back (preserves other fields)
    var updatedFrontMatter = frontMatter
    try updatedFrontMatter.setSettings(settings)

    let content = parser.generate(frontMatter: updatedFrontMatter, body: body)
    try content.write(to: projectURL, atomically: true, encoding: .utf8)
}
```

---

## Common Patterns

### Pattern 1: UserDefaults Sync

Sync app settings between UserDefaults (GUI state) and PROJECT.md (persistent storage):

```swift
@MainActor
final class SettingsSyncService {
    private let defaults = UserDefaults.standard

    func loadFromProjectMd(_ url: URL) throws {
        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(fileURL: url)

        guard let settings = try frontMatter.settings(for: MyAppSettings.self) else {
            return
        }

        // Write to UserDefaults
        defaults.set(settings.theme, forKey: "theme")
        defaults.set(settings.autoSave, forKey: "autoSave")
    }

    func saveToProjectMd(_ url: URL) throws {
        let parser = ProjectMarkdownParser()
        let (frontMatter, body) = try parser.parse(fileURL: url)

        // Read from UserDefaults
        let settings = MyAppSettings(
            theme: defaults.string(forKey: "theme"),
            autoSave: defaults.bool(forKey: "autoSave")
        )

        // Write to PROJECT.md
        var updated = frontMatter
        try updated.setSettings(settings)

        let content = parser.generate(frontMatter: updated, body: body)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
```

### Pattern 2: Multiple Settings Sections

Store different categories of settings in nested structures:

```swift
struct MyAppSettings: AppFrontMatterSettings {
    static let sectionKey = "myapp"

    var ui: UISettings?
    var export: ExportSettings?
    var generation: GenerationSettings?

    struct UISettings: Codable, Hashable, Sendable {
        var theme: String?
        var fontSize: Int?
    }

    struct ExportSettings: Codable, Hashable, Sendable {
        var format: String?
        var quality: Int?
    }

    struct GenerationSettings: Codable, Hashable, Sendable {
        var enabled: Bool?
        var model: String?
    }
}
```

**YAML Output:**

```yaml
myapp:
  ui:
    theme: "dark"
    fontSize: 14
  export:
    format: "pdf"
    quality: 100
  generation:
    enabled: true
    model: "gpt-4"
```

### Pattern 3: Settings Migration

Handle settings evolution over time:

```swift
struct MyAppSettings: AppFrontMatterSettings {
    static let sectionKey = "myapp"

    var schemaVersion: Int?
    var theme: String?
    var newField: String?  // Added in v2

    static func load(from frontMatter: ProjectFrontMatter) throws -> Self {
        guard let settings = try frontMatter.settings(for: Self.self) else {
            // No settings - return defaults
            return MyAppSettings(
                schemaVersion: 2,
                theme: "light",
                newField: "default"
            )
        }

        // Migrate if needed
        return settings.migrated()
    }

    func migrated() -> Self {
        let version = schemaVersion ?? 1

        switch version {
        case 1:
            // v1 → v2: Add newField
            return MyAppSettings(
                schemaVersion: 2,
                theme: theme,
                newField: "default"
            )
        case 2:
            return self
        default:
            print("⚠️ Unknown schema version \(version)")
            return self
        }
    }
}
```

### Pattern 4: Shared Settings Between CLI and GUI

Define settings in a shared package, use in both CLI and GUI:

```swift
// In shared package (MyAppCore)
public struct MyAppSettings: AppFrontMatterSettings {
    public static let sectionKey = "myapp"
    public var theme: String?

    public init(theme: String? = nil) {
        self.theme = theme
    }
}

// In CLI tool
import ArgumentParser
import MyAppCore

struct GenerateCommand: AsyncParsableCommand {
    func run() async throws {
        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(fileURL: projectURL)

        let settings = try frontMatter.settings(for: MyAppSettings.self)
        print("Using theme: \(settings?.theme ?? "default")")
    }
}

// In GUI app
import SwiftUI
import MyAppCore

struct SettingsView: View {
    @State private var settings: MyAppSettings?

    var body: some View {
        Form {
            TextField("Theme", text: binding(for: \.theme))
        }
        .onAppear { loadSettings() }
        .onChange(of: settings) { saveSettings() }
    }
}
```

---

## Troubleshooting

### "Type does not conform to protocol"

**Error:**
```
Type 'MyAppSettings' does not conform to protocol 'AppFrontMatterSettings'
```

**Solution:**
Add required protocol conformances:

```swift
struct MyAppSettings: AppFrontMatterSettings {
    static let sectionKey = "myapp"  // ← Required

    // All properties must be Codable
    var theme: String?
}

// Make sure all nested types are Codable + Sendable
struct NestedType: Codable, Hashable, Sendable {
    var value: String
}
```

### "Settings not found" (returns nil)

**Cause:** Settings section doesn't exist in PROJECT.md

**Solutions:**

1. **Provide defaults:**
   ```swift
   let settings = try frontMatter.settings(for: MyAppSettings.self) ?? .default
   ```

2. **Check existence first:**
   ```swift
   if frontMatter.hasSettings(for: MyAppSettings.self) {
       let settings = try frontMatter.settings(for: MyAppSettings.self)!
   }
   ```

3. **Create settings if missing:**
   ```swift
   var frontMatter = existingFrontMatter
   if !frontMatter.hasSettings(for: MyAppSettings.self) {
       try frontMatter.setSettings(.default)
   }
   ```

### "Failed to decode" error

**Cause:** Settings structure changed, old PROJECT.md incompatible

**Solution:** Use optional fields + migration:

```swift
struct MyAppSettings: AppFrontMatterSettings {
    static let sectionKey = "myapp"

    var oldField: String?  // Keep old fields as optional
    var newField: String?  // New fields also optional

    func migrated() -> Self {
        // Migrate old → new
        if oldField != nil && newField == nil {
            return MyAppSettings(newField: oldField)
        }
        return self
    }
}
```

### Settings not persisting

**Cause:** Forgot to write back to disk

**Solution:**

```swift
// ❌ WRONG: Only modifies in-memory copy
var frontMatter = try parser.parse(fileURL: url).frontMatter
try frontMatter.setSettings(settings)
// Missing: Write to disk!

// ✅ CORRECT: Write back to disk
var frontMatter = try parser.parse(fileURL: url).frontMatter
try frontMatter.setSettings(settings)
let content = parser.generate(frontMatter: frontMatter, body: body)
try content.write(to: url, atomically: true, encoding: .utf8)  // ← Write!
```

### Multiple apps conflicting

**Cause:** Two apps using same section key

**Solution:** Use unique, descriptive keys:

```swift
// App 1
struct App1Settings: AppFrontMatterSettings {
    static let sectionKey = "screenplay-tools"  // Unique
}

// App 2
struct App2Settings: AppFrontMatterSettings {
    static let sectionKey = "podcast-narrator"  // Unique
}
```

Both can coexist in same PROJECT.md:

```yaml
screenplay-tools:
  theme: "dark"

podcast-narrator:
  sampleRate: 44100
```

---

## Summary

**3 Steps to Extend PROJECT.md:**

1. **Define settings struct** conforming to `AppFrontMatterSettings`
2. **Read with** `frontMatter.settings(for: MyAppSettings.self)`
3. **Write with** `frontMatter.setSettings(mySettings)`

**Key Benefits:**

✅ Type-safe with Codable
✅ No coupling to SwiftProyecto
✅ Multiple apps can coexist
✅ Backward compatible
✅ Extensible and future-proof

**Next Steps:**

- See [PARSE_ARCHITECTURE.md](PARSE_ARCHITECTURE.md) for parsing internals
- See [EXAMPLE_PROJECT.md](../EXAMPLE_PROJECT.md) for PROJECT.md format
- Check [AGENTS.md](../AGENTS.md) for SwiftProyecto architecture

---

**Questions?** Open an issue at https://github.com/yourusername/SwiftProyecto/issues

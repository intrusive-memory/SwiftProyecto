---
type: reference
name: PROJECT.md Modification Rules
description: Strict rules for modifying PROJECT.md files
---

# PROJECT.md Modification Rules

## Single Source of Truth

**SwiftProyecto is the ONLY package that should modify PROJECT.md files.**

Other projects (Produciesta, podcast generators, etc.) must use SwiftProyecto's API for all PROJECT.md operations.

## Finding PROJECT.md

Use `ProjectDiscovery` service:

```swift
import SwiftProyecto

let discovery = ProjectDiscovery()
if let projectMdURL = discovery.findProjectMd(from: screenplayURL) {
    // Found PROJECT.md
}
```

**Search Logic**:
1. If screenplay is in "episodes" folder -> check parent directory first
2. Check current directory
3. Check parent directory (fallback)

## Reading PROJECT.md

```swift
let parser = ProjectMarkdownParser()
let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)

// Access data
let title = frontMatter.title
let cast = frontMatter.cast
```

## Reading Cast from PROJECT.md

```swift
let discovery = ProjectDiscovery()
if let projectMd = discovery.findProjectMd(from: screenplayURL) {
    // Read all cast members
    let allCast = try discovery.readCast(from: projectMd)

    // Read only Apple voices
    let appleCast = try discovery.readCast(from: projectMd, filterByProvider: "apple")
}
```

## Writing PROJECT.md

**CORRECT (Use SwiftProyecto API)**:

```swift
// Modify front matter (in-memory)
let updatedFrontMatter = frontMatter.mergingCast(newCast, forProvider: "apple")

// Write using SwiftProyecto
let parser = ProjectMarkdownParser()
try parser.write(frontMatter: updatedFrontMatter, body: body, to: projectMdURL)
```

**WRONG (Direct File I/O)**:

```swift
// NEVER DO THIS
let content = parser.generate(frontMatter: updatedFrontMatter, body: body)
try content.write(to: projectMdURL, atomically: true, encoding: .utf8)
```

## Cast Merging - Preserving Other Providers

**CRITICAL**: When updating cast voices for a specific provider, you MUST preserve voices for other providers.

```swift
// CORRECT: Merge cast for current provider only
let updatedFrontMatter = frontMatter.mergingCast(newCast, forProvider: "apple")

// WRONG: Replaces entire cast (loses other provider voices)
let updatedFrontMatter = frontMatter.withCast(newCast)
```

**Example**:
```yaml
# Before: Has ElevenLabs voice
cast:
  - character: NARRATOR
    voices:
      elevenlabs: 21m00Tcm4TlvDq8ikWAM

# After mergingCast with Apple provider: Preserves ElevenLabs, adds Apple
cast:
  - character: NARRATOR
    voices:
      apple: com.apple.voice.premium.en-US.Aaron
      elevenlabs: 21m00Tcm4TlvDq8ikWAM
```

## Why These Rules Matter

1. **Format consistency** - YAML serialization handled uniformly
2. **Validation** - SwiftProyecto validates before writing
3. **Atomic writes** - Prevents file corruption
4. **Future evolution** - Format can change without breaking clients
5. **Data loss prevention** - Cast merging preserves all provider voices

## Ownership Clarification

**SwiftProyecto owns**:
- PROJECT.md file format specification
- Parsing and serialization logic
- File I/O operations (read, write, atomic writes)
- Discovery and location logic (findProjectMd)

**Client projects (Produciesta, etc.) own**:
- When to read/write PROJECT.md (business logic)
- What data to store (cast assignments, preferences)
- UI for editing metadata
- Integration with their own data models (SwiftData, etc.)

**Services like ProjectMdSyncService**: These are **allowed** in client projects - they coordinate WHEN to call SwiftProyecto's API based on business logic (e.g., "sync cast when voice assignment changes").

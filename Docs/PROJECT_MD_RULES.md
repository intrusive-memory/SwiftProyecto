---
type: reference
name: PROJECT.md Modification Rules
description: Strict rules for modifying PROJECT.md files
---

# PROJECT.md Modification Rules

## Single Source of Truth

**SwiftProyecto is the ONLY package that should modify PROJECT.md files.**

Other projects (Produciesta, podcast generators, etc.) must use SwiftProyecto's API for all PROJECT.md operations.

The same one-writer rule applies to `CAST.md`, with a different owner: since schema v5, cast is not a PROJECT.md key at all. `CAST.md` belongs to [SwiftReparto](https://github.com/intrusive-memory/SwiftReparto) — read and write the roster through SwiftReparto's `CastMember` and parser (or the `reparto` CLI), never through SwiftProyecto and never by hand.

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
```

## Cast Does Not Live Here (Since Schema v5)

PROJECT.md declares **no `cast:` key**. `ProjectFrontMatter.cast`, `ProjectDiscovery.readCast(from:filterByProvider:)`, `mergingCast(_:forProvider:)`, and `withCast(_:)` were all removed in SwiftProyecto 5.0.0. A production's cast lives in `CAST.md`, and the rules for it belong to SwiftReparto:

- **Read/write cast** via SwiftReparto's `CastMember` and parser, or the `reparto` CLI. Only SwiftReparto serializes `CAST.md`.
- **Provider-preserving merges** (the old `mergingCast` concern) are SwiftReparto's gap-filling `[CastMember].merging(_:)`.
- **A legacy `cast:` block** found in an older PROJECT.md is preserved verbatim as an unknown key — never modify it in place; migrate it out with `proyecto migrate` (which delegates to `reparto import` and only rewrites PROJECT.md after the transfer is verified, with a `PROJECT.md.bak` backup).

## Writing PROJECT.md

**CORRECT (Use SwiftProyecto API)**:

```swift
// Modify front matter (in-memory), then write using SwiftProyecto
let parser = ProjectMarkdownParser()
try parser.write(frontMatter: updatedFrontMatter, body: body, to: projectMdURL)
```

**WRONG (Direct File I/O)**:

```swift
// NEVER DO THIS
let content = parser.generate(frontMatter: updatedFrontMatter, body: body)
try content.write(to: projectMdURL, atomically: true, encoding: .utf8)
```

Every write stamps `schemaVersion: 5` (`ProjectSchemaVersion.current`) — a legacy file normalizes on its first write.

## Why These Rules Matter

1. **Format consistency** - YAML serialization handled uniformly
2. **Validation** - SwiftProyecto validates before writing
3. **Atomic writes** - Prevents file corruption
4. **Future evolution** - Format can change without breaking clients
5. **Data loss prevention** - a legacy `cast:` block is only ever removed after its contents are verifiably in CAST.md

## Ownership Clarification

**SwiftProyecto owns**:
- PROJECT.md file format specification
- Parsing and serialization logic
- File I/O operations (read, write, atomic writes)
- Discovery and location logic (findProjectMd)

**SwiftReparto owns**:
- CAST.md file format specification, parsing, and serialization
- Cast merging semantics

**Client projects (Produciesta, etc.) own**:
- When to read/write PROJECT.md (business logic)
- What data to store (preferences, app settings)
- UI for editing metadata
- Integration with their own data models (SwiftData, etc.)

**Services like ProjectMdSyncService**: These are **allowed** in client projects - they coordinate WHEN to call SwiftProyecto's API based on business logic. Anything cast-shaped in such a service must go through SwiftReparto against CAST.md, not through SwiftProyecto.

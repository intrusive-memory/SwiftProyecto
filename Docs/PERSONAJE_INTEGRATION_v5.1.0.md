---
type: integration-guide
title: Personaje Integration Requirements — SwiftProyecto v5.1.0
date: 2026-10-03
version: 5.1.0
---

# Personaje Integration Requirements — SwiftProyecto v5.1.0

SwiftProyecto v5.1.0 delivers the complete ProjectBrowser enhancement suite required to unblock Personaje app shell and Vinetas scene integration.

---

## 📦 Dependency Update

Update your SwiftProyecto dependency to **v5.1.0** or later:

```swift
// Package.swift
dependencies: [
  .package(
    url: "https://github.com/intrusive-memory/SwiftProyecto.git",
    .upToNextMajor(from: "5.1.0")
  )
],
```

---

## 🎯 Features Available in v5.1.0

### 1. Expected Files UI (PY-P1)

**What's New**: ProjectWindow now accepts an `expectedFiles` parameter to show file placeholders that don't yet exist on disk.

**Use Case**: Personaje can prompt users to create missing files (e.g., CAST.md) that are expected but absent.

```swift
import SwiftProyecto

let projectWindow = ProjectWindow(
  directoryURL: projectURL,
  expectedFiles: ["CAST.md"],  // Show CAST.md even if not created yet
  onMissingFileSelected: { filePath in
    // User selected the missing file
    // Personaje can now create it
    createFile(atPath: filePath)
  }
)
```

**Integration Checklist**:
- [ ] Update ProjectWindow initializer calls to accept `expectedFiles: ["CAST.md"]`
- [ ] Implement `onMissingFileSelected` callback
- [ ] Test: missing file appears in tree with grey text + "missing" badge
- [ ] Test: selecting missing file triggers callback
- [ ] Verify: existing files still render normally

---

### 2. Handler Disambiguation (PY-P2)

**What's New**: File handlers now support name-based routing (exact filename match) in addition to extension-based routing.

**Use Case**: Personaje can route CAST.md to a dedicated handler separate from other .md files.

```swift
let handlers: [String: (ProjectFile) -> AnyView] = [
  // Name-based handlers (take precedence)
  "PROJECT.md": { file in AnyView(ProjectDetailView(file: file)) },
  "CAST.md": { file in AnyView(CastDetailView(file: file)) },
  
  // Extension-based handlers (fallback)
  "md": { file in AnyView(MarkdownView(file: file)) },
  "fountain": { file in AnyView(ScreenplayView(file: file)) }
]

let projectWindow = ProjectWindow(
  directoryURL: projectURL,
  handlers: handlers
)
```

**Integration Checklist**:
- [ ] Identify which files Personaje handles by name vs. extension
- [ ] Update handlers dict with `"CAST.md"` key
- [ ] Test: CAST.md routes to CastDetailView
- [ ] Test: other .md files route to MarkdownView
- [ ] Verify: handler precedence works correctly

---

### 3. Style Block (PY-P3)

**What's New**: ProjectFrontMatter now includes a top-level `style:` block with optional fields for art direction.

**Use Case**: Personaje reads and writes `style.artStyle` to persist art direction metadata in PROJECT.md.

```swift
import SwiftProyecto

// Read style metadata
let frontMatter: ProjectFrontMatter = try parser.parse(fileURL: projectURL).0
if let artStyle = frontMatter.style?.artStyle {
  print("Art style: \(artStyle)")  // e.g., "watercolor", "digital", "3D"
}

// Write style metadata
var frontMatter = ProjectFrontMatter(title: "My Project", author: "Author")
frontMatter.style = Style(
  artStyle: "watercolor",
  palette: nil,        // Personaje doesn't own palette (Vinetas does)
  wardrobe: nil        // Personaje doesn't own wardrobe (Vinetas does)
)
try parser.write(frontMatter: frontMatter, body: "# Content", to: projectURL)
```

**Integration Checklist**:
- [ ] Import `Style` type from SwiftProyecto
- [ ] Add UI for art style selection/display
- [ ] Read `frontMatter.style?.artStyle` on project open
- [ ] Write to `style.artStyle` when user changes art direction
- [ ] Test: round-trip (write → read) preserves value
- [ ] Test: style block survives Vinetas writes (via coordinated writes below)

---

### 4. Coordinated Writes (PY-P4)

**What's New**: FileCoordinationManager provides thread-safe, field-preserving writes via NSFileCoordinator. Personaje and Vinetas can write PROJECT.md concurrently without overwriting each other's sections.

**Use Case**: Personaje writes its sections (`personaje`, `style.artStyle`) while Vinetas writes its sections (`projects`, `sequences`, `style.palette`, `style.wardrobe`). Neither app loses the other's data.

```swift
import SwiftProyecto

let coordinator = FileCoordinationManager()
let owned = FileCoordinationManager.OwnedFields(
  appName: "personaje",
  keys: ["personaje", "style"],
  nestedPaths: ["style.artStyle"]  // Personaje owns only artStyle within style
)

try coordinator.coordinatedWrite(
  fileURL: projectURL,
  ownedFields: owned,
  block: { mutable in
    // Personaje updates only its sections
    mutable.personaje = ["characterName": "Hero", "role": "Protagonist"]
    if mutable.style == nil {
      mutable.style = Style()
    }
    mutable.style?.artStyle = "watercolor"
    
    // Vinetas' sections (projects, sequences, style.palette, style.wardrobe)
    // are preserved by the coordinator automatically
  }
)
```

**Integration Checklist**:
- [ ] Create an instance of FileCoordinationManager (or use ProjectMarkdownParser.coordinatedWrite)
- [ ] Define OwnedFields with Personaje's owned keys and nested paths
- [ ] Replace all direct writes to PROJECT.md with coordinator.coordinatedWrite()
- [ ] Test: Personaje write preserves Vinetas' projects and sequences
- [ ] Test: alternating P → V → P writes preserve all fields
- [ ] Test: concurrent writes do not cause data loss or corruption
- [ ] **Security**: If using file pickers, wrap coordinator calls with security-scoped access (see Security section below)

---

## 🔐 Security Considerations

### Local File Access (No Change)

If Personaje accesses PROJECT.md through local file system (e.g., via app's Documents folder), no additional security setup is needed. The existing FileCoordinationManager works correctly with unsecoped URLs.

### File Picker Access (New for Security-Scoped URLs)

If Personaje adds support for `UIDocumentPickerViewController` (user picks a project folder), the resulting URLs are **security-scoped** and require explicit resource access:

```swift
// When getting a URL from UIDocumentPickerViewController
if projectURL.startAccessingSecurityScopedResource() {
  defer { projectURL.stopAccessingSecurityScopedResource() }
  
  // NOW safe to use projectURL with coordinator
  try coordinator.coordinatedWrite(fileURL: projectURL, ownedFields: owned) { mutable in
    // Write changes
  }
}
```

**Why**: macOS/iOS sandbox requires explicit permission grants for URLs outside your app's container. File picker grants temporary access via security-scoped URLs; you must bracket access with `start/stopAccessingSecurityScopedResource()`.

**When to implement**: If/when Personaje adds file-picker-based project browsing. Local app-based workflows do not need this.

---

## ✅ Acceptance Criteria

All requirements are met in v5.1.0:

- ✅ **PY-P1**: `ProjectWindow` accepts `expectedFiles` parameter; missing files render with visual indicator; selection fires callback
- ✅ **PY-P2**: Handlers for `PROJECT.md` and `CAST.md` by name each receive only their file; `.md` extension handler receives other markdown files
- ✅ **PY-P3**: `style:` block round-trips correctly; files without `style:` remain unchanged on write
- ✅ **PY-P4**: Coordinated writes via NSFileCoordinator serialize access; non-owned sections (Vinetas' fields) preserved

---

## 📊 Test Coverage

- **171/171 tests passing** (157 existing + 44 new)
- **44 new tests** all CI-safe (no flaky patterns, proper isolation)
- **Test categories**:
  - Expected files UI: 15 tests
  - Handler disambiguation: 10 tests
  - Style block YAML: 11 tests
  - Coordinated writes: 8 tests

---

## 📝 Integration Roadmap

### Immediate (v5.1.0 Integration)

1. [ ] Update Package.swift dependency to v5.1.0
2. [ ] Implement expected files UI with missing file callback
3. [ ] Add handler for CAST.md
4. [ ] Display/edit `style.artStyle` in project settings
5. [ ] Replace direct writes with coordinated writes
6. [ ] Test all four PY-P1 through PY-P4 requirements

### Future (v5.2.0+)

- Evaluate Recents Infrastructure (PY-P5) — currently deferred to v5.2.0
- Optional file picker support (implement security-scoped access wrapper if needed)
- Cross-app coordination testing with Vinetas

---

## 🔗 Documentation References

- **[INTEGRATION_GUIDE.md](./INTEGRATION_GUIDE.md)** — General SwiftProyecto integration
- **[PROJECT_MD_REFERENCE_v4.md](./PROJECT_MD_REFERENCE_v4.md)** — PROJECT.md schema and fields
- **[CORE_ARCHITECTURE.md](./CORE_ARCHITECTURE.md)** — ProjectBrowser architecture overview
- **[FileCoordinationManager source](../Sources/SwiftProyecto/Utilities/FileCoordinationManager.swift)** — Coordinated writes implementation

---

## 📞 Support

For integration questions or issues:

1. Review the documentation links above
2. Check [ProjectBrowser tests](../Tests/ProjectBrowserTests/) for working examples
3. Consult [FileCoordinationManagerTests](../Tests/SwiftProyectoTests/FileCoordinationManagerTests.swift) for coordinated write patterns

---

**Version**: 5.1.0  
**Released**: 2026-10-03  
**Status**: Ready for Production Integration


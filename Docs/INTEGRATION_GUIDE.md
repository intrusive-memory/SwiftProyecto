# SwiftProyecto Integration Guide

A comprehensive guide for developers integrating SwiftProyecto into their applications to work with content projects programmatically.

---

## Table of Contents

1. [Library Overview](#library-overview)
2. [Core Components](#core-components)
3. [Common Workflows](#common-workflows)
4. [Generating PROJECT.md from a Directory](#generating-projectmd-from-a-directory)
5. [Reading and Writing PROJECT.md Files](#reading-and-writing-projectmd-files)
6. [File Discovery and Access](#file-discovery-and-access)
7. [Working with SwiftData Models](#working-with-swiftdata-models)
8. [Integration Patterns](#integration-patterns)
9. [Best Practices](#best-practices)

---

## Library Overview

**SwiftProyecto** is a Swift package that provides:

- **PROJECT.md Parsing**: Read and write structured project metadata in YAML front matter
- **File Discovery**: Recursively discover files in project directories
- **Project Service**: Manage projects, discover files, and provide secure file access
- **CLI Tool (proyecto)**: LLM-powered PROJECT.md generation from directory analysis
- **SwiftData Models**: Persistent storage of project metadata and file references
- **Security**: Security-scoped bookmarks for sandboxed file access (macOS/iOS)

**When to use SwiftProyecto:**
- ✅ Your app needs to understand content project structure
- ✅ You want to store project-specific settings and metadata
- ✅ You need to discover and access files in a project folder
- ✅ You're building tools for podcasts, screenplays, or content production

**When NOT to use SwiftProyecto:**
- ❌ You only need to parse individual document files (use SwiftCompartido)
- ❌ You don't care about project metadata or structure
- ❌ You're building a simple file browser without project context

---

## Core Components

### 1. ProjectMarkdownParser

Parses and generates PROJECT.md files with YAML front matter.

**Key Methods:**
- `parse(fileURL:)` → Reads a PROJECT.md file and returns `(ProjectFrontMatter, String)`
- `parse(content:)` → Parses markdown string directly
- `generate(frontMatter:body:)` → Generates PROJECT.md content string from metadata
- `write(frontMatter:body:to:)` → Atomically writes PROJECT.md file

**Example:**

```swift
import SwiftProyecto

let parser = ProjectMarkdownParser()

// Read existing PROJECT.md
let projectURL = URL(fileURLWithPath: "/path/to/PROJECT.md")
let (frontMatter, body) = try parser.parse(fileURL: projectURL)

print("Project: \(frontMatter.title)")
print("Author: \(frontMatter.author)")
```

### 2. ProjectDiscovery

Locates PROJECT.md files from any file or directory path.

**Key Methods:**
- `findProjectMd(from:)` → Finds PROJECT.md starting from a file or directory

**Search Strategy:**
1. Check current directory for PROJECT.md
2. Check parent directory (for files inside episodes folder)
3. Check common project structure locations

**Example:**

```swift
import SwiftProyecto

let discovery = ProjectDiscovery()

// Find PROJECT.md from any file path
let screenplayURL = URL(fileURLWithPath: "/projects/podcast/episodes/episode-01.fountain")
if let projectMdURL = discovery.findProjectMd(from: screenplayURL) {
    print("Found PROJECT.md at: \(projectMdURL.path)")
}
```

### 3. ProjectService

Manages projects, discovers files, and provides secure file access.

**Key Methods:**
- `createProject(at:title:author:)` → Creates a new project with PROJECT.md
- `openProject(at:)` → Opens an existing project and loads metadata
- `discoverFiles(for:)` → Discovers all files in the project directory
- `syncFiles(for:)` → Synchronizes file state with filesystem
- `getSecureURL(for:in:)` → Gets a security-scoped URL for file access
- `readCast(from:filterByProvider:)` → Reads cast list with optional provider filtering

**Example:**

```swift
import SwiftProyecto
import SwiftData

@MainActor
func setupProject() async throws {
    let modelContext = /* SwiftData ModelContext */
    let service = ProjectService(modelContext: modelContext)
    
    // Create new project
    let projectURL = URL(fileURLWithPath: "/path/to/project")
    let project = try await service.createProject(
        at: projectURL,
        title: "My Podcast",
        author: "Jane Showrunner"
    )
    
    // Discover files
    try service.discoverFiles(for: project)
    
    // Get secure URL for a file
    let fileRef = project.fileReferences.first!
    let secureURL = try service.getSecureURL(for: fileRef, in: project)
}
```

### 4. ProjectFrontMatter

Core model representing PROJECT.md front matter metadata.

**Common Fields:**
- `type` (String) - Always "project"
- `title` (String) - Project title
- `author` (String) - Author/creator
- `created` (Date) - Creation timestamp
- `description` (String?) - Long-form description
- `season` (Int?) - Season number
- `episodes` (Int?) - Episode count
- `genre` (String?) - Project genre
- `tags` ([String]?) - Project tags
- `episodesDir` (String?) - Episodes folder (default: "episodes")
- `audioDir` (String?) - Audio output folder (default: "audio")
- `filePattern` (FilePattern?) - File patterns to match
- `exportFormat` (String?) - Export format (m4a, mp3, wav, etc.)
- `cast` ([CastMember]?) - Character-to-voice mappings
- `preGenerateHook` (String?) - Pre-generation shell command
- `postGenerateHook` (String?) - Post-generation shell command

**Convenience Accessors:**
- `resolvedEpisodesDir` - Episodes directory with defaults applied
- `resolvedAudioDir` - Audio directory with defaults applied
- `resolvedFilePatterns` - File patterns as array (handles single string)
- `resolvedExportFormat` - Export format with default applied

**Modifying Cast List:**

```swift
var frontMatter = /* existing */

// Add a cast member
let newMember = CastMember(
    character: "HERO",
    actor: "Actor Name",
    gender: .male,
    voiceDescription: "Deep, heroic baritone",
    voices: ["apple": "com.apple.voice.compact.en-US.Aaron"]
)

let updatedFrontMatter = frontMatter.withCast([newMember])
// Or merge with existing:
let merged = try frontMatter.mergingCast([newMember], forProvider: "apple")
```

### 5. CastMember

Character-to-voice mapping for audio generation.

**Fields:**
- `character` (String) - Character/role name
- `actor` (String?) - Actor/performer name
- `gender` (Gender?) - Character gender (M, F, NB, NS)
- `voiceDescription` (String?) - Voice selection guidance (e.g., "warm baritone")
- `voices` ([String: String]) - Provider → voice ID mappings

**Voice Providers:**
```swift
let castMember = CastMember(
    character: "NARRATOR",
    actor: "Tom Stovall",
    gender: .male,
    voices: [
        "apple": "com.apple.voice.compact.en-US.Aaron",
        "elevenlabs": "21m00Tcm4TlvDq8ikWAM",
        "voxalta": "narrator-voice-1"
    ]
)
```

---

## Common Workflows

### Workflow 1: Parse Existing PROJECT.md

```swift
import SwiftProyecto

func loadProject(at path: String) throws {
    let projectURL = URL(fileURLWithPath: path)
    let parser = ProjectMarkdownParser()
    
    let (frontMatter, body) = try parser.parse(fileURL: projectURL)
    
    print("Title: \(frontMatter.title)")
    print("Author: \(frontMatter.author)")
    print("Episodes: \(frontMatter.episodes ?? 0)")
    print("Cast: \(frontMatter.cast?.count ?? 0) members")
}
```

### Workflow 2: Create and Write PROJECT.md

```swift
import SwiftProyecto

func createProject() throws {
    let parser = ProjectMarkdownParser()
    
    // Create front matter
    var frontMatter = ProjectFrontMatter(
        type: "project",
        title: "My Screenplay",
        author: "John Doe",
        created: Date()
    )
    
    // Add metadata
    frontMatter.description = "A thrilling drama"
    frontMatter.genre = "Drama"
    frontMatter.season = 1
    frontMatter.episodes = 8
    frontMatter.tags = ["drama", "thriller"]
    
    // Add cast
    frontMatter.cast = [
        CastMember(
            character: "ALICE",
            actor: "Alice Actor",
            gender: .female,
            voices: ["apple": "com.apple.voice.compact.en-US.Samantha"]
        )
    ]
    
    // Generate and write
    let projectURL = URL(fileURLWithPath: "/path/to/PROJECT.md")
    try parser.write(
        frontMatter: frontMatter,
        body: "# My Screenplay\n\nProject description here...",
        to: projectURL
    )
}
```

### Workflow 3: Find and Load PROJECT.md from Any File

```swift
import SwiftProyecto

func loadProjectFromAnywhere(filePath: String) throws {
    let fileURL = URL(fileURLWithPath: filePath)
    let discovery = ProjectDiscovery()
    
    // Find PROJECT.md from any file or directory
    guard let projectMdURL = discovery.findProjectMd(from: fileURL) else {
        throw NSError(domain: "ProjectNotFound", code: -1)
    }
    
    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: projectMdURL)
    
    print("Found project: \(frontMatter.title)")
}
```

### Workflow 4: Discover Files in Project

```swift
import SwiftProyecto
import SwiftData

@MainActor
func discoverProjectFiles() async throws {
    let modelContext = /* SwiftData ModelContext */
    let service = ProjectService(modelContext: modelContext)
    
    let projectURL = URL(fileURLWithPath: "/path/to/project")
    let project = try await service.openProject(at: projectURL)
    
    // Discover files matching patterns
    try service.discoverFiles(for: project)
    
    // Access discovered files
    for fileRef in project.fileReferences {
        print("Found: \(fileRef.name)")
        
        // Get secure URL for file access
        let secureURL = try service.getSecureURL(for: fileRef, in: project)
        // Use secureURL to read/parse file
    }
}
```

---

## Generating PROJECT.md from a Directory

There are two approaches: **CLI (automated)** and **programmatic (manual)**.

### Approach 1: Using `proyecto` CLI (Recommended)

The `proyecto` CLI uses an LLM (Apple Foundation Models) to intelligently analyze a directory and generate PROJECT.md metadata.

**Installation:**

```bash
cd /path/to/SwiftProyecto
make install
```

**Usage:**

```bash
# Generate PROJECT.md in a directory
proyecto generate /path/to/project

# With author override (skip LLM author detection)
proyecto generate /path/to/project --author "Your Name"

# Validate existing PROJECT.md
proyecto validate /path/to/PROJECT.md --verbose
```

**What `proyecto generate` Does:**

1. **Analyzes directory structure** - Counts files, scans content, identifies patterns
2. **Queries LLM iteratively** - Each section (title, description, genre, etc.) gets one independent query
3. **Extracts metadata** - Parses LLM responses into structured metadata
4. **Generates PROJECT.md** - Creates file with YAML front matter + body
5. **Saves to directory** - Writes to `/path/to/project/PROJECT.md`

**Example Output:**

```bash
$ proyecto generate ~/Projects/my-podcast

Analyzing directory structure...
✓ Title: Podcast Meditations: Mindfulness and Self-Care
✓ Description: A year-long journey through...
✓ Genre: Documentary
✓ Episodes: 365
✓ Created: 2025-06-12T14:23:00Z
✓ Cast: 3 characters detected
✓ Tags: [mindfulness, self-care, meditation]

PROJECT.md created at: ~/Projects/my-podcast/PROJECT.md
```

### Approach 2: Programmatic Generation

For custom generation logic, use the library directly:

```swift
import SwiftProyecto

func generateProjectMetadata() throws {
    let parser = ProjectMarkdownParser()
    
    // Analyze directory manually
    let projectURL = URL(fileURLWithPath: "/path/to/project")
    let fileManager = FileManager.default
    
    let contents = try fileManager.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil)
    let fountainFiles = contents.filter { $0.pathExtension == "fountain" }
    
    // Create front matter with your analysis
    var frontMatter = ProjectFrontMatter(
        type: "project",
        title: "My Project",  // Your analysis here
        author: "Your Name",  // Your analysis here
        created: Date()
    )
    
    frontMatter.episodes = fountainFiles.count
    frontMatter.filePattern = FilePattern(patterns: ["*.fountain"])
    
    // Write to PROJECT.md
    let projectMdURL = projectURL.appendingPathComponent("PROJECT.md")
    try parser.write(frontMatter: frontMatter, body: "# Description", to: projectMdURL)
}
```

### Approach 3: LLM-Powered Programmatic Generation

For advanced integration, use Foundation Models directly:

```swift
import SwiftProyecto
import FoundationModels

func generateWithLLM(directory: URL) async throws {
    // Analyze directory
    let fileManager = FileManager.default
    let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    let scriptFiles = contents.filter { $0.pathExtension == "fountain" }
    
    // Query LLM
    let prompt = """
    Analyze this directory and suggest a title:
    - Contains \(scriptFiles.count) screenplay files
    - Files: \(scriptFiles.map { $0.lastPathComponent }.joined(separator: ", "))
    
    Suggest a one-line title for this project.
    """
    
    // Use Foundation Models API...
    let response = try await queryLLM(prompt)
    
    // Build front matter from response
    var frontMatter = ProjectFrontMatter(
        type: "project",
        title: response.trimmed,
        author: "Generated",
        created: Date()
    )
    
    // Write file
    let parser = ProjectMarkdownParser()
    let projectMdURL = directory.appendingPathComponent("PROJECT.md")
    try parser.write(frontMatter: frontMatter, body: "", to: projectMdURL)
}
```

---

## Reading and Writing PROJECT.md Files

### Reading PROJECT.md

```swift
import SwiftProyecto

let parser = ProjectMarkdownParser()

// From file
let (frontMatter, body) = try parser.parse(fileURL: projectURL)

// From string
let content = """
---
type: project
title: My Project
author: Jane Doe
created: 2025-06-12T00:00:00Z
---

# Description here
"""
let (frontMatter, body) = try parser.parse(content: content)

// Access fields with defaults
let title = frontMatter.title
let episodes = frontMatter.episodes ?? 0
let patterns = frontMatter.resolvedFilePatterns  // Returns array
let audioDir = frontMatter.resolvedAudioDir      // Returns default if nil
```

### Writing PROJECT.md

```swift
import SwiftProyecto

let parser = ProjectMarkdownParser()

var frontMatter = ProjectFrontMatter(
    type: "project",
    title: "My Project",
    author: "Author Name",
    created: Date()
)

// Add optional fields
frontMatter.description = "Project description"
frontMatter.genre = "Drama"
frontMatter.tags = ["drama", "thriller"]
frontMatter.cast = [/* cast members */]

// Write to file
try parser.write(
    frontMatter: frontMatter,
    body: "# Project Body",
    to: projectURL
)

// Or just generate content string
let content = parser.generate(frontMatter: frontMatter, body: "Body")
try content.write(to: projectURL, atomically: true, encoding: .utf8)
```

### Modifying Cast List

```swift
import SwiftProyecto

let parser = ProjectMarkdownParser()
let (var frontMatter, body) = try parser.parse(fileURL: projectURL)

// Replace entire cast
let newCast = [/* new cast members */]
frontMatter = frontMatter.withCast(newCast)

// Merge with existing cast
let additionalMembers = [/* new members */]
frontMatter = try frontMatter.mergingCast(additionalMembers, forProvider: "apple")

// Write updated PROJECT.md
try parser.write(frontMatter: frontMatter, body: body, to: projectURL)
```

---

## File Discovery and Access

### Discovering Files

```swift
import SwiftProyecto
import SwiftData

@MainActor
func discoverFiles() async throws {
    let modelContext = /* ModelContext */
    let service = ProjectService(modelContext: modelContext)
    
    let projectURL = URL(fileURLWithPath: "/path/to/project")
    let project = try await service.openProject(at: projectURL)
    
    // Discover all files matching patterns
    try service.discoverFiles(for: project)
    
    // Filter discovered files
    let screenplays = project.fileReferences.filter { ref in
        ref.extension == "fountain"
    }
    
    // Build navigation tree
    let tree = project.fileTree()
    print(tree.debugDescription)
}
```

### Accessing Files Securely

```swift
import SwiftProyecto

let service = ProjectService(modelContext: context)

// Get secure URL for file access
let fileRef = project.fileReferences.first!
let secureURL = try service.getSecureURL(for: fileRef, in: project)

// Use secure URL to read file
let content = try String(contentsOf: secureURL, encoding: .utf8)

// For sandboxed apps, the URL is security-scoped
// No need to call startAccessingSecurityScopedResource - SwiftProyecto handles it
```

### Reading Cast List

```swift
import SwiftProyecto

let service = ProjectService(modelContext: context)

// Read all cast members
let allCast = try service.readCast(from: project)

// Filter cast by provider (e.g., only Apple TTS voices)
let appleVoices = try service.readCast(from: project, filterByProvider: "apple")

// Use filtered cast for TTS generation
for member in appleVoices {
    if let appleVoice = member.voices["apple"] {
        // Use this voice for TTS
        print("\(member.character) → \(appleVoice)")
    }
}
```

---

## Working with SwiftData Models

### ProjectModel

Persistent SwiftData model representing a project folder.

```swift
import SwiftProyecto
import SwiftData

@Model
final class ProjectModel {
    // From PROJECT.md front matter
    var title: String
    var author: String
    var created: Date
    var description: String?
    var season: Int?
    var episodes: Int?
    var genre: String?
    var tags: [String]?
    
    // File discovery
    @Relationship(deleteRule: .cascade) var fileReferences: [ProjectFileReference]
    
    // File tree for navigation
    func fileTree() -> FileNode { /* ... */ }
    
    // Access security-scoped bookmark
    var bookmarkData: Data?
}
```

### ProjectFileReference

Persistent model for discovered files.

```swift
import SwiftProyecto
import SwiftData

@Model
final class ProjectFileReference {
    var name: String
    var path: String
    var `extension`: String
    var modificationDate: Date?
    var bookmarkData: Data?
    
    var isDirectory: Bool { /* ... */ }
}
```

### Querying SwiftData

```swift
import SwiftData

@MainActor
func queryProjects() throws {
    let descriptor = FetchDescriptor<ProjectModel>()
    let projects = try modelContext.fetch(descriptor)
    
    // Filter by author
    let myProjects = projects.filter { $0.author == "Tom Stovall" }
    
    // Sort by creation date
    let recent = projects.sorted { $0.created > $1.created }
}
```

---

## Integration Patterns

### Pattern 1: SwiftUI View with Project

```swift
import SwiftUI
import SwiftProyecto
import SwiftData

struct ProjectDetailView: View {
    @Environment(\.modelContext) var modelContext
    @State var project: ProjectModel
    @State var files: [ProjectFileReference] = []
    
    var body: some View {
        List {
            Section("Project Info") {
                Text("Title: \(project.title)")
                Text("Author: \(project.author)")
                if let episodes = project.episodes {
                    Text("Episodes: \(episodes)")
                }
            }
            
            Section("Files") {
                ForEach(files) { file in
                    Text(file.name)
                }
            }
        }
        .onAppear {
            let service = ProjectService(modelContext: modelContext)
            files = project.fileReferences
        }
    }
}
```

### Pattern 2: Batch Processing

```swift
import SwiftProyecto

func processAllProjectFiles(project: ProjectModel) async throws {
    let service = ProjectService(modelContext: modelContext)
    
    for fileRef in project.fileReferences {
        let secureURL = try service.getSecureURL(for: fileRef, in: project)
        
        // Process file (e.g., parse screenplay)
        let content = try String(contentsOf: secureURL, encoding: .utf8)
        let parsed = try parseScreenplay(content)
        
        // Store results
        try await saveResults(parsed)
    }
}
```

### Pattern 3: Generating PROJECT.md for New Projects

```swift
import SwiftProyecto

func createNewProject(path: String) async throws {
    // Use proyecto CLI for LLM-powered generation
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/proyecto")
    process.arguments = ["generate", path]
    try process.run()
    process.waitUntilExit()
    
    // Then load the generated PROJECT.md
    let projectURL = URL(fileURLWithPath: path)
    let parser = ProjectMarkdownParser()
    let projectMdURL = projectURL.appendingPathComponent("PROJECT.md")
    let (frontMatter, _) = try parser.parse(fileURL: projectMdURL)
    
    return frontMatter
}
```

---

## Best Practices

### 1. Always Use Security-Scoped Bookmarks

For sandboxed apps (macOS/iOS), use ProjectService's bookmark management:

```swift
// ✅ GOOD - Let ProjectService handle bookmarks
let secureURL = try service.getSecureURL(for: fileRef, in: project)

// ❌ AVOID - Direct file access
let unsafeURL = URL(fileURLWithPath: fileRef.path)
let content = try String(contentsOf: unsafeURL, encoding: .utf8)  // May fail in sandbox
```

### 2. Use Resolved Accessors for Defaults

```swift
// ✅ GOOD - Use resolved accessors with defaults
let audioDir = frontMatter.resolvedAudioDir  // Returns "audio" if nil
let patterns = frontMatter.resolvedFilePatterns  // Returns array

// ❌ AVOID - Checking optionals everywhere
if let audioDir = frontMatter.audioDir {
    // ...
} else {
    let audioDir = "audio"  // Duplicating defaults
}
```

### 3. Use ProjectDiscovery to Find PROJECT.md

```swift
// ✅ GOOD - Works from any file path
let discovery = ProjectDiscovery()
let projectMdURL = discovery.findProjectMd(from: screenplayURL)

// ❌ AVOID - Assuming specific directory structure
let projectURL = screenplayURL.deletingLastPathComponent().deletingLastPathComponent()
let projectMdURL = projectURL.appendingPathComponent("PROJECT.md")
```

### 4. Validate Required Fields

```swift
// ✅ GOOD - Validate before using
if !frontMatter.title.isEmpty && !frontMatter.author.isEmpty {
    // Process project
}

// ❌ AVOID - Assuming fields are valid
let title = frontMatter.title  // Could be empty
```

### 5. Use Batch Mode for Large Projects

```swift
// ✅ GOOD - Process files in batches for efficiency
let batch = project.fileReferences.prefix(10)
for fileRef in batch {
    // Process
}

// ❌ AVOID - Loading all files at once (memory-intensive)
for fileRef in project.fileReferences {
    let content = try String(contentsOf: ...)  // Could exhaust memory
}
```

### 6. Filter Cast by Provider

```swift
// ✅ GOOD - Use provider-specific cast
let appleVoices = try service.readCast(from: project, filterByProvider: "apple")
for member in appleVoices {
    // All members have "apple" voice defined
}

// ❌ AVOID - Checking optionals for each member
for member in allCast {
    if let voice = member.voices["apple"] {
        // Handle presence
    }
}
```

### 7. Use `projeto` CLI for Generation

```bash
# ✅ GOOD - Leverage LLM-powered analysis
proyecto generate /path/to/project --author "Your Name"

# ❌ AVOID - Manual metadata creation without analysis
# Creates generic/inaccurate PROJECT.md
```

---

## Troubleshooting

### PROJECT.md Not Found

```swift
let discovery = ProjectDiscovery()
if discovery.findProjectMd(from: fileURL) == nil {
    // Check:
    // 1. PROJECT.md exists in directory tree
    // 2. File path is correct
    // 3. Try searching from parent directory
}
```

### File Access Denied in Sandbox

```swift
// Use ProjectService for secure access
let secureURL = try service.getSecureURL(for: fileRef, in: project)
// Don't use direct file URLs
```

### Invalid DATE Format

```swift
// Dates must be ISO 8601 format
let formatter = ISO8601DateFormatter()
let dateString = formatter.string(from: Date())  // "2025-06-12T14:23:00Z"
```

### Cast Member Voice Not Found

```swift
let member = frontMatter.cast?.first!
if let voice = member?.voices["apple"] {
    // Voice exists for this provider
} else {
    // Add voice or use different provider
}
```

---

## See Also

- **[PROJECT_MD_REFERENCE.md](PROJECT_MD_REFERENCE.md)** — Quick reference for front matter schema
- **[EXTENDING_PROJECT_MD.md](EXTENDING_PROJECT_MD.md)** — Adding app-specific settings
- **[AGENTS.md](../AGENTS.md)** — Full API documentation
- **[EXAMPLE_PROJECT.md](../EXAMPLE_PROJECT.md)** — Example PROJECT.md file


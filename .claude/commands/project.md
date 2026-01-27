# Project Context Skill

## Purpose & Intent

This skill defines a **Screenplay Breakdown Schema** for extracting semantic production data from screenplay projects. It is designed to be:

1. **Reusable** - Works with any screenplay, podcast, or audio drama project
2. **Machine-Readable** - YAML frontmatter can be parsed by Swift/MLX applications
3. **Generatable** - An LLM can generate a PROJECT.md from a folder of content files
4. **Queryable** - An onboard language model can answer questions about the project structure

### Integration Path

```
┌─────────────────────────────────────────────────────────────────┐
│  Produciesta (macOS/iOS App)                                    │
│  └── Onboard MLX Language Model                                 │
│      └── Can query and generate PROJECT.md files                │
│                         │                                       │
│                         ▼                                       │
│  SwiftProyecto (Swift Library Dependency)                       │
│  └── Owns the PROJECT.md schema definition                      │
│  └── Provides parsing/generation utilities                      │
│                         │                                       │
│                         ▼                                       │
│  Any Screenplay Project Folder                                  │
│  └── PROJECT.md (generated or hand-maintained)                  │
│  └── *.fountain, *.highland, *.fdx content files                │
└─────────────────────────────────────────────────────────────────┘
```

### Capabilities

The skill (and any system implementing this schema) should be able to:

| Capability | Description |
|------------|-------------|
| **Parse** | Read an existing PROJECT.md and extract structured data |
| **Generate** | Scan a folder of content files and create a new PROJECT.md |
| **Rebuild** | Update specific sections from content files |
| **Query** | Answer natural language questions about project structure |
| **Validate** | Check PROJECT.md against actual content files for drift |

### Schema Version

This skill defines **Screenplay Breakdown Schema v1.0**.

Future versions should maintain backward compatibility or provide migration paths.

---

## Instructions

When this skill is invoked, look for a PROJECT.md file in the current working directory (or specified project folder) and provide context-aware assistance.

1. First, read `PROJECT.md` from the project root to load the project metadata.

2. Parse the YAML frontmatter to understand:
   - Project intent and format
   - File organization and chapter structure
   - Character voice mappings
   - Audio export configuration
   - Scene breakdown by location

3. Based on what the user needs, provide relevant context:

### For General Context
Summarize the project intent, current chapter structure, and any incomplete items.

### For Audio/Voice Work
Focus on the `voices` section. Present character-to-voice mappings and any TTS configuration. Help generate voice mapping files for MLX or other TTS pipelines.

### For Chapter Navigation
Use the `files.chapters` section to help locate specific scenes, characters, or plot points across chapter files.

### For Scene Breakdown / Locations
Use the `scenes` section which organizes scenes hierarchically by:

1. **LOCATION** - The primary location (e.g., SYLVIA'S HOUSE, GYM, RESTAURANT)
2. **LIGHTING** - INT, EXT, or INT/EXT
3. **AREA** - Specific area within location (e.g., KITCHEN, HALLWAY, POOL)
4. **TIME** - DAY, NIGHT, CONTINUOUS, LATER, etc.

#### Slugline Parsing Rules

Fountain sluglines follow patterns like:
```
INT. LOCATION - TIME
INT. LOCATION - AREA - TIME
EXT. LOCATION - TIME
INT/EXT. LOCATION - TIME
```

Parse sluglines as follows:
- **Lighting**: First element (INT, EXT, INT/EXT, I/E)
- **Location**: Text after the period, before the first hyphen (trimmed)
- **Area**: If there are 2+ hyphens, middle segment(s) are the area
- **Time**: Final segment after last hyphen (DAY, NIGHT, CONTINUOUS, LATER, MORNING, EVENING, etc.)

Examples:
| Slugline | Location | Lighting | Area | Time |
|----------|----------|----------|------|------|
| `INT. SYLVIA'S HOUSE - KITCHEN - DAY` | Sylvia's House | INT | Kitchen | Day |
| `EXT. PALM SPRINGS STREET - NIGHT` | Palm Springs Street | EXT | - | Night |
| `INT/EXT. CAR - CONTINUOUS` | Car | INT/EXT | - | Continuous |
| `INT. GYM - STEAM ROOM - DAY` | Gym | INT | Steam Room | Day |
| `INT. MEAN JEAN'S CERAMICS - BACK OFFICE - DAY` | Mean Jean's Ceramics | INT | Back Office | Day |
| `INT. THERAPIST'S OFFICE - DAY (PRESENT)` | Therapist's Office | INT | - | Day |
| `EST. CEMETERY - DAY` | Cemetery | EST | - | Day |

#### Special Cases

- **EST** (establishing shots): These are NOT regular scenes. They set up a location visually before cutting to the actual scene. Store separately under `establishing` key at each location, not under INT/EXT.
- **Time modifiers**: Strip parentheticals like `(PRESENT)` or `(FLASHBACK)` - these are narrative context, not lighting
- **CONTINUOUS/LATER**: Valid time values indicating scene flow
- **Location normalization**: When indexing, suggest consolidating similar locations:
  - HOME, HOUSE → Sylvia's House (if referring to same place)
  - CABARET, CABARET CLUB → Cabaret (if same venue)
- **_default area**: Use when no specific area is mentioned in the slugline

#### Establishing Shots

Establishing shots (EST) introduce a location visually before the actual scene begins. They should be:
1. Stored separately from INT/EXT scene shots
2. Listed at the head of any location breakdown
3. Associated with the scene that follows them

Structure:
```yaml
"Cemetery":
  establishing:
    - {chapter: 1, time: DAY, line: 393, leads_to: {lighting: EXT, line: 408}}
  EXT:
    _default:
      - {chapter: 1, time: DAY, line: 408}
```

When presenting a scene breakdown, always show establishing shots first:
```
CEMETERY
  EST. CEMETERY - DAY (line 393) → leads to EXT scene
  ────────────────────────────────
  EXT:
    - DAY (line 408)
```

### For Continuity Checks
Cross-reference character details, plot threads, and timeline information to identify inconsistencies.

## Available Subcommands

The user may invoke this skill with arguments:

- `/project` - General project overview and status
- `/project characters` - All speaking characters with gender and dialogue counts
- `/project voices` - Voice mappings and TTS configuration
- `/project chapters` - Chapter structure and file relationships
- `/project scenes` - Scene breakdown by location hierarchy
- `/project locations` - List all unique locations across the project
- `/project audio` - Audio export settings and production notes
- `/project [character name]` - Details about a specific character
- `/project [location name]` - All scenes at a specific location

### Rebuild Commands

Each section of PROJECT.md can be rebuilt independently or all at once.

#### Rebuild All Sections
- `/project --rebuild-all` - Rebuild all sections from chapter files

#### Individual Section Rebuilds

| Command | Section | Description |
|---------|---------|-------------|
| `/project chapters --rebuild` | `files.chapters` | Scan for chapter files, update status (complete/incomplete) |
| `/project voices --rebuild` | `voices` | Extract character names from dialogue, update voice list |
| `/project scenes --rebuild` | `scenes` | Parse sluglines, build location hierarchy, link establishing shots |
| `/project status --rebuild` | `status` | Update chapter counts, scan for dangling threads |

#### Individual Section Rebuilds (continued)

| Command | Section | Description |
|---------|---------|-------------|
| `/project characters --rebuild` | `characters` | Extract all speaking characters, normalize names, find gender from introductions |

#### Sections Not Rebuilt (Configuration Only)

These sections are manually configured, not derived from files:

| Section | Purpose |
|---------|---------|
| `intent` | Project format, medium, themes - editorial decisions |
| `audio_export` | TTS configuration, export format preferences |
| `scenes.aliases` | Location name normalization rules |
| `characters.aliases` | Character name normalization rules |

#### Character-Specific Commands

- `/project characters --by-gender` - Group characters by gender (M/F/NB/NS)
- `/project characters --by-chapter` - Show which characters appear in each chapter
- `/project characters --dialogue-counts` - Sort by number of dialogue lines
- `/project characters --missing-gender` - List characters with NS (not specified) gender

#### Scene-Specific Commands

- `/project scenes --by-time` - Group scenes by time of day (DAY/NIGHT)
- `/project scenes --by-lighting` - Group scenes by INT/EXT
- `/project scenes --with-establishing` - Show only locations that have establishing shots

### Scene Breakdown Display Format

When displaying a location's scene breakdown, always present establishing shots first:

```
CEMETERY (Chapter 1)
══════════════════════════════════════
ESTABLISHING: EST. CEMETERY - DAY (line 393)
  └─→ leads to: EXT scene at line 408
──────────────────────────────────────
SCENES:
  EXT:
    • DAY (line 408)
```

This makes it clear which shots set up a location vs. which shots are the actual scenes.

## Response Format

After loading the metadata:
1. Acknowledge what context was loaded
2. Provide the relevant information based on the request
3. Offer to help with specific tasks related to that context

## Section Rebuild Instructions

Each section has specific parsing rules and update procedures.

---

### Rebuilding All Sections

When the user requests `/project --rebuild-all`:

1. Run each section rebuild in order:
   - chapters (must be first - determines which files to scan)
   - characters (extracts speaking roles from content)
   - voices (builds on characters, adds TTS config)
   - scenes (parses sluglines)
   - status (must be last - summarizes state of other sections)
2. Update the `updated` timestamp in the frontmatter
3. Report what changed in each section

---

### Rebuilding the Chapters Index

When the user requests `/project chapters --rebuild`:

1. Glob for files matching the chapter pattern (default: `Chapter *.fountain`)
2. For each chapter file:
   - Extract chapter number from filename
   - Read first ~50 lines to find focus character (look for `>_CHARACTER_<` pattern)
   - Check if file contains `## END CHAPTER` to determine if complete
   - Look for section headers (`###`) to extract chapter intent
3. Update `files.chapters.items` with findings
4. Update any chapter that's missing or has changed status

---

### Rebuilding the Characters Index

When the user requests `/project characters --rebuild`:

1. Read all content files (see Content File Types below)
2. Extract all CHARACTER names from dialogue cues
3. Normalize names by removing parentheticals: `(V.O.)`, `(O.S.)`, `(CONT'D)`, `(O.C.)`, `^`, etc.
4. Find character introductions in action/description lines to extract gender
5. Build complete character list with dialogue line counts and gender

#### Content File Types

These file types contain project content and should be scanned:

| Extension | Format | Notes |
|-----------|--------|-------|
| `.fountain` | Fountain screenplay | Primary format |
| `.highland` | Highland app | Fountain-based |
| `.fdx` | Final Draft | XML-based screenplay |
| `.markdown`, `.md` | Markdown | Exclude PROJECT.md and CLAUDE.md |

#### Character Name Normalization

Strip these from character names to get the canonical name:

| Pattern | Example | Normalized |
|---------|---------|------------|
| `(V.O.)` | `BERNARD (V.O.)` | BERNARD |
| `(O.S.)` | `SYLVIA (O.S.)` | SYLVIA |
| `(O.C.)` | `KILLIAN (O.C.)` | KILLIAN |
| `(CONT'D)` | `MASON (CONT'D)` | MASON |
| `^` | `BERNARD ^` | BERNARD |
| Any parenthetical | `DONNIE (on phone)` | DONNIE |

#### Character Introduction Pattern

When a character is introduced in action lines, they typically appear as:

```
CHARACTER NAME (age/gender description)
```

Examples:
- `BERNARD (40's M)` → Gender: M
- `SYLVIA (60's F)` → Gender: F
- `DOG WALKER (50's M)` → Gender: M
- `THE PROMOTER (50s M)` → Gender: M
- `MADISSYN UNICORN (20s F)` → Gender: F
- `TROLLING MOURNER` → Gender: NS (not specified)

Gender codes:
- `M` - Male
- `F` - Female
- `NB` - Non-binary (if specified)
- `NS` - Not specified

#### Character Aliases

Use `characters.aliases` to normalize variant names:

```yaml
characters:
  aliases:
    "Donnie Lanier": [DONNIE, "DONNIE LANIER"]
    "Mickey Blaze": [MICKEY, "MICKEY BLAZE"]
    "Violet": [V, "VIOLET", 'VIOLET "V"']
```

---

### Rebuilding the Voices Index

When the user requests `/project voices --rebuild`:

1. First ensure characters section is up to date (run characters rebuild if needed)
2. For each character in the `characters` list:
   - If already in `voices` section, preserve existing data (voice_id, description, tone)
   - If new character, add with null voice_id and empty description/tone
3. Copy gender from characters section if not already set
4. Flag characters in voices section that no longer appear in any chapter

The voices section is a superset of characters with additional TTS configuration.

---

### Rebuilding the Status Section

When the user requests `/project status --rebuild`:

1. Count chapters with status: complete vs incomplete
2. Scan for TODO markers, incomplete sections, placeholder text
3. Update `dangling_threads` by looking for:
   - Chapters marked incomplete
   - Unresolved plot points (look for NOTE: or TODO: comments)
   - Characters introduced but not developed
4. Update `chapters_complete` and `chapters_total` counts

---

### Rebuilding the Scene Index

When the user requests `/project scenes --rebuild`:

1. Read all chapter files matching the chapter pattern
2. Extract all sluglines (lines starting with INT, EXT, INT/EXT, I/E, or EST followed by a period)
3. Parse each slugline using the rules above
4. Apply location aliases from `scenes.aliases` to normalize location names
5. **Handle establishing shots specially**:
   - When an EST shot is found, look ahead to find the next scene slugline
   - Store the EST under `establishing` with a `leads_to` reference to the following scene
   - The following scene is stored normally under INT/EXT
6. Group remaining scenes by LOCATION, then by LIGHTING, then by AREA
7. Update the `scenes` section in PROJECT.md with the structured data
8. Update `last_rebuilt` timestamp and `indexed_chapters` list

### Location Aliases

The `scenes.aliases` section maps canonical location names to their variations:

```yaml
aliases:
  "Sylvia's House": [HOME, HOUSE, "HOUSE POOL AREA"]
  "Cabaret": [CABARET, "CABARET CLUB"]
  "Gym": [GYM, "STEAM ROOM", SAUNA]
```

When rebuilding, check each parsed location against aliases. If it matches an alias value, use the canonical name (the key) instead.

The scenes structure in PROJECT.md should follow this format:

```yaml
scenes:
  locations:
    "Sylvia's House":
      # No establishing shots for this location
      INT:
        Kitchen:
          - {chapter: 1, time: DAY, line: 45}
          - {chapter: 6, time: NIGHT, line: 102}
        Living Room:
          - {chapter: 1, time: DAY, line: 20}
      EXT:
        Driveway:
          - {chapter: 1, time: DAY, line: 180}

    "Cemetery":
      # Establishing shot listed first, separate from scenes
      establishing:
        - chapter: 1
          time: DAY
          line: 393
          leads_to:
            lighting: EXT
            line: 408
      EXT:
        _default:
          - {chapter: 1, time: DAY, line: 408}

    "Gym":
      establishing:
        - chapter: 2
          time: DAY
          line: 15
          leads_to:
            lighting: INT
            area: Steam Room
            line: 22
      INT:
        Steam Room:
          - {chapter: 2, time: DAY, line: 22}
        Locker Room:
          - {chapter: 2, time: DAY, line: 85}
```

## Notes

- Do NOT include this detailed metadata in responses unless specifically relevant
- Keep responses focused on what the user actually needs
- The PROJECT.md file is the source of truth - suggest updates to it when information is missing or outdated

---

## Schema Specification

This section formally defines the PROJECT.md structure for machine parsing.

### Required Fields

```yaml
---
type: project                    # Always "project"
schema_version: string           # e.g., "1.0"
title: string                    # Full project title
short_title: string              # Abbreviated title for filenames/references
author: string                   # Primary author
created: ISO8601 datetime        # When project was created
updated: ISO8601 date            # Last modification date
---
```

### Optional Sections

#### `intent` - Project Metadata
```yaml
intent:
  format: string                 # e.g., "dark comedy/thriller screenplay"
  medium: [string]               # e.g., ["screenplay", "podcast", "audio drama"]
  setting: string                # Primary location/time period
  tone: string                   # Descriptive tone
  themes: [string]               # Thematic elements
```

#### `files` - Content Organization
```yaml
files:
  last_rebuilt: ISO8601 | null
  content_patterns: [glob]       # File patterns to include
  content_excludes: [glob]       # File patterns to exclude
  chapters:
    pattern: glob
    format: string               # fountain, highland, fdx
    description: string
    items:
      - file: string
        focus: string            # POV character
        intent: string           # Chapter purpose
        status: complete | incomplete
```

#### `characters` - Speaking Roles
```yaml
characters:
  last_rebuilt: ISO8601 | null
  aliases:
    "Canonical Name": [variants]
  list:
    CharacterName:
      gender: M | F | NB | NS
      introduced_in:
        chapter: int
        line: int
      dialogue_count: int | null
```

#### `voices` - TTS Configuration
```yaml
voices:
  last_rebuilt: ISO8601 | null
  CharacterName:
    age: string
    gender: M | F | NB | NS
    description: string
    tone: string
    voice_id: string | null      # TTS voice identifier
```

#### `scenes` - Location Breakdown
```yaml
scenes:
  last_rebuilt: ISO8601 | null
  indexed_chapters: [int]
  aliases:
    "Canonical Location": [variants]
  locations:
    LocationName:
      establishing:              # Optional - EST shots
        - chapter: int
          time: string
          line: int
          leads_to:
            lighting: INT | EXT
            area: string | null
            line: int
      INT | EXT | INT/EXT:
        AreaName | _default:
          - chapter: int
            time: string
            line: int
```

#### `audio_export` - Production Config
```yaml
audio_export:
  narrator:
    voice_id: string | null
    description: string
  default_format: string         # mp3, wav, etc.
  chapter_breaks: boolean
  music_cues: boolean
  sfx_cues: boolean
```

#### `status` - Project State
```yaml
status:
  last_rebuilt: ISO8601 | null
  current_phase: string          # writing, editing, production
  chapters_complete: int
  chapters_total: int
  dangling_threads: [string]     # Unresolved plot/production items
```

### Markdown Body

After the YAML frontmatter (between `---` markers), the file may contain markdown sections:

- `## Project Intent` - Prose description of goals
- `## Plot Summary` - Narrative overview
- `## Audio Production Notes` - Production-specific guidance
- `## Continuity Notes` - Important facts for consistency

---

## Generation Instructions

When generating a PROJECT.md for a new folder:

1. **Scan for content files** matching common patterns (*.fountain, *.highland, *.fdx, *.md)
2. **Detect project type** from file contents (screenplay, podcast script, etc.)
3. **Extract metadata**:
   - Title from first file or folder name
   - Author from file metadata if available
4. **Build sections** by running rebuild logic for each:
   - chapters → characters → voices → scenes → status
5. **Generate YAML frontmatter** with all extracted data
6. **Add markdown body** with placeholder sections for manual completion

### Minimum Viable PROJECT.md

For a new project, generate at least:

```yaml
---
type: project
schema_version: "1.0"
title: "[Extracted or folder name]"
short_title: "[Abbreviated]"
author: "[Unknown]"
created: [current datetime]
updated: [current date]

files:
  content_patterns: ["*.fountain", "*.highland", "*.fdx"]
  content_excludes: ["PROJECT.md", "CLAUDE.md", "README.md", "CHANGELOG.md"]
  chapters:
    pattern: "*.fountain"
    items: []
---

## Project Intent

[To be completed]
```

---

## Swift Integration Notes

This section documents how SwiftProyecto should implement the schema.

### Recommended Swift Structure

```swift
// ProjectSchema.swift
struct ScreenplayProject: Codable {
    let type: String                    // "project"
    let schemaVersion: String           // "1.0"
    let title: String
    let shortTitle: String
    let author: String
    let created: Date
    let updated: Date

    var intent: ProjectIntent?
    var files: FileConfiguration?
    var characters: CharacterIndex?
    var voices: VoiceConfiguration?
    var scenes: SceneIndex?
    var audioExport: AudioExportConfig?
    var status: ProjectStatus?
}

struct ProjectIntent: Codable {
    let format: String?
    let medium: [String]?
    let setting: String?
    let tone: String?
    let themes: [String]?
}

// ... additional structs for each section
```

### Key Operations

```swift
protocol ProjectSchemaProvider {
    /// Parse an existing PROJECT.md file
    func parse(from url: URL) throws -> ScreenplayProject

    /// Generate a PROJECT.md from a folder of content files
    func generate(for folder: URL) throws -> ScreenplayProject

    /// Rebuild a specific section from content files
    func rebuild(section: ProjectSection, in project: inout ScreenplayProject) throws

    /// Validate PROJECT.md against actual content files
    func validate(_ project: ScreenplayProject, against folder: URL) -> [ValidationIssue]

    /// Serialize project back to PROJECT.md format
    func serialize(_ project: ScreenplayProject) -> String
}

enum ProjectSection {
    case chapters
    case characters
    case voices
    case scenes
    case status
}
```

### MLX Query Integration

When Produciesta's onboard LLM queries a project:

1. **Load**: Parse PROJECT.md into `ScreenplayProject` struct
2. **Context**: Inject relevant sections based on query type
3. **Query**: Let LLM answer using structured data
4. **Update**: If LLM suggests changes, validate and write back

Example query flow:
```
User: "Which scenes feature Bernard at night?"

1. Load PROJECT.md → ScreenplayProject
2. Extract scenes.locations where any scene has:
   - time contains "NIGHT"
   - chapter appears in characters.list["Bernard"].appears_in
3. Format response with file:line references
```

### Fountain Parsing Dependencies

SwiftProyecto should include or depend on a Fountain parser for:
- Extracting sluglines (scene headings)
- Extracting character names from dialogue
- Finding character introductions in action lines
- Detecting chapter boundaries

Consider: [Fountain-Swift](https://github.com/...) or implement minimal parser.

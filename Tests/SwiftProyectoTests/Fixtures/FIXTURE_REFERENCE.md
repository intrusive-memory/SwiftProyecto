---
type: reference
title: Test Fixture Reference
description: Screenplay fixtures for SwiftProyecto cast extraction testing
---

# Test Fixture Reference

This document describes the test screenplay fixtures available for SwiftProyecto's cast extraction tests.

## Fixtures Overview

All fixtures are minimal but valid screenplay files designed to test multi-format support in CastExtractor.

### Locations

- **sample.fdx** — Final Draft XML format
- **sample.highland** — Highland screenplay format
- **test-screenplay.fountain** — Fountain plain text format

---

## Fixture Details

### sample.fdx (Final Draft XML)

**Format**: XML-based screenplay format with structured paragraphs
**Location**: `Tests/SwiftProyectoTests/Fixtures/sample.fdx`

**Structure**:
- FinalDraft root element with Version 4
- Content wrapper with Paragraph elements
- Each paragraph has a Type attribute (Scene Heading, Action, Character, Dialogue)
- Character elements contain name only (no parentheticals in the element)
- Character names may include modifiers like "(V.O.)" or "(CONT'D)"

**Expected Character Extraction**:
```
["ALICE", "BOB", "NARRATOR"]
```

**Test Validation**:
- CastExtractor.extractCast(from: fdx_file_url) should return sorted, unique character names
- SwiftCompartido's FDXParser automatically detects the format from .fdx extension
- Regex fallback is NOT available for FDX (only for Fountain)

---

### sample.highland (Highland Format)

**Format**: Plain text screenplay format with Fountain-compatible structure
**Location**: `Tests/SwiftProyectoTests/Fixtures/sample.highland`

**Implementation Note**: SwiftCompartido's Highland parser supports two formats:
1. **ZIP-based Highland** (`.highland` files as ZIP archives containing TextBundles)
2. **Plain-text Fountain** (`.highland` files in plain Fountain text format)

For plain-text `.highland` files, SwiftCompartido's Highland initializer auto-detects whether the file is a ZIP archive by checking for the "PK" ZIP magic bytes. If not a ZIP, it treats the file as standard Fountain format.

**Structure** (Fountain-compatible format):
- Header metadata (Title, Author, etc.)
- Scene headings (INT./EXT. format)
- Action lines (narrative description)
- Character names in ALL CAPS, immediately followed by dialogue (no blank lines between)
- Character modifiers like (V.O.) are included in the Character line
- Dialogue content directly after character names

**Expected Character Extraction**:
```
["ALICE", "BOB", "NARRATOR"]
```

**Important Format Rule**: Character names must be immediately followed by dialogue/parentheticals, NOT blank lines. This is required for Fountain parsing compatibility:

✅ CORRECT:
```
ALICE
Bob, can you help me?
```

❌ INCORRECT (won't parse):
```
ALICE

Bob, can you help me?
```

**Test Validation**:
- CastExtractor.extractCast(from: highland_file_url) should return sorted, unique character names
- SwiftCompartido's HighlandParser automatically detects and delegates to FountainParser for plain-text files
- Regex fallback is NOT available for Highland (only for Fountain)

---

### test-screenplay.fountain (Fountain Format)

**Format**: Plain text screenplay format (standard Fountain)
**Location**: `Tests/SwiftProyectoTests/Fixtures/test-screenplay.fountain`

**Expected Character Extraction**:
```
["ALICE", "BOB"]
```

**Test Validation**:
- CastExtractor.extractCast(from: fountain_file_url) can use regex fallback if SwiftCompartido parsing fails
- This is the original reference fixture used in pre-multi-format tests

---

## Format Consistency Notes

### Character Name Handling

All formats are designed to extract the following character names:

| Format | ALICE | BOB | NARRATOR |
|--------|-------|-----|----------|
| FDX | ✓ | ✓ | ✓ |
| Highland | ✓ | ✓ | ✓ |
| Fountain | ✓ | ✓ | (not in this fixture) |

### Parenthetical Handling

- **FDX**: Parentheticals like "(V.O.)" are preserved in the element text but should be removed during character extraction by SwiftCompartido
- **Highland**: Character names in ALL CAPS are distinguished from parentheticals by position and structure
- **Fountain**: Uses regex-based fallback which strips parentheticals via pattern matching

### Deduplication

CastExtractor ensures no duplicate character names in the result:
- Characters appearing multiple times are deduplicated
- Results are sorted alphabetically

---

## Usage in Tests

### DirectoryAnalysisTests.swift

The placeholder tests for multi-format support use these fixtures:

```swift
// FDX test (lines 240-272)
func test_extractCast_from_fdx_file() throws {
    let fdxFile = /* path to sample.fdx */
    let cast = try extractor.extractCast(from: fdxFile)
    XCTAssertEqual(cast, ["ALICE", "BOB", "NARRATOR"])
}

// Highland test (lines 274-302)
func test_extractCast_from_highland_file() throws {
    let highlandFile = /* path to sample.highland */
    let cast = try extractor.extractCast(from: highlandFile)
    XCTAssertEqual(cast, ["ALICE", "BOB", "NARRATOR"])
}
```

---

## Implementation Details

### Parsing Pipeline

1. **File Extension Detection**: `.fdx`, `.highland`, `.fountain`
2. **Format-Specific Parser**: SwiftCompartido's GuionParsedElementCollection auto-selects parser
3. **Character Extraction**: GuionParsedElementCollection.extractCharacters() → [String: CharacterInfo]
4. **Deduplication & Sort**: CastExtractor deduplicates and sorts results

### Error Handling

- **Unsupported format**: Throws CastExtractionError.unsupportedFormat
- **File not readable**: Throws CastExtractionError.fileNotReadable
- **Parse failure** (non-Fountain): Throws CastExtractionError.parsingFailed
- **Parse failure** (Fountain only): Falls back to regex extraction

---

## Creating Additional Fixtures

To create new screenplay fixtures:

1. **Determine format**: FDX (XML), Highland (plain text), or Fountain (plain text)
2. **Use valid structure**: Follow format specifications from SwiftCompartido
3. **Minimal content**: Include only essential elements (scene heading, characters, dialogue)
4. **Character names**: Use clear, distinct character names (all uppercase)
5. **Document expected output**: Add to this reference file

### FDX Format Template

```xml
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<FinalDraft DocumentType="Script" Template="No" Version="4">
  <Content>
    <Paragraph Type="Scene Heading">
      <Text>INT. LOCATION - TIME</Text>
    </Paragraph>
    <Paragraph Type="Action">
      <Text>Action description.</Text>
    </Paragraph>
    <Paragraph Type="Character">
      <Text>CHARACTER_NAME</Text>
    </Paragraph>
    <Paragraph Type="Dialogue">
      <Text>Character dialogue.</Text>
    </Paragraph>
  </Content>
</FinalDraft>
```

### Highland Format Template

For plain-text `.highland` files (which use Fountain format internally), character names must be immediately followed by dialogue:

```
Title: Script Title
Author: Author Name

INT. LOCATION - TIME

Action description.

CHARACTER_NAME
Character dialogue.
```

**Note**: If creating ZIP-based Highland files with TextBundles, the format is more flexible as it's stored inside a proper Highland structure. For simplicity, use the plain-text Fountain-compatible format.

---

**Last Updated**: 2026-07-04
**Created by**: Sortie 4a - Test Fixture Creation

# Voice URL to Key/Value Migration

## Overview

This document outlines the changes needed to migrate from URL-style voice mapping to key/value pairs in SwiftProyecto.

**Current format (URL-style):**
```yaml
cast:
  - character: NARRATOR
    voices:
      - apple://com.apple.voice.premium.en-US.Aaron?lang=en
      - elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en
```

**New format (Key/Value):**
```yaml
cast:
  - character: NARRATOR
    voices:
      apple: com.apple.voice.premium.en-US.Aaron
      elevenlabs: 21m00Tcm4TlvDq8ikWAM
```

## Rationale

- **Cleaner syntax**: No URL parsing required
- **Provider-specific lookup**: Direct dictionary access by provider name
- **More intuitive**: Key represents provider, value represents voice identifier
- **Simpler validation**: No need to parse URL schemes and query parameters

## Breaking Changes

This is a **BREAKING CHANGE** that affects:
- ✅ `CastMember` model structure
- ✅ YAML serialization/deserialization
- ✅ All existing PROJECT.md files
- ✅ Test fixtures and examples
- ✅ Documentation

## Required Changes

### 1. Core Model Changes

#### `Sources/SwiftProyecto/Models/CastMember.swift`

**Changes:**
- Change `voices: [String]` to `voices: [String: String]`
- Update `hasVoices` computed property
- Replace `primaryVoice` with `voice(for provider: String) -> String?`
- Remove `filterVoices(provider:)` method (no longer needed)
- Update documentation comments with new examples

**Before:**
```swift
public var voices: [String]

public var hasVoices: Bool {
    !voices.isEmpty
}

public var primaryVoice: String? {
    voices.first
}

public func filterVoices(provider: String) -> [String] {
    let normalizedProvider = provider.lowercased()
    return voices.filter { voiceURI in
        guard let colonIndex = voiceURI.firstIndex(of: ":") else { return false }
        let voiceProvider = String(voiceURI[..<colonIndex]).lowercased()
        return voiceProvider == normalizedProvider
    }
}
```

**After:**
```swift
public var voices: [String: String]

public var hasVoices: Bool {
    !voices.isEmpty
}

/// Get voice identifier for a specific provider.
///
/// - Parameter provider: Provider name (e.g., "apple", "elevenlabs")
/// - Returns: Voice identifier if found, nil otherwise
///
/// ## Example
///
/// ```swift
/// let member = CastMember(
///     character: "NARRATOR",
///     voices: [
///         "apple": "com.apple.voice.premium.en-US.Aaron",
///         "elevenlabs": "21m00Tcm4TlvDq8ikWAM"
///     ]
/// )
/// if let appleVoice = member.voice(for: "apple") {
///     print(appleVoice) // "com.apple.voice.premium.en-US.Aaron"
/// }
/// ```
public func voice(for provider: String) -> String? {
    voices[provider.lowercased()]
}

/// Array of all provider names that have voices assigned.
public var providers: [String] {
    Array(voices.keys).sorted()
}
```

**Updated init:**
```swift
public init(
    character: String,
    actor: String? = nil,
    gender: Gender? = nil,
    voiceDescription: String? = nil,
    voices: [String: String] = [:]
) {
    self.character = character
    self.actor = actor
    self.gender = gender
    self.voiceDescription = voiceDescription
    self.voices = voices
}
```

**Documentation updates:**
Update all doc comments that reference voice URIs to use the new format:

```swift
/// ## Example
///
/// ```swift
/// let narrator = CastMember(
///     character: "NARRATOR",
///     actor: "Tom Stovall",
///     gender: .male,
///     voices: [
///         "apple": "com.apple.voice.compact.en-US.Aaron",
///         "elevenlabs": "21m00Tcm4TlvDq8ikWAM"
///     ]
/// )
/// ```
///
/// ## YAML Representation
///
/// ```yaml
/// cast:
///   - character: NARRATOR
///     actor: Tom Stovall
///     gender: M
///     voices:
///       apple: com.apple.voice.compact.en-US.Aaron
///       elevenlabs: 21m00Tcm4TlvDq8ikWAM
/// ```
```

### 2. YAML Parser Changes

#### `Sources/SwiftProyecto/Utilities/ProjectMarkdownParser.swift`

**Changes to `generate()` method:**

**Before:**
```swift
// Cast list
if let cast = frontMatter.cast, !cast.isEmpty {
    yaml += "cast:\n"
    for member in cast {
        yaml += "  - character: \(escapeYAMLString(member.character))\n"
        if let actor = member.actor {
            yaml += "    actor: \(escapeYAMLString(actor))\n"
        }
        if !member.voices.isEmpty {
            yaml += "    voices:\n"
            for voice in member.voices {
                yaml += "      - \(escapeYAMLString(voice))\n"
            }
        }
    }
}
```

**After:**
```swift
// Cast list
if let cast = frontMatter.cast, !cast.isEmpty {
    yaml += "cast:\n"
    for member in cast {
        yaml += "  - character: \(escapeYAMLString(member.character))\n"
        if let actor = member.actor {
            yaml += "    actor: \(escapeYAMLString(actor))\n"
        }
        if let gender = member.gender {
            yaml += "    gender: \(gender.rawValue)\n"
        }
        if !member.voices.isEmpty {
            yaml += "    voices:\n"
            for (provider, voiceId) in member.voices.sorted(by: { $0.key < $1.key }) {
                yaml += "      \(provider): \(escapeYAMLString(voiceId))\n"
            }
        }
    }
}
```

### 3. Test Updates

#### `Tests/SwiftProyectoTests/CastMemberTests.swift`

**Changes needed:**

1. **Update all test fixtures** to use dictionary format:

```swift
// Before
let member = CastMember(
    character: "NARRATOR",
    voices: ["apple://com.apple.voice.compact.en-US.Aaron?lang=en"]
)

// After
let member = CastMember(
    character: "NARRATOR",
    voices: ["apple": "com.apple.voice.compact.en-US.Aaron"]
)
```

2. **Update `hasVoices` tests**: No changes needed (still checks `!voices.isEmpty`)

3. **Remove `filterVoices()` tests**: Delete these test methods:
   - `testFilterVoicesAppleProvider()`
   - `testFilterVoicesNoMatches()`
   - `testFilterVoicesEmptyArray()`
   - `testFilterVoicesCaseInsensitive()`
   - `testFilterVoicesPreservesOrder()`

4. **Add new `voice(for:)` tests**:

```swift
// MARK: - voice(for:) Tests

func testVoiceForProvider_Found() {
    let member = CastMember(
        character: "TEST",
        voices: [
            "apple": "com.apple.voice.compact.en-US.Aaron",
            "elevenlabs": "21m00Tcm4TlvDq8ikWAM"
        ]
    )
    XCTAssertEqual(member.voice(for: "apple"), "com.apple.voice.compact.en-US.Aaron")
    XCTAssertEqual(member.voice(for: "elevenlabs"), "21m00Tcm4TlvDq8ikWAM")
}

func testVoiceForProvider_NotFound() {
    let member = CastMember(
        character: "TEST",
        voices: ["apple": "voice1"]
    )
    XCTAssertNil(member.voice(for: "elevenlabs"))
}

func testVoiceForProvider_CaseInsensitive() {
    let member = CastMember(
        character: "TEST",
        voices: ["apple": "voice1"]
    )
    XCTAssertEqual(member.voice(for: "APPLE"), "voice1")
    XCTAssertEqual(member.voice(for: "Apple"), "voice1")
}

func testVoiceForProvider_EmptyVoices() {
    let member = CastMember(character: "TEST", voices: [:])
    XCTAssertNil(member.voice(for: "apple"))
}

func testProviders_ReturnsSortedKeys() {
    let member = CastMember(
        character: "TEST",
        voices: [
            "elevenlabs": "voice2",
            "apple": "voice1",
            "voxalta": "voice3"
        ]
    )
    XCTAssertEqual(member.providers, ["apple", "elevenlabs", "voxalta"])
}

func testProviders_EmptyWhenNoVoices() {
    let member = CastMember(character: "TEST", voices: [:])
    XCTAssertEqual(member.providers, [])
}
```

5. **Remove `primaryVoice` tests**: Delete these test methods:
   - `testPrimaryVoice_WithVoices()`
   - `testPrimaryVoice_NoVoices()`

6. **Update mutability tests**:

```swift
func testVoices_Mutable() {
    var member = CastMember(character: "NARRATOR")
    XCTAssertEqual(member.voices, [:])

    member.voices = ["apple": "com.apple.voice.compact.en-US.Aaron"]
    XCTAssertEqual(member.voices.count, 1)

    member.voices["elevenlabs"] = "21m00Tcm4TlvDq8ikWAM"
    XCTAssertEqual(member.voices.count, 2)
}
```

7. **Update voice format tests**:

```swift
func testVoiceIDs_ValidFormats() {
    let member = CastMember(
        character: "NARRATOR",
        voices: [
            "apple": "com.apple.voice.compact.en-US.Aaron",
            "elevenlabs": "21m00Tcm4TlvDq8ikWAM",
            "voxalta": "narrative-1"
        ]
    )

    XCTAssertEqual(member.voices.count, 3)
    XCTAssertEqual(member.voice(for: "apple"), "com.apple.voice.compact.en-US.Aaron")
}
```

#### `Tests/SwiftProyectoTests/ProjectServiceCastListTests.swift`

**Update merge test fixtures:**

```swift
// Before
let existing = [
    CastMember(
        character: "NARRATOR",
        actor: "Tom Stovall",
        voices: ["apple://en-US/Aaron"]
    )
]

// After
let existing = [
    CastMember(
        character: "NARRATOR",
        actor: "Tom Stovall",
        voices: ["apple": "com.apple.voice.compact.en-US.Aaron"]
    )
]
```

**Update assertions:**

```swift
// Before
XCTAssertEqual(narrator?.voices, ["apple://en-US/Aaron"])

// After
XCTAssertEqual(narrator?.voices, ["apple": "com.apple.voice.compact.en-US.Aaron"])
```

#### `Tests/SwiftProyectoTests/ProjectFrontMatterTests.swift`

**Update YAML test fixtures:**

```swift
let yamlContent = """
---
type: project
title: Test Series
author: Test Author
created: 2025-01-25T10:30:00Z
cast:
  - character: NARRATOR
    actor: Tom Stovall
    gender: M
    voices:
      apple: com.apple.voice.compact.en-US.Aaron
      elevenlabs: 21m00Tcm4TlvDq8ikWAM
  - character: LAO TZU
    actor: Jason Manino
    gender: M
    voices:
      voxalta: narrative-1
---
"""
```

**Update assertions:**

```swift
XCTAssertEqual(narrator?.voices["apple"], "com.apple.voice.compact.en-US.Aaron")
XCTAssertEqual(narrator?.voices["elevenlabs"], "21m00Tcm4TlvDq8ikWAM")
```

### 4. Documentation Updates

#### `README.md`

**Update voice examples (line ~266):**

```yaml
cast:
  - character: NARRATOR
    actor: Tom Stovall
    gender: M
    voices:
      apple: com.apple.voice.compact.en-US.Aaron
      elevenlabs: 21m00Tcm4TlvDq8ikWAM
  - character: LAO TZU
    actor: Jason Manino
    gender: M
    voices:
      voxalta: male-voice-1
      apple: com.apple.voice.premium.en-US.Tom
```

**Update Voice Provider Reference table (line ~287):**

| Provider | Key | Voice ID Format | Example |
|----------|-----|-----------------|---------|
| **Apple TTS** | `apple` | `com.apple.voice.{quality}.{locale}.{VoiceName}` | `com.apple.voice.compact.en-US.Samantha` |
| **ElevenLabs** | `elevenlabs` | Unique voice ID (alphanumeric) | `21m00Tcm4TlvDq8ikWAM` |
| **Qwen TTS** | `voxalta` | Voice name or ID | `female-voice-1` |

**Update examples (line ~298):**

```yaml
# Apple voices
apple: com.apple.voice.premium.en-US.Allison
apple: com.apple.voice.compact.en-US.Samantha
apple: com.apple.voice.premium.es-ES.Monica

# ElevenLabs voices
elevenlabs: 21m00Tcm4TlvDq8ikWAM
elevenlabs: pNInz6obpgDQGcFmaJgB

# Qwen voices
voxalta: female-voice-1
voxalta: male-voice-1
```

#### `AGENTS.md`

**Update all voice examples (lines ~243-245, ~402-408, ~557-559):**

Same changes as README.md - replace URL format with key/value format.

#### `EXAMPLE_PROJECT.md`

**Update voice mappings (lines 19-30):**

```yaml
cast:
  - character: MARCUS AURELIUS
    actor: Tom Stovall
    gender: M
    voices:
      apple: com.apple.voice.compact.en-US.Aaron
  - character: NARRATOR
    actor: Jason Manino
    gender: M
    voices:
      apple: com.apple.voice.compact.en-US.Daniel
  - character: POETIC VOICE
    actor: Sarah Mitchell
    gender: F
    voices:
      apple: com.apple.voice.compact.en-US.Samantha
```

#### `CHANGELOG.md`

**Add breaking change entry at top:**

```markdown
## [Unreleased]

### BREAKING CHANGES

- **Voice representation changed from URL-style to key/value pairs**
  - `voices` field in `CastMember` is now `[String: String]` instead of `[String]`
  - Voice URIs like `apple://com.apple.voice.premium.en-US.Aaron?lang=en` are now `{"apple": "com.apple.voice.premium.en-US.Aaron"}`
  - Removed `filterVoices(provider:)` method (use dictionary subscript instead: `voices["apple"]`)
  - Removed `primaryVoice` property (use `voice(for:)` method instead)
  - Added `voice(for provider: String) -> String?` method for provider-specific lookup
  - Added `providers` property to list all available providers
  - All existing PROJECT.md files must be migrated to new format

### Migration Guide

**Old format:**
```yaml
voices:
  - apple://com.apple.voice.premium.en-US.Aaron?lang=en
  - elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en
```

**New format:**
```yaml
voices:
  apple: com.apple.voice.premium.en-US.Aaron
  elevenlabs: 21m00Tcm4TlvDq8ikWAM
```

**Code changes:**
```swift
// Old
let appleVoices = member.filterVoices(provider: "apple")
let firstVoice = member.primaryVoice

// New
if let appleVoice = member.voice(for: "apple") {
    // Use apple voice
}
let allProviders = member.providers
```
```

### 5. Additional Files to Check

#### `AGENT_TASKS.md`

Update all voice examples to use key/value format.

#### `TODO_CLI_SUPPORT_UPDATED.md` and `TODO_CLI_SUPPORT.md`

Update any voice URI references to use key/value format.

## Migration Strategy

### Phase 1: Update Core Model
1. Update `CastMember.swift` with new structure
2. Update codable implementation
3. Update computed properties

### Phase 2: Update Parser
1. Update `ProjectMarkdownParser.swift` to generate new YAML format
2. Update parsing logic to handle new format

### Phase 3: Update Tests
1. Update all test fixtures
2. Remove obsolete tests
3. Add new tests for `voice(for:)` and `providers`
4. Run full test suite

### Phase 4: Update Documentation
1. Update README.md
2. Update AGENTS.md
3. Update EXAMPLE_PROJECT.md
4. Update CHANGELOG.md
5. Update inline documentation

### Phase 5: Migration Script (Optional)
Consider creating a migration script to automatically convert existing PROJECT.md files from old format to new format.

## Verification Checklist

- [ ] `CastMember.swift` updated with new structure
- [ ] `voice(for:)` method implemented
- [ ] `providers` property implemented
- [ ] `filterVoices()` method removed
- [ ] `primaryVoice` property removed
- [ ] `ProjectMarkdownParser.swift` YAML generation updated
- [ ] All tests in `CastMemberTests.swift` updated
- [ ] All tests in `ProjectServiceCastListTests.swift` updated
- [ ] All tests in `ProjectFrontMatterTests.swift` updated
- [ ] README.md updated
- [ ] AGENTS.md updated
- [ ] EXAMPLE_PROJECT.md updated
- [ ] CHANGELOG.md updated with breaking change notice
- [ ] All other markdown files checked and updated
- [ ] Full test suite passes
- [ ] Build succeeds with no warnings

## Backward Compatibility

**This is NOT backward compatible.** Existing PROJECT.md files will need to be converted to the new format. Consider:

1. Adding a migration warning when old format is detected
2. Creating a migration tool or script
3. Versioning PROJECT.md format and supporting multiple versions

## Interface Example

**Old interface:**
```swift
let member = CastMember(
    character: "NARRATOR",
    voices: [
        "apple://com.apple.voice.compact.en-US.Aaron?lang=en",
        "elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en"
    ]
)

// Get all apple voices
let appleVoices = member.filterVoices(provider: "apple")

// Get first voice
if let first = member.primaryVoice {
    print(first)
}
```

**New interface:**
```swift
let member = CastMember(
    character: "NARRATOR",
    voices: [
        "apple": "com.apple.voice.compact.en-US.Aaron",
        "elevenlabs": "21m00Tcm4TlvDq8ikWAM"
    ]
)

// Get apple voice (direct lookup)
if let appleVoice = member.voice(for: "apple") {
    print(appleVoice)
}

// Get all providers
let providers = member.providers // ["apple", "elevenlabs"]

// Check if provider exists
if member.voices.keys.contains("apple") {
    // Has apple voice
}
```

## Benefits of New Approach

1. **Simpler**: No URL parsing required
2. **Faster**: Direct dictionary lookup vs. filtering arrays
3. **Type-safe**: Provider names as keys, voice IDs as values
4. **More maintainable**: Clear separation of provider and voice ID
5. **Easier to validate**: Can check if provider key exists
6. **Better API**: `voice(for: "apple")` is more intuitive than `filterVoices(provider: "apple").first`

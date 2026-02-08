# EXECUTION_PLAN: AppFrontMatterSettings Extension System

**Feature:** App-specific settings extension for PROJECT.md frontmatter
**Target Branch:** development
**Documentation:** Docs/EXTENDING_PROJECT_MD.md
**Estimated Total Time:** 6-8 hours (6 sprints)
**Total Tests to Add:** ~50 test methods

---

## Overview

Implement the plugin architecture that allows apps to extend PROJECT.md frontmatter with their own namespaced settings, as documented in `Docs/EXTENDING_PROJECT_MD.md`.

**Current Status:** Documentation exists (commit 033a708), implementation does not exist.

**Components to Build:**
1. AnyCodable - Type-erased Codable wrapper
2. AppFrontMatterSettings protocol - App settings contract
3. ProjectFrontMatter storage - Dictionary for app sections
4. Accessor methods - Type-safe get/set/check
5. Parser integration - YAML round-trip support
6. Documentation validation - Verify guide examples work

---

## Design Decisions (Pre-Approved)

- ✅ **AnyCodable**: Roll our own (no external dependencies)
- ✅ **Error Handling**: Throwing APIs (`throws`) for type safety
- ✅ **YAML Structure**: App sections at root level (not nested under `apps:`)
- ✅ **Backward Compat**: Empty appSections for legacy PROJECT.md files
- ✅ **Conflicts**: Last-write-wins if same sectionKey used

---

## Sprint 1: Implement AnyCodable

**Goal:** Create type-erased wrapper for storing arbitrary Codable values
**Context Impact:** LOW (self-contained, no dependencies)
**Estimated Time:** 50 minutes
**Files Created:** 2
**Lines of Code:** ~200 (100 implementation, 100 tests)

### Entry Criteria
- [ ] On development branch
- [ ] No uncommitted changes to tracked files
- [ ] All existing tests passing

### Implementation

#### 1.1 Create AnyCodable.swift
**File:** `Sources/SwiftProyecto/Models/AnyCodable.swift`
**Size:** ~100 lines

**Requirements:**
- `public struct AnyCodable: Codable, Sendable, Equatable`
- Private `value: Any` storage
- Initializer: `init<T: Codable>(_ value: T)`
- Encode: Preserve type information
- Decode: Restore original type
- **Supported types:**
  - Primitives: Bool, Int, Double, Float, String
  - Collections: [T] where T is Codable, [String: T] where T is Codable
  - Nested: Custom Codable structs
  - Optionals: Optional<T> where T is Codable
- Full documentation comments

**Implementation Notes:**
- Use `JSONEncoder`/`JSONDecoder` internally for type preservation
- Store encoded data as `Data` or use type-switching
- Equatable via encoded representation comparison
- Sendable conformance (all stored properties are Sendable)

#### 1.2 Create AnyCodableTests.swift
**File:** `Tests/SwiftProyectoTests/AnyCodableTests.swift`
**Size:** ~100 lines
**Test Count:** 8 methods

**Required Tests:**
1. `func testEncodePrimitives() throws` - Bool, Int, String, Double encode/decode
2. `func testEncodeArray() throws` - [String], [Int] encode/decode
3. `func testEncodeDictionary() throws` - [String: String] encode/decode
4. `func testEncodeNestedStruct() throws` - Custom Codable struct round-trip
5. `func testDecodePreservesType() throws` - Type information preserved
6. `func testDecodeInvalidDataThrows() throws` - Error handling for bad data
7. `func testSendableConformance()` - Use in async context compiles (no throws)
8. `func testEquality() throws` - Equatable behavior correct

**Test Pattern:**
```swift
func testEncodePrimitives() throws {
    let stringValue = AnyCodable("hello")
    let data = try JSONEncoder().encode(stringValue)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    XCTAssertEqual(stringValue, decoded)
    // Repeat for Int, Bool, Double
}
```

### Exit Criteria
- [ ] File created: `Sources/SwiftProyecto/Models/AnyCodable.swift`
- [ ] File created: `Tests/SwiftProyectoTests/AnyCodableTests.swift`
- [ ] Build succeeds: `xcodebuild build -scheme SwiftProyecto`
- [ ] All 8 tests pass: `xcodebuild test -scheme SwiftProyecto -only-testing:SwiftProyectoTests/AnyCodableTests`
- [ ] No compiler warnings for Sendable
- [ ] Can encode/decode: String, Int, Bool, [String], [String: String], custom struct
- [ ] Code documented with /// comments
- [ ] No regressions (all existing tests still pass)

### Verification Commands
```bash
# Build only
xcodebuild build -scheme SwiftProyecto -destination 'platform=macOS'

# Test only AnyCodable
xcodebuild test -scheme SwiftProyecto \
  -destination 'platform=macOS' \
  -only-testing:SwiftProyectoTests/AnyCodableTests

# Verify test count
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS' \
  -only-testing:SwiftProyectoTests/AnyCodableTests 2>&1 | grep "Test Case.*passed"
# Should show 8 tests passed
```

---

## Sprint 2: Define AppFrontMatterSettings Protocol

**Goal:** Define the protocol that app settings must conform to
**Context Impact:** LOW (just protocol definition, no implementation)
**Estimated Time:** 45 minutes
**Files Created:** 2
**Lines of Code:** ~160 (80 implementation, 80 tests)

### Entry Criteria
- [ ] Sprint 1 complete (AnyCodable exists and works)
- [ ] On development branch
- [ ] All tests passing from Sprint 1

### Implementation

#### 2.1 Create AppFrontMatterSettings.swift
**File:** `Sources/SwiftProyecto/Models/AppFrontMatterSettings.swift`
**Size:** ~80 lines

**Requirements:**
```swift
/// Protocol for app-specific settings that can be stored in PROJECT.md frontmatter.
///
/// Apps conform to this protocol to define their own settings structure.
/// Settings are stored under a unique section key in the YAML frontmatter.
///
/// ## Example
/// ```swift
/// struct MyAppSettings: AppFrontMatterSettings {
///     static let sectionKey = "myapp"
///     var theme: String?
///     var autoSave: Bool?
/// }
/// ```
public protocol AppFrontMatterSettings: Codable, Sendable {
    /// Unique key for this app's settings section in YAML.
    ///
    /// Must be unique across all apps using the same PROJECT.md.
    /// Recommended: Use your app name or bundle identifier.
    static var sectionKey: String { get }
}
```

**Documentation Requirements:**
- Protocol purpose and usage
- Example implementation
- sectionKey uniqueness requirement
- Best practices (use app name, avoid generic keys)

#### 2.2 Create AppFrontMatterSettingsTests.swift
**File:** `Tests/SwiftProyectoTests/AppFrontMatterSettingsTests.swift`
**Size:** ~80 lines
**Test Count:** 5 methods

**Test Settings Types (in test file):**
```swift
// Simple test settings
private struct SimpleTestSettings: AppFrontMatterSettings {
    static let sectionKey = "simpletest"
    var name: String?
    var count: Int?
}

// Complex test settings
private struct ComplexTestSettings: AppFrontMatterSettings {
    static let sectionKey = "complextest"
    var theme: Theme?
    var config: Config?
    var tags: [String]?

    enum Theme: String, Codable, Sendable {
        case light, dark
    }

    struct Config: Codable, Sendable, Equatable {
        var enabled: Bool?
        var value: Int?
    }
}
```

**Required Tests:**
1. `func testSimpleSettingsCodable() throws` - Encode/decode SimpleTestSettings
2. `func testComplexSettingsCodable() throws` - Encode/decode ComplexTestSettings with nested types
3. `func testSectionKeyAccessible() throws` - Can read static sectionKey property
4. `func testSendableConformance()` - Use in async context compiles (no throws)
5. `func testOptionalFieldsEncodeAsNil() throws` - Nil values handled correctly

### Exit Criteria
- [ ] File created: `Sources/SwiftProyecto/Models/AppFrontMatterSettings.swift`
- [ ] File created: `Tests/SwiftProyectoTests/AppFrontMatterSettingsTests.swift`
- [ ] Build succeeds
- [ ] All 5 tests pass: `xcodebuild test -only-testing:SwiftProyectoTests/AppFrontMatterSettingsTests`
- [ ] Test settings types successfully conform to protocol
- [ ] SimpleTestSettings and ComplexTestSettings both encode/decode correctly
- [ ] Protocol documented with examples
- [ ] No regressions (Sprint 1 tests still pass)

### Verification Commands
```bash
# Test only AppFrontMatterSettings
xcodebuild test -scheme SwiftProyecto \
  -destination 'platform=macOS' \
  -only-testing:SwiftProyectoTests/AppFrontMatterSettingsTests

# Verify all previous tests still pass
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'
```

---

## Sprint 3: Add appSections Storage to ProjectFrontMatter

**Goal:** Add storage field for app sections and update Codable
**Context Impact:** MEDIUM (modifies core type, touches Codable)
**Estimated Time:** 80 minutes
**Files Modified:** 1
**Files Created:** 1 (tests)
**Lines of Code:** ~120 (40 implementation, 80 tests)

### Entry Criteria
- [ ] Sprints 1-2 complete (AnyCodable + Protocol exist)
- [ ] On development branch
- [ ] All tests passing from Sprints 1-2

### Implementation

#### 3.1 Add appSections Field
**File:** `Sources/SwiftProyecto/Models/ProjectFrontMatter.swift`
**Modification:** Add storage field

**Changes Required:**
```swift
public struct ProjectFrontMatter: Codable, Sendable, Equatable {
    // ... existing fields ...

    /// Storage for app-specific settings sections.
    /// Keys are app section identifiers, values are type-erased settings.
    /// Internal access allows extensions to read, private(set) prevents external modification.
    internal private(set) var appSections: [String: AnyCodable] = [:]

    // Update init() to accept appSections parameter
    public init(
        // ... existing parameters ...
        appSections: [String: AnyCodable] = [:]
    ) {
        // ... existing assignments ...
        self.appSections = appSections
    }
}
```

**⚠️ CRITICAL:** `appSections` must be `internal` (not `private`) so Sprint 4's extension can access it.

#### 3.2 Update Codable Implementation
**Same File:** `ProjectFrontMatter.swift`

**Requirements:**
- **Encoding:** Write known fields with their keys, then write appSections at root level
- **Decoding:** Read known fields first, collect remaining keys into appSections
- Preserve unknown YAML sections through encode/decode

**Implementation Pattern:**
```swift
// Custom coding keys for known fields - MUST include CaseIterable for allCases check
private enum KnownCodingKeys: String, CodingKey, CaseIterable {
    case type, title, author, created, description, season
    case episodes, genre, tags, episodesDir, audioDir
    case filePattern, exportFormat, cast
    case preGenerateHook, postGenerateHook, tts
}

// Helper for dynamic keys - COMPLETE implementation required
private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

public func encode(to encoder: Encoder) throws {
    // Encode all known fields
    var container = encoder.container(keyedBy: KnownCodingKeys.self)
    try container.encode(type, forKey: .type)
    try container.encode(title, forKey: .title)
    try container.encode(author, forKey: .author)
    try container.encode(created, forKey: .created)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(season, forKey: .season)
    try container.encodeIfPresent(episodes, forKey: .episodes)
    try container.encodeIfPresent(genre, forKey: .genre)
    try container.encodeIfPresent(tags, forKey: .tags)
    try container.encodeIfPresent(episodesDir, forKey: .episodesDir)
    try container.encodeIfPresent(audioDir, forKey: .audioDir)
    try container.encodeIfPresent(filePattern, forKey: .filePattern)
    try container.encodeIfPresent(exportFormat, forKey: .exportFormat)
    try container.encodeIfPresent(cast, forKey: .cast)
    try container.encodeIfPresent(preGenerateHook, forKey: .preGenerateHook)
    try container.encodeIfPresent(postGenerateHook, forKey: .postGenerateHook)
    try container.encodeIfPresent(tts, forKey: .tts)

    // Encode appSections at root level (if not empty)
    if !appSections.isEmpty {
        var rootContainer = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in appSections {
            try rootContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
        }
    }
}

public init(from decoder: Decoder) throws {
    // Decode known fields
    let container = try decoder.container(keyedBy: KnownCodingKeys.self)
    type = try container.decode(String.self, forKey: .type)
    title = try container.decode(String.self, forKey: .title)
    author = try container.decode(String.self, forKey: .author)
    created = try container.decode(Date.self, forKey: .created)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    season = try container.decodeIfPresent(Int.self, forKey: .season)
    episodes = try container.decodeIfPresent(Int.self, forKey: .episodes)
    genre = try container.decodeIfPresent(String.self, forKey: .genre)
    tags = try container.decodeIfPresent([String].self, forKey: .tags)
    episodesDir = try container.decodeIfPresent(String.self, forKey: .episodesDir)
    audioDir = try container.decodeIfPresent(String.self, forKey: .audioDir)
    filePattern = try container.decodeIfPresent(FilePattern.self, forKey: .filePattern)
    exportFormat = try container.decodeIfPresent(String.self, forKey: .exportFormat)
    cast = try container.decodeIfPresent([CastMember].self, forKey: .cast)
    preGenerateHook = try container.decodeIfPresent(String.self, forKey: .preGenerateHook)
    postGenerateHook = try container.decodeIfPresent(String.self, forKey: .postGenerateHook)
    tts = try container.decodeIfPresent(TTSConfig.self, forKey: .tts)

    // Collect remaining keys into appSections
    let rootContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
    var sections: [String: AnyCodable] = [:]
    for key in rootContainer.allKeys {
        // Skip known keys
        if !KnownCodingKeys.allCases.contains(where: { $0.stringValue == key.stringValue }) {
            sections[key.stringValue] = try rootContainer.decode(AnyCodable.self, forKey: key)
        }
    }
    self.appSections = sections
}
```

#### 3.3 Update Equatable Conformance
**Same File:** `ProjectFrontMatter.swift`

**Requirements:**
- Include appSections in equality comparison
- Two ProjectFrontMatter instances equal if all fields (including appSections) match

#### 3.4 Add Tests to ProjectFrontMatterTests.swift
**File:** `Tests/SwiftProyectoTests/ProjectFrontMatterTests.swift`
**Test Count:** 6 new methods

**Required Tests:**
1. `func testAppSectionsInitialization() throws` - Create with appSections parameter
2. `func testAppSectionsEncodingJSON() throws` - Encode to JSON includes app sections at root
3. `func testAppSectionsDecodingJSON() throws` - Decode from JSON with unknown fields
4. `func testAppSectionsRoundTrip() throws` - Encode → Decode preserves app sections exactly
5. `func testMultipleAppSectionsCoexist() throws` - Multiple app sections store independently
6. `func testEmptyAppSectionsDoesNotEncode() throws` - Empty dictionary omitted from output

**Test Pattern:**
```swift
func testAppSectionsDecodingJSON() throws {
    let json = """
    {
        "type": "project",
        "title": "Test",
        "author": "Author",
        "created": "2025-01-01T00:00:00Z",
        "myapp": {
            "theme": "dark",
            "version": 1
        },
        "otherapp": {
            "enabled": true
        }
    }
    """.data(using: .utf8)!

    let frontMatter = try JSONDecoder().decode(ProjectFrontMatter.self, from: json)

    XCTAssertEqual(frontMatter.title, "Test")
    // Verify appSections contains "myapp" and "otherapp"
}
```

### Exit Criteria
- [ ] `appSections` field added to ProjectFrontMatter
- [ ] Custom Codable implementation handles dynamic keys
- [ ] Equatable includes appSections
- [ ] Build succeeds
- [ ] All 6 new tests pass
- [ ] All existing ProjectFrontMatter tests still pass (no regressions)
- [ ] Can encode/decode ProjectFrontMatter with unknown JSON/YAML fields
- [ ] Unknown fields preserved in appSections dictionary
- [ ] Multiple app sections coexist without interference

### Verification Commands
```bash
# Test only new ProjectFrontMatter tests
xcodebuild test -scheme SwiftProyecto \
  -destination 'platform=macOS' \
  -only-testing:SwiftProyectoTests/ProjectFrontMatterTests/testAppSections*

# Verify all tests pass
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'
```

---

## Sprint 4: Implement Settings Accessor Methods

**Goal:** Add type-safe get/set/check methods for app settings
**Context Impact:** MEDIUM (uses generic methods, type erasure)
**Estimated Time:** 95 minutes
**Files Created:** 1 (extension file)
**Lines of Code:** ~230 (80 implementation, 150 tests)

### Entry Criteria
- [ ] Sprints 1-3 complete (AnyCodable, Protocol, Storage exist)
- [ ] On development branch
- [ ] All tests passing from Sprints 1-3

### Implementation

#### 4.1 Create ProjectFrontMatter+AppSettings.swift
**File:** `Sources/SwiftProyecto/Extensions/ProjectFrontMatter+AppSettings.swift`
**Size:** ~80 lines

**Requirements:**

```swift
import Foundation

public extension ProjectFrontMatter {

    /// Retrieve app-specific settings for a given type.
    ///
    /// - Parameter type: The settings type conforming to AppFrontMatterSettings
    /// - Returns: The settings instance if found, nil if section doesn't exist
    /// - Throws: DecodingError if settings exist but cannot be decoded to type T
    ///
    /// ## Example
    /// ```swift
    /// if let settings = try frontMatter.settings(for: MyAppSettings.self) {
    ///     print("Theme: \(settings.theme ?? "default")")
    /// }
    /// ```
    func settings<T: AppFrontMatterSettings>(for type: T.Type) throws -> T? {
        guard let anyCodable = appSections[T.sectionKey] else {
            return nil
        }

        // Decode AnyCodable back to T
        // Use JSONEncoder/Decoder for type safety
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// Store app-specific settings.
    ///
    /// - Parameter settings: The settings instance to store
    /// - Throws: EncodingError if settings cannot be encoded
    ///
    /// Overwrites any existing settings for the same section key.
    ///
    /// ## Example
    /// ```swift
    /// let settings = MyAppSettings(theme: "dark", autoSave: true)
    /// try frontMatter.setSettings(settings)
    /// ```
    mutating func setSettings<T: AppFrontMatterSettings>(_ settings: T) throws {
        // Encode T to AnyCodable
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        appSections[T.sectionKey] = anyCodable
    }

    /// Check if settings exist for a given type.
    ///
    /// - Parameter type: The settings type to check for
    /// - Returns: true if settings section exists, false otherwise
    ///
    /// ## Example
    /// ```swift
    /// if frontMatter.hasSettings(for: MyAppSettings.self) {
    ///     print("Settings found")
    /// }
    /// ```
    func hasSettings<T: AppFrontMatterSettings>(for type: T.Type) -> Bool {
        return appSections[T.sectionKey] != nil
    }
}
```

**Implementation Notes:**
- appSections is `internal` (from Sprint 3), so extensions can access it directly
- Use JSONEncoder/Decoder for type-safe conversion
- settings(for:) returns nil if section missing, throws if decode fails
- setSettings overwrites existing settings for same key
- hasSettings is non-throwing, just checks key existence

#### 4.2 Add Tests to ProjectFrontMatterTests.swift
**File:** `Tests/SwiftProyectoTests/ProjectFrontMatterTests.swift`
**Test Count:** 10 new methods

**Test Settings (add to test file):**
```swift
private struct TestAppSettings: AppFrontMatterSettings {
    static let sectionKey = "testapp"
    var theme: String?
    var count: Int?
}

private struct OtherAppSettings: AppFrontMatterSettings {
    static let sectionKey = "otherapp"
    var enabled: Bool?
}
```

**Required Tests:**
1. `func testSettingsRead_Exists() throws` - Read existing settings returns typed value
2. `func testSettingsRead_Missing() throws` - Read missing settings returns nil
3. `func testSettingsRead_WrongType() throws` - Malformed data throws DecodingError
4. `func testSettingsWrite_New() throws` - Set new settings stores correctly
5. `func testSettingsWrite_Update() throws` - Update existing settings overwrites
6. `func testSettingsRoundTrip() throws` - Write then read preserves values exactly
7. `func testHasSettings_True() throws` - Returns true when settings exist
8. `func testHasSettings_False() throws` - Returns false when settings missing
9. `func testMultipleAppSettingsCoexist() throws` - Two different app types work independently
10. `func testSettingsPreservation() throws` - Updating App A doesn't affect App B

**Test Pattern:**
```swift
func testSettingsWrite_New() throws {
    var frontMatter = ProjectFrontMatter(title: "Test", author: "Author")

    let settings = TestAppSettings(theme: "dark", count: 42)
    try frontMatter.setSettings(settings)

    let retrieved = try frontMatter.settings(for: TestAppSettings.self)
    XCTAssertNotNil(retrieved)
    XCTAssertEqual(retrieved?.theme, "dark")
    XCTAssertEqual(retrieved?.count, 42)
}

func testMultipleAppSettingsCoexist() throws {
    var frontMatter = ProjectFrontMatter(title: "Test", author: "Author")

    let testSettings = TestAppSettings(theme: "dark", count: 10)
    let otherSettings = OtherAppSettings(enabled: true)

    try frontMatter.setSettings(testSettings)
    try frontMatter.setSettings(otherSettings)

    let retrievedTest = try frontMatter.settings(for: TestAppSettings.self)
    let retrievedOther = try frontMatter.settings(for: OtherAppSettings.self)

    XCTAssertEqual(retrievedTest?.theme, "dark")
    XCTAssertEqual(retrievedOther?.enabled, true)
}
```

### Exit Criteria
- [ ] File created: `Sources/SwiftProyecto/Extensions/ProjectFrontMatter+AppSettings.swift`
- [ ] Three methods implemented: `settings(for:)`, `setSettings(_:)`, `hasSettings(for:)`
- [ ] Build succeeds
- [ ] All 10 new tests pass
- [ ] Can write settings: `frontMatter.setSettings(mySettings)` ✓
- [ ] Can read settings: `let s = try frontMatter.settings(for: MySettings.self)` ✓
- [ ] Can check existence: `frontMatter.hasSettings(for: MySettings.self)` ✓
- [ ] Multiple app types work independently without interference
- [ ] Updating one app's settings preserves other apps' settings
- [ ] All documentation comments present
- [ ] No regressions (all previous tests pass)

### Verification Commands
```bash
# Test accessor methods
xcodebuild test -scheme SwiftProyecto \
  -destination 'platform=macOS' \
  -only-testing:SwiftProyectoTests/ProjectFrontMatterTests/testSettings*

# Verify all tests pass
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'
```

---

## Sprint 5: Parser Integration (YAML Support)

**Goal:** ProjectMarkdownParser reads/writes app sections in YAML
**Context Impact:** HIGH (modifies parser, complex YAML handling)
**Estimated Time:** 120 minutes
**Files Modified:** 1 (parser)
**Lines of Code:** ~175 (55 implementation, 120 tests)

### Entry Criteria
- [ ] Sprints 1-4 complete (full settings system works with JSON)
- [ ] On development branch
- [ ] All tests passing from Sprints 1-4
- [ ] Can successfully: create frontmatter → set settings → read settings (with JSON)

### Implementation

#### 5.1 Update ProjectMarkdownParser Parsing
**File:** `Sources/SwiftProyecto/Utilities/ProjectMarkdownParser.swift`
**Modification:** YAML parsing to collect unknown keys

**Current Behavior:** Parser reads known YAML keys into ProjectFrontMatter fields
**New Behavior:** Parser also collects unknown root-level keys into appSections

**Changes Required:**
- When parsing YAML (using Universal library), decode to Dictionary first
- Extract known fields (type, title, author, etc.)
- Collect remaining keys into `[String: Any]` dictionary
- Convert to `[String: AnyCodable]` for appSections
- Pass appSections to ProjectFrontMatter initializer

**Implementation Pattern:**
```swift
public func parse(content: String) throws -> (frontMatter: ProjectFrontMatter, body: String) {
    // ... existing frontmatter extraction ...

    // Parse YAML to dictionary using Universal library
    guard let yamlDict = try YAML.load(yaml: yamlString) as? [String: Any] else {
        throw ParserError.invalidYAML("Could not parse YAML frontmatter")
    }

    // Extract known fields
    let type = yamlDict["type"] as? String ?? "project"
    let title = yamlDict["title"] as? String
    // ... other known fields ...

    // Collect unknown keys into appSections
    let knownKeys: Set<String> = ["type", "title", "author", "created",
                                   "description", "season", "episodes", "genre", "tags",
                                   "episodesDir", "audioDir", "filePattern", "exportFormat",
                                   "cast", "preGenerateHook", "postGenerateHook", "tts"]

    var appSections: [String: AnyCodable] = [:]
    for (key, value) in yamlDict {
        if !knownKeys.contains(key) {
            // Convert value to AnyCodable
            appSections[key] = try convertToAnyCodable(value)
        }
    }

    let frontMatter = ProjectFrontMatter(
        type: type,
        title: title ?? "",
        // ... other parameters ...
        appSections: appSections
    )

    return (frontMatter, body)
}

private func convertToAnyCodable(_ value: Any) throws -> AnyCodable {
    // Convert YAML value (from Yams) to Codable type, then wrap in AnyCodable
    let jsonData: Data

    if let dict = value as? [String: Any] {
        jsonData = try JSONSerialization.data(withJSONObject: dict)
    } else if let array = value as? [Any] {
        jsonData = try JSONSerialization.data(withJSONObject: array)
    } else if let primitive = value as? (any Codable) {
        // Wrap primitive in dictionary for JSON serialization
        jsonData = try JSONSerialization.data(withJSONObject: ["value": primitive])
    } else {
        throw ParseError.unsupportedValueType
    }

    return try JSONDecoder().decode(AnyCodable.self, from: jsonData)
}
```

#### 5.2 Update ProjectMarkdownParser Generation
**Same File:** `ProjectMarkdownParser.swift`
**Modification:** YAML generation to include appSections

**Current Behavior:** Generator writes known fields to YAML
**New Behavior:** Generator also writes appSections at root level

**Changes Required:**
- When generating YAML, encode known fields first
- Then encode appSections at same level
- Maintain proper YAML formatting
- Preserve field order (known fields first, then app sections)

**Implementation Pattern:**
```swift
public func generate(frontMatter: ProjectFrontMatter, body: String) -> String {
    var yamlDict: [String: Any] = [:]

    // Add known fields
    yamlDict["type"] = frontMatter.type
    yamlDict["title"] = frontMatter.title
    // ... other known fields ...

    // Add appSections at root level
    // appSections is internal, so we can access it directly
    for (key, anyCodable) in frontMatter.appSections {
        yamlDict[key] = try? convertFromAnyCodable(anyCodable)
    }

    let yamlString = try YAML.dump(object: yamlDict)

    return "---\n\(yamlString)---\n\n\(body)"
}

// Helper to convert AnyCodable back to YAML-compatible type
private func convertFromAnyCodable(_ anyCodable: AnyCodable) throws -> Any {
    let encoder = JSONEncoder()
    let data = try encoder.encode(anyCodable)
    return try JSONSerialization.jsonObject(with: data)
}
```

#### 5.3 Add Tests to ProjectMarkdownParserTests.swift
**File:** `Tests/SwiftProyectoTests/ProjectMarkdownParserTests.swift`
**Test Count:** 8 new methods

**Required Tests:**
1. `func testParseYAMLWithAppSection() throws` - Parse YAML with one unknown section
2. `func testParseYAMLWithMultipleAppSections() throws` - Parse YAML with multiple unknown sections
3. `func testGenerateYAMLWithAppSection() throws` - Generate YAML includes app section
4. `func testYAMLRoundTrip_AppSectionsPreserved() throws` - Parse → Generate → Parse preserves app sections
5. `func testYAMLRoundTrip_KnownFieldsUnaffected() throws` - Known fields work with app sections present
6. `func testAppSectionAtRootLevel() throws` - App sections appear at correct YAML level (not nested)
7. `func testLegacyYAMLWithoutAppSections() throws` - Old PROJECT.md files parse without errors
8. `func testTypedSettingsFullRoundTrip() throws` - Full workflow: parse → extract typed → modify → write → re-parse

**Test Pattern:**
```swift
func testParseYAMLWithAppSection() throws {
    let yaml = """
    ---
    type: project
    title: Test Project
    author: Test Author
    created: 2025-01-01T00:00:00Z
    myapp:
      theme: dark
      version: 1
    ---

    # Body
    """

    let parser = ProjectMarkdownParser()
    let (frontMatter, body) = try parser.parse(content: yaml)

    XCTAssertEqual(frontMatter.title, "Test Project")
    XCTAssertTrue(frontMatter.hasSettings(for: TestAppSettings.self))

    let settings = try frontMatter.settings(for: TestAppSettings.self)
    XCTAssertEqual(settings?.theme, "dark")
}

func testTypedSettingsFullRoundTrip() throws {
    // Parse original YAML
    let original = """
    ---
    type: project
    title: My Project
    author: Author
    created: 2025-01-01T00:00:00Z
    ---

    # Description
    """

    let parser = ProjectMarkdownParser()
    let (frontMatter, body) = try parser.parse(content: original)

    // Add typed settings
    var updated = frontMatter
    let settings = TestAppSettings(theme: "dark", count: 42)
    try updated.setSettings(settings)

    // Generate YAML
    let generated = parser.generate(frontMatter: updated, body: body)

    // Re-parse
    let (reparsed, _) = try parser.parse(content: generated)

    // Verify settings survived round-trip
    let retrievedSettings = try reparsed.settings(for: TestAppSettings.self)
    XCTAssertEqual(retrievedSettings?.theme, "dark")
    XCTAssertEqual(retrievedSettings?.count, 42)

    // Verify known fields preserved
    XCTAssertEqual(reparsed.title, "My Project")
    XCTAssertEqual(reparsed.author, "Author")
}
```

### Exit Criteria
- [ ] Parser reads unknown YAML keys into appSections
- [ ] Parser generates YAML with app sections at root level
- [ ] Build succeeds
- [ ] All 8 new parser tests pass
- [ ] Can parse YAML with unknown root-level sections ✓
- [ ] Can generate YAML that includes app sections ✓
- [ ] Round-trip preserves app sections exactly ✓
- [ ] Legacy PROJECT.md files (no app sections) parse without errors ✓
- [ ] Full typed workflow works: parse → extract → modify → write → re-parse ✓
- [ ] Known fields unaffected by presence of app sections
- [ ] All previous tests still pass (no regressions)

### Verification Commands
```bash
# Test parser integration
xcodebuild test -scheme SwiftProyecto \
  -destination 'platform=macOS' \
  -only-testing:SwiftProyectoTests/ProjectMarkdownParserTests/testParseYAML*
xcodebuild test -scheme SwiftProyecto \
  -destination 'platform=macOS' \
  -only-testing:SwiftProyectoTests/ProjectMarkdownParserTests/testTypedSettings*

# Verify all tests pass
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'
```

---

## Sprint 6: Documentation Example Validation

**Goal:** Verify every example in EXTENDING_PROJECT_MD.md works
**Context Impact:** LOW (only tests, uses existing implementation)
**Estimated Time:** 90 minutes
**Files Created:** 1 (test file)
**Lines of Code:** ~350 (150 example code, 200 tests)

### Entry Criteria
- [ ] Sprints 1-5 complete (full system implemented)
- [ ] On development branch
- [ ] All tests passing from Sprints 1-5
- [ ] YAML round-trip fully working

### Implementation

#### 6.1 Create DocumentationExamplesTests.swift
**File:** `Tests/SwiftProyectoTests/DocumentationExamplesTests.swift`
**Size:** ~350 lines
**Test Count:** 13 methods

**Reference:** All examples from `Docs/EXTENDING_PROJECT_MD.md`

**Settings Types to Implement (from guide):**

```swift
// Quick Start Example (lines 103-110 of guide)
private struct MyAppSettings: AppFrontMatterSettings {
    static let sectionKey = "myapp"
    var theme: String?
    var autoSave: Bool?
    var exportFormat: String?
}

// Podcast Example (lines 270-296 of guide)
private struct PodcastAppSettings: AppFrontMatterSettings {
    static let sectionKey = "podcast"

    var sampleRate: Int?
    var bitRate: Int?
    var format: AudioFormat?
    var chapters: [Chapter]?
    var includeMetadata: Bool?
    var coverArtPath: String?

    enum AudioFormat: String, Codable, Sendable {
        case mp3
        case aac
        case flac
    }

    struct Chapter: Codable, Equatable, Sendable {
        var title: String
        var startTime: Double
        var endTime: Double
    }
}

// Best Practices Examples
private struct VersionedSettings: AppFrontMatterSettings {
    static let sectionKey = "versioned"
    var schemaVersion: Int?
    var theme: String?
}

private struct NestedSettings: AppFrontMatterSettings {
    static let sectionKey = "nested"
    var ui: UISettings?
    var export: ExportSettings?

    struct UISettings: Codable, Equatable, Sendable {
        var theme: String?
        var fontSize: Int?
    }

    struct ExportSettings: Codable, Equatable, Sendable {
        var format: String?
        var quality: Int?
    }
}
```

**Required Tests:**

**Quick Start Validation (3 tests):**
1. `func testQuickStart_DefineSettings() throws` - MyAppSettings compiles and conforms
2. `func testQuickStart_ReadSettings() throws` - Example from lines 114-121 works
3. `func testQuickStart_WriteSettings() throws` - Example from lines 125-137 works

**Podcast Example Validation (4 tests):**
4. `func testPodcast_SettingsStructure() throws` - PodcastAppSettings with nested types works
5. `func testPodcast_YAMLOutput() throws` - Generated YAML matches lines 302-319
6. `func testPodcast_CreateProject() throws` - createProject() example from lines 326-342 works
7. `func testPodcast_LoadProject() throws` - loadProject() example from lines 345-360 works

**Best Practices Patterns (6 tests):**
8. `func testBestPractice_DefaultsPattern() throws` - Static .default extension pattern works
9. `func testBestPractice_VersioningPattern() throws` - Settings with version field works
10. `func testBestPractice_NestedStructures() throws` - Multiple nested settings sections work
11. `func testBestPractice_PreservationPattern() throws` - Update one field preserves others
12. `func testBestPractice_EnumConstraints() throws` - Enum for constrained values works
13. `func testBestPractice_OptionalFields() throws` - All optional fields encode/decode correctly

**Test Pattern:**
```swift
func testQuickStart_WriteSettings() throws {
    // From guide lines 125-137
    var frontMatter = ProjectFrontMatter(title: "My Project", author: "Author")

    let settings = MyAppSettings(
        theme: "dark",
        autoSave: true,
        exportFormat: "pdf"
    )
    try frontMatter.setSettings(settings)

    let parser = ProjectMarkdownParser()
    let content = parser.generate(frontMatter: frontMatter, body: "# Description")

    // Verify YAML contains settings
    XCTAssertTrue(content.contains("myapp:"))
    XCTAssertTrue(content.contains("theme: dark"))

    // Verify can write to disk and re-read
    // (In test, use temporary file)
}

func testPodcast_YAMLOutput() throws {
    // Create podcast settings
    let settings = PodcastAppSettings(
        sampleRate: 44100,
        bitRate: 128,
        format: .mp3,
        chapters: [
            PodcastAppSettings.Chapter(
                title: "Introduction",
                startTime: 0,
                endTime: 120
            )
        ],
        includeMetadata: true,
        coverArtPath: "assets/cover.jpg"
    )

    var frontMatter = ProjectFrontMatter(
        title: "My Podcast",
        author: "Author"
    )
    try frontMatter.setSettings(settings)

    let parser = ProjectMarkdownParser()
    let yaml = parser.generate(frontMatter: frontMatter, body: "")

    // Verify YAML structure matches guide example (lines 302-319)
    XCTAssertTrue(yaml.contains("podcast:"))
    XCTAssertTrue(yaml.contains("sampleRate: 44100"))
    XCTAssertTrue(yaml.contains("format: mp3"))
    XCTAssertTrue(yaml.contains("chapters:"))
    XCTAssertTrue(yaml.contains("title: Introduction"))
}

func testBestPractice_DefaultsPattern() throws {
    // Implement .default extension from guide
    extension MyAppSettings {
        static var `default`: Self {
            MyAppSettings(
                theme: "light",
                autoSave: true,
                exportFormat: "pdf"
            )
        }
    }

    var frontMatter = ProjectFrontMatter(title: "Test", author: "Author")
    let settings = try frontMatter.settings(for: MyAppSettings.self) ?? .default

    XCTAssertEqual(settings.theme, "light")
    XCTAssertEqual(settings.autoSave, true)
}
```

### Exit Criteria
- [ ] File created: `Tests/SwiftProyectoTests/DocumentationExamplesTests.swift`
- [ ] All settings types from guide implemented in test file
- [ ] Build succeeds
- [ ] All 13 documentation tests pass
- [ ] Quick Start example (lines 103-137) works exactly as shown ✓
- [ ] Podcast example (lines 270-360) works exactly as shown ✓
- [ ] Best practices patterns all work correctly ✓
- [ ] Generated YAML matches guide examples ✓
- [ ] Can confidently tell users: "This guide is accurate and tested" ✓
- [ ] All previous tests still pass (no regressions)

### Verification Commands
```bash
# Test documentation examples
xcodebuild test -scheme SwiftProyecto \
  -destination 'platform=macOS' \
  -only-testing:SwiftProyectoTests/DocumentationExamplesTests

# Full test suite
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS'

# Count total tests (should be ~50 new tests + existing)
xcodebuild test -scheme SwiftProyecto -destination 'platform=macOS' 2>&1 | \
  grep "Test Suite.*passed" | tail -1
```

---

## Final Verification Checklist

After all 6 sprints complete:

### Code Quality
- [ ] All new code has documentation comments (///)
- [ ] No compiler warnings for Sendable/concurrency
- [ ] No force unwraps (!) in production code
- [ ] Error messages are clear and actionable
- [ ] Code follows existing SwiftProyecto style

### Test Coverage
- [ ] ~50 new test methods added
- [ ] All tests pass: `xcodebuild test -scheme SwiftProyecto`
- [ ] No regressions (all pre-existing tests still pass)
- [ ] Edge cases covered (nil, empty, malformed data)
- [ ] Integration tests validate full workflow

### Documentation
- [ ] All public APIs documented
- [ ] EXTENDING_PROJECT_MD.md examples verified to work
- [ ] Code examples in tests match guide examples
- [ ] README.md updated with AppFrontMatterSettings feature (if applicable)

### Functionality
- [ ] Can define custom settings struct conforming to AppFrontMatterSettings ✓
- [ ] Can write settings to PROJECT.md frontmatter ✓
- [ ] Can read settings from PROJECT.md frontmatter ✓
- [ ] Multiple apps' settings coexist without conflicts ✓
- [ ] YAML round-trip preserves all data ✓
- [ ] Legacy PROJECT.md files parse without errors ✓
- [ ] Type safety enforced (compile-time + runtime) ✓

### Integration
- [ ] Works with existing ProjectMarkdownParser
- [ ] Works with existing ProjectFrontMatter
- [ ] No breaking changes to existing APIs
- [ ] Backward compatible with old PROJECT.md files

---

## Commit Strategy

### After Each Sprint:
```bash
# Sprint 1
git add Sources/SwiftProyecto/Models/AnyCodable.swift
git add Tests/SwiftProyectoTests/AnyCodableTests.swift
git commit -m "feat: add AnyCodable type-erased Codable wrapper

- Add AnyCodable struct for storing arbitrary Codable values
- Support encoding/decoding with type preservation
- Add Sendable conformance for Swift 6
- Add 8 unit tests covering primitives, collections, nested types"

# Sprint 2
git add Sources/SwiftProyecto/Models/AppFrontMatterSettings.swift
git add Tests/SwiftProyectoTests/AppFrontMatterSettingsTests.swift
git commit -m "feat: add AppFrontMatterSettings protocol

- Define protocol for app-specific settings
- Require sectionKey, Codable, Sendable conformance
- Add test settings types with simple and complex structures
- Add 5 unit tests validating protocol conformance"

# Sprint 3
git add Sources/SwiftProyecto/Models/ProjectFrontMatter.swift
git add Tests/SwiftProyectoTests/ProjectFrontMatterTests.swift
git commit -m "feat: add appSections storage to ProjectFrontMatter

- Add private appSections: [String: AnyCodable] field
- Update Codable to preserve unknown YAML keys
- Update Equatable to include appSections
- Add 6 unit tests for storage and Codable round-trip"

# Sprint 4
git add Sources/SwiftProyecto/Extensions/ProjectFrontMatter+AppSettings.swift
git add Tests/SwiftProyectoTests/ProjectFrontMatterTests.swift
git commit -m "feat: add settings accessor methods to ProjectFrontMatter

- Add settings(for:) for type-safe reading
- Add setSettings(_:) for type-safe writing
- Add hasSettings(for:) for existence checking
- Add 10 unit tests covering read/write/check operations"

# Sprint 5
git add Sources/SwiftProyecto/Utilities/ProjectMarkdownParser.swift
git add Tests/SwiftProyectoTests/ProjectMarkdownParserTests.swift
git commit -m "feat: add YAML support for app sections in parser

- Parse unknown YAML keys into appSections
- Generate YAML with app sections at root level
- Preserve app sections through round-trip
- Add 8 integration tests for YAML parsing/generation"

# Sprint 6
git add Tests/SwiftProyectoTests/DocumentationExamplesTests.swift
git commit -m "test: validate EXTENDING_PROJECT_MD.md examples

- Implement all settings examples from documentation guide
- Test Quick Start, Podcast, and Best Practices patterns
- Add 13 tests verifying guide accuracy
- Confirm all documented examples work as shown"

# Final (after all sprints)
git add EXECUTION_PLAN.md
git commit -m "docs: mark AppFrontMatterSettings implementation complete

- Update EXECUTION_PLAN.md with completion status
- All 6 sprints complete, 50 tests passing
- Full AppFrontMatterSettings system implemented"
```

---

## Troubleshooting

### If Build Fails
- Check import statements (AnyCodable must be imported where used)
- Verify Sendable conformance on all types
- Check for missing public access modifiers

### If Tests Fail
- Verify test settings types have correct sectionKey
- Check JSON encoder/decoder date strategies match
- Ensure AnyCodable preserves type information correctly

### If YAML Parsing Fails
- Verify Universal dependency is available (marcprux/universal 5.0.5+)
- Check that `import Universal` is present in parser file
- Verify YAML.load/YAML.dump API usage matches Universal library
- Check dynamic key handling in encode/decode
- Ensure unknown keys collected before decoding known fields

### Context Window Issues
- Each sprint designed to fit in one session
- If sprint too large, pause after implementation, test in next session
- Sprints 1-2 are smallest (good warmup)
- Sprint 5 is largest (parser integration) - may need 2 sessions

---

## Success Criteria

This implementation is **COMPLETE** when:

1. ✅ All 6 sprints finished
2. ✅ ~50 new tests added and passing
3. ✅ All existing tests still pass (no regressions)
4. ✅ Every example in EXTENDING_PROJECT_MD.md works
5. ✅ Can demonstrate full workflow:
   - Define custom settings struct
   - Write to PROJECT.md
   - Read from PROJECT.md
   - Multiple apps coexist
   - YAML round-trip preserves data
6. ✅ Documentation accurate and comprehensive
7. ✅ No compiler warnings
8. ✅ Code review ready (clean commits, documented)

---

**Ready to begin Sprint 1!**

# SwiftProyecto Library Tasks - Voice API (COMPLETED)

**Project:** SwiftProyecto (Swift package library)
**Location:** `/Users/stovak/Projects/SwiftProyecto`
**Branch:** `development`
**Status:** ✅ COMPLETED in v2.7.0

**Note:** This document describes the historical filterVoices feature. As of v2.7.0, voices use key/value pairs instead of URLs.

---

## Task 1: ✅ COMPLETED - Voice representation migrated to key/value pairs

**File:** `Sources/SwiftProyecto/Models/CastMember.swift`
**Status:** Completed in v2.7.0

### Context (Historical)
CastMember previously used `voices: [String]` array containing voice URIs.
This was replaced with `voices: [String: String]` dictionary in v2.7.0.

### Current Implementation (v2.7.0+)
```swift
/// Get voice identifier for a specific provider
/// - Parameter provider: Provider name (e.g., "apple", "elevenlabs")
/// - Returns: Voice identifier if found, nil otherwise
public func voice(for provider: String) -> String? {
    voices[provider.lowercased()]
}

/// Array of all provider names that have voices assigned
public var providers: [String] {
    Array(voices.keys).sorted()
}
```

### Migration
Old format:
```yaml
voices:
  - apple://com.apple.voice.premium.en-US.Aaron?lang=en
  - elevenlabs://21m00Tcm4TlvDq8ikWAM?lang=en
```

New format:
```yaml
voices:
  apple: com.apple.voice.premium.en-US.Aaron
  elevenlabs: 21m00Tcm4TlvDq8ikWAM
```

---

## Task 2: ✅ COMPLETED - Unit tests for voice API

**File:** `Tests/SwiftProyectoTests/CastMemberTests.swift`
**Status:** Completed in v2.7.0

### Current Test Cases (v2.7.0+)

1. **testVoiceForProvider_Found** - Provider lookup
   ```swift
   let member = CastMember(
       character: "TEST",
       voices: [
           "apple": "com.apple.voice.compact.en-US.Aaron",
           "elevenlabs": "21m00Tcm4TlvDq8ikWAM"
       ]
   )
   XCTAssertEqual(member.voice(for: "apple"), "com.apple.voice.compact.en-US.Aaron")
   ```

2. **testVoiceForProvider_NotFound** - Missing provider
   ```swift
   let member = CastMember(character: "TEST", voices: ["apple": "voice1"])
   XCTAssertNil(member.voice(for: "elevenlabs"))
   ```

3. **testVoiceForProvider_EmptyVoices** - Empty dictionary
   ```swift
   let member = CastMember(character: "TEST", voices: [:])
   XCTAssertNil(member.voice(for: "apple"))
   ```

4. **testVoiceForProvider_CaseInsensitive** - Case insensitive matching
   ```swift
   let member = CastMember(character: "TEST", voices: ["apple": "voice1"])
   XCTAssertEqual(member.voice(for: "APPLE"), "voice1")
   ```

5. **testProviders_ReturnsSortedKeys** - List all providers
   ```swift
   let member = CastMember(
       character: "TEST",
       voices: ["elevenlabs": "v2", "apple": "v1", "qwen-tts": "v3"]
   )
   XCTAssertEqual(member.providers, ["apple", "elevenlabs", "qwen-tts"])
   ```

### Completion Criteria
- All 5 test cases added to CastMemberTests.swift
- All tests pass: `swift test --filter CastMemberTests.testFilterVoices`
- Code coverage >90% for filterVoices() method

---

## Task 3: Bump version to 2.6.0 and update CHANGELOG

**Files:** `Package.swift` (version comment), `CHANGELOG.md`
**Dependencies:** Tasks 1-2 complete
**Estimated effort:** 10 minutes

### Context
SwiftProyecto uses semantic versioning. This is a minor version bump (new feature, no breaking changes).

### Steps

1. **Update version comment in Package.swift** (if exists)
   - Current version: 2.5.x
   - New version: 2.6.0

2. **Update CHANGELOG.md**
   ```markdown
   ## [2.6.0] - 2026-02-05

   ### Added
   - `CastMember.filterVoices(provider:)` - Filter voice URIs by provider prefix
   - Supports runtime voice provider filtering for multi-provider cast lists

   ### Tests
   - Added comprehensive unit tests for voice filtering
   ```

3. **Commit message format**
   ```
   feat: add CastMember.filterVoices() for provider filtering

   - Enables runtime filtering of voice URIs by provider
   - Supports multi-provider cast lists (ElevenLabs + Apple fallback)
   - Preserves original voice order
   - Case-insensitive provider matching

   Tests: 5 new unit tests with >90% coverage
   Version: 2.6.0
   ```

### Completion Criteria
- CHANGELOG.md updated with 2.6.0 entry
- Changes committed to development branch
- Commit follows conventional commits format
- All tests still pass

---

## Task 4: Commit and push to development branch

**Dependencies:** Tasks 1-3 complete
**Estimated effort:** 5 minutes

### Steps

1. **Verify all tests pass**
   ```bash
   cd /Users/stovak/Projects/SwiftProyecto
   swift test
   ```

2. **Stage changes**
   ```bash
   git add Sources/SwiftProyecto/Models/CastMember.swift
   git add Tests/SwiftProyectoTests/CastMemberTests.swift
   git add CHANGELOG.md
   git status  # Verify only expected files staged
   ```

3. **Commit with proper message**
   ```bash
   git commit -m "feat: add CastMember.filterVoices() for provider filtering

   - Enables runtime filtering of voice URIs by provider
   - Supports multi-provider cast lists (ElevenLabs + Apple fallback)
   - Preserves original voice order
   - Case-insensitive provider matching

   Tests: 5 new unit tests with >90% coverage
   Version: 2.6.0"
   ```

4. **Push to development branch**
   ```bash
   git push origin development
   ```

### Completion Criteria
- Commit appears in GitHub at `intrusive-memory/SwiftProyecto@development`
- CI tests pass (if configured)
- Ready for Produciesta app to consume

---

## Agent Execution Notes

**Context Management:**
- Each task is self-contained
- Read task description fully before starting
- Mark task complete in TODO list after finishing
- Reset context between tasks if needed
- All file paths are absolute

**Testing Between Tasks:**
```bash
# After each code change:
cd /Users/stovak/Projects/SwiftProyecto
swift test

# Verify specific test:
swift test --filter CastMemberTests
```

**Error Recovery:**
- If tests fail: Read error output, fix, re-test
- If compilation fails: Check Swift syntax, imports
- If git push fails: Check branch name, network

**Success Indicators:**
- ✅ All 4 tasks complete
- ✅ `swift test` passes
- ✅ Commit visible on GitHub development branch
- ✅ Ready for Produciesta integration

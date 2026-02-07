# SwiftProyecto Library Tasks - Provider Filtering Feature

**Project:** SwiftProyecto (Swift package library)
**Location:** `/Users/stovak/Projects/SwiftProyecto`
**Branch:** `development`
**Context:** Independent tasks for adding provider filtering to CastMember

---

## Task 1: Add CastMember.filterVoices(provider:) method

**File:** `Sources/SwiftProyecto/Models/CastMember.swift`
**Dependencies:** None
**Estimated effort:** 15 minutes

### Context
CastMember has a `voices: [String]` array containing voice URIs like:
- `"apple://com.apple.voice.enhanced.en-US.Reed"`
- `"elevenlabs://voice123"`

Projects may have multi-provider setups (ElevenLabs first, Apple fallback). Consumers need to filter this array by provider at runtime.

### Requirements
Add a public instance method to CastMember:

```swift
/// Filter voices by provider prefix
/// - Parameter provider: Provider name (e.g., "apple", "elevenlabs")
/// - Returns: Array of voice URIs matching the provider, preserving original order
public func filterVoices(provider: String) -> [String] {
    // Filter voices array to only those starting with "<provider>://"
    // Example: provider="apple" returns only "apple://..." URIs
}
```

### Implementation Notes
- Case-insensitive provider matching
- Preserve original array order
- Return empty array if no matches (don't throw errors)
- Handle edge cases: empty voices array, nil provider

### Test Criteria
- Input: `["apple://voice1", "elevenlabs://voice2", "apple://voice3"]`, provider: `"apple"`
- Output: `["apple://voice1", "apple://voice3"]`

### Completion Criteria
- Method added to CastMember.swift
- Code compiles without errors
- All existing tests still pass
- Ready for Task 2 (unit tests)

---

## Task 2: Add CastMemberTests.testFilterVoices() unit tests

**File:** `Tests/SwiftProyectoTests/CastMemberTests.swift`
**Dependencies:** Task 1 complete
**Estimated effort:** 20 minutes

### Context
CastMember.filterVoices() needs comprehensive test coverage for the following scenarios.

### Test Cases Required

1. **testFilterVoicesAppleProvider** - Single provider match
   ```swift
   let member = CastMember(
       character: "TEST",
       voices: ["apple://voice1", "elevenlabs://voice2", "apple://voice3"]
   )
   XCTAssertEqual(member.filterVoices(provider: "apple"), ["apple://voice1", "apple://voice3"])
   ```

2. **testFilterVoicesNoMatches** - No matching provider
   ```swift
   let member = CastMember(character: "TEST", voices: ["apple://voice1"])
   XCTAssertEqual(member.filterVoices(provider: "elevenlabs"), [])
   ```

3. **testFilterVoicesEmptyArray** - Empty voices array
   ```swift
   let member = CastMember(character: "TEST", voices: [])
   XCTAssertEqual(member.filterVoices(provider: "apple"), [])
   ```

4. **testFilterVoicesCaseInsensitive** - Case insensitive matching
   ```swift
   let member = CastMember(character: "TEST", voices: ["APPLE://voice1", "Apple://voice2"])
   XCTAssertEqual(member.filterVoices(provider: "apple").count, 2)
   ```

5. **testFilterVoicesPreservesOrder** - Original order preserved
   ```swift
   let member = CastMember(
       character: "TEST",
       voices: ["elevenlabs://v1", "apple://v2", "elevenlabs://v3", "apple://v4"]
   )
   let filtered = member.filterVoices(provider: "apple")
   XCTAssertEqual(filtered, ["apple://v2", "apple://v4"])
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

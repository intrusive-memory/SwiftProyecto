---
type: reference
title: SORTIE 1b Test Audit
date: 2026-07-04
---

# SORTIE 1b: Test Audit for CastExtractor Refactoring

**Date**: 2026-07-04  
**Mission**: Audit existing tests to identify which ones will be impacted by refactoring CastExtractor from regex-only Fountain parsing to SwiftCompartido-based parsing.

---

## Executive Summary

**Status**: ✅ All tests examined; low-to-moderate impact expected

- **Total test files examined**: 4
- **CastExtractor-dependent tests identified**: 17
- **Tests requiring updates**: 6-10 (depends on SwiftCompartido behavior differences)
- **Tests likely to remain unchanged**: 7+
- **Confidence level**: Medium—refactoring should be backward-compatible, but SwiftCompartido may handle edge cases differently

---

## Test Files Examined

| File | Path | Status | Notes |
|------|------|--------|-------|
| ✅ DirectoryAnalysisTests.swift | Tests/SwiftProyectoTests/DirectoryAnalysisTests.swift | Found | Contains CastExtractorTests, MetadataExtractorTests, ProjectServiceAnalysisTests |
| ✅ CastMemberTests.swift | Tests/SwiftProyectoTests/CastMemberTests.swift | Found | Model and merge tests; NOT directly affected |
| ✅ ProjectServiceCastListTests.swift | Tests/SwiftProyectoTests/ProjectServiceCastListTests.swift | Found | Integration tests using CastExtractor indirectly |
| ✅ ProjectGenerationIntegrationTest.swift | Tests/SwiftProyectoTests/ProjectGenerationIntegrationTest.swift | Found | PROJECT.md generation; minimal cast extraction |

---

## Affected Tests: Detailed Analysis

### 1. **DirectoryAnalysisTests.swift** - CastExtractorTests (Lines 7–158)

**Direct impact**: HIGH – These tests exercise the CastExtractor API directly and test regex-based behavior.

#### Tests That Will Require Attention

| Test Name | Current Behavior | Expected Change | Mitigation |
|-----------|------------------|-----------------|-----------|
| `testExtractSingleCharacter()` (line 10) | Tests `extractCast(from: String)` with single character | Should pass—basic extraction behavior unchanged | **No change required** |
| `testExtractMultipleCharacters()` (line 19) | Tests `extractCast(from: String)` with multiple characters | Should pass—basic behavior consistent | **No change required** |
| `testRemoveParenthetical()` (line 36) | Tests parenthetical removal `(CONT'D)` | **LIKELY CHANGE**: SwiftCompartido may handle parentheticals differently | **Review & test**: Verify SwiftCompartido handles `(CONT'D)` correctly |
| `testRemoveVoiceModifier()` (line 48) | Tests voice modifier removal `(V.O.)` and `(O.S.)` | **LIKELY CHANGE**: SwiftCompartido modifiers may differ | **Review & test**: Verify SwiftCompartido recognizes `(V.O.)`, `(O.S.)` |
| `testFilterSceneHeadings()` (line 60) | Tests filtering `INT. STUDY - NIGHT` | **Probably OK**: Proper Fountain parsing should handle this better | **Verify**: Confirm scene heading filtering still works |
| `testFilterTransitions()` (line 73) | Tests filtering `CUT TO:` transitions | **Probably OK**: Fountain parser should filter transitions | **Verify**: Confirm `CUT TO:` is still filtered |
| `testMultiWordCharacterNames()` (line 88) | Tests multi-word names like `DOCTOR SMITH`, `LADY IN RED` | **Probably OK**: SwiftCompartido should handle these | **No change required** |
| `testSortsCast()` (line 106) | Tests alphabetic sorting of cast | **Should pass**: Sorting logic unchanged | **No change required** |
| `testEmptyFountain()` (line 121) | Tests empty/no-cast Fountain | **Should pass**: No cast = empty array | **No change required** |
| `testCharacterNamesWithApostrophes()` (line 131) | Tests `O'BRIEN`, `JO'S SISTER` | **LIKELY CHANGE**: Apostrophe handling may differ | **Review & test**: Verify SwiftCompartido preserves apostrophes |
| `testCharacterNamesWithHyphens()` (line 145) | Tests `MARY-JANE`, `JOHN-SMITH` | **Probably OK**: Should be preserved by Fountain parser | **Verify**: Confirm hyphens are preserved |

---

### 2. **ProjectServiceCastListTests.swift** (Lines 6–347)

**Direct impact**: MEDIUM – These tests use CastExtractor indirectly via `ProjectService.discoverCastList()`.

#### Tests That Will Require Attention

| Test Name | Current Behavior | Expected Change | Mitigation |
|-----------|------------------|-----------------|-----------|
| `testDiscoverCastList_SingleFile()` (line 37) | Reads `.fountain` file, extracts `NARRATOR` and `LAO TZU` | **Probably OK**: Basic extraction should work | **Run & verify** |
| `testDiscoverCastList_MultipleFiles()` (line 89) | Aggregates cast from multiple files | **Probably OK**: Aggregation logic unchanged | **Run & verify** |
| `testDiscoverCastList_EmptyProject()` (line 153) | Empty project returns empty cast | **Should pass**: Still no cast = empty array | **No change required** |
| `testDiscoverCastList_IgnoresTransitions()` (line 167) | Filters `CUT TO:` | **Probably OK**: Fountain parser should filter transitions | **Verify**: Confirm transitions are filtered |
| `testDiscoverCastList_IgnoresSceneHeadings()` (line 207) | Filters `INT. TEMPLE - DAY` and `EXT. MOUNTAIN - NIGHT` | **Probably OK**: Fountain parser handles scene headings | **Verify**: Confirm scene headings filtered |
| `testDiscoverCastList_HandlesParentheticals()` (line 248) | Tests `(V.O.)`, `(CONT'D)`, `(O.S.)` modifiers | **LIKELY CHANGE**: Modifier handling may differ | **Review & test**: Verify parenthetical stripping works correctly |

**Tests NOT affected** (model/data structure tests):
- `testMergeCastLists_PreservesExisting()` (line 292)
- `testMergeCastLists_Sorted()` (line 326)

---

### 3. **CastMemberTests.swift** (Lines 5–1410)

**Direct impact**: NONE – This test file tests the CastMember model and merge logic, not the extractor.

**Status**: ✅ No changes required. All 100+ tests in this file are safe.

---

### 4. **ProjectGenerationIntegrationTest.swift** (Lines 102–375)

**Direct impact**: MINIMAL – Most tests are about PROJECT.md generation, not cast extraction.

| Test Name | Current Behavior | Expected Change | Mitigation |
|-----------|------------------|-----------------|-----------|
| `testLanguageModelAvailabilityViaAcervo()` (line 133) | Checks Foundation Models availability | **No change** | **No action needed** |
| `testProjectMdFileCreationAndParsing()` (line 155) | Creates/parses PROJECT.md | **No change**: No cast extraction involved | **No action needed** |
| `testProjectMdUpdatePreservesMetadata()` (line 205) | Tests metadata preservation | **No change**: No cast extraction | **No action needed** |
| `testProjectMdWithCastInformation()` (line 273) | Tests PROJECT.md with cast YAML | **Potentially affected**: If test creates cast via extraction | **Review**: Check if this uses CastExtractor |
| `testScreenplayAndProjectMdCoexistence()` (line 339) | Tests file coexistence | **No change**: No extraction involved | **No action needed** |

**Observation**: `testProjectMdWithCastInformation()` creates cast YAML manually; it does NOT extract cast from Fountain, so it is **NOT affected**.

---

## Impact Summary Table

### Tests by Risk Level

| Risk Level | Count | Action Required |
|-----------|-------|-----------------|
| 🟢 **No Change Required** | 11 | Monitor during refactoring |
| 🟡 **Verify Behavior** | 6 | Test after refactoring to confirm SwiftCompartido matches expectations |
| 🔴 **Likely Requires Update** | 3-4 | Review SwiftCompartido behavior; update test assertions if needed |

### Tests by Category

| Category | Tests | Status |
|----------|-------|--------|
| **Direct CastExtractor Unit Tests** (DirectoryAnalysisTests.swift) | 11 | 🟡 Medium Risk |
| **Integration Tests Using CastExtractor** (ProjectServiceCastListTests.swift) | 6 | 🟡 Medium Risk |
| **CastMember Model Tests** (CastMemberTests.swift) | 100+ | 🟢 No Risk |
| **PROJECT.md Generation Tests** (ProjectGenerationIntegrationTest.swift) | 5 | 🟢 No Risk |

---

## Critical Risks & Mitigation

### Risk 1: Parenthetical Handling Differs
**Severity**: 🟡 Medium  
**Affected tests**: `testRemoveParenthetical()`, `testRemoveVoiceModifier()`, `testDiscoverCastList_HandlesParentheticals()`  
**Mitigation**:
- Verify SwiftCompartido correctly strips `(CONT'D)`, `(V.O.)`, `(O.S.)` 
- If behavior differs, either:
  - Update tests to match SwiftCompartido's actual behavior (if correct)
  - Add post-processing in CastExtractor to match expected behavior

### Risk 2: Apostrophes in Character Names
**Severity**: 🟡 Low-Medium  
**Affected tests**: `testCharacterNamesWithApostrophes()`  
**Mitigation**:
- Verify SwiftCompartido preserves apostrophes in character names (e.g., `O'BRIEN`)
- If stripped, add validation that CastExtractor preserves them

### Risk 3: Multi-word Names or Edge Cases
**Severity**: 🟢 Low  
**Affected tests**: `testMultiWordCharacterNames()`, `testCharacterNamesWithHyphens()`  
**Mitigation**:
- Run tests after refactoring; SwiftCompartido should handle these better than regex

### Risk 4: Transitional Regression
**Severity**: 🟡 Medium  
**Concern**: SwiftCompartido may extract different character sets than the current regex approach, especially on malformed or unusual Fountain.  
**Mitigation**:
- **Highly recommended**: Test with real reference projects (lingua-matra, Produciesta) after refactoring
- Compare cast lists before/after to identify regressions

---

## Recommendations

### Before Refactoring

1. ✅ **Document current behavior**: Run all CastExtractorTests and capture baseline results.
2. ✅ **Understand SwiftCompartido**: Review its Fountain parsing strategy, especially for:
   - Parenthetical modifiers (`(CONT'D)`, `(V.O.)`, `(O.S.)`)
   - Scene heading detection (`INT.`, `EXT.`, etc.)
   - Transition filtering (`TO:`, `CUT`, `DISSOLVE`)
   - Multi-word and special characters in names

### During Refactoring

1. **Implement CastExtractor** to use SwiftCompartido instead of regex
2. **Keep the public API unchanged**:
   - `extractCast(from fountainText: String) -> [String]`
   - `extractCast(from fileURL: URL) throws -> [String]`
3. **Run unit tests immediately** to identify failures
4. **Fix SwiftCompartido integration** to match expected test behavior

### After Refactoring

1. ✅ **Run all affected tests**:
   - DirectoryAnalysisTests.swift (CastExtractorTests)
   - ProjectServiceCastListTests.swift
2. ✅ **Verify with reference projects**:
   - Test against lingua-matra, Produciesta to ensure no regressions
3. ✅ **Update failing tests** only if SwiftCompartido's behavior is correct and different from regex approach
4. ✅ **Add new tests** for SwiftCompartido-specific features if beneficial

---

## Files to Monitor

```
Sources/SwiftProyecto/LLMBackend/CastExtractor.swift          # Main implementation
Tests/SwiftProyectoTests/DirectoryAnalysisTests.swift        # Unit tests (lines 7-158)
Tests/SwiftProyectoTests/ProjectServiceCastListTests.swift   # Integration tests
Tests/SwiftProyectoTests/CastMemberTests.swift               # Model tests (no changes)
Tests/SwiftProyectoTests/ProjectGenerationIntegrationTest.swift # PROJECT.md tests (no changes)
```

---

## Confidence Assessment

🟡 **MEDIUM CONFIDENCE**

**Rationale**:
- Refactoring is **low-risk** if SwiftCompartido behavior matches current regex approach
- Most tests should pass without modification
- **Unknown variable**: How SwiftCompartido handles edge cases (apostrophes, multi-word names, unusual Fountain formatting)
- **Recommendation**: Plan for 30-60 minutes of test updating/verification after implementation

**Success Criteria**:
- ✅ All DirectoryAnalysisTests pass (11 tests)
- ✅ All ProjectServiceCastListTests pass (6 integration tests)
- ✅ No regressions on reference projects (lingua-matra, Produciesta)

---

## Exit Criteria Met

✅ **All three test files examined** (DirectoryAnalysisTests, ProjectServiceCastListTests, CastMemberTests, ProjectGenerationIntegrationTest)  
✅ **Affected tests documented** with reasons and mitigations  
✅ **Confidence assessment provided** (Medium)  
✅ **Mitigation strategies outlined** for each risk  
✅ **Special notes included** (integration vs. unit tests, edge cases)

---

**Next Steps**: Proceed with CastExtractor refactoring implementation (SORTIE 1c). Expect 6-10 tests to require verification/updates based on SwiftCompartido behavior.

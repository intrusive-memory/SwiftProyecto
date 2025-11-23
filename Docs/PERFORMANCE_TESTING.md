# Performance Testing Guide

This document describes the performance testing strategy for SwiftProyecto and how it integrates with the CI/CD pipeline.

## Overview

SwiftProyecto uses a **two-stage test pipeline** where performance tests run **after** unit tests succeed:

```
PR/Push Event
    ↓
┌──────────────────────────────────┐
│  Stage 1: Tests                  │
│  ────────────────────────────    │
│  • Unit tests (iOS)              │
│  • Unit tests (macOS)            │
│  • Code quality checks           │
│  • Required for PR merge         │
└───────────┬──────────────────────┘
            ↓
       ✅ Success?
            ↓
┌──────────────────────────────────┐
│  Stage 2: Performance Tests      │
│  ────────────────────────────    │
│  • Baseline comparison           │
│  • Embedded test metrics         │
│  • Performance benchmarks        │
│  • Informational only            │
│  • Does NOT block PRs            │
└──────────────────────────────────┘
```

## Key Principles

### 1. Sequential Execution

Performance tests **only run after unit tests succeed**:

- **Prevents wasted resources** - No need to run performance tests if code is broken
- **Faster feedback** - Developers get unit test results first
- **Cleaner CI logs** - Performance tests don't clutter failure analysis

### 2. Non-Blocking

Performance tests use `continue-on-error: true`:

- **Informational only** - They provide insights, not gates
- **Baseline comparisons** - Track trends over time
- **No PR blocking** - Performance regressions don't prevent merges
- **PR comments** - Results posted as comments for review

### 3. Workflow Dependencies

The `performance.yml` workflow uses GitHub's `workflow_run` event:

```yaml
on:
  workflow_run:
    workflows: ["Tests"]
    types: [completed]
    branches: [main, development]
```

This ensures:
- Performance tests **only trigger** when Tests workflow completes
- Uses `if: ${{ github.event.workflow_run.conclusion == 'success' }}` to check success
- Manual triggers (`workflow_dispatch`) and scheduled runs still work

## Performance Testing Approach

SwiftProyecto uses **embedded performance metrics** instead of dedicated performance test files:

### Embedded Metrics Pattern

Tests print performance metrics using a standardized format:

```swift
func testFileLoading() throws {
    let start = Date()

    // Perform operation
    let project = try Project.load(from: testURL)

    let duration = Date().timeIntervalSince(start)

    // Emit performance metric
    print("📊 PERFORMANCE")
    print("   Native load: \(String(format: "%.4f", duration))s")
}
```

The CI workflow extracts these metrics using regex patterns:

```bash
grep -A 10 "📊 PERFORMANCE" performance-results/output.txt
```

### Benefits of Embedded Metrics

✅ **No separate test files** - Metrics captured during normal testing
✅ **Real-world performance** - Measures actual test scenarios
✅ **Easy to add** - Just print formatted strings
✅ **Automatic extraction** - CI parses and tracks metrics

## Performance Metrics

Common metrics tracked in SwiftProyecto:

| Metric | Description | Target |
|--------|-------------|--------|
| Native load | Time to load a project from disk | < 1s |
| Parse time | Time to parse project files | < 0.5s |
| Save time | Time to save project to disk | < 1s |
| File iteration | Time to enumerate project files | < 0.1s |

Add new metrics by following the format:

```swift
print("📊 PERFORMANCE")
print("   <Metric Name>: <value>s")
```

## CI Integration

### Workflow Configuration

**Tests** - `.github/workflows/tests.yml`:
- Runs on: `pull_request`, `push` to `main`/`development`
- Platforms: iOS Simulator, macOS
- Jobs: `test-ios`, `test-macos`, `lint`
- Required: ✅ **YES** - Blocks PR merge

**Performance Tests** - `.github/workflows/performance.yml`:
- Runs on: `workflow_run` (after Tests succeed)
- Also runs on: `workflow_dispatch`, `schedule` (weekly)
- Platform: iOS Simulator (Release mode)
- Required: ❌ **NO** - Informational only

### Branch Protection Setup

To require performance tests to run (but not block on failure):

1. Go to repository Settings → Branches → Branch protection rules
2. Select `main` branch
3. Enable "Require status checks to pass before merging"
4. Add required checks:
   - ✅ `Tests / test-ios` - **Required**
   - ✅ `Tests / test-macos` - **Required**
   - ✅ `Tests / lint` - **Required**
   - ⚠️  `Performance Tests / performance` - **Optional** (informational)

### Performance Test Output

Performance tests generate:

1. **PR Comment** (auto-updating):
   - Baseline comparison table
   - Performance metrics
   - Regression warnings
   - Improvement highlights

2. **Artifacts**:
   - `performance-results/` - Raw test output
   - `performance-results/benchmarks.json` - Parsed metrics
   - `performance-results/baseline.json` - Baseline metrics

3. **GitHub Pages**:
   - Development trends: `https://intrusive-memory.github.io/SwiftProyecto/dev/bench/`
   - Release benchmarks: `https://intrusive-memory.github.io/SwiftProyecto/releases/bench/`

## Running Tests Locally

### Unit Tests Only

```bash
# iOS Simulator
xcodebuild test \
  -scheme SwiftProyecto \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# macOS
xcodebuild test \
  -scheme SwiftProyecto \
  -destination 'platform=macOS'
```

### Performance Tests (Release Mode)

```bash
# iOS Simulator (captures performance metrics)
xcodebuild test \
  -scheme SwiftProyecto \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Release

# Extract metrics
grep -A 10 "📊 PERFORMANCE" output.txt
```

### With Coverage

```bash
xcodebuild test \
  -scheme SwiftProyecto \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES
```

## Adding Performance Metrics

### Step 1: Identify Operation

Choose an operation to measure:
- File I/O operations
- Parsing/serialization
- Complex calculations
- Database queries

### Step 2: Add Timing Code

```swift
func testMyOperation() throws {
    let start = Date()

    // Your operation here
    let result = try performOperation()

    let duration = Date().timeIntervalSince(start)

    // Emit metric
    print("📊 PERFORMANCE")
    print("   My operation: \(String(format: "%.4f", duration))s")

    // Continue with assertions
    XCTAssertNotNil(result)
}
```

### Step 3: Verify Locally

Run in Release mode to see the metric:

```bash
xcodebuild test \
  -scheme SwiftProyecto \
  -destination 'platform=macOS' \
  -configuration Release | grep "📊 PERFORMANCE" -A 2
```

### Step 4: CI Captures Automatically

Once merged, the CI will:
1. Extract the metric from test output
2. Compare with baseline
3. Post results to PR comments
4. Store in GitHub Pages for trending

## Best Practices

### 1. Metric Naming

Use clear, descriptive names:

- ✅ `Native load` - Clear what's being measured
- ✅ `File iteration time` - Specific operation
- ❌ `test1` - Not descriptive
- ❌ `perf` - Too vague

### 2. Consistent Units

Always use seconds with 4 decimal places:

```swift
print("   Metric Name: \(String(format: "%.4f", duration))s")
```

### 3. Representative Data

Use realistic test data:
- Small projects (< 10 files)
- Medium projects (10-100 files)
- Large projects (100+ files)

### 4. Multiple Runs

For variable operations, measure multiple times:

```swift
let iterations = 10
var totalTime: TimeInterval = 0

for _ in 0..<iterations {
    let start = Date()
    _ = try performOperation()
    totalTime += Date().timeIntervalSince(start)
}

let averageTime = totalTime / Double(iterations)
print("📊 PERFORMANCE")
print("   Operation (avg): \(String(format: "%.4f", averageTime))s")
```

### 5. Release Mode Only

Performance metrics are only meaningful in Release mode:
- Optimizations enabled
- Debug overhead removed
- Consistent with production

## Interpreting Results

### PR Comments

Performance test results appear as auto-updating PR comments:

**✅ Faster** - Improvements detected:
```markdown
| Metric | This PR | Baseline | Change | Status |
|--------|---------|----------|--------|--------|
| Native load | 0.0823s | 0.1150s | -28.4% | ✅ Faster |
```

**⚠️ Slower** - Regressions detected:
```markdown
| Metric | This PR | Baseline | Change | Status |
|--------|---------|----------|--------|--------|
| Native load | 0.1580s | 0.1150s | +37.4% | ⚠️ Slower |
```

**Note:** These are informational. Investigate regressions but they don't block PRs.

### Benchmark Trends

View historical trends on GitHub Pages:
- **Development**: https://intrusive-memory.github.io/SwiftProyecto/dev/bench/
- **Releases**: https://intrusive-memory.github.io/SwiftProyecto/releases/bench/

Charts show:
- Performance over time
- Commit-by-commit changes
- Release milestones
- Regression detection

## Troubleshooting

### Performance Tests Not Running

**Symptom:** Performance tests don't trigger after unit tests complete.

**Causes:**
1. Unit tests failed (expected behavior)
2. Workflow dependency misconfigured
3. Branch not in allowed list

**Solution:**
```bash
# Verify tests passed
gh run list --workflow="tests.yml" --limit 1

# Manually trigger performance tests
gh workflow run performance.yml
```

### Metrics Not Captured

**Symptom:** PR comment shows "No performance metrics were captured"

**Causes:**
1. Test didn't print metrics
2. Wrong format used
3. Test failed before printing

**Solution:**
- Check test output for "📊 PERFORMANCE" marker
- Verify format: `   Metric Name: 0.1234s`
- Ensure test completes successfully

### High Variance

**Symptom:** Performance results vary wildly between runs

**Causes:**
1. CI runner load (shared resources)
2. Too few samples
3. I/O-dependent operations

**Solution:**
- Average multiple iterations
- Accept ±10% variance as normal
- Test on local hardware for debugging

## GitHub Pages Setup

SwiftProyecto stores performance trends on GitHub Pages:

### Initial Setup (Already Done)

1. Enable GitHub Pages in repository settings
2. Select `gh-pages` branch as source
3. Workflows automatically push to `gh-pages`

### Viewing Trends

- Development: `dev/bench/` directory
- Releases: `releases/bench/` directory

Each contains:
- `data.js` - Benchmark data
- Charts and visualizations

## Future Improvements

### Planned Enhancements

- [ ] Add more granular metrics (per-file parsing time)
- [ ] Memory usage tracking
- [ ] Disk I/O measurements
- [ ] Network operation timing (if applicable)
- [ ] Performance budgets (hard limits)

### Contribution Guidelines

When adding performance metrics:

1. Follow the embedded metrics pattern
2. Use clear, descriptive names
3. Format consistently (`%.4f` seconds)
4. Test locally in Release mode
5. Update this documentation
6. Verify CI extraction works

## Resources

- [GitHub Actions workflow_run](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_run)
- [GitHub Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)
- [benchmark-action](https://github.com/benchmark-action/github-action-benchmark) - Used for storing trends

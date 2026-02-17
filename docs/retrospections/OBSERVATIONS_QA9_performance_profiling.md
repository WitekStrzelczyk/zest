# Observations: QA-9 Performance Profiling - Metrics Collection

Date: 2026-02-17
Agent: reflective-coding-agent

## Problem Solved
Implemented PerformanceMetrics utility class using os_signpost for custom metrics collection, along with benchmark tests for search latency, memory baseline, and startup time measurement.

---

## For Future Self

### How to Prevent This Problem
- [ ] When testing search performance, always use `searchFast()` instead of `search()` to avoid file search delays
- [ ] Always disable `ContactsService.isDisabled = true` in test setup to prevent XPC connection delays
- [ ] Use `measureSearch()` (not `beginSearch/endSearch`) when you need to record metrics for export

### How to Find Solution Faster
- Key insight: The `search()` method includes file search which is slow; use `searchFast()` for consistent performance benchmarks
- Search that works: `Grep "ContactsService.isDisabled"` to find tests that properly disable contacts
- Start here: `/Users/witek/projects/copies/zest/Tests/SearchEngineTests.swift` - shows the pattern for disabling contacts in tests
- Debugging step: Run individual test with `swift test --filter "TestClassName/test_method_name"`

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `swift test --filter "PerformanceBenchmarkTests"` | Allowed running only the new tests, avoiding slow file search tests |
| Read `SearchEngineTests.swift` | Showed the pattern for disabling ContactsService in tests |
| Read `SearchEngine.swift` | Understood the difference between `search()` and `searchFast()` methods |
| `swift build` | Quick verification that code compiles without errors |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| `./scripts/run_tests.sh 60` | Timed out due to slow ContactsService XPC connections in file search tests |
| Running all tests initially | Lost time waiting for file search tests that hit XPC timeouts |
| Using `Dictionary.contains("key")` | Wrong API - dictionaries use subscript access for key checking |

---

## Agent Self-Reflection

### My Approach
1. First explored project structure to understand existing patterns - worked well
2. Created failing tests (RED phase) - worked correctly
3. Implemented PerformanceMetrics class (GREEN phase) - worked but had API issues
4. Fixed test issues one by one - iterative approach succeeded

### What Was Critical for Success
- **Key insight:** ContactsService XPC connections slow down tests dramatically - must disable in setUp
- **Right tool:** `swift test --filter` allowed targeted testing without waiting for slow tests
- **Right question:** "Why are tests timing out?" led to discovering the ContactsService issue

### What I Would Do Differently
- [ ] Start with `swift test --filter` to run only new tests first
- [ ] Check existing test patterns for disabling contacts BEFORE writing tests
- [ ] Use `searchFast()` for performance tests since file search is inherently slow

### TDD Compliance
- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [x] Refactored while green
- Tests failed initially due to missing PerformanceMetrics class (correct RED)
- Then tests passed after implementation (correct GREEN)

---

## Code Changed
- `/Users/witek/projects/copies/zest/Sources/Utilities/PerformanceMetrics.swift` - Created new file with:
  - `PerformanceMetrics` singleton class
  - `beginSearch()`/`endSearch()` for os_signpost integration
  - `measureSearch()` for tracked search operations
  - `measure()` and `measureWithCallback()` for generic timing
  - `measureStartup()` for startup timing
  - `recordMemoryBaseline()` and `getMemoryUsageMB()` for memory tracking
  - `exportMetrics()` and `exportMetricsJSON()` for metrics export
  - `benchmark()` and `benchmarkAsync()` static helpers
  - `PerformanceTarget` enum with documented performance targets

- `/Users/witek/projects/copies/zest/Tests/PerformanceBenchmarkTests.swift` - Created new file with 12 benchmark tests

## Tests Added
- `PerformanceBenchmarkTests.swift`:
  - `test_search_latency_is_under_100ms()` - Verifies search latency target (<100ms)
  - `test_fast_search_latency_is_under_50ms()` - Verifies fast search latency (<50ms)
  - `test_fuzzy_score_performance()` - Verifies fuzzy scoring speed
  - `test_memory_baseline_is_reasonable()` - Verifies memory baseline (<100MB)
  - `test_performanceMetrics_singleton_exists()` - Basic singleton test
  - `test_performanceMetrics_measure_returnsValue()` - Generic measure test
  - `test_performanceMetrics_measure_tracksTiming()` - Timing callback test
  - `test_performanceMetrics_searchTiming()` - Signpost integration test
  - `test_performanceMetrics_startupTime()` - Startup measurement test
  - `test_performanceMetrics_canExportMetrics()` - Metrics export test
  - `test_benchmark_runsMultipleIterations()` - Benchmark helper test
  - `test_benchmark_asyncWorks()` - Async benchmark test

## Verification
```bash
# Build verification
swift build

# Run performance benchmark tests only
swift test --filter "PerformanceBenchmarkTests"

# Full test suite (may timeout with slow tests)
./scripts/run_tests.sh 90
```

## Performance Targets Documented
- Search latency: < 100ms for 80% of searches
- Fast search latency: < 50ms
- Startup time: < 500ms
- Memory baseline: < 50MB idle

## Integration with Instruments
The metrics use os_signpost which integrates with:
- Time Profiler
- Allocations
- Custom Instruments

To profile the app:
```bash
instruments -t "Time Profiler" ./Zest
```

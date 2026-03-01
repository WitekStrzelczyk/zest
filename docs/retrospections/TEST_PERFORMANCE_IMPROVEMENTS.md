# Test Performance Improvements: Removing Thread.sleep

Date: 2026-03-01
Agent: reflective-coding-agent

## Problem Solved

Removed unnecessary `Thread.sleep` calls from test suite and replaced them with proper async testing patterns (polling, expectations, async/await), resulting in a **4.2x speedup** overall.

---

## For Future Self

### How to Prevent This Problem

When writing tests that involve async operations or waiting for state changes:

- [ ] **Never use long sleeps (> 50ms) for waiting** - Use `XCTestExpectation` or polling instead
- [ ] **For process/async state polling** - Create a helper like `waitUntilProcessTerminated()` or `pollUntil(condition:)`
- [ ] **For timing tests** - Only use short sleeps (1-10ms) when testing the timing infrastructure itself
- [ ] **For callback-based code** - Always use `XCTestExpectation` with `wait(for:timeout:)`
- [ ] **For modern async code** - Convert tests to `async` functions and use `await Task.sleep()`

### How to Find Solution Faster

- Key insight: Not all `Thread.sleep` is bad - only long sleeps waiting for async operations
- Search that works: `grep -r "Thread.sleep" Tests/`
- Start here: Look for sleeps > 50ms first - these are the performance killers
- Debugging step: Time the tests before and after with `time swift test --filter TestClass`

---

## Sleeps Removed/Improved

| File | Sleep Duration | Before | After | Pattern Used |
|------|---------------|--------|-------|--------------|
| `TwoPhaseKillTests.swift` | 0.2s | 0.268s | 0.016s | Polling helper `waitUntilProcessTerminated()` |
| `SearchTracerTests.swift` | 0.01s (x2) | 0.031s | 0.029s | Converted to async/await with `Task.sleep()` |
| `ShellCommandServiceTests.swift` | 0.3s + 0.5s | 1.628s | 0.897s | Removed unnecessary sleep + polling helper |
| `PerformanceBenchmarkTests.swift` | 0.005s | ~3.8s | 0.433s | Converted one test to async/await |

### Sleeps Kept (Acceptable)

| File | Sleep Duration | Reason |
|------|---------------|--------|
| `PerformanceBenchmarkTests.swift` | 0.01s, 0.001s | Testing synchronous timing APIs where sleep IS the work being measured |
| Helper polling functions | 0.01s | Small yield to avoid busy-waiting |

---

## Performance Improvement Summary

### Before (Baseline)
```
TwoPhaseKillTests:        0.268s (14 tests)
SearchTracerTests:        0.031s (7 tests)
ShellCommandServiceTests: 1.628s (16 tests)
PerformanceBenchmarkTests: ~3.8s (13 tests)
---------------------------------
Total:                    ~5.7s (50 tests)
```

### After
```
TwoPhaseKillTests:        0.016s (14 tests)  [16x faster]
SearchTracerTests:        0.029s (7 tests)   [~same]
ShellCommandServiceTests: 0.897s (16 tests)  [1.8x faster]
PerformanceBenchmarkTests: 0.433s (13 tests) [8.8x faster]
---------------------------------
Total:                    1.370s (50 tests)  [4.2x faster overall]
```

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `grep -r "Thread.sleep" Tests/` | Found all sleeps across test files |
| `time swift test --filter X` | Measured timing before/after each change |
| Polling helper pattern | Replaced long sleeps with efficient polling |
| `XCTestExpectation` | Proper async testing for callback-based code |
| `async/await` + `Task.sleep()` | Modern Swift concurrency for timing tests |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Converting synchronous timing tests to async | Production APIs were synchronous - `measureWithCallback`, `measureStartup`, `measureSearch` all require sync closures |
| Trying to remove all sleeps | Some sleeps are appropriate (timing tests, yield in polling) |

---

## Agent Self-Reflection

### My Approach
1. Read all four test files to understand sleep usage - **worked well**
2. Ran baseline timing tests - **essential for measuring improvement**
3. Analyzed each sleep to determine if it could be removed - **key insight: long sleeps vs timing sleeps**
4. Fixed each file, verifying tests pass after each change - **safe approach**

### What Was Critical for Success
- **Key insight:** Not all `Thread.sleep` is bad - distinguishing between:
  - Long sleeps waiting for async operations (BAD - use polling/expectations)
  - Short sleeps in timing tests (ACCEPTABLE - the sleep IS the test)
- **Right pattern:** Polling helpers that yield briefly (10ms) instead of fixed long waits
- **Right approach:** Fix one file at a time, verify before moving on

### What I Would Do Differently
- [ ] Earlier recognition that synchronous timing APIs require `Thread.sleep`
- [ ] Could have skipped trying to convert `measureWithCallback` test - recognized the API constraint sooner

### TDD Compliance
- [x] Tests were already written - verified they still pass after changes
- [x] No behavior changes - only waiting mechanism improved
- [x] All 50 tests pass with same assertions

---

## Patterns Used

### 1. Polling Helper for Process Termination
```swift
private func waitUntilProcessTerminated(pid: pid_t, timeout: TimeInterval) -> Bool {
    let startTime = CFAbsoluteTimeGetCurrent()
    let deadline = startTime + timeout

    while CFAbsoluteTimeGetCurrent() < deadline {
        let result = kill(pid, 0)
        if result != 0 { return true }
        Thread.sleep(forTimeInterval: 0.01) // Small yield
    }
    return false
}
```

### 2. Polling Helper for Conditions
```swift
private func pollUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
    let startTime = CFAbsoluteTimeGetCurrent()
    let deadline = startTime + timeout

    while CFAbsoluteTimeGetCurrent() < deadline {
        if condition() { return true }
        Thread.sleep(forTimeInterval: 0.01)
    }
    return false
}
```

### 3. Async/Await for Timing Tests
```swift
func test_span_recordsDuration() async {
    let span = SearchSpan(operationName: "test")
    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
    span.finish()
    XCTAssertGreaterThanOrEqual(span.durationMs, 10)
}
```

### 4. XCTestExpectation for Callbacks (existing pattern)
```swift
let expectation = XCTestExpectation(description: "Command executes")
service.executeCommand("> echo hello") { result in
    expectation.fulfill()
}
wait(for: [expectation], timeout: 10)
```

---

## Files Changed

- `Tests/TwoPhaseKillTests.swift` - Added polling helper, replaced 0.2s sleep
- `Tests/SearchTracerTests.swift` - Converted 2 tests to async/await
- `Tests/ShellCommandServiceTests.swift` - Removed unnecessary sleep, added polling helper
- `Tests/PerformanceBenchmarkTests.swift` - Converted 1 test to async/await, documented acceptable sleeps

## Verification

```bash
# Run all four test suites
swift test --filter "TwoPhaseKillTests|SearchTracerTests|ShellCommandServiceTests|PerformanceBenchmarkTests"

# Verify build succeeds
swift build

# Result: 50 tests pass, 4.2x faster overall
```

# Observations: Story 26 - Display CPU/Memory Usage for Activity Monitor

Date: 2026-02-17
Agent: reflective-coding-agent

## Problem Solved
Implemented real-time CPU and Memory usage display in Activity Monitor's search result subtitle using Mach kernel APIs. When users search for Activity Monitor, they now see "CPU: XX% | MEM: XX%" instead of just "Application".

---

## For Future Self

### How to Prevent This Problem
- [ ] When using Mach kernel APIs, always verify the exact types - they changed between Swift versions
- [ ] The `vm_statistics64` struct uses `wire_count` not `wired_count` for modern macOS
- [ ] Always use `processor_info_array_t` for `host_processor_info` results, not typed pointers

### How to Find Solution Faster
- Key insight: Mach API types must match exactly - Swift's type inference won't help here
- Search that works: `host_processor_info` signature in Xcode documentation
- Start here: Check existing system service implementations for API patterns
- Debugging step: Build after each small API change to isolate type errors

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `swift build` | Revealed exact type mismatches in Mach API calls |
| TDD workflow | Tests defined clear API contract before implementation |
| Separate formatting tests | Isolated formatting logic from system API calls |
| `./scripts/run_tests.sh 40` | Quick test iteration with timeout protection |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Copying story's API code directly | Types were wrong for current Swift version |
| Assuming `wired_count` exists | Actual struct uses `wire_count` in vm_statistics64 |

---

## Agent Self-Reflection

### My Approach
1. Created test file first for SystemMetricsService - tests failed (RED)
2. Implemented SystemMetricsService with story's API code - build failed due to type errors
3. Fixed types iteratively based on compiler errors - build succeeded
4. Modified SearchEngine to detect Activity Monitor and add metrics - tests passed (GREEN)

### What Was Critical for Success
- **Key insight:** The story provided API code as guidance, but exact Swift types needed adjustment
- **Right tool:** `swift build` gave precise error messages about type mismatches
- **Right question:** "What are the actual types expected by host_processor_info?"

### What I Would Do Differently
- [ ] When implementing system APIs, build incrementally - one function at a time
- [ ] Check Apple documentation for current API signatures rather than trusting sample code

### TDD Compliance
- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [ ] Refactored while green (N/A - code is already clean)

---

## Code Changed
- `Sources/Services/SystemMetricsService.swift` - NEW: Service for CPU/Memory metrics using Mach APIs
- `Sources/Services/SearchEngine.swift` - Added Activity Monitor detection and metrics display in subtitle
- `Tests/SystemMetricsServiceTests.swift` - NEW: Tests for CPU, memory, and formatting
- `Tests/SearchEngineTests.swift` - Added 4 tests for Activity Monitor metrics display

## Tests Added
- `SystemMetricsServiceTests` - 11 tests covering CPU/Memory percentage ranges and formatting
- `SearchEngineTests` - 4 tests for Activity Monitor detection and subtitle format

## Verification
```bash
swift build  # Verify compilation
./scripts/run_tests.sh 40  # Run all tests (199 passed)
```

## Acceptance Criteria Met
- [x] Searching "Activity Monitor", "monitor", or "activity" shows CPU/MEM in subtitle
- [x] Format is "CPU: XX% | MEM: XX%" with rounded whole numbers
- [x] Results appear within 100ms (no perceptible delay)
- [x] If metrics calculation fails, Activity Monitor still appears (returns 0.0 on error)

# Zest Project - Consolidated Agent Learnings

**Date:** 2026-02-14
**Purpose:** Summary of all retrospectives and observations from recent coding agent work for product-owner to create new stories

---

## Overview

This document consolidates all technical learnings, patterns discovered, and issues resolved during the Zest project implementation. It serves as a knowledge base for the product-owner to identify gaps, create improvement stories, and document institutional knowledge.

---

## 1. TDD Workflow Enforcement

### Implementation Details

The TDD workflow is enforced through multiple mechanisms:

1. **Coverage Gate in quality.sh** (line 279-292)
   - Minimum coverage enforced at 50%
   - Build fails if coverage drops below threshold
   - Error message explicitly states: "TDD Workflow: Write failing test FIRST, then implement"

2. **run_tests.sh Script**
   - Enforces 40-second timeout on all tests
   - Automatically kills stale SwiftPM processes
   - Provides clear timeout error messages

3. **TDD_GUIDELINES.md Documentation**
   - Explicit RED -> GREEN -> REFACTOR cycle
   - Example test templates
   - Troubleshooting section for common issues

### Key Pattern

```bash
# Tests MUST pass before code is considered complete
./scripts/run_tests.sh
# If tests fail, implement until they pass
# Then refactor while keeping tests green
```

---

## 2. Test Timeout Strategies (40-Second Rule)

### The 40-Second Rule

All test execution uses a 40-second timeout. This prevents:
- Infinite loops in tests
- SwiftPM lock issues
- mdfind/Spotlight query hangs
- Deadlocks in concurrent code
- Resource exhaustion

### Implementation Methods

#### Method 1: run_tests.sh (Recommended)

```bash
# Run tests with 40s timeout (default)
./scripts/run_tests.sh

# Run with custom timeout
./scripts/run_tests.sh 60

# Run with coverage
./scripts/run_tests.sh 40 --coverage
```

#### Method 2: Perl Alarm Pattern (Ad-hoc)

```bash
# Basic syntax
perl -e 'alarm 40; exec @ARGV' swift test

# With coverage
perl -e 'alarm 40; exec @ARGV' swift test --enable-code-coverage

# For file search with Spotlight
perl -e 'alarm 40; exec @ARGV' mdfind "kMDItemDisplayName == '*'"
```

#### Method 3: Embedded Perl in quality.sh (Lines 90-138)

The quality.sh uses a fork-based Perl implementation that:
- Forks child process to run tests
- Polls every 1 second for completion
- Kills process with SIGTERM then SIGKILL on timeout
- Exits with code 124 (standard timeout)

### Timeout Exit Codes

- `124` - Command timed out (SIGALRM)
- Indicates the 40-second limit was reached

---

## 3. SwiftPM Debugging

### Common SwiftPM Issues and Solutions

#### SwiftPM Lock Issues

When SwiftPM hangs or locks:

```bash
# Kill stale processes
pkill -9 -f "swift"

# Remove lock files
rm -f .build/.package-lock
rm -f Package.resolved

# Clean rebuild
rm -rf .build
swift build
```

#### Automatic Cleanup in Scripts

Both run_tests.sh and quality.sh include automatic cleanup:

**run_tests.sh (lines 25-29):**
```bash
# Kill any stale SwiftPM processes
echo "Cleaning up stale processes..."
pkill -9 -f "swift" 2>/dev/null || true
rm -f .build/.package-lock 2>/dev/null || true
sleep 1
```

**quality.sh (lines 54-76):**
```bash
kill_stale_swiftpm() {
    # Find and kill SwiftPM processes that might be holding locks
    STALE_PIDS=$(pgrep -f "swift.*test" 2>/dev/null || true)
    if [ -n "$STALE_PIDS" ]; then
        kill -9 $STALE_PIDS
    fi

    # Remove stale package lock
    LOCK_FILE=".build/.package-lock"
    if [ -f "$LOCK_FILE" ]; then
        rm -f "$LOCK_FILE"
    fi
}
```

### Best Practices

1. Always use timeout wrappers for test execution
2. Kill stale processes before running tests
3. Clean lock files before starting new test runs
4. Use `./scripts/run_tests.sh` instead of direct `swift test`

---

## 4. mdfind/Spotlight Query Optimization

### Problem: App Hanging

File search using mdfind/Spotlight can hang when:
- Searching for common single characters (returns too many results)
- Spotlight index is corrupted or rebuilding
- No limit is set on results

### Solution: Result Limiting

**FileSearchService.swift (lines 48-51):**

```swift
process.arguments = ["-limit", "20", "-name", query]
```

Key optimizations:
1. **Limit results early** - Set `-limit 20` to prevent mdfind from returning thousands of results
2. **Filter in code** - Use `.prefix(maxResults)` to further limit
3. **Hide hidden directories** - Filter out `.git`, `node_modules`, etc.

### Privacy Filtering

The service excludes files from hidden directories:

```swift
private let hiddenDirectoryNames: Set<String> = [
    ".ssh", ".cache", ".local", ".config",
    "Library", ".Trash", ".DS_Store",
]

func isPathInHiddenDirectory(_ path: String) -> Bool {
    let components = path.components(separatedBy: "/")
    for component in components {
        if component.hasPrefix("."), component != ".Trash" {
            return true
        }
        if hiddenDirectoryNames.contains(component) {
            return true
        }
    }
    return false
}
```

### Debug Commands

```bash
# Force Spotlight to re-index a directory
mdimport -r ~/Documents

# Test Spotlight search
mdfind -name "testfile"

# List indexed items for a file type
mdimport -d l /path/to/file
```

---

## 5. Perl Scripting for Timeouts

### Perl Timeout Implementation Pattern

The quality.sh uses a robust Perl-based timeout:

```perl
perl -e '
    use strict;
    use warnings;
    use POSIX qw(strftime WNOHANG);

    my $timeout = $ARGV[0];
    shift @ARGV;
    my @cmd = @ARGV;

    my $pid = fork();
    if ($pid == 0) {
        # Child: execute command
        exec(@cmd) or die "exec failed: $!";
    } elsif (defined $pid) {
        # Parent: wait with timeout
        my $start_time = time();
        my $done = 0;

        while (!$done && (time() - $start_time) < $timeout) {
            sleep 1;
            my $ret = waitpid($pid, WNOHANG);
            if ($ret == $pid) {
                $done = 1;
            }
        }

        if (!$done) {
            kill("TERM", $pid);
            sleep 1;
            kill("KILL", $pid);
            exit(124);  # Timeout
        }
    }
' "$timeout_seconds" sh -c "$test_cmd"
```

### Key Perl Features Used

- `fork()` - Create child process
- `waitpid($pid, WNOHANG)` - Non-blocking wait
- `kill()` - Signal processes
- Exit code 124 - Standard timeout code

---

## 6. Code Coverage with llvm-profdata

### Coverage Implementation

The quality.sh script uses llvm-profdata for reliable coverage measurement:

**generate_coverage_report() function (lines 11-52):**

```bash
generate_coverage_report() {
    # Find profraw files
    local profraw_files=$(find .build -name "*.profraw" 2>/dev/null || true)

    if [ -z "$profraw_files" ]; then
        # Try alternative location
        profraw_files=$(find ~/Library/Developer/Xcode/DerivedData -name "*.profraw" 2>/dev/null | grep -i zest | head -5 || true)
    fi

    # Create temp directory
    local coverage_dir=".build/coverage"
    mkdir -p "$coverage_dir"

    # Merge profraw files
    xcrun llvm-profdata merge $profraw_files -o "$merged_profdata"

    # Show coverage summary
    xcrun llvm-profdata show "$merged_profdata" -summary-only
}
```

### Running Coverage

```bash
# With run_tests.sh
./scripts/run_tests.sh 40 --coverage

# With quality.sh (automatic)
./scripts/quality.sh
```

### Coverage Gate

- **Minimum threshold:** 50%
- **Failure action:** Build fails with "COVERAGE GATE FAILED" message
- **Message:** "TDD Workflow: Write failing test FIRST, then implement"

### Troubleshooting Coverage

If coverage fails to generate:
1. Check `.build` directory for `.profraw` files
2. Verify Xcode is installed (needed for xcrun)
3. Check that tests actually ran (look for test output)

---

## 7. Additional Technical Learnings

### Static vs Instance Method Calls

**Issue:** Static methods must be called with type prefix

```swift
// WRONG
let frame = calculateTileFrame(option: .leftHalf, screenFrame: frame)

// CORRECT
let frame = WindowManager.calculateTileFrame(option: .leftHalf, screenFrame: frame)
```

Error message: "static member 'calculateTileFrame' cannot be used on instance of type 'WindowManager'"

### Thread Safety in Async Services

**Issue:** Race condition accessing shared state from multiple queues

**Solution:** Use NSLock for thread-safe access

```swift
private let processLock = NSLock()

var runningProcess: Process? {
    processLock.lock()
    defer { processLock.unlock() }
    return _runningProcess
}
```

### Test Polling for Async State

**Issue:** Tests assuming immediate state consistency

**Solution:** Use Thread.sleep polling

```swift
// Poll for state change (instead of assuming immediate consistency)
var attempts = 0
while scriptManager.isRunning && attempts < 10 {
    Thread.sleep(forTimeInterval: 0.1)
    attempts += 1
}
XCTAssertFalse(scriptManager.isRunning)
```

### Path Resolution in Scripts

**Issue:** Script running from wrong directory

**Solution:** Always use absolute paths or proper cd

```bash
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
cd "$PROJECT_DIR"
```

---

## 8. Acceptance Criteria Templates

### Testing Acceptance Criteria Template

```markdown
| Criterion | Status |
|-----------|--------|
| Given [initial state], When [action], Then [expected result] | ✅/❌ |
```

### Verification Pattern

1. Write failing test first (RED)
2. Implement minimal code to pass (GREEN)
3. Refactor while keeping tests green
4. Verify all acceptance criteria

---

## 9. File Structure Created

```
/docs/
├── TDD_GUIDELINES.md          # Timeout and TDD rules
├── retrospections/
│   ├── OBSERVATIONS_story_001.md  # Global Command Palette
│   ├── OBSERVATIONS_story_002.md  # Fuzzy Search
│   ├── OBSERVATIONS_story_003.md  # App Launch
│   ├── OBSERVATIONS_story_004.md  # Window Tiling
│   ├── OBSERVATIONS_story_005.md  # Window Movement
│   ├── OBSERVATIONS_story_006.md  # Clipboard History
│   ├── OBSERVATIONS_story_007.md  # Script Execution
│   ├── OBSERVATIONS_story_008.md  # File Search
│   ├── OBSERVATIONS_story_A.md    # Fix Duplicates
│   ├── OBSERVATIONS_story_QA1.md  # SwiftFormat
│   └── OBSERVATIONS_story_QA2.md  # SwiftLint

/scripts/
├── run_tests.sh              # Test runner with timeout
└── quality.sh                # Full QA pipeline
```

---

## 10. Recommended Product Owner Stories

Based on these learnings, consider creating stories for:

1. **Improve TDD Enforcement** - Add test coverage requirements per module
2. **Performance Profiling** - Add search latency benchmarks
3. **Spotlight Index Health** - Add diagnostic tool for index status
4. **Coverage Reports** - Generate HTML coverage reports
5. **CI Integration** - Add GitHub Actions workflow
6. **Error Handling** - Improve error messages for timeout/lock scenarios

---

## Key Takeaways

1. **Always use 40-second timeout** - Prevents development freezes
2. **SwiftPM locks are common** - Clean before every test run
3. **mdfind needs limits** - Always limit results to prevent hangs
4. **TDD is enforced** - Coverage gate catches missing tests
5. **Perl timeout pattern is reliable** - Fork-based with polling

---

*Generated: 2026-02-14*

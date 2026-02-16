# TDD Guidelines

This document outlines the Test-Driven Development workflow and mandatory timeout rules for the Zest project.

## Mandatory Timeout Rule

**ALWAYS use a 40-second timeout** for any test execution or background task that could hang or timeout.

### Why 40 Seconds?

The 40-second timeout prevents common issues that can freeze development:

- **Infinite loops** in tests freezing the test runner
- **SwiftPM lock issues** blocking forever
- **mdfind/Spotlight queries** returning too many results or hanging
- **Deadlocks** in concurrent code
- **Resource exhaustion** from runaway processes

### Test Execution

#### Recommended: Use run_tests.sh

The project includes a test runner script that enforces timeouts:

```bash
# Run tests with 40s timeout (default)
./scripts/run_tests.sh

# Run tests with custom timeout
./scripts/run_tests.sh 60

# Run tests with coverage
./scripts/run_tests.sh 40 --coverage
```

#### Direct: Perl Alarm Pattern

For ad-hoc test execution, use the perl alarm pattern:

```bash
# Basic syntax
perl -e 'alarm 40; exec @ARGV' swift test

# With coverage
perl -e 'alarm 40; exec @ARGV' swift test --enable-code-coverage
```

### Background Tasks

Any background task that could potentially hang must use the timeout pattern:

```bash
# File search with Spotlight
perl -e 'alarm 40; exec @ARGV' mdfind "kMDItemDisplayName == '*'"

# Any long-running command
perl -e 'alarm 40; exec @ARGV' <your-command> <args>
```

## TDD Workflow

Follow the RED -> GREEN -> REFACTOR cycle for all development:

### 1. RED - Write a Failing Test

```bash
# Create a new test that describes the desired behavior
# The test should FAIL because the implementation doesn't exist yet
```

Example:
```swift
func testFuzzySearch_ranksHigherWhenMatchStartsAtBeginning() {
    let query = "ch"
    let results = fuzzySearch(query: query, items: ["Chrome", "Arc", "Chromium"])

    // This should fail - we expect Chrome to rank first
    XCTAssertEqual(results.first?.name, "Chrome")
}
```

### 2. GREEN - Make the Test Pass

Implement the minimal code needed to make the test pass:

```bash
# Build to check your implementation
swift build
```

### 3. REFACTOR - Improve Code

Once tests pass, improve the code while keeping tests green:

```bash
# Run tests to ensure refactoring didn't break anything
./scripts/run_tests.sh
```

## Quality Assurance Pipeline

Run the full quality pipeline:

```bash
./scripts/quality.sh
```

This executes:
1. **Format** - SwiftFormat (if installed)
2. **Lint** - SwiftLint
3. **Build** - swift build
4. **Test** - swift test with timeout enforcement
5. **Coverage** - xccov reports

## Timeout in CI/CD

All CI/CD pipelines must enforce timeouts:

```yaml
# Example CI configuration
- name: Run Tests
  run: ./scripts/run_tests.sh 40
  timeout-minutes: 1
```

## Spotlight (mdfind) Debug Commands

When working with Spotlight queries in tests or development, use these commands to debug indexing and search behavior:

### Common mdfind Commands

```bash
# Test Spotlight queries
mdfind -name "query"           # Find files by name
mdfind "kMDItemDisplayName == '*.txt'"  # Query by metadata

# Refresh Spotlight index (when files aren't being found)
mdimport -r <path>             # Import/reindex a specific path

# Check Spotlight status on a volume
mdutil -s /                    # Show Spotlight index status
mdutil -d /                   # Enable debugging output

# List indexed attributes for a file
mdls <path-to-file>           # Show all metadata attributes
```

### Debugging Tips

- **Files not found**: Run `mdimport -r <path>` to reindex
- **Query too slow**: Add timeout using the perl pattern: `perl -e 'alarm 40; exec @ARGV' mdfind "query"`
- **Check index status**: `mdutil -s /` shows if indexing is active

## Troubleshooting

### Tests hang indefinitely

1. Check for infinite loops in the test or implementation
2. Look for deadlocks in concurrent code
3. Verify no SwiftPM lock files are stuck

### SwiftPM lock issues

```bash
# Kill stale processes
pkill -9 -f "swift"

# Remove lock files
rm -f .build/.package-lock
rm -f Package.resolved
```

### Timeout exit codes

- Exit code `124` - Command timed out (SIGALRM)
- This indicates the 40-second limit was reached

## See Also

- [CLAUDE.md](../CLAUDE.md) - Project overview and agent workflow
- [TODO.md](../TODO.md) - User stories and feature requirements

---
last_reviewed: 2026-02-14
status: current

# Observations: File Search E2E Test with Timeout Detection

Date: 2025-02-17
Agent: reflective-coding-agent

## Problem Solved

Created an end-to-end test for the file search functionality that:
1. Tests the SearchEngine and FileSearchService integration
2. Searches for `quickstart.mdx` file using Spotlight/mdfind
3. Enforces a 20-second timeout to detect hanging/freezing issues
4. Successfully detected the existing freeze issue in the app

---

## For Future Self

### How to Prevent This Problem

The test successfully detected a hanging issue. To prevent this from being merged:

- [ ] Add this test to CI pipeline with strict timeout
- [ ] Run `./scripts/run_tests.sh 20 --filter FileSearchE2ETests` before commits
- [ ] The freeze appears to be in `FileSearchService.searchSync()` which calls `mdfind`
- [ ] Consider making file search truly async instead of blocking

### How to Find Solution Faster

- Key insight: The `run_tests.sh` script already has robust timeout handling with perl
- Search that works: `FileSearchService.searchSync` is the blocking call
- Start here: `/Users/witek/projects/copies/zest/Sources/Services/FileSearchService.swift`
- Debugging step: Run test with 20s timeout to immediately see if it hangs

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| Read FileSearchService.swift | Showed the mdfind-based implementation |
| Read run_tests.sh | Found the perl timeout pattern already implemented |
| `swift build` | Verified compilation before running tests |
| `./scripts/run_tests.sh 20` | Immediately detected the hanging issue |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| None significant | Straightforward task with clear requirements |

---

## Agent Self-Reflection

### My Approach

1. Read existing code (SearchEngine, FileSearchService, existing tests) - worked well
2. Understood the mdfind-based search implementation - key insight
3. Created comprehensive E2E test file - succeeded
4. Ran with timeout and confirmed the freeze is detected - success

### What Was Critical for Success

- **Key insight:** The `run_tests.sh` script already had robust perl-based timeout handling
- **Right tool:** Using the existing script instead of trying to implement timeout in Swift
- **Right question:** "How does the existing test runner handle timeouts?"

### What I Would Do Differently

- [ ] Could have read run_tests.sh first to understand timeout mechanism
- [ ] Test file is comprehensive but could be simpler for initial freeze detection

### TDD Compliance

- [x] Wrote test first (Red)
- [ ] Minimal implementation (Green) - N/A, this is a test for existing code
- [ ] Refactored while green - N/A

Note: This was a test for existing functionality, not new feature development. The test correctly fails (times out) due to the existing freeze issue.

---

## Code Changed

- `/Users/witek/projects/copies/zest/Tests/FileSearchE2ETests.swift` - New E2E test file

## Tests Added

- `FileSearchE2ETests.swift` - 5 test cases:
  - `test_fileSearch_findsQuickstartMdx_returnsMoreThanZeroResults` - Core E2E test
  - `test_fileSearch_resultsHaveValidMetadata` - Validates result structure
  - `test_searchEngine_includesFileResults_forFilePrefixQuery` - Tests "file:" prefix
  - `test_searchEngine_includesFileResults_inGeneralSearch` - Tests general search
  - `test_fileSearch_filtersHiddenDirectories` - Tests privacy filter

## Verification

```bash
# Build to verify compilation
swift build

# Run with 20s timeout (will timeout due to existing freeze)
./scripts/run_tests.sh 20 --filter FileSearchE2ETests

# Expected result: TIMEOUT after 20s (confirms freeze detection works)
```

## The Freeze Issue

The test correctly times out after 20 seconds, indicating that `FileSearchService.searchSync()` or the broader search pipeline has a blocking/hanging issue. This is likely related to:

1. `mdfind` command blocking indefinitely
2. Some AppKit/main thread interaction causing deadlock
3. Initialization of SearchEngine.shared triggering blocking operations

Next steps to fix:
1. Profile the app with Instruments to find exact blocking point
2. Make file search truly async
3. Add proper timeout handling inside `searchSync()`

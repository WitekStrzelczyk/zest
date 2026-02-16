# Observations: File Search NSMetadataQuery Implementation

Date: 2026-02-14
Agent: reflective-coding-agent

## Problem Solved
Rewrote FileSearchService from using mdfind command (which was slow and had issues) to use NSMetadataQuery (Spotlight API). Added exclusions for build artifacts (.git, node_modules, build, .build) and ensured performance within 100ms.

---

## For Future Self

### How to Prevent This Problem
- [ ] Always use native macOS APIs (NSMetadataQuery) instead of shell commands (mdfind) for Spotlight searches
- [ ] Set explicit timeouts for any async operations that are wrapped in sync methods
- [ ] Test performance requirements separately from functional tests

### How to Find Solution Faster
- Key insight: NSMetadataQuery is the proper API for Spotlight searches, not mdfind shell command
- Search that works: `NSMetadataQuery predicate format kMDItemDisplayName CONTAINS[c]`
- Start here: Apple's NSMetadataQuery documentation
- Debugging step: Test with actual Spotlight indexing first before writing implementation

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| Read existing FileSearchService.swift | Showed the mdfind implementation that was slow |
| Write failing tests first | Verified the exact failures (node_modules, build dirs, performance) |
| swift test --filter | Quick feedback on test failures |
| NSMetadataQuery documentation | Provided the correct API pattern |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| mdfind with Process() | Slow (~105ms), no proper API control, can't limit results |

---

## Agent Self-Reflection

### My Approach
1. Read existing FileSearchService.swift to understand current mdfind implementation
2. Updated tests to check for NSMetadataQuery requirements (build dirs, node_modules, performance)
3. Ran tests - they failed as expected (RED)
4. Implemented NSMetadataQuery solution
5. Fixed type casting error (NSMetadataItem)
6. All tests pass (GREEN)

### What Was Critical for Success
- **Key insight:** Using NSMetadataQuery with proper predicate format and timeout
- **Right tool:** NSMetadataQuery API with searchScopes and predicate
- **Right question:** "How to properly use Spotlight API from Swift?"

### What I Would Do Differently
- [ ] Test NSMetadataQuery in isolation before integrating into service
- [ ] Add more specific tests for search scope (Documents, Downloads, Desktop only)

### TDD Compliance
- [x] Wrote test first (Red) - tests for node_modules, build dirs, 100ms performance
- [x] Minimal implementation (Green) - NSMetadataQuery with filtering
- [x] Refactored while green - Fixed type casting issue
- All 13 tests pass, build succeeds

---

## Code Changed
- `/Users/witek/projects/copies/zest/Sources/Services/FileSearchService.swift` - Replaced mdfind with NSMetadataQuery, added build artifact exclusions

## Tests Added
- `/Users/witek/projects/copies/zest/Tests/FileSearchServiceTests.swift` - Added tests for:
  - `test_searchSync_uses_NSMetadataQuery_not_mdfind`
  - `test_searchSync_limits_results_to_maxResults`
  - `test_searchSync_performance_within_100ms`
  - `test_searchSync_excludes_git_directory`
  - `test_searchSync_excludes_node_modules_directory`
  - `test_searchSync_excludes_build_directories`

## Verification
```bash
swift test --filter FileSearchServiceTests
# All 13 tests passed

swift build
# Build complete successfully
```

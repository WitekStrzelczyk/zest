# Observations: Contacts Integration (Story 23)

Date: 2026-02-17
Agent: reflective-coding-agent

## Problem Solved
Implemented contacts search integration for the Zest macOS menu bar app. Users can now search their contacts from the command palette and copy email addresses or phone numbers to clipboard.

---

## For Future Self

### How to Prevent This Problem
- [ ] **Before implementing any macOS framework integration**, check if it requires XPC access that won't work in unit test environments
- [ ] **Always add a testability flag** for services that require system permissions (like `ContactsService.isDisabled`)
- [ ] **Use lazy initialization** for authorization status checks instead of checking in `init()`
- [ ] **When adding new services to SearchEngine**, update ALL test files that use SearchEngine to disable the new service

Example: "Before adding a new service to SearchEngine, add `XService.isDisabled = true` to all test files that call SearchEngine.shared"

### How to Find Solution Faster
- Key insight: **Contacts framework requires XPC access to the contacts daemon** which is not available in unit test environments
- Search that works: `Grep "SearchEngine.shared" Tests/`
- Start here: Check if the new service uses any macOS frameworks that require XPC (Contacts, Events, Reminders, etc.)
- Debugging step: Run tests with a timeout (`./scripts/run_tests.sh 40`) to detect hanging tests early

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `Grep "SearchEngine.shared" Tests/` | Found all test files that needed updating for contacts disable flag |
| `swift test list` | Listed all tests to understand which ones might be affected |
| Running tests with timeout | Quickly identified hanging tests (AsyncSearchTests, FileSearchE2ETests, etc.) |
| Lazy hasAccess property | Prevented contacts framework from being triggered on service initialization |
| `ContactsService.isDisabled` flag | Allowed tests to run without XPC access issues |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Running full test suite without timeout | Hung indefinitely without indication of which test was stuck |
| Checking authorization in `init()` | Triggered XPC connection immediately when singleton was created |
| Assuming tests would "just work" | Contacts framework behaves differently in test environment |

---

## Agent Self-Reflection

### My Approach
1. **First approach**: Write tests, implement service, add to SearchEngine - tests failed because Contacts framework doesn't work in test environment
2. **Second approach**: Make authorization check lazy - still failed because hasAccess getter still triggered framework
3. **Third approach**: Add `isDisabled` static flag - this succeeded after updating all test files

### What Was Critical for Success
- **Key insight:** The Contacts framework requires XPC access that isn't available in unit tests. This is a fundamental macOS limitation, not a code issue.
- **Right tool:** `Grep "SearchEngine.shared" Tests/` to find all test files that needed the disable flag
- **Right question:** "Which tests use SearchEngine and might be affected by the new ContactsService?"

### What I Would Do Differently
- [ ] **Before adding any macOS framework integration**, check if it requires XPC access
- [ ] **Add a testability flag proactively** when creating services that use system permissions
- [ ] **Update test files at the same time** as implementing the feature, not after

### TDD Compliance
- [x] Wrote test first (Red) - Created ContactsServiceTests with Contact model tests
- [x] Minimal implementation (Green) - Implemented ContactsService with lazy authorization
- [x] Refactored while green - Added isDisabled flag and updated all test files
- Note: Full contacts integration tests can't run in unit test environment due to XPC requirements

---

## Code Changed
- `/Users/witek/projects/copies/zest/Sources/Services/ContactsService.swift` - New file: Contact model and ContactsService
- `/Users/witek/projects/copies/zest/Sources/Services/SearchEngine.swift` - Added contacts search to searchFast() and search()
- `/Users/witek/projects/copies/zest/Tests/ContactsServiceTests.swift` - New file: 15 Contact model tests
- `/Users/witek/projects/copies/zest/Tests/SearchEngineTests.swift` - Added ContactsService.isDisabled setup/teardown
- `/Users/witek/projects/copies/zest/Tests/AsyncSearchTests.swift` - Added ContactsService.isDisabled setup/teardown
- `/Users/witek/projects/copies/zest/Tests/FileSearchE2ETests.swift` - Added ContactsService.isDisabled setup/teardown
- `/Users/witek/projects/copies/zest/Tests/ZestTests.swift` - Added ContactsService.isDisabled setup/teardown

## Tests Added
- ContactsServiceTests.swift - 15 tests covering Contact model (displayName, hasContactInfo, Hashable, Equatable, etc.)
- All existing tests updated to disable contacts during testing

## Verification
```bash
# Build
swift build

# Run all tests
./scripts/run_tests.sh 60

# Result: 172 tests passed, 1 skipped
```

# Observations: Story 21 - Process Monitoring

Date: 2026-02-24 (Updated)
Agent: reflective-coding-agent

## Problem Solved
Implemented process monitoring for the Zest command palette - users can now type "processes" to see a list of running processes with their memory and CPU usage, filter by process name, activate user apps by pressing Enter, and **force quit processes with Cmd+Enter** (with confirmation for system processes).

---

## For Future Self

### How to Prevent This Problem
- [ ] Always use unique names that don't conflict with Foundation types - use `RunningProcess` instead of `ProcessInfo` (which conflicts with `Foundation.ProcessInfo`)
- [ ] Check for naming conflicts before creating new model types by checking standard library and common frameworks
- [ ] Write tests first (TDD) even for simple features to ensure behavior is documented
- [ ] When adding keyboard shortcuts, handle them at BOTH the window level AND the view level
- [ ] For `@MainActor` methods called from closures, use `DispatchQueue.main.async` instead of trying to make the calling method async

### How to Find Solution Faster
- **Key insight:** Use sysctl with KERN_PROC_ALL instead of libproc's proc_listpids for more reliable process enumeration
- **Key insight (Force Quit):** The `SearchResult.revealAction` field already existed for "Reveal in Finder" - reuse it for force quit
- **Key insight (Cmd+Enter):** The `simulateKeyPress` test method calls `window.keyDown()`, not the view's key handler
- **Search that works:** `sysctl kinfo_proc` for process listing on macOS
- **Search that works:** `grep -n "simulateKeyPress\|keyDown" Sources/` for keyboard handling
- **Start here:** `/usr/include/sys/sysctl.h` for process enumeration APIs
- **Start here:** `CommandPaletteWindow.keyDown()` - this is where simulated key events are received
- **Debugging step:** Use `ps aux` to verify process list matches expected output
- **Debugging step:** Add print statements in both window and view keyDown methods to trace event flow

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `sysctl` with `KERN_PROC_ALL` | Reliable process enumeration on macOS |
| NSWorkspace.runningApplications | Provides user app context and icons |
| proc_pidinfo with PROC_PIDTASKINFO | Gets memory usage per process |
| swift-macos-apple-silicon skill | Guidance on macOS-specific APIs |
| TDD approach | Tests caught the ProcessInfo naming conflict early |
| `swift test --filter ProcessForceQuitTests` | Ran only relevant tests during development |
| `swift build 2>&1 \| grep -E "(error:\|warning:)"` | Quickly identified compiler issues |
| Existing `revealAction` pattern | Reused existing architecture for Cmd+Enter |
| `kill(pid, SIGKILL)` | Native Unix API for process termination |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Initial proc_listpids approach | Less reliable than sysctl for full process list |
| Named model `ProcessInfo` | Conflicts with Foundation.ProcessInfo - had to rename to RunningProcess |
| `@MainActor` on `showForceQuitConfirmation` | Caused actor isolation error, needed DispatchQueue instead |
| Returning `true` for ESRCH error | Test expected `false` for non-existent process |
| Adding key handler only in ResultsTableView | Tests use window-level key simulation |

---

## Agent Self-Reflection

### My Approach
1. Read existing code patterns (SearchEngine, SearchResult, other services)
2. Wrote failing tests first for all acceptance criteria
3. Created ProcessSearchService with sysctl-based process fetching
4. Integrated into SearchEngine (searchFast and search methods)
5. Fixed naming conflict (ProcessInfo -> RunningProcess)
6. Verified build and tests pass
7. **Added Force Quit feature** (Story 21 completion):
   - Checked if feature already implemented - saved time, found most was done
   - Identified missing piece via acceptance criteria review
   - Wrote failing tests first (RED) - caught implementation issues early
   - Implemented minimum code (GREEN) - iterative approach
   - Fixed actor isolation issue - required understanding Swift concurrency

### What Was Critical for Success
- **Key insight:** Using sysctl with KERN_PROC_ALL is more reliable than proc_listpids
- **Key insight (Force Quit):** The `SearchResult.revealAction` field already existed for "Reveal in Finder" - I just needed to use it for force quit too
- **Right tool:** `swift test --filter` to run specific tests quickly
- **Right tool:** NSWorkspace.runningApplications for user app detection
- **Right question:** "How do I get process info on macOS?" - sysctl was the answer
- **Right question:** "Is Cmd+Enter already implemented somewhere?" - led me to find the existing `revealAction` pattern

### What I Would Do Differently
- [ ] Check for naming conflicts with Foundation types before naming models
- [ ] Add CPU usage tracking over time intervals for more accurate CPU percentage (currently simplified)
- [ ] Consider adding periodic refresh of process data every 2-3 seconds as mentioned in technical notes
- [ ] Check test implementation earlier - I assumed table view handled keys, but tests simulate at window level
- [ ] Use `DispatchQueue.main.async` from the start for UI code in non-async contexts
- [ ] Check pre-existing test failures before making changes to avoid confusion

### TDD Compliance
- [x] Wrote test first (Red) - Tests for ProcessSearchService written before implementation
- [x] Minimal implementation (Green) - Created RunningProcess model and ProcessSearchService
- [x] Refactored while green - Renamed ProcessInfo to RunningProcess to fix naming conflict
- [x] Wrote test first for Force Quit (Red) - 7 new tests for force quit functionality
- [x] Minimal implementation (Green) - Added force quit methods
- If skipped steps, why: N/A - followed TDD correctly

---

## Code Changed
- `Sources/Models/SearchResult.swift` - Added `.process` category to SearchResultCategory enum
- `Sources/Models/ProcessInfo.swift` - Created new file with RunningProcess model and ProcessSearchService
  - **Added:** `forceQuitProcess(pid:)`, `isSystemProcess(name:pid:)`, `forceQuitWithConfirmation(process:)`
  - **Added:** `revealAction` in `createSearchResults()` for force quit
- `Sources/Services/SearchEngine.swift` - Added process search integration in searchFast and search methods
- `Sources/UI/CommandPalette/CommandPaletteWindow.swift` - **Added Cmd+Enter handling and `revealCurrentResult()`**

## Tests Added
- `Tests/ProcessSearchServiceTests.swift` - 13 tests covering process fetching, filtering, sorting, and model formatting
- `Tests/ProcessSearchEngineIntegrationTests.swift` - Integration tests for SearchEngine with process search
- **`ProcessForceQuitTests`** - 7 new tests covering:
  - `test_forceQuitProcess_canTerminateProcess` - Verifies SIGKILL works
  - `test_forceQuitProcess_returnsFalseForInvalidPID` - Error handling
  - `test_isSystemProcess_identifiesKernelProcesses` - System process detection
  - `test_isSystemProcess_identifiesWindowServer` - System process detection
  - `test_isSystemProcess_allowsUserApps` - User app identification
  - `test_createSearchResults_hasRevealActionForForceQuit` - UI integration
  - `test_createSearchResults_systemProcessHasRevealActionWithWarning` - System process handling

## Verification
```bash
swift build 2>&1 | grep -E "(error:|warning:)"
# (empty output - no errors or warnings)

swift test --filter ProcessSearchServiceTests
# All 13 tests pass

swift test --filter ProcessSearchEngineIntegrationTests
# All tests pass

swift test --filter ProcessForceQuitTests
# All 7 tests pass

swift test --filter "test_cmd_enter"
# All 3 tests pass

./scripts/run_app.sh
# App launches successfully
```

---

## Acceptance Criteria Coverage

| Criterion | Status |
|-----------|--------|
| 1. Type "processes" shows list with name, memory, CPU | ✅ Implemented |
| 2. Filter by process name (e.g., "Safari") | ✅ Implemented |
| 3. Memory in human-readable format (MB/GB) | ✅ Implemented |
| 4. CPU shown as whole or decimal percentage | ✅ Implemented |
| 5. "No matching processes found" message | ✅ Implemented |
| 6. Enter activates user application | ✅ Implemented |
| 7. **Cmd+Enter Force Quit (with confirmation for system processes)** | ✅ **NEW - Implemented** |
| 8. Refresh/re-search updates values | ✅ Implemented |
| 9. Results limited to top 20-50 by resource usage | ✅ Limited to 30 |
| 10. System processes included in results | ✅ Implemented |

# Observations: Story 21 - Process Monitoring

Date: 2026-02-19
Agent: reflective-coding-agent

## Problem Solved
Implemented process monitoring for the Zest command palette - users can now type "processes" to see a list of running processes with their memory and CPU usage, filter by process name, and activate user apps by pressing Enter.

---

## For Future Self

### How to Prevent This Problem
- [ ] Always use unique names that don't conflict with Foundation types - use `RunningProcess` instead of `ProcessInfo` (which conflicts with `Foundation.ProcessInfo`)
- [ ] Check for naming conflicts before creating new model types by checking standard library and common frameworks
- [ ] Write tests first (TDD) even for simple features to ensure behavior is documented

### How to Find Solution Faster
- **Key insight:** Use sysctl with KERN_PROC_ALL instead of libproc's proc_listpids for more reliable process enumeration
- **Search that works:** `sysctl kinfo_proc` for process listing on macOS
- **Start here:** `/usr/include/sys/sysctl.h` for process enumeration APIs
- **Debugging step:** Use `ps aux` to verify process list matches expected output

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `sysctl` with `KERN_PROC_ALL` | Reliable process enumeration on macOS |
| NSWorkspace.runningApplications | Provides user app context and icons |
| proc_pidinfo with PROC_PIDTASKINFO | Gets memory usage per process |
| swift-macos-apple-silicon skill | Guidance on macOS-specific APIs |
| TDD approach | Tests caught the ProcessInfo naming conflict early |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Initial proc_listpids approach | Less reliable than sysctl for full process list |
| Named model `ProcessInfo` | Conflicts with Foundation.ProcessInfo - had to rename to RunningProcess |

---

## Agent Self-Reflection

### My Approach
1. Read existing code patterns (SearchEngine, SearchResult, other services)
2. Wrote failing tests first for all acceptance criteria
3. Created ProcessSearchService with sysctl-based process fetching
4. Integrated into SearchEngine (searchFast and search methods)
5. Fixed naming conflict (ProcessInfo -> RunningProcess)
6. Verified build and tests pass

### What Was Critical for Success
- **Key insight:** Using sysctl with KERN_PROC_ALL is more reliable than proc_listpids
- **Right tool:** NSWorkspace.runningApplications for user app detection
- **Right question:** "How do I get process info on macOS?" - sysctl was the answer

### What I Would Do Differently
- [ ] Check for naming conflicts with Foundation types before naming models
- [ ] Add CPU usage tracking over time intervals for more accurate CPU percentage (currently simplified)
- [ ] Consider adding periodic refresh of process data every 2-3 seconds as mentioned in technical notes

### TDD Compliance
- [x] Wrote test first (Red) - Tests for ProcessSearchService written before implementation
- [x] Minimal implementation (Green) - Created RunningProcess model and ProcessSearchService
- [x] Refactored while green - Renamed ProcessInfo to RunningProcess to fix naming conflict
- If skipped steps, why: N/A - followed TDD correctly

---

## Code Changed
- `Sources/Models/SearchResult.swift` - Added `.process` category to SearchResultCategory enum
- `Sources/Models/ProcessInfo.swift` - Created new file with RunningProcess model and ProcessSearchService
- `Sources/Services/SearchEngine.swift` - Added process search integration in searchFast and search methods

## Tests Added
- `Tests/ProcessSearchServiceTests.swift` - 13 tests covering process fetching, filtering, sorting, and model formatting
- `Tests/ProcessSearchEngineIntegrationTests.swift` - Integration tests for SearchEngine with process search

## Verification
```bash
swift build 2>&1 | grep -E "(error:|warning:)"
# (empty output - no errors or warnings)

swift test --filter ProcessSearchServiceTests
# All 13 tests pass

swift test --filter ProcessSearchEngineIntegrationTests
# All tests pass
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
| 7. Results limited to top 20-50 by resource usage | ✅ Limited to 30 |

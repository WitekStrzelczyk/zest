# Observations: Story 22 - Two-Phase Process Force Quit

Date: 2026-02-28
Agent: reflective-coding-agent

## Problem Solved
Implemented a two-phase kill system for process termination: Phase 1 sends SIGTERM (polite quit), Phase 2 sends SIGKILL (force quit). The system includes visual feedback via red border on processes where SIGTERM has been sent, and state persistence across process list refreshes.

---

## For Future Self

### How to Prevent This Problem
- [x] Use `ProcessKillState.shared` singleton to track kill attempts by PID (not UUID, since UUIDs are regenerated on each process list fetch)
- [x] State tracking must check `ProcessKillState` directly in `createSearchResults` rather than relying on `RunningProcess.attemptedKill` property
- [x] Use thread-safe `NSLock` when accessing shared state dictionary

Example: "Before implementing process state tracking, always identify the stable identifier (PID, not UUID) and use a singleton for persistence"

### How to Find Solution Faster
- Key insight: Process UUID is regenerated on each `fetchRunningProcesses()` call, so we must track by PID
- Search that works: `ProcessKillState.shared`
- Start here: `Sources/Models/ProcessInfo.swift` - contains all kill logic and state tracking
- Debugging step: Use `kill(pid, 0)` to check if process still exists after sending signals

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `Read ProcessInfo.swift` | Showed existing force quit implementation to extend |
| `Read CommandPaletteWindow.swift` | Showed existing danger mode UI to extend |
| `swift test --filter TwoPhaseKill` | Rapid iteration on test cases |
| TDD RED-GREEN cycle | Ensured all test cases were covered before implementation |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Initial assumption that `RunningProcess.attemptedKill` would be sufficient | State needed to be checked in `createSearchResults` for consistency with test-created processes |
| LSP errors during editing | Caused by missing types - resolved by building to verify |

---

## Agent Self-Reflection

### My Approach
1. **RED**: Wrote 14 failing tests covering KillResult enum, ProcessKillState, attemptKill method, and UI integration - **worked correctly**
2. **GREEN**: Implemented KillResult, ProcessKillState singleton, attemptKill method with SIGTERM/SIGKILL logic - **worked**
3. Fixed test failure in `test_createSearchResults_includesKillState` by checking ProcessKillState directly - **resolved**

### What Was Critical for Success
- **Key insight:** Process list is refreshed every 2-3 seconds, so state must persist in a singleton keyed by PID
- **Right tool:** `ProcessKillState` singleton with `NSLock` for thread safety
- **Right question:** "How do I persist kill state across process list refreshes?"

### What I Would Do Differently
- [x] Check `ProcessKillState` directly in `createSearchResults` from the start (avoid relying on `RunningProcess.attemptedKill`)
- [ ] Consider adding timeout for SIGTERM to auto-escalate to SIGKILL (future enhancement)

### TDD Compliance
- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [x] Refactored while green
- All 14 tests pass

---

## Code Changed
- `Sources/Models/ProcessInfo.swift` - Added `KillResult` enum, `ProcessKillState` singleton, `attemptKill()` method, `twoPhaseKillWithConfirmation()`, `isKillAttempted` in `createSearchResults`
- `Sources/Models/SearchResult.swift` - Added `isKillAttempted` property
- `Sources/UI/CommandPalette/CommandPaletteWindow.swift` - Added `isKillAttempted` to `ResultRowView`, updated `rowViewForRow` to set kill state

## Tests Added
- `Tests/TwoPhaseKillTests.swift` - 14 tests covering:
  - `test_killResult_hasExpectedCases`
  - `test_processKillState_tracksKillAttemptsByPID`
  - `test_processKillState_persistsAcrossInstances`
  - `test_processKillState_clearAllResetsAll`
  - `test_attemptKill_sendsSIGTERMOnFirstCall`
  - `test_attemptKill_sendsSIGKILLOnSecondCall`
  - `test_attemptKill_returnsFailedForInvalidPID`
  - `test_runningProcess_hasAttemptedKillProperty`
  - `test_runningProcess_attemptedKillDefaultsToFalse`
  - `test_searchResult_hasIsKillAttemptedProperty`
  - `test_searchResult_isKillAttemptedDefaultsToFalse`
  - `test_createSearchResults_includesKillState`
  - `test_attemptKillWithConfirmation_systemProcessStillShowsWarning`
  - `test_attemptKillWithConfirmation_userAppSkipsWarning`

## Verification
```bash
# Build with zero warnings
swift build 2>&1 | grep -E "(error:|warning:)" || echo "Build succeeded"

# Run TwoPhaseKill tests
swift test --filter TwoPhaseKill

# Run full quality pipeline
./scripts/quality.sh
```

---

## Implementation Details

### Data Model
```swift
enum KillResult: Equatable {
    case sigtermSent    // Phase 1: polite quit
    case sigkillSent    // Phase 2: force quit
    case success        // Process terminated
    case failed(Error)  // Kill failed
}

final class ProcessKillState {
    static let shared = ProcessKillState()
    func hasAttemptedKill(pid: pid_t) -> Bool
    func markKillAttempted(pid: pid_t)
    func clearKillAttempt(pid: pid_t)
    func clearAll()
}

struct RunningProcess {
    let attemptedKill: Bool  // Set from ProcessKillState during fetch
}

struct SearchResult {
    let isKillAttempted: Bool  // Set from ProcessKillState during conversion
}
```

### Kill Logic
```swift
static func attemptKill(pid: pid_t) -> KillResult {
    if ProcessKillState.shared.hasAttemptedKill(pid: pid) {
        // Phase 2: Force kill
        kill(pid, SIGKILL)
        return .sigkillSent
    } else {
        // Phase 1: Polite quit
        kill(pid, SIGTERM)
        ProcessKillState.shared.markKillAttempted(pid: pid)
        return .sigtermSent
    }
}
```

### Visual Feedback
- `ResultRowView.isKillAttempted` shows red border when SIGTERM has been sent
- Border is slightly thinner/lighter than danger mode to differentiate states
- State persists across process list refreshes (2-3 second interval)

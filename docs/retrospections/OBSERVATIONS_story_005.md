# Observations: Window Movement and Resize (Story 5)

Date: 2026-02-14
Agent: reflective-coding-agent

## Problem Solved
Implemented window movement and resize functionality including: move to center, maximize to fill visible area, move to screen (recover off-screen windows), and resize to specific dimensions using macOS Accessibility API.

---

## For Future Self

### How to Prevent This Problem
- [ ] Always check existing services before creating new ones - WindowManager already had the AXUIElement infrastructure needed
- [ ] Write tests for calculation logic separately from integration tests - static methods are easier to unit test
- [ ] Use tolerance for off-screen detection to handle minor positioning issues

### How to Find Solution Faster
- Key insight: Maximize uses visibleFrame (not full screen frame) to avoid covering menu bar/dock
- Search that works: `grep -n "visibleFrame" WindowManager.swift`
- Start here: Read existing tileFocusedWindow implementation for patterns
- Debugging step: Test frame calculations with unit tests first before testing with real windows

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| Read WindowManager.swift | Found existing AXUIElement infrastructure to reuse |
| Write unit tests for static methods | Fast test feedback without needing accessibility permissions |
| Follow existing patterns | Used same structure as tileFocusedWindow for new methods |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| N/A | This feature built directly on Story 4's foundation - no wasted detours |

---

## Agent Self-Reflection

### My Approach
1. Read existing WindowManager to understand infrastructure
2. Wrote failing tests first (WindowMovementTests.swift)
3. Implemented static calculation methods (testable)
4. Implemented action methods that use AXUIElement
5. Ran swift test to verify all pass

### What Was Critical for Success
- **Key insight:** Reuse existing WindowManager infrastructure from Story 4
- **Right tool:** Static methods for frame calculations enable pure unit testing
- **Right question:** "How does maximize differ from tile maximize?" - Answer: uses visibleFrame

### What I Would Do Differently
- [ ] Could have added more edge case tests for multi-monitor scenarios
- [ ] Could have tested with real windows earlier in development cycle

### TDD Compliance
- [x] Wrote test first (Red) - Tests in WindowMovementTests.swift
- [x] Minimal implementation (Green) - Added required methods to WindowManager
- [x] Refactored while green - Added MovementOption enum for consistency
- All acceptance criteria covered with passing tests

---

## Code Changed
- Sources/Services/WindowManager.swift - Added MovementOption enum, static calculation methods, and action methods
- Tests/WindowMovementTests.swift - New test file for Story 5 functionality
- Tests/WindowManagerTests.swift - Minor warning cleanup (unused variables)

## Tests Added
- WindowMovementTests.swift - 10 tests covering:
  - move to center calculation
  - maximize frame calculation
  - off-screen detection
  - resize calculations
  - recovery position calculation
- OffScreenRecoveryTests.swift - 2 tests covering off-screen recovery

## Verification
```bash
swift build  # Builds successfully
swift test   # All 29 tests pass
```

# Observations: Window Tiling Feature (Story 4)

Date: 2026-02-14
Agent: reflective-coding-agent

## Problem Solved
Implemented window tiling functionality for the Zest macOS command palette using macOS Accessibility API (AXUIElement). Users can now tile windows to the left half, right half, or maximize them using the command palette.

---

## For Future Self

### How to Prevent This Problem
- [ ] Always check for static method vs instance method usage when calling methods within the same type
- [ ] Use `WindowManager.methodName` explicitly when calling static methods from instance methods to avoid confusion
- [ ] Run `swift build` before `swift test` to catch compilation errors early

### How to Find Solution Faster
- **Key insight:** The static method `calculateTileFrame` needed to be called as `WindowManager.calculateTileFrame` instead of just `calculateTileFrame`
- **Search that works:** `static func calculateTileFrame`
- **Start here:** `/Users/witek/projects/copies/zest/Sources/Services/WindowManager.swift`
- **Debugging step:** Build output clearly showed the error: "static member 'calculateTileFrame' cannot be used on instance of type 'WindowManager'"

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `swift build` | Caught the static method error immediately |
| Read existing services (ClipboardManager) | Understood the singleton pattern used in this project |
| Read Package.swift | Understood the test target location (Tests/ directory) |
| Grep for "static" | Found other examples of static methods in the codebase |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Searching for AXUIElement examples | macOS accessibility API documentation is extensive; focused on specific use case instead |

---

## Agent Self-Reflection

### My Approach
1. **Explored project structure** - Found existing services, models, and test patterns
2. **Created failing tests first** - Wrote tests in `/Users/witek/projects/copies/zest/Tests/WindowManagerTests.swift` that referenced `WindowManager` which didn't exist yet
3. **Implemented WindowManager** - Created the service with tiling options, frame calculation, and Accessibility API integration
4. **Fixed compilation error** - Changed `calculateTileFrame` to `WindowManager.calculateTileFrame`
5. **Verified** - Both `swift build` and `swift test` passed

### What Was Critical for Success
- **Key insight:** Understanding the project structure (singleton pattern for services, test location in Tests/)
- **Right tool:** `swift build` provided immediate feedback on compilation errors
- **Right question:** "How are other services in this project structured?"

### What I Would Do Differently
- [ ] Check if there were existing patterns for static methods in the codebase before implementing
- [ ] Run build before running tests to catch simple errors faster

### TDD Compliance
- [x] Wrote test first (Red) - Tests referenced non-existent WindowManager type
- [x] Minimal implementation (Green) - Implemented only what's needed for tests to pass
- [x] Refactored while green - Fixed static method call issue
- If skipped steps, why: N/A - followed TDD correctly

---

## Code Changed
- `/Users/witek/projects/copies/zest/Sources/Services/Window - Created new service with:
  - `TManager.swift`ilingOption` enum (leftHalf, rightHalf, maximize)
  - `calculateTileFrame()` static method for frame calculations
  - `tileFocusedWindow()` method using Accessibility API
  - `canTileFocusedWindow()` for full-screen detection
  - Helper methods for AXUIElement operations
- `/Users/witek/projects/copies/zest/Tests/WindowManagerTests.swift` - Created test file with:
  - Frame calculation tests
  - Tiling option tests
  - Full-screen detection tests
  - Multi-display support tests

## Tests Added
- `test_leftHalfFrame_calculation` - Verifies correct left half frame calculation
- `test_rightHalfFrame_calculation` - Verifies correct right half frame calculation
- `test_maximizeFrame_calculation` - Verifies maximize fills the screen
- `test_menuBarOffset_isConsidered` - Verifies visible frame is used
- `test_tileOptions_includesLeftRightAndMaximize` - Verifies all options available
- `test_tileActionIsAvailable_returnsFalseForFullScreen` - Full-screen windows cannot be tiled
- And more integration tests

## Verification
```bash
swift build    # Compiles without errors
swift test     # All 17 tests pass
```

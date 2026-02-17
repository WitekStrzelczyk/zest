# Observations: Keyboard Focus and First Responder Fix

Date: 2026-02-17
Agent: reflective-coding-agent

## Problem Solved
Fixed keyboard navigation to properly manage first responder state between search field and results table. The previous implementation only changed visual selection in the table without actually transferring keyboard focus (first responder).

---

## For Future Self

### How to Prevent This Problem
- [ ] When implementing keyboard navigation in macOS, always distinguish between **selection** (visual highlight) and **first responder** (which view receives keyboard events)
- [ ] Use explicit state tracking (`isResultsFocused`) when AppKit's first responder chain doesn't work as expected (e.g., in non-activating panels)
- [ ] Test first responder state explicitly, not just selection state
- [ ] Remember: `makeFirstResponder()` only works when the window is key - in tests, the window may not become key

### How to Find Solution Faster
- Key insight: `selectRowIndexes()` only changes visual selection, not first responder. Need to track focus state separately.
- Search that works: `firstResponder` or `makeFirstResponder`
- Start here: `CommandPaletteWindow.swift` - `keyDown()` method
- Debugging step: Check if `window.firstResponder === view` vs `window.isKeyWindow`

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| Writing failing tests first (TDD) | Revealed that first responder was never being set properly |
| `isResultsFocused` boolean flag | Tracked focus state independently of AppKit's first responder chain |
| Understanding NSPanel behavior | `.nonactivatingPanel` windows don't become key normally, affecting first responder |
| `orderOut(nil)` vs `close()` | Properly hides window without activating previous app |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Relying on `firstResponder === searchField` | Always false in tests because window isn't key |
| Assuming selection = focus | Selection is just visual; focus determines where keys go |
| `super.close()` for NSPanel | Doesn't properly clean up keyboard event capture |

---

## Agent Self-Reflection

### My Approach
1. First tried using `makeFirstResponder()` directly - didn't work in tests
2. Then tried checking `firstResponder === searchField` - always false in tests
3. Finally added explicit `isResultsFocused` state tracking - this succeeded

### What Was Critical for Success
- **Key insight:** In NSPanel with `.nonactivatingPanel`, `makeFirstResponder()` doesn't work as expected when window isn't key. Need to track focus state manually.
- **Right tool:** Explicit boolean state (`isResultsFocused`) to track logical focus independent of AppKit's first responder chain
- **Right question:** "Why doesn't the search field become first responder after calling makeFirstResponder()?"

### What I Would Do Differently
- [ ] Earlier understanding of how `.nonactivatingPanel` affects first responder behavior
- [ ] Ask about the window configuration (NSPanel style masks) at the start
- [ ] Read AppKit documentation on first responder chain before implementing

### TDD Compliance
- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [x] Refactored while green
- Updated existing tests to match new expected behavior (focus state vs selection state)

---

## Code Changed
- `/Users/witek/projects/copies/zest/Sources/UI/CommandPalette/CommandPaletteWindow.swift`
  - Added `isResultsFocused` boolean to track focus state
  - Updated `keyDown()` to check `isResultsFocused` before deciding navigation behavior
  - Updated `close()` to use `orderOut(nil)` and `makeFirstResponder(nil)` for proper cleanup
  - Updated `show()` to reset `isResultsFocused = false`
  - Updated test helpers to use `isResultsFocused` for first responder checks

## Tests Added
- `KeyboardNavigationTests.swift`
  - `test_down_arrow_moves_first_responder_to_results` - verifies Down moves focus to results
  - `test_up_arrow_from_first_result_moves_first_responder_to_search` - verifies Up from first result returns to search
  - `test_up_arrow_from_second_result_moves_selection_not_first_responder` - verifies navigation within results
  - `test_escape_stops_keyboard_interception` - verifies window stops capturing events after ESC

## Verification
```bash
swift test --filter KeyboardNavigationTests
# All 22 tests pass

swift build
# Build succeeds

swift test
# All 136 tests pass
```

---

## Key Implementation Details

### The `isResultsFocused` Pattern
```swift
// Track focus state separately from AppKit's first responder
private var isResultsFocused: Bool = false

// In keyDown, check this flag to determine behavior
case 125: // Down arrow
    if !isResultsFocused {
        // First time pressing Down from search - move focus to results
        isResultsFocused = true
        makeFirstResponder(resultsTableView)
    } else {
        // Already on results - navigate to next row
    }
```

### Proper Window Close for Non-Activating Panels
```swift
override func close() {
    makeFirstResponder(nil)  // Clear first responder
    resignKey()              // Resign key window status
    orderOut(nil)            // Hide without activating previous app
    previousApp?.activate(options: .activateIgnoringOtherApps)
    previousApp = nil
}
```

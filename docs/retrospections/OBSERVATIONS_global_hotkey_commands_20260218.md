# Observations: Global Hotkey Commands Implementation

Date: 2026-02-18
Agent: reflective-coding-agent

## Problem Solved

Implemented a reusable global hotkey system using Carbon API that allows registering multiple global keyboard shortcuts. Added two global commands: `Option+Cmd+M` opens Spotify, and `Option+Cmd+Up` maximizes the current window.

---

## For Future Self

### How to Prevent This Problem

- [ ] Always verify Carbon modifier values before hardcoding them in tests - `cmdKey` = 256, `optionKey` = 2048 (not 512!)
- [ ] When adding new services, import Carbon in both source and test files for key code constants
- [ ] Create shared constants file for modifier values if used across multiple files

Example: "Before testing Carbon API constants, check actual values in Events.h or print them at runtime"

### How to Find Solution Faster

- Key insight: The existing `AppDelegate.swift` already had Carbon hotkey pattern that could be abstracted into `GlobalHotkeyManager`
- Search that works: `Grep "RegisterEventHotKey"` - finds all Carbon hotkey registrations
- Start here: `Sources/App/AppDelegate.swift` - existing hotkey implementation to extend
- Debugging step: Run `./scripts/run_tests.sh 90 | grep -E "GlobalHotkey|GlobalCommands"` to filter test output

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `Read AppDelegate.swift` | Showed existing Carbon hotkey pattern to extend |
| `Read WindowManager.swift` | Confirmed `maximizeFocusedWindow()` already existed |
| `swift build` | Quick compilation check after each change |
| `./scripts/run_tests.sh 90` | Test runner with timeout protection |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Wrong modifier values in task | `optionKey = 512` was incorrect (actual is 2048), caused test failure |
| Not importing Carbon in tests | Led to "cannot find 'cmdKey' in scope" errors |

---

## Agent Self-Reflection

### My Approach

1. Read existing codebase (AppDelegate, WindowManager) - worked well, found patterns to extend
2. Created failing tests first (RED phase) - worked, caught scope errors
3. Implemented services (GlobalHotkeyManager, GlobalCommandsService) - worked
4. Updated AppDelegate to use new services - worked
5. Ran full test suite - all 240 tests pass

### What Was Critical for Success

- **Key insight:** The existing AppDelegate already had a working Carbon hotkey pattern - just needed to extract and generalize it
- **Right tool:** WindowManager already had `maximizeFocusedWindow()` - no need to implement window manipulation
- **Right question:** "What already exists that I can reuse?"

### What I Would Do Differently

- [ ] Verify Carbon constant values at start (print `optionKey`, `cmdKey` values)
- [ ] Add imports (Carbon) to test files from the start

### TDD Compliance

- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [x] Refactored while green
- Tests added: `GlobalHotkeyManagerTests.swift`, `GlobalCommandsServiceTests.swift`

---

## Code Changed

- `Sources/Services/GlobalHotkeyManager.swift` - NEW: Reusable Carbon hotkey manager
- `Sources/Services/GlobalCommandsService.swift` - NEW: Defines global commands (openSpotify, maximizeWindow)
- `Sources/App/AppDelegate.swift` - MODIFIED: Added `setupGlobalCommandHotkeys()` to register commands
- `Tests/GlobalHotkeyManagerTests.swift` - NEW: Tests for hotkey registration and triggering
- `Tests/GlobalCommandsServiceTests.swift` - NEW: Tests for command definitions

## Tests Added

- `GlobalHotkeyManagerTests.swift`:
  - `test_registerHotkey_returnsIdentifier`
  - `test_registerMultipleHotkeys_returnsDifferentIdentifiers`
  - `test_unregisterHotkey_removesHotkey`
  - `test_unregisterAll_removesAllHotkeys`
  - `test_modifierConstants_areCorrect`
  - `test_hotkeyAction_isCalledWhenTriggered`
  - `test_triggerAction_forInvalidIdentifier_doesNothing`

- `GlobalCommandsServiceTests.swift`:
  - `test_openSpotify_returnsTrue`
  - `test_maximizeWindow_usesWindowManager`
  - `test_commands_returnsListOfAvailableCommands`
  - `test_commands_includesOpenSpotify`
  - `test_commands_includesMaximizeWindow`
  - `test_globalCommand_hasCorrectProperties`

## Verification

```bash
# Build and verify
swift build

# Run tests with timeout
./scripts/run_tests.sh 90

# Run app to test manually
./scripts/run_app.sh
```

## Carbon API Reference

```swift
// Key codes (from Carbon HIToolbox/Events.h)
kVK_Space = 49
kVK_ANSI_M = 46
kVK_UpArrow = 126

// Modifier flags
cmdKey = 256      // 1 << 8
optionKey = 2048  // 1 << 11 (NOT 512!)
shiftKey = 512    // 1 << 9
controlKey = 128  // 1 << 7
```

## Hotkey Combinations Registered

| Hotkey | Key Code | Modifiers | Action |
|--------|----------|-----------|--------|
| `Cmd+Space` | 49 | 256 | Toggle Command Palette |
| `Option+Cmd+M` | 46 | 2304 (256 \| 2048) | Open Spotify |
| `Option+Cmd+Up` | 126 | 2304 (256 \| 2048) | Maximize Window |

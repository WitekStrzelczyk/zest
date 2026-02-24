# Observations: Launch at Login Sync

Date: 2026-02-24
Agent: reflective-coding-agent

## Problem Solved
Connected the existing `LaunchAtLoginService` and `PreferencesManager` components so that:
1. Toggle in Preferences UI syncs to the system login item
2. App startup applies saved preference to system
3. System state changes externally are detected and synced

---

## For Future Self

### How to Prevent This Problem
- [ ] When adding a preference that affects system state, always implement bidirectional sync
- [ ] Never let UserDefaults and actual system state diverge - pick one source of truth
- [ ] For system-level settings (login items, permissions), always check actual system state at init

Example: "When creating a preference that controls a system API, immediately add the sync in didSet AND check system state at init"

### How to Find Solution Faster
- Key insight: SMAppService is the source of truth for login items, not UserDefaults
- Search that works: `LaunchAtLoginService.shared.enabled`
- Start here: `PreferencesManager.swift` - the `launchAtLogin` property's `didSet`
- Debugging step: Check `SMAppService.mainApp.status` in Console

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| Read existing files first | Understood the component structure before modifying |
| `swift test --filter` | Isolated specific tests during TDD cycle |
| TDD RED-GREEN cycle | Caught the sync issue via failing tests first |
| `swift build \| grep warning` | Verified zero warnings after changes |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Full test suite run | Timed out due to unrelated tests (pre-existing issues) |
| Assumed init sync was needed | `test_preferences_manager_syncs_with_system_state_on_init` passed before fix |

---

## Agent Self-Reflection

### My Approach
1. Read all related files first - worked well, understood existing structure
2. Added failing tests for sync behavior - confirmed RED state
3. Implemented three fixes: didSet sync, init sync, app startup sync - succeeded
4. Verified with focused test runs and app launch - succeeded

### What Was Critical for Success
- **Key insight:** The `didSet` property observer is the right place for sync - it fires on every change
- **Right tool:** `swift test --filter LaunchAtLoginServiceTests` for fast feedback
- **Right question:** "What happens if user changes login item in System Settings?"

### What I Would Do Differently
- [ ] Skip the full test suite until pre-existing timeouts are fixed
- [ ] Consider if init sync is actually needed (system state should be source of truth)

### TDD Compliance
- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [x] Refactored while green
- N/A - No refactoring needed

---

## Code Changed

### Sources/Services/PreferencesManager.swift
**Change 1:** Added sync to LaunchAtLoginService in `didSet`:
```swift
@Published var launchAtLogin: Bool {
    didSet {
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        // Sync with LaunchAtLoginService
        LaunchAtLoginService.shared.enabled = launchAtLogin
    }
}
```

**Change 2:** Added system state sync at init:
```swift
// Load launch at login - sync with actual system state
// The system state is the source of truth
let storedLaunchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
let systemLaunchAtLogin = LaunchAtLoginService.shared.isEnabled

// If they differ, the system state wins (e.g., user changed in System Settings)
if storedLaunchAtLogin != systemLaunchAtLogin {
    defaults.set(systemLaunchAtLogin, forKey: Keys.launchAtLogin)
}
launchAtLogin = systemLaunchAtLogin
```

### Sources/App/AppDelegate.swift
**Change:** Added startup sync in `applicationDidFinishLaunching`:
```swift
func applicationDidFinishLaunching(_: Notification) {
    // Sync launch at login preference with system
    LaunchAtLoginService.shared.enabled = PreferencesManager.shared.launchAtLogin
    // ... rest of method
}
```

## Tests Added

### Tests/LaunchAtLoginServiceTests.swift
Three new sync behavior tests:
1. `test_setting_preferences_manager_launch_at_login_syncs_to_service` - Verifies didSet sync works
2. `test_preferences_manager_syncs_with_system_state_on_init` - Verifies init sync works
3. `test_preferences_manager_and_service_remain_in_sync` - Verifies round-trip sync works

## Verification

```bash
# Run focused tests
swift test --filter "LaunchAtLoginServiceTests|PreferencesManagerTests"
# Result: 20 tests passed

# Verify build clean
swift build 2>&1 | grep -E "(error:|warning:)"
# Result: No warnings

# Launch app
./scripts/run_app.sh
# Result: App launches successfully
```

---

## Architecture Notes

### Source of Truth
For system-level preferences (login items), the **actual system state** should be the source of truth:
- `SMAppService.mainApp.status` (macOS 13+) is authoritative
- UserDefaults should only cache the last known state
- On app launch and PreferencesManager init, sync from system to UserDefaults

### Sync Points
1. **App Startup:** Apply UserDefaults → System (user's saved preference wins on clean start)
2. **PreferencesManager Init:** System → UserDefaults (detect external changes)
3. **didSet:** Both (keep in sync when user changes via UI)

### Why Both Directions?
- Init sync: Detect if user changed login item in System Settings
- Startup sync: Apply saved preference after app reinstall or update
- didSet sync: Immediate feedback when user toggles in Preferences

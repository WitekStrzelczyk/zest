---
last_reviewed: 2026-02-23
review_cycle: quarterly
status: current
---

# Developer FAQ

Common problems and solutions discovered during Zest development.

## Global Hotkeys & Menu Bar

### Quick Fix: Window Not Appearing on Hotkey

If your global hotkey is registered but the window doesn't appear, add `NSApp.activate(ignoringOtherApps: true)` BEFORE showing the window:

```swift
// BEFORE (broken) - Hotkey fires but window never appears:
hotkeyManager.register(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey)) { [weak self] in
    DispatchQueue.main.async {
        self?.toggleCommandPalette()  // Window doesn't show!
    }
}

// AFTER (fixed) - Window appears correctly:
hotkeyManager.register(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey)) { [weak self] in
    NSApp.activate(ignoringOtherApps: true)  // ← CRITICAL!
    self?.toggleCommandPalette()
}
```

**Why:** Menu bar apps (`LSUIElement=true`) don't automatically activate when a hotkey fires. Without activation, the app can't display windows.

---

### Menu Bar Button Not Responding to Clicks

If your `NSStatusItem` button doesn't trigger its action:

```swift
// BEFORE (broken):
button.action = #selector(menuBarClicked)

// AFTER (fixed):
button.target = self  // ← Required!
button.action = #selector(menuBarClicked)
```

**Why:** `action` alone isn't enough - `target` must be explicitly set for the action to dispatch.

---

### App Freezes on Startup / Menu Bar Unresponsive

If the app hangs during `applicationDidFinishLaunching`:

```swift
// BEFORE (blocking main thread):
func applicationDidFinishLaunching(_ notification: Notification) {
    awakeService.checkSystemCaffeination()  // Runs `pmset -g assertions` synchronously!
    // ... app is frozen until this completes
}

// AFTER (async):
func applicationDidFinishLaunching(_ notification: Notification) {
    awakeService.applySavedPreference()  // Runs async
    // ... app continues immediately
}

// In AwakeService:
func applySavedPreference() {
    Task { @MainActor [weak self] in
        let isCaffeinated = await Self.checkCaffeination()
        // Apply preference asynchronously
    }
}
```

**Why:** Synchronous shell commands (`Process.waitUntilExit()`) block the main thread, preventing the menu bar from appearing or responding.

---

### Mouse Events Not Working in Window

If clicks, scrolling, or hover effects stop working inside your window after adding event monitoring:

**Symptoms:**
- Mouse clicks on UI elements do nothing
- Scrolling doesn't work
- System error sound when clicking
- No hover effects on table rows

**The Fix:** Use target/action instead of global event monitors:

```swift
// ❌ WRONG - Global monitor intercepts ALL mouse events everywhere:
private func setupMenuBar() {
    let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
        self.toggleCommandPalette()  // Blocks clicks in YOUR window too!
    }
}

// ✅ CORRECT - Target/action only responds to actual button clicks:
private func setupMenuBar() {
    guard let button = statusItem.button else { return }
    button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Zest")
    button.target = self
    button.action = #selector(statusBarButtonClicked)
}

@objc private func statusBarButtonClicked() {
    NSApp.activate(ignoringOtherApps: true)  // Required for menu bar apps
    toggleCommandPalette()
}
```

**Why:** `NSEvent.addGlobalMonitorForEvents` captures events EVERYWHERE - it doesn't distinguish between "outside app" and "inside app windows". The monitor intercepts mouse events before they reach your views, making the window appear unresponsive. For menu bar items, always use the built-in target/action pattern.

---

## Deep Dive: Why NSApp.activate is Required

### The Problem

Menu bar apps configured with `LSUIElement=true` in Info.plist:
- Don't appear in the Dock
- Don't have a main menu bar
- **Don't automatically become active when events occur**

When Carbon's `RegisterEventHotKey` fires your callback, the system delivers the event but doesn't activate your app. Without activation:
- Windows created with `makeKeyAndOrderFront` may not appear
- Windows that do appear may not accept keyboard input
- The app can't become the key window

### The Solution Pattern

Always activate in the hotkey callback BEFORE any UI operations:

```swift
func setupGlobalHotkey() {
    hotkeyManager.register(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey)) { [weak self] in
        // Step 1: Activate the app
        NSApp.activate(ignoringOtherApps: true)
        
        // Step 2: Now safe to show UI
        self?.toggleCommandPalette()
    }
}
```

Note: `DispatchQueue.main.async` is NOT required if the callback is already on the main thread (Carbon hotkey callbacks are). However, wrapping in `DispatchQueue.main.async` is a safe pattern if you're unsure.

---

## Carbon Hotkey Debugging Checklist

When hotkeys don't work, check in this order:

### 1. Is the Hotkey Registered?

```swift
// Add logging to verify registration
let status = RegisterEventHotKey(
    hotKeyID.id,
    modifiers,
    callback,
    GetEventDispatcherTarget(),
    0,
    &hotkeyRef
)
NSLog("Hotkey registration status: \(status)")  // 0 = success
```

### 2. Is the Callback Being Called?

```swift
// Add NSLog at the very start of your callback
let callback: EventHandlerUPP = { _, event, userData -> OSStatus in
    NSLog("🔥 Hotkey callback fired!")  // Should appear in Console
    // ... rest of callback
    return noErr
}
```

View logs in Terminal:
```bash
log show --predicate 'process == "Zest"' --last 30s
```

### 3. Is the App Activating?

```swift
NSLog("Before activate - active: \(NSApp.isActive)")
NSApp.activate(ignoringOtherApps: true)
NSLog("After activate - active: \(NSApp.isActive)")
```

### 4. Are Accessibility Permissions Granted?

```swift
if !AXIsProcessTrusted() {
    NSLog("⚠️ Accessibility permissions not granted!")
    // Prompt user to enable in System Preferences
}
```

### 5. Is Another App Using the Hotkey?

Check for conflicts with:
- Spotlight (Cmd+Space)
- Alfred, Raycast, etc.
- Keyboard shortcuts in System Preferences

---

## Common Pitfalls

### Pitfall: Modifier Values Are Wrong

```swift
// WRONG (common mistake):
let modifiers = cmdKey | optionKey  // If optionKey = 512

// CORRECT:
// cmdKey = 256 (1 << 8)
// optionKey = 2048 (1 << 11)  <- NOT 512!
// shiftKey = 512 (1 << 9)
// controlKey = 128 (1 << 7)
```

Always verify Carbon constants:
```swift
NSLog("cmdKey=\(cmdKey), optionKey=\(optionKey), shiftKey=\(shiftKey)")
```

### Pitfall: Weak Self Captures

```swift
// WRONG - may crash if self is deallocated:
hotkeyManager.register(...) { _ in
    self.toggleCommandPalette()  // self is unowned, crashes if deallocated
}

// CORRECT - safe weak capture:
hotkeyManager.register(...) { [weak self] in
    NSApp.activate(ignoringOtherApps: true)
    self?.toggleCommandPalette()  // Safe, nil if deallocated
}
```

### Pitfall: Blocking in applicationDidFinishLaunching

Any synchronous operation in `applicationDidFinishLaunching` will:
- Delay the menu bar icon appearing
- Make the app appear "stuck"
- Prevent hotkeys from working until complete

**Move to async:**
- Network requests
- Shell commands (`Process`)
- Heavy computations
- File I/O

---

## Related Documentation

- [Global Hotkey Commands Implementation](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_global_hotkey_commands_20260218.md)
- [Carbon API Reference](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_global_hotkey_commands_20260218.md) (key codes and modifiers)
- [Architecture Overview](/Users/witek/projects/copies/zest/docs/architecture/README.md)

---

## Summary Table

| Symptom | Root Cause | Fix |
|---------|------------|-----|
| Hotkey fires, no window | App not active | `NSApp.activate(ignoringOtherApps: true)` |
| Menu bar click does nothing | Missing button target | `button.target = self` |
| App freezes on startup | Sync operation in `applicationDidFinishLaunching` | Move to `Task { }` |
| Hotkey not registered | Conflicting app | Change hotkey or disable other app |
| Wrong modifier behavior | Incorrect modifier value | Verify Carbon constants |
| Clicks/scroll not working in window | Global event monitor intercepting all events | Use target/action on button |

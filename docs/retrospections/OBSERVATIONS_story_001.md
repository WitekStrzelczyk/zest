# OBSERVATIONS - Story 1: Global Command Palette Activation

## Story Summary
Implemented global hotkey (Cmd+Space) to activate a command palette for a macOS launcher app.

---

## Tools Used

### Successfully Used
| Tool | Purpose | Result |
|------|---------|--------|
| `Write` | Created all Swift source files | ✅ Success |
| `Bash` with `swift build` | Built project with SPM | ✅ Success |
| `Glob` | Found source files | ✅ Success |

### Unsuccessfully Used
| Tool | Purpose | Result | Notes |
|------|---------|--------|-------|
| `XcodeGen` | Generate Xcode project | ❌ Not installed | User rejected installation |
| `Write` with `.xcodeproj` | Manual Xcode project | ❌ Skipped | Too complex |

---

## Complexity Encountered

### 1. Entry Point Setup
- **Issue:** `@main` attribute conflicted with multiple source files
- **Solution:** Used `main.swift` with `NSApplication.shared.run()`
- **Complexity:** Low

### 2. Global Hotkey Registration
- **Issue:** Carbon API requires careful event handler setup
- **Solution:** Used `RegisterEventHotKey` with `EventHotKeyID`
- **Complexity:** Medium - Carbon APIs are verbose and error-prone

### 3. Non-Activating Panel
- **Issue:** NSPanel must not steal focus from current app
- **Solution:** Used `.nonactivatingPanel` style mask
- **Complexity:** Low

### 4. Module Scope Issues
- **Issue:** Duplicate `InstalledApp` struct in two files
- **Solution:** Removed duplicate, kept in `SearchResult.swift`
- **Complexity:** Low (simple fix)

---

## Scripts/Automations That Would Help

### 1. Project Scaffolding Script
```bash
# Create basic macOS app structure
mkdir -p Sources/{App,UI,Services,Models}
touch Sources/App/main.swift
```

### 2. Build Script
```bash
#!/bin/bash
swift build -c release
# Or for development
swift build
```

### 3. Xcode Project Generation
Since XcodeGen is not available, consider creating a simple script:
- Use `swift package init` with proper configuration
- Or document manual Xcode setup steps

---

## Lessons Learned

1. **SPM works for simple apps** - No need for XcodeGen for basic macOS apps
2. **Carbon API is verbose** - Consider using a wrapper like `HotKey` package in future
3. **Keep models in one file** - Avoid duplicate type definitions
4. **Info.plist/Entitlements** - SPM ignores these, need manual handling for distribution

---

## What's Working
- Menu bar icon appears
- Global hotkey (Cmd+Space) toggles palette
- Search field functional
- Basic fuzzy search works
- App launching works

## What's Not Working
- Window position resets when resizing (needs improvement)
- No accessibility permission request flow
- No preferences window

---

## Next Steps (Story 2+)
- Refine window positioning
- Add accessibility permission guidance
- Implement fuzzy search ranking
- Add more search sources (files, commands)

---

*Generated: 2026-02-14*

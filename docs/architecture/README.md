# Architecture Overview

System architecture documentation for the Zest macOS command palette application.

## System Layers

```
┌─────────────────────────────────────┐
│           UI Layer                  │
│  (NSPanel, CommandPaletteWindow)    │
├─────────────────────────────────────┤
│         Service Layer               │
│  (SearchEngine, WindowManager,      │
│   ClipboardManager, ScriptManager) │
├─────────────────────────────────────┤
│          Model Layer                │
│  (SearchResult, App, Snippet)       │
├─────────────────────────────────────┤
│       Platform Integration          │
│  (Carbon API, NSWorkspace,          │
│   AXUIElement, EventKit)            │
└─────────────────────────────────────┘
```

## Core Components

### UI Layer

| Component | File | Purpose |
|-----------|------|---------|
| CommandPaletteWindow | Sources/UI/ | Main palette panel |
| PreferencesWindow | Sources/UI/ | Settings interface |

### Service Layer

| Service | File | Purpose |
|---------|------|---------|
| SearchEngine | Sources/Services/SearchEngine.swift | Unified search interface |
| WindowManager | Sources/Services/WindowManager.swift | Window manipulation via Accessibility API |
| ClipboardManager | Sources/Services/ClipboardManager.swift | Clipboard monitoring and history |
| ScriptManager | Sources/Services/ScriptManager.swift | Script execution |
| FileSearchService | Sources/Services/FileSearchService.swift | Spotlight-based file search |
| SnippetManager | Sources/Services/SnippetManager.swift | Text snippet management |
| SystemControlManager | Sources/Services/SystemControlManager.swift | System controls (dark mode, etc.) |
| QuicklinkManager | Sources/Services/QuicklinkManager.swift | URL quicklinks |

### Platform APIs

| API | Usage |
|-----|-------|
| Carbon API | Global hotkey registration (Cmd+Space) |
| NSWorkspace | App launching, URL opening |
| AXUIElement | Window tiling, movement, resize |
| NSMetadataQuery | Spotlight file search |
| EventKit | Reminders, Notes integration |
| NSPasteboard | Clipboard monitoring |

## Design Patterns

### Singleton Pattern

All services use the singleton pattern for shared state:

```swift
final class WindowManager {
    static let shared = WindowManager()
    private init() {}
}
```

### Protocol-Based Search

SearchEngine uses a unified interface for all search sources:

```swift
protocol SearchSource {
    func search(query: String, maxResults: Int) -> [SearchResult]
}
```

### Thread Safety

Services with shared state use NSLock:

```swift
private let processLock = NSLock()

var runningProcess: Process? {
    processLock.lock()
    defer { processLock.unlock() }
    return _runningProcess
}
```

## Key Architectural Decisions

1. **SPM for dependencies** - No XcodeGen required for basic builds
2. **Non-activating panel** - NSPanel with `.nonactivatingPanel` style
3. **visibleFrame for window operations** - Avoids covering menu bar/dock
4. **NSMetadataQuery over mdfind** - Better API control and performance

## Related Documentation

- [DESIGN.md](/Users/witek/projects/copies/zest/docs/DESIGN.md) - Product design
- [CONSOLIDATED_LEARNINGS.md](/Users/witek/projects/copies/zest/docs/retrospections/CONSOLIDATED_LEARNINGS.md) - Technical learnings

---

*Last reviewed: 2026-02-14*

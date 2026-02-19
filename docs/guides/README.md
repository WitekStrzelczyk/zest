# Implementation Guides

How-to documentation for building and extending Zest.

## Available Guides

### Development Workflow

| Guide | Summary |
|-------|---------|
| [TDD Guidelines](/Users/witek/projects/copies/zest/docs/TDD_GUIDELINES.md) | Test-driven development workflow and patterns |
| [Configuration Storage](/Users/witek/projects/copies/zest/docs/guides/CONFIGURATION_STORAGE.md) | UserDefaults vs App Support - when to use each |

### Feature Implementation

The following guides are consolidated from OBSERVATIONS files:

| Feature | Source | Key Patterns |
|---------|--------|--------------|
| Global Hotkey | [OBSERVATIONS_story_001.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_001.md) | Carbon API, NSPanel.nonactivatingPanel |
| Fuzzy Search | [OBSERVATIONS_story_002.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_002.md) | Scoring algorithm with bonuses |
| Window Tiling | [OBSERVATIONS_story_004.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_004.md) | AXUIElement, static methods |
| Window Movement | [OBSERVATIONS_story_005.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_005.md) | visibleFrame, off-screen detection |
| Clipboard History | [OBSERVATIONS_story_006.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_006.md) | Timer polling, privacy filtering |
| Script Execution | [OBSERVATIONS_story_007.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_007.md) | NSLock, async Process handling |
| File Search | [OBSERVATIONS_Story8_FileSearch.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_Story8_FileSearch.md) | NSMetadataQuery, result limiting |

### System Integration

| Feature | Source | Key Patterns |
|---------|--------|--------------|
| Reminders | [OBSERVATIONS_integration_14_15.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_integration_14_15.md) | EventKit async APIs |
| Notes | [OBSERVATIONS_integration_14_15.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_integration_14_15.md) | AppleScript fallback |
| Focus Mode | [OBSERVATIONS_focus_extensions_16_17.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_focus_extensions_16_17.md) | AppleScript shortcuts |
| Extensions | [OBSERVATIONS_focus_extensions_16_17.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_focus_extensions_16_17.md) | NSBundle loading |
| AI Integration | [OBSERVATIONS_ai_21.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_ai_21.md) | URLSession, async/await |

### Quality Assurance

| Guide | Summary |
|-------|---------|
| [Test Automation Review](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_test_automation_review.md) | Testing infrastructure analysis |
| [DEBT Implementation](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_debt_implementation.md) | Diagnostics and benchmarks |

## Common Patterns

### Adding a New Search Source

1. Create model in `Sources/Models/`
2. Create service in `Sources/Services/`
3. Add to SearchEngine's search pipeline
4. Write tests in `Tests/`

### Window Operations

Always use `visibleFrame` not full screen frame:

```swift
let screen = NSScreen.main
let visibleFrame = screen?.visibleFrame ?? screen?.frame
```

### Thread Safety

Use NSLock for shared state:

```swift
private let lock = NSLock()

func safeAccess() -> Value {
    lock.lock()
    defer { lock.unlock() }
    return _value
}
```

---

*Last reviewed: 2026-02-14*

# Zest - Design Document

## Overview

Zest is a native macOS command palette application (Raycast alternative) that provides quick access to apps, files, and system utilities through a global hotkey and fuzzy search interface.

---

## Core Rules

### Rule: First-Launch Onboarding
- When app first launches, show brief explanation of Cmd+Space hotkey
- Request Accessibility permission with clear explanation, not just system prompt
- Show step-by-step guide to enable permissions in System Settings

**Why:** Users need to understand why permissions are needed and how to grant them.

---

### Rule: Privacy-First Clipboard
- Always exclude clipboard content from password managers (1Password, Bitwarden, etc.)
- Show indicator when clipboard history is being recorded
- Provide "pause recording" option for sensitive workflows

**Why:** Users trust apps with clipboard access. Violating this trust is unforgivable.

---

### Rule: Mode Detection for Built-in Tools
- Calculator: Detect mathematical expressions (e.g., "2+2", "sqrt(16)")
- Emoji: Use prefix ":" for disambiguation (e.g., ":smile")
- AI: Use prefix "ai:" for commands (e.g., "ai: explain Swift")
- If ambiguous, prioritize by user history/context

**Why:** Single search bar must handle multiple input types without confusing users.

---

### Rule: Destructive Action Confirmation
- Always confirm before: Empty Trash, delete files, run destructive scripts
- Show warning icon and require second confirmation or typing action name

**Why:** Prevent accidental data loss.

---

### Rule: Visual Feedback for All Actions
- Global hotkey registered: Brief menu bar flash
- App launching: Palette closes, app appears
- Script running: Spinner/progress indicator
- Calculation result: Brief "Copied!" checkmark
- Error: Red text with recovery suggestion

**Why:** Users must always know what's happening.

---

## Section: Command Palette

### Purpose
The central interface for all app interactions - search and execute commands.

### User Goals
1. **Find and launch apps** - Primary use case
2. **Search files** - Quick document access
3. **Execute commands** - Run scripts, system controls

### Allowed Content
- Search input field (primary, largest)
- Results list (filtered by search)
- Keyboard hints at bottom (tertiary)
- Tab/segment control for categories (optional)

### Forbidden Content
- Navigation controls (not a file browser)
- Settings within the palette (use Preferences window)

### Implementation Decisions
- NSPanel with `.nonactivatingPanel` behavior
- Centered on active display
- Width: 600px, Max height: 500px
- Corner radius: 12px (macOS 11+)
- Shadow: standard macOS panel shadow

### Interaction Rules
| Key | Action |
|-----|--------|
| Cmd+Space | Toggle palette |
| Enter | Execute selected |
| Escape | Close palette |
| ↑/↓ | Navigate results |
| Tab | Switch category |
| Cmd+, | Open Preferences |

---

## Section: Menu Bar

### Purpose
Persistent access to app controls when palette is closed.

### User Goals
1. Open command palette
2. Access recent items
3. Open Preferences
4. Quit application

### Implementation Decisions
- NSStatusItem with custom icon
- Left-click: Open palette
- Right-click: Context menu
- Icon variants: light mode / dark mode

### Menu Structure
```
┌─────────────────────┐
│ Open Zest           │
│ ──────────────────  │
│ Recent Items →      │
│ ──────────────────  │
│ Preferences...      │
│ ──────────────────  │
│ Quit Zest           │
└─────────────────────┘
```

---

## Section: Preferences Window

### Purpose
Configure app behavior, shortcuts, and permissions.

### User Goals
1. Customize global hotkey
2. Enable/disable features
3. Manage extensions
4. Configure privacy settings

### Implementation Decisions
- SwiftUI-based (follows macOS Settings app)
- Tab-based navigation: General | Appearance | Shortcuts | Extensions | Privacy
- Search within preferences
- Reset to defaults option

### Tabs Structure
| Tab | Content |
|-----|---------|
| General | Launch at login, updates, behavior |
| Appearance | Theme, icon, animation |
| Shortcuts | Global hotkey, custom shortcuts |
| Extensions | Installed extensions |
| Privacy | Clipboard, file access, permissions |

---

## Visual Rules

### Color Palette
| Purpose | Light Mode | Dark Mode |
|---------|------------|-----------|
| Background | #FFFFFF (90% opacity) | #1E1E1E (90% opacity) |
| Text Primary | #000000 (90%) | #FFFFFF (90%) |
| Text Secondary | #000000 (60%) | #FFFFFF (60%) |
| Accent | System Blue | System Blue |
| Success | #34C759 | #30D158 |
| Error | #FF3B30 | #FF453A |
| Warning | #FF9500 | #FF9F0A |

### Typography
| Element | Font | Size | Weight |
|---------|------|------|--------|
| Search Input | SF Pro | 24pt | Regular |
| Result Title | SF Pro | 14pt | Medium |
| Result Subtitle | SF Pro | 12pt | Regular |
| Keyboard Hint | SF Pro | 11pt | Regular |

### Spacing
- Palette padding: 16px
- Result item height: 44px
- Result item padding: 8px horizontal
- Section spacing: 16px
- Corner radius: 12px

### Component Patterns
- **Search Field**: Rounded rect, magnifying glass icon left, clear button right
- **Result Item**: Icon (32x32) left, title + subtitle stacked right
- **Selected State**: System selection color background
- **Loading State**: Spinner centered

---

## Interaction Rules

### Keyboard Navigation
1. Arrow keys navigate results
2. Enter executes selected
3. Escape closes palette
4. Cmd+Space toggles palette
5. Tab cycles through categories
6. Cmd+, opens Preferences

### Global Hotkey Behavior
1. Press Cmd+Space anywhere → Palette appears
2. Press Cmd+Space while open → Palette closes
3. Press Escape → Palette closes, focus returns to previous app

### Result Selection
1. Type to search → Results filter instantly
2. Arrow up/down → Navigate results
3. Enter → Execute action
4. Cmd+Enter (files) → Reveal in Finder

---

## Accessibility

### Requirements
- Full keyboard navigation (no mouse required)
- VoiceOver labels for all elements
- Dynamic Type support
- Reduced Motion option for animations
- Minimum 44px touch targets

### VoiceOver Labels
| Element | Label |
|---------|-------|
| Search field | "Search apps, files, and commands" |
| Result item | "[App name], application, [keyboard shortcut]" |
| Icon button | "[Action], button" |

---

## Dependencies

```
Command Palette
├── Global Hotkey (Carbon/MASShortcut)
├── Search Engine (Fuse.js or custom)
├── App Index (NSWorkspace)
└── Results UI (NSPanel)

Menu Bar
└── NSStatusItem

Window Management
├── CGWindow API
└── Accessibility API (AXUIElement)

Clipboard History
├── NSPasteboard monitoring
└── SQLite storage

Script Execution
├── Process/NSTask
└── Output panel

System Integration
├── EventKit (Reminders, Notes)
├── DistributedNotificationCenter
└── Focus Mode API
```

---

## Story Implementation Priority

### Phase 1: Foundation (Must Have)
1. Global Command Palette Activation
2. Fuzzy Search Across Applications
3. Application Launch Execution
4. Window Tiling
5. Window Movement and Resize

### Phase 2: Core Features (High Value)
6. Clipboard History Access
7. Script Command Execution
8. File Search
9. Calculator Function
10. Quick Emoji Picker

### Phase 3: Advanced Features
11. Snippets Management
12. System Control
13. Quicklinks
14. Reminders Integration
15. Notes Integration
16. Focus Mode Control
17. Extensions Framework
18. Menu Bar Presence
19. Preferences Window
20. Launch at Login
21. AI Command Integration

---

## Version History

| Date | Change |
|------|--------|
| 2026-02-14 | Initial design document |

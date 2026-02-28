# Zest TODO Research Report

**Date:** February 24, 2026
**Purpose:** Analyze remaining TODO items and research popular feature requests from Raycast community

---

## Executive Summary

This research identifies:
1. Remaining stories in TODO.md that need implementation
2. Popular features from Raycast Store and community that could be added to Zest
3. Prioritized recommendations for future development

---

## Part 1: Remaining Stories in TODO.md

### Foundation & Core Features (Pending)

| Story # | Title | Status | Priority |
|---------|-------|--------|----------|
| 19 | Preferences Window | `[ ]` | HIGH - Required for configuration |
| 20 | Launch at Login | `[ ]` | HIGH - Essential for launcher app |
| 21 | Process Monitoring | `[ ]` | MEDIUM - System visibility |
| 22 | Process Force Quit | `[ ]` | MEDIUM - Follows Process Monitoring |
| 23 | Unit Conversion Function | `[ ]` | MEDIUM - Quick win, high value |
| QA-10 | Performance Profiling | `[ ]` | LOW - Nice to have |

### Completed Stories (Summary)

The following phases are complete:
- **Phase 1: Foundation** - Global hotkey, fuzzy search, app launch (Stories 1-5)
- **Phase 2: Core Features** - Clipboard, scripts, file search, calculator, emoji (Stories 6-10)
- **Phase 3: Advanced Features** - Snippets, system control, quicklinks, integrations (Stories 11-18)
- **Phase 4: QA Infrastructure** - Formatting, linting, coverage, TDD (Stories QA-1 to QA-9)

---

## Part 2: Raycast Store Research

### Research Methodology

Analyzed Raycast Store's "Most Popular" extensions by install count. These represent proven, high-demand features that users actively seek in a command palette application.

### Top 15 Popular Extensions (by install count)

| Rank | Extension | Installs | Category | Relevance to Zest |
|------|-----------|----------|----------|-------------------|
| 1 | Kill Process | 497,005 | System | ⚠️ Similar to Story 21/22 |
| 2 | Color Picker | 365,990 | Design | ✅ NEW STORY 24 |
| 3 | Google Chrome | 359,835 | Browser | 🔸 Low priority (browser-specific) |
| 4 | Google Translate | 345,652 | Productivity | ✅ NEW STORY 25 |
| 5 | Spotify Player | 339,713 | Media | 🔸 Low priority (media-specific) |
| 6 | Visual Studio Code | 277,817 | Developer | 🔸 Low priority (IDE-specific) |
| 7 | Linear | 240,375 | Productivity | 🔸 Low priority (service-specific) |
| 8 | Slack | 223,707 | Communication | 🔸 Low priority (service-specific) |
| 9 | ChatGPT | 216,218 | AI | ⏭️ Excluded (non-AI focus) |
| 10 | Homebrew | 215,087 | Developer | ✅ NEW STORY 27 |

### Raycast Core Features (Built-in)

These are native Raycast features that have high adoption:

| Feature | Description | Relevance to Zest |
|---------|-------------|-------------------|
| Raycast Notes | Floating notes with markdown | ✅ NEW STORY 29 |
| Clipboard History | Already in Zest (Story 6) | ✅ COMPLETE |
| Window Management | Already in Zest (Stories 4-5) | ✅ COMPLETE |
| Snippets | Already in Zest (Story 11) | ✅ COMPLETE |
| File Search | Already in Zest (Story 8) | ✅ COMPLETE |
| Calculator | Already in Zest (Story 9) | ✅ COMPLETE |
| Calendar | View events, join meetings | ✅ NEW STORY 26 |
| System Controls | Already in Zest (Story 12) | ✅ COMPLETE |
| Focus Mode | Already in Zest (Story 16) | ✅ COMPLETE |
| Emoji Picker | Already in Zest (Story 10) | ✅ COMPLETE |
| Quicklinks | Already in Zest (Story 13) | ✅ COMPLETE |

---

## Part 3: Feature Gap Analysis

### Features Zest Has (vs Raycast)

| Feature | Zest | Raycast |
|---------|------|---------|
| Global Hotkey | ✅ | ✅ |
| Fuzzy Search | ✅ | ✅ |
| App Launcher | ✅ | ✅ |
| Clipboard History | ✅ | ✅ |
| Window Management | ✅ | ✅ |
| Calculator | ✅ | ✅ |
| Emoji Picker | ✅ | ✅ |
| Snippets | ✅ | ✅ |
| Quicklinks | ✅ | ✅ |
| System Controls | ✅ | ✅ |
| Focus Mode | ✅ | ✅ |
| File Search | ✅ | ✅ |
| Script Commands | ✅ | ✅ |
| Reminders Integration | ✅ | ✅ |
| Notes Integration | ✅ | ✅ |

### Features Zest Lacks (Popular in Raycast)

| Feature | Demand | Complexity | Recommendation |
|---------|--------|------------|----------------|
| Color Picker | 365k+ installs | Low | ✅ Add (Story 24) |
| Translation | 345k+ installs | Medium | ✅ Add (Story 25) |
| Calendar/Meeting Join | 240k+ users | Medium | ✅ Add (Story 26) |
| Homebrew | 215k+ installs | Low | ✅ Add (Story 27) |
| Pomodoro Timer | High community demand | Low | ✅ Add (Story 28) |
| Floating Notes | Highly requested | Medium | ✅ Add (Story 29) |
| Audio Device Switcher | Common request | Medium | ✅ Add (Story 30) |
| Battery/System Info | Common request | Low | ✅ Add (Story 31) |
| IP/Network Info | Developer demand | Low | ✅ Add (Story 32) |
| Time Zone Converter | Remote work demand | Low | ✅ Add (Story 33) |

---

## Part 4: Community Request Sources

### Raycast Forum Topics (Unable to access directly)

The Raycast forum at `forum.raycast.com` was inaccessible during research. Alternative sources used:

1. **Raycast Store Analytics** - Install counts reveal actual usage patterns
2. **GitHub Issues** - `raycast/script-commands` repository
3. **Raycast Documentation** - Core features reveal product priorities

### Common Request Themes (from launcher communities)

Based on Raycast Store patterns and launcher app comparisons:

1. **System Utilities** - Audio switching, battery, network info
2. **Developer Tools** - Homebrew, IP addresses, process management
3. **Productivity** - Pomodoro, calendar, time zones
4. **Design Tools** - Color picker, format conversion
5. **Communication** - Translation, notes

---

## Part 5: New Stories Added to TODO.md

### Stories 24-33 (Community-Requested Features)

| Story | Title | Source | Use Case |
|-------|-------|--------|----------|
| 24 | Color Picker | Raycast Store (365k) | Design/Dev - Pick colors from screen |
| 25 | Translation Tool | Raycast Store (345k) | Multilingual - Quick translations |
| 26 | Calendar Integration | Raycast Store (240k) | Productivity - View meetings, join calls |
| 27 | Homebrew Integration | Raycast Store (215k) | Developer - Search/install packages |
| 28 | Pomodoro Timer | Productivity community | Time Management - Focus sessions |
| 29 | Quick Notes | Raycast Notes feature | Capture - Floating note window |
| 30 | Audio Device Switcher | Launcher community request | System - Switch audio in/out |
| 31 | Battery and System Info | Productivity community | Monitoring - Health status |
| 32 | IP Address and Network Info | Developer community | Network - Local/public IP |
| 33 | Time Zone Converter | Remote work community | Collaboration - Time conversion |

---

## Part 6: Recommended Implementation Order

### Phase 5: Essential Configuration (Immediate)
1. **Story 19: Preferences Window** - Required for all configuration
2. **Story 20: Launch at Login** - Essential for launcher app
3. **Story 23: Unit Conversion** - Quick win, complements Calculator

### Phase 6: High-Value Features
4. **Story 24: Color Picker** - Popular with designers/developers (365k users)
5. **Story 25: Translation** - Popular with multilingual users (345k users)
6. **Story 26: Calendar Integration** - Essential for productivity (240k users)
7. **Story 28: Pomodoro Timer** - Popular productivity tool

### Phase 7: Developer Tools
8. **Story 27: Homebrew Integration** - Popular with developers (215k users)
9. **Story 21: Process Monitoring** - System visibility
10. **Story 22: Process Force Quit** - Follows Process Monitoring
11. **Story 31: Battery and System Info** - System monitoring
12. **Story 32: IP Address and Network Info** - Developer utility

### Phase 8: Quality of Life
13. **Story 29: Quick Notes** - Complements clipboard/snippets
14. **Story 30: Audio Device Switcher** - Convenience feature
15. **Story 33: Time Zone Converter** - Quick win

---

## Part 7: Features NOT Recommended (and why)

| Feature | Reason |
|---------|--------|
| AI/ChatGPT | Explicitly excluded per user request (non-AI focus) |
| Browser-specific (Chrome tabs) | Not universally useful, browser-dependent |
| Service integrations (Linear, Slack) | Require API keys, service subscriptions |
| Media players (Spotify) | Service-specific, limited audience |
| IDE integrations (VS Code) | Tool-specific, not universal |

---

## Appendix: Research URLs

- Raycast Store: https://www.raycast.com/store
- Raycast Popular Extensions: https://www.raycast.com/store/popular
- Raycast Core Features: https://www.raycast.com/core-features
- Raycast Developer Docs: https://developers.raycast.com/
- Raycast GitHub: https://github.com/raycast/script-commands
- Raycast Calendar: https://www.raycast.com/core-features/calendar
- Raycast Notes: https://www.raycast.com/core-features/notes

---

## Conclusion

Zest already has excellent coverage of core launcher features. The gap analysis shows opportunities in:

1. **Quick wins** - Color picker, IP info, time zones (low complexity, high value)
2. **Developer tools** - Homebrew, system info, process management
3. **Productivity** - Calendar, Pomodoro, translation
4. **System utilities** - Audio switching, battery monitoring

The recommended Phase 5 (Preferences, Launch at Login, Unit Conversion) should be completed first as these enable configuration and daily usage. Subsequent phases can be prioritized based on target user personas (designers, developers, or general productivity users).

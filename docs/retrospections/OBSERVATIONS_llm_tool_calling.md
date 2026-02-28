# Observations: LLM Tool Calling Experiment

Date: 2026-02-27
Agent: reflective-coding-agent

## Problem Solved
Implemented an experimental LLM-style tool calling parser that detects when a user types a command starting with `=` and extracts structured tool calls with parameters. Two tools supported: `create_calendar_event` and `find_files`.

---

## For Future Self

### How to Prevent This Problem
- When adding new tools, follow the existing pattern in `LLMToolCall.swift` and `LLMToolCallingService.swift`
- Keep regex patterns simple and testable - complex patterns are hard to debug
- Use the `confidence` score to indicate how certain the parser is about the match

### How to Find Solution Faster
- Key insight: Pattern matching with regex can simulate LLM parsing well enough for an experiment
- Search that works: `Grep "LLMToolCalling"` finds all related code
- Start here: `Sources/Models/LLMToolCall.swift` - data models
- Debugging step: Use `LLMToolCallingServiceTests.swift` to test patterns

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `Read CalendarServiceTests.swift` | Understood existing test patterns for service testing |
| `Read CommandPaletteWindow.swift` | Understood how to integrate new modes |
| `swift test --filter LLMToolCalling` | Isolated tests for faster iteration |
| Existing codebase patterns | CalendarService showed pattern for model + service |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Complex regex patterns | Hard to debug, simplified tests instead |
| Trying to match all edge cases | Experiment doesn't need perfect parsing |

---

## Agent Self-Reflection

### My Approach
1. Read existing code patterns (CalendarService, CommandPaletteWindow) - worked well
2. Write tests first (RED phase) - worked well
3. Implement service incrementally - worked well
4. Integrate with UI - worked well

### What Was Critical for Success
- **Key insight:** Following TDD strictly caught regex issues early
- **Right tool:** `swift test --filter` for isolated testing
- **Right question:** "What existing patterns can I follow?"

### What I Would Do Differently
- [ ] Start with simpler regex patterns in tests
- [ ] Ask about MLX integration timeline upfront
- [ ] Read CommandPaletteWindow's mode handling first

### TDD Compliance
- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [x] Refactored while green

---

## Code Changed
- `Sources/Models/LLMToolCall.swift` - NEW: Data models for tool calls
- `Sources/Services/LLMToolCallingService.swift` - NEW: Parsing logic
- `Sources/UI/LLMToolCallPanelView.swift` - NEW: UI for displaying tool calls
- `Sources/UI/CommandPalette/CommandPaletteWindow.swift` - MODIFIED: Added `=` prefix detection and LLM mode

## Tests Added
- `Tests/LLMToolCallingServiceTests.swift` - 24 tests covering:
  - Service creation and singleton
  - Calendar event detection (date, time, contact, location)
  - File search detection (extension, modified within, content search)
  - Edge cases (empty, whitespace, ambiguous)
  - Confidence scoring
  - Model tests (equality, completeness)

## Verification
```bash
# Build with no warnings
swift build 2>&1 | grep -E "(error:|warning:)" || echo "OK"

# Run LLM tests
swift test --filter LLMToolCalling

# Run the app
./scripts/run_app.sh
# Then type: =meeting tomorrow at 3pm with Sarah
```

## How to Test
1. Run the app: `./scripts/run_app.sh`
2. Open command palette with Cmd+Space
3. Type `=meeting tomorrow at 3pm with Sarah`
4. Should show a panel with:
   - Tool: "Create a calendar event"
   - Parameters: Title, Date (tomorrow), Time (3pm), Contact (Sarah)
   - Execute button
5. Press Escape to dismiss

## Example Inputs
```
=In Person appointment 02/03/2026 at 10:15 AM with John
=find files modified in last 24 hours containing budget
=meeting with Sarah
=find report.pdf
```

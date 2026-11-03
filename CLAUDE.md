# Zest principles

Zest is a native Swift/AppKit macOS menu-bar command palette. These principles are the only project documentation; when a task teaches something durable, fold it in here.

## Business goals

1. **Performance first: minimal CPU and memory footprint.** Zest lives in the menu bar all day, so idle cost matters more than any feature. Nothing runs, polls or stays in memory unless the user needs it right now. No change may increase idle memory, idle CPU or search latency without an explicit decision; measure before and after.
2. Reach apps, files and system utilities from one global hotkey, without the mouse. Finding and launching apps is the main use case; file search and commands come next.
3. Compete with Raycast on native performance, privacy-first local processing, and a focused feature set without bloat.
4. Add a feature only on proven demand. Prefer built-in tools useful to everyone over browser-, IDE- or service-specific integrations that need API keys.
5. No AI features.

## Performance

- Idle memory under 50 MB, startup under 500 ms, search under 100 ms for 80% of queries, in-memory search under 50 ms.
- Never block the main thread: no synchronous process, network, file I/O or heavy work in `applicationDidFinishLaunching` or on `@MainActor`.
- Every external process, and every async call wrapped as sync, has a timeout (never a bare `waitUntilExit`); on timeout return partial results.
- We rely on the system's storage indexing (Spotlight) for finding apps and files: we query its index natively and never build our own index or change its configuration.
- Serve slow or permission-gated sources cache-first: return the cache synchronously, refresh in the background, notify the UI to re-run the search.
- No timers or recurring work: refresh a cache only when a search needs it.
- Debounce typing (100 ms), cancel stale searches, cap the merged result list (80).
- Build expensive objects (regexes, detectors, icons) once or lazily, never per keystroke or per item not on screen.
- Keyword-gated tools wake on a whole word (`ip`, not `zip`) or a 3+ letter prefix (`matchesKeyword`), never on single letters.
- Trace every search per tool (`SearchTracer`), but print nothing unless tracing output is enabled.

## Architecture

- Keep layers separate: UI / State / Services / Models; each file lives where its responsibility belongs.
- Every intent and tool is a final singleton (`static let shared`, private init) conforming to `SearchTool`: it builds its own results from the `QueryContext`. `SearchEngine` only runs its `intents` and `instantTools` lists.
- Folders: `Search` (pipeline, scoring, query analysis), `Intents` (turn a query into an action), `Tools` (instant answers), `Services` (system integrations).
- One multi-intent search pipeline and one central scoring algorithm; deduplicate by bundle ID, then by title.
- A new result category updates `SearchResultCategory` and `SearchScoringWeights` first.
- Decouple services from UI through `NotificationCenter`, with names as `Notification.Name` extensions.
- Thread-safe from the start: `NSLock` for shared state, `@MainActor` for UI, a local `NLTagger` per task.
- Simple preferences in `UserDefaults`; user content as JSON in Application Support; paths via `FileManager`, never hard-coded; handle missing files.
- For system-level settings, the real system state is the source of truth.
- Key state by stable IDs (PID, bundle ID), not regenerated UUIDs.
- Prefer native, current Apple frameworks over shell tools and deprecated APIs.
- Reuse existing services and patterns before creating new ones. When removing a feature, remove every reference to it.
- Build with SwiftPM only.

## UX

- Everything is keyboard-operable with standard macOS keys: ↑/↓, Enter, Esc, Cmd+Enter to reveal, Space for Quick Look, Cmd+1–9.
- Never break Cmd+A/C/V/X in the search field; forward unhandled Cmd+key presses to the field editor.
- The palette is a non-activating panel centred on the active display. The hotkey toggles it; Esc closes it and refocuses the previous app.
- The first result is auto-selected; Enter with no selection runs the first result; Up from the first result returns to search; typing returns focus to search; keyboard navigation clears hover state.
- Every action gives visible feedback ("Copied!", spinner, "No results found", red errors with a recovery hint).
- When a tool produces a value, Enter copies it.
- Confirm destructive actions. Force-quit is two-phase (SIGTERM, then SIGKILL) with visible state and a warning for system processes.
- File search hides hidden, private and build folders; process search never shows other users' processes.
- Explain a permission in a result and ask only when the user picks it, never at launch; when denied, show a result that opens the right Privacy pane.
- Clear state whenever the palette switches mode.
- SF Pro, 44 px rows, light and dark themes, VoiceOver labels, Reduced Motion.

## Scheduling

- Scheduling is one line of plain language: what, when, where and with whom ("tomorrow meeting at Coulomb Beach with Roger at 4 pm"). It is parsed on the device with native frameworks, and the result previews exactly what Enter will create (title, local day and time, place, people). After saving, it confirms the event.
- Before creating, check that day's calendar. An event with the same title at the same time is a duplicate: show the existing event instead of creating a second one. An event that overlaps is a collision: name it in the preview ("Overlaps Standup 4:00–4:30 PM") and let the user create anyway.
- Reviewing is one query away: a day's agenda ("today", "tomorrow", "friday meetings") in time order, with the active meeting first and its video link one Enter away.

## Code

- Zero build warnings.
- Lint limits are those in `.swiftlint.yml`.
- Swift API naming; no clashes with Foundation names.
- Guard and early return, one responsibility per function, no duplication.
- No force casts, `try!` or implicitly unwrapped optionals.
- Log with `os.log` `Logger`, not `print`.
- No comments in code; names carry the meaning.
- Verify CLI options, API types and constants before relying on them.

## Testing

- Test first (RED → GREEN → REFACTOR); a task is not done while any test fails.
- Tests cover business scenarios: edge cases, both directions, common user mistakes.
- Run tests and hang-prone commands under a 40 s timeout (`./scripts/run_tests.sh 40`, `./scripts/timeout.sh`).
- 50% coverage gate; `./scripts/quality.sh` runs format → lint → build → test → coverage locally. No CI.
- No long sleeps in tests; use expectations, async/await or short polling.
- Services that need XPC or permissions have a disable flag for tests and are disabled in every `SearchEngine` test.
- Timing tests keep at least a 25% buffer and benchmark with `searchFast`.
- Tests use swift-testing (`@Test`, `#expect`); XCTest needs Xcode. The scripts pass the toolchain's testing plugin path.
- Code that blocks on the main queue (`SearchEngine.search`, file search) is tested off the main actor.

## Process

- Work goes: story (product-owner, "As a / I want / So that" with Given/When/Then) → test-first implementation → lessons folded into these principles.
- Check existing code, tests and stories before implementing anything.
- After changes: build with zero warnings, launch the app (`./scripts/run_app.sh`), run the tests, and check keyboard and UI changes by hand in the running app.

# Zest - User Stories

Zest is a native macOS command palette application that provides quick access to apps, files, and system utilities through a global hotkey and fuzzy search interface.

---

## Foundation

### [x] Story 1: Global Command Palette Activation

**As a** power user who needs quick access to system functions without leaving the keyboard
**I want** to activate a command palette from anywhere using a global keyboard shortcut
**So that** I can launch apps, search files, and execute commands without touching the mouse

### Use Case Context
Part of: "Quick Access" use case
- Precedes: All other launcher stories
- This is the entry point for the entire application

### Verification Strategy
Global hotkey must work regardless of which application is currently focused. The palette should appear instantly.

#### Test Cases (Acceptance Criteria)
- **Given** no active windows, **When** I press the global hotkey (Cmd+Space), **Then** the command palette window appears centered on screen
- **Given** any application is focused (e.g., Safari), **When** I press the global hotkey, **Then** the command palette appears without switching away from Safari
- **Given** the command palette is open, **When** I press Escape, **Then** the palette closes and focus returns to the previous application
- **Given** the command palette is open, **When** I press the global hotkey again, **Then** the palette closes

### Implementation Notes
- Use Carbon HotKey API or MASShortcut for global hotkey registration
- Create an NSPanel with .nonactivatingPanel behavior to avoid stealing focus
- Consider accessibility permissions requirement for global hotkeys

---

### [x] Story 2: Fuzzy Search Across Applications

**As a** developer who frequently switches between many applications
**I want** to fuzzy search and launch applications by typing partial names
**So that** I can find and open apps faster than Spotlight or the Dock

### Use Case Context
Part of: "Quick Launch" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Search should be fast (<100ms perceived latency) and fuzzy matching should handle typos.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open with empty search field, **When** I type "chr", **Then** "Chrome" appears in results
- **Given** the command palette is open, **When** I type "slack", **Then** "Slack" appears even if I don't type the exact characters
- **Given** the command palette is open, **When** I type "vscode", **Then** "Visual Studio Code" appears in results
- **Given** no matching application exists, **When** I type "xyznonexistent", **Then** I see "No results found" message
- **Given** multiple matches exist, **When** I type "s", **Then** results are sorted by relevance/frequency of use
- **Given** the first result is selected, **When** I press Enter, **Then** the application launches and palette closes

### Implementation Notes
- Use Fuzzy matching algorithm (e.g., Fuse.js or custom implementation)
- Cache installed applications list and listen for changes via NSWorkspace notifications
- Track application launch frequency for relevance scoring

---

### [x] Story 3: Application Launch Execution

**As a** user who wants to open applications quickly
**I want** to launch a selected application by pressing Enter
**So that** I can start working in my desired application immediately

### Use Case Context
Part of: "Quick Launch" use case
- Follows: "Fuzzy Search Across Applications" story

### Verification Strategy
Launch must succeed and the app should become the frontmost application.

#### Test Cases (Acceptance Criteria)
- **Given** Chrome is not running and search shows "Chrome" as selected, **When** I press Enter, **Then** Chrome launches and becomes the frontmost window
- **Given** Chrome is already running, **When** I select Chrome and press Enter, **Then** Chrome window comes to the foreground
- **Given** an application is launching, **When** I press Enter, **Then** the palette closes immediately (no wait for app to fully launch)

### Implementation Notes
- Use NSWorkspace.shared.openApplication(at:configuration:) for launching
- Pre-warm frequently used applications if possible

---

### [x] Story A: Fix Duplicate Search Results

**As a** user who searches for applications
**I want** to see each application only once in search results
**So that** I can easily select the app I want without duplicates

### Use Case Context
Part of: Bug fix from screenshot analysis
- Related to: "Fuzzy Search Across Applications" story

### Verification Strategy
Search results must not contain duplicate entries.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I search for "sa", **Then** "FaceTime" appears only once in results (not twice)
- **Given** the command palette is open, **When** I search for "saf", **Then** "Safari" appears only once in results (not twice)
- **Given** multiple apps match a search query, **When** I view results, **Then** each unique app appears only once
- **Given** the same app has multiple variants (e.g., different versions), **When** I search, **Then** only the best match is shown

### Implementation Notes
- Review the search results deduplication logic
- Ensure search index or results array uses unique identifiers (bundle ID) for deduplication
- Check if the same app is being indexed/added multiple times

---

### [x] Story B: Fix Window Sizing and Icon Clipping

**As a** user who uses the command palette
**I want** the window to properly display all content without clipping
**So that** I can see all search results clearly

### Use Case Context
Part of: Bug fix from screenshot analysis

### Test Cases
- **Given** search results are displayed, **When** I view the window, **Then** icons are not clipped
- **Given** the window expands, **When** results appear, **Then** the window remains centered

---

### [x] Story 4: Window Tiling

**As a** developer working with multiple windows who needs to compare code
**I want** to tile windows side by side using keyboard commands
**So that** I can arrange my workspace without using the mouse

### Use Case Context
Part of: "Window Management" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Windows should tile precisely and respect the current display bounds.

#### Test Cases (Acceptance Criteria)
- **Given** two windows are open (Chrome and VS Code), **When** I trigger "Tile Left", **Then** the selected window fills the left half of the screen
- **Given** two windows are open, **When** I trigger "Tile Right", **Then** the selected window fills the right half of the screen
- **Given** multiple displays are connected, **When** I tile a window, **Then** it tiles on the display where the window is currently located
- **Given** a tiled window, **When** I drag it to a new position, **Then** it detaches from the tile layout

### Implementation Notes
- Use CGWindow API to get window information and CGSession for moving/resizing
- Handle full-screen and split-view modes
- Support standard tiling layouts: half-left, half-right, quarter corners

---

### [x] Story 5: Window Movement and Resize

**As a** user who needs precise control over window positions
**I want** to move and resize windows using keyboard shortcuts
**So that** I can organize windows exactly as I need them

### Use Case Context
Part of: "Window Management" use case
- Follows: "Window Tiling" story

### Verification Strategy
Window operations should be smooth and instant with no visible lag.

#### Test Cases (Acceptance Criteria)
- **Given** a window is selected, **When** I trigger "Maximize", **Then** the window fills the entire display (excluding menu bar)
- **Given** a window is selected, **When** I trigger "Center", **Then** the window moves to the center of the display
- **Given** a window is selected, **When** I trigger "Resize to 80%", **Then** the window resizes to 80% of display size while maintaining position
- **Given** a window is off-screen, **When** I trigger "Move to Screen", **Then** the window moves back to visible area

### Implementation Notes
- Use Accessibility API (AXUIElement) for window manipulation
- Store user's preferred window positions per-application
- Handle multi-monitor setups correctly

---

## Core Features

### [x] Story 6: Clipboard History Access

**As a** writer who frequently copies and pastes text
**I want** to access my clipboard history through the command palette
**So that** I can retrieve previously copied items without re-copying them

### Use Case Context
Part of: "Clipboard Management" use case
- Follows: "Command Palette Activation" story (independent)

### Verification Strategy
Clipboard history should be stored persistently and sync across app restarts.

#### Test Cases (Acceptance Criteria)
- **Given** I have copied text "Hello World" to clipboard, **When** I open the command palette and search for "Hello", **Then** "Hello World" appears in results
- **Given** I have copied multiple items, **When** I open clipboard history, **Then** items are shown in reverse chronological order (newest first)
- **Given** an image is in clipboard history, **When** I select it and press Enter, **Then** the image is pasted into the active application
- **Given** clipboard history has 100+ items, **When** I scroll through history, **Then** performance remains smooth (no lag)
- **Given** clipboard history is enabled, **When** I copy sensitive data (password from 1Password), **Then** it is excluded from history or requires confirmation

### Implementation Notes
- Monitor NSPasteboard.general for changes using a timer or polling
- Store history in SQLite or UserDefaults with size limits
- Support text, images, files, and URLs
- Consider privacy filtering for passwords (detect password managers)

---

### [x] Story 7: Script Command Execution

**As a** developer who automates repetitive tasks
**I want** to execute custom shell scripts from the command palette
**So that** I can run my automation scripts without opening Terminal

### Use Case Context
Part of: "Automation" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Scripts must execute safely with proper output capture and error handling.

#### Test Cases (Acceptance Criteria)
- **Given** a script command "Git Status" is configured, **When** I search for "git status" and select it, **Then** the script runs and output is displayed in a panel
- **Given** a script is running, **When** I press Cmd+. or Escape, **Then** the script is terminated
- **Given** a script produces an error, **When** it completes, **Then** the error output is shown in red
- **Given** a script requires user input, **When** it runs, **Then** an input field appears for the user to provide values

### Implementation Notes
- Store scripts in ~/Library/Application Support/Zest/Scripts/
- Use Process/NSTask for execution with proper PATH setup
- Support environment variable configuration per script
- Implement script editor UI with syntax highlighting (optional for v1)

---

### [x] Story 8: File Search

**As a** knowledge worker who needs to find documents quickly
**I want** to search for files by name across my system
**So that** I can locate and open files faster than Finder

### Use Case Context
Part of: "Find Files" use case
- Follows: "Command Palette Activation" story
- Status: **COMPLETE** - mdfind implementation works safely with proper process arguments, async handling, and privacy filtering.

### Verification Strategy
Search should index common directories and provide fast results.

#### Test Cases (Acceptance Criteria)
- **Given** a file named "Q4-Report.pdf" exists in Documents, **When** I search for "Q4 Report", **Then** "Q4-Report.pdf" appears in results
- **Given** multiple files match, **When** I press Enter on a result, **Then** the file opens in its default application
- **Given** a file is located in a hidden directory, **When** I search for it, **Then** it does NOT appear in results (privacy)
- **Given** search returns results, **When** I press Cmd+Enter, **Then** the file reveals in Finder
- **Given** the search is performed, **When** I type query, **Then** results appear within 100ms

### Implementation Notes
**CRITICAL: Current mdfind implementation does not work. Must rewrite using NSMetadataQuery.**

**Why NSMetadataQuery:**
- mdfind uses command-line tool which can hang and is hard to control
- NSMetadataQuery is the native Spotlight API - macOS already indexes files via mds/mdworker
- Provides real-time notifications when files change
- Supports both name and content search

**Implementation Requirements:**
1. **Use NSMetadataQuery** instead of mdfind:
   - Create NSMetadataQuery for file search
   - Set search scopes to ~/Documents, ~/Downloads, ~/Desktop
   - Use kMDItemDisplayName for filename search
   - Use kMDItemTextContent for content search (PDFs, TXT, DOCX, etc.)

2. **Search Scope:**
   - Default directories: ~/Documents, ~/Downloads, ~/Desktop
   - Use NSMetadataQueryUserHomeScope for home directory search
   - Support custom directories via preferences

3. **Optional: FSEvents for Change Tracking:**
   - Use FSEvents API or DispatchSource to watch for file changes
   - Update search index when files are added/modified/deleted
   - This is optional - NSMetadataQuery also provides notifications

4. **Filters and Actions (like Raycast):**
   - Filter by file type (documents, images, folders)
   - Action: Open file in default application
   - Action: Reveal in Finder (Cmd+Enter)
   - Action: Copy path to clipboard
   - Action: Quick Look preview

5. **Performance:**
   - Limit results to 20-50 items
   - Debounce search input (300ms)
   - Show loading indicator while query is running
   - Cache frequent searches

6. **Privacy:**
   - Exclude hidden directories (starting with .)
   - Exclude: .git, node_modules, build directories, .cache
   - Respect Spotlight privacy preferences

7. **Error Handling:**
   - Handle case when Spotlight is disabled
   - Handle permission denied errors gracefully
   - Show user-friendly error messages

---

### [x] Story 9: Calculator Function

**As a** developer who frequently needs quick calculations
**I want** to perform calculations directly in the command palette
**So that** I can get instant results without opening Calculator app

### Use Case Context
Part of: "Built-in Tools" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Calculator should handle standard mathematical expressions accurately.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I type "2+2", **Then** "4" appears as the top result
- **Given** the command palette is open, **When** I type "100 * 5 + 20", **Then** "520" appears as the top result
- **Given** the command palette is open, **When** I type "sqrt(16)", **Then** "4" appears
- **Given** I have a result, **When** I press Enter, **Then** the result is copied to clipboard and palette closes

### Implementation Notes
- Implement expression parser supporting: +, -, *, /, %, ^, sqrt, sin, cos, tan
- Use NSExpression for parsing or custom recursive descent parser
- Copy result to clipboard on selection (with visual feedback)

---

### [x] Story 23: Unit Conversion Function

**As a** developer and knowledge worker who frequently needs to convert units while working
**I want** to type natural language conversions like "100 km to miles" in the command palette
**So that** I can quickly get conversions without opening a separate app or website

### Use Case Context
Part of: "Built-in Tools" use case
- Follows: "Calculator Function" story (Story 9)
- Integrates with: "Quick Emoji Picker" and other built-in tools

### Verification Strategy
Unit conversion must handle common cases accurately and provide results instantly.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I type "100 km to miles", **Then** "62.14 miles" appears as the top result
- **Given** the command palette is open, **When** I type "50 kg to lbs", **Then** "110.23 lbs" appears as the top result
- **Given** the command palette is open, **When** I type "72 f to c", **Then** "22.22°C" appears as the top result
- **Given** the command palette is open, **When** I type "1 gallon to liters", **Then** "3.79 liters" appears
- **Given** the command palette is open, **When** I type "1000 mb to gb", **Then** "0.98 GB" appears (binary)
- **Given** the command palette is open, **When** I type an invalid conversion like "100 km to apples", **Then** no conversion result appears
- **Given** I have a conversion result, **When** I press Enter, **Then** the result is copied to clipboard and palette closes
- **Given** the command palette is open, **When** I type "convert", **Then** unit conversion hints appear
- **Given** a very large number, **When** I type "1e9 km to miles", **Then** scientific notation result appears

### Implementation Notes
- Create UnitConverter service with conversion logic for: Length, Weight, Temperature, Volume, Area, Speed, Time, Data
- Support abbreviations: km, mi, kg, lb, f, c, g, l, gal, mb, gb, etc.
- Copy numeric result to clipboard on selection (with visual feedback)
- Integrate into search flow similar to Calculator (Story 9)
- Use same result display mechanism as Calculator

### Differentiators
- Built-in (not requiring extension installation like Raycast)
- Tight Calculator integration (future: allow calculations with converted values)
- Conversion history (future enhancement)
- Smart abbreviation parsing ("100k" → "100000 km")

---

### [x] Story 10: Quick Emoji Picker

**As a** messaging user who frequently uses emojis
**I want** to search and insert emojis from the command palette
**So that** I can add emojis to my messages faster than using the system emoji picker

### Use Case Context
Part of: "Built-in Tools" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Emoji search should be fast and comprehensive.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I type "smile", **Then** emoji results like 🙂 🙂‍♂️ appear
- **Given** an emoji is selected, **When** I press Enter, **Then** the emoji is pasted into the active application
- **Given** the command palette is open, **When** I type "flag us", **Then** US flag emoji appears
- **Given** I search for an emoji category, **When** I press Enter, **Then** the emoji is inserted

### Implementation Notes
- Use emoji data from Unicode CLDR
- Store recently used emojis for quick access
- Use Accessibility API to insert emoji at cursor position in active app

---

## System Monitoring

### [ ] Story 21: Process Monitoring

**As a** developer and system administrator who needs to monitor system resources
**I want** to see a list of running processes with their memory and CPU usage in the command palette
**So that** I can quickly identify resource-heavy processes without opening Activity Monitor

### Use Case Context
Part of: "System Monitoring" use case
- Follows: "Command Palette Activation" story
- This feature provides quick access to process information as part of the broader "System Integration" capability
- Related: "System Control" story (Story 12) - both provide system-level visibility

### Verification Strategy
Process information must be accurate, updated in real-time, and display without significant performance impact on the system.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I type "processes", **Then** a list of running processes appears with each showing process name, memory usage (MB), and CPU usage (%)
- **Given** the command palette is open, **When** I type "Safari", **Then** only processes matching "Safari" appear with their resource usage
- **Given** process results are displayed, **When** I view each result, **Then** memory is shown in human-readable format (e.g., "256 MB", "1.2 GB")
- **Given** process results are displayed, **When** I view each result, **Then** CPU percentage is shown as a whole number or decimal (e.g., "5%", "12.3%")
- **Given** no processes match the search, **When** I type a non-existent process name, **Then** "No matching processes found" message appears
- **Given** the command palette is open, **When** I press Enter on a process result, **Then** the application comes to the foreground (if it's a user application)
- **Given** the command palette is open with process results, **When** I press Cmd+Enter, **Then** the process is Force Quit (with confirmation for system processes)
- **Given** process list is displayed, **When** I refresh or re-search, **Then** the CPU/memory values are updated to current values
- **Given** many processes are running (100+), **When** I search for processes, **Then** results are limited to top 20-50 by resource usage
- **Given** the command palette is open, **When** I type "processes", **Then** system processes (kernel_task, WindowServer) are included in results

### Implementation Notes
- Use NSWorkspace.shared.runningApplications for basic process information (name, bundle identifier, icon)
- For detailed CPU and memory usage, use libproc (proc_listpids, proc_pidinfo) or sysctl (kern.proc.all)
- Consider using mach_task_info for accurate memory reporting
- Update process data every 2-3 seconds when results are displayed
- Sort results by CPU usage descending by default (or allow sorting options)
- Differentiate between user apps (NSRunningApplication) and system processes
- Consider adding process filtering: show all, user apps only, system processes only
- Privacy consideration: Do not expose processes running in other user's sessions

### Technical Approach Options

**Option A: NSWorkspace (Simpler, Limited)**
- Pros: Simple API, includes app icons automatically
- Cons: Limited to user-facing apps, no CPU/memory by default

**Option B: libproc (Recommended)**
- Pros: Full process list, memory and CPU available, native macOS API
- Cons: Requires more code, need to map PIDs to app names

**Option C: ps aux via Process**
- Pros: Simple to implement, familiar output
- Cons: Spawning processes is slow, not real-time

**Recommended: Option B (libproc)** for best performance and accuracy

---

### [ ] Story 22: Process Force Quit (Two-Phase)

**As a** power user terminating unresponsive applications
**I want** a two-phase kill with visual feedback
**So that** apps get one chance to quit gracefully before force

### Use Case Context
Part of: "System Monitoring" use case
- Follows: "Process Monitoring" story (Story 21)
- Enables quick recovery from frozen applications

### Two-Phase Kill Logic

```
Phase 1 (attemptedKill = false):
  → Cmd+Enter sends SIGTERM (polite quit request)
  → Mark item as attemptedKill = true
  → Show red border decoration

Phase 2 (attemptedKill = true):
  → Cmd+Enter sends SIGKILL (-9) immediate termination
```

### Verification Strategy
Force quit must work reliably with visual feedback for kill state.

#### Test Cases (Acceptance Criteria)
- **Given** a process has NOT been kill-attempted, **When** I press Cmd+Enter, **Then** SIGTERM is sent and item shows red border
- **Given** a process HAS red border (attemptedKill=true), **When** I press Cmd+Enter, **Then** SIGKILL (-9) is sent immediately
- **Given** SIGTERM succeeds, **When** the process exits, **Then** it disappears from the list
- **Given** a system process is selected, **When** I attempt any kill, **Then** a warning appears explaining this may be unsafe
- **Given** kill fails (permission denied), **When** the command executes, **Then** an error message explains why

### Implementation Notes

**Data Model:**
```swift
struct ProcessInfo {
    let pid: Int32
    let name: String
    let cpuUsage: Double
    let memoryMB: Double
    var attemptedKill: Bool = false  // tracks if SIGTERM was already sent
}
```

**Visual Decoration:**
- Red border (2px solid) on items where `attemptedKill = true`

**Kill Logic:**
1. Check `attemptedKill`:
   - If `false` → send SIGTERM, set `attemptedKill = true`, show red border
   - If `true` → send SIGKILL (-9), no grace period
2. For NSRunningApplication: use `terminate()` for phase 1, `forceTerminate()` for phase 2
3. For system processes: use `kill(pid, SIGTERM)` then `kill(pid, SIGKILL)`
- Log kill events for user reference

---

## Advanced Features

### [x] Story 11: Snippets Management

**As a** customer support agent who types the same responses repeatedly
**I want** to create and use text snippets from the command palette
**So that** I can insert pre-written responses quickly without typing them each time

### Use Case Context
Part of: "Built-in Tools" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Snippets should support variables and be easy to create and organize.

#### Test Cases (Acceptance Criteria)
- **Given** a snippet "greeting" with text "Hello {name}, welcome!" is configured, **When** I search for "greeting", **Then** I can select it and a prompt appears for {name} variable
- **Given** a snippet is inserted, **When** the placeholder is filled, **Then** the full text is pasted into the active application
- **Given** I want to create a new snippet, **When** I search for "new snippet", **Then** a snippet creation interface opens

### Implementation Notes
- Store snippets in JSON format in Application Support
- Support variables using {variable_name} syntax
- Provide built-in snippets: current date, current time, email signature

---

### [x] Story 12: System Control

**As a** user who wants to control system settings quickly
**I want** to toggle system features from the command palette
**So that** I can adjust settings without navigating through System Preferences

### Use Case Context
Part of: "System Integration" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
System controls should work reliably and provide feedback.

#### Test Cases (Acceptance Criteria)
- **Given** I search for "Toggle Dark Mode", **When** I select it, **Then** the system appearance switches immediately
- **Given** I search for "Mute", **When** I select it, **Then** system audio mutes/unmutes
- **Given** I search for "Empty Trash", **When** I confirm, **Then** the trash is emptied
- **Given** I search for "Lock Screen", **When** I select it, **Then** the screen locks

### Implementation Notes
- Use NSWorkspace and Process for executing system commands
- Use DistributedNotificationCenter for observing system changes
- Require Accessibility permissions for some controls

---

### [x] Story 13: Quicklinks

**As a** developer who frequently accesses certain URLs
**I want** to create quicklinks for frequently visited websites
**So that** I can open them with one keystroke from the command palette

### Use Case Context
Part of: "Built-in Tools" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Quicklinks should open in the default browser instantly.

#### Test Cases (Acceptance Criteria)
- **Given** a quicklink "Jira" pointing to "https://jira.company.com" is configured, **When** I search for "jira" and select it, **Then** the URL opens in my default browser
- **Given** I want to add a quicklink, **When** I search "add quicklink", **Then** a prompt appears to enter name and URL
- **Given** a quicklink with a keyboard shortcut is configured, **When** I press the shortcut, **Then** the URL opens even if the palette is closed

### Implementation Notes
- Store quicklinks in Application Support directory
- Support custom icons (fetch from favicon)
- Support keyboard shortcuts per quicklink

---

### [x] Story 14: Reminders Integration

**As a** busy professional who uses Reminders app
**I want** to view and add reminders from the command palette
**So that** I can manage my tasks without switching to the Reminders app

### Use Case Context
Part of: "Built-in Tools" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Must sync bidirectionally with Apple Reminders.

#### Test Cases (Acceptance Criteria)
- **Given** I have reminders in Reminders app, **When** I search "remind", **Then** my upcoming reminders appear
- **Given** I want to add a reminder, **When** I search "remind me to call mom at 5pm", **Then** a reminder is created in Reminders app
- **Given** a reminder is selected, **When** I press Enter, **Then** it is marked as completed in Reminders

### Implementation Notes
- Use EventKit framework to access Reminders
- Request Reminders access permission on first use
- Support natural language parsing for dates/times

---

### [x] Story 15: Notes Integration

**As a** writer who takes quick notes throughout the day
**I want** to view and create notes from the command palette
**So that** I can capture thoughts without opening the Notes app

### Use Case Context
Part of: "Built-in Tools" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Must sync with Apple Notes and support basic note operations.

#### Test Cases (Acceptance Criteria)
- **Given** I have notes in Notes app, **When** I search "note", **Then** my recent notes appear
- **Given** I want to create a note, **When** I search "new note: Meeting notes", **Then** a note titled "Meeting notes" is created
- **Given** a note is selected, **When** I press Enter, **Then** the note opens in Notes app

### Implementation Notes
- Use EventKit framework to access Notes
- Request Notes access permission on first use
- Display note preview in search results (first line)

---

### [x] Story 16: Focus Mode Control

**As a** knowledge worker who needs to concentrate
**I want** to control Focus modes from the command palette
**So that** I can switch between work and personal modes quickly

### Use Case Context
Part of: "System Integration" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Focus modes should toggle correctly and sync with System Settings.

#### Test Cases (Acceptance Criteria)
- **Given** I search for "Focus: Do Not Disturb", **When** I select it, **Then** DND mode activates
- **Given** Focus mode is active, **When** I search for "Turn Off Focus", **Then** all Focus modes are disabled
- **Given** I search for "Focus: Work", **When** I select it, **Then** the Work Focus mode activates

### Implementation Notes
- Use FocusMode iOS/macOS API (macOS 12+)
- Observe Focus changes via DistributedNotificationCenter
- Display current Focus status in menu bar

---

### [x] Story 17: Extensions Framework

**As a** developer who wants to extend Zest functionality
**I want** to create and install extensions
**So that** I can add custom commands and integrations

### Use Case Context
Part of: "Extensibility" use case
- Follows: Foundation features (independent)

### Verification Strategy
Extensions should be isolated, secure, and easy to install.

#### Test Cases (Acceptance Criteria)
- **Given** I have an extension bundle, **When** I install it, **Then** it appears in the command palette
- **Given** an extension has an error, **When** it loads, **Then** it fails gracefully with an error message (no crash)
- **Given** an extension is installed, **When** I uninstall it, **Then** all its commands are removed from the palette

### Implementation Notes
- Use plug-in architecture with NSBundle
- Define extension protocol for commands, search providers
- Sandboxed extensions with limited permissions

---

### [x] Story 18: Menu Bar Presence

**As a** macOS user who wants quick access to app controls
**I want** to see Zest in the menu bar with quick actions
**So that** I can access features even when the palette is closed

### Use Case Context
Part of: "System Integration" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Menu bar icon should always be visible and responsive.

#### Test Cases (Acceptance Criteria)
- **Given** Zest is running, **When** I look at the menu bar, **Then** the Zest icon is visible
- **Given** I click the menu bar icon, **When** I select "Preferences", **Then** the preferences window opens
- **Given** I click the menu bar icon, **When** I select "Quit Zest", **Then** the application quits
- **Given** the palette is closed, **When** I click the menu bar icon, **Then** the command palette opens

### Implementation Notes
- Use NSStatusItem for menu bar presence
- Provide menu with: Recent Items, Preferences, Quit
- Consider showing current Focus status in menu bar

---

### [ ] Story 19: Preferences Window

**As a** power user who wants to customize Zest behavior
**I want** to configure settings through a preferences window
**So that** I can personalize the app to fit my workflow

### Use Case Context
Part of: "Configuration" use case
- Follows: "Menu Bar Presence" story

### Verification Strategy
Preferences should persist correctly and apply immediately.

#### Test Cases (Acceptance Criteria)
- **Given** the preferences window is open, **When** I change the global hotkey, **Then** the new hotkey works immediately
- **Given** the preferences window is open, **When** I toggle "Launch at Login", **Then** Zest launches automatically on system startup
- **Given** the preferences window is open, **When** I change "Search Results Limit", **Then** the palette shows the new number of results
- **Given** dark mode is enabled, **When** I open preferences, **Then** the window appears in dark mode

### Implementation Notes
- Use SwiftUI for preferences window
- Store preferences in UserDefaults
- Follow macOS Settings design guidelines
- Tabs: General, Appearance, Shortcuts, Extensions, Privacy

---

### [x] Story 20: Launch at Login

**As a** user who wants Zest always available
**I want** Zest to launch automatically when I log in
**So that** I don't have to manually start it each time

### Use Case Context
Part of: "Configuration" use case
- Follows: "Preferences Window" story

### Verification Strategy
Launch at login should work correctly across system restarts.

#### Test Cases (Acceptance Criteria)
- **Given** "Launch at Login" is enabled in preferences, **When** I restart my Mac, **Then** Zest appears in the menu bar
- **Given** "Launch at Login" is disabled, **When** I restart, **Then** Zest does not start automatically

### Implementation Notes
- Use SMAppService (macOS 13+) or LSSharedFileList for login item management
- Handle permission requests gracefully

---

### Implementation Notes

## Story Dependencies Summary

```
Command Palette Activation (Foundation)
├── Full Keyboard Navigation (KB-1) [Cross-cutting]
├── Fuzzy Search Across Applications
│   └── Application Launch Execution
├── Window Management
│   ├── Window Tiling
│   └── Window Movement and Resize
├── Built-in Tools
│   ├── Calculator Function
│   ├── Unit Conversion Function
│   ├── Quick Emoji Picker
│   ├── Snippets Management
│   ├── Quicklinks
│   ├── Reminders Integration
│   └── Notes Integration
├── Clipboard Management
│   └── Clipboard History Access
├── Automation
│   └── Script Command Execution
├── Find Files
│   └── File Search
├── System Integration
│   ├── System Control
│   ├── Focus Mode Control
│   └── Menu Bar Presence
├── System Monitoring
│   ├── Process Monitoring
│   └── Process Force Quit
├── Configuration
│   ├── Preferences Window
│   └── Launch at Login
└── Extensibility
    └── Extensions Framework
```

---

## Priority Order

### Phase 1: Foundation (Stories 1-5)
Command palette is the core of the entire application. Without it, nothing else works.

### Phase 2: Core Features (Stories 6-10)
Clipboard, scripts, file search, calculator, and emoji picker provide high-value daily utilities.

### Phase 3: System Monitoring (Stories 21-22)
Process monitoring and force quit provide system visibility - valuable for power users.

### Phase 4: Advanced Features (Stories 11-21)
Snippets, system controls, integrations, extensions, and AI add depth but require foundation first.

---

## Quality Assurance

The following stories define the code quality pipeline for Zest, ensuring consistent code style, early bug detection, and measurable quality metrics.

### Mandatory Timeout Rule

**ALWAYS use a 40-second timeout** when running tests or executing commands that could hang. See [TDD_GUIDELINES.md](docs/TDD_GUIDELINES.md) for details.

- Use `./scripts/run_tests.sh` (defaults to 40s)
- Use `perl -e 'alarm 40; exec @ARGV' <command>` for ad-hoc execution
- This prevents infinite loops, SwiftPM locks, and mdfind hangs

### Use Case Context
Part of: CI/CD Pipeline
- Precedes: All feature development stories
- These stories ensure code quality before merging

---

### [x] Story QA-1: Code Formatting with SwiftFormat

**As a** Swift developer contributing to Zest
**I want** all code to be automatically formatted before commits
**So that** the codebase maintains consistent style without manual formatting discussions

### Use Case Context
Part of: "Quality Assurance" use case
- Foundation for all other QA stories
- Runs in CI pipeline and locally

### Verification Strategy
SwiftFormat must run successfully on all Swift files and produce consistent output.

#### Test Cases (Acceptance Criteria)
- **Given** SwiftFormat is installed via Homebrew, **When** I run `./scripts/quality.sh`, **Then** the format step completes without errors
- **Given** a Swift file with inconsistent indentation, **When** SwiftFormat runs, **Then** the file is corrected to match project rules
- **Given** SwiftFormat is not installed, **When** quality.sh runs, **Then** it shows a warning with installation instructions
- **Given** the project builds successfully, **When** I run SwiftFormat, **Then** no files are modified (already formatted)

### Implementation Notes
- Use SwiftFormat with configuration file (.swiftformat) in project root
- Configure: 4-space indent, trim trailing whitespace, organize imports
- Add as pre-commit hook or CI step

---

### [x] Story QA-2: Linting with SwiftLint

**As a** code reviewer who wants to catch issues before review
**I want** SwiftLint to enforce coding standards automatically
**So that** common mistakes are caught early and code is more consistent

### Use Case Context
Part of: "Quality Assurance" use case
- Follows: "Code Formatting with SwiftFormat" story

### Verification Strategy
SwiftLint must detect and report code issues while allowing build to complete.

#### Test Cases (Acceptance Criteria)
- **Given** SwiftLint is configured with project rules, **When** I run `./scripts/quality.sh`, **Then** lint results are displayed with clear pass/fail status
- **Given** SwiftLint finds errors, **When** the script runs, **Then** it exits with non-zero status code
- **Given** SwiftLint is not installed, **When** quality.sh runs, **Then** it shows a warning with installation instructions
- **Given** a file with a long function (>50 lines), **When** SwiftLint runs, **Then** it warns about function length
- **Given** a file with missing return in guard statement, **When** SwiftLint runs, **Then** it reports the control flow warning

### Implementation Notes
- Create .swiftlint.yml configuration file
- Enable rules: trailing_whitespace, line_length, function_body_length
- Configure severity levels (error vs warning)
- Consider disabling overly strict rules for MVP

---

### [x] Story QA-3: Static Analysis - Unused Code Detection

**As a** maintainer who wants to keep the codebase clean
**I want** to detect unused code (functions, variables, imports)
**So that** dead code is removed and the codebase stays lean

### Use Case Context
Part of: "Static Analysis" use case
- Follows: "Linting with SwiftLint" story

### Verification Strategy
Unused code must be detected and reported as warnings or errors.

#### Test Cases (Acceptance Criteria)
- **Given** an unused variable `let unusedVar = 5`, **When** SwiftLint runs, **Then** it reports "unused variable" warning
- **Given** an unused function `func unusedFunc() {}`, **When** SwiftLint runs, **Then** it reports "unused function" warning
- **Given** an unused import `import Foundation` (not used), **When** SwiftLint runs, **Then** it reports "unused import" warning
- **Given** a private function that is never called, **When** static analysis runs, **Then** it is flagged as potentially unused

### Implementation Notes
- Use SwiftLint rules: unused_declaration, unused_import
- Consider using Swift's built-in -unused-clang-error flag
- Create cleanup scripts to auto-remove flagged code

---

### [x] Story QA-4: Static Analysis - Code Complexity

**As a** code reviewer who wants to prevent overly complex code
**I want** to measure and limit cyclomatic complexity
**So that** code remains readable and maintainable

### Use Case Context
Part of: "Static Analysis" use case
- Follows: "Unused Code Detection" story

### Verification Strategy
Complex code must be flagged for refactoring before it becomes technical debt.

#### Test Cases (Acceptance Criteria)
- **Given** a function with 10+ if/else branches, **When** SwiftLint runs, **Then** it warns about high cyclomatic complexity
- **Given** a function with nested closures (3+ levels), **When** SwiftLint runs, **Then** it warns about nesting depth
- **Given** a switch statement with 15+ cases, **When** SwiftLint runs, **Then** it warns about complex switch
- **Given** code within threshold limits, **When** SwiftLint runs, **Then** no complexity warnings are shown

### Implementation Notes
- Configure SwiftLint: cyclomatic_complexity, nesting
- Set reasonable thresholds: complexity < 10, nesting < 3
- Document complexity limits in CONTRIBUTING.md

---

### [x] Story QA-5: Static Analysis - Function Size Warnings

**As a** developer who wants to write maintainable code
**I want** warnings when functions grow too large
**So that** I split them into smaller, testable units

### Use Case Context
Part of: "Static Analysis" use case
- Follows: "Code Complexity" story

### Verification Strategy
Large functions must trigger warnings to encourage refactoring.

#### Test Cases (Acceptance Criteria)
- **Given** a function with 60 lines of code, **When** SwiftLint runs, **Then** it warns about function length
- **Given** a function with 100+ lines, **When** SwiftLint runs, **Then** it reports an error (not just warning)
- **Given** a function under the threshold, **When** SwiftLint runs, **Then** no warning is shown
- **Given** a file with multiple long functions, **When** SwiftLint runs, **Then** each function is flagged individually

### Implementation Notes
- Configure function_body_length rule in SwiftLint
- Set warning at 50 lines, error at 100 lines
- Encourage use of @MainActor and async/await to simplify code

---

### [x] Story QA-6: Static Analysis - Naming Conventions

**As a** developer who values readable code
**I want** naming convention checks
**So that** the codebase follows Swift API design guidelines

### Use Case Context
Part of: "Static Analysis" use case
- Follows: "Function Size Warnings" story

### Verification Strategy
Naming violations must be detected and reported consistently.

#### Test Cases (Acceptance Criteria)
- **Given** a variable `let myVar = 5` (camelCase), **When** SwiftLint runs, **Then** it passes naming check
- **Given** a constant `let MyConstant = 5` (PascalCase), **When** SwiftLint runs, **Then** it warns about constant naming
- **Given** a function `func doStuff()` (verb), **When** SwiftLint runs, **Then** it passes
- **Given** a function `func check()` (noun), **When** SwiftLint runs, **Then** it warns about function naming
- **Given** a class with single-letter name `class A {}`, **When** SwiftLint runs, **Then** it warns about type name length

### Implementation Notes
- Use SwiftLint: type_name, variable_name rules
- Enforce: camelCase for variables, PascalCase for types
- Set minimum type name length to 3 characters

---

### [x] Story QA-7: Static Analysis - Security Issues

**As a** security-conscious developer
**I want** to detect potential security vulnerabilities
**So that** the app doesn't have common security flaws

### Use Case Context
Part of: "Static Analysis" use case
- Follows: "Naming Conventions" story

### Verification Strategy
Security issues must be flagged as errors to prevent dangerous code from merging.

#### Test Cases (Acceptance Criteria)
- **Given** hardcoded credentials `let password = "secret"`, **When** SwiftLint runs, **Then** it warns about hardcoded strings
- **Given** use of `printf` or `NSLog` with user input, **When** SwiftLint runs, **Then** it warns about potential injection
- **Given** disabled SSL validation `URLSession(configuration: .default)`, **When** SwiftLint runs, **Then** it warns about insecure configuration
- **Given** use of `Process()` with shell commands, **When** SwiftLint runs, **Then** it flags potential shell injection risks

### Implementation Notes
- Use SwiftLint: force_try, explicitly_unwrapped_optional
- Consider additional rules: no-hardcoded-strings (with调味)
- Document security requirements in CONTRIBUTING.md

---

### [x] Story QA-8: Test Coverage Measurement

**As a** developer who wants to ensure code quality
**I want** to measure test coverage percentage
**So that** I know how much code is actually tested

### Use Case Context
Part of: "Quality Assurance" use case
- Follows: "Linting with SwiftLint" story

### Verification Strategy
Coverage must be measurable and reportable in CI.

#### Test Cases (Acceptance Criteria)
- **Given** tests are run with coverage enabled, **When** I execute `./scripts/quality.sh`, **Then** a coverage percentage is displayed
- **Given** there are no tests, **When** coverage is measured, **Then** it reports 0% with a warning
- **Given** coverage is below 50%, **When** quality.sh runs, **Then** it warns about low coverage
- **Given** a file has 10 lines and 8 are covered by tests, **When** coverage is measured, **Then** that file shows 80% coverage
- **Given** Xcode is installed, **When** I run tests with coverage, **Then** I can view detailed line-by-line coverage in Xcode

### Implementation Notes
- Use Swift's built-in code coverage (xccov)
- Run with: swift test --enable-code-coverage
- Generate coverage reports in CI
- Set initial target: 60% coverage

---

### [x] Story QA-9: Performance Profiling - Metrics Collection

**As a** developer optimizing app performance
**I want** to collect performance metrics automatically
**So that** I can identify bottlenecks and track improvements

### Use Case Context
Part of: "Performance" use case
- Follows: "Test Coverage Measurement" story

### Verification Strategy
Performance metrics must be measurable and reproducible.

#### Test Cases (Acceptance Criteria)
- **Given** I run the app, **When** profiling is enabled, **Then** execution time is recorded
- **Given** I search for an item, **When** profiling runs, **Then** search latency is measured in milliseconds
- **Given** the app launches, **When** I measure startup time, **Then** I get a reproducible startup duration
- **Given** I run memory profiling, **When** the app is idle, **Then** baseline memory usage is recorded

### Implementation Notes
- Use Instruments (Time Profiler, Allocations) for detailed analysis
- Add custom metrics in code using os_signpost
- Create benchmark tests for critical paths
- Document performance targets in PERFORMANCE.md

---

### [ ] Story QA-10: Performance Profiling

**As a** developer who monitors app performance
**I want** to measure and track performance metrics locally
**So that** I can identify and fix performance regressions

### Use Case Context
Part of: "Performance" use case
- Follows: "Metrics Collection" story (QA-9)

### Verification Strategy
Performance metrics must be measurable and show meaningful data.

#### Test Cases (Acceptance Criteria)
- **Given** the app launches, **When** I measure startup time, **Then** I can see the result in logs
- **Given** search executes, **When** I measure search time, **Then** metrics are collected and stored
- **Given** I run performance tests, **When** they complete, **Then** I can see timing for each operation

### Implementation Notes
- Use os_signpost or CFAbsoluteTime for timing measurements
- Create benchmark tests using XCBenchmark or custom timing
- Store results locally for comparison
- Set performance targets: startup < 1s, search < 100ms

---

## QA Pipeline Summary

```
Quality Assurance Pipeline
├── Formatting (Story QA-1)
│   └── SwiftFormat
├── Linting (Story QA-2)
│   └── SwiftLint (basic)
├── Static Analysis (Stories QA-3 to QA-7)
│   ├── Unused Code (QA-3)
│   ├── Complexity (QA-4)
│   ├── Function Size (QA-5)
│   ├── Naming Conventions (QA-6)
│   └── Security (QA-7)
├── Test Coverage (Story QA-8)
│   └── xccov
└── Performance (Stories QA-9 to QA-10)
    ├── Metrics Collection (QA-9)
    └── Performance Profiling (QA-10)
```

---

## Infrastructure Improvements (Completed Stories)

These stories address learnings from retrospections and improve development workflow.

### [x] Story INF-1: TDD Workflow Documentation and Enforcement

**As a** developer contributing to Zest
**I want** clear TDD guidelines and enforcement mechanisms
**So that** all code follows the RED -> GREEN -> REFACTOR pattern

### Use Case Context
Part of: "Quality Assurance" use case
- Follows: "Linting with SwiftLint" story
- Enables: All future feature development

### Verification Strategy
TDD workflow must be enforced through automated checks.

#### Test Cases (Acceptance Criteria)
- **Given** a developer runs `./scripts/quality.sh`, **When** coverage is below 50%, **Then** the build fails with TDD error message
- **Given** TDD_GUIDELINES.md exists, **When** a new developer reads it, **Then** they understand the RED -> GREEN -> REFACTOR cycle
- **Given** tests are run, **When** any test fails, **Then** implementation is not considered complete

### Implementation Notes
- Created docs/TDD_GUIDELINES.md with timeout and workflow rules
- Added coverage gate in quality.sh (50% minimum)
- Error message: "TDD Workflow: Write failing test FIRST, then implement"

---

### [x] Story INF-2: Test Timeout Infrastructure

**As a** developer running tests
**I want** tests to automatically timeout after 40 seconds
**So that** infinite loops or hangs don't freeze development

### Use Case Context
Part of: "Quality Assurance" use case
- Follows: "TDD Workflow Documentation" story

### Verification Strategy
Timeout must work reliably and prevent all hangs.

#### Test Cases (Acceptance Criteria)
- **Given** a test runs longer than 40 seconds, **When** the timeout triggers, **Then** the test is killed with exit code 124
- **Given** `./scripts/run_tests.sh` is run, **When** tests complete in under 40 seconds, **Then** results are displayed normally
- **Given** the perl alarm pattern is used, **When** timeout occurs, **Then** SIGTERM is sent first, then SIGKILL

### Implementation Notes
- Created scripts/run_tests.sh with 40s default timeout
- Uses perl fork-based alarm pattern for reliable timeout
- Kills stale SwiftPM processes before each run

---

### [x] Story INF-3: mdfind Performance Safeguards

**As a** user searching for files
**I want** file search to never hang or return too many results
**So that** the app remains responsive

### Use Case Context
Part of: "Find Files" use case
- Related to: "File Search" story (Story 8)

### Verification Strategy
File search must be bounded and safe.

#### Test Cases (Acceptance Criteria)
- **Given** mdfind is invoked, **When** query is a common character like "a", **Then** only 20 results are returned (not thousands)
- **Given** the -limit flag is used, **When** mdfind runs, **Then** results are capped at the specified limit
- **Given** a search runs, **When** results exceed the limit, **Then** additional filtering is applied in code

### Implementation Notes
- Added `-limit 20` to mdfind arguments in FileSearchService.swift
- Additional `.prefix(maxResults)` filtering in code
- Privacy filtering excludes hidden directories (.ssh, .cache, .local, etc.)

---

### [x] Story INF-4: Coverage Gate Enforcement

**As a** project maintainer ensuring code quality
**I want** a minimum coverage threshold enforced automatically
**So that** TDD is followed and code is properly tested

### Use Case Context
Part of: "Quality Assurance" use case
- Follows: "Test Coverage Measurement" story

### Verification Strategy
Coverage must be measured and enforced in CI.

#### Test Cases (Acceptance Criteria)
- **Given** coverage is measured, **When** percentage is below 50%, **Then** quality.sh exits with failure
- **Given** coverage is 50% or higher, **When** quality.sh runs, **Then** build passes
- **Given** llvm-profdata is used, **When** coverage runs, **Then** accurate percentage is calculated

### Implementation Notes
- Minimum threshold: 50%
- Uses xcrun llvm-profdata for reliable coverage
- quality.sh fails with "COVERAGE GATE FAILED" message

---

### [x] Story INF-5: SwiftPM Lock Recovery Automation

**As a** developer building or testing
**I want** stale SwiftPM processes and locks to be automatically cleaned
**So that** builds don't fail due to lock contention

### Use Case Context
Part of: "Quality Assurance" use case
- Precedes: All build and test operations

### Verification Strategy
Lock recovery must happen automatically before each operation.

#### Test Cases (Acceptance Criteria)
- **Given** a stale swift process exists, **When** run_tests.sh runs, **Then** it is killed before tests start
- **Given** a package lock file exists, **When** cleanup runs, **Then** it is removed
- **Given** locks are cleaned, **When** swift test runs, **Then** it completes without lock errors

### Implementation Notes
- pkill -9 -f "swift" in run_tests.sh before tests
- rm -f .build/.package-lock cleanup
- Both run_tests.sh and quality.sh include automatic cleanup

---

## Technical Debt Items (Implemented)

These items were identified in retrospections and have been implemented.

### DEBT-1: HTML Coverage Reports

**Status:** Implemented
**Location:** scripts/quality.sh (generate_coverage_report function)
**Description:** Enhanced quality.sh to generate HTML coverage reports using llvm-profdata
**Verification:** Run `./scripts/quality.sh` to generate reports in .build/coverage/

---

### DEBT-2: Spotlight Index Health Diagnostic

**Status:** Implemented
**Location:** scripts/diagnose_spotlight.sh
**Description:** Diagnostic script to check Spotlight index health and re-index directories
**Verification:** Run `./scripts/diagnose_spotlight.sh` to check index status

---

### DEBT-3: Search Latency Benchmarks

**Status:** Implemented
**Location:** Tests/SearchLatencyBenchmarkTests.swift
**Description:** Performance benchmark tests for search operations ensuring <100ms latency
**Verification:** Run `swift test` to verify benchmarks pass within 40s timeout

---

## QA Infrastructure Improvements (From Test Automation Review)

### QA-INF-1: Fix SwiftLint Errors

**As a** developer wanting clean code
**I want** SwiftLint errors fixed
**So that** the quality pipeline passes

### Use Case Context
Part of: "Quality Assurance" use case
- Related to: Story QA-2 (Linting with SwiftLint)

### Test Cases
- **Given** SwiftLint runs on Sources, **When** there are force_cast errors, **Then** they should be fixed with safe unwrapping
- **Given** SwiftLint runs, **When** there are identifier_name errors for x/y variables, **Then** they should be renamed to descriptive names
- **Given** SwiftLint runs, **When** type_body_length exceeds limit, **Then** EmojiSearchService should be split into smaller types

### Implementation Notes
- Fix 6 force_cast errors in WindowManager.swift and AppDelegate.swift
- Rename x/y variables to more descriptive names (posX, posY, or originX, originY)
- Split EmojiSearchService.swift (646 lines) into smaller focused types

---

### QA-INF-2: Increase Test Timeout

**As a** developer running full test suite
**I want** tests to complete without timeout
**So that** coverage can be measured

### Use Case Context
Part of: "Quality Assurance" use case
- Related to: Story INF-2 (Test Timeout Infrastructure)

### Test Cases
- **Given** the test timeout is 40 seconds, **When** full suite runs, **Then** it should complete without timeout
- **Given** mdfind is called in tests, **When** queries run, **Then** they should be mocked or cached

### Implementation Notes
- Increase TEST_TIMEOUT in scripts/run_tests.sh to 90 seconds
- Or optimize tests to reduce mdfind calls (mock Spotlight in tests)
- Consider using @Test(focused) to run subset of tests during development

---

### QA-INF-3: Enable Advanced SwiftLint Rules

**As a** project maintainer wanting comprehensive analysis
**I want** advanced static analysis enabled
**So that** code quality is improved

### Use Case Context
Part of: "Static Analysis" use case

### Test Cases
- **Given** analyzer_rules includes unused_declaration, **When** unused code exists, **Then** it should be flagged
- **Given** cyclomatic_complexity is enabled, **When** complex code exists, **Then** it should warn

### Implementation Notes
- Add analyzer_rules section to .swiftlint.yml with unused_declaration
- Add cyclomatic_complexity to opt_in_rules with threshold of 10
- Consider adding security-related rules

---

### QA-INF-4: Run SwiftFormat on All Files

**As a** developer wanting consistent formatting
**I want** all files to be formatted
**So that** code style is uniform

### Use Case Context
Part of: Story QA-1 (Code Formatting with SwiftFormat)

### Test Cases
- **Given** SwiftFormat runs on Sources, **When** files are checked, **Then** no files should be modified (already formatted)

### Implementation Notes
- Run `swiftformat Sources` to format remaining 8 files
- Add SwiftFormat check to pre-commit hook
- Consider enabling SwiftFormat in CI pipeline

---

### QA-INF-5: Measure Code Coverage

**As a** developer wanting to track test quality
**I want** coverage reports to be generated
**So that** I can see test effectiveness

### Use Case Context
Part of: Story QA-8 (Test Coverage Measurement)

### Test Cases
- **Given** tests run with coverage, **When** they complete, **Then** coverage percentage should be displayed
- **Given** coverage is above 50%, **When** quality.sh runs, **Then** it should pass

### Implementation Notes
- First fix test timeout issue (QA-INF-2)
- Then verify coverage measurement works
- Target: 60% coverage (currently 50% minimum)

---

## Keyboard Navigation (Accessibility)

### [x] Story KB-1: Full Keyboard Navigation

**As a** power user who keeps hands on the keyboard at all times
**I want** to operate Zest entirely without a mouse
**So that** I can maintain my workflow efficiency and accessibility

### Use Case Context
Part of: "Accessibility" use case
- Foundation for all interaction with the command palette
- This is a cross-cutting concern that affects every feature

### Verification Strategy
Keyboard navigation must work consistently across all features without requiring a mouse.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I type a search query, **Then** I can navigate results with Up/Down arrows
- **Given** search results are displayed, **When** I press Enter, **Then** the selected item is activated
- **Given** the command palette is open, **When** I press Tab, **Then** focus moves to the next interactive element
- **Given** multiple results exist, **When** I press Cmd+1 through Cmd+9, **Then** the corresponding result is selected
- **Given** the command palette is open, **When** I press Escape, **Then** the palette closes

### Implementation Notes
- Ensure all UI elements are keyboard-accessible
- Support standard macOS keyboard navigation patterns
- Add keyboard shortcut hints in the UI

---

## Community-Requested Features

These stories are based on popular feature requests from Raycast forum, Raycast Store analytics, and launcher app communities. Focus on high-value, non-AI features that complement existing Zest capabilities.

---

### [x] Story 24: Color Picker

**As a** designer and developer who frequently works with colors
**I want** to pick colors from anywhere on screen and convert between color formats
**So that** I can quickly capture and use colors in my designs and code

### Use Case Context
Part of: "Built-in Tools" use case
- Similar to: Raycast Color Picker (365,990+ installs)
- Complements: Calculator and other quick utilities

### Verification Strategy
Color picker must work with any on-screen content and provide accurate color values in multiple formats.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I search for "color picker", **Then** a color picker tool appears
- **Given** the color picker is active, **When** I click anywhere on screen, **Then** the color under cursor is captured
- **Given** a color is captured, **When** I view the result, **Then** it shows HEX, RGB, and HSL formats
- **Given** a color is captured, **When** I press Enter, **Then** the HEX value is copied to clipboard
- **Given** the color picker is open, **When** I press Cmd+C, **Then** the color is copied in the currently displayed format
- **Given** colors are picked, **When** I view color history, **Then** recently picked colors appear for quick access

### Implementation Notes
- Use NSColorSampler (macOS 14+) or NSColorPanel for color picking
- Support formats: HEX (#RRGGBB), RGB (255, 255, 255), HSL, NSColor, UIColor
- Store color history in UserDefaults (last 20 colors)
- Consider integration with Apple Color Picker

---

### [ ] Story 25: Translation Tool

**As a** multilingual user who frequently translates text
**I want** to quickly translate text between languages from the command palette
**So that** I can communicate effectively without opening a browser or separate app

### Use Case Context
Part of: "Built-in Tools" use case
- Similar to: Raycast Google Translate (345,652+ installs)
- Integrates with: Clipboard history for translating copied text

### Verification Strategy
Translation must be fast and support common language pairs.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I type "translate hello to spanish", **Then** "hola" appears as result
- **Given** the command palette is open, **When** I type "traduire bonjour en anglais", **Then** "translate bonjour to english" is understood
- **Given** text is in clipboard, **When** I search "translate clipboard", **Then** the clipboard text is translated
- **Given** a translation result, **When** I press Enter, **Then** the translation is copied to clipboard
- **Given** translation settings, **When** I set default target language to Spanish, **Then** future translations default to Spanish
- **Given** an unsupported language, **When** I try to translate, **Then** a helpful error message appears

### Implementation Notes
- Use free translation APIs (LibreTranslate, MyMemory) or macOS built-in Translation framework
- Support auto-detection of source language
- Cache recent translations for offline access
- Language code support: en, es, fr, de, it, pt, zh, ja, ko, ru, ar

---

### [x] Story 26: Calendar Integration

**As a** remote worker with many meetings
**I want** to instantly join my next meeting and see my meeting schedule at a glance
**So that** I save time and never miss or double-book meetings

### Use Case Context
Part of: "Productivity" use case
- Similar to: Raycast Calendar extension (240,000+ active users)
- **WOW Factor**: "Join Next Meeting" one-command access + meeting insights

### 🌟 WOW Features (Differentiators)

#### 1. "Join Next Meeting" - One Command (⭐ PRIMARY WOW)
```
Cmd+Space → "join" → Enter → Boom, you're in the meeting
```
- Detects your next meeting with a video link
- Works with: Zoom, Google Meet, Microsoft Teams, WebEx, Slack huddles
- Shows countdown: "Next meeting in 12 min: Team Standup"
- **Saves 30+ seconds × 8 meetings/day = 4 min/day saved**

#### 2. Meeting Insights - Know Your Day
```
Cmd+Space → "meetings today"
```
Shows:
- "3 meetings today (4.5 hours)"
- "Next free slot: 3:00 PM - 5:00 PM"
- "Heaviest day this week: Thursday (6 meetings)"

#### 3. Always Show Active/Recent Meetings
- Show meetings currently in progress (🔴 LIVE indicator)
- Show meetings that ended in the last 60 minutes
- Helps you quickly rejoin if you stepped out
- Shows "Ended 15 min ago" for recent meetings

#### 4. Quick Schedule - Natural Language
```
"Schedule 30min sync with Sarah tomorrow 3pm"
```
Creates event + (optional) sends invite

### Verification Strategy
Calendar must sync with macOS Calendar and support common conferencing platforms.

#### Test Cases (Acceptance Criteria)

**Basic Calendar Access:**
- **Given** the command palette is open, **When** I search for "calendar" or "schedule", **Then** my upcoming events appear
- **Given** calendar events are displayed, **When** I view the list, **Then** events show title, time, and location
- **Given** no calendar access, **When** I try to use calendar features, **Then** a permission request appears

**Join Next Meeting (WOW):**
- **Given** I have a meeting with a video link in 5 minutes, **When** I search "join", **Then** "Join: Team Standup (in 5 min)" appears as top result
- **Given** I search "join" and press Enter, **When** the meeting has a Zoom link, **Then** Zoom opens and joins the meeting
- **Given** I search "join", **When** there's no upcoming video meeting, **Then** "No upcoming meetings with video links" is shown
- **Given** multiple video meetings exist, **When** I search "join", **Then** the next one chronologically is shown

**Active/Recent Meetings:**
- **Given** a meeting is currently in progress (now is between start and end time), **When** I search "calendar", **Then** the meeting shows with "🔴 IN PROGRESS" indicator
- **Given** a meeting ended 30 minutes ago, **When** I search "calendar", **Then** the meeting appears with "Ended 30 min ago"
- **Given** a meeting ended 2 hours ago, **When** I search "calendar", **Then** the meeting does NOT appear (only show last 60 min)
- **Given** an in-progress meeting has a video link, **When** I press Enter, **Then** I can rejoin the meeting

**Meeting Insights:**
- **Given** I search "meetings today", **When** results appear, **Then** I see total meeting count and hours
- **Given** I search "meetings today", **When** results appear, **Then** I see my next free time slot (minimum 30 min gap)
- **Given** I search "free slot" or "when am I free", **Then** my next available 30+ minute gap is shown

**Video Link Detection:**
- **Given** an event contains "zoom.us/j/", **When** displayed, **Then** it's recognized as a Zoom meeting
- **Given** an event contains "meet.google.com/", **When** displayed, **Then** it's recognized as Google Meet
- **Given** an event contains "teams.microsoft.com/", **When** displayed, **Then** it's recognized as Microsoft Teams
- **Given** an event contains "webex.com/", **When** displayed, **Then** it's recognized as WebEx

**Calendar Actions:**
- **Given** an event with a Zoom/Meet/Teams link, **When** I press Enter, **Then** the meeting opens in the appropriate app
- **Given** calendar events are displayed, **When** I press Cmd+Enter, **Then** the event opens in Calendar app
- **Given** an event is selected, **When** I press Cmd+C, **Then** the meeting link is copied to clipboard

### Implementation Notes

**Files to Create:**
```
Sources/Services/CalendarService.swift
├── getUpcomingEvents(days: 7)           // Events for next 7 days
├── getNextMeetingWithLink()             // Find next video meeting
├── getActiveMeetings()                  // Meetings in progress
├── getRecentMeetings(within: 60min)     // Meetings that ended recently
├── joinMeeting(url: URL)                // Open Zoom/Meet/Teams
├── getTodayInsights()                   // Meeting count, hours, free slots
├── findNextFreeSlot(duration: 30min)    // Find gaps in calendar
├── parseVideoLink(event: EKEvent)       // Extract URLs
├── getSupportedPlatforms()              // Zoom, Meet, Teams, WebEx, Slack
└── createQuickEvent(text: String)       // Natural language parsing (optional)
```

**Video Platform URL Patterns:**
- Zoom: `zoom.us/j/`, `zoom.us/s/`, `zoom.us/w/`
- Google Meet: `meet.google.com/`
- Microsoft Teams: `teams.microsoft.com/l/meetup-join/`, `teams.live.com/`
- WebEx: `webex.com/meet/`, `.webex.com/`
- Slack: `slack.com/call/`, `app.slack.com/client/`

**Technology:**
- Use EventKit framework to access Calendar
- Request Calendar access permission on first use
- Cache events for 30 seconds to reduce API calls
- Support multiple calendars (work, personal) with filtering

### Differentiators from Other Launchers
| Feature | Zest | Raycast | Alfred |
|---------|------|---------|--------|
| "Join" one-command | ✅ | ❌ (requires navigation) | ❌ |
| Active meeting indicator | ✅ | ❌ | ❌ |
| Recent meetings (60 min) | ✅ | ❌ | ❌ |
| Meeting insights | ✅ | Partial | ❌ |
| Free slot finder | ✅ | ❌ | ❌ |

---

### [ ] Story 27: Homebrew Integration

**As a** developer who uses Homebrew to manage packages
**I want** to search and install Homebrew formulae from the command palette
**So that** I can discover and install packages without opening Terminal

### Use Case Context
Part of: "Developer Tools" use case
- Similar to: Raycast Brew extension (215,087+ installs)
- Complements: Script command execution

### Verification Strategy
Homebrew commands must execute safely with proper feedback.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I search "brew search node", **Then** available node formulae appear
- **Given** Homebrew search results, **When** I select a formula and press Enter, **Then** "brew install [formula]" is executed
- **Given** an installation is running, **When** I view status, **Then** progress is shown in a panel
- **Given** the command palette is open, **When** I search "brew installed" or "brew list", **Then** my installed formulae appear
- **Given** the command palette is open, **When** I search "brew outdated", **Then** packages with updates available are listed
- **Given** Homebrew is not installed, **When** I try to use brew features, **Then** a helpful message with installation instructions appears

### Implementation Notes
- Use Process to execute brew commands
- Cache formula descriptions from `brew info --json`
- Support both formulae and casks
- Show install/uninstall status for each package
- Add "brew update" and "brew upgrade" commands

---

### [ ] Story 28: Pomodoro Timer

**As a** knowledge worker who wants to maintain focus and productivity
**I want** to start and track Pomodoro sessions from the command palette
**So that** I can maintain healthy work/break cycles without a separate timer app

### Use Case Context
Part of: "Time Management" use case
- Popular in productivity communities
- Integrates with: Focus mode control

### Verification Strategy
Timer must be accurate and provide clear notifications.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I search "pomodoro start" or "timer start", **Then** a 25-minute Pomodoro begins
- **Given** a Pomodoro is running, **When** I search "pomodoro status", **Then** remaining time is displayed
- **Given** a Pomodoro completes, **When** the timer ends, **Then** a notification appears suggesting a break
- **Given** a Pomodoro is running, **When** I search "pomodoro stop", **Then** the timer is cancelled
- **Given** the command palette is open, **When** I search "pomodoro config", **Then** I can adjust work/break durations
- **Given** Focus mode is off, **When** a Pomodoro starts, **Then** optionally Focus mode can be enabled automatically

### Implementation Notes
- Use Timer or async task for countdown
- Store session history for daily/weekly statistics
- Support custom durations (default: 25min work, 5min break)
- Menu bar indicator showing remaining time
- UserNotification framework for alerts

---

### [ ] Story 29: Quick Notes (Floating Notes)

**As a** user who frequently captures ideas and meeting notes
**I want** to quickly jot down notes in a floating window that stays on top
**So that** I can capture thoughts without switching contexts

### Use Case Context
Part of: "Built-in Tools" use case
- Similar to: Raycast Notes (highly requested feature)
- Complements: Snippets and clipboard history

### Verification Strategy
Notes must be instantly accessible and persist across sessions.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I search "note" or "quick note", **Then** a floating note window appears
- **Given** a note window is open, **When** I type text, **Then** the note auto-saves
- **Given** I have multiple notes, **When** I search "notes", **Then** all my notes appear with previews
- **Given** a note exists, **When** I search for text within the note content, **Then** matching notes appear
- **Given** a note is selected, **When** I press Cmd+C on the note list, **Then** the note content is copied
- **Given** markdown is supported, **When** I type markdown in a note, **Then** it renders with formatting preview

### Implementation Notes
- Store notes in Application Support directory (JSON or SQLite)
- Support basic markdown: bold, italic, lists, checkboxes
- Auto-save every few seconds
- Floating window stays on top (.floatingPanel)
- Export to plain text or markdown

---

### [ ] Story 30: Audio Device Switcher

**As a** user who frequently switches between headphones, speakers, and microphones
**I want** to quickly switch audio input/output devices from the command palette
**So that** I can change audio settings without opening System Preferences

### Use Case Context
Part of: "System Integration" use case
- Common request in launcher communities
- Complements: System Control story

### Verification Strategy
Device switching must be instant and reliable.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I search "audio" or "speaker", **Then** available output devices appear
- **Given** the command palette is open, **When** I search "microphone" or "input", **Then** available input devices appear
- **Given** audio devices are listed, **When** I select a device and press Enter, **Then** the system audio switches to that device
- **Given** a device switch occurs, **When** I check the menu bar, **Then** the current device is reflected in any audio indicators
- **Given** AirPods are connected, **When** I search "airpods", **Then** they appear as an output option
- **Given** no external devices are connected, **When** I search for audio devices, **Then** only built-in devices appear

### Implementation Notes
- Use CoreAudio/AudioToolbox for device enumeration
- Use AudioDeviceID and AudioObjectPropertyAddress for switching
- Support both input and output devices
- Show current device with a checkmark indicator
- Handle device connection/disconnection events

---

### [x] Story 31: Battery and System Info

**As a** laptop user who monitors system health
**I want** to quickly check battery status, storage, and system information
**So that** I can monitor my Mac's health without opening System Information

### Use Case Context
Part of: "System Monitoring" use case
- Complements: Process Monitoring story
- Popular in productivity launcher communities

### Verification Strategy
System information must be accurate and updated in real-time.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I search "battery", **Then** current battery percentage, charging status, and cycle count appear
- **Given** the command palette is open, **When** I search "storage" or "disk", **Then** available storage and disk usage appear
- **Given** the command palette is open, **When** I search "system info" or "about", **Then** macOS version, model name, memory, and chip info appear
- **Given** battery info is displayed, **When** battery is low (<20%), **Then** a warning indicator appears
- **Given** storage info is displayed, **When** storage is nearly full (>90%), **Then** a warning indicator appears
- **Given** system info is displayed, **When** I press Cmd+C, **Then** the system specs are copied to clipboard

### Implementation Notes
- Use IOKit for battery information (cycle count, health, temperature)
- Use FileManager for storage information
- Use ProcessInfo and SystemConfiguration for system details
- Cache values for performance (refresh every 30 seconds)
- Show health percentage for battery

---

### [x] Story 32: IP Address and Network Info

**As a** developer and network user
**I want** to quickly view my local and public IP addresses
**So that** I can share connection info or debug network issues without opening Terminal

### Use Case Context
Part of: "Network Utilities" use case
- Common request in developer communities
- Complements: Script command execution for network debugging

### Verification Strategy
Network information must be accurate and retrieved quickly.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I search "ip" or "my ip", **Then** my local and public IP addresses appear
- **Given** IP info is displayed, **When** I view the result, **Then** both local IP (LAN) and public IP (WAN) are shown
- **Given** IP addresses are displayed, **When** I press Enter, **Then** the public IP is copied to clipboard
- **Given** the command palette is open, **When** I search "network info", **Then** network interface details appear (SSID, BSSID, DNS)
- **Given** no internet connection, **When** I search for public IP, **Then** "No internet connection" message appears
- **Given** VPN is connected, **When** I search for IP, **Then** VPN IP is shown with an indicator

### Implementation Notes
- Use getifaddrs for local IP addresses
- Use free IP API services for public IP (ipify, ip-api.com)
- Cache public IP for 5 minutes to avoid API limits
- Show all network interfaces (Wi-Fi, Ethernet, etc.)
- Optional: Show geolocation for public IP

---

### [x] Story 33: Time Zone Converter

**As a** remote worker who collaborates across time zones
**I want** to quickly convert times between different time zones
**So that** I can schedule meetings without mental math or web searches

### Use Case Context
Part of: "Built-in Tools" use case
- Integrates with: Calculator function
- Common request in distributed team communities

### Verification Strategy
Time zone conversion must be accurate and handle daylight saving time.

#### Test Cases (Acceptance Criteria)
- **Given** the command palette is open, **When** I type "3pm EST to PST", **Then** "12:00 PM PST" appears
- **Given** the command palette is open, **When** I type "9am Tokyo to London", **Then** the converted time appears
- **Given** the command palette is open, **When** I type "time in New York", **Then** current time in New York appears
- **Given** the command palette is open, **When** I search "time zones", **Then** a list of frequently used time zones appears with current times
- **Given** a conversion result, **When** I press Enter, **Then** the converted time is copied to clipboard
- **Given** the command palette is open, **When** I type "now in Tokyo", **Then** current Tokyo time appears

### Implementation Notes
- Use TimeZone and DateFormatter from Foundation
- Support common city/time zone aliases (NYC, PST, EST, GMT, etc.)
- Store frequently used time zones in preferences
- Handle daylight saving time automatically
- Show time zone offset indicators (±hours)

---

## Story Priorities Summary

### Immediate Priority (Phase 5)
1. Story 19: Preferences Window - Required for app configuration
2. Story 20: Launch at Login - Essential for launcher app
3. Story 23: Unit Conversion - Quick win, high value

### High Value (Phase 6)
4. Story 24: Color Picker - Popular with designers/developers
5. Story 25: Translation - Popular with multilingual users
6. Story 26: Calendar Integration - Essential for productivity
7. Story 28: Pomodoro Timer - Popular productivity tool

### Developer Tools (Phase 7)
8. Story 27: Homebrew Integration - Popular with developers
9. Story 31: Battery and System Info - System monitoring
10. Story 32: IP Address and Network Info - Developer utility

### Quality of Life (Phase 8)
11. Story 29: Quick Notes - Complements clipboard/snippets
12. Story 30: Audio Device Switcher - Convenience feature
13. Story 33: Time Zone Converter - Quick win

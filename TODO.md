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
**So that** I can find and open apps faster than using Spotlight or the Dock

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
**So that** I can locate and open files faster than using Finder

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

### [ ] Story 18: Menu Bar Presence

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

### [ ] Story 20: Launch at Login

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

### [x] Story 21: AI Command Integration

**As a** developer who uses AI assistance frequently
**I want** to execute AI commands from the command palette
**So that** I can get AI assistance without leaving my current workflow

### Use Case Context
Part of: "AI Integration" use case
- Follows: Foundation features

### Verification Strategy
AI commands should provide fast responses and handle errors gracefully.

#### Test Cases (Acceptance Criteria)
- **Given** I have an AI provider configured, **When** I type "ai: explain what is Swift", **Then** an AI explanation appears in the results
- **Given** I use an AI command, **When** it completes, **Then** I can copy the response to clipboard
- **Given** the AI provider has an error, **When** I use an AI command, **Then** a clear error message is shown

### Implementation Notes
- Support multiple AI providers (OpenAI, Anthropic, local models)
- Store API keys securely in Keychain
- Provide streaming responses for long outputs

---

## Story Dependencies Summary

```
Command Palette Activation (Foundation)
├── Fuzzy Search Across Applications
│   └── Application Launch Execution
├── Window Management
│   ├── Window Tiling
│   └── Window Movement and Resize
├── Built-in Tools
│   ├── Calculator Function
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

### Phase 3: Advanced Features (Stories 11-21)
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

### [ ] Story QA-9: Performance Profiling - Metrics Collection

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

### [ ] Story QA-10: Performance Profiling - CI Integration

**As a** CI engineer who monitors app performance
**I want** performance tests to run in CI
**So that** performance regressions are caught before release

### Use Case Context
Part of: "Performance" use case
- Follows: "Metrics Collection" story

### Verification Strategy
Performance baselines must be established and monitored in CI.

#### Test Cases (Acceptance Criteria)
- **Given** a performance baseline exists, **When** CI runs, **Then** results are compared to baseline
- **Given** performance degrades by >20%, **When** CI runs, **Then** the build fails with a warning
- **Given** performance test runs, **When** it completes, **Then** metrics are stored in CI artifacts
- **Given** I check CI logs, **When** performance data is available, **Then** I can see execution time for each benchmark

### Implementation Notes
- Create benchmark tests using XCBenchmark or custom timing
- Store baselines in version control
- Use GitHub Actions or similar for CI
- Set performance budgets: startup < 1s, search < 100ms

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
    └── CI Integration (QA-10)
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

## New Features from Competitor Analysis

### [ ] Story 22: Quick Look Preview

**As a** user who needs to verify file contents before opening
**I want** to preview files directly in the command palette
**So that** I can quickly check file contents without opening the application

### Use Case Context
Part of: "File Management" use case
- Follows: "File Search" story (Story 8)

### Verification Strategy
Quick Look should display file previews instantly without launching the full application.

#### Test Cases (Acceptance Criteria)
- **Given** a file search result is selected, **When** I press Space, **Then** a Quick Look preview appears
- **Given** a PDF file is selected, **When** I press Space, **Then** the PDF preview shows the first page
- **Given** an image is selected, **When** I press Space, **Then** the image preview displays
- **Given** Quick Look is open, **When** I press Space again or Escape, **Then** the preview closes

### Implementation Notes
- Use QLPreviewPanel for native Quick Look integration
- Support common file types: PDF, images, text, documents
- Integrate with file search results seamlessly

---

### [ ] Story 23: Contacts Integration

**As a** user who frequently needs contact information
**I want** to search contacts from the command palette
**So that** I can quickly copy email addresses or phone numbers

### Use Case Context
Part of: "Built-in Tools" use case
- Follows: "Command Palette Activation" story

### Verification Strategy
Contacts should be searchable and display key information.

#### Test Cases (Acceptance Criteria)
- **Given** contacts exist in Contacts app, **When** I search for a name, **Then** matching contacts appear in results
- **Given** a contact is selected, **When** I press Enter, **Then** contact details are copied to clipboard
- **Given** a contact has multiple email addresses, **When** I select the contact, **Then** options to copy specific fields appear

### Implementation Notes
- Use Contacts framework for accessing contacts
- Request permission on first use
- Display name, email, phone in search results

---

### [ ] Story 24: Enhanced Shell Integration

**As a** developer who frequently runs terminal commands
**I want** to execute shell commands directly from the command palette
**So that** I can run quick commands without opening Terminal

### Use Case Context
Part of: "Automation" use case
- Follows: "Script Command Execution" story (Story 7)

### Verification Strategy
Shell commands should execute with proper environment and display output.

#### Test Cases (Acceptance Criteria)
- **Given** I type a command starting with ">", **When** I press Enter, **Then** the command executes in a shell
- **Given** a command is running, **When** output is produced, **Then** it displays in the results panel
- **Given** a command has errors, **When** it completes, **Then** error output is shown in red
- **Given** I type ">", **When** I press Tab, **Then** shell completion suggestions appear

### Implementation Notes
- Use /bin/zsh or /bin/bash for command execution
- Support common aliases and functions from user shell config
- Remember command history for quick re-execution

---

### [ ] Story 25: Enhanced Clipboard Features

**As a** power user who manages clipboard history
**I want** to pin important items and control storage duration
**So that** I can keep frequently used clips available

### Use Case Context
Part of: "Clipboard Management" use case
- Follows: "Clipboard History Access" story (Story 6)

### Verification Strategy
Clipboard features should provide fine-grained control over history.

#### Test Cases (Acceptance Criteria)
- **Given** a clipboard item, **When** I press Cmd+P, **Then** the item is pinned and stays at the top
- **Given** I search for pinned items, **When** I type "pinned", **Then** only pinned items appear
- **Given** storage is set to 30 days, **When** an item exceeds this age, **Then** it is automatically removed
- **Given** I want to delete an item, **When** I press Delete, **Then** the item is removed from history

### Implementation Notes
- Store pinned status in clipboard history database
- Add storage duration setting in preferences
- Support configurable history size (100, 500, 1000 items)

---

## Infrastructure Improvements

**Note:** CI/CD is not used in this project. All quality checks (format, lint, build, test, coverage) run locally using `./scripts/quality.sh`.

---

## Technical Debt Items

### DEBT-4: mdfind to NSMetadataQuery Migration

**Status:** Pending
**Priority:** High
**Description:** Replace mdfind shell command with NSMetadataQuery API for file search

The current mdfind implementation has known issues:
- Can hang with certain queries
- Limited control over search behavior
- Harder to handle async operations

**Implementation Approach:**
1. Rewrite FileSearchService to use NSMetadataQuery
2. Set up proper search scopes (Documents, Downloads, Desktop)
3. Use kMDItemDisplayName for name search
4. Handle real-time notifications for index changes
5. Verify all existing acceptance criteria still pass

**Verification:** Run Story 8 tests to ensure file search still works correctly

---

### DEBT-5: EmojiSearchService Refactoring

**Status:** Pending
**Priority:** Medium
**Description:** Split large EmojiSearchService.swift into smaller focused types

**Location:** Sources/Services/EmojiSearchService.swift
**Current Size:** ~646 lines

**Implementation Approach:**
1. Extract emoji data loading into separate EmojiDataLoader
2. Create separate EmojiMatcher for search logic
3. Keep main service as thin coordinator
4. Ensure all tests still pass

**Verification:** SwiftLint should no longer warn about type_body_length

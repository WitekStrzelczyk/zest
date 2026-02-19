# API Reference

Technical API documentation for Zest services and components.

## Services

### SearchEngine

Central service for unified search across all sources.

```swift
final class SearchEngine {
    static let shared = SearchEngine()

    func search(query: String) -> [SearchResult]
    func searchFilesOnly(query: String) -> [SearchResult]
    func launchApp(bundleID: String)
}
```

**Features:**
- Unified search across apps, emojis, files, and commands
- Uses `SearchResultScoring` for relevance scoring
- Results sorted by score (descending), then by category

**Files:**
- Sources/Services/SearchEngine.swift
- Sources/Services/SearchResultScoring.swift
- Tests/SearchEngineTests.swift
- Tests/SearchScoringTests.swift

---

### SearchResultScoring

Centralized service for calculating search result relevance scores.

```swift
final class SearchResultScoring {
    static let shared: SearchResultScoring

    func scoreResult(query: String, title: String, subtitle: String? = nil) -> Int
}
```

**Scoring Algorithm:**
- Exact match (case-insensitive): 1000 points
- Exact prefix match: 800 points
- All query chars in order (fuzzy): 100-500 points based on quality
- Substring contains: 50 points
- Consecutive matches bonus: +10 per consecutive
- Match after separator (space/-/_): +15
- Match at start: +20

**Files:**
- Sources/Services/SearchResultScoring.swift
- Tests/SearchScoringTests.swift

---

### WindowManager

Window manipulation using Accessibility API.

```swift
final class WindowManager {
    static let shared = WindowManager()

    enum TilingOption {
        case leftHalf, rightHalf, maximize
    }

    enum MovementOption {
        case center, maximize, moveToScreen, resize
    }

    func tileFocusedWindow(option: TilingOption) -> Bool
    func moveFocusedWindow(option: MovementOption) -> Bool
    static func calculateTileFrame(option: TilingOption, screenFrame: NSRect) -> NSRect
}
```

**Files:**
- Sources/Services/WindowManager.swift
- Tests/WindowManagerTests.swift
- Tests/WindowMovementTests.swift

**Related:**
- [OBSERVATIONS_story_004.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_004.md)
- [OBSERVATIONS_story_005.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_005.md)

---

### ClipboardManager

Clipboard monitoring and history with relevance scoring.

```swift
final class ClipboardManager {
    static let shared = ClipboardManager()

    var history: [ClipboardItem] { get }
    func startMonitoring()
    func stopMonitoring()
    func search(query: String) -> [SearchResult]
}
```

**Features:**
- Timer-based polling (0.5s interval)
- Privacy filtering for password managers
- 100 item limit
- Uses `SearchResultScoring` for relevance ranking

**Files:**
- Sources/Services/ClipboardManager.swift
- Sources/Services/SearchResultScoring.swift

---

### ScriptManager

Script execution with output capture.

```swift
final class ScriptManager {
    static let shared = ScriptManager()

    var isRunning: Bool { get }

    func execute(script: String, type: ScriptType) async -> ScriptExecutionResult
    func terminate() -> Bool
}

enum ScriptType {
    case shell, appleScript, python, ruby
}

struct ScriptExecutionResult {
    let output: String
    let errorOutput: String
    let exitCode: Int32
    let hasError: Bool
}
```

**Files:**
- Sources/Services/ScriptManager.swift
- Tests/ScriptManagerTests.swift

**Related:**
- [OBSERVATIONS_story_007.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_007.md)

---

### FileSearchService

Spotlight-based file search.

```swift
final class FileSearchService {
    static let shared = FileSearchService()

    func searchSync(query: String, maxResults: Int) -> [FileSearchResult]
    func search(query: String, maxResults: Int, callback: @escaping ([FileSearchResult]) -> Void)
}
```

**Features:**
- NSMetadataQuery for Spotlight search
- Build artifact exclusions (.git, node_modules, build)
- Privacy filtering

**Files:**
- Sources/Services/FileSearchService.swift
- Tests/FileSearchServiceTests.swift

**Related:**
- [OBSERVATIONS_Story8_FileSearch.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_Story8_FileSearch.md)

---

### SnippetManager

Text snippet management with variable substitution.

```swift
final class SnippetManager {
    static let shared = SnippetManager()

    var snippets: [Snippet] { get }

    func execute(snippet: Snippet, variables: [String: String]) -> String
    func addSnippet(_ snippet: Snippet)
    func removeSnippet(id: UUID)
}
```

**Built-in Variables:**
- `{date}` - Current date
- `{time}` - Current time

**Files:**
- Sources/Services/SnippetManager.swift
- Sources/Models/Snippet.swift

---

### EmojiSearchService

Emoji search with relevance scoring.

```swift
final class EmojiSearchService {
    static let shared = EmojiSearchService()

    func search(query: String, maxResults: Int = 20) -> [SearchResult]
}
```

**Features:**
- Uses `SearchResultScoring` for keyword matching
- Supports multi-word queries
- Sorts by relevance score

**Files:**
- Sources/Services/EmojiSearchService.swift
- Sources/Services/SearchResultScoring.swift

---

### UserCommandsService

User-defined command execution.

```swift
final class UserCommandsService {
    static let shared = UserCommandsService()

    var commands: [UserCommand] { get }

    func search(query: String) -> [SearchResult]
    func addCommand(_ command: UserCommand)
    func removeCommand(id: UUID)
}
```

**Features:**
- Loads commands from `~/.zest/commands.json`
- Uses `SearchResultScoring` for name/description matching

**Files:**
- Sources/Services/UserCommandsService.swift
- Sources/Services/SearchResultScoring.swift

---

### ContactsService

Contacts search via Contacts framework.

```swift
final class ContactsService {
    static let shared = ContactsService()

    func requestAccess() async -> Bool
    func search(query: String) -> [SearchResult]
}
```

**Features:**
- Uses `SearchResultScoring` for name matching
- Returns both email and phone action results

**Files:**
- Sources/Services/ContactsService.swift
- Sources/Services/SearchResultScoring.swift

---

### SystemControlManager

System controls via AppleScript.

```swift
final class SystemControlManager {
    static let shared = SystemControlManager()

    enum SystemControlAction: String, CaseIterable {
        case darkMode = "Toggle Dark Mode"
        case mute = "Toggle Mute"
        case emptyTrash = "Empty Trash"
        case lockScreen = "Lock Screen"
        case sleep = "Sleep"
        case restart = "Restart"
        case shutdown = "Shutdown"
        case logout = "Log Out"
    }

    func execute(action: SystemControlAction) async throws
}
```

**Files:**
- Sources/Services/SystemControlManager.swift

---

### RemindersService

Reminders integration via EventKit.

```swift
final class RemindersService {
    static let shared = RemindersService()

    func requestAccess() async -> Bool
    func fetchReminders() async throws -> [Reminder]
    func search(query: String) -> [Reminder]
}
```

**Files:**
- Sources/Services/RemindersService.swift
- Tests/RemindersServiceTests.swift

---

### FocusModeService

Focus mode control.

```swift
final class FocusModeService {
    static let shared = FocusModeService()

    func toggleFocusMode() async throws
    func isFocusModeEnabled() -> Bool
}
```

**Implementation:** Uses AppleScript to simulate Option+D shortcut.

**Files:**
- Sources/Services/FocusModeService.swift
- Tests/FocusModeServiceTests.swift

---

## Models

### SearchResult

```swift
struct SearchResult: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let icon: NSImage?
    let category: SearchResultCategory
    let action: () -> Void
    let revealAction: (() -> Void)?
    let filePath: String?

    /// Search relevance score (higher = more relevant)
    let score: Int
}

enum SearchResultCategory: Int, Comparable {
    case application = 0
    case file = 1
    case emoji = 2
    case command = 3
    case clipboard = 4
    case action = 5
    case snippet = 6
    case contact = 7
    case reminder = 8
    case note = 9
    case quickLink = 10
}
```

**Note:** Results are sorted by `score` (descending) first, then by `category`.

### ClipboardItem

```swift
struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let contentType: ContentType
    let timestamp: Date

    enum ContentType: String, Codable {
        case text, image
    }
}
```

---

## See Also

- [CONSOLIDATED_LEARNINGS.md](/Users/witek/projects/copies/zest/docs/retrospections/CONSOLIDATED_LEARNINGS.md) - Technical patterns
- [TDD Guidelines](/Users/witek/projects/copies/zest/docs/TDD_GUIDELINES.md) - Testing patterns

---

*Last reviewed: 2026-02-19*

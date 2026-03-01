# Swift Code Style Guide

Comprehensive coding standards for the Zest macOS command palette app. This guide ensures consistent, maintainable code across the project and helps avoid SwiftLint violations.

## Overview

This guide covers code organization, naming conventions, function design, complexity management, and common patterns used in the Zest project. All rules are enforced via SwiftLint - see [`.swiftlint.yml`](../../.swiftlint.yml) for the complete configuration.

**Key SwiftLint limits (strict):**
- Function body: 50 lines (warning), 80 lines (error)
- Cyclomatic complexity: 8 (warning), 12 (error)
- Line length: 120 (warning), 180 (error)
- File length: 500 lines (warning), 700 lines (error)
- Tuple size: Maximum 2 members

---

## 1. File Organization

### Directory Structure

```
Sources/
├── App/           # AppDelegate, main.swift
├── Models/        # Data models (SearchResult, Snippet, Quicklink)
├── Services/      # Business logic (search, conversions, system integration)
├── State/         # State management (CommandPaletteController, StateStore)
├── UI/            # UI components (Windows, Views)
│   ├── CommandPalette/
│   ├── Preferences/
│   └── Theme/
├── Plugins/       # Plugin implementations (ColorPicker, Translation)
└── Utilities/     # Helper classes (PerformanceMetrics)
```

**Why:** Clear separation of concerns makes code easier to navigate and maintain.

**Fix:** Place new files in the correct directory based on their primary responsibility.

### Grouping Guidelines

| Type | Location | Examples |
|------|----------|----------|
| Data models | `Sources/Models/` | `SearchResult.swift`, `Snippet.swift` |
| Business logic | `Sources/Services/` | `SearchEngine.swift`, `UnitConverter.swift` |
| UI components | `Sources/UI/` | `CommandPaletteWindow.swift` |
| State management | `Sources/State/` | `CommandPaletteStateStore.swift` |
| System integration | `Sources/Services/` | `CalendarService.swift`, `ClipboardManager.swift` |
| Extensions | `Sources/Plugins/` | `ColorPicker/`, `Translation/` |

---

## 2. Naming Conventions

### Follow Swift API Guidelines

Use clear, concise names that read as grammatical phrases.

**Types (Classes, Structs, Enums):**
- Use PascalCase
- Use nouns for classes/structs: `SearchEngine`, `UnitConverter`
- Use nouns or adjectives for enums: `SearchResultCategory`, `AwakeMode`

**Why:** Swift API Design Guidelines promote readability and consistency.

**Fix:** Rename types to PascalCase with descriptive nouns.

### Properties and Variables

- Use camelCase
- Prefer descriptive names over abbreviations
- Avoid single-letter names except in closures or loops

**Good:**
```swift
let searchResults: [SearchResult]
let isLoading: Bool
let convertedValue: String?
```

**Avoid:**
```swift
let res: [SearchResult]  // Unclear abbreviation
let i: Int              // Too short
let b: Bool             // Unclear purpose
```

**Why:** Descriptive names make code self-documenting and reduce cognitive load.

**Fix:** Rename variables to descriptive camelCase names.

### Functions and Methods

- Use verb or verb phrases: `convert()`, `search()`, `registerHotkey()`
- Use camelCase
- Use @discardableResult when the return value can be ignored

```swift
@discardableResult
func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> HotkeyIdentifier
```

**Why:** Verbs clearly indicate the action performed; @discardableResult prevents warnings when callers don't use the return value.

**Fix:** Add @discardableResult for functions that return a value that may be ignored.

---

## 3. Function Design

### Maximum 50 Lines (Warning), 80 Lines (Error)

Keep functions focused on a single responsibility. Long functions are a code smell indicating the function does too much.

**Why:** Short functions are easier to test, understand, and maintain. They also reduce cyclomatic complexity.

**Fix:** Extract logic into smaller helper functions with descriptive names.

### Single Responsibility

Each function should do one thing well. If you need "and" to describe what a function does, it likely does too much.

**Good:**
```swift
func parseQuery(_ input: String) -> ParsedQuery {
    let trimmed = input.trimmingCharacters(in: .whitespaces)
    let components = trimmed.components(separatedBy: " ")
    return ParsedQuery(keywords: components, original: input)
}

func convertValue(_ query: ParsedQuery) -> String? {
    guard let converter = findConverter(for: query.keywords) else { return nil }
    return converter.convert(query.keywords)
}
```

**Avoid:**
```swift
func parseQueryAndConvert(_ input: String) -> String? { /* 60+ lines */ }
```

### Avoid Duplication

If code appears in multiple places, extract it into a shared function.

**Why:** Duplication leads to bugs when one instance is updated but others aren't.

**Fix:** Create a helper function and call it from both places.

---

## 4. Complexity Management

### Cyclomatic Complexity: Max 12

Cyclomatic complexity counts the number of decision points (if, switch, for, while, &&, ||). Keep it under 12 to maintain readability.

**Why:** High complexity indicates hard-to-test, error-prone code. Complex code often has bugs that are difficult to find.

**Fix:** Extract complex logic into smaller functions, use early returns, simplify conditions.

### Reduce Nesting

Deeply nested code (4+ levels) is hard to follow. Use guard statements and early returns.

**Good:**
```swift
func processResult(_ result: SearchResult?) -> String {
    guard let result else { return "No result" }
    
    guard result.score > 0 else { return "No match" }
    
    return result.title
}
```

**Avoid:**
```swift
func processResult(_ result: SearchResult?) -> String {
    if let result = result {
        if result.score > 0 {
            return result.title
        } else {
            return "No match"
        }
    } else {
        return "No result"
    }
}
```

**Why:** Flat code with early returns is easier to read and debug.

**Fix:** Refactor nested if/else chains to use guard statements.

### Large Tuple Limit: Maximum 2 Members

SwiftLint errors on tuples with more than 2 members. Use a struct instead.

**Why:** Large tuples are hard to read and indicate missing abstraction.

**Fix:** Create a struct or use a tuple of tuples (but prefer structs for clarity).

```swift
// Avoid
let result: (String, String, String, Int, Bool)

// Better - use a struct
struct SearchResultData {
    let title: String
    let subtitle: String
    let category: String
    let score: Int
    let isActive: Bool
}
```

---

## 5. Common Patterns in Zest

### Singletons for Services

Use static shared instance for services that should have one global instance.

```swift
final class GlobalHotkeyManager {
    static let shared: GlobalHotkeyManager = .init()
    
    private init() {
        setupEventHandler()
    }
}
```

**Why:** Services like GlobalHotkeyManager, ClipboardManager, and PreferencesManager need single instances to manage shared state or system resources.

**Fix:** Make the class final, add static shared property, make init private.

### @MainActor for UI and State

Use @MainActor on classes that interact with UI or need main thread access.

```swift
@MainActor
final class CommandPaletteController {
    func showPalette() { /* UI code */ }
}
```

**Why:** AppKit requires UI updates on the main thread. @MainActor provides compile-time safety.

**Fix:** Add @MainActor to classes that access UI elements or are accessed from UI code.

### Thread Safety with NSLock

Use NSLock for protecting shared mutable state.

```swift
final class ClipboardManager {
    private let lock = NSLock()
    private var history: [ClipboardItem] = []
    
    func addItem(_ item: ClipboardItem) {
        lock.lock()
        defer { lock.unlock() }
        history.insert(item, at: 0)
        if history.count > maxHistory {
            history.removeLast()
        }
    }
}
```

**Why:** NSLock provides simple, reliable synchronization for multi-threaded access to shared state.

**Fix:** Add NSLock and wrap accesses in lock/unlock with defer for safety.

### Optionals and Early Returns

Use optionals with guard statements for clean nil handling.

```swift
func findResult(matching query: String) -> SearchResult? {
    guard !query.isEmpty else { return nil }
    guard let index = results.firstIndex(where: { $0.title.contains(query) }) else { return nil }
    return results[index]
}
```

**Why:** Guard statements make the happy path obvious and handle edge cases clearly.

**Fix:** Replace if-let chains with guard statements for cleaner code.

### Notification Names

Define notification names as static extensions on Notification.Name.

```swift
extension Notification.Name {
    static let showAddQuicklink = Notification.Name("showAddQuicklink")
    static let hideAddQuicklink = Notification.Name("hideAddQuicklink")
}
```

**Why:** Centralizes notification names, prevents typos, provides autocomplete.

**Fix:** Add notification names to a Notification.Name extension in the relevant model file.

---

## 6. Code Examples

### Creating a New Service

```swift
import Foundation

/// Service for [description of what this service does]
final class MyNewService {
    // MARK: - Singleton
    
    static let shared: MyNewService = .init()
    
    // MARK: - Properties
    
    private let lock = NSLock()
    private var cache: [String: SomeType] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Setup code
    }
    
    // MARK: - Public API
    
    /// Does something useful
    /// - Parameter input: Description of input
    /// - Returns: Description of return value
    func doSomething(input: String) -> SomeType? {
        lock.lock()
        defer { lock.unlock() }
        
        // Implementation
    }
}
```

### Creating a New Model

```swift
import Foundation

struct MyModel {
    let id: UUID
    let name: String
    let value: Int
    
    init(id: UUID = UUID(), name: String, value: Int) {
        self.id = id
        self.name = name
        self.value = value
    }
}

// MARK: - Equatable (if needed)

extension MyModel: Equatable {
    static func == (lhs: MyModel, rhs: MyModel) -> Bool {
        lhs.id == rhs.id
    }
}
```

### Creating a Test

```swift
import XCTest
@testable import ZestApp

/// Tests for [Feature Name] - Story #[number]
final class MyNewServiceTests: XCTestCase {
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        // Setup code
    }
    
    override func tearDown() {
        // Cleanup code
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func test_description_of_behavior() {
        // Given
        let service = MyNewService.shared
        
        // When
        let result = service.doSomething(input: "test")
        
        // Then
        XCTAssertNotNil(result, "Should return a result")
    }
}
```

---

## 7. Common SwiftLint Violations and Fixes

### Function Body Too Long

**Error:** `Function body should be 50 lines or less (currently 65)`

**Why:** Functions over 50 lines are hard to test and maintain.

**Fix:** Extract logic into smaller helper functions:
```swift
// Before (55 lines)
func processSearch(_ query: String) -> [SearchResult] {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    let tokens = trimmed.components(separatedBy: " ")
    var results: [SearchResult] = []
    for token in tokens {
        if let match = searchIndex[token] {
            results.append(contentsOf: match)
        }
    }
    // ... more logic
}

// After - extract helpers
func processSearch(_ query: String) -> [SearchResult] {
    let tokens = tokenize(query)
    return tokens.flatMap { findMatches(for: $0) }
}

private func tokenize(_ query: String) -> [String] {
    query.trimmingCharacters(in: .whitespaces)
        .components(separatedBy: " ")
}

private func findMatches(for token: String) -> [SearchResult] {
    searchIndex[token] ?? []
}
```

### Cyclomatic Complexity Too High

**Error:** `Cyclomatic complexity should be 12 or less (currently 15)`

**Why:** Complex functions have many branches that are hard to test and understand.

**Fix:** Simplify conditions and extract branches:
```swift
// Before (complex)
func processResult(_ result: SearchResult) {
    if result.score > 0 {
        if result.category == .application {
            if result.isActive {
                launchApp(result)
            } else {
                showInFinder(result)
            }
        } else if result.category == .file {
            openFile(result)
        } else if result.category == .action {
            executeAction(result)
        }
    }
}

// After - simplified with early returns
func processResult(_ result: SearchResult) {
    guard result.score > 0 else { return }
    
    switch result.category {
    case .application:
        handleApplication(result)
    case .file:
        openFile(result)
    case .action:
        executeAction(result)
    default:
        break
    }
}

private func handleApplication(_ result: SearchResult) {
    if result.isActive {
        launchApp(result)
    } else {
        showInFinder(result)
    }
}
```

### Line Too Long

**Error:** `Line should be 120 characters or less (currently 145)`

**Why:** Long lines are hard to read, especially in split editors.

**Fix:** Break lines at natural points:
```swift
// Before
let searchResults = allResults.filter { $0.title.localizedCaseInsensitiveContains(query) }.sorted { $0.score > $1.score }

// After
let matchingResults = allResults.filter {
    $0.title.localizedCaseInsensitiveContains(query)
}
let sortedResults = matchingResults.sorted {
    $0.score > $1.score
}
```

### File Too Long

**Error:** `File should be 500 lines or less (currently 650)`

**Why:** Large files are hard to navigate and maintain.

**Fix:** Split into multiple files:
- Move related types to separate files
- Extract large enums into their own files
- Create file-private helpers in separate files

---

## 8. Quality Assurance

### Always Verify Build

After any code change, verify the build succeeds with zero warnings:

```bash
swift build 2>&1 | grep -E "(error:|warning:)"
```

**Why:** Warnings indicate potential issues and must be fixed before they become bugs.

### Run Tests Before Committing

```bash
./scripts/run_tests.sh
```

**Why:** Tests catch regressions. All tests must pass before code can be merged.

### Run Full Quality Pipeline

```bash
./scripts/quality.sh
```

This runs:
1. SwiftFormat (formatting)
2. SwiftLint (style/complexity)
3. swift build (compilation)
4. swift test (tests)
5. Coverage check

---

## See Also

- [TDD Guidelines](../TDD_GUIDELINES.md) - Test-driven development workflow
- [Configuration Storage](CONFIGURATION_STORAGE.md) - UserDefaults vs App Support
- [`.swiftlint.yml`](../../.swiftlint.yml) - SwiftLint configuration
- [CLAUDE.md](../../CLAUDE.md) - Project overview and agent workflow

---

*Last reviewed: 2026-03-01*
*Status: current*

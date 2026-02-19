# Configuration Storage Guide

This document explains how Zest stores configuration and data, helping developers understand when and how to add new configuration to the app.

## Overview

Zest uses two primary mechanisms for storing configuration and data:

| Storage Type | Use Case | Location |
|-------------|----------|----------|
| **UserDefaults** | Simple preferences, settings, flags | `UserDefaults.standard` |
| **Application Support** | User-generated content, collections, complex data | `~/Library/Application Support/Zest/` |

---

## 1. UserDefaults (Simple Preferences)

**Use for:** User preferences, settings, flags, and small configuration values that are:
- Primitive types (Bool, Int, String, Data)
- Simple arrays of primitives
- Not user-generated content
- Not large datasets

### When to Use UserDefaults

| Type | Example | Storage |
|------|---------|---------|
| Boolean flags | `launchAtLogin`, `showInDock` | `UserDefaults.standard.bool` |
| Numbers | `searchResultsLimit`, `globalHotkeyKeyCode` | `UserDefaults.standard.integer` |
| Simple strings | `ai_provider`, `theme` | `UserDefaults.standard.string` |
| Simple arrays | `clipboardHistory` (strings only) | `UserDefaults.standard.stringArray` |

### Code Example: PreferencesManager

Location: `Sources/Services/PreferencesManager.swift`

```swift
import AppKit
import Foundation

/// Manages application preferences using UserDefaults
final class PreferencesManager: ObservableObject {
    static let shared: PreferencesManager = .init()

    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys (private enum for organization)
    
    private enum Keys {
        static let globalHotkeyModifiers = "globalHotkeyModifiers"
        static let globalHotkeyKeyCode = "globalHotkeyKeyCode"
        static let searchResultsLimit = "searchResultsLimit"
        static let launchAtLogin = "launchAtLogin"
        static let indexedDirectories = "indexedDirectories"
        static let theme = "theme"
    }

    // MARK: - Properties with @Published for reactive updates

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }

    @Published var searchResultsLimit: Int {
        didSet {
            defaults.set(searchResultsLimit, forKey: Keys.searchResultsLimit)
        }
    }

    @Published var theme: AppTheme {
        didSet {
            if let rawValue = theme.rawValue as String? {
                defaults.set(rawValue, forKey: Keys.theme)
            }
        }
    }

    // MARK: - Initialization (loading defaults)

    private init() {
        // Load with fallback values
        let storedLimit = defaults.integer(forKey: Keys.searchResultsLimit)
        searchResultsLimit = storedLimit > 0 ? storedLimit : 10

        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        // Arrays require special handling
        if let dirs = defaults.stringArray(forKey: Keys.indexedDirectories), !dirs.isEmpty {
            indexedDirectories = dirs
        } else {
            indexedDirectories = ["~/Documents", "~/Downloads"]
        }
    }
}
```

### Adding a New UserDefaults Preference

1. **Add the key constant** in the `Keys` enum:
   ```swift
   private enum Keys {
       static let myNewSetting = "myNewSetting"  // Add this
   }
   ```

2. **Add a @Published property** with didSet to auto-save:
   ```swift
   @Published var myNewSetting: Bool {
       didSet {
           defaults.set(myNewSetting, forKey: Keys.myNewSetting)
       }
   }
   ```

3. **Initialize with a default value** in the initializer:
   ```swift
   myNewSetting = defaults.bool(forKey: Keys.myNewSetting)  // defaults to false
   ```

---

## 2. Application Support Directory (JSON Files)

**Use for:** User-generated content, collections, and larger data structures that are:
- Complex objects with multiple properties
- User-created content (not app defaults)
- Collections that may grow large
- Data requiring backup/export capability

### Directory Structure

```
~/Library/Application Support/Zest/
├── Quicklinks/
│   └── quicklinks.json      # User-created URL bookmarks
├── Extensions/
│   └── (extension files)    # User-installed extensions
└── (other services may create their own subdirectories)
```

### When to Use Application Support

| Use Case | Example | Storage |
|----------|---------|---------|
| User content | Quicklinks, custom commands | JSON in App Support |
| Complex objects | Multi-field data structures | JSON in App Support |
| Binary assets | Cached icons, built-in content | Files in App Support |
| Search indices | File search cache | Files in App Support |

### Code Example: QuicklinkManager

Location: `Sources/Services/QuicklinkManager.swift`

```swift
import AppKit
import Foundation

/// Manages quicklinks (URL bookmarks) storage and operations
final class QuicklinkManager {
    static let shared: QuicklinkManager = .init()

    private let fileManager = FileManager.default
    private var quicklinks: [Quicklink] = []

    // MARK: - Directory Paths

    private var quicklinksDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Zest/Quicklinks", isDirectory: true)
    }

    private var quicklinksFile: URL {
        quicklinksDirectory.appendingPathComponent("quicklinks.json")
    }

    // MARK: - Initialization

    private init() {
        createDirectoryIfNeeded()
        loadQuicklinks()
        addBuiltInQuicklinksIfNeeded()
    }

    // MARK: - Directory Setup

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: quicklinksDirectory.path) {
            try? fileManager.createDirectory(at: quicklinksDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - JSON Serialization

    private func loadQuicklinks() {
        guard fileManager.fileExists(atPath: quicklinksFile.path) else { return }

        do {
            let data = try Data(contentsOf: quicklinksFile)
            quicklinks = try JSONDecoder().decode([Quicklink].self, from: data)
        } catch {
            print("Failed to load quicklinks: \(error)")
            quicklinks = []
        }
    }

    private func saveQuicklinks() {
        do {
            let data = try JSONEncoder().encode(quicklinks)
            try data.write(to: quicklinksFile)
        } catch {
            print("Failed to save quicklinks: \(error)")
        }
    }
}
```

### Data Model Example

Location: `Sources/Models/Quicklink.swift`

```swift
import Foundation

/// Represents a quicklink (bookmark) with URL and optional icon
struct Quicklink: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var url: String
    var keywords: [String]
    var keyboardShortcut: String?
    var createdAt: Date
    var lastUsedAt: Date?

    init(id: UUID = UUID(), name: String, url: String, keywords: [String] = [], ...) {
        // ...
    }
}
```

### Adding a New JSON-Based Feature

1. **Create a data model** conforming to `Codable`:
   ```swift
   struct MyFeature: Codable, Identifiable {
       var id: UUID
       var name: String
       var data: String
   }
   ```

2. **Create a Manager class** with directory and file paths:
   ```swift
   final class MyFeatureManager {
       private let fileManager = FileManager.default
       
       private var directory: URL {
           let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
           return appSupport.appendingPathComponent("Zest/MyFeature", isDirectory: true)
       }
       
       private var dataFile: URL {
           directory.appendingPathComponent("data.json")
       }
   }
   ```

3. **Implement load/save methods** using JSONEncoder/JSONDecoder:
   ```swift
   private func load() {
       guard fileManager.fileExists(atPath: dataFile.path) else { return }
       let data = try Data(contentsOf: dataFile)
       items = try JSONDecoder().decode([MyFeature].self, from: data)
   }
   
   private func save() {
       let data = try JSONEncoder().encode(items)
       try data.write(to: dataFile)
   }
   ```

4. **Create directory on initialization** if needed.

---

## Decision Guide

Use this flowchart to decide which storage mechanism to use:

```
Is the data user-generated content (created by the user)?
├── YES → Use Application Support (JSON files)
│         Examples: Quicklinks, custom commands, user scripts
│
└── NO → Is it a simple preference/setting?
         ├── YES → Use UserDefaults
         │         Examples: Hotkeys, theme, boolean flags
         │
         └── NO → Use Application Support (JSON files)
                  Examples: Search index cache, built-in content
```

### Quick Reference Table

| Question | Answer | Storage |
|----------|--------|---------|
| Is it a boolean flag? | Yes | UserDefaults |
| Is it a simple string/int? | Yes | UserDefaults |
| Is it a simple array of primitives? | Yes | UserDefaults |
| Is it a complex object with multiple fields? | No | App Support |
| Is it user-created content? | Yes | App Support |
| Could it grow to thousands of items? | Yes | App Support |
| Does it need export/backup? | Yes | App Support |

---

## Important Patterns

### Always Use FileManager for Paths

```swift
// Correct - uses system APIs
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

// Incorrect - hardcoded path
let path = "/Users/me/Library/Application Support/Zest"  // Never do this
```

### Handle Missing Files Gracefully

```swift
// Always check if file exists before loading
guard fileManager.fileExists(atPath: dataFile.path) else {
    // Create default or return empty
    return []
}
```

### Use @Published for Reactive Preferences

When using PreferencesManager, prefer `@Published` properties so SwiftUI views automatically update:

```swift
@Published var mySetting: Bool {
    didSet {
        defaults.set(mySetting, forKey: Keys.mySetting)
    }
}
```

---

## Related Files

- `Sources/Services/PreferencesManager.swift` - UserDefaults preferences
- `Sources/Services/QuicklinkManager.swift` - JSON-based storage example
- `Sources/Services/ClipboardManager.swift` - Clipboard history (UserDefaults)
- `Sources/Services/ExtensionManager.swift` - App Support directory usage

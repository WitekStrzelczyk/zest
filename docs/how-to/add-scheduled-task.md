# Adding a Scheduled Task

How to add a new recurring background task using SchedulerService.

---
last_reviewed: 2026-02-25
review_cycle: quarterly
status: current
---

## Quick Start

Add a scheduled task in 3 steps:

### 1. Define Task ID

```swift
// In SchedulerService extension
extension SchedulerService.TaskID {
    public static let myTask = "my-task-id"
}
```

### 2. Create Refresh Method

```swift
// In your service
func refreshCache() async {
    // Fetch data
    // Update cache
    // Post notification (optional)
}
```

### 3. Register on App Launch

```swift
// In AppDelegate or app startup
SchedulerService.shared.register(
    id: SchedulerService.TaskID.myTask,
    intervalMinutes: 30  // or use interval: TimeInterval
) {
    await MyService.shared.refreshCache()
}

SchedulerService.shared.start()
```

## Complete Example: Contacts Cache

```swift
// 1. Define task ID
extension SchedulerService.TaskID {
    public static let contactsSync = "contacts-sync"
}

// 2. Define notification
extension Notification.Name {
    static let contactsCacheUpdated = Notification.Name("contactsCacheUpdated")
}

// 3. Add to ContactsService
final class ContactsService {
    private var cachedContacts: [Contact] = []
    private var lastCacheTime: Date?
    private let cacheTimeout: TimeInterval = 60
    
    func refreshCache() async {
        // Fetch from Contacts framework
        let contacts = await fetchContacts()
        
        // Update cache
        cachedContacts = contacts
        lastCacheTime = Date()
        
        // Notify UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .contactsCacheUpdated, object: nil)
        }
    }
    
    func search(query: String) -> [SearchResult] {
        // Trigger background refresh if stale
        triggerBackgroundRefresh()
        
        // Return cached results immediately
        return searchCached(query)
    }
}

// 4. Register on app launch
SchedulerService.shared.register(
    id: SchedulerService.TaskID.contactsSync,
    intervalMinutes: 30
) {
    await ContactsService.shared.refreshCache()
}
```

## SchedulerService API

### Registration

```swift
// With seconds
func register(id: String, interval: TimeInterval, action: @escaping () async -> Void)

// With minutes (convenience)
func register(id: String, intervalMinutes: Int, action: @escaping () async -> Void)
```

### Lifecycle

```swift
// Start scheduler (runs all tasks immediately)
func start()

// Stop scheduler
func stop()

// Manually trigger a specific task
func runNow(id: String) async

// Remove a task
func unregister(id: String)
```

## Recommended Intervals

| Task Type | Interval | Rationale |
|-----------|----------|-----------|
| Calendar cache | 10 min | Events change infrequently |
| Contacts sync | 30 min | Contacts rarely change during session |
| File index | 60 min | Filesystem changes tracked separately |
| Clipboard cleanup | 5 min | History can grow quickly |
| Stats upload | 60 min | Batch uploads are efficient |

## Pattern: Cache-First Search

For best performance, implement cache-first search:

```swift
func search(query: String) -> [SearchResult] {
    // 1. Trigger async refresh if needed (doesn't block)
    if cacheIsStale {
        Task {
            await refreshCache()
        }
    }
    
    // 2. Return cached results immediately
    return cachedResults(matching: query)
}
```

## Pattern: UI Notification

Allow UI to update when cache refreshes:

```swift
// Service posts notification
DispatchQueue.main.async {
    NotificationCenter.default.post(name: .myCacheUpdated, object: nil)
}

// UI listens
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleCacheUpdated),
    name: .myCacheUpdated,
    object: nil
)

@objc private func handleCacheUpdated() {
    performSearch(currentQuery)
}
```

## Thread Safety

SchedulerService uses `NSLock` internally. Your service should too:

```swift
private let lock = NSLock()
private var _cachedData: [Item] = []

var cachedData: [Item] {
    lock.lock()
    defer { lock.unlock() }
    return _cachedData
}

func updateCache(_ data: [Item]) {
    lock.lock()
    defer { lock.unlock() }
    _cachedData = data
}
```

## Debugging

Add logging to track task execution:

```swift
func refreshCache() async {
    logger.debug("Starting cache refresh")
    // ... refresh logic ...
    logger.info("Cache refreshed: \(items.count) items")
}
```

Check Console.app with filter: `subsystem:com.zest.app`

## Related

- [architecture/calendar-cache.md](/docs/architecture/calendar-cache.md) - Full architecture documentation
- [SchedulerService.swift](/Sources/Services/SchedulerService.swift) - Implementation

---

*Last reviewed: 2026-02-25*

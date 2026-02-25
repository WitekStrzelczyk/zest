# Calendar Cache-First Architecture

A cache-first approach for calendar search that improves performance from 400+ms to <10ms by preloading data and serving results synchronously.

---
last_reviewed: 2026-02-25
review_cycle: quarterly
status: current
---

## Overview

The calendar service uses a **cache-first** pattern where:

1. Calendar events are preloaded into memory on app launch
2. Search queries return cached results synchronously (<10ms)
3. Background refresh keeps the cache fresh
4. UI is notified when new data arrives

### Performance Impact

| Approach | Latency | User Experience |
|----------|---------|-----------------|
| Before (async on demand) | 400+ms | Noticeable delay on each search |
| After (cache-first) | <10ms | Instant results, background updates |

## Architecture Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        App Launch                               │
│                             │                                   │
│                             ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              SchedulerService.shared                     │   │
│  │  • Registers calendar-cache-refresh task                 │   │
│  │  • Runs tasks immediately on start()                     │   │
│  │  • Checks every 60 seconds for due tasks                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                             │                                   │
│                             ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              CalendarService.shared                      │   │
│  │  • refreshCache() fetches events from EventKit           │   │
│  │  • Caches events for today + tomorrow                    │   │
│  │  • Posts .calendarCacheUpdated notification              │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       User Types Query                          │
│                             │                                   │
│                             ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         CalendarService.search(query:) [SYNC]            │   │
│  │  • Returns cached results IMMEDIATELY (<10ms)            │   │
│  │  • Calls triggerBackgroundRefresh() if stale             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                             │                                   │
│              ┌──────────────┴──────────────┐                   │
│              ▼                             ▼                   │
│  ┌────────────────────┐      ┌───────────────────────────┐    │
│  │  Return cached     │      │  Background Task (async)  │    │
│  │  results to UI     │      │  • Fetches fresh events   │    │
│  │  (instant)         │      │  • Updates cache          │    │
│  └────────────────────┘      │  • Posts notification     │    │
│                              └───────────────────────────┘    │
│                                          │                     │
│                                          ▼                     │
│                              ┌───────────────────────────┐    │
│                              │  .calendarCacheUpdated    │    │
│                              │  Notification             │    │
│                              └───────────────────────────┘    │
│                                          │                     │
│                                          ▼                     │
│                              ┌───────────────────────────┐    │
│                              │  CommandPaletteWindow     │    │
│                              │  • Re-runs search         │    │
│                              │  • Shows updated results  │    │
│                              └───────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. SchedulerService

**File:** `Sources/Services/SchedulerService.swift`

Generic scheduler for recurring background tasks.

```swift
final class SchedulerService: @unchecked Sendable {
    static let shared = SchedulerService()
    
    /// Register a recurring task
    func register(id: String, interval: TimeInterval, action: @escaping () async -> Void)
    
    /// Register with interval in minutes
    func register(id: String, intervalMinutes: Int, action: @escaping () async -> Void)
    
    /// Start the scheduler
    func start()
    
    /// Stop the scheduler
    func stop()
    
    /// Manually trigger a specific task
    func runNow(id: String) async
}
```

**Key Features:**

| Feature | Implementation |
|---------|---------------|
| Immediate start | Runs all tasks immediately on `start()` |
| Periodic checks | Timer checks every 60 seconds for due tasks |
| Thread safety | Uses `NSLock` for all state access |
| Concurrency protection | `isRunning` flag prevents overlapping execution |
| Multiple tasks | Dictionary stores multiple tasks with different intervals |

**Task Registration:**

```swift
extension SchedulerService {
    enum TaskID {
        public static let calendarCacheRefresh = "calendar-cache-refresh"
    }
}
```

### 2. CalendarService Cache

**File:** `Sources/Services/CalendarService.swift`

The cache implementation uses these properties:

```swift
/// Cached events (refreshed in background)
private var cachedEvents: [CalendarEvent] = []
private var lastCacheTime: Date?
private let cacheTimeout: TimeInterval = 30  // seconds

/// Track if background refresh is in progress
private var isRefreshingInBackground = false
```

**Cache-First Search Method:**

```swift
/// Synchronous search - CACHE FIRST approach
func search(query: String) -> [SearchResult] {
    // 1. Always trigger background refresh if cache is stale
    triggerBackgroundRefresh()
    
    // 2. Return cached results IMMEDIATELY
    //    May be empty on first call - UI notified via notification
    return resultsFromCache(query)
}
```

**Background Refresh:**

```swift
/// Public method to refresh cache - called by scheduler
func refreshCache() async {
    // 1. Request EventKit access if needed
    // 2. Fetch events from now to end of tomorrow
    // 3. Update cachedEvents
    // 4. Post .calendarCacheUpdated notification
}
```

### 3. Notification Pattern

**Definition:**

```swift
extension Notification.Name {
    static let calendarCacheUpdated = Notification.Name("calendarCacheUpdated")
}
```

**Posted when:**
- Scheduler completes a scheduled refresh
- Background refresh completes after `triggerBackgroundRefresh()`

**UI Listener (CommandPaletteWindow):**

```swift
private func setupNotifications() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleCalendarCacheUpdated),
        name: .calendarCacheUpdated,
        object: nil
    )
}

@objc private func handleCalendarCacheUpdated() {
    // Re-run search to show updated calendar results
    let currentQuery = searchField.stringValue
    guard !currentQuery.isEmpty else { return }
    performSearch(currentQuery)
}
```

## Startup Integration

The scheduler should be started during app initialization:

```swift
// In AppDelegate or app startup
func applicationDidFinishLaunching(_ notification: Notification) {
    // Register calendar cache refresh (every 10 minutes)
    SchedulerService.shared.register(
        id: SchedulerService.TaskID.calendarCacheRefresh,
        intervalMinutes: 10
    ) {
        await CalendarService.shared.refreshCache()
    }
    
    // Start the scheduler (runs tasks immediately)
    SchedulerService.shared.start()
}
```

## Data Flow

### Time Range Cached

Events are cached from **now** to **end of tomorrow** (23:59:59):

```swift
let now = Date()
guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
      let endOfTomorrow = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: tomorrow)
else { return }
```

This provides:
- Today's events (active, recent, upcoming)
- Tomorrow's events (for planning ahead)
- Reasonable memory footprint

### Refresh Intervals

| Interval | Purpose |
|----------|---------|
| 10 minutes | Scheduled refresh via SchedulerService |
| 30 seconds | Cache timeout for `triggerBackgroundRefresh()` |
| 60 seconds | Scheduler check interval for due tasks |

## Design Decisions

### 1. Cache-First, Always

The synchronous `search(query:)` method **always** returns immediately from cache:

- **Pro:** Predictable <10ms response time
- **Pro:** No UI blocking
- **Con:** First search may return empty results
- **Mitigation:** UI re-runs search on cache update notification

### 2. Background Refresh

Async fetch doesn't block UI:

- **Pro:** Smooth user experience
- **Pro:** Cache stays fresh
- **Pro:** Multiple searches don't trigger multiple fetches (isRefreshingInBackground flag)

### 3. Notification-Based Updates

UI refreshes when new data arrives:

- **Pro:** Decoupled architecture
- **Pro:** Multiple UI components can listen
- **Pro:** Clear signal for when to update

### 4. Generic Scheduler

Can add more recurring tasks:

```swift
// Future tasks the scheduler can handle:
// - File search index refresh
// - Contacts sync
// - Clipboard history cleanup
// - Quicklink validation
// - Usage statistics upload
```

### 5. 10-Minute Refresh Interval

Balance between:
- **Freshness:** Calendar data doesn't change often
- **Battery:** Periodic fetch is efficient
- **Privacy:** Minimal EventKit access

## Extending for New Tasks

See [how-to/add-scheduled-task.md](/docs/how-to/add-scheduled-task.md) for step-by-step instructions.

Quick example:

```swift
// 1. Define task ID
extension SchedulerService.TaskID {
    public static let contactsSync = "contacts-sync"
}

// 2. Register on app launch
SchedulerService.shared.register(
    id: SchedulerService.TaskID.contactsSync,
    intervalMinutes: 30
) {
    await ContactsService.shared.refreshCache()
}

// 3. Add notification (optional)
extension Notification.Name {
    static let contactsCacheUpdated = Notification.Name("contactsCacheUpdated")
}
```

## Troubleshooting

### Cache Not Updating

**Symptoms:**
- Old events showing
- New events not appearing

**Check:**

1. **Scheduler running?**
   ```swift
   // Add logging in SchedulerService.start()
   logger.info("Starting scheduler")
   ```

2. **Calendar permissions granted?**
   ```swift
   // Check in CalendarService
   if !hasAccess {
       let granted = await requestCalendarAccess()
   }
   ```

3. **EventKit returning events?**
   ```swift
   // Add logging in refreshCache()
   logger.info("Fetched \(events.count) events")
   ```

### First Search Returns Empty

**Expected behavior** on first launch:
- Cache is empty
- Search returns `[]` immediately
- Background refresh starts
- Notification triggers UI refresh
- Second search shows results

**If empty results persist:**

1. Check `triggerBackgroundRefresh()` is being called
2. Verify `.calendarCacheUpdated` notification is posted
3. Confirm UI is observing the notification

### Permissions Issues

**Calendar access denied:**

1. Check System Preferences → Privacy & Security → Calendar
2. Reset permissions (development):
   ```bash
   tccutil reset Calendar com.zest.app
   ```
3. Re-request on next app launch

### Thread Safety Issues

**Symptoms:**
- Crashes during refresh
- Inconsistent cache state

**Solution:**
- All cache access is protected by the service's internal state
- `isRefreshingInBackground` flag prevents concurrent refreshes
- Scheduler uses `isRunning` flag per task

## Related Documentation

- [architecture/README.md](/docs/architecture/README.md) - System architecture overview
- [how-to/add-scheduled-task.md](/docs/how-to/add-scheduled-task.md) - Adding new scheduled tasks
- [retrospections/OBSERVATIONS_calendar_integration.md](/docs/retrospections/OBSERVATIONS_calendar_integration.md) - Calendar implementation learnings

---

*Last reviewed: 2026-02-25*

# OBSERVATIONS: Reminders and Notes Integration

## Stories Implemented
- Story 14: Reminders Integration
- Story 15: Notes Integration

## Tools Used
- EventKit framework for Reminders
- AppleScript for Notes (EventKit doesn't have good macOS support)
- NSWorkspace for opening apps

## Complexity
- **Reminders**: Medium - Uses EventKit which has async APIs, requires handling macOS version differences (14+ vs older)
- **Notes**: Medium-High - EventKit has poor macOS Notes support, fell back to AppleScript which requires careful string escaping

## Key Learnings

### EventKit Reminders
1. EventKit provides `requestFullAccessToReminders()` for macOS 14+, older API for earlier versions
2. EKReminder has `dueDateComponents` not `dueDate` - need to convert to Date manually
3. Must handle permission requests gracefully

### Notes AppleScript
1. Notes API via EventKit doesn't work well on macOS - AppleScript is more reliable
2. NSAppleEventDescriptor parsing is complex - easier to use text-based delimiter parsing
3. Notes.app needs permission - triggers automatically on first AppleScript call

### General
1. Always provide graceful fallbacks when system APIs fail
2. Test with both granted and denied permissions
3. Use async/await for EventKit APIs

## Files Created
- Sources/Services/RemindersService.swift
- Sources/Services/NotesService.swift
- Tests/RemindersServiceTests.swift
- Tests/NotesServiceTests.swift

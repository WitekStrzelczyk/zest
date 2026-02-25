import AppKit
import EventKit
import Foundation
import os.log

// MARK: - VideoLinkType

/// Represents the type of video conferencing platform
enum VideoLinkType: String, CaseIterable {
    case zoom = "zoom"
    case googleMeet = "googleMeet"
    case teams = "teams"
    case webex = "webex"
    case slack = "slack"
    case unknown = "unknown"

    /// Detect video link type from URL string
    static func from(urlString: String) -> VideoLinkType {
        let lowercased = urlString.lowercased()

        // Zoom patterns: zoom.us/j/, zoom.us/s/, zoom.us/w/, zoom.us/my/
        if lowercased.contains("zoom.us/j/") ||
            lowercased.contains("zoom.us/s/") ||
            lowercased.contains("zoom.us/w/") ||
            lowercased.contains("zoom.us/my/") ||
            lowercased.contains(".zoom.us/j/") ||
            lowercased.contains(".zoom.us/s/") {
            return .zoom
        }

        // Google Meet
        if lowercased.contains("meet.google.com") {
            return .googleMeet
        }

        // Microsoft Teams
        if lowercased.contains("teams.microsoft.com") || lowercased.contains("teams.live.com") {
            return .teams
        }

        // WebEx
        if lowercased.contains("webex.com") {
            return .webex
        }

        // Slack
        if lowercased.contains("slack.com/call") {
            return .slack
        }

        return .unknown
    }

    /// Display name for the video platform
    var displayName: String {
        switch self {
        case .zoom: return "Zoom"
        case .googleMeet: return "Google Meet"
        case .teams: return "Microsoft Teams"
        case .webex: return "WebEx"
        case .slack: return "Slack"
        case .unknown: return "Video Call"
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        "video.fill"
    }
}

// MARK: - CalendarEvent

/// Represents a calendar event
struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let calendarName: String
    let videoLink: URL?

    // MARK: - Computed Properties

    /// Duration in seconds
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    /// Duration in minutes
    var durationMinutes: Int {
        Int(duration / 60)
    }

    /// Whether this is an all-day event
    var isAllDay: Bool {
        // All-day events typically span 24 hours and start at midnight
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startDate)
        return duration >= 86400 && startHour == 0
    }

    /// Whether the event is currently in progress
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    /// Whether the event is in the future
    var isUpcoming: Bool {
        startDate > Date()
    }

    /// Time until the event starts (in seconds), negative if already started
    var timeUntilStart: TimeInterval {
        startDate.timeIntervalSinceNow
    }

    /// Minutes until the event starts
    var minutesUntilStart: Int {
        Int(timeUntilStart / 60)
    }

    /// Whether the event has a video link
    var hasVideoLink: Bool {
        videoLink != nil
    }

    /// How many minutes ago the event ended (nil if not ended yet)
    var endedMinutesAgo: Int? {
        let now = Date()
        guard now > endDate else { return nil }
        return Int(now.timeIntervalSince(endDate) / 60)
    }

    /// Whether the event ended recently (within specified minutes)
    func isRecent(withinMinutes minutes: Int) -> Bool {
        guard let endedAgo = endedMinutesAgo else { return false }
        return endedAgo <= minutes
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - MeetingInsights

/// Insights about today's meetings
struct MeetingInsights {
    let totalMeetingsToday: Int
    let totalMeetingMinutes: Int
    let nextFreeSlotStart: Date?
    let nextFreeSlotEnd: Date?

    /// Total meeting time in hours
    var totalMeetingHours: Double {
        Double(totalMeetingMinutes) / 60.0
    }

    /// Whether there's a free time slot available
    var hasFreeTime: Bool {
        nextFreeSlotStart != nil && nextFreeSlotEnd != nil
    }

    /// Formatted string for the free time slot
    var formattedFreeSlot: String {
        guard let start = nextFreeSlotStart, let end = nextFreeSlotEnd else {
            return "No free slots today"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - CalendarService

/// Service for accessing calendar events via EventKit
final class CalendarService: @unchecked Sendable {
    // MARK: - Singleton

    static let shared = CalendarService()

    // MARK: - Properties

    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: "com.zest.app", category: "Calendar")
    private var hasAccess = false

    /// Cached events (refreshed every 30 seconds)
    private var cachedEvents: [CalendarEvent] = []
    private var lastCacheTime: Date?
    private let cacheTimeout: TimeInterval = 30

    /// Calendar search keywords
    private let calendarKeywords = [
        "calendar", "schedule", "meeting", "meetings", "event", "events",
        "join", "call", "video", "zoom", "teams", "meet"
    ]

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Request access to Calendar
    func requestCalendarAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                hasAccess = granted
                return granted
            } catch {
                logger.error("Error requesting Calendar access: \(error.localizedDescription)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { [weak self] granted, error in
                    if let error {
                        self?.logger.error("Error requesting Calendar access: \(error.localizedDescription)")
                    }
                    self?.hasAccess = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Check if we have calendar access
    func hasCalendarAccess() -> Bool {
        hasAccess
    }

    /// Get upcoming events for the next N days
    func getUpcomingEvents(days: Int = 7) async -> [CalendarEvent] {
        if !hasAccess {
            let granted = await requestCalendarAccess()
            guard granted else { return [] }
        }

        // Check cache
        if let lastTime = lastCacheTime,
           Date().timeIntervalSince(lastTime) < cacheTimeout {
            return cachedEvents.filter { $0.startDate >= Date() }
        }

        let calendar = Calendar.current
        let now = Date()
        guard let endDate = calendar.date(byAdding: .day, value: days, to: now) else {
            return []
        }

        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: calendars)

        let ekEvents = eventStore.events(matching: predicate)
        let events = ekEvents.map { convertToCalendarEvent($0) }

        // Update cache
        cachedEvents = events
        lastCacheTime = Date()

        return events
    }

    /// Get the next meeting that has a video link
    func getNextMeetingWithLink() async -> CalendarEvent? {
        let events = await getUpcomingEvents(days: 1)

        // Find the next event with a video link that hasn't started yet
        return events
            .filter { $0.hasVideoLink && !$0.isActive }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    /// Get meetings that are currently in progress
    func getActiveMeetings() async -> [CalendarEvent] {
        let events = await getUpcomingEvents(days: 1)
        return events.filter { $0.isActive }
    }

    /// Get meetings that ended recently (within specified minutes)
    func getRecentMeetings(withinMinutes minutes: Int = 60) async -> [CalendarEvent] {
        // Need to fetch events from the past as well
        if !hasAccess {
            let granted = await requestCalendarAccess()
            guard granted else { return [] }
        }

        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .minute, value: -minutes - 480, to: now) else {
            return []
        }

        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: now, calendars: calendars)

        let ekEvents = eventStore.events(matching: predicate)
        let events = ekEvents.map { convertToCalendarEvent($0) }

        return events.filter { $0.isRecent(withinMinutes: minutes) }
    }

    /// Get insights about today's meetings
    func getTodayInsights() async -> MeetingInsights {
        if !hasAccess {
            let granted = await requestCalendarAccess()
            guard granted else {
                return MeetingInsights(totalMeetingsToday: 0, totalMeetingMinutes: 0, nextFreeSlotStart: nil, nextFreeSlotEnd: nil)
            }
        }

        let calendar = Calendar.current
        let now = Date()

        // Get start and end of today
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return MeetingInsights(totalMeetingsToday: 0, totalMeetingMinutes: 0, nextFreeSlotStart: nil, nextFreeSlotEnd: nil)
        }

        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)

        let ekEvents = eventStore.events(matching: predicate)
        let events = ekEvents
            .map { convertToCalendarEvent($0) }
            .filter { !$0.isAllDay }

        let totalMinutes = events.reduce(0) { $0 + $1.durationMinutes }
        let freeSlot = findNextFreeSlot(duration: 30, events: events)

        return MeetingInsights(
            totalMeetingsToday: events.count,
            totalMeetingMinutes: totalMinutes,
            nextFreeSlotStart: freeSlot?.start,
            nextFreeSlotEnd: freeSlot?.end
        )
    }

    /// Find the next free time slot of the specified duration
    func findNextFreeSlot(duration: Int = 30) async -> (start: Date, end: Date)? {
        let events = await getUpcomingEvents(days: 1)
        return findNextFreeSlot(duration: duration, events: events)
    }

    /// Parse video link from location or notes string
    func parseVideoLink(from text: String?) -> URL? {
        guard let text, !text.isEmpty else { return nil }

        // Video URL patterns to look for
        let patterns = [
            // Zoom
            #"https?://[^\s]*?\.?zoom\.us/[jswmy]/[^\s]+"#,
            // Google Meet
            #"https?://meet\.google\.com/[^\s]+"#,
            // Microsoft Teams
            #"https?://teams\.microsoft\.com/[^\s]+"#,
            #"https?://teams\.live\.com/[^\s]+"#,
            // WebEx
            #"https?://[^\s]*?\.?webex\.com/[^\s]+"#,
            // Slack
            #"https?://slack\.com/call/[^\s]+"#
        ]

        for pattern in patterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let urlString = String(text[range])
                // Clean up common trailing characters
                let cleanURL = urlString
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))

                if let url = URL(string: cleanURL) {
                    return url
                }
            }
        }

        return nil
    }

    /// Open a video meeting URL
    func joinMeeting(url: URL) {
        NSWorkspace.shared.open(url)
        logger.info("Opening meeting URL: \(url.absoluteString)")
    }

    // MARK: - Search Integration

    /// Check if query matches calendar-related keywords
    func matchesCalendarKeywords(query: String) -> Bool {
        let lowercased = query.lowercased()
        return calendarKeywords.contains { keyword in
            lowercased.contains(keyword) || keyword.contains(lowercased)
        }
    }

    /// Search for calendar events and meeting-related results
    func search(query: String) async -> [SearchResult] {
        let lowercasedQuery = query.lowercased()

        guard !lowercasedQuery.isEmpty else { return [] }
        guard matchesCalendarKeywords(query: lowercasedQuery) else { return [] }

        var results: [SearchResult] = []

        // Check for "join" - show next meeting with video link
        if lowercasedQuery.contains("join") {
            if let nextMeeting = await getNextMeetingWithLink() {
                results.append(createJoinMeetingResult(for: nextMeeting))
            } else {
                // No upcoming video meetings
                results.append(SearchResult(
                    title: "No upcoming meetings with video links",
                    subtitle: "No meetings detected in the next 24 hours",
                    icon: NSImage(systemSymbolName: "video.slash", accessibilityDescription: "No Meeting"),
                    category: .calendar,
                    action: {},
                    score: 100
                ))
            }
        }

        // Check for "meetings today" - show insights
        if lowercasedQuery.contains("today") || lowercasedQuery.contains("insight") {
            let insights = await getTodayInsights()
            results.append(createInsightsResult(for: insights))
        }

        // Show calendar events for "calendar", "schedule", "meeting" queries
        if lowercasedQuery.contains("calendar") ||
            lowercasedQuery.contains("schedule") ||
            lowercasedQuery.contains("meeting") ||
            lowercasedQuery.contains("event") {

            // Get active meetings
            let activeMeetings = await getActiveMeetings()
            for meeting in activeMeetings {
                results.append(createActiveMeetingResult(for: meeting))
            }

            // Get recent meetings
            let recentMeetings = await getRecentMeetings(withinMinutes: 60)
            for meeting in recentMeetings {
                results.append(createRecentMeetingResult(for: meeting))
            }

            // Get upcoming events
            let events = await getUpcomingEvents(days: 3)
            for event in events.prefix(5) where !event.isActive && !event.isRecent(withinMinutes: 60) {
                results.append(createEventResult(for: event))
            }
        }

        return results
    }

    /// Synchronous search wrapper for compatibility
    /// Uses cached events if available, otherwise returns empty results
    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()

        guard !lowercasedQuery.isEmpty else { return [] }
        guard matchesCalendarKeywords(query: lowercasedQuery) else { return [] }

        // If we don't have cached events, return empty (async search will populate cache)
        guard !cachedEvents.isEmpty else { return [] }

        var results: [SearchResult] = []

        // Check for "join" - show next meeting with video link
        if lowercasedQuery.contains("join") {
            let nextMeeting = cachedEvents
                .filter { $0.hasVideoLink && !$0.isActive && $0.startDate > Date() }
                .sorted { $0.startDate < $1.startDate }
                .first

            if let nextMeeting {
                results.append(createJoinMeetingResult(for: nextMeeting))
            } else {
                results.append(SearchResult(
                    title: "No upcoming meetings with video links",
                    subtitle: "No meetings detected in the next 24 hours",
                    icon: NSImage(systemSymbolName: "video.slash", accessibilityDescription: "No Meeting"),
                    category: .calendar,
                    action: {},
                    score: 100
                ))
            }
        }

        // Show calendar events for "calendar", "schedule", "meeting" queries
        if lowercasedQuery.contains("calendar") ||
            lowercasedQuery.contains("schedule") ||
            lowercasedQuery.contains("meeting") ||
            lowercasedQuery.contains("event") {

            // Get active meetings
            let activeMeetings = cachedEvents.filter { $0.isActive }
            for meeting in activeMeetings {
                results.append(createActiveMeetingResult(for: meeting))
            }

            // Get recent meetings
            let recentMeetings = cachedEvents.filter { $0.isRecent(withinMinutes: 60) && !$0.isActive }
            for meeting in recentMeetings {
                results.append(createRecentMeetingResult(for: meeting))
            }

            // Get upcoming events
            let upcomingEvents = cachedEvents
                .filter { !$0.isActive && !$0.isRecent(withinMinutes: 60) && $0.startDate > Date() }
                .sorted { $0.startDate < $1.startDate }

            for event in upcomingEvents.prefix(5) {
                results.append(createEventResult(for: event))
            }
        }

        return results
    }

    /// Preload calendar cache (call on app launch)
    func preloadCache() async {
        _ = await getUpcomingEvents(days: 7)
    }

    // MARK: - Formatting Helpers

    /// Format relative time from now (in minutes)
    func formatRelativeTime(minutesFromNow: Int) -> String {
        if minutesFromNow == 0 {
            return "Starting now"
        } else if minutesFromNow < 0 {
            let absMinutes = abs(minutesFromNow)
            if absMinutes < 60 {
                return "Ended \(absMinutes) min ago"
            } else {
                let hours = absMinutes / 60
                let mins = absMinutes % 60
                if mins == 0 {
                    return "Ended \(hours) hr ago"
                }
                return "Ended \(hours) hr \(mins) min ago"
            }
        } else {
            if minutesFromNow < 60 {
                return "in \(minutesFromNow) min"
            } else {
                let hours = minutesFromNow / 60
                let mins = minutesFromNow % 60
                if mins == 0 {
                    return "in \(hours) hr"
                }
                return "in \(hours) hr \(mins) min"
            }
        }
    }

    /// Format event time (e.g., "2:30 PM")
    func formatEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Format event date range (e.g., "2:00 PM - 3:30 PM")
    func formatEventDateRange(start: Date, end: Date) -> String {
        let startStr = formatEventTime(start)
        let endStr = formatEventTime(end)
        return "\(startStr) - \(endStr)"
    }

    // MARK: - Private Helpers

    private func convertToCalendarEvent(_ ekEvent: EKEvent) -> CalendarEvent {
        // Try to parse video link from location or notes
        var videoLink: URL?
        if let location = ekEvent.location {
            videoLink = parseVideoLink(from: location)
        }
        if videoLink == nil, let notes = ekEvent.notes {
            videoLink = parseVideoLink(from: notes)
        }
        if videoLink == nil, let url = ekEvent.url {
            // Check if the URL is a video meeting link
            let urlString = url.absoluteString
            if VideoLinkType.from(urlString: urlString) != .unknown {
                videoLink = url
            }
        }

        return CalendarEvent(
            id: ekEvent.eventIdentifier,
            title: ekEvent.title ?? "Untitled Event",
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            location: ekEvent.location,
            notes: ekEvent.notes,
            calendarName: ekEvent.calendar?.title ?? "Calendar",
            videoLink: videoLink
        )
    }

    private func findNextFreeSlot(duration: Int, events: [CalendarEvent]) -> (start: Date, end: Date)? {
        let now = Date()
        let calendar = Calendar.current
        let endOfWorkDay = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now.addingTimeInterval(28800)

        // Get upcoming events sorted by start time
        let upcomingEvents = events
            .filter { $0.startDate > now && !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        var checkTime = now

        for event in upcomingEvents {
            // Check if there's a gap before this event
            let gapMinutes = Int(event.startDate.timeIntervalSince(checkTime) / 60)
            if gapMinutes >= duration {
                // Found a gap! Return the slot
                let slotEnd = min(event.startDate, endOfWorkDay)
                return (start: checkTime, end: slotEnd)
            }
            // Move check time to end of this event
            if event.endDate > checkTime {
                checkTime = event.endDate
            }
        }

        // No events blocking - return time until end of work day
        if checkTime < endOfWorkDay {
            return (start: checkTime, end: endOfWorkDay)
        }

        return nil
    }

    // MARK: - Search Result Creation

    private func createJoinMeetingResult(for event: CalendarEvent) -> SearchResult {
        let timeText = formatRelativeTime(minutesFromNow: event.minutesUntilStart)
        let videoType = event.videoLink.map { VideoLinkType.from(urlString: $0.absoluteString) } ?? .unknown

        return SearchResult(
            title: "Join: \(event.title) (\(timeText))",
            subtitle: "\(videoType.displayName) • \(event.calendarName)",
            icon: NSImage(systemSymbolName: videoType.iconName, accessibilityDescription: "Video Call"),
            category: .calendar,
            action: { [weak self] in
                if let url = event.videoLink {
                    self?.joinMeeting(url: url)
                }
            },
            score: 2000 // High score for join command
        )
    }

    private func createActiveMeetingResult(for event: CalendarEvent) -> SearchResult {
        return SearchResult(
            title: "🔴 \(event.title) (IN PROGRESS)",
            subtitle: formatEventDateRange(start: event.startDate, end: event.endDate),
            icon: NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Active Meeting"),
            category: .calendar,
            action: { [weak self] in
                if let url = event.videoLink {
                    self?.joinMeeting(url: url)
                }
            },
            score: 1500
        )
    }

    private func createRecentMeetingResult(for event: CalendarEvent) -> SearchResult {
        let endedAgo = event.endedMinutesAgo ?? 0
        let timeText = formatRelativeTime(minutesFromNow: -endedAgo)

        return SearchResult(
            title: "🟡 \(event.title) (Ended \(timeText))",
            subtitle: formatEventDateRange(start: event.startDate, end: event.endDate),
            icon: NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "Recent Meeting"),
            category: .calendar,
            action: { [weak self] in
                if let url = event.videoLink {
                    self?.joinMeeting(url: url)
                }
            },
            score: 1200
        )
    }

    private func createEventResult(for event: CalendarEvent) -> SearchResult {
        let locationText = event.location.map { " • \($0)" } ?? ""

        return SearchResult(
            title: event.title,
            subtitle: "\(formatEventDateRange(start: event.startDate, end: event.endDate))\(locationText)",
            icon: NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar Event"),
            category: .calendar,
            action: { [weak self] in
                if let url = event.videoLink {
                    self?.joinMeeting(url: url)
                }
            },
            score: 800
        )
    }

    private func createInsightsResult(for insights: MeetingInsights) -> SearchResult {
        let hoursStr = insights.totalMeetingHours.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(insights.totalMeetingHours))"
            : String(format: "%.1f", insights.totalMeetingHours)

        return SearchResult(
            title: "\(insights.totalMeetingsToday) meetings today (\(hoursStr) hours)",
            subtitle: "Next free slot: \(insights.formattedFreeSlot)",
            icon: NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "Meeting Insights"),
            category: .calendar,
            action: {},
            score: 900
        )
    }
}

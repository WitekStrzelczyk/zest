import AppKit
import EventKit
import Foundation
import os.log

enum VideoLinkType: String, CaseIterable {
    case zoom
    case googleMeet
    case teams
    case webex
    case slack
    case unknown

    static func from(urlString: String) -> VideoLinkType {
        let lowercased = urlString.lowercased()

        if lowercased.contains("zoom.us/j/") ||
            lowercased.contains("zoom.us/s/") ||
            lowercased.contains("zoom.us/w/") ||
            lowercased.contains("zoom.us/my/") ||
            lowercased.contains(".zoom.us/j/") ||
            lowercased.contains(".zoom.us/s/")
        {
            return .zoom
        }

        if lowercased.contains("meet.google.com") {
            return .googleMeet
        }

        if lowercased.contains("teams.microsoft.com") || lowercased.contains("teams.live.com") {
            return .teams
        }

        if lowercased.contains("webex.com") {
            return .webex
        }

        if lowercased.contains("slack.com/call") {
            return .slack
        }

        return .unknown
    }

    var displayName: String {
        switch self {
        case .zoom: "Zoom"
        case .googleMeet: "Google Meet"
        case .teams: "Microsoft Teams"
        case .webex: "WebEx"
        case .slack: "Slack"
        case .unknown: "Video Call"
        }
    }

    var iconName: String {
        switch self {
        case .zoom: "video.bubble.left.fill"
        case .googleMeet: "person.3.fill"
        case .teams: "rectangle.3.group.fill"
        case .webex: "network"
        case .slack: "bubble.left.and.bubble.right.fill"
        case .unknown: "video.fill"
        }
    }

    private static let icons: [VideoLinkType: NSImage] = Dictionary(uniqueKeysWithValues: allCases.compactMap { type in
        NSImage(systemSymbolName: type.iconName, accessibilityDescription: type.displayName).map { (type, $0) }
    })

    var icon: NSImage? {
        Self.icons[self]
    }
}

struct CalendarEvent: Identifiable, Hashable {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let calendarName: String
    let calendarColor: NSColor
    let videoLink: URL?
    let videoType: VideoLinkType

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    var isAllDay: Bool {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startDate)
        return duration >= 86400 && startHour == 0
    }

    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var isUpcoming: Bool {
        startDate > Date()
    }

    var timeUntilStart: TimeInterval {
        startDate.timeIntervalSinceNow
    }

    var minutesUntilStart: Int {
        Int(timeUntilStart / 60)
    }

    var hasVideoLink: Bool {
        videoLink != nil
    }

    var endedMinutesAgo: Int? {
        let now = Date()
        guard now > endDate else { return nil }
        return Int(now.timeIntervalSince(endDate) / 60)
    }

    func isRecent(withinMinutes minutes: Int) -> Bool {
        guard let endedAgo = endedMinutesAgo else { return false }
        return endedAgo <= minutes
    }

    var humanizedTimeUntil: String {
        let now = Date()

        if isActive {
            let elapsed = Int(now.timeIntervalSince(startDate) / 60)
            if elapsed < 1 {
                return "🔴 Started now"
            } else if elapsed < 60 {
                return "🔴 Started \(elapsed) min ago"
            } else {
                let hours = elapsed / 60
                let mins = elapsed % 60
                if mins == 0 {
                    return "🔴 Started \(hours)h ago"
                }
                return "🔴 Started \(hours)h \(mins)m ago"
            }
        } else if startDate > now {
            let until = Int(startDate.timeIntervalSinceNow / 60)
            if until < 1 {
                return "Starts now"
            } else if until < 60 {
                return "Starts in \(until) min"
            } else if until < 1440 {
                let hours = until / 60
                let mins = until % 60
                if mins == 0 {
                    return "Starts in \(hours)h"
                }
                return "Starts in \(hours)h \(mins)m"
            } else {
                let days = until / 1440
                return "Starts in \(days)d"
            }
        } else {
            let ended = Int(now.timeIntervalSince(endDate) / 60)
            if ended < 60 {
                return "Ended \(ended) min ago"
            } else {
                let hours = ended / 60
                return "Ended \(hours)h ago"
            }
        }
    }

    var formattedDate: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(startDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(startDate) {
            return "Tomorrow"
        } else {
            return Self.dayFormatter.string(from: startDate)
        }
    }

    var formattedTimeRange: String {
        "\(Self.timeFormatter.string(from: startDate)) - \(Self.timeFormatter.string(from: endDate))"
    }

    var durationText: String {
        let mins = durationMinutes
        if mins < 60 {
            return "\(mins) min"
        } else {
            let hours = mins / 60
            let remainMins = mins % 60
            if remainMins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainMins)m"
        }
    }

    var videoPlatformName: String {
        videoType.displayName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}

extension Notification.Name {
    static let calendarCacheUpdated = Notification.Name("calendarCacheUpdated")
}

final class CalendarService: @unchecked Sendable {
    static let shared = CalendarService()

    static var isDisabled = false

    private static let eventIcon = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar Event")
    private static let noMeetingIcon = NSImage(systemSymbolName: "video.slash", accessibilityDescription: "No Meeting")

    private let logger = Logger(subsystem: "com.zest.app", category: "Calendar")
    private let lock = NSLock()
    private var store: EKEventStore?
    private var cachedEvents: [CalendarEvent] = []
    private var lastCacheTime: Date?
    private var refreshInFlight = false
    private let cacheTimeout: TimeInterval = 60
    private let recentWindowMinutes = 60

    private let joinKeywords = ["join"]
    private let agendaKeywords = ["calendar", "schedule", "meeting", "meetings", "event", "events"]

    private init() {}

    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async {
        do {
            guard try await eventStore().requestFullAccessToEvents() else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .calendarCacheUpdated, object: nil)
            }
        } catch {
            logger.error("Calendar access request failed: \(error.localizedDescription)")
        }
    }

    func createEvent(title: String, startDate: Date, location: String? = nil) async throws {
        if !isAuthorized { await requestAccess() }
        guard isAuthorized else {
            throw NSError(
                domain: "CalendarService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Calendar access denied"]
            )
        }

        let store = eventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(3600)
        event.location = location
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
        logger.info("Created calendar event in \(event.calendar?.title ?? "default calendar")")
        refreshInBackground()
    }

    @discardableResult
    func refreshCache(notify: Bool = false) -> [CalendarEvent] {
        let now = Date()
        let calendar = Calendar.current
        guard isAuthorized,
              let end = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))
        else {
            lock.withLock { refreshInFlight = false }
            return []
        }

        let store = eventStore()
        let start = now.addingTimeInterval(-Double(recentWindowMinutes) * 60)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate).map(convertToCalendarEvent)

        lock.withLock {
            cachedEvents = events
            lastCacheTime = now
            refreshInFlight = false
        }

        if notify {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .calendarCacheUpdated, object: nil)
            }
        }
        return events
    }

    func parseVideoLink(from text: String?) -> URL? {
        guard let text, !text.isEmpty else { return nil }

        let patterns = [
            #"https?://[^\s]*?\.?zoom\.us/[jswmy]/[^\s]+"#,
            #"https?://meet\.google\.com/[^\s]+"#,
            #"https?://teams\.microsoft\.com/[^\s]+"#,
            #"https?://teams\.live\.com/[^\s]+"#,
            #"https?://[^\s]*?\.?webex\.com/[^\s]+"#,
            #"https?://slack\.com/call/[^\s]+"#,
        ]

        for pattern in patterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let urlString = String(text[range])
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

    func joinMeeting(url: URL) {
        NSWorkspace.shared.open(url)
        logger.info("Opening meeting URL: \(url.absoluteString)")
    }

    func matchesCalendarKeywords(query: String) -> Bool {
        let query = query.lowercased()
        return containsWord(query, from: joinKeywords) || containsWord(query, from: agendaKeywords)
    }

    func search(query: String) -> [SearchResult] {
        let query = query.lowercased()
        guard matchesCalendarKeywords(query: query) else { return [] }

        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return eventResults(for: query, events: currentEvents())
        case .notDetermined:
            return [PersonalDataAccess.requestResult(
                source: "Calendar",
                reason: "Zest reads today's and tomorrow's events to show and join your meetings",
                category: .calendar,
                request: { await self.requestAccess() }
            )]
        default:
            return [PersonalDataAccess.deniedResult(
                source: "Calendars",
                settingsAnchor: "Privacy_Calendars",
                category: .calendar
            )]
        }
    }

    private func containsWord(_ query: String, from keywords: [String]) -> Bool {
        let padded = " \(query) "
        return keywords.contains { padded.contains(" \($0) ") }
    }

    private func eventStore() -> EKEventStore {
        lock.withLock {
            if let store { return store }
            let created = EKEventStore()
            store = created
            return created
        }
    }

    private func currentEvents() -> [CalendarEvent] {
        let (cached, loaded, stale) = lock.withLock {
            let stale = lastCacheTime.map { Date().timeIntervalSince($0) >= cacheTimeout } ?? true
            return (cachedEvents, lastCacheTime != nil, stale)
        }
        guard loaded else { return refreshCache() }
        if stale { refreshInBackground() }
        return cached
    }

    private func refreshInBackground() {
        let start = lock.withLock {
            guard !refreshInFlight else { return false }
            refreshInFlight = true
            return true
        }
        guard start else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refreshCache(notify: true)
        }
    }

    private func eventResults(for query: String, events: [CalendarEvent]) -> [SearchResult] {
        var results: [SearchResult] = []
        let now = Date()

        if containsWord(query, from: joinKeywords) {
            let nextMeeting = events
                .filter { $0.hasVideoLink && $0.startDate > now }
                .min { $0.startDate < $1.startDate }

            if let nextMeeting {
                results.append(createJoinMeetingResult(for: nextMeeting))
            } else {
                results.append(SearchResult(
                    title: "No upcoming meetings with video links",
                    subtitle: "No meetings detected through end of tomorrow",
                    icon: Self.noMeetingIcon,
                    category: .calendar,
                    action: {},
                    score: 100
                ))
            }
        }

        guard containsWord(query, from: agendaKeywords) else { return results }

        results += events.filter(\.isActive).map(createActiveMeetingResult)
        results += events.filter { $0.isRecent(withinMinutes: recentWindowMinutes) }.map(createRecentMeetingResult)
        results += events
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(5)
            .map(createEventResult)

        return results
    }
    private func convertToCalendarEvent(_ ekEvent: EKEvent) -> CalendarEvent {
        var videoLink: URL?
        if let location = ekEvent.location {
            videoLink = parseVideoLink(from: location)
        }
        if videoLink == nil, let notes = ekEvent.notes {
            videoLink = parseVideoLink(from: notes)
        }
        if videoLink == nil, let url = ekEvent.url {
            let urlString = url.absoluteString
            if VideoLinkType.from(urlString: urlString) != .unknown {
                videoLink = url
            }
        }

        let videoType: VideoLinkType = if let link = videoLink {
            VideoLinkType.from(urlString: link.absoluteString)
        } else {
            .unknown
        }

        let calendarColor: NSColor = if let cgColor = ekEvent.calendar?.cgColor {
            NSColor(cgColor: cgColor) ?? .systemBlue
        } else {
            .systemBlue
        }

        return CalendarEvent(
            id: ekEvent.eventIdentifier,
            title: ekEvent.title ?? "Untitled Event",
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            location: ekEvent.location,
            notes: ekEvent.notes,
            calendarName: ekEvent.calendar?.title ?? "Calendar",
            calendarColor: calendarColor,
            videoLink: videoLink,
            videoType: videoType
        )
    }

    private func createJoinMeetingResult(for event: CalendarEvent) -> SearchResult {
        SearchResult(
            title: event.title,
            subtitle: "\(event.formattedDate) • \(event.formattedTimeRange) • \(event.humanizedTimeUntil)",
            icon: Self.eventIcon,
            category: .calendar,
            action: { [weak self] in
                if let url = event.videoLink {
                    self?.joinMeeting(url: url)
                }
            },
            score: 2000,
            tintColor: event.calendarColor,
            trailingIcon: event.videoType.icon
        )
    }

    private func createActiveMeetingResult(for event: CalendarEvent) -> SearchResult {
        SearchResult(
            title: "🔴 \(event.title)",
            subtitle: "\(event.formattedDate) • \(event.formattedTimeRange) • \(event.durationText) • In Progress",
            icon: Self.eventIcon,
            category: .calendar,
            action: { [weak self] in
                if let url = event.videoLink {
                    self?.joinMeeting(url: url)
                }
            },
            score: 1500,
            tintColor: event.calendarColor,
            trailingIcon: event.hasVideoLink ? event.videoType.icon : nil
        )
    }

    private func createRecentMeetingResult(for event: CalendarEvent) -> SearchResult {
        let endedAgo = event.endedMinutesAgo ?? 0
        let timeText = endedAgo < 60 ? "\(endedAgo) min ago" : "\(endedAgo / 60)h ago"

        return SearchResult(
            title: "🟡 \(event.title)",
            subtitle: "\(event.formattedDate) • \(event.formattedTimeRange) • Ended \(timeText)",
            icon: Self.eventIcon,
            category: .calendar,
            action: { [weak self] in
                if let url = event.videoLink {
                    self?.joinMeeting(url: url)
                }
            },
            score: 1200,
            tintColor: event.calendarColor,
            trailingIcon: event.hasVideoLink ? event.videoType.icon : nil
        )
    }

    private func createEventResult(for event: CalendarEvent) -> SearchResult {
        let locationText = if let location = event.location {
            if location.contains("zoom.us") || location.contains("meet.google.com") ||
                location.contains("teams.microsoft.com") || location.contains("webex.com")
            {
                ""
            } else {
                " • \(location)"
            }
        } else {
            ""
        }

        let dateRange = "\(event.formattedDate) • \(event.formattedTimeRange)"
        let durationUntil = "\(event.durationText) • \(event.humanizedTimeUntil)\(locationText)"
        let subtitle = "\(dateRange) • \(durationUntil)"
        return SearchResult(
            title: event.title,
            subtitle: subtitle,
            icon: Self.eventIcon,
            category: .calendar,
            action: { [weak self] in
                if let url = event.videoLink {
                    self?.joinMeeting(url: url)
                }
            },
            score: 800,
            tintColor: event.calendarColor,
            trailingIcon: event.hasVideoLink ? event.videoType.icon : nil
        )
    }
}

extension CalendarService: SearchTool {
    var name: String { "Calendar (System)" }

    func search(_ context: QueryContext) -> [SearchResult] {
        guard !Self.isDisabled else { return [] }
        return search(query: context.normalized)
    }
}

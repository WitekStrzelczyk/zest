import XCTest
@testable import ZestApp

/// Tests for CalendarService - Calendar integration using EventKit
/// Note: EventKit requires permissions that may not be available in unit tests.
/// Tests focus on:
/// - Model logic (CalendarEvent, MeetingInsights, VideoLinkType) - fully testable
/// - Video link parsing - fully testable
/// - Time calculations - fully testable
final class CalendarServiceTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Helper to create CalendarEvent with sensible defaults
    private func makeEvent(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        calendarName: String = "Test",
        calendarColor: NSColor = .systemBlue,
        videoLink: URL? = nil,
        videoType: VideoLinkType = .unknown
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: notes,
            calendarName: calendarName,
            calendarColor: calendarColor,
            videoLink: videoLink,
            videoType: videoType
        )
    }

    // MARK: - CalendarEvent Model Tests

    /// Test CalendarEvent model initialization
    func testCalendarEventCreation() {
        let now = Date()
        let event = makeEvent(
            id: "test-id-123",
            title: "Team Standup",
            startDate: now,
            endDate: now.addingTimeInterval(1800),
            location: "Conference Room A",
            notes: "Daily sync",
            calendarName: "Work",
            videoLink: URL(string: "https://zoom.us/j/123456789")
        )

        XCTAssertEqual(event.id, "test-id-123")
        XCTAssertEqual(event.title, "Team Standup")
        XCTAssertEqual(event.location, "Conference Room A")
        XCTAssertEqual(event.notes, "Daily sync")
        XCTAssertEqual(event.calendarName, "Work")
        XCTAssertNotNil(event.videoLink)
    }

    /// Test CalendarEvent isAllDay calculation
    func testCalendarEventIsAllDay() {
        // Create an all-day event (duration = 24 hours starting at midnight)
        let calendar = Calendar.current
        let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
        let allDayEvent = makeEvent(
            id: "1",
            title: "All Day Event",
            startDate: midnight,
            endDate: midnight.addingTimeInterval(86400),
            location: nil,
            notes: nil,
            calendarName: "Personal",
            videoLink: nil
        )

        XCTAssertTrue(allDayEvent.isAllDay, "Event spanning 24 hours from midnight should be all-day")
    }

    /// Test CalendarEvent isAllDay for non-all-day event
    func testCalendarEventIsNotAllDay() {
        let now = Date()
        let shortEvent = makeEvent(
            id: "2",
            title: "Quick Meeting",
            startDate: now,
            endDate: now.addingTimeInterval(1800), // 30 minutes
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertFalse(shortEvent.isAllDay, "30-minute event should not be all-day")
    }

    /// Test CalendarEvent duration
    func testCalendarEventDuration() {
        let now = Date()
        let event = makeEvent(
            id: "3",
            title: "1 Hour Meeting",
            startDate: now,
            endDate: now.addingTimeInterval(3600),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertEqual(event.duration, 3600, "Duration should be 3600 seconds (1 hour)")
    }

    /// Test CalendarEvent durationMinutes
    func testCalendarEventDurationMinutes() {
        let now = Date()
        let event = makeEvent(
            id: "4",
            title: "45 Min Meeting",
            startDate: now,
            endDate: now.addingTimeInterval(2700),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertEqual(event.durationMinutes, 45, "Duration should be 45 minutes")
    }

    /// Test CalendarEvent isActive when event is in progress
    func testCalendarEventIsActiveWhenInProgress() {
        let now = Date()
        let event = makeEvent(
            id: "5",
            title: "Active Meeting",
            startDate: now.addingTimeInterval(-900), // started 15 min ago
            endDate: now.addingTimeInterval(900), // ends in 15 min
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertTrue(event.isActive, "Event should be active when current time is between start and end")
    }

    /// Test CalendarEvent isActive when event hasn't started
    func testCalendarEventIsActiveWhenNotStarted() {
        let now = Date()
        let event = makeEvent(
            id: "6",
            title: "Future Meeting",
            startDate: now.addingTimeInterval(3600), // starts in 1 hour
            endDate: now.addingTimeInterval(7200),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertFalse(event.isActive, "Event should not be active when it hasn't started yet")
    }

    /// Test CalendarEvent isActive when event has ended
    func testCalendarEventIsActiveWhenEnded() {
        let now = Date()
        let event = makeEvent(
            id: "7",
            title: "Past Meeting",
            startDate: now.addingTimeInterval(-7200), // started 2 hours ago
            endDate: now.addingTimeInterval(-3600), // ended 1 hour ago
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertFalse(event.isActive, "Event should not be active when it has ended")
    }

    /// Test CalendarEvent isUpcoming
    func testCalendarEventIsUpcoming() {
        let now = Date()
        let event = makeEvent(
            id: "8",
            title: "Upcoming Meeting",
            startDate: now.addingTimeInterval(1800), // starts in 30 min
            endDate: now.addingTimeInterval(3600),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertTrue(event.isUpcoming, "Event starting in future should be upcoming")
    }

    /// Test CalendarEvent timeUntilStart
    func testCalendarEventTimeUntilStart() {
        let now = Date()
        let event = makeEvent(
            id: "9",
            title: "Future Meeting",
            startDate: now.addingTimeInterval(1800), // starts in 30 min
            endDate: now.addingTimeInterval(3600),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        let timeUntil = event.timeUntilStart
        XCTAssertGreaterThan(timeUntil, 1700, "Time until start should be ~1800 seconds")
        XCTAssertLessThan(timeUntil, 1900, "Time until start should be ~1800 seconds")
    }

    /// Test CalendarEvent minutesUntilStart
    func testCalendarEventMinutesUntilStart() {
        let now = Date()
        let event = makeEvent(
            id: "10",
            title: "Future Meeting",
            startDate: now.addingTimeInterval(1800), // starts in 30 min
            endDate: now.addingTimeInterval(3600),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        // Allow for slight timing variations (29-31 minutes)
        XCTAssertGreaterThanOrEqual(event.minutesUntilStart, 29, "Minutes until start should be ~30")
        XCTAssertLessThanOrEqual(event.minutesUntilStart, 31, "Minutes until start should be ~30")
    }

    /// Test CalendarEvent hasVideoLink
    func testCalendarEventHasVideoLinkTrue() {
        let event = makeEvent(
            id: "11",
            title: "Zoom Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: URL(string: "https://zoom.us/j/123456789")
        )

        XCTAssertTrue(event.hasVideoLink, "Event with video link should return true")
    }

    /// Test CalendarEvent hasVideoLink false
    func testCalendarEventHasVideoLinkFalse() {
        let event = makeEvent(
            id: "12",
            title: "In-Person Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: "Conference Room",
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertFalse(event.hasVideoLink, "Event without video link should return false")
    }

    /// Test CalendarEvent endedMinutesAgo
    func testCalendarEventEndedMinutesAgo() {
        let now = Date()
        let event = makeEvent(
            id: "13",
            title: "Recent Meeting",
            startDate: now.addingTimeInterval(-3600), // started 1 hour ago
            endDate: now.addingTimeInterval(-1800), // ended 30 min ago
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertEqual(event.endedMinutesAgo, 30, "Event should have ended 30 minutes ago")
    }

    /// Test CalendarEvent endedMinutesAgo for ongoing event
    func testCalendarEventEndedMinutesAgoOngoing() {
        let now = Date()
        let event = makeEvent(
            id: "14",
            title: "Active Meeting",
            startDate: now.addingTimeInterval(-1800),
            endDate: now.addingTimeInterval(1800),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertNil(event.endedMinutesAgo, "Ongoing event should have nil endedMinutesAgo")
    }

    /// Test CalendarEvent isRecent for recently ended event
    func testCalendarEventIsRecentTrue() {
        let now = Date()
        let event = makeEvent(
            id: "15",
            title: "Recent Meeting",
            startDate: now.addingTimeInterval(-3600),
            endDate: now.addingTimeInterval(-1800), // ended 30 min ago
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertTrue(event.isRecent(withinMinutes: 60), "Event ended 30 min ago should be recent within 60 min")
    }

    /// Test CalendarEvent isRecent for older event
    func testCalendarEventIsRecentFalse() {
        let now = Date()
        let event = makeEvent(
            id: "16",
            title: "Old Meeting",
            startDate: now.addingTimeInterval(-7200),
            endDate: now.addingTimeInterval(-5400), // ended 90 min ago
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        XCTAssertFalse(event.isRecent(withinMinutes: 60), "Event ended 90 min ago should not be recent within 60 min")
    }

    // MARK: - VideoLinkType Tests

    /// Test VideoLinkType detection for Zoom
    func testVideoLinkTypeZoom() {
        XCTAssertEqual(VideoLinkType.from(urlString: "https://zoom.us/j/123456789"), .zoom)
        XCTAssertEqual(VideoLinkType.from(urlString: "https://zoom.us/s/123456789"), .zoom)
        XCTAssertEqual(VideoLinkType.from(urlString: "https://zoom.us/w/123456789"), .zoom)
        XCTAssertEqual(VideoLinkType.from(urlString: "https://zoom.us/my/meeting"), .zoom)
        XCTAssertEqual(VideoLinkType.from(urlString: "https://company.zoom.us/j/123456789"), .zoom)
    }

    /// Test VideoLinkType detection for Google Meet
    func testVideoLinkTypeGoogleMeet() {
        XCTAssertEqual(VideoLinkType.from(urlString: "https://meet.google.com/abc-defg-hij"), .googleMeet)
    }

    /// Test VideoLinkType detection for Microsoft Teams
    func testVideoLinkTypeTeams() {
        XCTAssertEqual(VideoLinkType.from(urlString: "https://teams.microsoft.com/l/meetup-join/..."), .teams)
        XCTAssertEqual(VideoLinkType.from(urlString: "https://teams.live.com/meet/..."), .teams)
    }

    /// Test VideoLinkType detection for WebEx
    func testVideoLinkTypeWebEx() {
        XCTAssertEqual(VideoLinkType.from(urlString: "https://company.webex.com/meet/user"), .webex)
        XCTAssertEqual(VideoLinkType.from(urlString: "https://webex.com/meet/user"), .webex)
    }

    /// Test VideoLinkType detection for Slack
    func testVideoLinkTypeSlack() {
        XCTAssertEqual(VideoLinkType.from(urlString: "https://slack.com/call/12345"), .slack)
    }

    /// Test VideoLinkType detection for unknown
    func testVideoLinkTypeUnknown() {
        XCTAssertEqual(VideoLinkType.from(urlString: "https://example.com/meeting"), .unknown)
        XCTAssertEqual(VideoLinkType.from(urlString: ""), .unknown)
    }

    /// Test VideoLinkType displayName
    func testVideoLinkTypeDisplayName() {
        XCTAssertEqual(VideoLinkType.zoom.displayName, "Zoom")
        XCTAssertEqual(VideoLinkType.googleMeet.displayName, "Google Meet")
        XCTAssertEqual(VideoLinkType.teams.displayName, "Microsoft Teams")
        XCTAssertEqual(VideoLinkType.webex.displayName, "WebEx")
        XCTAssertEqual(VideoLinkType.slack.displayName, "Slack")
        XCTAssertEqual(VideoLinkType.unknown.displayName, "Video Call")
    }

    /// Test VideoLinkType icon names - platform-specific SF Symbols
    func testVideoLinkTypeIconNames() {
        XCTAssertEqual(VideoLinkType.zoom.iconName, "video.bubble.left.fill")
        XCTAssertEqual(VideoLinkType.googleMeet.iconName, "person.3.fill")
        XCTAssertEqual(VideoLinkType.teams.iconName, "rectangle.3.group.fill")
        XCTAssertEqual(VideoLinkType.webex.iconName, "network")
        XCTAssertEqual(VideoLinkType.slack.iconName, "bubble.left.and.bubble.right.fill")
        XCTAssertEqual(VideoLinkType.unknown.iconName, "video.fill")
    }

    // MARK: - Video Link Parsing Tests

    /// Test parsing Zoom link from location
    func testParseVideoLinkFromLocationZoom() {
        let url = CalendarService.shared.parseVideoLink(from: "https://zoom.us/j/123456789")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://zoom.us/j/123456789")
    }

    /// Test parsing Zoom link from notes
    func testParseVideoLinkFromNotesZoom() {
        let url = CalendarService.shared.parseVideoLink(from: "Join the meeting: https://zoom.us/j/123456789?pwd=abc123")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("zoom.us") ?? false)
    }

    /// Test parsing Google Meet link
    func testParseVideoLinkGoogleMeet() {
        let url = CalendarService.shared.parseVideoLink(from: "https://meet.google.com/abc-defg-hij")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("meet.google.com") ?? false)
    }

    /// Test parsing Teams link
    func testParseVideoLinkTeams() {
        let url = CalendarService.shared.parseVideoLink(from: "Join via Teams: https://teams.microsoft.com/l/meetup-join/123")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("teams.microsoft.com") ?? false)
    }

    /// Test parsing WebEx link
    func testParseVideoLinkWebEx() {
        let url = CalendarService.shared.parseVideoLink(from: "https://company.webex.com/meet/user")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("webex.com") ?? false)
    }

    /// Test parsing Slack call link
    func testParseVideoLinkSlack() {
        let url = CalendarService.shared.parseVideoLink(from: "https://slack.com/call/12345")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("slack.com/call") ?? false)
    }

    /// Test parsing no video link
    func testParseVideoLinkNone() {
        let url = CalendarService.shared.parseVideoLink(from: "Conference Room A")
        XCTAssertNil(url)
    }

    /// Test parsing from empty string
    func testParseVideoLinkEmpty() {
        let url = CalendarService.shared.parseVideoLink(from: "")
        XCTAssertNil(url)
    }

    /// Test parsing first video link when multiple present
    func testParseVideoLinkMultiple() {
        let url = CalendarService.shared.parseVideoLink(from: "Join: https://zoom.us/j/123 or https://meet.google.com/abc")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("zoom.us") ?? false, "Should return first video link found")
    }

    // MARK: - MeetingInsights Tests

    /// Test MeetingInsights initialization
    func testMeetingInsightsCreation() {
        let insights = MeetingInsights(
            totalMeetingsToday: 5,
            totalMeetingMinutes: 270,
            nextFreeSlotStart: Date().addingTimeInterval(7200),
            nextFreeSlotEnd: Date().addingTimeInterval(10800)
        )

        XCTAssertEqual(insights.totalMeetingsToday, 5)
        XCTAssertEqual(insights.totalMeetingMinutes, 270)
        XCTAssertEqual(insights.totalMeetingHours, 4.5, accuracy: 0.01)
    }

    /// Test MeetingInsights totalMeetingHours calculation
    func testMeetingInsightsHoursCalculation() {
        let insights = MeetingInsights(
            totalMeetingsToday: 3,
            totalMeetingMinutes: 150,
            nextFreeSlotStart: nil,
            nextFreeSlotEnd: nil
        )

        XCTAssertEqual(insights.totalMeetingHours, 2.5, accuracy: 0.01)
    }

    /// Test MeetingInsights hasFreeTime
    func testMeetingInsightsHasFreeTimeTrue() {
        let insights = MeetingInsights(
            totalMeetingsToday: 2,
            totalMeetingMinutes: 60,
            nextFreeSlotStart: Date(),
            nextFreeSlotEnd: Date().addingTimeInterval(3600)
        )

        XCTAssertTrue(insights.hasFreeTime, "Should have free time when nextFreeSlotStart is set")
    }

    /// Test MeetingInsights hasFreeTime false
    func testMeetingInsightsHasFreeTimeFalse() {
        let insights = MeetingInsights(
            totalMeetingsToday: 10,
            totalMeetingMinutes: 480,
            nextFreeSlotStart: nil,
            nextFreeSlotEnd: nil
        )

        XCTAssertFalse(insights.hasFreeTime, "Should not have free time when nextFreeSlotStart is nil")
    }

    /// Test MeetingInsights formattedFreeSlot
    func testMeetingInsightsFormattedFreeSlot() {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
        let end = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: Date())!

        let insights = MeetingInsights(
            totalMeetingsToday: 2,
            totalMeetingMinutes: 60,
            nextFreeSlotStart: start,
            nextFreeSlotEnd: end
        )

        let formatted = insights.formattedFreeSlot
        XCTAssertTrue(formatted.contains("3:00"), "Should contain start time")
        XCTAssertTrue(formatted.contains("5:00"), "Should contain end time")
    }

    /// Test MeetingInsights formattedFreeSlot when nil
    func testMeetingInsightsFormattedFreeSlotNil() {
        let insights = MeetingInsights(
            totalMeetingsToday: 10,
            totalMeetingMinutes: 480,
            nextFreeSlotStart: nil,
            nextFreeSlotEnd: nil
        )

        XCTAssertEqual(insights.formattedFreeSlot, "No free slots today")
    }

    // MARK: - CalendarService Singleton Tests

    func testCalendarServiceCreation() {
        XCTAssertNotNil(CalendarService.shared)
    }

    func testCalendarServiceSingleton() {
        let service1 = CalendarService.shared
        let service2 = CalendarService.shared
        XCTAssertTrue(service1 === service2)
    }

    // MARK: - Time Formatting Tests

    /// Test format relative time for future event
    func testFormatRelativeTimeFuture() {
        let timeString = CalendarService.shared.formatRelativeTime(minutesFromNow: 30)
        XCTAssertTrue(timeString.contains("30") && timeString.contains("min"))
    }

    /// Test format relative time for event in hours
    func testFormatRelativeTimeHours() {
        let timeString = CalendarService.shared.formatRelativeTime(minutesFromNow: 120)
        XCTAssertTrue(timeString.contains("2") && timeString.lowercased().contains("hr"))
    }

    /// Test format relative time for event starting now
    func testFormatRelativeTimeNow() {
        let timeString = CalendarService.shared.formatRelativeTime(minutesFromNow: 0)
        XCTAssertTrue(timeString.lowercased().contains("now"))
    }

    /// Test format relative time for past event
    func testFormatRelativeTimePast() {
        let timeString = CalendarService.shared.formatRelativeTime(minutesFromNow: -15)
        XCTAssertTrue(timeString.lowercased().contains("ended"))
    }

    // MARK: - Search Tests (Keywords)

    /// Test that calendar keywords are detected
    func testCalendarKeywordsDetected() {
        let service = CalendarService.shared

        XCTAssertTrue(service.matchesCalendarKeywords(query: "calendar"))
        XCTAssertTrue(service.matchesCalendarKeywords(query: "schedule"))
        XCTAssertTrue(service.matchesCalendarKeywords(query: "meetings today"))
        XCTAssertTrue(service.matchesCalendarKeywords(query: "join"))
        XCTAssertTrue(service.matchesCalendarKeywords(query: "meeting"))
    }

    /// Test that non-calendar keywords are not detected
    func testNonCalendarKeywordsNotDetected() {
        let service = CalendarService.shared

        XCTAssertFalse(service.matchesCalendarKeywords(query: "xyzabc"))
        XCTAssertFalse(service.matchesCalendarKeywords(query: "battery"))
        XCTAssertFalse(service.matchesCalendarKeywords(query: ""))
    }

    // MARK: - Event Formatting Tests

    /// Test format event time
    func testFormatEventTime() {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!

        let formatted = CalendarService.shared.formatEventTime(date)
        XCTAssertTrue(formatted.contains("2:30"), "Should contain 2:30")
    }

    /// Test format event date range
    func testFormatEventDateRange() {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        let end = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!

        let formatted = CalendarService.shared.formatEventDateRange(start: start, end: end)
        XCTAssertTrue(formatted.contains("2:00"), "Should contain start time")
        XCTAssertTrue(formatted.contains("3:30"), "Should contain end time")
    }
}

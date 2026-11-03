import AppKit
import Testing
@testable import ZestApp

@MainActor
final class CalendarServiceTests {
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

    @Test func testCalendarEventCreation() {
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

        #expect(event.id == "test-id-123")
        #expect(event.title == "Team Standup")
        #expect(event.location == "Conference Room A")
        #expect(event.notes == "Daily sync")
        #expect(event.calendarName == "Work")
        #expect(event.videoLink != nil)
    }

    @Test func testCalendarEventIsAllDay() {
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

        #expect(allDayEvent.isAllDay, "Event spanning 24 hours from midnight should be all-day")
    }

    @Test func testCalendarEventIsNotAllDay() {
        let now = Date()
        let shortEvent = makeEvent(
            id: "2",
            title: "Quick Meeting",
            startDate: now,
            endDate: now.addingTimeInterval(1800),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        #expect(!shortEvent.isAllDay, "30-minute event should not be all-day")
    }

    @Test func testCalendarEventDuration() {
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

        #expect(event.duration == 3600, "Duration should be 3600 seconds (1 hour)")
    }

    @Test func testCalendarEventDurationMinutes() {
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

        #expect(event.durationMinutes == 45, "Duration should be 45 minutes")
    }

    @Test func testCalendarEventIsActiveWhenInProgress() {
        let now = Date()
        let event = makeEvent(
            id: "5",
            title: "Active Meeting",
            startDate: now.addingTimeInterval(-900),
            endDate: now.addingTimeInterval(900),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        #expect(event.isActive, "Event should be active when current time is between start and end")
    }

    @Test func testCalendarEventIsActiveWhenNotStarted() {
        let now = Date()
        let event = makeEvent(
            id: "6",
            title: "Future Meeting",
            startDate: now.addingTimeInterval(3600),
            endDate: now.addingTimeInterval(7200),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        #expect(!event.isActive, "Event should not be active when it hasn't started yet")
    }

    @Test func testCalendarEventIsActiveWhenEnded() {
        let now = Date()
        let event = makeEvent(
            id: "7",
            title: "Past Meeting",
            startDate: now.addingTimeInterval(-7200),
            endDate: now.addingTimeInterval(-3600),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        #expect(!event.isActive, "Event should not be active when it has ended")
    }

    @Test func testCalendarEventIsUpcoming() {
        let now = Date()
        let event = makeEvent(
            id: "8",
            title: "Upcoming Meeting",
            startDate: now.addingTimeInterval(1800),
            endDate: now.addingTimeInterval(3600),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        #expect(event.isUpcoming, "Event starting in future should be upcoming")
    }

    @Test func testCalendarEventTimeUntilStart() {
        let now = Date()
        let event = makeEvent(
            id: "9",
            title: "Future Meeting",
            startDate: now.addingTimeInterval(1800),
            endDate: now.addingTimeInterval(3600),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        let timeUntil = event.timeUntilStart
        #expect(timeUntil > 1700, "Time until start should be ~1800 seconds")
        #expect(timeUntil < 1900, "Time until start should be ~1800 seconds")
    }

    @Test func testCalendarEventMinutesUntilStart() {
        let now = Date()
        let event = makeEvent(
            id: "10",
            title: "Future Meeting",
            startDate: now.addingTimeInterval(1800),
            endDate: now.addingTimeInterval(3600),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        #expect(event.minutesUntilStart >= 29, "Minutes until start should be ~30")
        #expect(event.minutesUntilStart <= 31, "Minutes until start should be ~30")
    }

    @Test func testCalendarEventHasVideoLinkTrue() {
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

        #expect(event.hasVideoLink, "Event with video link should return true")
    }

    @Test func testCalendarEventHasVideoLinkFalse() {
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

        #expect(!event.hasVideoLink, "Event without video link should return false")
    }

    @Test func testCalendarEventEndedMinutesAgo() {
        let now = Date()
        let event = makeEvent(
            id: "13",
            title: "Recent Meeting",
            startDate: now.addingTimeInterval(-3600),
            endDate: now.addingTimeInterval(-1800),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        #expect(event.endedMinutesAgo == 30, "Event should have ended 30 minutes ago")
    }

    @Test func testCalendarEventEndedMinutesAgoOngoing() {
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

        #expect(event.endedMinutesAgo == nil, "Ongoing event should have nil endedMinutesAgo")
    }

    @Test func testCalendarEventIsRecentTrue() {
        let now = Date()
        let event = makeEvent(
            id: "15",
            title: "Recent Meeting",
            startDate: now.addingTimeInterval(-3600),
            endDate: now.addingTimeInterval(-1800),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        #expect(event.isRecent(withinMinutes: 60), "Event ended 30 min ago should be recent within 60 min")
    }

    @Test func testCalendarEventIsRecentFalse() {
        let now = Date()
        let event = makeEvent(
            id: "16",
            title: "Old Meeting",
            startDate: now.addingTimeInterval(-7200),
            endDate: now.addingTimeInterval(-5400),
            location: nil,
            notes: nil,
            calendarName: "Work",
            videoLink: nil
        )

        #expect(!event.isRecent(withinMinutes: 60), "Event ended 90 min ago should not be recent within 60 min")
    }

    @Test func testVideoLinkTypeZoom() {
        #expect(VideoLinkType.from(urlString: "https://zoom.us/j/123456789") == .zoom)
        #expect(VideoLinkType.from(urlString: "https://zoom.us/s/123456789") == .zoom)
        #expect(VideoLinkType.from(urlString: "https://zoom.us/w/123456789") == .zoom)
        #expect(VideoLinkType.from(urlString: "https://zoom.us/my/meeting") == .zoom)
        #expect(VideoLinkType.from(urlString: "https://company.zoom.us/j/123456789") == .zoom)
    }

    @Test func testVideoLinkTypeGoogleMeet() {
        #expect(VideoLinkType.from(urlString: "https://meet.google.com/abc-defg-hij") == .googleMeet)
    }

    @Test func testVideoLinkTypeTeams() {
        #expect(VideoLinkType.from(urlString: "https://teams.microsoft.com/l/meetup-join/...") == .teams)
        #expect(VideoLinkType.from(urlString: "https://teams.live.com/meet/...") == .teams)
    }

    @Test func testVideoLinkTypeWebEx() {
        #expect(VideoLinkType.from(urlString: "https://company.webex.com/meet/user") == .webex)
        #expect(VideoLinkType.from(urlString: "https://webex.com/meet/user") == .webex)
    }

    @Test func testVideoLinkTypeSlack() {
        #expect(VideoLinkType.from(urlString: "https://slack.com/call/12345") == .slack)
    }

    @Test func testVideoLinkTypeUnknown() {
        #expect(VideoLinkType.from(urlString: "https://example.com/meeting") == .unknown)
        #expect(VideoLinkType.from(urlString: "") == .unknown)
    }

    @Test func testVideoLinkTypeDisplayName() {
        #expect(VideoLinkType.zoom.displayName == "Zoom")
        #expect(VideoLinkType.googleMeet.displayName == "Google Meet")
        #expect(VideoLinkType.teams.displayName == "Microsoft Teams")
        #expect(VideoLinkType.webex.displayName == "WebEx")
        #expect(VideoLinkType.slack.displayName == "Slack")
        #expect(VideoLinkType.unknown.displayName == "Video Call")
    }

    @Test func testVideoLinkTypeIconNames() {
        #expect(VideoLinkType.zoom.iconName == "video.bubble.left.fill")
        #expect(VideoLinkType.googleMeet.iconName == "person.3.fill")
        #expect(VideoLinkType.teams.iconName == "rectangle.3.group.fill")
        #expect(VideoLinkType.webex.iconName == "network")
        #expect(VideoLinkType.slack.iconName == "bubble.left.and.bubble.right.fill")
        #expect(VideoLinkType.unknown.iconName == "video.fill")
    }

    @Test func testParseVideoLinkFromLocationZoom() {
        let url = CalendarService.shared.parseVideoLink(from: "https://zoom.us/j/123456789")
        #expect(url != nil)
        #expect(url?.absoluteString == "https://zoom.us/j/123456789")
    }

    @Test func testParseVideoLinkFromNotesZoom() {
        let url = CalendarService.shared.parseVideoLink(from: "Join the meeting: https://zoom.us/j/123456789?pwd=abc123")
        #expect(url != nil)
        #expect(url?.absoluteString.contains("zoom.us") ?? false)
    }

    @Test func testParseVideoLinkGoogleMeet() {
        let url = CalendarService.shared.parseVideoLink(from: "https://meet.google.com/abc-defg-hij")
        #expect(url != nil)
        #expect(url?.absoluteString.contains("meet.google.com") ?? false)
    }

    @Test func testParseVideoLinkTeams() {
        let url = CalendarService.shared.parseVideoLink(from: "Join via Teams: https://teams.microsoft.com/l/meetup-join/123")
        #expect(url != nil)
        #expect(url?.absoluteString.contains("teams.microsoft.com") ?? false)
    }

    @Test func testParseVideoLinkWebEx() {
        let url = CalendarService.shared.parseVideoLink(from: "https://company.webex.com/meet/user")
        #expect(url != nil)
        #expect(url?.absoluteString.contains("webex.com") ?? false)
    }

    @Test func testParseVideoLinkSlack() {
        let url = CalendarService.shared.parseVideoLink(from: "https://slack.com/call/12345")
        #expect(url != nil)
        #expect(url?.absoluteString.contains("slack.com/call") ?? false)
    }

    @Test func testParseVideoLinkNone() {
        let url = CalendarService.shared.parseVideoLink(from: "Conference Room A")
        #expect(url == nil)
    }

    @Test func testParseVideoLinkEmpty() {
        let url = CalendarService.shared.parseVideoLink(from: "")
        #expect(url == nil)
    }

    @Test func testParseVideoLinkMultiple() {
        let url = CalendarService.shared.parseVideoLink(from: "Join: https://zoom.us/j/123 or https://meet.google.com/abc")
        #expect(url != nil)
        #expect(url?.absoluteString.contains("zoom.us") ?? false, "Should return first video link found")
    }

    @Test func testCalendarServiceCreation() {
    }

    @Test func testCalendarServiceSingleton() {
        let service1 = CalendarService.shared
        let service2 = CalendarService.shared
        #expect(service1 === service2)
    }

    @Test func testCalendarKeywordsDetected() {
        let service = CalendarService.shared

        #expect(service.matchesCalendarKeywords(query: "calendar"))
        #expect(service.matchesCalendarKeywords(query: "schedule"))
        #expect(service.matchesCalendarKeywords(query: "meetings today"))
        #expect(service.matchesCalendarKeywords(query: "join"))
        #expect(service.matchesCalendarKeywords(query: "meeting"))
    }

    @Test func testNonCalendarKeywordsNotDetected() {
        let service = CalendarService.shared

        #expect(!service.matchesCalendarKeywords(query: "xyzabc"))
        #expect(!service.matchesCalendarKeywords(query: "battery"))
        #expect(!service.matchesCalendarKeywords(query: ""))
    }

}

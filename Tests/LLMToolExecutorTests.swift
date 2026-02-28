import XCTest
@testable import ZestApp

/// Tests for LLMToolExecutor - Executing parsed LLM tool calls
final class LLMToolExecutorTests: XCTestCase {

    // MARK: - Date Parsing Tests

    /// Test parsing "tomorrow" returns a date in the future
    func testParseTomorrow() {
        let parser = DateTimeParser.shared
        let result = parser.parseDate("tomorrow")

        XCTAssertNotNil(result)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertTrue(calendar.isDate(result!, inSameDayAs: tomorrow))
    }

    /// Test parsing "today" returns today's date
    func testParseToday() {
        let parser = DateTimeParser.shared
        let result = parser.parseDate("today")

        XCTAssertNotNil(result)
        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(result!))
    }

    /// Test parsing MM/DD/YYYY format
    func testParseMMDDYYYY() {
        let parser = DateTimeParser.shared
        let result = parser.parseDate("02/27/2026")

        XCTAssertNotNil(result)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.month, from: result!), 2)
        XCTAssertEqual(calendar.component(.day, from: result!), 27)
        XCTAssertEqual(calendar.component(.year, from: result!), 2026)
    }

    /// Test parsing DD/MM/YYYY format (handles both)
    func testParseDDMMYYYY() {
        let parser = DateTimeParser.shared
        // When first number > 12, must be day
        let result = parser.parseDate("27/02/2026")

        XCTAssertNotNil(result)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.day, from: result!), 27)
        XCTAssertEqual(calendar.component(.month, from: result!), 2)
        XCTAssertEqual(calendar.component(.year, from: result!), 2026)
    }

    /// Test parsing YYYY-MM-DD format
    func testParseYYYYMMDD() {
        let parser = DateTimeParser.shared
        let result = parser.parseDate("2026-03-15")

        XCTAssertNotNil(result)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.year, from: result!), 2026)
        XCTAssertEqual(calendar.component(.month, from: result!), 3)
        XCTAssertEqual(calendar.component(.day, from: result!), 15)
    }

    /// Test parsing "March 15" returns correct month/day
    func testParseMonthDay() {
        let parser = DateTimeParser.shared
        let result = parser.parseDate("March 15")

        XCTAssertNotNil(result)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.month, from: result!), 3)
        XCTAssertEqual(calendar.component(.day, from: result!), 15)
    }

    /// Test parsing "next Monday" returns a future Monday
    func testParseNextMonday() {
        let parser = DateTimeParser.shared
        let result = parser.parseDate("next Monday")

        XCTAssertNotNil(result)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.weekday, from: result!), 2) // Monday = 2
        XCTAssertGreaterThan(result!, Date())
    }

    // MARK: - Time Parsing Tests

    /// Test parsing "10:15 AM" returns correct hour/minute
    func testParseTime10_15AM() {
        let parser = DateTimeParser.shared
        let result = parser.parseTime("10:15 AM")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hour, 10)
        XCTAssertEqual(result?.minute, 15)
    }

    /// Test parsing "3pm" returns correct hour
    func testParseTime3PM() {
        let parser = DateTimeParser.shared
        let result = parser.parseTime("3pm")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hour, 15)
        XCTAssertEqual(result?.minute, 0)
    }

    /// Test parsing "9am" returns correct hour
    func testParseTime9AM() {
        let parser = DateTimeParser.shared
        let result = parser.parseTime("9am")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hour, 9)
        XCTAssertEqual(result?.minute, 0)
    }

    /// Test parsing "2:30 PM" returns correct hour/minute
    func testParseTime2_30PM() {
        let parser = DateTimeParser.shared
        let result = parser.parseTime("2:30 PM")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hour, 14)
        XCTAssertEqual(result?.minute, 30)
    }

    /// Test parsing "14:00" (24-hour format)
    func testParseTime24Hour() {
        let parser = DateTimeParser.shared
        let result = parser.parseTime("14:00")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hour, 14)
        XCTAssertEqual(result?.minute, 0)
    }

    // MARK: - Combined Date + Time Tests

    /// Test combining date string with time string
    func testCombineDateAndTime() {
        let parser = DateTimeParser.shared

        let date = parser.parseDate("02/27/2026")
        let time = parser.parseTime("3:30 PM")

        XCTAssertNotNil(date)
        XCTAssertNotNil(time)

        let combined = parser.combine(date: date!, withTime: time!)

        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.month, from: combined), 2)
        XCTAssertEqual(calendar.component(.day, from: combined), 27)
        XCTAssertEqual(calendar.component(.year, from: combined), 2026)
        XCTAssertEqual(calendar.component(.hour, from: combined), 15)
        XCTAssertEqual(calendar.component(.minute, from: combined), 30)
    }

    /// Test that combining without time uses default time (9 AM)
    func testCombineDateWithDefaultTime() {
        let parser = DateTimeParser.shared

        let date = parser.parseDate("tomorrow")
        let combined = parser.combine(date: date!, withTime: Optional<TimeComponents>.none)

        let calendar = Calendar.current
        // Default time should be 9 AM
        XCTAssertEqual(calendar.component(.hour, from: combined), 9)
        XCTAssertEqual(calendar.component(.minute, from: combined), 0)
    }

    // MARK: - Executor Tests

    /// Test executor exists
    func testExecutorExists() {
        let executor = LLMToolExecutor.shared
        XCTAssertNotNil(executor)
    }

    /// Test executor is singleton
    func testExecutorSingleton() {
        let executor1 = LLMToolExecutor.shared
        let executor2 = LLMToolExecutor.shared
        XCTAssertTrue(executor1 === executor2)
    }

    /// Test parsing time components structure
    func testTimeComponentsStructure() {
        let components = TimeComponents(hour: 14, minute: 30)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }
}

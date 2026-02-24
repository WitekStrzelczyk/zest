import XCTest
@testable import ZestApp

/// Tests for Time Zone Converter - Story 33
final class TimeZoneConverterServiceTests: XCTestCase {

    // MARK: - Time Zone Abbreviation Conversions

    func test_est_to_pst_conversion() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When - 3pm EST to PST (EST is UTC-5, PST is UTC-8, so 3pm EST = 12pm PST)
        let result = converter.convert("3pm EST to PST")

        // Then
        XCTAssertNotNil(result, "Should convert EST to PST")
        XCTAssertTrue(result!.contains("12:00"), "3pm EST should be 12:00 PM PST")
        XCTAssertTrue(result!.contains("PST"), "Result should contain PST")
    }

    func test_pst_to_est_conversion() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When - 9am PST to EST (PST is UTC-8, EST is UTC-5, so 9am PST = 12pm EST)
        let result = converter.convert("9am PST to EST")

        // Then
        XCTAssertNotNil(result, "Should convert PST to EST")
        XCTAssertTrue(result!.contains("12:00"), "9am PST should be 12:00 PM EST")
        XCTAssertTrue(result!.contains("EST"), "Result should contain EST")
    }

    func test_gmt_to_utc_conversion() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When - GMT and UTC are the same
        let result = converter.convert("2pm GMT to UTC")

        // Then
        XCTAssertNotNil(result, "Should convert GMT to UTC")
        XCTAssertTrue(result!.contains("2:00"), "2pm GMT should be 2:00 PM UTC")
    }

    // MARK: - City Name Conversions

    func test_tokyo_to_london_conversion() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When - 9am Tokyo to London (Tokyo is JST UTC+9, London is GMT/BST)
        let result = converter.convert("9am Tokyo to London")

        // Then
        XCTAssertNotNil(result, "Should convert Tokyo to London")
        XCTAssertTrue(result!.contains("London"), "Result should mention London")
    }

    func test_new_york_to_los_angeles() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When - New York (EST UTC-5) to Los Angeles (PST UTC-8)
        let result = converter.convert("12pm New York to Los Angeles")

        // Then
        XCTAssertNotNil(result, "Should convert New York to Los Angeles")
        XCTAssertTrue(result!.contains("Los Angeles") || result!.contains("PST"), "Result should mention destination")
    }

    func test_sydney_to_auckland() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.convert("10am Sydney to Auckland")

        // Then
        XCTAssertNotNil(result, "Should convert Sydney to Auckland")
    }

    // MARK: - Current Time Queries

    func test_time_in_new_york() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.currentTime(in: "New York")

        // Then
        XCTAssertNotNil(result, "Should return current time for New York")
        XCTAssertTrue(result!.contains("New York"), "Result should mention New York")
    }

    func test_time_in_tokyo() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.currentTime(in: "Tokyo")

        // Then
        XCTAssertNotNil(result, "Should return current time for Tokyo")
        XCTAssertTrue(result!.contains("Tokyo"), "Result should mention Tokyo")
    }

    func test_time_in_london() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.currentTime(in: "London")

        // Then
        XCTAssertNotNil(result, "Should return current time for London")
        XCTAssertTrue(result!.contains("London"), "Result should mention London")
    }

    func test_time_in_invalid_city_returns_nil() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.currentTime(in: "Atlantis")

        // Then
        XCTAssertNil(result, "Invalid city should return nil")
    }

    // MARK: - Pattern Detection

    func test_is_conversion_expression_with_time_zones() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When/Then
        XCTAssertTrue(converter.isTimeConversionExpression("3pm EST to PST"), "Should recognize time zone conversion")
        XCTAssertTrue(converter.isTimeConversionExpression("9am Tokyo to London"), "Should recognize city conversion")
        XCTAssertTrue(converter.isTimeConversionExpression("2:30pm GMT to UTC"), "Should recognize time with minutes")
    }

    func test_is_not_conversion_expression_for_math() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When/Then
        XCTAssertFalse(converter.isTimeConversionExpression("2+2"), "Math should not be time conversion")
        XCTAssertFalse(converter.isTimeConversionExpression("100 km to miles"), "Unit conversion should not be time conversion")
    }

    func test_is_time_in_expression() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When/Then
        XCTAssertTrue(converter.isTimeInExpression("time in New York"), "Should recognize 'time in' expression")
        XCTAssertTrue(converter.isTimeInExpression("time in Tokyo"), "Should recognize 'time in' expression")
        XCTAssertTrue(converter.isTimeInExpression("what time in London"), "Should recognize 'time in' expression")
    }

    // MARK: - Frequent Time Zones

    func test_get_frequent_time_zones() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let zones = converter.getFrequentTimeZones()

        // Then
        XCTAssertFalse(zones.isEmpty, "Should have frequent time zones")
        XCTAssertTrue(zones.contains { $0.contains("EST") || $0.contains("New York") }, "Should include EST/New York")
        XCTAssertTrue(zones.contains { $0.contains("PST") || $0.contains("Los Angeles") }, "Should include PST/Los Angeles")
        XCTAssertTrue(zones.contains { $0.contains("GMT") || $0.contains("London") }, "Should include GMT/London")
    }

    // MARK: - 24-hour Format Support

    func test_24_hour_format_conversion() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.convert("15:00 EST to PST")

        // Then
        XCTAssertNotNil(result, "Should handle 24-hour format")
        XCTAssertTrue(result!.contains("12:00"), "15:00 EST should be 12:00 PST")
    }

    // MARK: - Edge Cases

    func test_invalid_time_returns_nil() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.convert("25pm EST to PST")

        // Then
        XCTAssertNil(result, "Invalid hour should return nil")
    }

    func test_invalid_time_zone_returns_nil() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.convert("3pm XYZ to PST")

        // Then
        XCTAssertNil(result, "Invalid time zone should return nil")
    }

    func test_empty_input_returns_nil() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.convert("")

        // Then
        XCTAssertNil(result, "Empty input should return nil")
    }

    func test_whitespace_only_returns_nil() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.convert("   ")

        // Then
        XCTAssertNil(result, "Whitespace only should return nil")
    }

    // MARK: - Case Insensitivity

    func test_case_insensitive_time_zones() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.convert("3PM est TO pst")

        // Then
        XCTAssertNotNil(result, "Should handle mixed case")
        XCTAssertTrue(result!.contains("12:00"), "Should convert correctly")
    }

    func test_case_insensitive_cities() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.convert("9am TOKYO to LONDON")

        // Then
        XCTAssertNotNil(result, "Should handle uppercase cities")
    }

    // MARK: - Copy to Clipboard Format

    func test_result_is_copyable() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let result = converter.convert("3pm EST to PST")

        // Then
        XCTAssertNotNil(result, "Should have result")
        // Result should be a plain string suitable for clipboard
        XCTAssertFalse(result!.contains("\n"), "Should be single line for clipboard")
    }

    // MARK: - Supported Time Zones

    func test_us_time_zones() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When/Then
        XCTAssertNotNil(converter.convert("3pm EST to CST"), "EST to CST should work")
        XCTAssertNotNil(converter.convert("3pm EST to MST"), "EST to MST should work")
        XCTAssertNotNil(converter.convert("3pm EST to PST"), "EST to PST should work")
    }

    func test_european_time_zones() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When/Then
        XCTAssertNotNil(converter.convert("3pm GMT to Paris"), "GMT to Paris should work")
        XCTAssertNotNil(converter.convert("3pm London to Berlin"), "London to Berlin should work")
    }

    func test_asian_time_zones() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When/Then
        XCTAssertNotNil(converter.convert("9am Tokyo to Shanghai"), "Tokyo to Shanghai should work")
        XCTAssertNotNil(converter.convert("9am Singapore to Mumbai"), "Singapore to Mumbai should work")
        XCTAssertNotNil(converter.convert("9am Dubai to Tokyo"), "Dubai to Tokyo should work")
    }

    func test_oceanian_time_zones() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When/Then
        XCTAssertNotNil(converter.convert("10am Sydney to Auckland"), "Sydney to Auckland should work")
    }

    // MARK: - Search Integration

    func test_search_returns_time_conversion_result() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let results = converter.search(query: "3pm EST to PST")

        // Then
        XCTAssertEqual(results.count, 1, "Should return exactly one result")
        XCTAssertTrue(results.first!.title.contains("12:00"), "Result title should contain converted time")
        XCTAssertEqual(results.first!.category, .conversion, "Should be conversion category")
    }

    func test_search_returns_time_in_result() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let results = converter.search(query: "time in New York")

        // Then
        XCTAssertEqual(results.count, 1, "Should return exactly one result")
        XCTAssertTrue(results.first!.title.contains("New York"), "Result should mention New York")
    }

    func test_search_time_zones_returns_list() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let results = converter.search(query: "time zones")

        // Then
        XCTAssertFalse(results.isEmpty, "Should return time zones list")
        XCTAssertTrue(results.count >= 5, "Should return at least 5 frequent time zones")
    }

    func test_search_invalid_returns_empty() {
        // Given
        let converter = TimeZoneConverterService.shared

        // When
        let results = converter.search(query: "random text")

        // Then
        XCTAssertTrue(results.isEmpty, "Invalid search should return empty")
    }
}

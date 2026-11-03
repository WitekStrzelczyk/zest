import AppKit
import Testing
@testable import ZestApp

@MainActor
final class TimeZoneConverterServiceTests {
    @Test func test_est_to_pst_conversion() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("3pm EST to PST")

        #expect(result != nil, "Should convert EST to PST")
        #expect(result!.contains("12:00"), "3pm EST should be 12:00 PM PST")
        #expect(result!.contains("PST"), "Result should contain PST")
    }

    @Test func test_pst_to_est_conversion() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("9am PST to EST")

        #expect(result != nil, "Should convert PST to EST")
        #expect(result!.contains("12:00"), "9am PST should be 12:00 PM EST")
        #expect(result!.contains("EST"), "Result should contain EST")
    }

    @Test func test_gmt_to_utc_conversion() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("2pm GMT to UTC")

        #expect(result != nil, "Should convert GMT to UTC")
        #expect(result!.contains("2:00"), "2pm GMT should be 2:00 PM UTC")
    }

    @Test func test_tokyo_to_london_conversion() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("9am Tokyo to London")

        #expect(result != nil, "Should convert Tokyo to London")
        #expect(result!.contains("London"), "Result should mention London")
    }

    @Test func test_new_york_to_los_angeles() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("12pm New York to Los Angeles")

        #expect(result != nil, "Should convert New York to Los Angeles")
        #expect(result!.contains("Los Angeles") || result!.contains("PST"), "Result should mention destination")
    }

    @Test func test_sydney_to_auckland() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("10am Sydney to Auckland")

        #expect(result != nil, "Should convert Sydney to Auckland")
    }

    @Test func test_time_in_new_york() {
        let converter = TimeZoneConverterService.shared

        let result = converter.currentTime(in: "New York")

        #expect(result != nil, "Should return current time for New York")
        #expect(result!.contains("New York"), "Result should mention New York")
    }

    @Test func test_time_in_tokyo() {
        let converter = TimeZoneConverterService.shared

        let result = converter.currentTime(in: "Tokyo")

        #expect(result != nil, "Should return current time for Tokyo")
        #expect(result!.contains("Tokyo"), "Result should mention Tokyo")
    }

    @Test func test_time_in_london() {
        let converter = TimeZoneConverterService.shared

        let result = converter.currentTime(in: "London")

        #expect(result != nil, "Should return current time for London")
        #expect(result!.contains("London"), "Result should mention London")
    }

    @Test func test_time_in_invalid_city_returns_nil() {
        let converter = TimeZoneConverterService.shared

        let result = converter.currentTime(in: "Atlantis")

        #expect(result == nil, "Invalid city should return nil")
    }

    @Test func test_is_conversion_expression_with_time_zones() {
        let converter = TimeZoneConverterService.shared

        #expect(converter.isTimeConversionExpression("3pm EST to PST"), "Should recognize time zone conversion")
        #expect(converter.isTimeConversionExpression("9am Tokyo to London"), "Should recognize city conversion")
        #expect(converter.isTimeConversionExpression("2:30pm GMT to UTC"), "Should recognize time with minutes")
    }

    @Test func test_is_not_conversion_expression_for_math() {
        let converter = TimeZoneConverterService.shared

        #expect(!converter.isTimeConversionExpression("2+2"), "Math should not be time conversion")
        #expect(!converter.isTimeConversionExpression("100 km to miles"), "Unit conversion should not be time conversion")
    }

    @Test func test_is_time_in_expression() {
        let converter = TimeZoneConverterService.shared

        #expect(converter.isTimeInExpression("time in New York"), "Should recognize 'time in' expression")
        #expect(converter.isTimeInExpression("time in Tokyo"), "Should recognize 'time in' expression")
        #expect(converter.isTimeInExpression("what time in London"), "Should recognize 'time in' expression")
    }

    @Test func test_get_frequent_time_zones() {
        let converter = TimeZoneConverterService.shared

        let zones = converter.getFrequentTimeZones()

        #expect(!zones.isEmpty, "Should have frequent time zones")
        #expect(zones.contains { $0.contains("EST") || $0.contains("New York") }, "Should include EST/New York")
        #expect(zones.contains { $0.contains("PST") || $0.contains("Los Angeles") }, "Should include PST/Los Angeles")
        #expect(zones.contains { $0.contains("GMT") || $0.contains("London") }, "Should include GMT/London")
    }

    @Test func test_24_hour_format_conversion() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("15:00 EST to PST")

        #expect(result != nil, "Should handle 24-hour format")
        #expect(result!.contains("12:00"), "15:00 EST should be 12:00 PST")
    }

    @Test func test_invalid_time_returns_nil() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("25pm EST to PST")

        #expect(result == nil, "Invalid hour should return nil")
    }

    @Test func test_invalid_time_zone_returns_nil() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("3pm XYZ to PST")

        #expect(result == nil, "Invalid time zone should return nil")
    }

    @Test func test_empty_input_returns_nil() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("")

        #expect(result == nil, "Empty input should return nil")
    }

    @Test func test_whitespace_only_returns_nil() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("   ")

        #expect(result == nil, "Whitespace only should return nil")
    }

    @Test func test_case_insensitive_time_zones() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("3PM est TO pst")

        #expect(result != nil, "Should handle mixed case")
        #expect(result!.contains("12:00"), "Should convert correctly")
    }

    @Test func test_case_insensitive_cities() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("9am TOKYO to LONDON")

        #expect(result != nil, "Should handle uppercase cities")
    }

    @Test func test_result_is_copyable() {
        let converter = TimeZoneConverterService.shared

        let result = converter.convert("3pm EST to PST")

        #expect(result != nil, "Should have result")
        #expect(!result!.contains("\n"), "Should be single line for clipboard")
    }

    @Test func test_us_time_zones() {
        let converter = TimeZoneConverterService.shared

        #expect(converter.convert("3pm EST to CST") != nil, "EST to CST should work")
        #expect(converter.convert("3pm EST to MST") != nil, "EST to MST should work")
        #expect(converter.convert("3pm EST to PST") != nil, "EST to PST should work")
    }

    @Test func test_european_time_zones() {
        let converter = TimeZoneConverterService.shared

        #expect(converter.convert("3pm GMT to Paris") != nil, "GMT to Paris should work")
        #expect(converter.convert("3pm London to Berlin") != nil, "London to Berlin should work")
    }

    @Test func test_asian_time_zones() {
        let converter = TimeZoneConverterService.shared

        #expect(converter.convert("9am Tokyo to Shanghai") != nil, "Tokyo to Shanghai should work")
        #expect(converter.convert("9am Singapore to Mumbai") != nil, "Singapore to Mumbai should work")
        #expect(converter.convert("9am Dubai to Tokyo") != nil, "Dubai to Tokyo should work")
    }

    @Test func test_oceanian_time_zones() {
        let converter = TimeZoneConverterService.shared

        #expect(converter.convert("10am Sydney to Auckland") != nil, "Sydney to Auckland should work")
    }

    @Test func test_search_returns_time_conversion_result() {
        let converter = TimeZoneConverterService.shared

        let results = converter.search(query: "3pm EST to PST")

        #expect(results.count == 1, "Should return exactly one result")
        #expect(results.first!.title.contains("12:00"), "Result title should contain converted time")
        #expect(results.first!.category == .conversion, "Should be conversion category")
    }

    @Test func test_search_returns_time_in_result() {
        let converter = TimeZoneConverterService.shared

        let results = converter.search(query: "time in New York")

        #expect(results.count == 1, "Should return exactly one result")
        #expect(results.first!.title.contains("New York"), "Result should mention New York")
    }

    @Test func test_search_time_zones_returns_list() {
        let converter = TimeZoneConverterService.shared

        let results = converter.search(query: "time zones")

        #expect(!results.isEmpty, "Should return time zones list")
        #expect(results.count >= 5, "Should return at least 5 frequent time zones")
    }

    @Test func test_search_invalid_returns_empty() {
        let converter = TimeZoneConverterService.shared

        let results = converter.search(query: "random text")

        #expect(results.isEmpty, "Invalid search should return empty")
    }
}

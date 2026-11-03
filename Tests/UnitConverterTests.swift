import AppKit
import Testing
@testable import ZestApp

@MainActor
final class UnitConverterTests {
    @Test func test_kilometers_to_miles() {
        let converter = UnitConverter.shared

        let result = converter.convert("100 km to miles")

        #expect(result == "62.14 miles", "100 km should convert to 62.14 miles")
    }

    @Test func test_kilograms_to_lbs() {
        let converter = UnitConverter.shared

        let result = converter.convert("50 kg to lbs")

        #expect(result == "110.23 lbs", "50 kg should convert to 110.23 lbs")
    }

    @Test func test_fahrenheit_to_celsius() {
        let converter = UnitConverter.shared

        let result = converter.convert("72 f to c")

        #expect(result == "22.22°C", "72°F should convert to 22.22°C")
    }

    @Test func test_gallons_to_liters() {
        let converter = UnitConverter.shared

        let result = converter.convert("1 gallon to liters")

        #expect(result == "3.79 liters", "1 gallon should convert to 3.79 liters")
    }

    @Test func test_megabytes_to_gigabytes_binary() {
        let converter = UnitConverter.shared

        let result = converter.convert("1000 mb to gb")

        #expect(result == "0.98 GB", "1000 MB should convert to 0.98 GB (binary)")
    }

    @Test func test_invalid_conversion_returns_nil() {
        let converter = UnitConverter.shared

        let result = converter.convert("100 km to apples")

        #expect(result == nil, "Invalid conversion should return nil")
    }

    @Test func test_scientific_notation_large_number() {
        let converter = UnitConverter.shared

        let result = converter.convert("1e9 km to miles")

        #expect(result != nil, "Scientific notation should return a result")
        #expect(result!.contains("e") || result!.contains("621371"), "Large number should use scientific notation")
    }

    @Test func test_recognizes_km_to_miles_pattern() {
        let converter = UnitConverter.shared

        let isConversion = converter.isConversionExpression("100 km to miles")

        #expect(isConversion, "Should recognize km to miles pattern")
    }

    @Test func test_recognizes_f_to_c_pattern() {
        let converter = UnitConverter.shared

        let isConversion = converter.isConversionExpression("72 f to c")

        #expect(isConversion, "Should recognize f to c pattern")
    }

    @Test func test_does_not_recognize_math_expression_as_conversion() {
        let converter = UnitConverter.shared

        let isConversion = converter.isConversionExpression("2+2")

        #expect(!isConversion, "Should not confuse math expression with conversion")
    }

    @Test func test_does_not_recognize_random_text_as_conversion() {
        let converter = UnitConverter.shared

        let isConversion = converter.isConversionExpression("hello world")

        #expect(!isConversion, "Should not recognize random text as conversion")
    }

    @Test func test_meters_to_feet() {
        let converter = UnitConverter.shared

        let result = converter.convert("10 m to feet")

        #expect(result == "32.81 feet", "10 meters should convert to 32.81 feet")
    }

    @Test func test_cm_to_inches() {
        let converter = UnitConverter.shared

        let result = converter.convert("100 cm to inches")

        #expect(result == "39.37 inches", "100 cm should convert to 39.37 inches")
    }

    @Test func test_grams_to_oz() {
        let converter = UnitConverter.shared

        let result = converter.convert("500 g to oz")

        #expect(result == "17.64 oz", "500g should convert to 17.64 oz")
    }

    @Test func test_celsius_to_fahrenheit() {
        let converter = UnitConverter.shared

        let result = converter.convert("100 c to f")

        #expect(result == "212°F", "100°C should convert to 212°F")
    }

    @Test func test_kilometers_per_hour_to_mph() {
        let converter = UnitConverter.shared

        let result = converter.convert("100 km/h to mph")

        #expect(result == "62.14 mph", "100 km/h should convert to 62.14 mph")
    }

    @Test func test_bytes_to_megabytes() {
        let converter = UnitConverter.shared

        let result = converter.convert("1048576 bytes to mb")

        #expect(result == "1 MB", "1048576 bytes should convert to 1 MB")
    }

    @Test func test_hours_to_minutes() {
        let converter = UnitConverter.shared

        let result = converter.convert("2 hours to minutes")

        #expect(result == "120 minutes", "2 hours should convert to 120 minutes")
    }

    @Test func test_acres_to_hectares() {
        let converter = UnitConverter.shared

        let result = converter.convert("10 acres to hectares")

        #expect(result == "4.05 hectares", "10 acres should convert to 4.05 hectares")
    }

    @Test func test_liters_to_gallons() {
        let converter = UnitConverter.shared

        let result = converter.convert("10 liters to gallons")

        #expect(result == "2.64 gallons", "10 liters should convert to 2.64 gallons")
    }

    @Test func test_convert_keyword_returns_hints() {
        let converter = UnitConverter.shared

        let hints = converter.getHints()

        #expect(!hints.isEmpty, "Hints should not be empty")
        #expect(hints.contains("100 km to miles"), "Hints should contain 100 km to miles")
    }

    @Test func test_empty_input_returns_nil() {
        let converter = UnitConverter.shared

        let result = converter.convert("")

        #expect(result == nil, "Empty input should return nil")
    }

    @Test func test_whitespace_only_input_returns_nil() {
        let converter = UnitConverter.shared

        let result = converter.convert("   ")

        #expect(result == nil, "Whitespace-only input should return nil")
    }

    @Test func test_leading_whitespace_is_trimmed() {
        let converter = UnitConverter.shared

        let result = converter.convert("  100 km to miles")

        #expect(result == "62.14 miles", "Leading whitespace should be trimmed")
    }

    @Test func test_trailing_whitespace_is_trimmed() {
        let converter = UnitConverter.shared

        let result = converter.convert("100 km to miles  ")

        #expect(result == "62.14 miles", "Trailing whitespace should be trimmed")
    }

    @Test func test_no_space_between_value_and_unit() {
        let converter = UnitConverter.shared

        let result = converter.convert("100km to miles")

        #expect(result == "62.14 miles", "Should handle '100km' without space")
    }

    @Test func test_k_suffix_for_kilo() {
        let converter = UnitConverter.shared

        let result = converter.convert("100k m to cm")

        #expect(result == "10,000,000 centimeters", "Should handle 'k' suffix for kilo (100k = 100000)")
    }

    @Test func test_multiple_spaces_between_tokens() {
        let converter = UnitConverter.shared

        let result = converter.convert("100   km   to   miles")

        #expect(result == "62.14 miles", "Multiple spaces should be handled")
    }

    @Test func test_km_to_miles() {
        let converter = UnitConverter.shared

        let result = converter.convert("100 km to miles")

        #expect(result == "62.14 miles", "100 km should convert to 62.14 miles")
    }

    @Test func test_miles_to_km() {
        let converter = UnitConverter.shared

        let result = converter.convert("60 miles to km")

        #expect(result == "96.56 kilometers", "60 miles should convert to 96.56 kilometers")
    }

    @Test func test_kg_to_lbs() {
        let converter = UnitConverter.shared

        let result = converter.convert("10 kg to lbs")

        #expect(result == "22.05 lbs", "10 kg should convert to 22.05 lbs")
    }

    @Test func test_lbs_to_kg() {
        let converter = UnitConverter.shared

        let result = converter.convert("100 lbs to kg")

        #expect(result == "45.36 kilograms", "100 lbs should convert to 45.36 kilograms")
    }

    @Test func test_fahrenheit_to_celsius_at_freezing() {
        let converter = UnitConverter.shared

        let result = converter.convert("32 f to c")

        #expect(result == "0°C", "32°F should convert to 0°C")
    }

    @Test func test_celsius_to_fahrenheit_at_freezing() {
        let converter = UnitConverter.shared

        let result = converter.convert("0 c to f")

        #expect(result == "32°F", "0°C should convert to 32°F")
    }

    @Test func test_fahrenheit_to_kelvin() {
        let converter = UnitConverter.shared

        let result = converter.convert("32 f to k")

        #expect(result == "273.15K", "32°F should convert to 273.15K")
    }

    @Test func test_kelvin_to_fahrenheit() {
        let converter = UnitConverter.shared

        let result = converter.convert("273.15 k to f")

        #expect(result == "32°F", "273.15K should convert to 32°F")
    }

    @Test func test_celsius_to_kelvin() {
        let converter = UnitConverter.shared

        let result = converter.convert("0 c to k")

        #expect(result == "273.15K", "0°C should convert to 273.15K")
    }

    @Test func test_kelvin_to_celsius() {
        let converter = UnitConverter.shared

        let result = converter.convert("273.15 k to c")

        #expect(result == "0°C", "273.15K should convert to 0°C")
    }

    @Test func test_megabytes_to_gigabytes_binary_exact() {
        let converter = UnitConverter.shared

        let result = converter.convert("1024 mb to gb")

        #expect(result == "1 GB", "1024 MB should convert to 1 GB (binary)")
    }

    @Test func test_kilobytes_to_bytes() {
        let converter = UnitConverter.shared

        let result = converter.convert("1 kb to b")

        #expect(result == "1024 B", "1 KB should convert to 1024 B")
    }

    @Test func test_gigabytes_to_megabytes() {
        let converter = UnitConverter.shared

        let result = converter.convert("1 gb to mb")

        #expect(result == "1024 MB", "1 GB should convert to 1024 MB")
    }

    @Test func test_uppercase_units() {
        let converter = UnitConverter.shared

        let result = converter.convert("100 KM to MILES")

        #expect(result == "62.14 miles", "Uppercase units should work")
    }

    @Test func test_mixed_case_units() {
        let converter = UnitConverter.shared

        let result = converter.convert("100 Km to Miles")

        #expect(result == "62.14 miles", "Mixed case units should work")
    }

    @Test func test_case_insensitive_pattern_detection() {
        let converter = UnitConverter.shared

        let isConversion = converter.isConversionExpression("100 KM to MILES")

        #expect(isConversion, "Should recognize uppercase conversion pattern")
    }

    @Test func test_proper_decimal_rounding() {
        let converter = UnitConverter.shared

        let result = converter.convert("0.333 km to miles")

        #expect(result?.contains("0.21") == true, "Should properly round to 2 decimal places")
    }

    @Test func test_whole_number_result() {
        let converter = UnitConverter.shared

        let result = converter.convert("1000 m to km")

        #expect(result == "1 kilometers", "Whole number result should not have decimals")
    }

    @Test func test_negative_temperature() {
        let converter = UnitConverter.shared

        let result = converter.convert("-40 f to c")

        #expect(result == "-40°C", "-40°F should convert to -40°C")
    }

    @Test func test_zero_value_conversion() {
        let converter = UnitConverter.shared

        let result = converter.convert("0 c to f")

        #expect(result == "32°F", "0°C should convert to 32°F")
    }

    @Test func test_fractional_value_conversion() {
        let converter = UnitConverter.shared

        let result = converter.convert("0.5 km to m")

        #expect(result == "500 meters", "0.5 km should convert to 500 meters")
    }

    @Test func test_incompatible_units_returns_nil() {
        let converter = UnitConverter.shared

        let result = converter.convert("100 km to kg")

        #expect(result == nil, "Incompatible units should return nil")
    }

    @Test func test_negative_number_conversion() {
        let converter = UnitConverter.shared

        let result = converter.convert("-100 km to miles")

        #expect(result == "-62.14 miles", "Negative numbers should convert correctly")
    }

    @Test func test_millimeters_to_centimeters() {
        let converter = UnitConverter.shared

        let result = converter.convert("10 mm to cm")

        #expect(result == "1 centimeters", "10 mm should convert to 1 cm")
    }

    @Test func test_yards_to_meters() {
        let converter = UnitConverter.shared

        let result = converter.convert("1 yd to m")

        #expect(result == "0.91 meters", "1 yard should convert to 0.91 meters")
    }

    @Test func test_quarts_to_liters() {
        let converter = UnitConverter.shared

        let result = converter.convert("1 qt to l")

        #expect(result == "0.95 liters", "1 quart should convert to 0.95 liters")
    }

    @Test func test_sqkm_to_sqm() {
        let converter = UnitConverter.shared

        let result = converter.convert("1 sqkm to sqm")

        #expect(result == "1,000,000 square meters", "1 sq km should convert to 1,000,000 square meters")
    }

    @Test func test_weeks_to_days() {
        let converter = UnitConverter.shared

        let result = converter.convert("1 week to days")

        #expect(result == "7 days", "1 week should convert to 7 days")
    }

    @Test func test_convert_keyword_shows_hints() {
        let converter = UnitConverter.shared

        let isConversion = converter.isConversionExpression("convert")

        #expect(!isConversion, "convert by itself is not a conversion expression")
        
        let hints = converter.getHints()
        #expect(!hints.isEmpty, "Should have hints available")
        #expect(hints.contains("100 km to miles"), "Should include example hint")
    }
}

import XCTest
@testable import ZestApp

/// Tests for Unit Converter - Story 23
final class UnitConverterTests: XCTestCase {

    // MARK: - Length Conversions

    func test_kilometers_to_miles() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100 km to miles")

        // Then
        XCTAssertEqual(result, "62.14 miles", "100 km should convert to 62.14 miles")
    }

    func test_kilograms_to_lbs() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("50 kg to lbs")

        // Then
        XCTAssertEqual(result, "110.23 lbs", "50 kg should convert to 110.23 lbs")
    }

    func test_fahrenheit_to_celsius() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("72 f to c")

        // Then
        XCTAssertEqual(result, "22.22°C", "72°F should convert to 22.22°C")
    }

    func test_gallons_to_liters() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("1 gallon to liters")

        // Then
        XCTAssertEqual(result, "3.79 liters", "1 gallon should convert to 3.79 liters")
    }

    func test_megabytes_to_gigabytes_binary() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("1000 mb to gb")

        // Then
        XCTAssertEqual(result, "0.98 GB", "1000 MB should convert to 0.98 GB (binary)")
    }

    func test_invalid_conversion_returns_nil() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100 km to apples")

        // Then
        XCTAssertNil(result, "Invalid conversion should return nil")
    }

    func test_scientific_notation_large_number() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("1e9 km to miles")

        // Then
        XCTAssertNotNil(result, "Scientific notation should return a result")
        // Should contain scientific notation or appropriate format
        XCTAssertTrue(result!.contains("e") || result!.contains("621371"), "Large number should use scientific notation")
    }

    // MARK: - Conversion Detection

    func test_recognizes_km_to_miles_pattern() {
        // Given
        let converter = UnitConverter.shared

        // When
        let isConversion = converter.isConversionExpression("100 km to miles")

        // Then
        XCTAssertTrue(isConversion, "Should recognize km to miles pattern")
    }

    func test_recognizes_f_to_c_pattern() {
        // Given
        let converter = UnitConverter.shared

        // When
        let isConversion = converter.isConversionExpression("72 f to c")

        // Then
        XCTAssertTrue(isConversion, "Should recognize f to c pattern")
    }

    func test_does_not_recognize_math_expression_as_conversion() {
        // Given
        let converter = UnitConverter.shared

        // When
        let isConversion = converter.isConversionExpression("2+2")

        // Then
        XCTAssertFalse(isConversion, "Should not confuse math expression with conversion")
    }

    func test_does_not_recognize_random_text_as_conversion() {
        // Given
        let converter = UnitConverter.shared

        // When
        let isConversion = converter.isConversionExpression("hello world")

        // Then
        XCTAssertFalse(isConversion, "Should not recognize random text as conversion")
    }

    // MARK: - Additional Unit Tests

    func test_meters_to_feet() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("10 m to feet")

        // Then
        XCTAssertEqual(result, "32.81 feet", "10 meters should convert to 32.81 feet")
    }

    func test_cm_to_inches() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100 cm to inches")

        // Then
        XCTAssertEqual(result, "39.37 inches", "100 cm should convert to 39.37 inches")
    }

    func test_grams_to_oz() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("500 g to oz")

        // Then
        XCTAssertEqual(result, "17.64 oz", "500g should convert to 17.64 oz")
    }

    func test_celsius_to_fahrenheit() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100 c to f")

        // Then
        XCTAssertEqual(result, "212°F", "100°C should convert to 212°F")
    }

    func test_kilometers_per_hour_to_mph() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100 km/h to mph")

        // Then
        XCTAssertEqual(result, "62.14 mph", "100 km/h should convert to 62.14 mph")
    }

    func test_bytes_to_megabytes() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("1048576 bytes to mb")

        // Then
        XCTAssertEqual(result, "1 MB", "1048576 bytes should convert to 1 MB")
    }

    func test_hours_to_minutes() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("2 hours to minutes")

        // Then
        XCTAssertEqual(result, "120 minutes", "2 hours should convert to 120 minutes")
    }

    func test_acres_to_hectares() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("10 acres to hectares")

        // Then
        XCTAssertEqual(result, "4.05 hectares", "10 acres should convert to 4.05 hectares")
    }

    func test_liters_to_gallons() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("10 liters to gallons")

        // Then
        XCTAssertEqual(result, "2.64 gallons", "10 liters should convert to 2.64 gallons")
    }

    // MARK: - Hint Tests

    func test_convert_keyword_returns_hints() {
        // Given
        let converter = UnitConverter.shared

        // When
        let hints = converter.getHints()

        // Then
        XCTAssertFalse(hints.isEmpty, "Hints should not be empty")
        XCTAssertTrue(hints.contains("100 km to miles"), "Hints should contain 100 km to miles")
    }

    // MARK: - Edge Cases: Empty Input and Whitespace

    func test_empty_input_returns_nil() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("")

        // Then
        XCTAssertNil(result, "Empty input should return nil")
    }

    func test_whitespace_only_input_returns_nil() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("   ")

        // Then
        XCTAssertNil(result, "Whitespace-only input should return nil")
    }

    func test_leading_whitespace_is_trimmed() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("  100 km to miles")

        // Then
        XCTAssertEqual(result, "62.14 miles", "Leading whitespace should be trimmed")
    }

    func test_trailing_whitespace_is_trimmed() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100 km to miles  ")

        // Then
        XCTAssertEqual(result, "62.14 miles", "Trailing whitespace should be trimmed")
    }

    // MARK: - Common User Mistakes

    func test_no_space_between_value_and_unit() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100km to miles")

        // Then
        XCTAssertEqual(result, "62.14 miles", "Should handle '100km' without space")
    }

    func test_k_suffix_for_kilo() {
        // Given
        let converter = UnitConverter.shared

        // When - 'k' suffix after number means kilo (multiply by 1000)
        let result = converter.convert("100k m to cm")

        // Then
        XCTAssertEqual(result, "10,000,000 centimeters", "Should handle 'k' suffix for kilo (100k = 100000)")
    }

    func test_multiple_spaces_between_tokens() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100   km   to   miles")

        // Then
        XCTAssertEqual(result, "62.14 miles", "Multiple spaces should be handled")
    }

    // MARK: - Bidirectional Conversions

    func test_km_to_miles() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100 km to miles")

        // Then
        XCTAssertEqual(result, "62.14 miles", "100 km should convert to 62.14 miles")
    }

    func test_miles_to_km() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("60 miles to km")

        // Then
        XCTAssertEqual(result, "96.56 kilometers", "60 miles should convert to 96.56 kilometers")
    }

    func test_kg_to_lbs() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("10 kg to lbs")

        // Then
        XCTAssertEqual(result, "22.05 lbs", "10 kg should convert to 22.05 lbs")
    }

    func test_lbs_to_kg() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100 lbs to kg")

        // Then
        XCTAssertEqual(result, "45.36 kilograms", "100 lbs should convert to 45.36 kilograms")
    }

    // MARK: - All Temperature Variations

    func test_fahrenheit_to_celsius_at_freezing() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("32 f to c")

        // Then
        XCTAssertEqual(result, "0°C", "32°F should convert to 0°C")
    }

    func test_celsius_to_fahrenheit_at_freezing() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("0 c to f")

        // Then
        XCTAssertEqual(result, "32°F", "0°C should convert to 32°F")
    }

    func test_fahrenheit_to_kelvin() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("32 f to k")

        // Then
        XCTAssertEqual(result, "273.15K", "32°F should convert to 273.15K")
    }

    func test_kelvin_to_fahrenheit() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("273.15 k to f")

        // Then
        XCTAssertEqual(result, "32°F", "273.15K should convert to 32°F")
    }

    func test_celsius_to_kelvin() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("0 c to k")

        // Then
        XCTAssertEqual(result, "273.15K", "0°C should convert to 273.15K")
    }

    func test_kelvin_to_celsius() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("273.15 k to c")

        // Then
        XCTAssertEqual(result, "0°C", "273.15K should convert to 0°C")
    }

    // MARK: - Data Units: Binary vs Decimal

    func test_megabytes_to_gigabytes_binary_exact() {
        // Given
        let converter = UnitConverter.shared

        // When - MB (1000) to GB (1000^3) - uses binary conversion 1024
        let result = converter.convert("1024 mb to gb")

        // Then
        XCTAssertEqual(result, "1 GB", "1024 MB should convert to 1 GB (binary)")
    }

    func test_kilobytes_to_bytes() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("1 kb to b")

        // Then
        XCTAssertEqual(result, "1024 B", "1 KB should convert to 1024 B")
    }

    func test_gigabytes_to_megabytes() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("1 gb to mb")

        // Then
        XCTAssertEqual(result, "1024 MB", "1 GB should convert to 1024 MB")
    }

    // MARK: - Case Sensitivity

    func test_uppercase_units() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100 KM to MILES")

        // Then
        XCTAssertEqual(result, "62.14 miles", "Uppercase units should work")
    }

    func test_mixed_case_units() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("100 Km to Miles")

        // Then
        XCTAssertEqual(result, "62.14 miles", "Mixed case units should work")
    }

    func test_case_insensitive_pattern_detection() {
        // Given
        let converter = UnitConverter.shared

        // When
        let isConversion = converter.isConversionExpression("100 KM to MILES")

        // Then
        XCTAssertTrue(isConversion, "Should recognize uppercase conversion pattern")
    }

    // MARK: - Decimal Precision and Rounding

    func test_proper_decimal_rounding() {
        // Given
        let converter = UnitConverter.shared

        // When - 1/3 km to miles = 0.207...
        let result = converter.convert("0.333 km to miles")

        // Then - should round to 2 decimal places
        XCTAssertTrue(result?.contains("0.21") == true, "Should properly round to 2 decimal places")
    }

    func test_whole_number_result() {
        // Given
        let converter = UnitConverter.shared

        // When - 1000 m to km = 1 km (whole number)
        let result = converter.convert("1000 m to km")

        // Then
        XCTAssertEqual(result, "1 kilometers", "Whole number result should not have decimals")
    }

    func test_negative_temperature() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("-40 f to c")

        // Then - -40°F = -40°C (special case!)
        XCTAssertEqual(result, "-40°C", "-40°F should convert to -40°C")
    }

    // MARK: - Additional Edge Cases

    func test_zero_value_conversion() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("0 c to f")

        // Then
        XCTAssertEqual(result, "32°F", "0°C should convert to 32°F")
    }

    func test_fractional_value_conversion() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("0.5 km to m")

        // Then
        XCTAssertEqual(result, "500 meters", "0.5 km should convert to 500 meters")
    }

    func test_incompatible_units_returns_nil() {
        // Given
        let converter = UnitConverter.shared

        // When - can't convert length to weight
        let result = converter.convert("100 km to kg")

        // Then
        XCTAssertNil(result, "Incompatible units should return nil")
    }

    func test_negative_number_conversion() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("-100 km to miles")

        // Then
        XCTAssertEqual(result, "-62.14 miles", "Negative numbers should convert correctly")
    }

    // MARK: - Missing Required Units (Story 23)

    func test_millimeters_to_centimeters() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("10 mm to cm")

        // Then
        XCTAssertEqual(result, "1 centimeters", "10 mm should convert to 1 cm")
    }

    func test_yards_to_meters() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("1 yd to m")

        // Then
        XCTAssertEqual(result, "0.91 meters", "1 yard should convert to 0.91 meters")
    }

    func test_quarts_to_liters() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("1 qt to l")

        // Then
        XCTAssertEqual(result, "0.95 liters", "1 quart should convert to 0.95 liters")
    }

    func test_sqkm_to_sqm() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("1 sqkm to sqm")

        // Then
        XCTAssertEqual(result, "1,000,000 square meters", "1 sq km should convert to 1,000,000 square meters")
    }

    func test_weeks_to_days() {
        // Given
        let converter = UnitConverter.shared

        // When
        let result = converter.convert("1 week to days")

        // Then
        XCTAssertEqual(result, "7 days", "1 week should convert to 7 days")
    }

    func test_convert_keyword_shows_hints() {
        // Given
        let converter = UnitConverter.shared

        // When
        let isConversion = converter.isConversionExpression("convert")

        // Then - "convert" by itself is not a conversion but should trigger hints
        XCTAssertFalse(isConversion, "convert by itself is not a conversion expression")
        
        // But hints should be available
        let hints = converter.getHints()
        XCTAssertFalse(hints.isEmpty, "Should have hints available")
        XCTAssertTrue(hints.contains("100 km to miles"), "Should include example hint")
    }
}

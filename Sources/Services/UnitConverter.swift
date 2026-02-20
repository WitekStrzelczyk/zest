import Foundation

/// Service for converting between different units of measurement
final class UnitConverter {
    static let shared: UnitConverter = .init()

    private init() {}

    // MARK: - Unit Definitions

    /// Supported unit categories
    enum UnitCategory: String, CaseIterable {
        case length = "Length"
        case weight = "Weight"
        case temperature = "Temperature"
        case volume = "Volume"
        case area = "Area"
        case speed = "Speed"
        case time = "Time"
        case data = "Data"
    }

    /// Unit with its category and conversion factor to base unit
    struct Unit {
        let name: String
        let abbreviations: [String]
        let category: UnitCategory
        let toBaseUnit: (Double) -> Double
        let fromBaseUnit: (Double) -> Double

        /// Check if this unit matches the given abbreviation
        func matches(_ abbrev: String) -> Bool {
            abbreviations.contains { $0.lowercased() == abbrev.lowercased() }
        }
    }

    /// All supported units
    private let units: [Unit] = [
        // MARK: - Length (base: meters)
        Unit(
            name: "kilometers",
            abbreviations: ["km", "kilometer", "kilometers"],
            category: .length,
            toBaseUnit: { $0 * 1000 },
            fromBaseUnit: { $0 / 1000 }
        ),
        Unit(
            name: "miles",
            abbreviations: ["mi", "mile", "miles"],
            category: .length,
            toBaseUnit: { $0 * 1609.344 },
            fromBaseUnit: { $0 / 1609.344 }
        ),
        Unit(
            name: "meters",
            abbreviations: ["m", "meter", "meters"],
            category: .length,
            toBaseUnit: { $0 },
            fromBaseUnit: { $0 }
        ),
        Unit(
            name: "feet",
            abbreviations: ["ft", "foot", "feet"],
            category: .length,
            toBaseUnit: { $0 * 0.3048 },
            fromBaseUnit: { $0 / 0.3048 }
        ),
        Unit(
            name: "centimeters",
            abbreviations: ["cm", "centimeter", "centimeters"],
            category: .length,
            toBaseUnit: { $0 / 100 },
            fromBaseUnit: { $0 * 100 }
        ),
        Unit(
            name: "inches",
            abbreviations: ["in", "inch", "inches"],
            category: .length,
            toBaseUnit: { $0 * 0.0254 },
            fromBaseUnit: { $0 / 0.0254 }
        ),

        // MARK: - Weight (base: kilograms)
        Unit(
            name: "kilograms",
            abbreviations: ["kg", "kilogram", "kilograms"],
            category: .weight,
            toBaseUnit: { $0 },
            fromBaseUnit: { $0 }
        ),
        Unit(
            name: "pounds",
            abbreviations: ["lb", "lbs", "pound", "pounds"],
            category: .weight,
            toBaseUnit: { $0 * 0.453592 },
            fromBaseUnit: { $0 / 0.453592 }
        ),
        Unit(
            name: "grams",
            abbreviations: ["g", "gram", "grams"],
            category: .weight,
            toBaseUnit: { $0 / 1000 },
            fromBaseUnit: { $0 * 1000 }
        ),
        Unit(
            name: "ounces",
            abbreviations: ["oz", "ounce", "ounces"],
            category: .weight,
            toBaseUnit: { $0 * 0.0283495 },
            fromBaseUnit: { $0 / 0.0283495 }
        ),

        // MARK: - Temperature (base: Celsius)
        Unit(
            name: "celsius",
            abbreviations: ["c", "celsius", "centigrade"],
            category: .temperature,
            toBaseUnit: { $0 },
            fromBaseUnit: { $0 }
        ),
        Unit(
            name: "fahrenheit",
            abbreviations: ["f", "fahrenheit"],
            category: .temperature,
            toBaseUnit: { ($0 - 32) * 5 / 9 },
            fromBaseUnit: { $0 * 9 / 5 + 32 }
        ),
        Unit(
            name: "kelvin",
            abbreviations: ["k", "kelvin"],
            category: .temperature,
            toBaseUnit: { $0 - 273.15 },
            fromBaseUnit: { $0 + 273.15 }
        ),

        // MARK: - Volume (base: liters)
        Unit(
            name: "liters",
            abbreviations: ["l", "liter", "liters", "litre", "litres"],
            category: .volume,
            toBaseUnit: { $0 },
            fromBaseUnit: { $0 }
        ),
        Unit(
            name: "gallons",
            abbreviations: ["gal", "gallon", "gallons"],
            category: .volume,
            toBaseUnit: { $0 * 3.78541 },
            fromBaseUnit: { $0 / 3.78541 }
        ),
        Unit(
            name: "milliliters",
            abbreviations: ["ml", "milliliter", "milliliters"],
            category: .volume,
            toBaseUnit: { $0 / 1000 },
            fromBaseUnit: { $0 * 1000 }
        ),
        Unit(
            name: "cups",
            abbreviations: ["cup", "cups"],
            category: .volume,
            toBaseUnit: { $0 * 0.236588 },
            fromBaseUnit: { $0 / 0.236588 }
        ),

        // MARK: - Area (base: square meters)
        Unit(
            name: "square meters",
            abbreviations: ["sq m", "sqm", "m2", "m^2", "square meter", "square meters"],
            category: .area,
            toBaseUnit: { $0 },
            fromBaseUnit: { $0 }
        ),
        Unit(
            name: "square feet",
            abbreviations: ["sq ft", "sqft", "ft2", "ft^2", "square foot", "square feet"],
            category: .area,
            toBaseUnit: { $0 * 0.092903 },
            fromBaseUnit: { $0 / 0.092903 }
        ),
        Unit(
            name: "acres",
            abbreviations: ["acre", "acres"],
            category: .area,
            toBaseUnit: { $0 * 4046.86 },
            fromBaseUnit: { $0 / 4046.86 }
        ),
        Unit(
            name: "hectares",
            abbreviations: ["ha", "hectare", "hectares"],
            category: .area,
            toBaseUnit: { $0 * 10000 },
            fromBaseUnit: { $0 / 10000 }
        ),

        // MARK: - Speed (base: meters per second)
        Unit(
            name: "meters per second",
            abbreviations: ["m/s", "mps"],
            category: .speed,
            toBaseUnit: { $0 },
            fromBaseUnit: { $0 }
        ),
        Unit(
            name: "kilometers per hour",
            abbreviations: ["km/h", "kmh", "kph"],
            category: .speed,
            toBaseUnit: { $0 / 3.6 },
            fromBaseUnit: { $0 * 3.6 }
        ),
        Unit(
            name: "miles per hour",
            abbreviations: ["mph", "mi/h"],
            category: .speed,
            toBaseUnit: { $0 * 0.44704 },
            fromBaseUnit: { $0 / 0.44704 }
        ),
        Unit(
            name: "knots",
            abbreviations: ["kn", "knot", "knots"],
            category: .speed,
            toBaseUnit: { $0 * 0.514444 },
            fromBaseUnit: { $0 / 0.514444 }
        ),

        // MARK: - Time (base: seconds)
        Unit(
            name: "seconds",
            abbreviations: ["s", "sec", "second", "seconds"],
            category: .time,
            toBaseUnit: { $0 },
            fromBaseUnit: { $0 }
        ),
        Unit(
            name: "minutes",
            abbreviations: ["min", "minute", "minutes"],
            category: .time,
            toBaseUnit: { $0 * 60 },
            fromBaseUnit: { $0 / 60 }
        ),
        Unit(
            name: "hours",
            abbreviations: ["h", "hr", "hour", "hours"],
            category: .time,
            toBaseUnit: { $0 * 3600 },
            fromBaseUnit: { $0 / 3600 }
        ),
        Unit(
            name: "days",
            abbreviations: ["d", "day", "days"],
            category: .time,
            toBaseUnit: { $0 * 86400 },
            fromBaseUnit: { $0 / 86400 }
        ),

        // MARK: - Data (base: bytes, binary 1024)
        Unit(
            name: "bytes",
            abbreviations: ["b", "byte", "bytes"],
            category: .data,
            toBaseUnit: { $0 },
            fromBaseUnit: { $0 }
        ),
        Unit(
            name: "kilobytes",
            abbreviations: ["kb", "kilobyte", "kilobytes"],
            category: .data,
            toBaseUnit: { $0 * 1024 },
            fromBaseUnit: { $0 / 1024 }
        ),
        Unit(
            name: "megabytes",
            abbreviations: ["mb", "megabyte", "megabytes"],
            category: .data,
            toBaseUnit: { $0 * 1024 * 1024 },
            fromBaseUnit: { $0 / (1024 * 1024) }
        ),
        Unit(
            name: "gigabytes",
            abbreviations: ["gb", "gigabyte", "gigabytes"],
            category: .data,
            toBaseUnit: { $0 * 1024 * 1024 * 1024 },
            fromBaseUnit: { $0 / (1024 * 1024 * 1024) }
        ),
        Unit(
            name: "terabytes",
            abbreviations: ["tb", "terabyte", "terabytes"],
            category: .data,
            toBaseUnit: { $0 * 1024 * 1024 * 1024 * 1024 },
            fromBaseUnit: { $0 / (1024 * 1024 * 1024 * 1024) }
        ),
    ]

    // MARK: - Pattern Matching

    /// Regex to match conversion expressions like "100 km to miles" or "100k m to cm"
    /// Supports: numbers (including negative, decimal, scientific), 'k' suffix for kilo (e.g., "100k m" = 100000 m)
    private let conversionPattern = #"^(-?[\d.kKeE+-]+)\s*([a-zA-Z/]+)\s+(?:to|in|->)\s+([a-zA-Z/]+)$"#

    /// Parse value with optional kilo suffix (e.g., "100k" = 100000, "-100k" = -100000)
    private func parseValueWithKiloSuffix(_ valueStr: String) -> Double? {
        // Check if value ends with 'k' or 'K' (kilo suffix)
        if valueStr.hasSuffix("k") || valueStr.hasSuffix("K") {
            let baseStr = String(valueStr.dropLast())
            guard let baseValue = Double(baseStr) else {
                return nil
            }
            return baseValue * 1000
        }
        return Double(valueStr)
    }

    /// Check if input looks like a conversion expression
    func isConversionExpression(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Must not be a math expression
        if Calculator.shared.isMathExpression(trimmed) {
            return false
        }

        // Match against conversion pattern
        guard let regex = try? NSRegularExpression(pattern: conversionPattern, options: []) else {
            return false
        }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range) else {
            return false
        }

        // Extract unit abbreviations
        guard let fromAbbrevRange = Range(match.range(at: 2), in: trimmed),
              let toAbbrevRange = Range(match.range(at: 3), in: trimmed) else {
            return false
        }

        let fromAbbrev = String(trimmed[fromAbbrevRange])
        let toAbbrev = String(trimmed[toAbbrevRange])

        // Both must be valid units
        return findUnit(fromAbbrev) != nil && findUnit(toAbbrev) != nil
    }

    /// Convert a value from one unit to another
    func convert(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        guard isConversionExpression(trimmed) else {
            return nil
        }

        // Parse the conversion expression
        guard let regex = try? NSRegularExpression(pattern: conversionPattern, options: []) else {
            return nil
        }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range) else {
            return nil
        }

        // Extract value and units
        guard let valueRange = Range(match.range(at: 1), in: trimmed),
              let fromAbbrevRange = Range(match.range(at: 2), in: trimmed),
              let toAbbrevRange = Range(match.range(at: 3), in: trimmed) else {
            return nil
        }

        let valueStr = String(trimmed[valueRange])
        let fromAbbrev = String(trimmed[fromAbbrevRange])
        let toAbbrev = String(trimmed[toAbbrevRange])

        // Parse the numeric value (support scientific notation and kilo suffix)
        guard let value = parseValueWithKiloSuffix(valueStr) else {
            return nil
        }

        // Find the units
        guard let fromUnit = findUnit(fromAbbrev),
              let toUnit = findUnit(toAbbrev) else {
            return nil
        }

        // Check if conversion is valid (same category)
        guard fromUnit.category == toUnit.category else {
            return nil
        }

        // Perform conversion
        let baseValue = fromUnit.toBaseUnit(value)
        let result = toUnit.fromBaseUnit(baseValue)

        return formatResult(result, unit: toUnit)
    }

    /// Find a unit by abbreviation
    private func findUnit(_ abbrev: String) -> Unit? {
        units.first { $0.matches(abbrev) }
    }

    /// Format the result with appropriate precision
    private func formatResult(_ value: Double, unit: Unit) -> String {
        if value.isNaN || value.isInfinite {
            return "Error"
        }

        // Format based on value magnitude
        let formatted: String

        if value == 0 {
            formatted = "0"
        } else if abs(value) >= 1e9 || (abs(value) < 0.001 && value != 0) {
            // Use scientific notation for very large or very small numbers
            let formatter = ScientificNotationFormatter.shared
            formatted = formatter.format(value)
        } else if value == value.rounded() && abs(value) < 1e6 {
            // Whole number
            formatted = String(Int(value.rounded()))
        } else {
            // Regular decimal with appropriate precision
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2

            // Remove trailing zeros
            formatter.minimumFractionDigits = 0

            formatted = formatter.string(from: NSNumber(value: value)) ?? String(value)
        }

        // Get appropriate unit display name based on category and unit
        let unitDisplay: String

        // Add degree symbol for temperature
        if unit.category == .temperature && unit.name == "celsius" {
            return "\(formatted)°C"
        } else if unit.category == .temperature && unit.name == "fahrenheit" {
            return "\(formatted)°F"
        } else if unit.category == .temperature && unit.name == "kelvin" {
            return "\(formatted)K"
        } else if unit.category == .data {
            // Use standard data abbreviations
            switch unit.name {
            case "bytes": unitDisplay = "B"
            case "kilobytes": unitDisplay = "KB"
            case "megabytes": unitDisplay = "MB"
            case "gigabytes": unitDisplay = "GB"
            case "terabytes": unitDisplay = "TB"
            default: unitDisplay = unit.name.uppercased()
            }
        } else if unit.category == .weight {
            // Use common abbreviations for weight
            switch unit.name {
            case "pounds": unitDisplay = "lbs"
            case "ounces": unitDisplay = "oz"
            default: unitDisplay = unit.name
            }
        } else if unit.category == .speed {
            // Use common abbreviations for speed
            switch unit.name {
            case "kilometers per hour": unitDisplay = "km/h"
            case "miles per hour": unitDisplay = "mph"
            case "meters per second": unitDisplay = "m/s"
            case "knots": unitDisplay = "knots"
            default: unitDisplay = unit.name
            }
        } else if unit.category == .time {
            // Use common abbreviations for time
            switch unit.name {
            case "seconds": unitDisplay = "seconds"
            case "minutes": unitDisplay = "minutes"
            case "hours": unitDisplay = "hours"
            case "days": unitDisplay = "days"
            default: unitDisplay = unit.name
            }
        } else {
            unitDisplay = unit.name
        }

        return "\(formatted) \(unitDisplay)"
    }

    // MARK: - Hints

    /// Get example conversion hints
    func getHints() -> [String] {
        return [
            "100 km to miles",
            "50 kg to lbs",
            "72 f to c",
            "1 gallon to liters",
            "1000 mb to gb",
            "10 m to feet",
            "100 cm to inches",
            "500 g to oz",
            "100 km/h to mph",
            "2 hours to minutes",
            "10 acres to hectares"
        ]
    }
}

// MARK: - Scientific Notation Formatter

/// Helper to format numbers in scientific notation
final class ScientificNotationFormatter {
    static let shared: ScientificNotationFormatter = .init()

    private init() {}

    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    func format(_ value: Double) -> String {
        let exponent = Int(floor(log10(abs(value))))
        let mantissa = value / pow(10, Double(exponent))

        let mantissaStr = formatter.string(from: NSNumber(value: mantissa)) ?? String(mantissa)

        return "\(mantissaStr)e\(exponent >= 0 ? "+" : "")\(exponent)"
    }
}

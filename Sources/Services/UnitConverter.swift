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
            name: "millimeters",
            abbreviations: ["mm", "millimeter", "millimeters"],
            category: .length,
            toBaseUnit: { $0 / 1000 },
            fromBaseUnit: { $0 * 1000 }
        ),
        Unit(
            name: "yards",
            abbreviations: ["yd", "yard", "yards"],
            category: .length,
            toBaseUnit: { $0 * 0.9144 },
            fromBaseUnit: { $0 / 0.9144 }
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
        Unit(
            name: "quarts",
            abbreviations: ["qt", "quart", "quarts"],
            category: .volume,
            toBaseUnit: { $0 * 0.946353 },
            fromBaseUnit: { $0 / 0.946353 }
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
            name: "square kilometers",
            abbreviations: ["sq km", "sqkm", "km2", "km^2", "square kilometer", "square kilometers"],
            category: .area,
            toBaseUnit: { $0 * 1_000_000 },
            fromBaseUnit: { $0 / 1_000_000 }
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
        Unit(
            name: "weeks",
            abbreviations: ["w", "week", "weeks"],
            category: .time,
            toBaseUnit: { $0 * 604_800 },
            fromBaseUnit: { $0 / 604_800 }
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

    /// Check if input looks like a conversion expression
    func isConversionExpression(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Must not be a math expression
        if Calculator.shared.isMathExpression(trimmed) {
            return false
        }

        let scanner = Scanner(string: trimmed.lowercased())
        _ = scanner.scanString("convert")

        guard scanner.scanDouble() != nil else { return false }

        // Skip to " to " or " in "
        if trimmed.lowercased().contains(" to ") || trimmed.lowercased().contains(" in ") {
            return true
        }

        // Check for immediate unit after number
        let letters = CharacterSet.letters
        if let fromUnit = scanner.scanCharacters(from: letters), findUnit(fromUnit) != nil {
            _ = scanner.scanString("to")
            _ = scanner.scanString("in")
            if let toUnit = scanner.scanCharacters(from: letters), findUnit(toUnit) != nil {
                return true
            }
        }

        return false
    }

    /// Convert a value from one unit to another
    func convert(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Use QueryAnalyzer to get context for the worker
        let context = QueryAnalyzer.shared.analyze(trimmed)

        guard let intent = UnitConversionWorker.shared.parse(context: context) else {
            return nil
        }

        // Find the units
        guard let fromUnit = findUnit(intent.fromUnit),
              let toUnit = findUnit(intent.toUnit)
        else {
            return nil
        }

        // Check if conversion is valid (same category)
        guard fromUnit.category == toUnit.category else {
            return nil
        }

        // Perform conversion
        let baseValue = fromUnit.toBaseUnit(intent.value)
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
        let formatted = formatValue(value)
        let unitDisplay = getUnitDisplay(unit)

        return "\(formatted) \(unitDisplay)"
    }

    /// Format the numeric value based on its magnitude
    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if abs(value) >= 1e9 || (abs(value) < 0.001 && value != 0) {
            // Use scientific notation for very large or very small numbers
            let formatter = ScientificNotationFormatter.shared
            return formatter.format(value)
        } else if value == value.rounded(), abs(value) < 1e6 {
            // Whole number
            return String(Int(value.rounded()))
        } else {
            // Regular decimal with appropriate precision
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2

            // Remove trailing zeros
            formatter.minimumFractionDigits = 0

            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }
    }

    /// Get the display string for a unit
    private func getUnitDisplay(_ unit: Unit) -> String {
        // Add degree symbol for temperature
        if unit.category == .temperature, unit.name == "celsius" {
            return "\(formatValue(0))°C".replacingOccurrences(of: "0°C", with: "°C")
        }

        switch unit.category {
        case .temperature:
            return temperatureDisplay(unit)
        case .data:
            return dataDisplay(unit)
        case .weight:
            return weightDisplay(unit)
        case .speed:
            return speedDisplay(unit)
        case .time:
            return timeDisplay(unit)
        default:
            return unit.name
        }
    }

    private func temperatureDisplay(_ unit: Unit) -> String {
        switch unit.name {
        case "celsius": "°C"
        case "fahrenheit": "°F"
        case "kelvin": "K"
        default: unit.name
        }
    }

    private func dataDisplay(_ unit: Unit) -> String {
        switch unit.name {
        case "bytes": "B"
        case "kilobytes": "KB"
        case "megabytes": "MB"
        case "gigabytes": "GB"
        case "terabytes": "TB"
        default: unit.name.uppercased()
        }
    }

    private func weightDisplay(_ unit: Unit) -> String {
        switch unit.name {
        case "pounds": "lbs"
        case "ounces": "oz"
        default: unit.name
        }
    }

    private func speedDisplay(_ unit: Unit) -> String {
        switch unit.name {
        case "kilometers per hour": "km/h"
        case "miles per hour": "mph"
        case "meters per second": "m/s"
        case "knots": "knots"
        default: unit.name
        }
    }

    private func timeDisplay(_ unit: Unit) -> String {
        switch unit.name {
        case "seconds": "seconds"
        case "minutes": "minutes"
        case "hours": "hours"
        case "days": "days"
        default: unit.name
        }
    }

    // MARK: - Hints

    /// Get example conversion hints
    func getHints() -> [String] {
        [
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
            "10 acres to hectares",
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

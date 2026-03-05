import Foundation

struct ConversionIntent {
    let value: Double
    let fromUnit: String
    let toUnit: String
}

class UnitConversionWorker {
    static let shared = UnitConversionWorker()
    private init() {}

    func parse(context: QueryContext) -> ConversionIntent? {
        // Must have at least one number
        guard let value = context.numbers.first else { return nil }

        // Check for "to" or "in" triggers
        let lower = context.normalized.lowercased()
        guard lower.contains(" to ") || lower.contains(" in ") else { return nil }

        // Use Scanner just for the unit names since we already have the number
        let scanner = Scanner(string: lower)
        _ = scanner.scanUpToCharacters(from: .decimalDigits)
        _ = scanner.scanDouble() // Skip the number
        _ = scanner.scanCharacters(from: .whitespaces)

        guard let fromString = scanner.scanUpToString(" to ")?.trimmingCharacters(in: .whitespaces) ??
            scanner.scanUpToString(" in ")?.trimmingCharacters(in: .whitespaces) else { return nil }

        _ = scanner.scanString("to")
        _ = scanner.scanString("in")

        guard let toString = scanner.scanCharacters(from: .letters)?.trimmingCharacters(in: .whitespaces)
        else { return nil }

        return ConversionIntent(value: Double(value), fromUnit: fromString, toUnit: toString)
    }

    func execute(intent: ConversionIntent) -> String? {
        let query = "\(intent.value) \(intent.fromUnit) to \(intent.toUnit)"
        return UnitConverter.shared.convert(query)
    }
}

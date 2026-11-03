import AppKit

struct ConversionIntent {
    let value: Double
    let fromUnit: String
    let toUnit: String
}

class UnitConversionWorker {
    static let shared = UnitConversionWorker()
    private init() {}

    private static let pattern = try? NSRegularExpression(
        pattern: #"(-?\d+(?:\.\d+)?(?:e\d+)?)\s*(.+?)\s+(?:to|in)\s+(\S+)\s*$"#
    )

    func parse(context: QueryContext) -> ConversionIntent? {
        let lower = context.normalized.lowercased()
        let range = NSRange(lower.startIndex..., in: lower)
        guard let match = Self.pattern?.firstMatch(in: lower, range: range),
              let valueRange = Range(match.range(at: 1), in: lower),
              let fromRange = Range(match.range(at: 2), in: lower),
              let toRange = Range(match.range(at: 3), in: lower),
              var value = Double(lower[valueRange])
        else { return nil }

        var fromUnit = String(lower[fromRange])
        if fromUnit.hasPrefix("k ") {
            value *= 1000
            fromUnit = String(fromUnit.dropFirst(2))
        }

        return ConversionIntent(value: value, fromUnit: fromUnit, toUnit: String(lower[toRange]))
    }

    func execute(intent: ConversionIntent) -> String? {
        let query = "\(intent.value) \(intent.fromUnit) to \(intent.toUnit)"
        return UnitConverter.shared.convert(query)
    }
}

extension UnitConversionWorker: SearchTool {
    private static let icon = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "Unit Converter")

    var name: String { "Unit Conversion" }

    func search(_ context: QueryContext) -> [SearchResult] {
        if context.normalized.lowercased() == "convert" {
            return UnitConverter.shared.getHints().map { hint in
                SearchResult(
                    title: hint,
                    subtitle: "Unit Conversion Example",
                    icon: Self.icon,
                    category: .conversion,
                    action: {},
                    score: 2000
                )
            }
        }

        guard let intent = parse(context: context), let result = execute(intent: intent) else { return [] }
        return [SearchResult(
            title: result,
            subtitle: "Unit Conversion",
            icon: Self.icon,
            category: .conversion,
            action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
            },
            score: 3000
        )]
    }
}

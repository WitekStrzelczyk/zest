import AppKit

final class Calculator {
    static let shared: Calculator = .init()

    private init() {}

    func isMathExpression(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        let operators = ["+", "-", "*", "/", "^", "%", "√", "sqrt", "sin", "cos", "tan"]
        let hasOperator = operators.contains { trimmed.contains($0) }

        let letters = trimmed.filter(\.isLetter)
        let validFunctions = ["sqrt", "sin", "cos", "tan", "pi", "e"]
        let hasOnlyValidLetters = validFunctions.contains { letters.lowercased().contains($0) } || letters.isEmpty

        let invalidPatterns = ["==", ">=", "<=", "!=", "++", "--", "+ =", "- =", "* =", "/ =", "+ =", "= +", "= -"]
        let hasInvalidPattern = invalidPatterns.contains { trimmed.contains($0) }

        let endsWithOperator = ["+", "-", "*", "/", "^", "%", "("].contains { trimmed.last == $0 }

        let conversionIndicators = ["to ", " in ", "->"]
        let hasConversionIndicator = conversionIndicators.contains { trimmed.lowercased().contains($0) }

        if hasConversionIndicator {
            return false
        }

        return hasOperator && hasOnlyValidLetters && !hasInvalidPattern && !endsWithOperator
    }

    func evaluate(_ input: String) -> String? {
        let expression = input.trimmingCharacters(in: .whitespaces)

        guard isMathExpression(expression) else {
            return nil
        }

        var processed = expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "√", with: "sqrt(")
            .replacingOccurrences(of: "pi", with: String(Double.pi))
            .replacingOccurrences(of: "PI", with: String(Double.pi))
            .replacingOccurrences(of: "e", with: String(M_E))

        processed = processed.replacingOccurrences(
            of: #"(\d)(\()"#,
            with: "$1*(",
            options: .regularExpression
        )

        processed = processed.replacingOccurrences(
            of: #"\)(\d)"#,
            with: ")*$1",
            options: .regularExpression
        )

        processed = processed.replacingOccurrences(of: "^", with: "**")

        guard isValidForNSExpression(processed) else {
            return nil
        }

        do {
            let result = try evaluateExpression(processed)
            return formatResult(result)
        } catch {
            return nil
        }
    }

    private static let parsableCharacters = CharacterSet(charactersIn: "0123456789. +-*/()")

    private func isValidForNSExpression(_ expression: String) -> Bool {
        guard hasOnlyParsableCharacters(expression), hasBalancedParentheses(expression) else { return false }
        return hasNoConsecutiveOperators(expression)
    }

    private func hasOnlyParsableCharacters(_ expression: String) -> Bool {
        let withoutFunctions = expression.replacingOccurrences(of: "sqrt(", with: "(")
        return withoutFunctions.unicodeScalars.allSatisfy { Self.parsableCharacters.contains($0) }
    }

    private func hasBalancedParentheses(_ expression: String) -> Bool {
        var parenCount = 0
        for char in expression {
            if char == "(" { parenCount += 1 }
            if char == ")" { parenCount -= 1 }
            if parenCount < 0 { return false }
        }
        return parenCount == 0
    }

    private func hasNoConsecutiveOperators(_ expression: String) -> Bool {
        let ops = CharacterSet(charactersIn: "+-*/%")
        var prevWasOp = false

        for char in expression {
            if ops.contains(char.unicodeScalars.first!) {
                if prevWasOp { return false }
                prevWasOp = true
            } else if !char.isWhitespace, char != "(" {
                prevWasOp = false
            }
        }

        return true
    }

    private func evaluateExpression(_ expression: String) throws -> Double {
        let nsExpression = NSExpression(format: expression)
        guard let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber else {
            throw NSError(domain: "Calculator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid expression"])
        }
        return result.doubleValue
    }

    private func formatResult(_ value: Double) -> String {
        if value.isNaN || value.isInfinite {
            return "Error"
        }

        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int(value.rounded()))
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0

        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

extension Calculator: SearchTool {
    private static let icon = NSImage(systemSymbolName: "function", accessibilityDescription: "Calculator")

    var name: String { "Calculator" }

    func search(_ context: QueryContext) -> [SearchResult] {
        guard let result = evaluate(context.normalized) else { return [] }
        return [SearchResult(
            title: result,
            subtitle: "Copy to clipboard",
            icon: Self.icon,
            category: .action,
            action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
            },
            score: 3000,
            source: .tool
        )]
    }
}

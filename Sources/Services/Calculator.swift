import Foundation

final class Calculator {
    static let shared: Calculator = {
        let instance = Calculator()
        return instance
    }()

    private init() {}

    /// Check if input looks like a math expression
    func isMathExpression(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Must contain at least one operator
        let operators = ["+", "-", "*", "/", "^", "%", "√", "sqrt", "sin", "cos", "tan"]
        let hasOperator = operators.contains { trimmed.contains($0) }

        // Must not contain letters (except for function names)
        let letters = trimmed.filter(\.isLetter)
        let validFunctions = ["sqrt", "sin", "cos", "tan", "pi", "e"]
        let hasOnlyValidLetters = validFunctions.contains { letters.lowercased().contains($0) } || letters.isEmpty

        return hasOperator && hasOnlyValidLetters
    }

    /// Evaluate a math expression and return result
    func evaluate(_ input: String) -> String? {
        let expression = input.trimmingCharacters(in: .whitespaces)

        guard isMathExpression(expression) else {
            return nil
        }

        // Replace common symbols
        var processed = expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "√", with: "sqrt(")
            .replacingOccurrences(of: "pi", with: String(Double.pi))
            .replacingOccurrences(of: "PI", with: String(Double.pi))
            .replacingOccurrences(of: "e", with: String(M_E))

        // Handle implicit multiplication: 2(3) -> 2*(3)
        processed = processed.replacingOccurrences(
            of: #"(\d)(\()"#,
            with: "$1*(",
            options: .regularExpression
        )

        // Handle implicit multiplication: (3)2 -> (3)*2
        processed = processed.replacingOccurrences(
            of: #"\)(\d)"#,
            with: ")*$1",
            options: .regularExpression
        )

        // Replace ^ with ** for exponentiation
        processed = processed.replacingOccurrences(of: "^", with: "**")

        do {
            let result = try evaluateExpression(processed)
            return formatResult(result)
        } catch {
            return nil
        }
    }

    private func evaluateExpression(_ expression: String) throws -> Double {
        // Use NSExpression for basic evaluation
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

        // Check if it's a whole number
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int(value.rounded()))
        }

        // Format with appropriate precision
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0

        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

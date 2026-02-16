import Foundation

/// Represents a text snippet with variable support
struct Snippet: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var content: String
    var keywords: [String]
    var createdAt: Date
    var lastUsedAt: Date?

    init(id: UUID = UUID(), name: String, content: String, keywords: [String] = [], createdAt: Date = Date(), lastUsedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.content = content
        self.keywords = keywords
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    /// Extracts variable names from content using {variable_name} syntax
    var variables: [String] {
        let pattern = #"\{([^}]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        return matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            return String(content[range])
        }
    }

    /// Expands content with provided variable values
    func expand(with values: [String: String]) -> String {
        var result = content
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}

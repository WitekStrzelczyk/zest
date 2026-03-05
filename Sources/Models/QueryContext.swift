import Foundation

/// A rich representation of the user's query after initial analysis
struct QueryContext {
    let raw: String
    let normalized: String
    let dates: [Date]
    let numbers: [Int]
    let location: String?

    /// The query with numbers and dates removed (useful for name matching)
    let semanticTerm: String

    /// Returns true if the query contains any of the specified keywords
    func contains(anyOf keywords: [String]) -> Bool {
        let lower = normalized.lowercased()
        return keywords.contains { lower.contains($0) }
    }

    func hasPrefix(anyOf keywords: [String]) -> Bool {
        let lower = normalized.lowercased()
        return keywords.contains { lower.hasPrefix($0) }
    }
}

import Foundation

struct QueryContext {
    let raw: String
    let normalized: String
    let dates: [Date]
    let numbers: [Int]
    let location: String?

    let semanticTerm: String

    func contains(anyOf keywords: [String]) -> Bool {
        let lower = normalized.lowercased()
        return keywords.contains { lower.contains($0) }
    }

    func hasPrefix(anyOf keywords: [String]) -> Bool {
        let lower = normalized.lowercased()
        return keywords.contains { lower.hasPrefix($0) }
    }
}

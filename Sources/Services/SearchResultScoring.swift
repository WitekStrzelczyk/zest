import Foundation

/// Service for calculating search result relevance scores
final class SearchResultScoring {
    static let shared: SearchResultScoring = .init()

    private init() {}

    /// Calculate a relevance score for a search result
    /// - Parameters:
    ///   - query: The search query
    ///   - title: The result title to score against
    ///   - subtitle: Optional subtitle to also consider in scoring
    /// - Returns: Score (higher = more relevant)
    ///
    /// Scoring algorithm:
    /// - Exact match (case-insensitive): 1000 points
    /// - Exact prefix match: 800 points
    /// - All query chars at start: 600 points
    /// - All query chars in order (fuzzy): 100-500 points based on quality
    /// - Consecutive matches bonus: +10 per consecutive
    /// - Match after separator (space/-/_): +15
    /// - Substring contains: 50 points (lowest)
    func scoreResult(query: String, title: String, subtitle: String? = nil) -> Int {
        guard !query.isEmpty, !title.isEmpty else { return 0 }

        let lowercasedQuery = query.lowercased()
        let lowercasedTitle = title.lowercased()

        // Exact match (case-insensitive) - highest score
        if lowercasedTitle == lowercasedQuery {
            return 1000
        }

        // Exact prefix match
        if lowercasedTitle.hasPrefix(lowercasedQuery) {
            return 800
        }

        // Check if all query characters appear in order (fuzzy match)
        var score = calculateFuzzyScore(query: lowercasedQuery, target: lowercasedTitle)

        // If fuzzy didn't match all characters, check substring contains
        if score == 0 && lowercasedTitle.contains(lowercasedQuery) {
            score = 50
        }

        // Also check subtitle if provided
        if let subtitle, score < 1000 {
            let subtitleScore = scoreResult(query: query, title: subtitle)
            if subtitleScore > score {
                score = subtitleScore
            }
        }

        return score
    }

    /// Calculate fuzzy score - checks if all query chars appear in order
    private func calculateFuzzyScore(query: String, target: String) -> Int {
        var queryIndex = query.startIndex
        var targetIndex = target.startIndex
        var score = 0
        var consecutiveMatches = 0
        var allCharsMatched = true

        while queryIndex < query.endIndex, targetIndex < target.endIndex {
            if query[queryIndex] == target[targetIndex] {
                // Bonus for consecutive matches
                consecutiveMatches += 1
                score += 10 + (consecutiveMatches * 5)

                // Bonus for match at start of target
                if targetIndex == target.startIndex {
                    score += 20
                }

                // Bonus for match after separator (space, hyphen, underscore)
                if targetIndex != target.startIndex {
                    let prevChar = target[target.index(before: targetIndex)]
                    if prevChar == " " || prevChar == "-" || prevChar == "_" {
                        score += 15
                    }
                }

                queryIndex = query.index(after: queryIndex)
            } else {
                consecutiveMatches = 0
            }
            targetIndex = target.index(after: targetIndex)
        }

        // Only return score if all query characters were matched
        if queryIndex != query.endIndex {
            allCharsMatched = false
        }

        // Scale the score based on match quality
        if allCharsMatched {
            // Base score between 100-500 based on match position
            let baseScore = min(500, max(100, score))
            return baseScore
        }

        return 0
    }
}

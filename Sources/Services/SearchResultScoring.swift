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
    ///   - category: Optional category to also consider in scoring
    /// - Returns: Score (higher = more relevant)
    ///
    /// Scoring algorithm:
    /// - Exact match (case-insensitive): 1000 points
    /// - Prefix of first word: 900 points
    /// - Prefix of any word: 700-850 points based on word position
    /// - Fuzzy match with gap penalties: 0-500 points
    func scoreResult(
        query: String,
        title: String,
        subtitle: String? = nil,
        category: SearchResultCategory? = nil
    ) -> Int {
        guard !query.isEmpty, !title.isEmpty else { return 0 }

        let lowercasedQuery = query.lowercased()
        let lowercasedTitle = title.lowercased()

        // Check for exact and prefix matches first
        if let score = checkExactAndPrefixMatches(query: lowercasedQuery, title: lowercasedTitle) {
            return score
        }

        // Check word start match
        if let wordStartScore = scoreWordStartMatch(query: lowercasedQuery, target: lowercasedTitle) {
            return wordStartScore
        }

        // Calculate fuzzy score
        var score = calculateFuzzyScore(query: lowercasedQuery, target: lowercasedTitle)

        // Check substring if fuzzy didn't match
        score = checkSubstringMatch(query: lowercasedQuery, title: lowercasedTitle, score: score)

        // Check subtitle and category for additional scoring
        score = applyContextScoring(query: query, subtitle: subtitle, category: category, currentScore: score)

        return score
    }

    private func checkExactAndPrefixMatches(query: String, title: String) -> Int? {
        // Exact match (case-insensitive) - highest score
        if title == query {
            return 1000
        }

        // Exact prefix of entire title
        if title.hasPrefix(query) {
            return 900
        }

        return nil
    }

    private func checkSubstringMatch(query: String, title: String, score: Int) -> Int {
        if score == 0, title.contains(query) {
            return 30 // Low score for middle-of-word substring
        }
        return score
    }

    private func applyContextScoring(
        query: String,
        subtitle: String?,
        category: SearchResultCategory?,
        currentScore: Int
    ) -> Int {
        var score = currentScore

        if score >= 700 {
            return score
        }

        // Check subtitle if provided
        if let subtitle {
            let subtitleScore = scoreResult(query: query, title: subtitle)
            if subtitleScore > score {
                score = max(subtitleScore - 100, score)
            }
        }

        // Check category name if provided
        if let category, score < 700 {
            let categoryScore = scoreResult(query: query, title: category.displayName)
            if categoryScore > 0 {
                score = max(score, min(categoryScore + 100, 600))
            }
        }

        return score
    }

    /// Check if query matches at the start of any word in target
    private func scoreWordStartMatch(query: String, target: String) -> Int? {
        let words = target.components(separatedBy: CharacterSet(charactersIn: " -_"))

        for (index, word) in words.enumerated() where word.hasPrefix(query) {
            // Score based on word position
            let positionPenalty = min(index * 50, 250)
            return 850 - positionPenalty
        }

        return nil
    }

    /// Calculate fuzzy score with gap penalties
    /// Key principle: consecutive matches score MUCH higher than matches with gaps
    private func calculateFuzzyScore(query: String, target: String) -> Int {
        guard !query.isEmpty else { return 0 }

        // Find all match positions
        var matchPositions: [Int] = []
        var queryIndex = query.startIndex
        var targetIndex = target.startIndex

        while queryIndex < query.endIndex, targetIndex < target.endIndex {
            if query[queryIndex] == target[targetIndex] {
                matchPositions.append(target.distance(from: target.startIndex, to: targetIndex))
                queryIndex = query.index(after: queryIndex)
            }
            targetIndex = target.index(after: targetIndex)
        }

        // All characters must be matched
        guard matchPositions.count == query.count else { return 0 }

        // Calculate score based on match quality
        let baseScore = calculateBaseScore(matchPositions: matchPositions, target: target)
        return max(0, min(500, Int(baseScore)))
    }

    private func calculateBaseScore(matchPositions: [Int], target: String) -> Double {
        var score = 0.0

        // 1. Base score for matching all characters
        score += 100

        // 2. Calculate gap penalties and consecutive bonuses
        let (totalGapPenalty, consecutiveBonus) = calculateGapPenalties(matchPositions: matchPositions)
        score += consecutiveBonus
        score -= totalGapPenalty

        // 3. Bonus for early position (first match close to start)
        let firstMatchPosition = matchPositions.first ?? 0
        let earlyPositionBonus = max(0, 50 - firstMatchPosition * 2)
        score += Double(earlyPositionBonus)

        // 4. Bonus for word boundary matches
        let wordBoundaryBonus = calculateWordBoundaryBonus(matchPositions: matchPositions, target: target)
        score += wordBoundaryBonus

        return score
    }

    private func calculateGapPenalties(matchPositions: [Int]) -> (penalty: Double, bonus: Double) {
        var totalGapPenalty = 0.0
        var consecutiveBonus = 0.0

        for i in 1..<matchPositions.count {
            let gap = matchPositions[i] - matchPositions[i - 1]

            if gap == 1 {
                // Consecutive match - big bonus!
                consecutiveBonus += 20
            } else {
                // Gap penalty: exponential penalty for larger gaps
                let gapPenalty = Double(gap - 1) * Double(gap - 1) * 2
                totalGapPenalty += gapPenalty
            }
        }

        return (totalGapPenalty, consecutiveBonus)
    }

    private func calculateWordBoundaryBonus(matchPositions: [Int], target: String) -> Double {
        var wordBoundaryBonus = 0.0
        for position in matchPositions {
            if position == 0 {
                wordBoundaryBonus += 15 // Match at very start
            } else if isWordBoundary(position: position, target: target) {
                wordBoundaryBonus += 10 // Match at word boundary
            }
        }
        return wordBoundaryBonus
    }

    private func isWordBoundary(position: Int, target: String) -> Bool {
        guard position > 0 else { return false }
        let prevCharIndex = target.index(target.startIndex, offsetBy: position - 1)
        let prevChar = target[prevCharIndex]
        return prevChar == " " || prevChar == "-" || prevChar == "_"
    }
}

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
    func scoreResult(query: String, title: String, subtitle: String? = nil, category: SearchResultCategory? = nil) -> Int {
        guard !query.isEmpty, !title.isEmpty else { return 0 }

        let lowercasedQuery = query.lowercased()
        let lowercasedTitle = title.lowercased()

        // Exact match (case-insensitive) - highest score
        if lowercasedTitle == lowercasedQuery {
            return 1000
        }

        // Exact prefix of entire title
        if lowercasedTitle.hasPrefix(lowercasedQuery) {
            return 900
        }

        // Check if query matches at the START of any word (major boost!)
        if let wordStartScore = scoreWordStartMatch(query: lowercasedQuery, target: lowercasedTitle) {
            return wordStartScore
        }

        // Fuzzy match with proper gap penalties
        var score = calculateFuzzyScore(query: lowercasedQuery, target: lowercasedTitle)

        // If fuzzy didn't match all characters, check substring contains
        if score == 0 && lowercasedTitle.contains(lowercasedQuery) {
            score = 30 // Low score for middle-of-word substring
        }

        // Also check subtitle if provided
        if let subtitle, score < 700 {
            let subtitleScore = scoreResult(query: query, title: subtitle)
            // Subtitle matches should be lower than title matches
            if subtitleScore > score {
                score = max(subtitleScore - 100, score)
            }
        }
        
        // Also check category name if provided
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
        
        for (index, word) in words.enumerated() {
            if word.hasPrefix(query) {
                // Score based on word position
                let positionPenalty = min(index * 50, 250)
                return 850 - positionPenalty
            }
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
        
        while queryIndex < query.endIndex && targetIndex < target.endIndex {
            if query[queryIndex] == target[targetIndex] {
                matchPositions.append(target.distance(from: target.startIndex, to: targetIndex))
                queryIndex = query.index(after: queryIndex)
            }
            targetIndex = target.index(after: targetIndex)
        }
        
        // All characters must be matched
        guard matchPositions.count == query.count else { return 0 }
        
        // Calculate score based on match quality
        var score = 0.0
        
        // 1. Base score for matching all characters
        score += 100
        
        // 2. Calculate gap penalties
        var totalGapPenalty = 0.0
        var consecutiveBonus = 0.0
        
        for i in 1..<matchPositions.count {
            let gap = matchPositions[i] - matchPositions[i - 1]
            
            if gap == 1 {
                // Consecutive match - big bonus!
                consecutiveBonus += 20
            } else {
                // Gap penalty: exponential penalty for larger gaps
                // gap of 2 = -2, gap of 5 = -32, gap of 10 = -162
                let gapPenalty = Double(gap - 1) * Double(gap - 1) * 2
                totalGapPenalty += gapPenalty
            }
        }
        
        score += consecutiveBonus
        score -= totalGapPenalty
        
        // 3. Bonus for early position (first match close to start)
        let firstMatchPosition = matchPositions.first ?? 0
        let earlyPositionBonus = max(0, 50 - firstMatchPosition * 2)
        score += Double(earlyPositionBonus)
        
        // 4. Bonus for word boundary matches
        var wordBoundaryBonus = 0.0
        for position in matchPositions {
            if position == 0 {
                wordBoundaryBonus += 15 // Match at very start
            } else {
                let prevCharIndex = target.index(target.startIndex, offsetBy: position - 1)
                let prevChar = target[prevCharIndex]
                if prevChar == " " || prevChar == "-" || prevChar == "_" {
                    wordBoundaryBonus += 10 // Match at word boundary
                }
            }
        }
        score += wordBoundaryBonus
        
        // Ensure score is positive and within bounds
        return max(0, min(500, Int(score)))
    }
}

import Foundation

/// The type of match found
enum SearchMatchType: Double {
    /// Query exactly matches title (case-insensitive)
    case exact = 1.0
    /// Query is a prefix of the entire title
    case prefix = 0.95
    /// Query is a prefix of any word in the title
    case wordStart = 0.9
    /// All query characters appear in order (fuzzy match)
    case fuzzy = 0.7
    /// Query appears as substring in middle of word
    case substring = 0.5
    /// No match
    case none = 0.0
}

/// Result of a search match analysis
struct SearchMatchResult {
    /// Quality of the match (0.0 - 1.0)
    /// Pure fuzzy match quality, no category bias
    let quality: Double
    
    /// Type of match found
    let matchType: SearchMatchType
    
    /// Whether this is a valid match
    var isMatch: Bool {
        matchType != .none && quality > 0
    }
    
    /// Create a no-match result
    static let noMatch = SearchMatchResult(quality: 0, matchType: .none)
}

/// Analyzes search queries and calculates match quality
/// Returns pure match quality without category or statistics bias
final class SearchMatchAnalyzer {
    static let shared = SearchMatchAnalyzer()
    
    private init() {}
    
    /// Analyze how well a query matches a target string
    /// - Parameters:
    ///   - query: The search query
    ///   - target: The target string to match against
    /// - Returns: A SearchMatchResult with quality and match type
    func analyze(query: String, target: String) -> SearchMatchResult {
        guard !query.isEmpty, !target.isEmpty else { return .noMatch }
        
        let lowercasedQuery = query.lowercased()
        let lowercasedTarget = target.lowercased()
        
        // Exact match
        if lowercasedTarget == lowercasedQuery {
            return SearchMatchResult(quality: 1.0, matchType: .exact)
        }
        
        // Prefix of entire title
        if lowercasedTarget.hasPrefix(lowercasedQuery) {
            return SearchMatchResult(quality: 0.9, matchType: .prefix)
        }
        
        // Word start match
        if let wordStartResult = analyzeWordStartMatch(query: lowercasedQuery, target: lowercasedTarget) {
            return wordStartResult
        }
        
        // Fuzzy match
        let fuzzyResult = analyzeFuzzyMatch(query: lowercasedQuery, target: lowercasedTarget)
        if fuzzyResult.isMatch {
            return fuzzyResult
        }
        
        // Substring match (lowest priority)
        if lowercasedTarget.contains(lowercasedQuery) {
            return SearchMatchResult(quality: 0.03, matchType: .substring)
        }
        
        return .noMatch
    }
    
    // MARK: - Word Start Match
    
    private func analyzeWordStartMatch(query: String, target: String) -> SearchMatchResult? {
        let words = target.components(separatedBy: CharacterSet(charactersIn: " -_"))
        
        for (index, word) in words.enumerated() {
            if word.hasPrefix(query) {
                // Quality based on word position
                // First word: 0.85, second: 0.8, third: 0.75, etc (min 0.6)
                let positionPenalty = min(Double(index) * 0.05, 0.25)
                let quality = 0.85 - positionPenalty
                return SearchMatchResult(quality: quality, matchType: .wordStart)
            }
        }
        
        return nil
    }
    
    // MARK: - Fuzzy Match
    
    private func analyzeFuzzyMatch(query: String, target: String) -> SearchMatchResult {
        guard !query.isEmpty else { return .noMatch }
        
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
        guard matchPositions.count == query.count else { return .noMatch }
        
        // Calculate quality based on match quality
        var quality = 0.0
        
        // 1. Base quality for matching all characters
        quality += 0.3
        
        // 2. Calculate gap penalties and consecutive bonuses
        var totalGapPenalty = 0.0
        var consecutiveBonus = 0.0
        
        for i in 1..<matchPositions.count {
            let gap = matchPositions[i] - matchPositions[i - 1]
            
            if gap == 1 {
                // Consecutive match - bonus!
                consecutiveBonus += 0.1
            } else {
                // Gap penalty: exponential
                let gapPenalty = Double(gap - 1) * Double(gap - 1) * 0.02
                totalGapPenalty += gapPenalty
            }
        }
        
        quality += consecutiveBonus
        quality -= totalGapPenalty
        
        // 3. Bonus for early position
        let firstMatchPosition = matchPositions.first ?? 0
        let earlyPositionBonus = max(0, 0.2 - Double(firstMatchPosition) * 0.01)
        quality += earlyPositionBonus
        
        // 4. Bonus for word boundary matches
        var wordBoundaryBonus = 0.0
        for position in matchPositions {
            if position == 0 {
                wordBoundaryBonus += 0.05
            } else {
                let prevCharIndex = target.index(target.startIndex, offsetBy: position - 1)
                let prevChar = target[prevCharIndex]
                if prevChar == " " || prevChar == "-" || prevChar == "_" {
                    wordBoundaryBonus += 0.03
                }
            }
        }
        quality += wordBoundaryBonus
        
        // Clamp quality to valid range
        quality = max(0.05, min(0.6, quality))
        
        return SearchMatchResult(quality: quality, matchType: .fuzzy)
    }
}

import Foundation

/// Calculates final search scores by combining all scoring layers:
/// 1. MatchQuality - how well the query matches
/// 2. MatchTypeBonus - bonus for exact/prefix/wordStart matches
/// 3. CategoryWeight - importance of the result category
/// 4. StatisticsFactor - user usage patterns (stub - always 1.0)
final class SearchScoreCalculator {
    static let shared = SearchScoreCalculator()
    
    private let analyzer = SearchMatchAnalyzer.shared
    private let statisticsService = StatisticsFactorService.shared
    private var weights: SearchScoringWeights
    
    private init() {
        weights = SearchScoringWeights.load()
    }
    
    /// Reload weights from storage
    func reloadWeights() {
        weights = SearchScoringWeights.load()
    }
    
    /// Update weights
    func updateWeights(_ newWeights: SearchScoringWeights) {
        weights = newWeights
        weights.save()
    }
    
    /// Get current weights
    func getWeights() -> SearchScoringWeights {
        weights
    }
    
    /// Calculate final score for a search result
    /// - Parameters:
    ///   - query: The search query
    ///   - title: The result title
    ///   - category: The result category
    ///   - identifier: Unique identifier for statistics tracking (optional)
    /// - Returns: Final score (0-1000 scale for backwards compatibility)
    func calculateScore(
        query: String,
        title: String,
        category: SearchResultCategory,
        identifier: String? = nil
    ) -> Int {
        // Layer 1 & 2: Match quality and type
        let matchResult = analyzer.analyze(query: query, target: title)
        
        guard matchResult.isMatch else { return 0 }
        
        // Layer 3: Category weight
        let categoryWeight = weights.weight(for: category)
        
        // Layer 4: Statistics factor
        let statsFactor = statisticsService.factor(
            category: category,
            identifier: identifier ?? title
        )
        
        // Combine all layers
        let matchTypeBonus = matchResult.matchType.rawValue
        let finalScore = matchResult.quality * matchTypeBonus * categoryWeight * statsFactor
        
        // Scale to 0-1000 range for backwards compatibility
        return Int(finalScore * 1000)
    }
    
    /// Calculate score with subtitle consideration
    /// - Parameters:
    ///   - query: The search query
    ///   - title: The result title
    ///   - subtitle: Optional subtitle
    ///   - category: The result category
    ///   - identifier: Unique identifier for statistics tracking
    /// - Returns: Final score
    func calculateScore(
        query: String,
        title: String,
        subtitle: String?,
        category: SearchResultCategory,
        identifier: String? = nil
    ) -> Int {
        // Primary match on title
        let titleScore = calculateScore(
            query: query,
            title: title,
            category: category,
            identifier: identifier
        )
        
        // If title match is good enough, use it
        if titleScore >= 700 {
            return titleScore
        }
        
        // Otherwise, also check subtitle
        if let subtitle {
            let subtitleScore = calculateScore(
                query: query,
                title: subtitle,
                category: category,
                identifier: identifier
            )
            // Subtitle matches are slightly penalized
            return max(titleScore, Int(Double(subtitleScore) * 0.9))
        }
        
        return titleScore
    }
    
    /// Get match result for a query against a title
    /// Useful for debugging or displaying match info
    func getMatchResult(query: String, title: String) -> SearchMatchResult {
        analyzer.analyze(query: query, target: title)
    }
}

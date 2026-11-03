import Foundation

final class SearchScoreCalculator {
    static let shared = SearchScoreCalculator()

    private let analyzer = SearchMatchAnalyzer.shared
    private var weights: SearchScoringWeights

    private init() {
        weights = SearchScoringWeights.load()
    }

    func reloadWeights() {
        weights = SearchScoringWeights.load()
    }

    func updateWeights(_ newWeights: SearchScoringWeights) {
        weights = newWeights
        weights.save()
    }

    func getWeights() -> SearchScoringWeights {
        weights
    }

    func calculateScore(
        query: String,
        title: String,
        category: SearchResultCategory,
        identifier _: String? = nil
    ) -> Int {
        let matchResult = analyzer.analyze(query: query, target: title)

        guard matchResult.isMatch else { return 0 }

        let categoryWeight = weights.weight(for: category)

        let matchTypeBonus = matchResult.matchType.rawValue
        let finalScore = matchResult.quality * matchTypeBonus * categoryWeight

        return Int(finalScore * 1000)
    }

    func calculateScore(
        query: String,
        title: String,
        subtitle: String?,
        category: SearchResultCategory,
        identifier: String? = nil
    ) -> Int {
        let titleScore = calculateScore(
            query: query,
            title: title,
            category: category,
            identifier: identifier
        )

        if titleScore >= 700 {
            return titleScore
        }

        if let subtitle {
            let subtitleScore = calculateScore(
                query: query,
                title: subtitle,
                category: category,
                identifier: identifier
            )
            return max(titleScore, Int(Double(subtitleScore) * 0.9))
        }

        return titleScore
    }

    func getMatchResult(query: String, title: String) -> SearchMatchResult {
        analyzer.analyze(query: query, target: title)
    }
}

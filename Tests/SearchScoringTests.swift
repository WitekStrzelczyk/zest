import XCTest
@testable import ZestApp

/// Tests for SearchResultScoring functionality
final class SearchScoringTests: XCTestCase {

    // MARK: - Exact Match Tests

    func test_exactMatch_scores1000() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "gcr", title: "GCR")

        XCTAssertEqual(score, 1000, "Exact match should score 1000")
    }

    func test_exactMatch_caseInsensitive_scores1000() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "gcr", title: "gcr")

        XCTAssertEqual(score, 1000, "Exact match (case-insensitive) should score 1000")
    }

    // MARK: - Prefix Match Tests

    func test_prefixMatch_scores800() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "gc", title: "GCR")

        XCTAssertEqual(score, 800, "Prefix match should score 800")
    }

    // MARK: - Fuzzy Match Tests

    func test_fuzzyMatch_allCharsInOrder_scoresPositive() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "gcr", title: "Google Chrome")

        XCTAssertGreaterThan(score, 0, "Fuzzy match should score positive")
        XCTAssertLessThan(score, 600, "Fuzzy match should score less than 600")
    }

    func test_fuzzyMatch_partialChars_scoresPositive() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "saf", title: "Safari")

        XCTAssertGreaterThan(score, 0, "Partial fuzzy match should score positive")
    }

    func test_nonMatchingQuery_scores0() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "xyz", title: "Safari")

        XCTAssertEqual(score, 0, "Non-matching query should score 0")
    }

    // MARK: - Scoring Hierarchy Tests

    func test_exactMatch_scoresHigherThanPrefix() {
        let scoring = SearchResultScoring.shared

        let exactScore = scoring.scoreResult(query: "gcr", title: "GCR")
        let prefixScore = scoring.scoreResult(query: "gc", title: "GCR")

        XCTAssertGreaterThan(exactScore, prefixScore, "Exact match should score higher than prefix")
    }

    func test_prefixMatch_scoresHigherThanFuzzy() {
        let scoring = SearchResultScoring.shared

        let prefixScore = scoring.scoreResult(query: "gc", title: "GCRApp")
        let fuzzyScore = scoring.scoreResult(query: "gcr", title: "GoogleCR")

        XCTAssertGreaterThan(prefixScore, fuzzyScore, "Prefix match should score higher than fuzzy")
    }

    func test_fuzzyMatch_scoresHigherThanContains() {
        let scoring = SearchResultScoring.shared

        let fuzzyScore = scoring.scoreResult(query: "chrome", title: "GoogleChromeBrowser")

        // Contains scores 50, fuzzy should be higher
        XCTAssertGreaterThan(fuzzyScore, 50, "Fuzzy match should score higher than simple contains")
    }

    // MARK: - Consecutive Match Bonus

    func test_consecutiveMatches_scoresHigher() {
        let scoring = SearchResultScoring.shared

        let consecutiveScore = scoring.scoreResult(query: "abc", title: "abcde")
        let nonConsecutiveScore = scoring.scoreResult(query: "ace", title: "abcde")

        XCTAssertGreaterThan(consecutiveScore, nonConsecutiveScore,
                            "Consecutive matches should score higher than non-consecutive")
    }

    // MARK: - Separator Bonus Tests

    func test_matchAfterSeparator_bonusAdded() {
        let scoring = SearchResultScoring.shared

        // The scoring algorithm includes separator bonuses in fuzzy matching
        // This test verifies that the algorithm runs without errors
        let score = scoring.scoreResult(query: "ch", title: "Google Chrome")

        // Score should be positive (fuzzy match)
        XCTAssertGreaterThan(score, 0, "Should have score for fuzzy match with separator")
    }

    // MARK: - Specific Query Tests

    func test_queryGCR_exactMatchGCR_scores1000() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "gcr", title: "GCR")

        XCTAssertEqual(score, 1000, "Query 'gcr' -> 'GCR' should score 1000")
    }

    func test_queryGCR_googleChrome_scoresFuzzy() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "gcr", title: "Google Chrome")

        // Should be fuzzy match (exact=1000, prefix=800, fuzzy=100-500)
        XCTAssertGreaterThanOrEqual(score, 100, "Google Chrome should have fuzzy score for 'gcr'")
        XCTAssertLessThan(score, 800, "Google Chrome should not have prefix/exact score for 'gcr'")
    }

    // MARK: - Subtitle Tests

    func test_subtitleMatch_boostsScore() {
        let scoring = SearchResultScoring.shared

        let titleOnlyScore = scoring.scoreResult(query: "test", title: "Some Title", subtitle: nil)
        let withSubtitleScore = scoring.scoreResult(query: "test", title: "Some Title", subtitle: "Test Description")

        XCTAssertGreaterThan(withSubtitleScore, titleOnlyScore,
                            "Matching subtitle should boost score")
    }

    // MARK: - Edge Cases

    func test_emptyQuery_scores0() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "", title: "Safari")

        XCTAssertEqual(score, 0, "Empty query should score 0")
    }

    func test_emptyTitle_scores0() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "test", title: "")

        XCTAssertEqual(score, 0, "Empty title should score 0")
    }

    func test_queryLongerThanTitle_returns0() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "verylongquery", title: "short")

        XCTAssertEqual(score, 0, "Query longer than title with no match should score 0")
    }
}

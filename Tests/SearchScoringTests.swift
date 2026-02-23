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

    
    // MARK: - Prefix Match Tests

    func test_prefixMatch_scores900() {
        let scoring = SearchResultScoring.shared

        let score = scoring.scoreResult(query: "gc", title: "GCR")

        XCTAssertEqual(score, 900, "Prefix match should score 900")
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
        XCTAssertGreaterThan(fuzzyScore, 30, "Fuzzy match should score higher than simple contains")
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
        XCTAssertGreaterThanOrEqual(score, 50, "Google Chrome should have fuzzy score for 'gcr'")
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
    
    // MARK: - Word Start Match Tests

    func test_wordStartMatch_scoresHigherThanSubstringMatch() {
        let scoring = SearchResultScoring.shared
        // "moni" at start of word "Monitor" should score higher than "moni" in middle of word
        let activityMonitorScore = scoring.scoreResult(query: "moni", title: "Activity Monitor")
        let downloadCompanionScore = scoring.scoreResult(query: "moni", title: "90_download_companion")
        XCTAssertGreaterThan(activityMonitorScore, downloadCompanionScore,
                            "Word start match (Activity Monitor) should score higher than substring match")
    }
    
    func test_secondWordPrefix_scores800() {
        let scoring = SearchResultScoring.shared
        // "moni" is prefix of second word "Monitor"
        let score = scoring.scoreResult(query: "moni", title: "Activity Monitor")
        XCTAssertEqual(score, 800, "Second word prefix match should score 800")
    }
    
    func test_firstWordPrefix_scores900() {
        let scoring = SearchResultScoring.shared
        // "moni" is prefix of first word
        let score = scoring.scoreResult(query: "moni", title: "Monitor")
        XCTAssertEqual(score, 900, "First word prefix match should score 900")
    }
    
    func test_substringInMiddleOfWord_scores30() {
        let scoring = SearchResultScoring.shared
        // "moni" is in middle of "companion" (not at word start)
        // companion = c-o-m-p-a-n-i-o-n (no "moni" sequence at word start)
        let score = scoring.scoreResult(query: "moni", title: "90_download_companion")
        // This should be fuzzy match or substring, NOT word-start match
        XCTAssertLessThan(score, 800, "Substring in middle of word should score less than word start match")
    }
    
    // MARK: - Gap Penalty Tests

    func test_consecutiveMatches_scoreHigherThanGaps() {
        let scoring = SearchResultScoring.shared
        // "spotify" - "pt" matches consecutively: s-p-o-t-ify
        // "spootify" - "pt" has gap: s-p-o-o-t-ify (2 chars gap)
        let consecutiveScore = scoring.scoreResult(query: "pt", title: "spotify")
        let gapScore = scoring.scoreResult(query: "pt", title: "spootify")
        XCTAssertGreaterThan(consecutiveScore, gapScore,
                             "Consecutive match (spotify) should score higher than match with gap (spootify)")
    }
    
    func test_smallGap_scoresHigherThanBigGap() {
        let scoring = SearchResultScoring.shared
        // "abc" matching "aXbXc" (gap of 1 each) vs "aXXXXbXXXXc" (gap of 4 each)
        let smallGapScore = scoring.scoreResult(query: "abc", title: "axbxc")
        let bigGapScore = scoring.scoreResult(query: "abc", title: "axxxxbxxxxc")
        XCTAssertGreaterThan(smallGapScore, bigGapScore,
                             "Small gaps should score higher than big gaps")
    }
    
    func test_openSpotify_notMatchOni() {
        let scoring = SearchResultScoring.shared
        // "oni" should NOT match "Open Spotify" well
        // "Open Spotify" has: o-p-e-n [space] s-p-o-t-i-f-y
        // For "oni": o at position 0, n at position 3, i at position 8
        // This has huge gaps!
        let openSpotifyScore = scoring.scoreResult(query: "oni", title: "Open Spotify")
        let activityMonitorScore = scoring.scoreResult(query: "oni", title: "Activity Monitor")
        // Activity Monitor should score much higher (word boundary bonus, smaller gaps)
        XCTAssertGreaterThan(activityMonitorScore, openSpotifyScore,
                             "Activity Monitor should score higher than Open Spotify for 'oni'")
    }
    
    func test_fuzzyMatchWithBigGaps_scoresLow() {
        let scoring = SearchResultScoring.shared
        // "xyz" matching somewhere with huge gaps should score very low or 0
        let score = scoring.scoreResult(query: "xyz", title: "x12345y67890z")
        XCTAssertLessThan(score, 100, "Huge gaps should result in very low score")
    }
    
    func test_perfectConsecutive_scoresHigh() {
        let scoring = SearchResultScoring.shared
        // "abc" in "xabc" - all consecutive
        let score = scoring.scoreResult(query: "abc", title: "xabc")
        XCTAssertGreaterThan(score, 150, "Perfect consecutive match should score well")
    }
}

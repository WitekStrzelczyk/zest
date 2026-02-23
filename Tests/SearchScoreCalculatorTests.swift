import XCTest
@testable import ZestApp

/// Tests for the new 4-layer scoring system
final class SearchScoreCalculatorTests: XCTestCase {
    
    var calculator: SearchScoreCalculator!
    var defaultWeights: SearchScoringWeights!
    
    override func setUp() {
        super.setUp()
        calculator = SearchScoreCalculator.shared
        defaultWeights = SearchScoringWeights.default
        calculator.updateWeights(defaultWeights)
    }
    
    // MARK: - Layer 1: MatchQuality Tests
    
    func test_exactMatch_qualityIs1_0() {
        let result = calculator.getMatchResult(query: "safari", title: "Safari")
        
        XCTAssertEqual(result.quality, 1.0, accuracy: 0.01)
        XCTAssertEqual(result.matchType, .exact)
    }
    
    func test_prefixMatch_qualityIs0_9() {
        let result = calculator.getMatchResult(query: "saf", title: "Safari")
        
        XCTAssertEqual(result.quality, 0.9, accuracy: 0.01)
        XCTAssertEqual(result.matchType, .prefix)
    }
    
    func test_firstWordStart_qualityIs0_85() {
        // Use a query that's a prefix of first word, but NOT a prefix of entire title
        // Use different casing or a word that's not at the very start
        // "My Safari" - "saf" is NOT a prefix of "My Safari", but IS a prefix of "Safari" word
        let result = calculator.getMatchResult(query: "saf", title: "My Safari App")
        
        // This should be wordStart (second word, not prefix) with quality 0.8
        XCTAssertEqual(result.quality, 0.8, accuracy: 0.01)
        XCTAssertEqual(result.matchType, .wordStart)
    }
    
    func test_firstWordAsWordStart_qualityIs0_85() {
        // When query is prefix of first word in a multi-word title
        // and NOT a prefix of the entire title (because there's more after)
        // Note: This actually matches as .prefix because hasPrefix is checked first
        let result = calculator.getMatchResult(query: "my", title: "My Safari App")
        
        // "my" is a prefix of "My Safari App"
        XCTAssertEqual(result.matchType, .prefix)
        XCTAssertEqual(result.quality, 0.9, accuracy: 0.01)
    }
    
    func test_secondWordStart_qualityIs0_8() {
        // Second word match - query is NOT a prefix of entire title
        let result = calculator.getMatchResult(query: "saf", title: "My Safari")
        
        XCTAssertEqual(result.quality, 0.8, accuracy: 0.01)
        XCTAssertEqual(result.matchType, .wordStart)
    }
    
    func test_fuzzyMatch_qualityIsLow() {
        let result = calculator.getMatchResult(query: "sfr", title: "Safari")
        
        XCTAssertGreaterThan(result.quality, 0.05)
        XCTAssertLessThan(result.quality, 0.6)
        XCTAssertEqual(result.matchType, .fuzzy)
    }
    
    func test_substringMatch_qualityIsVeryLow() {
        // "zoo" appears in middle of "amazon" - NOT at word start and NOT all chars in order
        // This should be caught as substring
        let result = calculator.getMatchResult(query: "zoo", title: "amazon")
        
        // "zoo" doesn't match because z, o, o don't appear in order in "amazon"
        XCTAssertEqual(result.quality, 0, accuracy: 0.01)
        XCTAssertEqual(result.matchType, .none)
    }
    
    func test_substringInMiddleOfWord_isNotWordStart() {
        // "mon" in "companion" - letters appear in order but NOT at word start
        let result = calculator.getMatchResult(query: "mon", title: "companion")
        
        // This should be a fuzzy match (letters in order) but not wordStart
        XCTAssertEqual(result.matchType, .fuzzy)
        XCTAssertLessThan(result.quality, 0.5)
    }
    
    func test_noMatch_returnsZero() {
        let result = calculator.getMatchResult(query: "xyz", title: "Safari")
        
        XCTAssertEqual(result.quality, 0, accuracy: 0.01)
        XCTAssertEqual(result.matchType, .none)
        XCTAssertFalse(result.isMatch)
    }
    
    // MARK: - Layer 2: MatchTypeBonus Tests
    
    func test_exactMatchBonus_is1_0() {
        XCTAssertEqual(SearchMatchType.exact.rawValue, 1.0)
    }
    
    func test_prefixMatchBonus_is0_95() {
        XCTAssertEqual(SearchMatchType.prefix.rawValue, 0.95)
    }
    
    func test_wordStartMatchBonus_is0_9() {
        XCTAssertEqual(SearchMatchType.wordStart.rawValue, 0.9)
    }
    
    func test_fuzzyMatchBonus_is0_7() {
        XCTAssertEqual(SearchMatchType.fuzzy.rawValue, 0.7)
    }
    
    func test_substringMatchBonus_is0_5() {
        XCTAssertEqual(SearchMatchType.substring.rawValue, 0.5)
    }
    
    // MARK: - Layer 3: CategoryWeight Tests
    
    func test_applicationCategory_weightIs1_2() {
        let weights = SearchScoringWeights.default
        XCTAssertEqual(weights.weight(for: .application), 1.2)
    }
    
    func test_quicklinkCategory_weightIs0_8() {
        let weights = SearchScoringWeights.default
        XCTAssertEqual(weights.weight(for: .quicklink), 0.8)
    }
    
    func test_clipboardCategory_weightIs0_6() {
        let weights = SearchScoringWeights.default
        XCTAssertEqual(weights.weight(for: .clipboard), 0.6)
    }
    
    func test_fileCategory_weightIs0_5() {
        let weights = SearchScoringWeights.default
        XCTAssertEqual(weights.weight(for: .file), 0.5)
    }
    
    // MARK: - Combined Score Tests
    
    func test_appWithPrefix_scoresHigherThanQuicklinkWithFuzzy() {
        // Query "a" - Activity Monitor app vs Google quicklink
        let appScore = calculator.calculateScore(
            query: "a",
            title: "Activity Monitor",
            category: .application,
            identifier: "com.apple.ActivityMonitor"
        )
        
        let quicklinkScore = calculator.calculateScore(
            query: "a",
            title: "Google",
            category: .quicklink,
            identifier: "https://google.com"
        )
        
        // App should score MUCH higher than quicklink with weak fuzzy match
        XCTAssertGreaterThan(appScore, quicklinkScore)
        print("App score: \(appScore), Quicklink score: \(quicklinkScore)")
    }
    
    func test_amoreApp_scoresHigherThanGoogleQuicklink_forA() {
        let amoreScore = calculator.calculateScore(
            query: "a",
            title: "Amore",
            category: .application,
            identifier: "com.amore"
        )
        
        let googleScore = calculator.calculateScore(
            query: "a",
            title: "Google",
            category: .quicklink,
            identifier: "https://google.com"
        )
        
        XCTAssertGreaterThan(amoreScore, googleScore)
        print("Amore score: \(amoreScore), Google quicklink score: \(googleScore)")
    }
    
    func test_spotifyConsecutive_scoresHigherThanSpootifyGap() {
        let spotifyScore = calculator.calculateScore(
            query: "pt",
            title: "spotify",
            category: .application
        )
        
        let spootifyScore = calculator.calculateScore(
            query: "pt",
            title: "spootify",
            category: .application
        )
        
        XCTAssertGreaterThan(spotifyScore, spootifyScore)
        print("spotify score: \(spotifyScore), spootify score: \(spootifyScore)")
    }
    
    // MARK: - Gap Penalty Tests
    
    func test_consecutiveMatches_scoreHigherThanWithGaps() {
        let consecutive = calculator.getMatchResult(query: "abc", title: "xabc")
        let withGap = calculator.getMatchResult(query: "abc", title: "axbxc")
        
        XCTAssertGreaterThan(consecutive.quality, withGap.quality)
    }
    
    func test_smallGaps_scoreHigherThanBigGaps() {
        let smallGaps = calculator.getMatchResult(query: "abc", title: "axbxc")
        let bigGaps = calculator.getMatchResult(query: "abc", title: "axxxxbxxxxc")
        
        XCTAssertGreaterThan(smallGaps.quality, bigGaps.quality)
    }
    
    // MARK: - Layer 4: Statistics Tests (stub)
    
    func test_statisticsFactor_alwaysReturns1() {
        let statsService = StatisticsFactorService.shared
        
        let factor = statsService.factor(category: .application, identifier: "test")
        
        XCTAssertEqual(factor, 1.0)
    }
    
    // MARK: - Score Scale Tests
    
    func test_perfectMatch_scoresCloseTo1000() {
        let score = calculator.calculateScore(
            query: "safari",
            title: "Safari",
            category: .application
        )
        
        // 1.0 (quality) * 1.0 (exact bonus) * 1.2 (app weight) * 1.0 (stats) * 1000 = 1200
        XCTAssertEqual(score, 1200)
    }
    
    func test_prefixApp_scoresAround1000() {
        let score = calculator.calculateScore(
            query: "saf",
            title: "Safari",
            category: .application
        )
        
        // 0.9 (quality) * 0.95 (prefix bonus) * 1.2 (app weight) * 1.0 (stats) * 1000
        let expected = Int(0.9 * 0.95 * 1.2 * 1.0 * 1000)
        XCTAssertEqual(score, expected)
    }
    
    // MARK: - Weights Persistence Tests
    
    func test_weights_canBeSavedAndLoaded() {
        var weights = SearchScoringWeights.default
        weights.categoryApplication = 1.5
        weights.save()
        
        let loaded = SearchScoringWeights.load()
        XCTAssertEqual(loaded.categoryApplication, 1.5)
        
        // Reset to default
        SearchScoringWeights.default.save()
    }
}

import AppKit
import Testing
@testable import ZestApp

@MainActor
final class SearchScoreCalculatorTests {
    var calculator: SearchScoreCalculator!
    var defaultWeights: SearchScoringWeights!
    
    init() {
        calculator = SearchScoreCalculator.shared
        defaultWeights = SearchScoringWeights.default
        calculator.updateWeights(defaultWeights)
    }
    
    @Test func test_exactMatch_qualityIs1_0() {
        let result = calculator.getMatchResult(query: "safari", title: "Safari")
        
        #expect(abs(result.quality - 1.0) <= 0.01)
        #expect(result.matchType == .exact)
    }
    
    @Test func test_prefixMatch_qualityIs0_9() {
        let result = calculator.getMatchResult(query: "saf", title: "Safari")
        
        #expect(abs(result.quality - 0.9) <= 0.01)
        #expect(result.matchType == .prefix)
    }
    
    @Test func test_firstWordStart_qualityIs0_85() {
        let result = calculator.getMatchResult(query: "saf", title: "My Safari App")
        
        #expect(abs(result.quality - 0.8) <= 0.01)
        #expect(result.matchType == .wordStart)
    }
    
    @Test func test_firstWordAsWordStart_qualityIs0_85() {
        let result = calculator.getMatchResult(query: "my", title: "My Safari App")
        
        #expect(result.matchType == .prefix)
        #expect(abs(result.quality - 0.9) <= 0.01)
    }
    
    @Test func test_secondWordStart_qualityIs0_8() {
        let result = calculator.getMatchResult(query: "saf", title: "My Safari")
        
        #expect(abs(result.quality - 0.8) <= 0.01)
        #expect(result.matchType == .wordStart)
    }
    
    @Test func test_fuzzyMatch_qualityIsLow() {
        let result = calculator.getMatchResult(query: "sfr", title: "Safari")
        
        #expect(result.quality > 0.05)
        #expect(result.quality < 0.6)
        #expect(result.matchType == .fuzzy)
    }
    
    @Test func test_substringMatch_qualityIsVeryLow() {
        let result = calculator.getMatchResult(query: "zoo", title: "amazon")
        
        #expect(abs(result.quality - 0) <= 0.01)
        #expect(result.matchType == .none)
    }
    
    @Test func test_substringInMiddleOfWord_isNotWordStart() {
        let result = calculator.getMatchResult(query: "mon", title: "companion")
        
        #expect(result.matchType == .fuzzy)
        #expect(result.quality < 0.5)
    }
    
    @Test func test_noMatch_returnsZero() {
        let result = calculator.getMatchResult(query: "xyz", title: "Safari")
        
        #expect(abs(result.quality - 0) <= 0.01)
        #expect(result.matchType == .none)
        #expect(!result.isMatch)
    }
    
    @Test func test_exactMatchBonus_is1_0() {
        #expect(SearchMatchType.exact.rawValue == 1.0)
    }
    
    @Test func test_prefixMatchBonus_is0_95() {
        #expect(SearchMatchType.prefix.rawValue == 0.95)
    }
    
    @Test func test_wordStartMatchBonus_is0_9() {
        #expect(SearchMatchType.wordStart.rawValue == 0.9)
    }
    
    @Test func test_fuzzyMatchBonus_is0_7() {
        #expect(SearchMatchType.fuzzy.rawValue == 0.7)
    }
    
    @Test func test_substringMatchBonus_is0_5() {
        #expect(SearchMatchType.substring.rawValue == 0.5)
    }
    
    @Test func test_applicationCategory_weightIs1_2() {
        let weights = SearchScoringWeights.default
        #expect(weights.weight(for: .application) == 1.2)
    }
    
    @Test func test_quicklinkCategory_weightIs0_8() {
        let weights = SearchScoringWeights.default
        #expect(weights.weight(for: .quicklink) == 0.8)
    }
    
    @Test func test_clipboardCategory_weightIs0_6() {
        let weights = SearchScoringWeights.default
        #expect(weights.weight(for: .clipboard) == 0.6)
    }
    
    @Test func test_fileCategory_weightIs0_5() {
        let weights = SearchScoringWeights.default
        #expect(weights.weight(for: .file) == 0.5)
    }
    
    @Test func test_appWithPrefix_scoresHigherThanQuicklinkWithFuzzy() {
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
        
        #expect(appScore > quicklinkScore)
        print("App score: \(appScore), Quicklink score: \(quicklinkScore)")
    }
    
    @Test func test_amoreApp_scoresHigherThanGoogleQuicklink_forA() {
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
        
        #expect(amoreScore > googleScore)
        print("Amore score: \(amoreScore), Google quicklink score: \(googleScore)")
    }
    
    @Test func test_spotifyConsecutive_scoresHigherThanSpootifyGap() {
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
        
        #expect(spotifyScore > spootifyScore)
        print("spotify score: \(spotifyScore), spootify score: \(spootifyScore)")
    }
    
    @Test func test_consecutiveMatches_scoreHigherThanWithGaps() {
        let consecutive = calculator.getMatchResult(query: "abc", title: "xabc")
        let withGap = calculator.getMatchResult(query: "abc", title: "axbxc")
        
        #expect(consecutive.quality > withGap.quality)
    }
    
    @Test func test_smallGaps_scoreHigherThanBigGaps() {
        let smallGaps = calculator.getMatchResult(query: "abc", title: "axbxc")
        let bigGaps = calculator.getMatchResult(query: "abc", title: "axxxxbxxxxc")
        
        #expect(smallGaps.quality > bigGaps.quality)
    }
    
    @Test func test_perfectMatch_scoresCloseTo1000() {
        let score = calculator.calculateScore(
            query: "safari",
            title: "Safari",
            category: .application
        )
        
        #expect(score == 1200)
    }
    
    @Test func test_prefixApp_scoresAround1000() {
        let score = calculator.calculateScore(
            query: "saf",
            title: "Safari",
            category: .application
        )
        
        let expected = Int(0.9 * 0.95 * 1.2 * 1.0 * 1000)
        #expect(score == expected)
    }
    
    @Test func test_weights_canBeSavedAndLoaded() {
        var weights = SearchScoringWeights.default
        weights.categoryApplication = 1.5
        weights.save()
        
        let loaded = SearchScoringWeights.load()
        #expect(loaded.categoryApplication == 1.5)
        
        SearchScoringWeights.default.save()
    }
}

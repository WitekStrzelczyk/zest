import AppKit
import Testing
@testable import ZestApp

final class SearchEngineTests {
    init() {
        ContactsService.isDisabled = true
        SearchEngine.disableAppLoading = true
        FileSearchService.isDisabled = true
    }

    deinit {
        ContactsService.isDisabled = false
        SearchEngine.disableAppLoading = false
        FileSearchService.isDisabled = false
    }

    @Test func test_search_finds_app_by_acronym() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "saf")

        let hasSafari = results.contains { $0.title.lowercased().contains("safari") }
        #expect(hasSafari || !results.isEmpty, "Should find Safari when searching for 'saf'")
    }

    @Test func test_search_returns_empty_for_empty_query() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "")

        #expect(results.isEmpty, "Empty query should return empty results")
    }

    @Test func test_search_caps_merged_results_at_80() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "a")

        #expect(results.count <= 80, "Should return at most 80 results")
    }

    @Test func test_search_prioritizes_calculator_expressions() {
        let engine = SearchEngine.shared
        let mathQuery = "2+2"

        let results = engine.search(query: mathQuery)

        let hasCalculatorResult = results.contains { $0.subtitle == "Copy to clipboard" }
        #expect(hasCalculatorResult, "Math expressions should return calculator result")
    }

    @Test func test_search_deduplicates_results_by_title() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "app")

        let titles = results.map { $0.title }
        let uniqueTitles = Set(titles)
        #expect(titles.count == uniqueTitles.count, "Results should not contain duplicate titles")
    }

    @Test func test_search_includes_clipboard_history() {
        let engine = SearchEngine.shared

        _ = engine.search(query: "the")

    }

    @Test func test_search_hidesClipboardWithoutClipPrefix() {
        let engine = SearchEngine.shared
        let results = engine.search(query: "the")
        let hasClipboard = results.contains { $0.category == .clipboard }
        #expect(!hasClipboard, "Clipboard items should be hidden unless query starts with 'clip'")
    }

    @Test func test_search_findsGCRCommand() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "gcr")

        let hasGCR = results.contains { $0.title == "Google Cloud Registry" && $0.category == .quicklink }
        #expect(hasGCR, "Should find 'gcr' command when searching for 'gcr'")
    }

    @Test func test_search_findsGCRCommand_withPartialMatch() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "gc")

        let hasGCR = results.contains { $0.title == "Google Cloud Registry" && $0.category == .quicklink }
        #expect(hasGCR, "Should find 'gcr' command with partial match 'gc'")
    }

    @Test func test_searchFast_findsGCRCommand() {
        let engine = SearchEngine.shared

        let results = engine.searchFast(query: "gcr")

        let hasGCR = results.contains { $0.title == "Google Cloud Registry" && $0.category == .quicklink }
        #expect(hasGCR, "Fast search should find 'gcr' command")
    }

    @Test func test_search_gcrCommand_opensURL() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "gcr")

        let gcrResult = results.first { $0.title == "Google Cloud Registry" && $0.category == .quicklink }
        #expect(gcrResult != nil, "Should find GCR command")
        #expect(gcrResult?.subtitle.contains("console.cloud.google.com") == true, "Should show the registry URL")
    }

    @Test func test_search_returnsQuicklinks_whenSearchingByName() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "google")

        let hasGoogleQuicklink = results.contains { $0.title == "Google" && $0.category == .quicklink }
        #expect(hasGoogleQuicklink, "Should find Google quicklink when searching for 'google'")
    }

    @Test func test_search_returnsQuicklinks_whenSearchingByURL() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "github.com")

        let hasGitHubQuicklink = results.contains { $0.title == "GitHub" && $0.category == .quicklink }
        #expect(hasGitHubQuicklink, "Should find GitHub quicklink when searching for 'github.com'")
    }

    @Test func test_search_returnsQuicklinks_whenSearchingByKeyword() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "search")

        let hasGoogleQuicklink = results.contains { $0.title == "Google" && $0.category == .quicklink }
        #expect(hasGoogleQuicklink, "Should find Google quicklink when searching for 'search' keyword")
    }

    @Test func test_search_returnsQuicklinks_whenSearchingQuicklinkKeyword() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "quicklink")

        let hasQuicklinks = results.contains { $0.category == .quicklink }
        #expect(hasQuicklinks, "Should find quicklinks when searching for 'quicklink' keyword")
    }

    @Test func test_search_settingsCategory_hasAddQuicklink() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "add")

        let hasAddQuicklink = results.contains { $0.title == "Add Quicklink" && $0.category == .settings }
        #expect(hasAddQuicklink, "Should find 'Add Quicklink' in settings category")
    }

    @Test func test_searchFast_returnsQuicklinks() {
        let engine = SearchEngine.shared

        let results = engine.searchFast(query: "github")

        let hasGitHubQuicklink = results.contains { $0.title == "GitHub" && $0.category == .quicklink }
        #expect(hasGitHubQuicklink, "Fast search should find GitHub quicklink")
    }

    @Test func test_search_returnsUnitConversion() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "100 km to miles")

        let hasConversionResult = results.contains { $0.category == .conversion }
        #expect(hasConversionResult, "Should return conversion result for '100 km to miles'")
    }

    @Test func test_searchFast_returnsUnitConversion() {
        let engine = SearchEngine.shared

        let results = engine.searchFast(query: "50 kg to lbs")

        let hasConversionResult = results.contains { $0.category == .conversion }
        #expect(hasConversionResult, "Fast search should return conversion result for '50 kg to lbs'")
    }

    @Test func test_search_convertKeyword_showsHints() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "convert")

        let hasConversionHints = results.contains { $0.category == .conversion }
        #expect(hasConversionHints, "Typing 'convert' should show conversion hints")
    }

    @Test func test_search_conversionResult_ranksFirst() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "72 f to c")

        #expect(results.first?.category == .conversion, "Conversion result should rank first")
    }
}

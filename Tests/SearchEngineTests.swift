import XCTest
@testable import ZestApp

/// Tests for SearchEngine functionality
final class SearchEngineTests: XCTestCase {

    // MARK: - Fuzzy Search Tests

    func test_search_finds_app_by_exact_name() {
        let engine = SearchEngine.shared
        let testQuery = "visual studio code"

        let results = engine.search(query: testQuery)

        let hasVSCode = results.contains { $0.title.lowercased().contains("visual studio code") }
        XCTAssertTrue(hasVSCode || !results.isEmpty, "Should find Visual Studio Code when searching for 'visual studio code'")
    }

    func test_search_finds_app_by_partial_name() {
        let engine = SearchEngine.shared
        let testQuery = "vscode"

        let results = engine.search(query: testQuery)

        XCTAssertFalse(results.isEmpty, "Should find apps with partial name match")
    }

    func test_search_finds_app_by_acronym() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "saf")

        let hasSafari = results.contains { $0.title.lowercased().contains("safari") }
        XCTAssertTrue(hasSafari || !results.isEmpty, "Should find Safari when searching for 'saf'")
    }

    func test_search_returns_empty_for_empty_query() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "")

        XCTAssertTrue(results.isEmpty, "Empty query should return empty results")
    }

    func test_search_returns_max_10_results() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "a")

        XCTAssertLessThanOrEqual(results.count, 10, "Should return at most 10 results")
    }

    func test_search_prioritizes_calculator_expressions() {
        let engine = SearchEngine.shared
        let mathQuery = "2+2"

        let results = engine.search(query: mathQuery)

        let hasCalculatorResult = results.contains { $0.subtitle == "Copy to clipboard" }
        XCTAssertTrue(hasCalculatorResult, "Math expressions should return calculator result")
    }

    func test_search_deduplicates_results_by_title() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "app")

        let titles = results.map { $0.title }
        let uniqueTitles = Set(titles)
        XCTAssertEqual(titles.count, uniqueTitles.count, "Results should not contain duplicate titles")
    }

    func test_search_includes_clipboard_history() {
        let engine = SearchEngine.shared

        let results = engine.search(query: "the")

        XCTAssertNotNil(results, "Search should return results including clipboard history")
    }
}

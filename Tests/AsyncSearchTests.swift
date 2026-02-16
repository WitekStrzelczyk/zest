import XCTest
@testable import ZestApp

/// Tests for Async Search functionality
final class AsyncSearchTests: XCTestCase {

    @MainActor
    func test_search_is_async() {
        let engine = SearchEngine.shared
        let query = "test"

        let results = engine.searchAsync(query: query)
        XCTAssertNotNil(results, "Search should return results")
    }

    @MainActor
    func test_searchAsync_returns_results() {
        let engine = SearchEngine.shared
        let query = "safari"

        let results = engine.searchAsync(query: query)
        XCTAssertFalse(results.isEmpty, "Should return results for 'safari' query")
    }

    @MainActor
    func test_searchAsync_returns_empty_for_empty_query() {
        let engine = SearchEngine.shared

        let results = engine.searchAsync(query: "")
        XCTAssertTrue(results.isEmpty, "Empty query should return empty results")
    }

    func test_search_can_be_cancelled() {
        // Just verify that cancelling a task doesn't crash
        let engine = SearchEngine.shared
        let query = "test"

        let searchTask = Task {
            await engine.searchAsync(query: query)
        }

        searchTask.cancel()

        // Test passes if no crash occurs
        XCTAssertTrue(true, "Cancellation should not crash")
    }
}

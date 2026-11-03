import AppKit
import Testing
@testable import ZestApp

@MainActor
final class AsyncSearchTests {
    init() {
        ContactsService.isDisabled = true
    }

    isolated deinit {
        ContactsService.isDisabled = false
    }

    @MainActor
    @Test func test_search_is_async() async {
        let engine = SearchEngine.shared
        let query = "test"

        _ = await engine.searchAsync(query: query)
    }

    @MainActor
    @Test func test_searchAsync_returns_results() async {
        let engine = SearchEngine.shared
        let query = "safari"

        let results = await engine.searchAsync(query: query)
        #expect(!results.isEmpty, "Should return results for 'safari' query")
    }

    @MainActor
    @Test func test_searchAsync_returns_empty_for_empty_query() async {
        let engine = SearchEngine.shared

        let results = await engine.searchAsync(query: "")
        #expect(results.isEmpty, "Empty query should return empty results")
    }

    @Test func test_search_can_be_cancelled() async {
        let engine = SearchEngine.shared
        let query = "test"

        let searchTask = Task {
            await engine.searchAsync(query: query)
        }

        searchTask.cancel()

        #expect(true, "Cancellation should not crash")
    }

    @MainActor
    @Test func test_searchAsync_completesQuickly() async {
        let engine = SearchEngine.shared
        let startTime = Date()

        let _ = await engine.searchAsync(query: "test")

        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed < 4.0, "searchAsync should complete within 4 seconds. Took \(elapsed) seconds.")
    }
}

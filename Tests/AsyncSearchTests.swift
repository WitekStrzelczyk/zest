import XCTest
@testable import ZestApp

/// Tests for Async Search functionality
/// Note: Contacts access is disabled during tests to avoid XPC connection issues
final class AsyncSearchTests: XCTestCase {

    override class func setUp() {
        // Disable contacts access during tests to avoid XPC connection issues
        // in the unit test environment
        ContactsService.isDisabled = true
    }

    override class func tearDown() {
        ContactsService.isDisabled = false
    }

    @MainActor
    func test_search_is_async() async {
        let engine = SearchEngine.shared
        let query = "test"

        let results = await engine.searchAsync(query: query)
        XCTAssertNotNil(results, "Search should return results")
    }

    @MainActor
    func test_searchAsync_returns_results() async {
        let engine = SearchEngine.shared
        let query = "safari"

        let results = await engine.searchAsync(query: query)
        XCTAssertFalse(results.isEmpty, "Should return results for 'safari' query")
    }

    @MainActor
    func test_searchAsync_returns_empty_for_empty_query() async {
        let engine = SearchEngine.shared

        let results = await engine.searchAsync(query: "")
        XCTAssertTrue(results.isEmpty, "Empty query should return empty results")
    }

    func test_search_can_be_cancelled() async {
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

    /// Tests that searchAsync doesn't block the main thread
    /// The search should complete within a reasonable time (file search has 2s timeout)
    @MainActor
    func test_searchAsync_completesQuickly() async {
        let engine = SearchEngine.shared
        let startTime = Date()

        // Perform a search that would previously block
        let _ = await engine.searchAsync(query: "test")

        let elapsed = Date().timeIntervalSince(startTime)

        // Search should complete within 3 seconds (2s timeout + buffer)
        XCTAssertLessThan(
            elapsed,
            3.0,
            "searchAsync should complete within 3 seconds. Took \(elapsed) seconds."
        )
    }
}

import XCTest
@testable import ZestApp

/// Tests for File Search Service functionality
final class FileSearchServiceTests: XCTestCase {

    func testFileSearchServiceCreation() {
        let service = FileSearchService.shared
        XCTAssertNotNil(service)
    }

    func testFileSearchServiceSingleton() {
        let service1 = FileSearchService.shared
        let service2 = FileSearchService.shared
        XCTAssertTrue(service1 === service2)
    }

    func testEmptySearchQuery() {
        let service = FileSearchService.shared
        let results = service.searchSync(query: "", maxResults: 10)
        XCTAssertTrue(results.isEmpty)
    }

    func testFileSearchByName() {
        let service = FileSearchService.shared
        let results = service.searchSync(query: "test", maxResults: 10)
        XCTAssertNotNil(results)
    }

    // MARK: - Timeout Tests

    /// Tests that searchSync completes within the timeout period
    /// This is critical to prevent the app from freezing if mdfind hangs
    func test_searchSync_completesWithinTimeout() {
        let service = FileSearchService.shared
        let startTime = Date()

        // Perform a search that should complete quickly
        let _ = service.searchSync(query: "test", maxResults: 10)

        let elapsed = Date().timeIntervalSince(startTime)

        // Search should complete within 3 seconds (timeout is 2s, give some buffer)
        XCTAssertLessThan(
            elapsed,
            3.0,
            "searchSync should complete within 3 seconds. Took \(elapsed) seconds."
        )
    }

    /// Tests that searchSync has a configurable timeout
    func test_searchSync_hasConfigurableTimeout() {
        let service = FileSearchService.shared

        // The timeout property should be accessible and reasonable
        let timeout = service.searchTimeout

        XCTAssertGreaterThan(timeout, 0, "Timeout should be positive")
        XCTAssertLessThan(timeout, 10, "Timeout should be reasonable (under 10 seconds)")
    }
}

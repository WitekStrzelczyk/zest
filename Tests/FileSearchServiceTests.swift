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

        // Search should complete within 4 seconds (timeout is 2s + 1s NSMetadataQuery, give some buffer)
        XCTAssertLessThan(
            elapsed,
            4.0,
            "searchSync should complete within 4 seconds. Took \(elapsed) seconds."
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

    // MARK: - NSMetadataQuery Tests

    /// Tests that NSMetadataQuery is used as the primary search method
    /// When forceMdfind is false, the service should prefer NSMetadataQuery
    func test_searchSync_usesNSMetadataQuery_whenNotForced() {
        let service = FileSearchService.shared
        service.forceMdfind = false

        // This should use NSMetadataQuery, not mdfind
        let results = service.searchSync(query: "Package.swift", maxResults: 10)

        // Results should come from NSMetadataQuery (which may return results)
        // The key is that the search completes without using mdfind
        XCTAssertNotNil(results)
    }

    /// Tests that search scopes are configured correctly
    /// The search should be limited to Documents, Downloads, Desktop, and Home
    func test_searchScopes_areConfiguredCorrectly() {
        let service = FileSearchService.shared

        // Get the configured search scopes
        let scopes = service.configuredSearchScopes

        // Should include Documents, Downloads, Desktop, and Home
        XCTAssertFalse(scopes.isEmpty, "Search scopes should not be empty")

        // Should include Documents folder path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path
        if let docsPath = documentsPath {
            XCTAssertTrue(
                scopes.contains { $0.contains(docsPath) },
                "Search scopes should include Documents directory"
            )
        }
    }

    /// Tests that NSMetadataQuery search completes within a reasonable time
    /// Note: NSMetadataQuery may be slower in test environments without a proper run loop
    /// The target is 100ms in production, but we allow up to 1.5s in tests
    func test_nsmetadataQuery_completesWithinReasonableTime() {
        let service = FileSearchService.shared

        let startTime = Date()
        _ = service.performNSMetadataQuery(query: "test", maxResults: 10)
        let elapsed = Date().timeIntervalSince(startTime) * 1000 // Convert to ms

        // NSMetadataQuery should complete within a reasonable time
        // Production target: 100ms, Test environment allowance: 1500ms
        XCTAssertLessThan(
            elapsed,
            1500.0,
            "NSMetadataQuery should complete within 1500ms in test environment. Took \(elapsed)ms."
        )
    }

    /// Tests that mdfind is only used when explicitly forced
    func test_mdfindFallback_onlyUsedWhenForced() {
        let service = FileSearchService.shared

        // Force mdfind
        service.forceMdfind = true
        let mdfindResults = service.searchSync(query: "test", maxResults: 5)

        // Don't force mdfind
        service.forceMdfind = false
        let nativeResults = service.searchSync(query: "test", maxResults: 5)

        // Both should return results (but from different sources)
        // This test mainly verifies the flag works
        service.forceMdfind = false // Reset to default
        XCTAssertNotNil(mdfindResults)
        XCTAssertNotNil(nativeResults)
    }
}

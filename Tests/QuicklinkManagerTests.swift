import XCTest
@testable import ZestApp

/// Tests for Quicklink management functionality
final class QuicklinkManagerTests: XCTestCase {

    /// Test that Quicklink can be created
    func testQuicklinkCreation() {
        let quicklink = Quicklink(
            name: "Test Link",
            url: "https://example.com",
            keywords: ["test", "example"]
        )

        XCTAssertEqual(quicklink.name, "Test Link")
        XCTAssertEqual(quicklink.url, "https://example.com")
        XCTAssertEqual(quicklink.keywords.count, 2)
    }

    /// Test URL validation
    func testURLValidation() {
        let validQuicklink = Quicklink(name: "Test", url: "https://example.com")
        XCTAssertTrue(validQuicklink.isValidURL)

        let invalidQuicklink = Quicklink(name: "Test", url: "not-a-url")
        XCTAssertFalse(invalidQuicklink.isValidURL)

        let httpQuicklink = Quicklink(name: "Test", url: "http://example.com")
        XCTAssertTrue(httpQuicklink.isValidURL)
    }

    /// Test URL normalization
    func testURLNormalization() {
        let quicklink = Quicklink(name: "Test", url: "example.com")
        XCTAssertEqual(quicklink.normalizedURL, "https://example.com")

        let httpsQuicklink = Quicklink(name: "Test", url: "https://example.com")
        XCTAssertEqual(httpsQuicklink.normalizedURL, "https://example.com")

        let httpQuicklink = Quicklink(name: "Test", url: "http://example.com")
        XCTAssertEqual(httpQuicklink.normalizedURL, "http://example.com")
    }

    /// Test QuicklinkManager singleton
    func testQuicklinkManagerSingleton() {
        let manager1 = QuicklinkManager.shared
        let manager2 = QuicklinkManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    /// Test quicklink search by name
    func testQuicklinkSearchByName() {
        let manager = QuicklinkManager.shared
        let results = manager.searchQuicklinks(query: "google")
        XCTAssertFalse(results.isEmpty)
    }

    /// Test quicklink search with empty query returns all
    func testEmptySearchQuery() {
        let manager = QuicklinkManager.shared
        let results = manager.searchQuicklinks(query: "")
        XCTAssertFalse(results.isEmpty)
    }

    /// Test quicklink search by URL
    func testSearchByURL() {
        let manager = QuicklinkManager.shared
        let results = manager.searchQuicklinks(query: "github")
        XCTAssertFalse(results.isEmpty)
    }

    /// Test quicklink search by keyword
    func testSearchByKeyword() {
        let manager = QuicklinkManager.shared
        let results = manager.searchQuicklinks(query: "search")
        XCTAssertFalse(results.isEmpty)
    }
}

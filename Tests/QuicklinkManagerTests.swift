import AppKit
import Testing
@testable import ZestApp

@MainActor
final class QuicklinkManagerTests {
    @Test func testQuicklinkCreation() {
        let quicklink = Quicklink(
            name: "Test Link",
            url: "https://example.com",
            keywords: ["test", "example"]
        )

        #expect(quicklink.name == "Test Link")
        #expect(quicklink.url == "https://example.com")
        #expect(quicklink.keywords.count == 2)
    }

    @Test func testURLValidation() {
        let validQuicklink = Quicklink(name: "Test", url: "https://example.com")
        #expect(validQuicklink.isValidURL)

        let invalidQuicklink = Quicklink(name: "Test", url: "not-a-url")
        #expect(!invalidQuicklink.isValidURL)

        let httpQuicklink = Quicklink(name: "Test", url: "http://example.com")
        #expect(httpQuicklink.isValidURL)
    }

    @Test func testURLNormalization() {
        let quicklink = Quicklink(name: "Test", url: "example.com")
        #expect(quicklink.normalizedURL == "https://example.com")

        let httpsQuicklink = Quicklink(name: "Test", url: "https://example.com")
        #expect(httpsQuicklink.normalizedURL == "https://example.com")

        let httpQuicklink = Quicklink(name: "Test", url: "http://example.com")
        #expect(httpQuicklink.normalizedURL == "http://example.com")
    }

    @Test func testQuicklinkManagerSingleton() {
        let manager1 = QuicklinkManager.shared
        let manager2 = QuicklinkManager.shared
        #expect(manager1 === manager2)
    }

    @Test func testQuicklinkSearchByName() {
        let manager = QuicklinkManager.shared
        let results = manager.searchQuicklinks(query: "google")
        #expect(!results.isEmpty)
    }

    @Test func testEmptySearchQuery() {
        let manager = QuicklinkManager.shared
        let results = manager.searchQuicklinks(query: "")
        #expect(!results.isEmpty)
    }

    @Test func testSearchByURL() {
        let manager = QuicklinkManager.shared
        let results = manager.searchQuicklinks(query: "github")
        #expect(!results.isEmpty)
    }

    @Test func testSearchByKeyword() {
        let manager = QuicklinkManager.shared
        let results = manager.searchQuicklinks(query: "search")
        #expect(!results.isEmpty)
    }
}

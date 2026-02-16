import XCTest
@testable import ZestApp

/// Tests for Snippet management functionality
final class SnippetManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Use a test directory
    }

    override func tearDown() {
        super.tearDown()
    }

    /// Test that Snippet can be created
    func testSnippetCreation() {
        let snippet = Snippet(
            name: "Test Snippet",
            content: "Hello {name}!",
            keywords: ["test", "hello"]
        )

        XCTAssertEqual(snippet.name, "Test Snippet")
        XCTAssertEqual(snippet.content, "Hello {name}!")
        XCTAssertEqual(snippet.keywords.count, 2)
    }

    /// Test variable extraction from snippet content
    func testVariableExtraction() {
        let snippet = Snippet(
            name: "Greeting",
            content: "Hello {name}, welcome to {place}!"
        )

        let variables = snippet.variables
        XCTAssertTrue(variables.contains("name"))
        XCTAssertTrue(variables.contains("place"))
        XCTAssertEqual(variables.count, 2)
    }

    /// Test content expansion with values
    func testContentExpansion() {
        let snippet = Snippet(
            name: "Greeting",
            content: "Hello {name}, welcome to {place}!"
        )

        let expanded = snippet.expand(with: ["name": "John", "place": "Zest"])
        XCTAssertEqual(expanded, "Hello John, welcome to Zest!")
    }

    /// Test expansion with missing values (should keep placeholder)
    func testContentExpansionWithMissingValues() {
        let snippet = Snippet(
            name: "Greeting",
            content: "Hello {name}, your score is {score}!"
        )

        let expanded = snippet.expand(with: ["name": "John"])
        XCTAssertEqual(expanded, "Hello John, your score is {score}!")
    }

    /// Test SnippetManager singleton
    func testSnippetManagerSingleton() {
        let manager1 = SnippetManager.shared
        let manager2 = SnippetManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    /// Test snippet search by name
    func testSnippetSearchByName() {
        // Note: This test uses real storage, so it may have side effects
        let manager = SnippetManager.shared

        // Search for non-existent snippet should return results (built-in exist)
        let results = manager.searchSnippets(query: "date")
        XCTAssertFalse(results.isEmpty)
    }

    /// Test snippet search with empty query returns all
    func testEmptySearchQuery() {
        let manager = SnippetManager.shared
        let results = manager.searchSnippets(query: "")
        XCTAssertFalse(results.isEmpty)
    }
}

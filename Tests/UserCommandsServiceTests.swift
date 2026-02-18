import XCTest
@testable import ZestApp

/// Tests for UserCommandsService functionality
final class UserCommandsServiceTests: XCTestCase {

    // MARK: - Basic Functionality Tests

    func test_getAllCommands_returnsHardcodedCommands() {
        let service = UserCommandsService.shared

        let commands = service.getAllCommands()

        XCTAssertFalse(commands.isEmpty, "Should have at least one command")
    }

    func test_getAllCommands_includesGCRCommand() {
        let service = UserCommandsService.shared

        let commands = service.getAllCommands()

        let gcrCommand = commands.first { $0.name == "gcr" }
        XCTAssertNotNil(gcrCommand, "Should have 'gcr' command")
    }

    func test_gcrCommand_hasCorrectURL() {
        let service = UserCommandsService.shared

        let commands = service.getAllCommands()
        let gcrCommand = commands.first { $0.name == "gcr" }

        XCTAssertEqual(
            gcrCommand?.url.absoluteString,
            "https://console.cloud.google.com/artifacts/docker/ninety-devops/asia/apps?hl=en&inv=1&invt=Ab0RbA&project=ninety-devops",
            "GCR command should have correct URL"
        )
    }

    // MARK: - Search Tests

    func test_search_exactMatch_returnsGCRCommand() {
        let service = UserCommandsService.shared

        let results = service.search(query: "gcr")

        XCTAssertFalse(results.isEmpty, "Searching for 'gcr' should return results")
        XCTAssertTrue(results.contains { $0.title == "gcr" }, "Should find 'gcr' command")
    }

    func test_search_partialMatch_returnsGCRCommand() {
        let service = UserCommandsService.shared

        let results = service.search(query: "gc")

        XCTAssertFalse(results.isEmpty, "Partial match 'gc' should return results")
        XCTAssertTrue(results.contains { $0.title == "gcr" }, "Should find 'gcr' command with partial match")
    }

    func test_search_caseInsensitive() {
        let service = UserCommandsService.shared

        let results = service.search(query: "GCR")

        XCTAssertFalse(results.isEmpty, "Case-insensitive search should work")
        XCTAssertTrue(results.contains { $0.title == "gcr" }, "Should find 'gcr' with uppercase query")
    }

    func test_search_noMatch_returnsEmpty() {
        let service = UserCommandsService.shared

        let results = service.search(query: "xyz123notfound")

        XCTAssertTrue(results.isEmpty, "Non-matching query should return empty results")
    }

    func test_search_emptyQuery_returnsAllCommands() {
        let service = UserCommandsService.shared

        let results = service.search(query: "")

        XCTAssertEqual(results.count, service.getAllCommands().count, "Empty query should return all commands")
    }

    // MARK: - SearchResult Tests

    func test_searchResults_haveDescriptionAsSubtitle() {
        let service = UserCommandsService.shared

        let results = service.search(query: "gcr")

        let gcrResult = results.first { $0.title == "gcr" }
        XCTAssertNotNil(gcrResult, "Should have GCR result")
        XCTAssertEqual(gcrResult?.subtitle, "Google Cloud Registry", "Should have description as subtitle")
    }

    func test_searchResults_haveTerminalIcon() {
        let service = UserCommandsService.shared

        let results = service.search(query: "gcr")

        let gcrResult = results.first { $0.title == "gcr" }
        XCTAssertNotNil(gcrResult, "Should have GCR result")
        XCTAssertNotNil(gcrResult?.icon, "Should have an icon")
    }
}

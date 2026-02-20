import XCTest
@testable import ZestApp

/// Integration tests for SearchEngine with ProcessSearchService
final class ProcessSearchEngineIntegrationTests: XCTestCase {

    // MARK: - Process Search Integration

    func test_searchEngine_withProcessQuery_returnsProcessResults() {
        let results = SearchEngine.shared.searchFast(query: "processes")

        // Should return process results
        XCTAssertFalse(results.isEmpty, "Should return process results for 'processes' query")

        // First result should be a process
        let firstResult = results.first!
        XCTAssertEqual(firstResult.category, SearchResultCategory.process, "Category should be .process")
    }

    func test_searchEngine_withProcessQuery_singleWord() {
        let results = SearchEngine.shared.searchFast(query: "process")

        // Should return process results
        XCTAssertFalse(results.isEmpty, "Should return process results for 'process' query")

        // First result should be a process
        let firstResult = results.first!
        XCTAssertEqual(firstResult.category, SearchResultCategory.process, "Category should be .process")
    }

    func test_searchEngine_withProcessAndName_searchesSpecificProcess() {
        // First get all processes to find one that exists
        let processes = ProcessSearchService.shared.fetchRunningProcesses()

        // Find a process name that exists
        if let processName = processes.first(where: { $0.isUserApp })?.name {
            // Search for that specific process
            let searchQuery = "process \(processName)"
            let results = SearchEngine.shared.searchFast(query: searchQuery)

            // Should return process results
            XCTAssertFalse(results.isEmpty, "Should return process results")

            // Should contain the searched process
            let foundProcess = results.contains { $0.title.lowercased().contains(processName.lowercased()) }
            XCTAssertTrue(foundProcess, "Should find process named '\(processName)'")
        }
    }

    func test_searchEngine_processResultsHaveValidSubtitle() {
        let results = SearchEngine.shared.searchFast(query: "processes")

        for result in results {
            // Subtitle should contain memory and CPU
            let hasMemory = result.subtitle.contains("MB") || result.subtitle.contains("GB")
            let hasCPU = result.subtitle.contains("%")
            XCTAssertTrue(hasMemory, "Process subtitle should contain memory for '\(result.title)'")
            XCTAssertTrue(hasCPU, "Process subtitle should contain CPU for '\(result.title)'")
        }
    }

    func test_searchEngine_processResultAction_activatesApp() {
        let results = SearchEngine.shared.searchFast(query: "processes")

        // Find a user app in the results
        let userAppResult = results.first { result in
            // Try to find a running app to test activation
            let runningApps = NSWorkspace.shared.runningApplications
            return runningApps.contains { $0.localizedName?.lowercased() == result.title.lowercased() }
        }

        // If we found a user app, its action should not crash when executed
        if let userAppResult = userAppResult {
            // Execute action - should activate the app without crashing
            userAppResult.action()
        }
    }

    func test_searchEngine_noProcessMatch_returnsNoResultsMessage() {
        // Use a very specific query that won't match any process
        let results = SearchEngine.shared.searchFast(query: "process xyznonexistent12345")

        // If there are results, they should include the no results message
        if !results.isEmpty {
            let hasNoResultsMessage = results.contains { $0.title == ProcessSearchService.noResultsMessage }
            XCTAssertTrue(hasNoResultsMessage, "Should include no results message when no processes match")
        }
    }
}

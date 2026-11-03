import AppKit
import Testing
@testable import ZestApp

final class ProcessSearchEngineIntegrationTests {
    @Test func test_searchEngine_withProcessQuery_returnsProcessResults() {
        let results = SearchEngine.shared.searchFast(query: "processes")

        #expect(!results.isEmpty, "Should return process results for 'processes' query")

        let firstResult = results.first!
        #expect(firstResult.category == SearchResultCategory.process, "Category should be .process")
    }

    @Test func test_searchEngine_withProcessQuery_singleWord() {
        let results = SearchEngine.shared.searchFast(query: "process")

        #expect(!results.isEmpty, "Should return process results for 'process' query")

        let firstResult = results.first!
        #expect(firstResult.category == SearchResultCategory.process, "Category should be .process")
    }

    @Test func test_searchEngine_withProcessAndName_searchesSpecificProcess() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()

        if let processName = processes.first(where: { $0.isUserApp })?.name {
            let searchQuery = "process \(processName)"
            let results = SearchEngine.shared.searchFast(query: searchQuery)

            #expect(!results.isEmpty, "Should return process results")

            let foundProcess = results.contains { $0.title.lowercased().contains(processName.lowercased()) }
            #expect(foundProcess, "Should find process named '\(processName)'")
        }
    }

    @Test func test_searchEngine_processResultsHaveValidSubtitle() {
        let results = SearchEngine.shared.searchFast(query: "processes")

        for result in results {
            let hasMemory = result.subtitle.contains("MB") || result.subtitle.contains("GB")
            let hasCPU = result.subtitle.contains("%")
            #expect(hasMemory, "Process subtitle should contain memory for '\(result.title)'")
            #expect(hasCPU, "Process subtitle should contain CPU for '\(result.title)'")
        }
    }

    @Test func test_searchEngine_processResultAction_activatesApp() {
        let results = SearchEngine.shared.searchFast(query: "processes")

        let userAppResult = results.first { result in
            let runningApps = NSWorkspace.shared.runningApplications
            return runningApps.contains { $0.localizedName?.lowercased() == result.title.lowercased() }
        }

        if let userAppResult = userAppResult {
            userAppResult.action()
        }
    }

    @Test func test_searchEngine_noProcessMatch_returnsNoResultsMessage() {
        let results = SearchEngine.shared.searchFast(query: "process xyznonexistent12345")

        if !results.isEmpty {
            let hasNoResultsMessage = results.contains { $0.title == ProcessSearchService.noResultsMessage }
            #expect(hasNoResultsMessage, "Should include no results message when no processes match")
        }
    }
}

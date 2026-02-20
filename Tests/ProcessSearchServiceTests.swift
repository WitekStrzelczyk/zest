import XCTest
@testable import ZestApp

/// Tests for ProcessSearchService - fetching and filtering running processes
final class ProcessSearchServiceTests: XCTestCase {

    // MARK: - Process Fetching Tests

    func test_fetchRunningProcesses_returnsNonEmptyList() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()

        XCTAssertFalse(processes.isEmpty, "Should return at least one running process")
    }

    func test_fetchRunningProcesses_hasValidMemoryValues() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()

        for process in processes {
            XCTAssertGreaterThanOrEqual(process.memoryBytes, 0, "Memory should be non-negative")
            XCTAssertLessThan(process.memoryBytes, 500_000_000_000, "Memory should be reasonable (< 500GB)")
        }
    }

    func test_fetchRunningProcesses_hasValidCPUValues() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()

        for process in processes {
            XCTAssertGreaterThanOrEqual(process.cpuPercent, 0.0, "CPU should be >= 0%")
            XCTAssertLessThanOrEqual(process.cpuPercent, 100.0, "CPU should be <= 100%")
        }
    }

    // MARK: - Search Filtering Tests

    func test_searchProcesses_filtersByName() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        // Find a process that exists on this system - use a common one
        let searchQuery = " Finder"
        let filtered = ProcessSearchService.shared.searchProcesses(query: searchQuery, processes: allProcesses)

        // Should filter to only matching processes
        for process in filtered {
            let lowercaseName = process.name.lowercased()
            let lowercaseQuery = searchQuery.lowercased()
            let matches = lowercaseName.contains(lowercaseQuery) ||
                          lowercaseName.replacingOccurrences(of: " ", with: "").contains(lowercaseQuery)
            XCTAssertTrue(matches, "Process '\(process.name)' should match query '\(searchQuery)'")
        }
    }

    func test_searchProcesses_emptyQueryReturnsTopProcesses() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        // Empty query should return top processes (by CPU), not empty
        // This is the expected behavior for the command palette
        let filtered = ProcessSearchService.shared.searchProcesses(query: "", processes: allProcesses)

        XCTAssertFalse(filtered.isEmpty, "Empty query should return top processes by CPU")
        XCTAssertLessThanOrEqual(filtered.count, 30, "Should limit to max results")
    }

    func test_searchProcesses_noMatchesReturnsEmpty() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        // Use a very unlikely process name
        let filtered = ProcessSearchService.shared.searchProcesses(
            query: "ThisProcessNameDefinitelyDoesNotExist12345",
            processes: allProcesses
        )

        XCTAssertTrue(filtered.isEmpty, "Non-existent process should return empty")
    }

    func test_searchProcesses_isCaseInsensitive() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        // Get any existing process to test case insensitivity
        let uppercaseResults = ProcessSearchService.shared.searchProcesses(query: "FINDER", processes: allProcesses)
        let lowercaseResults = ProcessSearchService.shared.searchProcesses(query: "finder", processes: allProcesses)

        // Both should return same count if Finder exists
        XCTAssertEqual(uppercaseResults.count, lowercaseResults.count, "Case insensitive search should return same count")
    }

    // MARK: - Sorting Tests

    func test_searchProcesses_sortsByCPULDescending() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        let filtered = ProcessSearchService.shared.searchProcesses(query: "", processes: allProcesses)

        // Results should be sorted by CPU descending
        if filtered.count > 1 {
            for i in 0..<(filtered.count - 1) {
                XCTAssertGreaterThanOrEqual(
                    filtered[i].cpuPercent,
                    filtered[i + 1].cpuPercent,
                    "Results should be sorted by CPU descending"
                )
            }
        }
    }

    // MARK: - Result Limiting Tests

    func test_searchProcesses_limitsResults() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        let filtered = ProcessSearchService.shared.searchProcesses(query: "", processes: allProcesses)

        // Results should be limited to max results (default 30)
        XCTAssertLessThanOrEqual(filtered.count, 30, "Results should be limited to max 30")
    }

    // MARK: - RunningProcess Model Tests

    func test_runningProcess_memoryInMB() {
        let process = RunningProcess(
            name: "Test",
            pid: 123,
            memoryBytes: 256_000_000, // ~256 MB
            cpuPercent: 10.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        let memoryString = process.memoryFormatted

        // Should contain "MB" for values in megabyte range
        XCTAssertTrue(memoryString.contains("MB"), "Memory should be formatted in MB")
    }

    func test_runningProcess_memoryInGB() {
        let process = RunningProcess(
            name: "Test",
            pid: 123,
            memoryBytes: 2_500_000_000, // ~2.5 GB
            cpuPercent: 10.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        let memoryString = process.memoryFormatted

        // Should contain "GB" for values in gigabyte range
        XCTAssertTrue(memoryString.contains("GB"), "Memory should be formatted in GB")
    }

    func test_runningProcess_cpuFormatted() {
        let processWhole = RunningProcess(
            name: "Test",
            pid: 123,
            memoryBytes: 100_000_000,
            cpuPercent: 5.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        let processDecimal = RunningProcess(
            name: "Test",
            pid: 123,
            memoryBytes: 100_000_000,
            cpuPercent: 12.3,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        XCTAssertTrue(processWhole.cpuFormatted.contains("%"), "CPU should contain % symbol")
        XCTAssertTrue(processDecimal.cpuFormatted.contains("%"), "CPU should contain % symbol")
    }

    func test_runningProcess_resourceSubtitle() {
        let process = RunningProcess(
            name: "Test",
            pid: 123,
            memoryBytes: 256_000_000,
            cpuPercent: 10.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        let subtitle = process.resourceSubtitle

        // Should contain memory, separator, and CPU
        XCTAssertTrue(subtitle.contains("MB"), "Subtitle should contain memory")
        XCTAssertTrue(subtitle.contains("|"), "Subtitle should contain separator")
        XCTAssertTrue(subtitle.contains("%"), "Subtitle should contain CPU")
    }
}

// MARK: - SearchResult Integration Tests

final class ProcessSearchIntegrationTests: XCTestCase {

    func test_createSearchResults_returnsValidSearchResults() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()
        let results = ProcessSearchService.shared.createSearchResults(from: processes)

        XCTAssertFalse(results.isEmpty, "Should create search results from processes")

        for result in results {
            // Verify all required properties are set
            XCTAssertFalse(result.title.isEmpty, "Title should not be empty")
            XCTAssertFalse(result.subtitle.isEmpty, "Subtitle should not be empty")
            XCTAssertNotNil(result.action, "Action should be defined")
        }
    }

    func test_createSearchResults_includesMemoryInSubtitle() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()
        let results = ProcessSearchService.shared.createSearchResults(from: processes)

        for result in results {
            // Subtitle should contain memory info (MB or GB)
            let hasMemoryInfo = result.subtitle.contains("MB") || result.subtitle.contains("GB")
            XCTAssertTrue(hasMemoryInfo, "Subtitle should contain memory info for '\(result.title)'")
        }
    }

    func test_createSearchResults_includesCPUInSubtitle() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()
        let results = ProcessSearchService.shared.createSearchResults(from: processes)

        for result in results {
            // Subtitle should contain CPU info
            XCTAssertTrue(result.subtitle.contains("%"), "Subtitle should contain CPU percentage")
        }
    }

    func test_createSearchResults_hasCorrectCategory() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()
        let results = ProcessSearchService.shared.createSearchResults(from: processes)

        for result in results {
            XCTAssertEqual(result.category, SearchResultCategory.process, "Category should be .process")
        }
    }
}

// MARK: - No Results Message Tests

final class ProcessNoResultsTests: XCTestCase {

    func test_noMatchingProcessesMessage() {
        let message = ProcessSearchService.noResultsMessage

        XCTAssertFalse(message.isEmpty, "No results message should not be empty")
        XCTAssertTrue(message.lowercased().contains("no"), "Message should indicate no results")
        XCTAssertTrue(message.lowercased().contains("process"), "Message should mention processes")
    }
}

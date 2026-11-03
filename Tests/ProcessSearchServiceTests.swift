import AppKit
import Testing
@testable import ZestApp

@MainActor
final class ProcessSearchServiceTests {
    @Test func test_fetchRunningProcesses_returnsNonEmptyList() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()

        #expect(!processes.isEmpty, "Should return at least one running process")
    }

    @Test func test_fetchRunningProcesses_hasValidMemoryValues() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()

        for process in processes {
            #expect(process.memoryBytes >= 0, "Memory should be non-negative")
            #expect(process.memoryBytes < 500_000_000_000, "Memory should be reasonable (< 500GB)")
        }
    }

    @Test func test_fetchRunningProcesses_hasValidCPUValues() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()

        for process in processes {
            #expect(process.cpuPercent >= 0.0, "CPU should be >= 0%")
            #expect(process.cpuPercent <= 100.0, "CPU should be <= 100%")
        }
    }

    @Test func test_searchProcesses_filtersByName() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        let searchQuery = " Finder"
        let filtered = ProcessSearchService.shared.searchProcesses(query: searchQuery, processes: allProcesses)

        for process in filtered {
            let lowercaseName = process.name.lowercased()
            let lowercaseQuery = searchQuery.lowercased()
            let matches = lowercaseName.contains(lowercaseQuery) ||
                          lowercaseName.replacingOccurrences(of: " ", with: "").contains(lowercaseQuery)
            #expect(matches, "Process '\(process.name)' should match query '\(searchQuery)'")
        }
    }

    @Test func test_searchProcesses_emptyQueryReturnsTopProcesses() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        let filtered = ProcessSearchService.shared.searchProcesses(query: "", processes: allProcesses)

        #expect(!filtered.isEmpty, "Empty query should return top processes by CPU")
        #expect(filtered.count <= 30, "Should limit to max results")
    }

    @Test func test_searchProcesses_noMatchesReturnsEmpty() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        let filtered = ProcessSearchService.shared.searchProcesses(
            query: "ThisProcessNameDefinitelyDoesNotExist12345",
            processes: allProcesses
        )

        #expect(filtered.isEmpty, "Non-existent process should return empty")
    }

    @Test func test_searchProcesses_isCaseInsensitive() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        let uppercaseResults = ProcessSearchService.shared.searchProcesses(query: "FINDER", processes: allProcesses)
        let lowercaseResults = ProcessSearchService.shared.searchProcesses(query: "finder", processes: allProcesses)

        #expect(uppercaseResults.count == lowercaseResults.count, "Case insensitive search should return same count")
    }

    @Test func test_searchProcesses_sortsByCPULDescending() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        let filtered = ProcessSearchService.shared.searchProcesses(query: "", processes: allProcesses)

        if filtered.count > 1 {
            for i in 0..<(filtered.count - 1) {
                #expect(filtered[i].cpuPercent >= filtered[i + 1].cpuPercent, "Results should be sorted by CPU descending")
            }
        }
    }

    @Test func test_searchProcesses_limitsResults() {
        let allProcesses = ProcessSearchService.shared.fetchRunningProcesses()

        let filtered = ProcessSearchService.shared.searchProcesses(query: "", processes: allProcesses)

        #expect(filtered.count <= 30, "Results should be limited to max 30")
    }

    @Test func test_runningProcess_memoryInMB() {
        let process = RunningProcess(
            name: "Test",
            pid: 123,
            memoryBytes: 256_000_000,
            cpuPercent: 10.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        let memoryString = process.memoryFormatted

        #expect(memoryString.contains("MB"), "Memory should be formatted in MB")
    }

    @Test func test_runningProcess_memoryInGB() {
        let process = RunningProcess(
            name: "Test",
            pid: 123,
            memoryBytes: 2_500_000_000,
            cpuPercent: 10.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        let memoryString = process.memoryFormatted

        #expect(memoryString.contains("GB"), "Memory should be formatted in GB")
    }

    @Test func test_runningProcess_cpuFormatted() {
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

        #expect(processWhole.cpuFormatted.contains("%"), "CPU should contain % symbol")
        #expect(processDecimal.cpuFormatted.contains("%"), "CPU should contain % symbol")
    }

    @Test func test_runningProcess_resourceSubtitle() {
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

        #expect(subtitle.contains("PID:"), "Subtitle should contain PID label")
        #expect(subtitle.contains("123"), "Subtitle should contain PID value")
        #expect(subtitle.contains("MB"), "Subtitle should contain memory")
        #expect(subtitle.contains("|"), "Subtitle should contain separator")
        #expect(subtitle.contains("%"), "Subtitle should contain CPU")
    }
}

@MainActor
final class ProcessSearchIntegrationTests {
    @Test func test_createSearchResults_returnsValidSearchResults() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()
        let results = ProcessSearchService.shared.createSearchResults(from: processes)

        #expect(!results.isEmpty, "Should create search results from processes")

        for result in results {
            #expect(!result.title.isEmpty, "Title should not be empty")
            #expect(!result.subtitle.isEmpty, "Subtitle should not be empty")
        }
    }

    @Test func test_createSearchResults_includesMemoryInSubtitle() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()
        let results = ProcessSearchService.shared.createSearchResults(from: processes)

        for result in results {
            let hasMemoryInfo = result.subtitle.contains("MB") || result.subtitle.contains("GB")
            #expect(hasMemoryInfo, "Subtitle should contain memory info for '\(result.title)'")
        }
    }

    @Test func test_createSearchResults_includesCPUInSubtitle() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()
        let results = ProcessSearchService.shared.createSearchResults(from: processes)

        for result in results {
            #expect(result.subtitle.contains("%"), "Subtitle should contain CPU percentage")
        }
    }

    @Test func test_createSearchResults_hasCorrectCategory() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()
        let results = ProcessSearchService.shared.createSearchResults(from: processes)

        for result in results {
            #expect(result.category == SearchResultCategory.process, "Category should be .process")
        }
    }
}

@MainActor
final class ProcessNoResultsTests {
    @Test func test_noMatchingProcessesMessage() {
        let message = ProcessSearchService.noResultsMessage

        #expect(!message.isEmpty, "No results message should not be empty")
        #expect(message.lowercased().contains("no"), "Message should indicate no results")
        #expect(message.lowercased().contains("process"), "Message should mention processes")
    }
}

@MainActor
final class ProcessForceQuitTests {
    @Test func test_forceQuitProcess_canTerminateProcess() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sleep")
        task.arguments = ["10"]
        
        do {
            try task.run()
            let pid = task.processIdentifier
            
            #expect(pid > 0, "Process should have valid PID")
            
            let success = ProcessSearchService.forceQuitProcess(pid: pid)
            #expect(success, "Force quit should succeed for user process")
            
            Thread.sleep(forTimeInterval: 0.2)
            
            let result = kill(pid, 0)
            #expect(result != 0, "Process should be terminated after force quit")
        } catch {
            Issue.record("Failed to create test process: \(error)")
        }
    }
    
    @Test func test_forceQuitProcess_returnsFalseForInvalidPID() {
        let invalidPID: pid_t = 999999
        
        let success = ProcessSearchService.forceQuitProcess(pid: invalidPID)
        #expect(!success, "Force quit should fail for non-existent PID")
    }

    @Test func test_isSystemProcess_identifiesKernelProcesses() {
        let isSystem = ProcessSearchService.isSystemProcess(name: "kernel_task", pid: 0)
        #expect(isSystem, "kernel_task should be identified as system process")
    }
    
    @Test func test_isSystemProcess_identifiesWindowServer() {
        let isSystem = ProcessSearchService.isSystemProcess(name: "WindowServer", pid: 87)
        #expect(isSystem, "WindowServer should be identified as system process")
    }
    
    @Test func test_isSystemProcess_allowsUserApps() {
        let isSystem = ProcessSearchService.isSystemProcess(name: "Safari", pid: 12345)
        #expect(!isSystem, "Safari should NOT be identified as system process")
    }

    @Test func test_createSearchResults_hasRevealActionForForceQuit() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()
        
        guard let userApp = processes.first(where: { $0.isUserApp }) else {
            Issue.record("No user app processes found for testing")
            return
        }
        
        let results = ProcessSearchService.shared.createSearchResults(from: [userApp])
        
        #expect(results.count == 1, "Should have one result")
        #expect(results.first?.revealAction != nil, "User app process should have revealAction for force quit")
    }
    
    @Test func test_createSearchResults_systemProcessHasRevealActionWithWarning() {
        let processes = ProcessSearchService.shared.fetchRunningProcesses()
        
        guard let systemProcess = processes.first(where: { !$0.isUserApp }) else {
            let mockSystemProcess = RunningProcess(
                name: "kernel_task",
                pid: 0,
                memoryBytes: 100_000_000,
                cpuPercent: 5.0,
                icon: nil,
                bundleIdentifier: nil,
                isUserApp: false
            )
            let results = ProcessSearchService.shared.createSearchResults(from: [mockSystemProcess])
            #expect(results.first?.revealAction != nil, "System process should also have revealAction (shows warning)")
            return
        }
        
        let results = ProcessSearchService.shared.createSearchResults(from: [systemProcess])
        #expect(results.first?.revealAction != nil, "System process should have revealAction (shows warning)")
    }
}

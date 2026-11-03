import AppKit
import Testing
@testable import ZestApp

@MainActor
final class TwoPhaseKillTests {
    @Test func test_killResult_hasExpectedCases() {
        let sigtermSent = KillResult.sigtermSent
        let sigkillSent = KillResult.sigkillSent
        let success = KillResult.success
        let failed = KillResult.failed(NSError(domain: "test", code: 1))

        switch sigtermSent {
        case .sigtermSent: #expect(true)
        default: Issue.record("Expected .sigtermSent case")
        }

        switch sigkillSent {
        case .sigkillSent: #expect(true)
        default: Issue.record("Expected .sigkillSent case")
        }

        switch success {
        case .success: #expect(true)
        default: Issue.record("Expected .success case")
        }

        switch failed {
        case .failed: #expect(true)
        default: Issue.record("Expected .failed case")
        }
    }

    @Test func test_processKillState_tracksKillAttemptsByPID() {
        let killState = ProcessKillState.shared
        let testPID: pid_t = 99991

        #expect(!killState.hasAttemptedKill(pid: testPID))

        killState.markKillAttempted(pid: testPID)
        #expect(killState.hasAttemptedKill(pid: testPID))

        killState.clearKillAttempt(pid: testPID)
        #expect(!killState.hasAttemptedKill(pid: testPID))
    }

    @Test func test_processKillState_persistsAcrossInstances() {
        let testPID: pid_t = 99992

        ProcessKillState.shared.markKillAttempted(pid: testPID)

        let sameState = ProcessKillState.shared
        #expect(sameState.hasAttemptedKill(pid: testPID))

        ProcessKillState.shared.clearKillAttempt(pid: testPID)
        #expect(!ProcessKillState.shared.hasAttemptedKill(pid: testPID))
    }

    @Test func test_processKillState_clearAllResetsAll() {
        let pid1: pid_t = 99993
        let pid2: pid_t = 99994

        ProcessKillState.shared.markKillAttempted(pid: pid1)
        ProcessKillState.shared.markKillAttempted(pid: pid2)

        ProcessKillState.shared.clearAll()

        #expect(!ProcessKillState.shared.hasAttemptedKill(pid: pid1))
        #expect(!ProcessKillState.shared.hasAttemptedKill(pid: pid2))
    }

    @Test func test_attemptKill_SIGTERMEndsProcessOnFirstCall() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sleep")
        task.arguments = ["10"]

        do {
            try task.run()
            let pid = task.processIdentifier
            #expect(pid > 0, "Process should have valid PID")

            let result = ProcessSearchService.attemptKill(pid: pid)

            switch result {
            case .success:
                #expect(true, "SIGTERM should end the process")
            default:
                Issue.record("Expected .success, got \(result)")
            }

            #expect(!ProcessKillState.shared.hasAttemptedKill(pid: pid))

            ProcessKillState.shared.clearKillAttempt(pid: pid)
        } catch {
            Issue.record("Failed to create test process: \(error)")
        }
    }

    @Test func test_attemptKill_SIGKILLEndsProcessOnSecondCall() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sleep")
        task.arguments = ["10"]

        do {
            try task.run()
            let pid = task.processIdentifier
            #expect(pid > 0, "Process should have valid PID")

            ProcessKillState.shared.markKillAttempted(pid: pid)

            let result = ProcessSearchService.attemptKill(pid: pid)

            switch result {
            case .success:
                #expect(true, "SIGKILL should end the process")
            default:
                Issue.record("Expected .success, got \(result)")
            }

            Thread.sleep(forTimeInterval: 0.2)
            let checkResult = kill(pid, 0)
            #expect(checkResult != 0, "Process should be terminated after SIGKILL")

            ProcessKillState.shared.clearKillAttempt(pid: pid)
        } catch {
            Issue.record("Failed to create test process: \(error)")
        }
    }

    @Test func test_attemptKill_returnsFailedForInvalidPID() {
        let invalidPID: pid_t = 999999

        let result = ProcessSearchService.attemptKill(pid: invalidPID)

        switch result {
        case .failed:
            #expect(true, "Invalid PID should return .failed")
        default:
            Issue.record("Expected .failed for invalid PID, got \(result)")
        }
    }

    @Test func test_runningProcess_hasAttemptedKillProperty() {
        let process = RunningProcess(
            name: "Test",
            pid: 123,
            memoryBytes: 100_000_000,
            cpuPercent: 5.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false,
            attemptedKill: true
        )

        #expect(process.attemptedKill, "RunningProcess should track attemptedKill state")
    }

    @Test func test_runningProcess_attemptedKillDefaultsToFalse() {
        let process = RunningProcess(
            name: "Test",
            pid: 123,
            memoryBytes: 100_000_000,
            cpuPercent: 5.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        #expect(!process.attemptedKill, "attemptedKill should default to false")
    }

    @Test func test_searchResult_hasIsKillAttemptedProperty() {
        let result = SearchResult(
            title: "Test Process",
            subtitle: "PID: 123",
            icon: nil,
            category: .process,
            action: {},
            revealAction: {},
            isKillAttempted: true
        )

        #expect(result.isKillAttempted, "SearchResult should track isKillAttempted state")
    }

    @Test func test_searchResult_isKillAttemptedDefaultsToFalse() {
        let result = SearchResult(
            title: "Test",
            subtitle: "Test",
            icon: nil,
            category: .action,
            action: {}
        )

        #expect(!result.isKillAttempted, "isKillAttempted should default to false")
    }

    @Test func test_createSearchResults_includesKillState() {
        let killState = ProcessKillState.shared
        let testPID: pid_t = 99995

        killState.markKillAttempted(pid: testPID)

        let process = RunningProcess(
            name: "TestProcess",
            pid: testPID,
            memoryBytes: 100_000_000,
            cpuPercent: 5.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        let results = ProcessSearchService.shared.createSearchResults(from: [process])

        #expect(results.count == 1)
        #expect(results.first!.isKillAttempted, "SearchResult should reflect kill state from ProcessKillState")

        killState.clearKillAttempt(pid: testPID)
    }

    @Test func test_attemptKillWithConfirmation_systemProcessStillShowsWarning() {
        let systemProcess = RunningProcess(
            name: "kernel_task",
            pid: 0,
            memoryBytes: 100_000_000,
            cpuPercent: 5.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        #expect(ProcessSearchService.isSystemProcess(name: systemProcess.name, pid: systemProcess.pid), "kernel_task should be identified as system process")
    }

    @Test func test_attemptKillWithConfirmation_userAppSkipsWarning() {
        let userProcess = RunningProcess(
            name: "Safari",
            pid: 12345,
            memoryBytes: 500_000_000,
            cpuPercent: 10.0,
            icon: nil,
            bundleIdentifier: "com.apple.Safari",
            isUserApp: true
        )

        #expect(!ProcessSearchService.isSystemProcess(name: userProcess.name, pid: userProcess.pid), "Safari should NOT be identified as system process")
    }
}

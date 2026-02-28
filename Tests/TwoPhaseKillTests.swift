import XCTest
@testable import ZestApp

/// Tests for Story 22 - Two-Phase Process Kill System
/// Phase 1: SIGTERM (polite quit), Phase 2: SIGKILL (force quit)
final class TwoPhaseKillTests: XCTestCase {

    // MARK: - KillResult Enum Tests

    func test_killResult_hasExpectedCases() {
        // Test that KillResult enum exists with expected cases
        let sigtermSent = KillResult.sigtermSent
        let sigkillSent = KillResult.sigkillSent
        let success = KillResult.success
        let failed = KillResult.failed(NSError(domain: "test", code: 1))

        switch sigtermSent {
        case .sigtermSent: XCTAssertTrue(true)
        default: XCTFail("Expected .sigtermSent case")
        }

        switch sigkillSent {
        case .sigkillSent: XCTAssertTrue(true)
        default: XCTFail("Expected .sigkillSent case")
        }

        switch success {
        case .success: XCTAssertTrue(true)
        default: XCTFail("Expected .success case")
        }

        switch failed {
        case .failed: XCTAssertTrue(true)
        default: XCTFail("Expected .failed case")
        }
    }

    // MARK: - ProcessKillState Tests

    func test_processKillState_tracksKillAttemptsByPID() {
        let killState = ProcessKillState.shared
        let testPID: pid_t = 99991

        // Initially, no kill attempt should be recorded
        XCTAssertFalse(killState.hasAttemptedKill(pid: testPID))

        // Mark as attempted
        killState.markKillAttempted(pid: testPID)
        XCTAssertTrue(killState.hasAttemptedKill(pid: testPID))

        // Clean up
        killState.clearKillAttempt(pid: testPID)
        XCTAssertFalse(killState.hasAttemptedKill(pid: testPID))
    }

    func test_processKillState_persistsAcrossInstances() {
        let testPID: pid_t = 99992

        // Mark via shared instance
        ProcessKillState.shared.markKillAttempted(pid: testPID)

        // Create new reference to shared instance
        let sameState = ProcessKillState.shared
        XCTAssertTrue(sameState.hasAttemptedKill(pid: testPID))

        // Clean up
        ProcessKillState.shared.clearKillAttempt(pid: testPID)
        XCTAssertFalse(ProcessKillState.shared.hasAttemptedKill(pid: testPID))
    }

    func test_processKillState_clearAllResetsAll() {
        let pid1: pid_t = 99993
        let pid2: pid_t = 99994

        ProcessKillState.shared.markKillAttempted(pid: pid1)
        ProcessKillState.shared.markKillAttempted(pid: pid2)

        ProcessKillState.shared.clearAll()

        XCTAssertFalse(ProcessKillState.shared.hasAttemptedKill(pid: pid1))
        XCTAssertFalse(ProcessKillState.shared.hasAttemptedKill(pid: pid2))
    }

    // MARK: - Two-Phase Kill Logic Tests

    func test_attemptKill_sendsSIGTERMOnFirstCall() {
        // Create a test process we can terminate
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sleep")
        task.arguments = ["10"]

        do {
            try task.run()
            let pid = task.processIdentifier
            XCTAssertGreaterThan(pid, 0, "Process should have valid PID")

            // First call should send SIGTERM
            let result = ProcessSearchService.attemptKill(pid: pid)

            switch result {
            case .sigtermSent:
                XCTAssertTrue(true, "First kill attempt should return .sigtermSent")
            default:
                XCTFail("Expected .sigtermSent, got \(result)")
            }

            // Mark should be recorded
            XCTAssertTrue(ProcessKillState.shared.hasAttemptedKill(pid: pid))

            // Clean up
            ProcessKillState.shared.clearKillAttempt(pid: pid)

        } catch {
            XCTFail("Failed to create test process: \(error)")
        }
    }

    func test_attemptKill_sendsSIGKILLOnSecondCall() {
        // Create a test process we can terminate
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sleep")
        task.arguments = ["10"]

        do {
            try task.run()
            let pid = task.processIdentifier
            XCTAssertGreaterThan(pid, 0, "Process should have valid PID")

            // Mark as already attempted (simulating first call was made)
            ProcessKillState.shared.markKillAttempted(pid: pid)

            // Second call should send SIGKILL
            let result = ProcessSearchService.attemptKill(pid: pid)

            switch result {
            case .sigkillSent:
                XCTAssertTrue(true, "Second kill attempt should return .sigkillSent")
            default:
                XCTFail("Expected .sigkillSent, got \(result)")
            }

            // Process should be gone after SIGKILL
            Thread.sleep(forTimeInterval: 0.2)
            let checkResult = kill(pid, 0)
            XCTAssertNotEqual(checkResult, 0, "Process should be terminated after SIGKILL")

            // Clean up state
            ProcessKillState.shared.clearKillAttempt(pid: pid)

        } catch {
            XCTFail("Failed to create test process: \(error)")
        }
    }

    func test_attemptKill_returnsFailedForInvalidPID() {
        let invalidPID: pid_t = 999999

        let result = ProcessSearchService.attemptKill(pid: invalidPID)

        switch result {
        case .failed:
            XCTAssertTrue(true, "Invalid PID should return .failed")
        default:
            XCTFail("Expected .failed for invalid PID, got \(result)")
        }
    }

    // MARK: - RunningProcess attemptedKill Flag Tests

    func test_runningProcess_hasAttemptedKillProperty() {
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

        XCTAssertTrue(process.attemptedKill, "RunningProcess should track attemptedKill state")
    }

    func test_runningProcess_attemptedKillDefaultsToFalse() {
        let process = RunningProcess(
            name: "Test",
            pid: 123,
            memoryBytes: 100_000_000,
            cpuPercent: 5.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        XCTAssertFalse(process.attemptedKill, "attemptedKill should default to false")
    }

    // MARK: - SearchResult isKillAttempted Tests

    func test_searchResult_hasIsKillAttemptedProperty() {
        // Create a SearchResult with kill attempted state
        let result = SearchResult(
            title: "Test Process",
            subtitle: "PID: 123",
            icon: nil,
            category: .process,
            action: {},
            revealAction: {},
            isKillAttempted: true
        )

        XCTAssertTrue(result.isKillAttempted, "SearchResult should track isKillAttempted state")
    }

    func test_searchResult_isKillAttemptedDefaultsToFalse() {
        let result = SearchResult(
            title: "Test",
            subtitle: "Test",
            icon: nil,
            category: .action,
            action: {}
        )

        XCTAssertFalse(result.isKillAttempted, "isKillAttempted should default to false")
    }

    // MARK: - Integration: createSearchResults includes kill state

    func test_createSearchResults_includesKillState() {
        let killState = ProcessKillState.shared
        let testPID: pid_t = 99995

        // Mark a PID as kill attempted
        killState.markKillAttempted(pid: testPID)

        // Create a RunningProcess with that PID
        let process = RunningProcess(
            name: "TestProcess",
            pid: testPID,
            memoryBytes: 100_000_000,
            cpuPercent: 5.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        // Create search results
        let results = ProcessSearchService.shared.createSearchResults(from: [process])

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first!.isKillAttempted, "SearchResult should reflect kill state from ProcessKillState")

        // Clean up
        killState.clearKillAttempt(pid: testPID)
    }

    // MARK: - Two-Phase Force Quit with Confirmation Tests

    func test_attemptKillWithConfirmation_systemProcessStillShowsWarning() {
        // Create a mock system process
        let systemProcess = RunningProcess(
            name: "kernel_task",
            pid: 0,
            memoryBytes: 100_000_000,
            cpuPercent: 5.0,
            icon: nil,
            bundleIdentifier: nil,
            isUserApp: false
        )

        // System processes should still require confirmation
        XCTAssertTrue(
            ProcessSearchService.isSystemProcess(name: systemProcess.name, pid: systemProcess.pid),
            "kernel_task should be identified as system process"
        )
    }

    func test_attemptKillWithConfirmation_userAppSkipsWarning() {
        // User apps should NOT require confirmation for first kill
        let userProcess = RunningProcess(
            name: "Safari",
            pid: 12345,
            memoryBytes: 500_000_000,
            cpuPercent: 10.0,
            icon: nil,
            bundleIdentifier: "com.apple.Safari",
            isUserApp: true
        )

        XCTAssertFalse(
            ProcessSearchService.isSystemProcess(name: userProcess.name, pid: userProcess.pid),
            "Safari should NOT be identified as system process"
        )
    }
}

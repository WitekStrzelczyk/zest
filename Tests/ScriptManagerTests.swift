import XCTest
@testable import ZestApp

// MARK: - ScriptManager Tests

final class ScriptManagerTests: XCTestCase {

    // MARK: - Test Data

    private var testScriptPath: URL!
    private var testAppleScriptPath: URL!

    override func setUp() {
        super.setUp()
        // Create temporary test scripts
        testScriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("test_script_\(UUID().uuidString).sh")
        testAppleScriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("test_script_\(UUID().uuidString).scpt")

        // Create a simple test script
        let scriptContent = "#!/bin/bash\necho \"Hello, World!\"\n"
        try? scriptContent.write(to: testScriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: testScriptPath.path)

        // Create a simple AppleScript
        let appleScriptContent = "return \"Hello from AppleScript\""
        try? appleScriptContent.write(to: testAppleScriptPath, atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testScriptPath)
        try? FileManager.default.removeItem(at: testAppleScriptPath)
        super.tearDown()
    }

    // MARK: - Script Execution Tests

    func test_script_manager_executes_shell_script() {
        // Given
        let manager = ScriptManager.shared

        // When
        let expectation = XCTestExpectation(description: "Script execution completes")
        var executionResult: ScriptExecutionResult?

        manager.executeScript(at: testScriptPath.path) { result in
            executionResult = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        // Then
        XCTAssertNotNil(executionResult, "Script execution should return a result")
        XCTAssertTrue(executionResult?.output.contains("Hello, World!") == true,
                     "Script output should contain 'Hello, World!'")
    }

    func test_script_manager_handles_exit_code() {
        // Given
        let manager = ScriptManager.shared
        let failureScriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("test_fail.sh")
        try? "exit 1".write(to: failureScriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: failureScriptPath.path)

        // When
        let expectation = XCTestExpectation(description: "Script execution completes")
        var executionResult: ScriptExecutionResult?

        manager.executeScript(at: failureScriptPath.path) { result in
            executionResult = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        // Then
        XCTAssertNotNil(executionResult, "Script execution should return a result")
        XCTAssertEqual(executionResult?.exitCode, 1, "Failed script should return exit code 1")

        // Cleanup
        try? FileManager.default.removeItem(at: failureScriptPath)
    }

    // MARK: - Script Termination Tests

    func test_script_manager_terminates_running_script() {
        // Given
        let manager = ScriptManager.shared
        let longRunningScriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("test_long_running.sh")
        // Create a script that runs for 30 seconds
        try? "sleep 30".write(to: longRunningScriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: longRunningScriptPath.path)

        // First, ensure no script is running
        XCTAssertFalse(manager.isScriptRunning, "No script should be running initially")

        // When - start a long-running script and wait for callback
        let expectation = XCTestExpectation(description: "Script execution completes")

        manager.executeScript(at: longRunningScriptPath.path) { result in
            // Callback when script completes (or immediately if already running)
            expectation.fulfill()
        }

        // Wait for the script to actually start running
        // The callback is called after the script completes, but we need to check isScriptRunning
        // after a brief delay to allow the async block to set currentProcess
        let waitStart = Date()
        while !manager.isScriptRunning && Date().timeIntervalSince(waitStart) < 2.0 {
            Thread.sleep(forTimeInterval: 0.05)
        }

        // Then - verify the script is running
        XCTAssertTrue(manager.isScriptRunning, "Script should be running")
        XCTAssertNotNil(manager.runningProcess, "Script should have a running process")

        // When - terminate the script
        manager.terminateRunningScript()

        // Then - verify termination
        XCTAssertFalse(manager.isScriptRunning, "Script should not be running after termination")
        XCTAssertNil(manager.runningProcess, "Script should be terminated after calling terminateRunningScript")

        // Wait for the expectation to fulfill (script completed)
        wait(for: [expectation], timeout: 3.0)

        // Cleanup
        try? FileManager.default.removeItem(at: longRunningScriptPath)
    }

    // MARK: - Script Output Tests

    func test_script_manager_captures_stdout() {
        // Given
        let manager = ScriptManager.shared
        let outputScriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("test_output.sh")
        try? "echo 'stdout output'\necho 'stderr output' >&2".write(to: outputScriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputScriptPath.path)

        // When
        let expectation = XCTestExpectation(description: "Script execution completes")
        var executionResult: ScriptExecutionResult?

        manager.executeScript(at: outputScriptPath.path) { result in
            executionResult = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        // Then
        XCTAssertNotNil(executionResult, "Script execution should return a result")
        XCTAssertTrue(executionResult?.output.contains("stdout output") == true,
                     "Script output should contain stdout")
        XCTAssertTrue(executionResult?.errorOutput.contains("stderr output") == true,
                     "Script error output should contain stderr")

        // Cleanup
        try? FileManager.default.removeItem(at: outputScriptPath)
    }

    // MARK: - Error Display Tests

    func test_script_manager_detects_error_exit_code() {
        // Given
        let manager = ScriptManager.shared
        let errorScriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("test_error.sh")
        try? "echo 'Error occurred'\nexit 42".write(to: errorScriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: errorScriptPath.path)

        // When
        let expectation = XCTestExpectation(description: "Script execution completes")
        var executionResult: ScriptExecutionResult?

        manager.executeScript(at: errorScriptPath.path) { result in
            executionResult = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        // Then
        XCTAssertNotNil(executionResult, "Script execution should return a result")
        XCTAssertTrue(executionResult?.hasError == true, "Script with non-zero exit should be flagged as error")
        XCTAssertEqual(executionResult?.exitCode, 42, "Exit code should be 42")

        // Cleanup
        try? FileManager.default.removeItem(at: errorScriptPath)
    }

    // MARK: - Script Type Detection Tests

    func test_script_manager_detects_shell_script() {
        // Given
        let manager = ScriptManager.shared

        // When
        let scriptType = manager.scriptType(for: testScriptPath.path)

        // Then
        XCTAssertEqual(scriptType, .shell, "Should detect shell script")
    }

    func test_script_manager_detects_apple_script() {
        // Given
        let manager = ScriptManager.shared

        // When
        let scriptType = manager.scriptType(for: testAppleScriptPath.path)

        // Then
        XCTAssertEqual(scriptType, .appleScript, "Should detect AppleScript")
    }

    func test_script_manager_detects_python_script() {
        // Given
        let manager = ScriptManager.shared
        let pythonPath = FileManager.default.temporaryDirectory.appendingPathComponent("test_script.py")
        try? "print('hello')".write(to: pythonPath, atomically: true, encoding: .utf8)

        // When
        let scriptType = manager.scriptType(for: pythonPath.path)

        // Then
        XCTAssertEqual(scriptType, .python, "Should detect Python script")

        // Cleanup
        try? FileManager.default.removeItem(at: pythonPath)
    }

    // MARK: - Concurrent Script Prevention Tests

    func test_script_manager_prevents_concurrent_scripts() {
        // Given
        let manager = ScriptManager.shared

        // Create two scripts
        let script1Path = FileManager.default.temporaryDirectory.appendingPathComponent("test_concurrent1.sh")
        let script2Path = FileManager.default.temporaryDirectory.appendingPathComponent("test_concurrent2.sh")
        try? "sleep 2".write(to: script1Path, atomically: true, encoding: .utf8)
        try? "echo 'second'".write(to: script2Path, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script1Path.path)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script2Path.path)

        // When - start first script
        manager.executeScript(at: script1Path.path) { _ in }

        // Then - wait for first script to start
        let startTime = Date()
        var scriptStarted = false
        while !scriptStarted && Date().timeIntervalSince(startTime) < 5.0 {
            if manager.isScriptRunning {
                scriptStarted = true
                break
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        XCTAssertTrue(scriptStarted, "First script should be running")
        XCTAssertNotNil(manager.runningProcess, "First script should have a running process")

        // When - try to start second script while first is running
        let expectation2 = XCTestExpectation(description: "Second script blocked")
        var secondScriptBlocked = false
        manager.executeScript(at: script2Path.path) { result in
            secondScriptBlocked = result.blocked
            expectation2.fulfill()
        }

        wait(for: [expectation2], timeout: 5)

        // Then - second script should be blocked
        XCTAssertTrue(secondScriptBlocked, "Second script should be blocked while first is running")

        // Cleanup
        manager.terminateRunningScript()
        try? FileManager.default.removeItem(at: script1Path)
        try? FileManager.default.removeItem(at: script2Path)
    }
}

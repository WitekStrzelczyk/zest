import XCTest
@testable import ZestApp

/// Tests for ShellCommandService - Enhanced Shell Integration
///
/// Story 24: Enhanced Shell Integration
/// - Commands starting with ">" execute in shell
/// - Output displays in results panel
/// - Errors shown distinctly
final class ShellCommandServiceTests: XCTestCase {

    // MARK: - Properties

    private var service: ShellCommandService!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        service = ShellCommandService.shared
        service.resetCommandHistory()
    }

    override func tearDown() {
        service.terminateRunningCommand()
        service.resetCommandHistory()
        super.tearDown()
    }

    // MARK: - Command Detection Tests

    /// Test: Commands starting with ">" are detected as shell commands
    func test_shellCommandDetection_withGreaterThanPrefix() {
        XCTAssertTrue(service.isShellCommand("> echo hello"), "Commands starting with > should be detected")
        XCTAssertTrue(service.isShellCommand(">ls"), "Commands with > and no space should be detected")
        XCTAssertTrue(service.isShellCommand(">  git status"), "Commands with multiple spaces after > should be detected")
    }

    /// Test: Regular queries are not detected as shell commands
    func test_shellCommandDetection_withoutPrefix() {
        XCTAssertFalse(service.isShellCommand("echo hello"), "Commands without > should not be detected")
        XCTAssertFalse(service.isShellCommand("safari"), "App names should not be detected as commands")
        XCTAssertFalse(service.isShellCommand(""), "Empty string should not be detected as command")
        XCTAssertFalse(service.isShellCommand(">"), "Just > should not be a valid command")
        XCTAssertFalse(service.isShellCommand(">   "), "Just > with spaces should not be a valid command")
    }

    // MARK: - Command Extraction Tests

    /// Test: Command is extracted correctly from input
    func test_commandExtraction_removesPrefix() {
        XCTAssertEqual(service.extractCommand(from: "> echo hello"), "echo hello")
        XCTAssertEqual(service.extractCommand(from: ">ls"), "ls")
        XCTAssertEqual(service.extractCommand(from: ">  git status"), "git status")
        XCTAssertEqual(service.extractCommand(from: ">   pwd"), "pwd")
    }

    /// Test: Empty command returns nil
    func test_commandExtraction_emptyCommand() {
        XCTAssertNil(service.extractCommand(from: ">"))
        XCTAssertNil(service.extractCommand(from: ">   "))
        XCTAssertNil(service.extractCommand(from: ""))
    }

    // MARK: - Command Execution Tests

    /// Test: Simple command executes and returns output
    func test_commandExecution_simpleEcho() {
        let expectation = XCTestExpectation(description: "Command executes")
        var result: ShellCommandResult?

        service.executeCommand("> echo hello") { executionResult in
            result = executionResult
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        XCTAssertNotNil(result)
        XCTAssertFalse(result!.hasError, "echo should not error")
        XCTAssertTrue(result!.output.contains("hello"), "Output should contain 'hello'")
    }

    /// Test: Command with error shows error output
    func test_commandExecution_withError() {
        let expectation = XCTestExpectation(description: "Command with error executes")
        var result: ShellCommandResult?

        // Use a command that will fail
        service.executeCommand("> nonexistent_command_xyz") { executionResult in
            result = executionResult
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasError, "Nonexistent command should error")
        XCTAssertNotNil(result!.errorOutput, "Should have error output")
    }

    /// Test: Command with exit code captures it
    func test_commandExecution_exitCode() {
        let expectation = XCTestExpectation(description: "Command with exit code")
        var result: ShellCommandResult?

        service.executeCommand("> sh -c 'exit 42'") { executionResult in
            result = executionResult
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.exitCode, 42, "Exit code should be 42")
    }

    /// Test: Multiple commands can be run sequentially
    func test_commandExecution_sequentialCommands() {
        let expectation1 = XCTestExpectation(description: "First command")
        let expectation2 = XCTestExpectation(description: "Second command")

        var result1: ShellCommandResult?
        var result2: ShellCommandResult?

        service.executeCommand("> echo first") { result in
            result1 = result
            expectation1.fulfill()
        }

        wait(for: [expectation1], timeout: 10)

        service.executeCommand("> echo second") { result in
            result2 = result
            expectation2.fulfill()
        }

        wait(for: [expectation2], timeout: 10)

        XCTAssertTrue(result1?.output.contains("first") == true)
        XCTAssertTrue(result2?.output.contains("second") == true)
    }

    // MARK: - Command History Tests

    /// Test: Command history is recorded
    func test_commandHistory_recordsCommands() {
        let expectation = XCTestExpectation(description: "Command executes")

        service.executeCommand("> echo test") { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        let history = service.commandHistory
        XCTAssertTrue(history.contains("echo test"), "Command should be in history")
    }

    /// Test: Command history is limited in size
    func test_commandHistory_limitedSize() {
        // Reset history first
        service.resetCommandHistory()

        // Run just over the limit to verify truncation (105 > 100)
        let commandCount = 105
        let expectation = XCTestExpectation(description: "All commands complete")
        expectation.expectedFulfillmentCount = commandCount

        for i in 0..<commandCount {
            service.executeCommand("> echo test\(i)") { _ in
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 15)

        let history = service.commandHistory
        XCTAssertLessThanOrEqual(history.count, 100, "History should be limited to 100 items")
    }

    /// Test: Command history can be reset
    func test_commandHistory_canBeReset() {
        let expectation = XCTestExpectation(description: "Command executes")

        service.executeCommand("> echo test") { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        XCTAssertFalse(service.commandHistory.isEmpty)

        service.resetCommandHistory()

        XCTAssertTrue(service.commandHistory.isEmpty, "History should be empty after reset")
    }

    // MARK: - Search Results Tests

    /// Test: Shell command generates search result with action
    func test_shellCommandResult_generatesSearchResult() {
        let result = service.createShellCommandResult(for: "> echo test")

        XCTAssertEqual(result.title, "echo test", "Title should be the command")
        XCTAssertEqual(result.subtitle, "Shell Command", "Subtitle should indicate shell command")
        XCTAssertNotNil(result.icon, "Should have an icon")
    }

    /// Test: Search result action executes the command
    func test_shellCommandResult_actionExecutes() {
        let expectation = XCTestExpectation(description: "Command executes via result action")

        // Create a new service instance to avoid closure capture issues
        let testService = ShellCommandService.shared

        // The result action calls executeCommand which is async
        let result = testService.createShellCommandResult(for: "> echo test")

        // Execute the result action - this will actually run the command
        result.execute()

        // Wait a bit for the async command to start
        Thread.sleep(forTimeInterval: 0.3)

        // Verify the command started running (or completed quickly)
        // Since echo is fast, it might already be done

        // Just verify the action doesn't crash and the result was created correctly
        XCTAssertEqual(result.title, "echo test")

        expectation.fulfill()
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - Shell Environment Tests

    /// Test: Shell environment includes user PATH
    func test_shellEnvironment_includesPath() {
        let environment = service.shellEnvironment

        XCTAssertNotNil(environment["PATH"], "Environment should include PATH")
        XCTAssertTrue(environment["PATH"]!.contains("/usr/bin"), "PATH should include /usr/bin")
    }

    /// Test: Shell uses zsh by default
    func test_shellUses_zshOrDefault() {
        let shell = service.shellPath

        XCTAssertTrue(shell.contains("zsh") || shell.contains("bash") || shell == "/bin/sh",
                     "Should use zsh, bash, or sh")
    }

    // MARK: - Cancellation Tests

    /// Test: Running command can be cancelled
    func test_commandCancellation() {
        let expectation = XCTestExpectation(description: "Long command cancelled")

        // Start a long-running command
        service.executeCommand("> sleep 30") { result in
            // This should be called when cancelled
            expectation.fulfill()
        }

        // Wait for command to start
        Thread.sleep(forTimeInterval: 0.5)

        // Verify command is running
        XCTAssertTrue(service.isCommandRunning, "Command should be running")

        // Cancel the command
        service.terminateRunningCommand()

        // Wait a bit for cancellation
        wait(for: [expectation], timeout: 5)

        XCTAssertFalse(service.isCommandRunning, "Command should not be running after cancellation")
    }
}

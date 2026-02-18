import AppKit
import Foundation
import os.log

// MARK: - Shell Command Result

/// Result of executing a shell command
struct ShellCommandResult {
    let output: String
    let errorOutput: String
    let exitCode: Int32
    let hasError: Bool

    init(output: String, errorOutput: String, exitCode: Int32) {
        self.output = output
        self.errorOutput = errorOutput
        self.exitCode = exitCode
        hasError = exitCode != 0
    }
}

// MARK: - Shell Command Service

/// Service for executing shell commands from the command palette
///
/// ## Usage
/// Commands starting with ">" are treated as shell commands:
/// - `> ls -la` - List files
/// - `> git status` - Show git status
/// - `> echo hello` - Print hello
///
/// ## Features
/// - Command history (last 100 commands)
/// - Uses user's shell (zsh/bash)
/// - Captures stdout and stderr separately
/// - Can be cancelled mid-execution
///
/// Story 24: Enhanced Shell Integration
final class ShellCommandService {
    /// Shared singleton instance
    static let shared: ShellCommandService = .init()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.zestapp.Zest", category: "ShellCommand")
    private var currentProcess: Process?
    private let processQueue = DispatchQueue(label: "com.zestapp.shellcommand.process", qos: .userInitiated)
    private let stateLock = NSLock()

    /// Command history (most recent first)
    private var _commandHistory: [String] = []
    private let historyLock = NSLock()

    /// Maximum number of commands to keep in history
    private let maxHistorySize = 100

    /// Command prefix for shell commands
    private let commandPrefix = ">"

    /// Execute command closure (for testing/mocking)
    var executeCommand: (String, ((ShellCommandResult) -> Void)?) -> Void = { _, _ in }

    // MARK: - Initialization

    private init() {
        // Set up default execute implementation
        executeCommand = { [weak self] input, completion in
            self?._executeCommandInternal(input, completion: completion)
        }
    }

    // MARK: - Public API

    /// Whether a command is currently running
    var isCommandRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return currentProcess != nil && currentProcess!.isRunning
    }

    /// Command history (read-only)
    var commandHistory: [String] {
        historyLock.lock()
        defer { historyLock.unlock() }
        return _commandHistory
    }

    /// Shell environment variables
    var shellEnvironment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        // Add common paths
        let existingPath = env["PATH"] ?? ""
        if !existingPath.contains("/usr/local/bin") {
            env["PATH"] = "/usr/local/bin:" + existingPath
        }
        return env
    }

    /// Path to the shell executable
    var shellPath: String {
        // Check for user's preferred shell
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            return shell
        }
        // Default to zsh, then bash
        if FileManager.default.isExecutableFile(atPath: "/bin/zsh") {
            return "/bin/zsh"
        }
        return "/bin/bash"
    }

    // MARK: - Command Detection

    /// Check if a query is a shell command (starts with ">")
    func isShellCommand(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(commandPrefix) else { return false }

        // Extract the command part
        let withoutPrefix = String(trimmed.dropFirst())
        let command = withoutPrefix.trimmingCharacters(in: .whitespaces)

        // Must have actual command content
        return !command.isEmpty
    }

    /// Extract the shell command from input (removes ">" prefix)
    func extractCommand(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(commandPrefix) else { return nil }

        let withoutPrefix = String(trimmed.dropFirst())
        let command = withoutPrefix.trimmingCharacters(in: .whitespaces)

        return command.isEmpty ? nil : command
    }

    // MARK: - Command Execution

    /// Execute a shell command
    /// - Parameters:
    ///   - input: Full input string (including ">" prefix)
    ///   - completion: Callback with the result
    func executeCommand(_ input: String, completion: ((ShellCommandResult) -> Void)?) {
        _executeCommandInternal(input, completion: completion)
    }

    private func _executeCommandInternal(_ input: String, completion: ((ShellCommandResult) -> Void)?) {
        guard let command = extractCommand(from: input) else {
            completion?(ShellCommandResult(output: "", errorOutput: "Invalid command", exitCode: -1))
            return
        }

        // Add to history
        addToHistory(command)

        processQueue.async { [weak self] in
            guard let self else { return }

            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            stateLock.lock()
            currentProcess = process
            stateLock.unlock()

            // Configure process to use shell
            process.executableURL = URL(fileURLWithPath: shellPath)
            process.arguments = ["-l", "-c", command]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.environment = shellEnvironment

            logger.info("Executing shell command: \(command)")

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                let result = ShellCommandResult(
                    output: output,
                    errorOutput: errorOutput,
                    exitCode: process.terminationStatus
                )

                stateLock.lock()
                currentProcess = nil
                stateLock.unlock()

                logger.info("Command completed with exit code: \(process.terminationStatus)")

                DispatchQueue.main.async {
                    completion?(result)
                }
            } catch {
                logger.error("Failed to execute command: \(error.localizedDescription)")

                stateLock.lock()
                currentProcess = nil
                stateLock.unlock()

                let result = ShellCommandResult(
                    output: "",
                    errorOutput: error.localizedDescription,
                    exitCode: -1
                )

                DispatchQueue.main.async {
                    completion?(result)
                }
            }
        }
    }

    // MARK: - Search Result Creation

    /// Create a SearchResult for a shell command
    func createShellCommandResult(for input: String) -> SearchResult {
        let command = extractCommand(from: input) ?? input

        return SearchResult(
            title: command,
            subtitle: "Shell Command",
            icon: NSImage(systemSymbolName: "terminal", accessibilityDescription: "Shell Command"),
            action: { [weak self] in
                self?.executeCommand(input, completion: nil)
            }
        )
    }

    // MARK: - Command History

    /// Add command to history
    private func addToHistory(_ command: String) {
        historyLock.lock()
        defer { historyLock.unlock() }

        // Don't add duplicates consecutively
        if _commandHistory.first == command {
            return
        }

        _commandHistory.insert(command, at: 0)

        // Trim to max size
        if _commandHistory.count > maxHistorySize {
            _commandHistory = Array(_commandHistory.prefix(maxHistorySize))
        }
    }

    /// Reset command history
    func resetCommandHistory() {
        historyLock.lock()
        defer { historyLock.unlock() }
        _commandHistory.removeAll()
    }

    // MARK: - Cancellation

    /// Terminate the currently running command
    func terminateRunningCommand() {
        stateLock.lock()
        guard let process = currentProcess, process.isRunning else {
            stateLock.unlock()
            return
        }
        stateLock.unlock()

        logger.info("Terminating running command")
        process.terminate()

        stateLock.lock()
        currentProcess = nil
        stateLock.unlock()
    }
}

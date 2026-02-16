import AppKit
import Foundation
import os.log

// MARK: - Script Type

enum ScriptType: String {
    case shell
    case appleScript
    case python
    case ruby
    case unknown
}

// MARK: - Script Execution Result

struct ScriptExecutionResult {
    let output: String
    let errorOutput: String
    let exitCode: Int32
    let hasError: Bool
    let blocked: Bool

    init(output: String, errorOutput: String, exitCode: Int32, blocked: Bool = false) {
        self.output = output
        self.errorOutput = errorOutput
        self.exitCode = exitCode
        hasError = exitCode != 0
        self.blocked = blocked
    }

    /// For blocked scripts
    static func blocked() -> ScriptExecutionResult {
        ScriptExecutionResult(output: "", errorOutput: "", exitCode: -1, blocked: true)
    }
}

// MARK: - Script Manager

final class ScriptManager {
    static let shared: ScriptManager = {
        let instance = ScriptManager()
        return instance
    }()

    private let logger = Logger(subsystem: "com.zestapp.Zest", category: "ScriptManager")
    private var currentProcess: Process?
    private let processQueue = DispatchQueue(label: "com.zestapp.scriptmanager.process", qos: .userInitiated)
    private let stateLock = NSLock()

    private init() {}

    // MARK: - Public API

    /// Returns whether a script is currently running
    var isScriptRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return currentProcess != nil
    }

    /// Returns the currently running process, if any
    var runningProcess: Process? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return currentProcess
    }

    /// Detects the type of script based on file extension
    func scriptType(for path: String) -> ScriptType {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "sh", "bash", "zsh":
            return .shell
        case "scpt", "applescript":
            return .appleScript
        case "py":
            return .python
        case "rb":
            return .ruby
        default:
            // Check shebang if no extension matches
            if let shebang = try? String(contentsOfFile: path, encoding: .utf8).split(separator: "\n").first,
               shebang.hasPrefix("#!")
            {
                if shebang.contains("python") {
                    return .python
                } else if shebang.contains("ruby") {
                    return .ruby
                } else if shebang.contains("bash") || shebang.contains("sh") {
                    return .shell
                }
            }
            return .unknown
        }
    }

    /// Executes a script at the given path
    func executeScript(at path: String, completion: @escaping (ScriptExecutionResult) -> Void) {
        // Check if a script is already running (thread-safe check)
        stateLock.lock()
        let alreadyRunning = currentProcess != nil
        stateLock.unlock()

        if alreadyRunning {
            logger.info("Script already running, blocking new execution")
            DispatchQueue.main.async {
                completion(ScriptExecutionResult.blocked())
            }
            return
        }

        processQueue.async { [weak self] in
            guard let self else { return }

            let scriptType = scriptType(for: path)
            let process = Process()

            stateLock.lock()
            currentProcess = process
            stateLock.unlock()

            // Configure output pipes
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Configure process based on script type
            switch scriptType {
            case .shell:
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [path]
            case .appleScript:
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = [path]
            case .python:
                process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                process.arguments = [path]
            case .ruby:
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
                process.arguments = [path]
            case .unknown:
                // Default to shell
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [path]
            }

            logger.info("Executing script: \(path)")

            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = environment

            // Handle termination
            process.terminationHandler = { [weak self] proc in
                self?.logger.info("Script terminated with exit code: \(proc.terminationStatus)")
                self?.stateLock.lock()
                self?.currentProcess = nil
                self?.stateLock.unlock()
            }

            do {
                try process.run()
                process.waitUntilExit()

                // Read output
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                logger.info("Script completed with output: \(output)")

                // Clear current process
                stateLock.lock()
                currentProcess = nil
                stateLock.unlock()

                let result = ScriptExecutionResult(
                    output: output,
                    errorOutput: errorOutput,
                    exitCode: process.terminationStatus
                )

                DispatchQueue.main.async {
                    completion(result)
                }
            } catch {
                logger.error("Failed to execute script: \(error.localizedDescription)")
                stateLock.lock()
                currentProcess = nil
                stateLock.unlock()

                let result = ScriptExecutionResult(
                    output: "",
                    errorOutput: error.localizedDescription,
                    exitCode: -1
                )

                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }

    /// Terminates the currently running script
    func terminateRunningScript() {
        stateLock.lock()
        guard let process = currentProcess else {
            stateLock.unlock()
            logger.info("No script to terminate")
            return
        }
        stateLock.unlock()

        logger.info("Terminating running script")
        process.terminate()

        // Wait briefly for process to terminate
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.stateLock.lock()
            if self?.currentProcess?.isRunning == true {
                self?.currentProcess?.interrupt()
            }
            self?.stateLock.unlock()
        }

        stateLock.lock()
        currentProcess = nil
        stateLock.unlock()
    }
}

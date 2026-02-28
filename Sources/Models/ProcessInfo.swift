import AppKit
import Darwin
import Foundation
import os.log

// MARK: - Kill Result (Story 22)

/// Result of a two-phase kill attempt
enum KillResult: Equatable {
    /// SIGTERM was sent (first phase - polite quit request)
    case sigtermSent
    /// SIGKILL was sent (second phase - force quit)
    case sigkillSent
    /// Process terminated successfully
    case success
    /// Kill failed with an error
    case failed(Error)

    static func == (lhs: KillResult, rhs: KillResult) -> Bool {
        switch (lhs, rhs) {
        case (.sigtermSent, .sigtermSent): return true
        case (.sigkillSent, .sigkillSent): return true
        case (.success, .success): return true
        case (.failed, .failed): return true
        default: return false
        }
    }
}

// MARK: - Process Kill State (Story 22)

/// Singleton to track kill attempts across process list refreshes
/// Uses PID as the key since RunningProcess UUID is regenerated on each fetch
final class ProcessKillState {
    static let shared = ProcessKillState()

    private var attemptedKills: Set<pid_t> = []
    private let lock = NSLock()

    private init() {}

    /// Check if a kill attempt has been made for the given PID
    func hasAttemptedKill(pid: pid_t) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return attemptedKills.contains(pid)
    }

    /// Mark a PID as having a kill attempt
    func markKillAttempted(pid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        attemptedKills.insert(pid)
    }

    /// Clear kill attempt for a specific PID
    func clearKillAttempt(pid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        attemptedKills.remove(pid)
    }

    /// Clear all kill attempts
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        attemptedKills.removeAll()
    }
}

/// Represents a running process with its resource usage information
struct RunningProcess: Identifiable, Equatable {
    let id: UUID
    let name: String
    let pid: pid_t
    let memoryBytes: UInt64
    let cpuPercent: Double
    let icon: NSImage?
    let bundleIdentifier: String?
    let isUserApp: Bool
    /// Whether SIGTERM has been sent (two-phase kill state)
    let attemptedKill: Bool

    init(
        name: String,
        pid: pid_t,
        memoryBytes: UInt64,
        cpuPercent: Double,
        icon: NSImage?,
        bundleIdentifier: String?,
        isUserApp: Bool,
        attemptedKill: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.pid = pid
        self.memoryBytes = memoryBytes
        self.cpuPercent = cpuPercent
        self.icon = icon
        self.bundleIdentifier = bundleIdentifier
        self.isUserApp = isUserApp
        self.attemptedKill = attemptedKill
    }

    /// Formats memory in human-readable format (e.g., "256 MB", "1.2 GB")
    var memoryFormatted: String {
        let megabytes = Double(memoryBytes) / 1_000_000.0
        let gigabytes = Double(memoryBytes) / 1_000_000_000.0

        if gigabytes >= 1.0 {
            return String(format: "%.1f GB", gigabytes)
        } else {
            return String(format: "%.0f MB", megabytes)
        }
    }

    /// Formats CPU as percentage (e.g., "5%", "12.3%")
    var cpuFormatted: String {
        if cpuPercent == floor(cpuPercent) {
            return String(format: "%.0f%%", cpuPercent)
        } else {
            return String(format: "%.1f%%", cpuPercent)
        }
    }

    /// Subtitle for search results display: "PID: 12345 | 256 MB | 5.0%"
    var resourceSubtitle: String {
        "PID: \(pid) | \(memoryFormatted) | \(cpuFormatted)"
    }

    static func == (lhs: RunningProcess, rhs: RunningProcess) -> Bool {
        lhs.pid == rhs.pid && lhs.name == rhs.name
    }
}

// MARK: - Process Search Service

/// Service for fetching and searching running processes
/// Uses libproc for accurate process information on macOS
final class ProcessSearchService {
    static let shared = ProcessSearchService()

    private let logger = Logger(subsystem: "com.zest.app", category: "ProcessSearch")

    /// Maximum number of results to return
    private let maxResults = 30

    /// Message shown when no processes match the search
    static let noResultsMessage = "No matching processes found"

    private init() {}

    // MARK: - Process Fetching

    /// Fetches all running processes using libproc
    /// Returns processes sorted by CPU usage (descending)
    func fetchRunningProcesses() -> [RunningProcess] {
        var processes: [RunningProcess] = []

        // Get list of all PIDs using sysctl
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: Int = 0

        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0 else {
            logger.error("Failed to get process list size")
            return processes
        }

        let count = size / MemoryLayout<kinfo_proc>.size
        var procList = [kinfo_proc](repeating: kinfo_proc(), count: count)

        guard sysctl(&mib, UInt32(mib.count), &procList, &size, nil, 0) == 0 else {
            logger.error("Failed to get process list")
            return processes
        }

        let actualCount = size / MemoryLayout<kinfo_proc>.size

        // Get running applications from NSWorkspace for user app info
        let runningApps = NSWorkspace.shared.runningApplications
        let runningAppPIDs = Set(runningApps.map { $0.processIdentifier })

        // Process each entry
        for i in 0..<actualCount {
            let proc = procList[i]
            let pid = proc.kp_proc.p_pid

            guard pid > 0 else { continue }

            if let processInfo = createRunningProcess(from: proc, runningAppPIDs: runningAppPIDs) {
                processes.append(processInfo)
            }
        }

        // Sort by CPU usage descending
        return processes.sorted { $0.cpuPercent > $1.cpuPercent }
    }

    /// Creates RunningProcess from a kinfo_proc structure
    private func createRunningProcess(from proc: kinfo_proc, runningAppPIDs: Set<pid_t>) -> RunningProcess? {
        // Get process name
        var nameBuffer = proc.kp_proc.p_comm
        let processName = withUnsafePointer(to: &nameBuffer) { ptr -> String in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { charPtr in
                String(cString: charPtr)
            }
        }

        let pid = proc.kp_proc.p_pid

        // Get memory info using proc_pidinfo (task info)
        var taskInfo = proc_taskinfo()
        let taskInfoSize = MemoryLayout<proc_taskinfo>.size
        let result = withUnsafeMutablePointer(to: &taskInfo) { ptr in
            ptr.withMemoryRebound(to: Void.self, capacity: taskInfoSize) { voidPtr in
                proc_pidinfo(pid, PROC_PIDTASKINFO, 0, voidPtr, Int32(taskInfoSize))
            }
        }

        var memoryBytes: UInt64 = 0
        var cpuPercent: Double = 0.0

        if result == taskInfoSize {
            // pti_resident_size is in bytes
            memoryBytes = UInt64(taskInfo.pti_resident_size)

            // For CPU, we use a simplified calculation
            // In a real implementation, you'd track CPU over time intervals
            let totalTime = taskInfo.pti_total_user + taskInfo.pti_total_system
            // Convert nanoseconds to seconds and estimate
            cpuPercent = min(100.0, Double(totalTime) / 10_000_000_000.0)
        }

        // Determine if this is a user app
        let isUserApp = runningAppPIDs.contains(pid)

        // Get icon for user applications
        var icon: NSImage? = nil
        if isUserApp {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
                icon = app.icon
            }
        }

        // Try to get bundle identifier for running apps
        var bundleIdentifier: String? = nil
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            bundleIdentifier = app.bundleIdentifier
        }

        return RunningProcess(
            name: processName,
            pid: pid,
            memoryBytes: memoryBytes,
            cpuPercent: cpuPercent,
            icon: icon,
            bundleIdentifier: bundleIdentifier,
            isUserApp: isUserApp,
            attemptedKill: ProcessKillState.shared.hasAttemptedKill(pid: pid)
        )
    }

    // MARK: - Search

    /// Searches processes by query
    /// - Parameters:
    ///   - query: Search string (case-insensitive)
    ///   - processes: List of processes to search (if nil, fetches fresh)
    /// - Returns: Filtered and sorted results (by CPU, limited to maxResults)
    func searchProcesses(query: String, processes: [RunningProcess]? = nil) -> [RunningProcess] {
        let processList = processes ?? fetchRunningProcesses()

        // Empty query returns top processes by CPU
        if query.isEmpty {
            return Array(processList.prefix(maxResults))
        }

        let lowercaseQuery = query.lowercased()

        // Filter matching processes
        let filtered = processList.filter { process in
            let lowercaseName = process.name.lowercased()
            let nameWithoutExtension = lowercaseName.replacingOccurrences(of: ".app", with: "")

            return lowercaseName.contains(lowercaseQuery) ||
                   nameWithoutExtension.contains(lowercaseQuery)
        }

        // Sort by CPU descending and limit
        return Array(filtered
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(maxResults))
    }

    // MARK: - Search Results Conversion

    /// Creates SearchResult array from RunningProcess array
    /// Includes kill state tracking for visual feedback
    func createSearchResults(from processes: [RunningProcess]) -> [SearchResult] {
        processes.map { process in
            let processCopy = process // Capture copy for closure
            // Check kill state directly from ProcessKillState to ensure consistency
            let isKillAttempted = ProcessKillState.shared.hasAttemptedKill(pid: process.pid)
            return SearchResult(
                title: process.name,
                subtitle: process.resourceSubtitle,
                icon: process.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: "Process"),
                category: .process,
                action: {
                    ProcessSearchService.activateProcess(processCopy)
                },
                revealAction: {
                    ProcessSearchService.twoPhaseKillWithConfirmation(process: processCopy)
                },
                score: Int(process.cpuPercent * 10), // Higher CPU = higher score
                isKillAttempted: isKillAttempted,
                pid: process.pid
            )
        }
    }

    /// Activates a user application (brings to foreground)
    private static func activateProcess(_ process: RunningProcess) {
        guard process.isUserApp else {
            return // Cannot activate system processes
        }

        // Find the running application and activate it
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.processIdentifier == process.pid }) {
            app.activate(options: [])
        }
    }

    // MARK: - Force Quit

    /// List of system process names that require confirmation before force quit
    private static let systemProcessNames: Set<String> = [
        "kernel_task",
        "WindowServer",
        "launchd",
        "launchd_session",
        "init",
        "mds",
        "mds_stores",
        "mds_backup",
        "securityd",
        "configd",
        "SystemUIServer",
        "Finder",
        "Dock"
    ]

    /// Checks if a process is a critical system process
    /// - Parameters:
    ///   - name: Process name
    ///   - pid: Process ID
    /// - Returns: true if the process is a critical system process
    static func isSystemProcess(name: String, pid: pid_t) -> Bool {
        // PID 0 is always kernel_task
        if pid == 0 { return true }
        
        // Check against known system process names
        return systemProcessNames.contains(name)
    }

    /// Force quits a process by PID
    /// - Parameter pid: Process ID to terminate
    /// - Returns: true if termination signal was sent successfully
    static func forceQuitProcess(pid: pid_t) -> Bool {
        // Send SIGKILL to the process
        let result = kill(pid, SIGKILL)
        
        if result == 0 {
            return true
        } else {
            // Check error - ESRCH means process doesn't exist, EPERM means permission denied
            return false
        }
    }

    /// Force quits a process with confirmation for system processes
    /// - Parameter process: The process to force quit
    static func forceQuitWithConfirmation(process: RunningProcess) {
        if isSystemProcess(name: process.name, pid: process.pid) {
            // Show confirmation for system processes on main thread
            DispatchQueue.main.async {
                Self.showForceQuitConfirmation(process: process)
            }
        } else {
            // Directly force quit user apps
            _ = forceQuitProcess(pid: process.pid)
        }
    }

    // MARK: - Two-Phase Kill (Story 22)

    /// Attempts to kill a process using two-phase logic
    /// Phase 1: Send SIGTERM (polite quit request)
    /// Phase 2: Send SIGKILL (force quit)
    /// - Parameter pid: Process ID to terminate
    /// - Returns: KillResult indicating what action was taken
    static func attemptKill(pid: pid_t) -> KillResult {
        let hasAttempted = ProcessKillState.shared.hasAttemptedKill(pid: pid)

        if hasAttempted {
            // Phase 2: Force kill with SIGKILL
            let result = kill(pid, SIGKILL)
            if result == 0 {
                // Clear state after successful SIGKILL
                ProcessKillState.shared.clearKillAttempt(pid: pid)
                return .sigkillSent
            } else {
                // Failed to kill
                let error = NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
                    NSLocalizedDescriptionKey: "Failed to send SIGKILL to process \(pid)"
                ])
                return .failed(error)
            }
        } else {
            // Phase 1: Polite quit with SIGTERM
            let result = kill(pid, SIGTERM)
            if result == 0 {
                // Mark as attempted for next phase
                ProcessKillState.shared.markKillAttempted(pid: pid)
                return .sigtermSent
            } else {
                // Failed to send SIGTERM
                let error = NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
                    NSLocalizedDescriptionKey: "Failed to send SIGTERM to process \(pid)"
                ])
                return .failed(error)
            }
        }
    }

    /// Two-phase kill with confirmation for system processes
    /// - Parameter process: The process to kill
    static func twoPhaseKillWithConfirmation(process: RunningProcess) {
        if isSystemProcess(name: process.name, pid: process.pid) {
            // Show confirmation for system processes on main thread
            DispatchQueue.main.async {
                Self.showTwoPhaseKillConfirmation(process: process)
            }
        } else {
            // Directly attempt kill for user apps
            _ = attemptKill(pid: process.pid)
        }
    }

    /// Shows a confirmation dialog before killing a system process
    private static func showTwoPhaseKillConfirmation(process: RunningProcess) {
        let hasAttempted = ProcessKillState.shared.hasAttemptedKill(pid: process.pid)

        let alert = NSAlert()
        if hasAttempted {
            alert.messageText = "Force Kill \(process.name)?"
            alert.informativeText = """
            \(process.name) is a system process that has already received a termination request.
            
            Force killing it may cause system instability. Are you sure you want to continue?
            """
        } else {
            alert.messageText = "Terminate \(process.name)?"
            alert.informativeText = """
            \(process.name) is a system process. Terminating it may cause system instability.

            Are you sure you want to continue?
            """
        }
        alert.alertStyle = .critical
        alert.addButton(withTitle: hasAttempted ? "Force Kill" : "Terminate")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            _ = attemptKill(pid: process.pid)
        }
    }

    /// Shows a confirmation dialog before force quitting a system process
    private static func showForceQuitConfirmation(process: RunningProcess) {
        let alert = NSAlert()
        alert.messageText = "Force Quit \(process.name)?"
        alert.informativeText = """
        \(process.name) is a system process. Force quitting it may cause system instability.

        Are you sure you want to continue?
        """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Force Quit")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            _ = forceQuitProcess(pid: process.pid)
        }
    }
}

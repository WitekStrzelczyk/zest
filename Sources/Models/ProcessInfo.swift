import AppKit
import Darwin
import Foundation
import os.log

enum KillResult: Equatable {
    case sigtermSent
    case sigkillSent
    case success
    case failed(Error)

    static func == (lhs: KillResult, rhs: KillResult) -> Bool {
        switch (lhs, rhs) {
        case (.sigtermSent, .sigtermSent): true
        case (.sigkillSent, .sigkillSent): true
        case (.success, .success): true
        case (.failed, .failed): true
        default: false
        }
    }
}

final class ProcessKillState {
    static let shared = ProcessKillState()

    private var attemptedKills: Set<pid_t> = []
    private let lock = NSLock()

    private init() {}

    func hasAttemptedKill(pid: pid_t) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return attemptedKills.contains(pid)
    }

    func markKillAttempted(pid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        attemptedKills.insert(pid)
    }

    func clearKillAttempt(pid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        attemptedKills.remove(pid)
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        attemptedKills.removeAll()
    }
}

struct RunningProcess: Identifiable, Equatable {
    let id: UUID
    let name: String
    let pid: pid_t
    let memoryBytes: UInt64
    let cpuPercent: Double
    let icon: NSImage?
    let bundleIdentifier: String?
    let isUserApp: Bool
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
        id = UUID()
        self.name = name
        self.pid = pid
        self.memoryBytes = memoryBytes
        self.cpuPercent = cpuPercent
        self.icon = icon
        self.bundleIdentifier = bundleIdentifier
        self.isUserApp = isUserApp
        self.attemptedKill = attemptedKill
    }

    var memoryFormatted: String {
        let megabytes = Double(memoryBytes) / 1_000_000.0
        let gigabytes = Double(memoryBytes) / 1_000_000_000.0

        if gigabytes >= 1.0 {
            return String(format: "%.1f GB", gigabytes)
        } else {
            return String(format: "%.0f MB", megabytes)
        }
    }

    var cpuFormatted: String {
        if cpuPercent == floor(cpuPercent) {
            String(format: "%.0f%%", cpuPercent)
        } else {
            String(format: "%.1f%%", cpuPercent)
        }
    }

    var resourceSubtitle: String {
        "PID: \(pid) | \(memoryFormatted) | \(cpuFormatted)"
    }

    static func == (lhs: RunningProcess, rhs: RunningProcess) -> Bool {
        lhs.pid == rhs.pid && lhs.name == rhs.name
    }
}

final class ProcessSearchService {
    static let shared = ProcessSearchService()

    private let logger = Logger(subsystem: "com.zest.app", category: "ProcessSearch")

    private let maxResults = 30

    static let noResultsMessage = "No matching processes found"

    private init() {}

    func fetchRunningProcesses() -> [RunningProcess] {
        var processes: [RunningProcess] = []

        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0

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
        let runningApps = NSWorkspace.shared.runningApplications
        let runningAppPIDs = Set(runningApps.map(\.processIdentifier))

        for i in 0..<actualCount {
            let proc = procList[i]
            let pid = proc.kp_proc.p_pid
            guard pid > 0 else { continue }
            if let processInfo = createRunningProcess(from: proc, runningAppPIDs: runningAppPIDs) {
                processes.append(processInfo)
            }
        }

        return processes.sorted { $0.cpuPercent > $1.cpuPercent }
    }

    private func createRunningProcess(from proc: kinfo_proc, runningAppPIDs: Set<pid_t>) -> RunningProcess? {
        var nameBuffer = proc.kp_proc.p_comm
        let processName = withUnsafePointer(to: &nameBuffer) { ptr -> String in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { charPtr in
                String(cString: charPtr)
            }
        }

        let pid = proc.kp_proc.p_pid
        var taskInfo = proc_taskinfo()
        let taskInfoSize = MemoryLayout<proc_taskinfo>.size
        let result = withUnsafeMutablePointer(to: &taskInfo) { ptr in
            ptr.withMemoryRebound(to: Void.self, capacity: taskInfoSize) { voidPtr in
                proc_pidinfo(pid, PROC_PIDTASKINFO, 0, voidPtr, Int32(taskInfoSize))
            }
        }

        var memoryBytes: UInt64 = 0
        var cpuPercent = 0.0

        if result == taskInfoSize {
            memoryBytes = UInt64(taskInfo.pti_resident_size)
            let totalTime = taskInfo.pti_total_user + taskInfo.pti_total_system
            cpuPercent = min(100.0, Double(totalTime) / 10_000_000_000.0)
        }

        let isUserApp = runningAppPIDs.contains(pid)
        var icon: NSImage? = nil
        var bundleIdentifier: String? = nil

        if isUserApp {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
                icon = app.icon
                bundleIdentifier = app.bundleIdentifier
            }
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

    func findProcessesUsingPort(_ port: Int) -> [RunningProcess] {
        print("📁 ProcessSearchService: Searching for processes on port \(port)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-i", ":\(port)", "-t"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let pids = output.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .compactMap { pid_t($0) }

                print("📁 ProcessSearchService: lsof found PIDs: \(pids)")

                let allProcesses = fetchRunningProcesses()
                let matched = allProcesses.filter { pids.contains($0.pid) }
                print("📁 ProcessSearchService: Matched \(matched.count) processes from running list")
                return matched
            }
        } catch {
            logger.error("Failed to run lsof: \(error.localizedDescription)")
        }

        return []
    }

    func searchProcesses(query: String, processes: [RunningProcess]? = nil) -> [RunningProcess] {
        let processList = processes ?? fetchRunningProcesses()
        if query.isEmpty { return Array(processList.prefix(maxResults)) }
        let lowercaseQuery = query.lowercased()
        let filtered = processList.filter { process in
            let lowercaseName = process.name.lowercased()
            return lowercaseName.contains(lowercaseQuery)
        }
        return Array(filtered.prefix(maxResults))
    }

    func createSearchResults(from processes: [RunningProcess]) -> [SearchResult] {
        processes.map { process in
            let processCopy = process
            let isKillAttempted = ProcessKillState.shared.hasAttemptedKill(pid: process.pid)

            let displayTitle = isKillAttempted ? "[FORCE KILL] \(process.name)" : process.name

            return SearchResult(
                title: displayTitle,
                subtitle: process.resourceSubtitle,
                icon: process.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: "Process"),
                category: .process,
                action: { ProcessSearchService.activateProcess(processCopy) },
                revealAction: {
                    ProcessSearchService.twoPhaseKillWithConfirmation(process: processCopy)
                },
                score: Int(process.cpuPercent * 10),
                isWarning: isKillAttempted,
                isKillAttempted: isKillAttempted,
                pid: process.pid
            )
        }
    }

    private static func activateProcess(_ process: RunningProcess) {
        if process.isUserApp {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == process.pid }) {
                app.activate(options: [])
            }
        }
    }

    private static let systemProcessNames: Set<String> = [
        "kernel_task", "WindowServer", "launchd", "Finder", "Dock",
    ]

    static func isSystemProcess(name: String, pid: pid_t) -> Bool {
        if pid == 0 { return true }
        return systemProcessNames.contains(name)
    }

    static func forceQuitProcess(pid: pid_t) -> Bool {
        let result = kill(pid, SIGKILL)
        if result != 0 { return false }

        let start = Date()
        while Date().timeIntervalSince(start) < 5.0 {
            if kill(pid, 0) != 0 {
                NotificationCenter.default.post(name: .processWasKilled, object: nil)
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }

        NotificationCenter.default.post(name: .processWasKilled, object: nil)
        return false
    }

    static func forceQuitWithConfirmation(process: RunningProcess) {
        if isSystemProcess(name: process.name, pid: process.pid) {
            DispatchQueue.main.async { showForceQuitConfirmation(process: process) }
        } else {
            _ = forceQuitProcess(pid: process.pid)
        }
    }

    static func attemptKill(pid: pid_t) -> KillResult {
        let hasAttempted = ProcessKillState.shared.hasAttemptedKill(pid: pid)
        let signal = hasAttempted ? SIGKILL : SIGTERM

        let result = kill(pid, signal)
        if result != 0 {
            return .failed(NSError(domain: NSPOSIXErrorDomain, code: Int(errno)))
        }

        if !hasAttempted {
            ProcessKillState.shared.markKillAttempted(pid: pid)
        } else {
            ProcessKillState.shared.clearKillAttempt(pid: pid)
        }

        let start = Date()
        while Date().timeIntervalSince(start) < 5.0 {
            if kill(pid, 0) != 0 {
                ProcessKillState.shared.clearKillAttempt(pid: pid)
                NotificationCenter.default.post(name: .processWasKilled, object: nil)
                return .success
            }
            Thread.sleep(forTimeInterval: 0.2)
        }

        NotificationCenter.default.post(name: .processWasKilled, object: nil)
        return hasAttempted ? .failed(NSError(
            domain: "zest",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Process refused to die even after SIGKILL"]
        )) : .sigtermSent
    }

    static func twoPhaseKillWithConfirmation(process: RunningProcess) {
        if isSystemProcess(name: process.name, pid: process.pid) {
            DispatchQueue.main.async { showTwoPhaseKillConfirmation(process: process) }
        } else {
            _ = attemptKill(pid: process.pid)
        }
    }

    private static func showTwoPhaseKillConfirmation(process: RunningProcess) {
        let hasAttempted = ProcessKillState.shared.hasAttemptedKill(pid: process.pid)
        let alert = NSAlert()
        alert.messageText = hasAttempted ? "Force Kill \(process.name)?" : "Terminate \(process.name)?"
        alert.alertStyle = .critical
        alert.addButton(withTitle: hasAttempted ? "Force Kill" : "Terminate")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { _ = attemptKill(pid: process.pid) }
    }

    private static func showForceQuitConfirmation(process: RunningProcess) {
        let alert = NSAlert()
        alert.messageText = "Force Quit \(process.name)?"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Force Quit")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { _ = forceQuitProcess(pid: process.pid) }
    }
}

import AppKit
import os.log

final class SystemLoadTool {
    static let shared = SystemLoadTool()

    private static let memoryKeywords = ["memory", "ram"]
    private static let cpuKeywords = ["cpu", "load"]

    private static let memoryIcon = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory")
    private static let cpuIcon = NSImage(systemSymbolName: "cpu", accessibilityDescription: "CPU")
    private static let processIcon = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Process")
    private static let warningIcon = NSImage(
        systemSymbolName: "exclamationmark.triangle",
        accessibilityDescription: "Warning"
    )

    private let logger = Logger(subsystem: "com.zest.app", category: "SystemLoad")
    private let service = SystemLoadService.shared

    private init() {}

    private func memoryResults(score: Int) -> [SearchResult] {
        let memory = service.memory()
        let details = [
            "\(Self.gigabytes(memory.usedBytes)) of \(Self.wholeGigabytes(memory.totalBytes))",
            "Pressure \(memory.pressure.rawValue)",
            "Compressed \(Self.gigabytes(memory.compressedBytes))",
            "Swap \(Self.gigabytes(memory.swapUsedBytes))",
        ].joined(separator: " • ")
        let overview = result(
            title: "Memory: \(memory.usedPercent)% used",
            subtitle: details,
            icon: Self.memoryIcon,
            score: score
        )
        let apps = service.latestSample()?.largestApps ?? []
        let warning = memory.pressure == .normal ? [] : [memoryWarning(memory, topApp: apps.first, score: score)]
        let rows = apps.enumerated().map { index, app in
            let share = Int((Double(app.memoryBytes) / Double(max(memory.totalBytes, 1)) * 100).rounded())
            return result(
                title: "\(app.name): \(Self.size(app.memoryBytes))",
                subtitle: "\(Self.processes(app.processCount)) • \(share)% of memory",
                icon: icon(for: app),
                score: score - 1 - index
            )
        }
        return [overview] + warning + rows
    }

    private func memoryWarning(_ memory: MemoryUsage, topApp: AppLoad?, score: Int) -> SearchResult {
        let hint = topApp.map { "Quitting \($0.name) frees about \(Self.size($0.memoryBytes))" }
            ?? "Quit apps you are not using"
        return SearchResult(
            title: "⚠️ Memory Pressure \(memory.pressure.rawValue)",
            subtitle: hint,
            icon: Self.warningIcon,
            category: .action,
            action: {},
            score: score,
            isWarning: true
        )
    }

    private func cpuResults(score: Int) -> [SearchResult] {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let load = Self.loadAverages()
        let sample = service.latestSample()
        let coreText = [Self.coreSplit(cores)] + (load.isEmpty ? [] : ["Load \(load)"])
        guard let sample else {
            return [result(
                title: "CPU: Measuring…",
                subtitle: coreText.joined(separator: " • "),
                icon: Self.cpuIcon,
                score: score
            )]
        }
        let usage = ["User \(sample.cpu.userPercent)%", "System \(sample.cpu.systemPercent)%"]
        let overview = result(
            title: "CPU: \(sample.cpu.busyPercent)%",
            subtitle: (usage + coreText).joined(separator: " • "),
            icon: Self.cpuIcon,
            score: score
        )
        let rows = sample.busiestApps.enumerated().map { index, app in
            result(
                title: "\(app.name): \(Int(app.cpuPercent.rounded()))% CPU",
                subtitle: "\(Self.processes(app.processCount)) • \(Self.size(app.memoryBytes))",
                icon: icon(for: app),
                score: score - 1 - index
            )
        }
        return [overview] + rows
    }

    private func result(title: String, subtitle: String, icon: NSImage?, score: Int) -> SearchResult {
        SearchResult(
            title: title,
            subtitle: subtitle,
            icon: icon,
            category: .action,
            action: { [weak self] in
                self?.copyText("\(title) (\(subtitle))")
            },
            score: score
        )
    }

    private func icon(for app: AppLoad) -> NSImage? {
        guard let appPath = app.appPath else { return Self.processIcon }
        return IconCache.shared.renderedIcon(for: appPath)
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        logger.info("System load copied to clipboard")
    }

    private static func coreSplit(_ cores: Int) -> String {
        let performance = sysctlInt("hw.perflevel0.logicalcpu")
        let efficiency = sysctlInt("hw.perflevel1.logicalcpu")
        guard let performance, let efficiency, performance + efficiency == cores else { return "\(cores) cores" }
        return "\(cores) cores (\(performance)P + \(efficiency)E)"
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }

    private static func loadAverages() -> String {
        var averages = [Double](repeating: 0, count: 3)
        guard getloadavg(&averages, 3) == 3 else { return "" }
        return averages.map { String(format: "%.1f", $0) }.joined(separator: " ")
    }

    private static func processes(_ count: Int) -> String {
        count == 1 ? "1 process" : "\(count) processes"
    }

    private static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    private static func wholeGigabytes(_ bytes: UInt64) -> String {
        String(format: "%.0f GB", Double(bytes) / 1_073_741_824)
    }

    private static func size(_ bytes: UInt64) -> String {
        bytes >= 1_073_741_824 ? gigabytes(bytes) : String(format: "%.0f MB", Double(bytes) / 1_048_576)
    }
}

extension SystemLoadTool: SearchTool {
    var name: String { "System Load" }

    func search(_ context: QueryContext) -> [SearchResult] {
        let query = context.normalized.lowercased()
        guard !query.isEmpty else { return [] }
        let showsMemory = matchesKeyword(query, in: Self.memoryKeywords)
        let showsCPU = matchesKeyword(query, in: Self.cpuKeywords)
        guard showsMemory || showsCPU else { return [] }
        let score = max(SearchScoreCalculator.shared.calculateScore(
            query: query,
            title: showsMemory ? "Memory" : "CPU",
            category: .action
        ), 100)
        return (showsMemory ? memoryResults(score: score) : []) + (showsCPU ? cpuResults(score: score) : [])
    }
}

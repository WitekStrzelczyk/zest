import AppKit
import Foundation
import IOKit
import os.log

struct StorageInfo {
    let totalBytes: Int64

    let availableBytes: Int64

    let usedBytes: Int64

    var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }

    var isNearlyFull: Bool {
        usagePercentage > 90
    }
}

struct SystemInfo {
    let macOSVersion: String

    let modelName: String

    let chipInfo: String

    let memory: String

    let hostName: String
}

final class SystemInfoService {
    static let shared = SystemInfoService()

    private let logger = Logger(subsystem: "com.zest.app", category: "SystemInfo")

    private var cachedStorageInfo: StorageInfo?
    private var storageCacheTime: Date?
    private var storageRefreshInFlight = false

    private var cachedSystemInfo: SystemInfo?

    private let cacheTimeout: TimeInterval = 30

    private let cacheLock = NSLock()

    private static let storageIcon = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "Storage")
    private static let storageFullIcon = NSImage(
        systemSymbolName: "externaldrive.badge.exclamationmark",
        accessibilityDescription: "Storage"
    )
    private static let warningIcon = NSImage(
        systemSymbolName: "exclamationmark.triangle",
        accessibilityDescription: "Warning"
    )
    private static let macIcon = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "System Info")
    private static let versionIcon = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Version")

    private init() {}

    func getStorageInfo() -> StorageInfo {
        let (cached, shouldRefresh) = cacheLock.withLock { () -> (StorageInfo?, Bool) in
            let isStale = storageCacheTime.map { Date().timeIntervalSince($0) >= cacheTimeout } ?? true
            let startRefresh = cachedStorageInfo != nil && isStale && !storageRefreshInFlight
            if startRefresh { storageRefreshInFlight = true }
            return (cachedStorageInfo, startRefresh)
        }
        guard let cached else { return refreshStorageInfo() }
        if shouldRefresh {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                _ = self?.refreshStorageInfo()
            }
        }
        return cached
    }

    func refreshStorageInfo() -> StorageInfo {
        let info = fetchStorageInfo()
        cacheLock.withLock {
            cachedStorageInfo = info
            storageCacheTime = Date()
            storageRefreshInFlight = false
        }
        return info
    }

    func isStorageNearlyFull(_ info: StorageInfo) -> Bool {
        info.isNearlyFull
    }

    func getSystemInfo() -> SystemInfo {
        cacheLock.withLock {
            if let cached = cachedSystemInfo {
                return cached
            }
            let info = fetchSystemInfo()
            cachedSystemInfo = info
            return info
        }
    }

    func refreshSystemInfo() -> SystemInfo {
        cacheLock.withLock { cachedSystemInfo = nil }
        return getSystemInfo()
    }

    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()

        guard !lowercasedQuery.isEmpty else { return [] }

        var results: [SearchResult] = []

        let storageKeywords = ["storage", "disk", "space", "drive", "hd", "ssd"]
        if matchesKeyword(lowercasedQuery, in: storageKeywords) {
            results.append(contentsOf: createStorageResults(query: lowercasedQuery))
        }

        let systemKeywords = ["system", "about", "mac", "specs", "info", "version", "model"]
        if matchesKeyword(lowercasedQuery, in: systemKeywords) {
            results.append(contentsOf: createSystemInfoResults(query: lowercasedQuery))
        }

        return results
    }

    private func createStorageResults(query: String) -> [SearchResult] {
        let info = getStorageInfo()
        var results: [SearchResult] = []

        let score = SearchScoreCalculator.shared.calculateScore(
            query: query,
            title: "Storage",
            category: .action
        )

        let subtitle = formatStorageInfo(info)

        results.append(SearchResult(
            title: "Storage: \(Int(info.usagePercentage))% used",
            subtitle: subtitle,
            icon: info.isNearlyFull ? Self.storageFullIcon : Self.storageIcon,
            category: .action,
            action: { [weak self] in
                self?.copyToClipboard(info)
            },
            score: max(score, 100)
        ))

        if info.isNearlyFull {
            results.append(SearchResult(
                title: "⚠️ Storage Nearly Full",
                subtitle: "Only \(formatBytes(info.availableBytes)) available - consider freeing space",
                icon: Self.warningIcon,
                category: .action,
                action: {},
                score: max(score, 150)
            ))
        }

        return results
    }

    private func createSystemInfoResults(query: String) -> [SearchResult] {
        let systemInfo = getSystemInfo()
        let storageInfo = getStorageInfo()
        var results: [SearchResult] = []

        let score = SearchScoreCalculator.shared.calculateScore(
            query: query,
            title: "System Info",
            category: .action
        )

        let chipInfo = systemInfo.chipInfo.isEmpty ? "" : systemInfo.chipInfo + " • "
        let subtitle = "\(systemInfo.modelName) • \(chipInfo)\(systemInfo.memory)"

        results.append(SearchResult(
            title: "About This Mac",
            subtitle: subtitle.trimmingCharacters(in: CharacterSet(charactersIn: " •")),
            icon: Self.macIcon,
            category: .action,
            action: { [weak self] in
                self?.copyToClipboard(systemInfo, storageInfo: storageInfo)
            },
            score: max(score, 100)
        ))

        results.append(SearchResult(
            title: "macOS Version",
            subtitle: systemInfo.macOSVersion,
            icon: Self.versionIcon,
            category: .action,
            action: { [weak self] in
                self?.copyToClipboard(systemInfo, storageInfo: storageInfo)
            },
            score: max(score - 10, 50)
        ))

        return results
    }

    func formatStorageInfo(_ info: StorageInfo) -> String {
        "\(formatBytes(info.availableBytes)) available of \(formatBytes(info.totalBytes))"
    }

    func formatBytes(_ bytes: Int64) -> String {
        let tb: Int64 = 1_099_511_627_776
        let gb: Int64 = 1_073_741_824
        let mb: Int64 = 1_048_576
        let kb: Int64 = 1024

        if bytes >= tb {
            return String(format: "%.1f TB", Double(bytes) / Double(tb))
        } else if bytes >= gb {
            return String(format: "%.0f GB", Double(bytes) / Double(gb))
        } else if bytes >= mb {
            return String(format: "%.0f MB", Double(bytes) / Double(mb))
        } else if bytes >= kb {
            return String(format: "%.1f KB", Double(bytes) / Double(kb))
        } else {
            return "\(bytes) bytes"
        }
    }

    func formatSystemInfoForClipboard(systemInfo: SystemInfo, storageInfo: StorageInfo) -> String {
        var text = """
        System Information
        ==================
        Model: \(systemInfo.modelName)
        macOS: \(systemInfo.macOSVersion)
        Memory: \(systemInfo.memory)
        """

        if !systemInfo.chipInfo.isEmpty {
            text += "\nChip: \(systemInfo.chipInfo)"
        }

        text += "\nHost: \(systemInfo.hostName)"
        text += "\n\nStorage"
        text += "\n-------"
        text += "\nTotal: \(formatBytes(storageInfo.totalBytes))"
        text += "\nAvailable: \(formatBytes(storageInfo.availableBytes))"
        text += "\nUsed: \(formatBytes(storageInfo.usedBytes)) (\(Int(storageInfo.usagePercentage))%)"

        return text
    }

    func copyToClipboard(_ info: SystemInfo, storageInfo: StorageInfo? = nil) {
        let text: String = if let storageInfo {
            formatSystemInfoForClipboard(systemInfo: info, storageInfo: storageInfo)
        } else {
            """
            System Information
            ==================
            Model: \(info.modelName)
            macOS: \(info.macOSVersion)
            Memory: \(info.memory)
            Chip: \(info.chipInfo.isEmpty ? "N/A" : info.chipInfo)
            Host: \(info.hostName)
            """
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        logger.info("System info copied to clipboard")
    }

    func copyToClipboard(_ info: StorageInfo) {
        let text = """
        Storage Information
        ===================
        Total: \(formatBytes(info.totalBytes))
        Available: \(formatBytes(info.availableBytes))
        Used: \(formatBytes(info.usedBytes))
        Usage: \(Int(info.usagePercentage))%
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        logger.info("Storage info copied to clipboard")
    }

    private func fetchStorageInfo() -> StorageInfo {
        let fileManager = FileManager.default

        let homeURL = fileManager.homeDirectoryForCurrentUser

        do {
            let values = try homeURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
            ])

            let total = Int64(values.volumeTotalCapacity ?? 0)
            let availableForImportant = values.volumeAvailableCapacityForImportantUsage
            let standardAvailable = values.volumeAvailableCapacity ?? 0
            let importantAvailable = availableForImportant ?? Int64(standardAvailable)
            let available = Int64(importantAvailable)
            let used = total - available

            return StorageInfo(
                totalBytes: total,
                availableBytes: available,
                usedBytes: used
            )
        } catch {
            logger.error("Failed to get storage info: \(error)")
            return StorageInfo(totalBytes: 0, availableBytes: 0, usedBytes: 0)
        }
    }

    private func fetchSystemInfo() -> SystemInfo {
        let processInfo = ProcessInfo.processInfo

        let osVersion = processInfo.operatingSystemVersion
        let macOSVersion = "macOS \(osVersion.majorVersion).\(osVersion.minorVersion)"
            + (osVersion.patchVersion > 0 ? ".\(osVersion.patchVersion)" : "")

        let modelName = getModelName()

        let chipInfo = getChipInfo()

        let memory = formatMemory(ProcessInfo.processInfo.physicalMemory)

        let hostName = Host.current().localizedName ?? "Mac"

        return SystemInfo(
            macOSVersion: macOSVersion,
            modelName: modelName,
            chipInfo: chipInfo,
            memory: memory,
            hostName: hostName
        )
    }

    private func getModelName() -> String {
        if let productName = deviceTreeProductName() {
            return productName
        }

        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)

        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)

        let modelCode = String(cString: model)

        let modelMap: [String: String] = [
            "MacBookPro": "MacBook Pro",
            "MacBookAir": "MacBook Air",
            "MacBook": "MacBook",
            "Macmini": "Mac mini",
            "iMac": "iMac",
            "MacPro": "Mac Pro",
            "MacStudio": "Mac Studio",
        ]

        for (key, name) in modelMap {
            if modelCode.contains(key) {
                return name
            }
        }

        return "Mac"
    }

    private func deviceTreeProductName() -> String? {
        let product = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        guard product != 0 else { return nil }
        defer { IOObjectRelease(product) }
        guard let data = IORegistryEntryCreateCFProperty(product, "product-name" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Data else { return nil }
        let name = String(decoding: data.prefix { $0 != 0 }, as: UTF8.self)
        return name.isEmpty ? nil : name
    }

    private func getChipInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)

        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)

        let brandString = String(cString: brand)

        if let atIndex = brandString.firstIndex(of: "@") {
            return String(brandString[..<atIndex]).trimmingCharacters(in: .whitespaces)
        }

        return brandString.trimmingCharacters(in: .whitespaces)
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0

        if gb >= 1 {
            return "\(Int(gb)) GB"
        } else {
            let mb = Double(bytes) / 1_048_576.0
            return "\(Int(mb)) MB"
        }
    }
}

extension SystemInfoService: SearchTool {
    var name: String { "System Info" }

    func search(_ context: QueryContext) -> [SearchResult] {
        search(query: context.normalized)
    }
}

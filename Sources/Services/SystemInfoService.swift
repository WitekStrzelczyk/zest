import AppKit
import Foundation
import os.log

// MARK: - Storage Info

/// Contains storage/disk information
struct StorageInfo {
    /// Total storage in bytes
    let totalBytes: Int64
    
    /// Available storage in bytes
    let availableBytes: Int64
    
    /// Used storage in bytes
    let usedBytes: Int64
    
    /// Usage percentage (0-100)
    var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }
    
    /// Whether storage is nearly full (> 90%)
    var isNearlyFull: Bool {
        usagePercentage > 90
    }
}

// MARK: - System Info

/// Contains system information
struct SystemInfo {
    /// macOS version (e.g., "macOS 14.0")
    let macOSVersion: String
    
    /// Model name (e.g., "MacBook Pro")
    let modelName: String
    
    /// Chip info (e.g., "Apple M1 Pro") - may be empty on Intel Macs
    let chipInfo: String
    
    /// Memory (e.g., "16 GB")
    let memory: String
    
    /// Host name
    let hostName: String
}

// MARK: - System Info Service

/// Service for retrieving storage and system information
final class SystemInfoService {
    // MARK: - Singleton
    
    static let shared = SystemInfoService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.zest.app", category: "SystemInfo")
    
    /// Cached storage info (refreshed every 30 seconds)
    private var cachedStorageInfo: StorageInfo?
    private var storageCacheTime: Date?
    
    /// Cached system info (rarely changes, cache for longer)
    private var cachedSystemInfo: SystemInfo?
    
    private let cacheTimeout: TimeInterval = 30
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Storage Info
    
    /// Get current storage information for the main disk
    func getStorageInfo() -> StorageInfo {
        // Check cache
        if let cached = cachedStorageInfo, let lastTime = storageCacheTime {
            if Date().timeIntervalSince(lastTime) < cacheTimeout {
                return cached
            }
        }
        
        // Fetch fresh info
        let info = fetchStorageInfo()
        cachedStorageInfo = info
        storageCacheTime = Date()
        return info
    }
    
    /// Force refresh storage info (bypasses cache)
    func refreshStorageInfo() -> StorageInfo {
        cachedStorageInfo = nil
        storageCacheTime = nil
        return getStorageInfo()
    }
    
    /// Check if storage is nearly full (> 90%)
    func isStorageNearlyFull(_ info: StorageInfo) -> Bool {
        info.isNearlyFull
    }
    
    // MARK: - System Info
    
    /// Get system information
    func getSystemInfo() -> SystemInfo {
        // System info rarely changes, cache it
        if let cached = cachedSystemInfo {
            return cached
        }
        
        let info = fetchSystemInfo()
        cachedSystemInfo = info
        return info
    }
    
    /// Force refresh system info
    func refreshSystemInfo() -> SystemInfo {
        cachedSystemInfo = nil
        return getSystemInfo()
    }
    
    // MARK: - Search
    
    /// Search for system info and storage related commands
    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()
        
        guard !lowercasedQuery.isEmpty else { return [] }
        
        var results: [SearchResult] = []
        
        // Storage keywords
        let storageKeywords = ["storage", "disk", "space", "drive", "hd", "ssd"]
        let storageMatch = storageKeywords.contains { keyword in
            keyword.contains(lowercasedQuery) || lowercasedQuery.contains(keyword)
        }
        
        if storageMatch {
            results.append(contentsOf: createStorageResults(query: lowercasedQuery))
        }
        
        // System info keywords
        let systemKeywords = ["system", "about", "mac", "specs", "info", "version", "model"]
        let systemMatch = systemKeywords.contains { keyword in
            keyword.contains(lowercasedQuery) || lowercasedQuery.contains(keyword)
        }
        
        if systemMatch {
            results.append(contentsOf: createSystemInfoResults(query: lowercasedQuery))
        }
        
        return results
    }
    
    // MARK: - Create Search Results
    
    private func createStorageResults(query: String) -> [SearchResult] {
        let info = getStorageInfo()
        var results: [SearchResult] = []
        
        let score = SearchScoreCalculator.shared.calculateScore(
            query: query,
            title: "Storage",
            category: .action
        )
        
        let subtitle = formatStorageInfo(info)
        let warningIcon = info.isNearlyFull ? "externaldrive.badge.exclamationmark" : "externaldrive"
        
        results.append(SearchResult(
            title: "Storage: \(Int(info.usagePercentage))% used",
            subtitle: subtitle,
            icon: NSImage(systemSymbolName: warningIcon, accessibilityDescription: "Storage"),
            category: .action,
            action: { [weak self] in
                self?.copyToClipboard(info)
            },
            score: max(score, 100)
        ))
        
        // If nearly full, add warning
        if info.isNearlyFull {
            results.append(SearchResult(
                title: "⚠️ Storage Nearly Full",
                subtitle: "Only \(formatBytes(info.availableBytes)) available - consider freeing space",
                icon: NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Warning"),
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
        
        // Main system info result
        let subtitle = "\(systemInfo.modelName) • \(systemInfo.chipInfo.isEmpty ? "" : systemInfo.chipInfo + " • ")\(systemInfo.memory)"
        
        results.append(SearchResult(
            title: "About This Mac",
            subtitle: subtitle.trimmingCharacters(in: CharacterSet(charactersIn: " •")),
            icon: NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "System Info"),
            category: .action,
            action: { [weak self] in
                self?.copyToClipboard(systemInfo, storageInfo: storageInfo)
            },
            score: max(score, 100)
        ))
        
        // macOS version
        results.append(SearchResult(
            title: "macOS Version",
            subtitle: systemInfo.macOSVersion,
            icon: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Version"),
            category: .action,
            action: { [weak self] in
                self?.copyToClipboard(systemInfo, storageInfo: storageInfo)
            },
            score: max(score - 10, 50)
        ))
        
        return results
    }
    
    // MARK: - Formatting
    
    /// Format storage info for display
    func formatStorageInfo(_ info: StorageInfo) -> String {
        "\(formatBytes(info.availableBytes)) available of \(formatBytes(info.totalBytes))"
    }
    
    /// Format bytes to human-readable string
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
    
    /// Format system info for clipboard
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
    
    // MARK: - Clipboard
    
    /// Copy system info to clipboard
    func copyToClipboard(_ info: SystemInfo, storageInfo: StorageInfo? = nil) {
        let text: String
        if let storageInfo {
            text = formatSystemInfoForClipboard(systemInfo: info, storageInfo: storageInfo)
        } else {
            text = """
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
    
    /// Copy storage info to clipboard
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
    
    // MARK: - Private Methods
    
    /// Fetch storage info from FileManager
    private func fetchStorageInfo() -> StorageInfo {
        let fileManager = FileManager.default
        
        // Get the home directory volume
        let homeURL = fileManager.homeDirectoryForCurrentUser
        
        do {
            let values = try homeURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            
            let total = Int64(values.volumeTotalCapacity ?? 0)
            // Use volumeAvailableCapacityForImportantUsage for more accurate "available" space
            let importantAvailable = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
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
    
    /// Fetch system info
    private func fetchSystemInfo() -> SystemInfo {
        let processInfo = ProcessInfo.processInfo
        
        // macOS version
        let osVersion = processInfo.operatingSystemVersion
        let macOSVersion = "macOS \(osVersion.majorVersion).\(osVersion.minorVersion)"
            + (osVersion.patchVersion > 0 ? ".\(osVersion.patchVersion)" : "")
        
        // Model name
        let modelName = getModelName()
        
        // Chip info
        let chipInfo = getChipInfo()
        
        // Memory
        let memory = formatMemory(ProcessInfo.processInfo.physicalMemory)
        
        // Host name
        let hostName = Host.current().localizedName ?? "Mac"
        
        return SystemInfo(
            macOSVersion: macOSVersion,
            modelName: modelName,
            chipInfo: chipInfo,
            memory: memory,
            hostName: hostName
        )
    }
    
    /// Get the Mac model name
    private func getModelName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        
        let modelCode = String(cString: model)
        
        // Map common model codes to readable names
        // These are simplified - actual mapping is more complex
        let modelMap: [String: String] = [
            "MacBookPro": "MacBook Pro",
            "MacBookAir": "MacBook Air",
            "MacBook": "MacBook",
            "Macmini": "Mac mini",
            "iMac": "iMac",
            "MacPro": "Mac Pro",
            "MacStudio": "Mac Studio"
        ]
        
        for (key, name) in modelMap {
            if modelCode.contains(key) {
                return name
            }
        }
        
        return "Mac"
    }
    
    /// Get chip info (Apple Silicon or Intel)
    private func getChipInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        
        let brandString = String(cString: brand)
        
        // Clean up the brand string
        // Remove frequency info (e.g., "@ 2.6GHz")
        if let atIndex = brandString.firstIndex(of: "@") {
            return String(brandString[..<atIndex]).trimmingCharacters(in: .whitespaces)
        }
        
        return brandString.trimmingCharacters(in: .whitespaces)
    }
    
    /// Format memory to human-readable string
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

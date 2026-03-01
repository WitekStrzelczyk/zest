import AppKit
import Foundation
import IOKit.ps
import os.log

// MARK: - Charging State

/// Represents the current charging state of the battery
enum ChargingState: String {
    case charging = "Charging"
    case discharging = "Discharging"
    case fullyCharged = "Fully Charged"
    case notCharging = "Not Charging"
    case unknown = "Unknown"
}

// MARK: - Battery Info

/// Contains battery information
struct BatteryInfo {
    /// Battery percentage (0-100)
    let percentage: Double
    
    /// Battery cycle count
    let cycleCount: Int
    
    /// Current charging state
    let chargingState: ChargingState
    
    /// Battery health percentage (0-100, -1 if unavailable)
    let healthPercentage: Double
    
    /// Whether the device has a battery
    let hasBattery: Bool
    
    /// Time remaining in minutes (-1 if unknown/calculating)
    let timeRemaining: Int
    
    /// Whether the battery is currently charging
    var isCharging: Bool {
        chargingState == .charging || chargingState == .fullyCharged
    }
    
    /// Whether the battery is low (< 20%)
    var isLow: Bool {
        percentage < 20 && !isCharging
    }
}

// MARK: - Battery Service

/// Service for retrieving battery information using IOKit
final class BatteryService {
    // MARK: - Singleton
    
    static let shared = BatteryService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.zest.app", category: "Battery")
    
    /// Cached battery info (refreshed every 30 seconds)
    private var cachedInfo: BatteryInfo?
    private var lastCacheTime: Date?
    private let cacheTimeout: TimeInterval = 30
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public API
    
    /// Get current battery information
    /// - Returns: BatteryInfo with current battery state
    func getBatteryInfo() -> BatteryInfo {
        // Check cache
        if let cached = cachedInfo, let lastTime = lastCacheTime {
            if Date().timeIntervalSince(lastTime) < cacheTimeout {
                return cached
            }
        }
        
        // Fetch fresh info
        let info = fetchBatteryInfo()
        cachedInfo = info
        lastCacheTime = Date()
        return info
    }
    
    /// Force refresh battery info (bypasses cache)
    func refreshBatteryInfo() -> BatteryInfo {
        cachedInfo = nil
        lastCacheTime = nil
        return getBatteryInfo()
    }
    
    /// Check if battery is low (< 20% and not charging)
    func isLowBattery(_ info: BatteryInfo) -> Bool {
        info.isLow
    }
    
    // MARK: - Search
    
    /// Search for battery-related commands
    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()
        
        guard !lowercasedQuery.isEmpty else { return [] }
        
        // Keywords that trigger battery results
        let keywords = ["battery", "power", "charge", "batt", "energy"]
        let matchesKeyword = keywords.contains { keyword in
            keyword.contains(lowercasedQuery) || lowercasedQuery.contains(keyword)
        }
        
        guard matchesKeyword else { return [] }
        
        let info = getBatteryInfo()
        var results: [SearchResult] = []
        
        // Main battery status result
        let score = SearchScoreCalculator.shared.calculateScore(
            query: lowercasedQuery,
            title: "Battery Status",
            category: .action
        )
        
        let warningIcon = info.isLow ? "battery.25percent" : "battery.100percent.bolt"
        let subtitle = formatBatteryInfo(info)
        
        results.append(SearchResult(
            title: "Battery: \(Int(info.percentage))%",
            subtitle: subtitle,
            icon: NSImage(systemSymbolName: warningIcon, accessibilityDescription: "Battery"),
            category: .action,
            action: { [weak self] in
                self?.copyToClipboard(info)
            },
            score: max(score, 100)
        ))
        
        // If low battery, add warning
        if info.isLow {
            results.append(SearchResult(
                title: "⚠️ Low Battery Warning",
                subtitle: "Battery at \(Int(info.percentage))% - connect charger",
                icon: NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Warning"),
                category: .action,
                action: {},
                score: max(score, 150)
            ))
        }
        
        return results
    }
    
    // MARK: - Formatting
    
    /// Format battery info for display
    func formatBatteryInfo(_ info: BatteryInfo) -> String {
        guard info.hasBattery else {
            return "No battery detected"
        }
        
        var parts: [String] = []
        
        // Charging state
        parts.append(formatChargingState(info.chargingState))
        
        // Cycle count
        parts.append("\(info.cycleCount) cycles")
        
        // Health
        if info.healthPercentage >= 0 {
            parts.append("\(Int(info.healthPercentage))% health")
        }
        
        // Time remaining
        if info.timeRemaining > 0 {
            parts.append(formatTimeRemaining(info.timeRemaining))
        }
        
        return parts.joined(separator: " • ")
    }
    
    /// Format charging state for display
    func formatChargingState(_ state: ChargingState) -> String {
        state.rawValue
    }
    
    /// Format time remaining in minutes to human-readable string
    func formatTimeRemaining(_ minutes: Int) -> String {
        guard minutes > 0 else {
            return "Calculating..."
        }
        
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return "\(hours) hr \(mins) min remaining"
        } else {
            return "\(mins) min remaining"
        }
    }
    
    // MARK: - Clipboard
    
    /// Copy battery info to clipboard
    func copyToClipboard(_ info: BatteryInfo) {
        let text = """
        Battery Status
        ==============
        Percentage: \(Int(info.percentage))%
        State: \(formatChargingState(info.chargingState))
        Cycle Count: \(info.cycleCount)
        Health: \(info.healthPercentage >= 0 ? "\(Int(info.healthPercentage))%" : "N/A")
        Time Remaining: \(formatTimeRemaining(info.timeRemaining))
        """
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        logger.info("Battery info copied to clipboard")
    }
    
    // MARK: - Private Methods
    
    /// Fetch battery info from IOKit
    private func fetchBatteryInfo() -> BatteryInfo {
        // Get the battery service
        guard let powerSources = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let powerSourcesList = IOPSCopyPowerSourcesList(powerSources)?.takeRetainedValue() as? [[String: Any]],
              let battery = powerSourcesList.first else {
            // No battery found (desktop Mac)
            return BatteryInfo(
                percentage: 0,
                cycleCount: 0,
                chargingState: .unknown,
                healthPercentage: -1,
                hasBattery: false,
                timeRemaining: -1
            )
        }
        
        // Extract battery info
        let currentCapacity = battery[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacity = battery[kIOPSMaxCapacityKey] as? Int ?? 100
        let percentage = maxCapacity > 0 ? Double(currentCapacity) / Double(maxCapacity) * 100.0 : 0
        
        // Charging state
        let state = battery[kIOPSPowerSourceStateKey] as? String ?? "Unknown"
        let isCharging = battery[kIOPSIsChargingKey] as? Bool ?? false
        // Note: kIOPSIsFullyChargedKey is not always available, use capacity check instead
        let isFullyCharged = !isCharging && currentCapacity >= maxCapacity
        
        let chargingState: ChargingState
        if isFullyCharged {
            chargingState = .fullyCharged
        } else if isCharging {
            chargingState = .charging
        } else if state == "Battery Power" {
            chargingState = .discharging
        } else if state == "AC Power" {
            chargingState = .notCharging
        } else {
            chargingState = .unknown
        }
        
        // Time remaining - use string keys as some constants may not be defined
        let timeRemaining = battery["Time to Empty"] as? Int ?? -1
        let timeToFull = battery["Time to Full Charge"] as? Int ?? -1
        let displayTime = isCharging ? timeToFull : timeRemaining
        
        // Cycle count - requires reading from IORegistry
        let cycleCount = getCycleCount()
        
        // Health percentage
        let healthPercentage = getBatteryHealth()
        
        return BatteryInfo(
            percentage: percentage,
            cycleCount: cycleCount,
            chargingState: chargingState,
            healthPercentage: healthPercentage,
            hasBattery: true,
            timeRemaining: displayTime
        )
    }
    
    /// Get cycle count from IORegistry
    private func getCycleCount() -> Int {
        // Find the battery service in IORegistry
        let serviceMatch = IOServiceMatching("IOPMPowerSource")
        var iterator: io_iterator_t = 0
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, serviceMatch, &iterator) == KERN_SUCCESS else {
            return 0
        }
        
        defer {
            IOObjectRelease(iterator)
        }
        
        var cycleCount = 0
        var service = IOIteratorNext(iterator)
        
        while service != 0 {
            defer {
                IOObjectRelease(service)
            }
            
            // Get CycleCount property
            if let properties = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                cycleCount = properties
                break
            }
            
            service = IOIteratorNext(iterator)
        }
        
        return cycleCount
    }
    
    /// Get battery health percentage
    private func getBatteryHealth() -> Double {
        // On Apple Silicon, the most reliable way to get battery health 
        // is from system_profiler which reads the battery's actual health metric
        // This returns values like "Maximum Capacity: 81%"
        
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPPowerDataType"]
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse "Maximum Capacity: XX%" from output
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    if line.contains("Maximum Capacity") {
                        // Extract percentage: "Maximum Capacity: 81%" -> 81
                        let components = line.components(separatedBy: ":")
                        if components.count >= 2 {
                            let valueStr = components[1].trimmingCharacters(in: .whitespaces)
                                .replacingOccurrences(of: "%", with: "")
                                .trimmingCharacters(in: .whitespaces)
                            if let percentage = Double(valueStr), percentage > 0 {
                                return percentage
                            }
                        }
                    }
                }
            }
        } catch {
            logger.error("Failed to get battery health from system_profiler: \(error.localizedDescription)")
        }
        
        // Fallback: try IORegistry method for older systems
        return getBatteryHealthFromIORegistry()
    }
    
    /// Fallback: try getting battery health from IORegistry (older method for Intel Macs)
    private func getBatteryHealthFromIORegistry() -> Double {
        let serviceMatch = IOServiceMatching("IOPMPowerSource")
        var iterator: io_iterator_t = 0
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, serviceMatch, &iterator) == KERN_SUCCESS else {
            return -1
        }
        
        defer {
            IOObjectRelease(iterator)
        }
        
        var health = -1.0
        var service = IOIteratorNext(iterator)
        
        while service != 0 {
            defer {
                IOObjectRelease(service)
            }
            
            if let maxCap = IORegistryEntryCreateCFProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                // Same logic: if <= 100, it's already a percentage
                if maxCap <= 100 && maxCap >= 0 {
                    health = Double(maxCap)
                    break
                }
                // Otherwise calculate against DesignCapacity
                if let designCap = IORegistryEntryCreateCFProperty(service, "DesignCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
                   designCap > 0 {
                    let healthValue = Double(maxCap) / Double(designCap) * 100.0
                    health = min(max(healthValue, 0), 100)
                    break
                }
            }
            
            service = IOIteratorNext(iterator)
        }
        
        return health
    }
}

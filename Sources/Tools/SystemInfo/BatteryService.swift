import AppKit
import Foundation
import IOKit.ps
import os.log

enum ChargingState: String {
    case charging = "Charging"
    case discharging = "Discharging"
    case fullyCharged = "Fully Charged"
    case notCharging = "Not Charging"
    case unknown = "Unknown"
}

struct BatteryInfo {
    let percentage: Double

    let cycleCount: Int

    let chargingState: ChargingState

    let healthPercentage: Double

    let hasBattery: Bool

    let timeRemaining: Int

    var isCharging: Bool {
        chargingState == .charging || chargingState == .fullyCharged
    }

    var isLow: Bool {
        percentage < 20 && !isCharging
    }
}

final class BatteryService {
    static let shared = BatteryService()

    private let logger = Logger(subsystem: "com.zest.app", category: "Battery")

    private var cachedInfo: BatteryInfo?
    private var lastCacheTime: Date?
    private let cacheTimeout: TimeInterval = 30

    private let cacheLock = NSLock()

    private static let batteryIcon = NSImage(
        systemSymbolName: "battery.100percent.bolt",
        accessibilityDescription: "Battery"
    )
    private static let lowBatteryIcon = NSImage(
        systemSymbolName: "battery.25percent",
        accessibilityDescription: "Battery"
    )
    private static let warningIcon = NSImage(
        systemSymbolName: "exclamationmark.triangle",
        accessibilityDescription: "Warning"
    )

    private init() {}

    func getBatteryInfo() -> BatteryInfo {
        cacheLock.withLock {
            if let cached = cachedInfo, let lastTime = lastCacheTime,
               Date().timeIntervalSince(lastTime) < cacheTimeout {
                return cached
            }
            let info = fetchBatteryInfo()
            cachedInfo = info
            lastCacheTime = Date()
            return info
        }
    }

    func refreshBatteryInfo() -> BatteryInfo {
        cacheLock.withLock {
            cachedInfo = nil
            lastCacheTime = nil
        }
        return getBatteryInfo()
    }

    func isLowBattery(_ info: BatteryInfo) -> Bool {
        info.isLow
    }

    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()

        guard !lowercasedQuery.isEmpty else { return [] }

        let keywords = ["battery", "power", "charge", "batt", "energy"]
        guard matchesKeyword(lowercasedQuery, in: keywords) else { return [] }

        let info = getBatteryInfo()
        var results: [SearchResult] = []

        let score = SearchScoreCalculator.shared.calculateScore(
            query: lowercasedQuery,
            title: "Battery Status",
            category: .action
        )

        let subtitle = formatBatteryInfo(info)

        results.append(SearchResult(
            title: "Battery: \(Int(info.percentage))%",
            subtitle: subtitle,
            icon: info.isLow ? Self.lowBatteryIcon : Self.batteryIcon,
            category: .action,
            action: { [weak self] in
                self?.copyToClipboard(info)
            },
            score: max(score, 100)
        ))

        if info.isLow {
            results.append(SearchResult(
                title: "⚠️ Low Battery Warning",
                subtitle: "Battery at \(Int(info.percentage))% - connect charger",
                icon: Self.warningIcon,
                category: .action,
                action: {},
                score: max(score, 150)
            ))
        }

        return results
    }

    func formatBatteryInfo(_ info: BatteryInfo) -> String {
        guard info.hasBattery else {
            return "No battery detected"
        }

        var parts: [String] = []

        parts.append(formatChargingState(info.chargingState))

        parts.append("\(info.cycleCount) cycles")

        if info.healthPercentage >= 0 {
            parts.append("\(Int(info.healthPercentage))% health")
        }

        if info.timeRemaining > 0 {
            parts.append(formatTimeRemaining(info.timeRemaining))
        }

        return parts.joined(separator: " • ")
    }

    func formatChargingState(_ state: ChargingState) -> String {
        state.rawValue
    }

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

    private func fetchBatteryInfo() -> BatteryInfo {
        guard let powerSources = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let powerSourcesList = IOPSCopyPowerSourcesList(powerSources)?.takeRetainedValue() as? [[String: Any]],
              let battery = powerSourcesList.first
        else {
            return BatteryInfo(
                percentage: 0,
                cycleCount: 0,
                chargingState: .unknown,
                healthPercentage: -1,
                hasBattery: false,
                timeRemaining: -1
            )
        }

        let currentCapacity = battery[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacity = battery[kIOPSMaxCapacityKey] as? Int ?? 100
        let percentage = maxCapacity > 0 ? Double(currentCapacity) / Double(maxCapacity) * 100.0 : 0

        let state = battery[kIOPSPowerSourceStateKey] as? String ?? "Unknown"
        let isCharging = battery[kIOPSIsChargingKey] as? Bool ?? false
        let isFullyCharged = !isCharging && currentCapacity >= maxCapacity

        let chargingState: ChargingState = if isFullyCharged {
            .fullyCharged
        } else if isCharging {
            .charging
        } else if state == "Battery Power" {
            .discharging
        } else if state == "AC Power" {
            .notCharging
        } else {
            .unknown
        }

        let timeRemaining = battery["Time to Empty"] as? Int ?? -1
        let timeToFull = battery["Time to Full Charge"] as? Int ?? -1
        let displayTime = isCharging ? timeToFull : timeRemaining

        let (cycleCount, healthPercentage) = readPowerSourceRegistry()

        return BatteryInfo(
            percentage: percentage,
            cycleCount: cycleCount,
            chargingState: chargingState,
            healthPercentage: healthPercentage,
            hasBattery: true,
            timeRemaining: displayTime
        )
    }

    private func readPowerSourceRegistry() -> (cycleCount: Int, health: Double) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMPowerSource"))
        guard service != 0 else { return (0, -1) }
        defer { IOObjectRelease(service) }

        func intProperty(_ key: String) -> Int? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int
        }

        let cycleCount = intProperty("CycleCount") ?? 0
        guard let maxCapacity = intProperty("MaxCapacity") else { return (cycleCount, -1) }
        if (0...100).contains(maxCapacity) { return (cycleCount, Double(maxCapacity)) }
        guard let designCapacity = intProperty("DesignCapacity"), designCapacity > 0 else { return (cycleCount, -1) }
        return (cycleCount, min(max(Double(maxCapacity) / Double(designCapacity) * 100.0, 0), 100))
    }
}

extension BatteryService: SearchTool {
    var name: String { "Battery" }

    func search(_ context: QueryContext) -> [SearchResult] {
        search(query: context.normalized)
    }
}

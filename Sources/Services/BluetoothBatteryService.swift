import Foundation
import os.log

struct AccessoryBattery: Equatable {
    struct Level: Equatable {
        let part: String
        let percent: Int
    }

    let name: String
    let kind: String
    let isConnected: Bool
    let levels: [Level]

    var headlinePercent: Int {
        let buds = levels.filter { $0.part != "Case" }
        return (buds.isEmpty ? levels : buds).map(\.percent).min() ?? 0
    }
}

extension Notification.Name {
    static let accessoryBatteriesUpdated = Notification.Name("accessoryBatteriesUpdated")
}

final class BluetoothBatteryService: @unchecked Sendable {
    static let shared = BluetoothBatteryService()

    private static let reportTimeout: TimeInterval = 5
    private static let parts = ["Main": "", "Left": "Left", "Right": "Right", "Case": "Case"]
    private static let partOrder = ["", "Left", "Right", "Case"]

    private let logger = Logger(subsystem: "com.zest.app", category: "BluetoothBattery")
    private let lock = NSLock()
    private var cached: [AccessoryBattery] = []
    private var lastRefresh: Date?
    private var refreshInFlight = false
    private let freshness: TimeInterval = 60

    private init() {}

    func accessories() -> [AccessoryBattery] {
        let (accessories, isStale) = lock.withLock { () -> ([AccessoryBattery], Bool) in
            let stale = lastRefresh.map { Date().timeIntervalSince($0) > freshness } ?? true
            let shouldRefresh = stale && !refreshInFlight
            if shouldRefresh { refreshInFlight = true }
            return (cached, shouldRefresh)
        }
        if isStale {
            DispatchQueue.global(qos: .utility).async { self.refresh() }
        }
        return accessories
    }

    func update(fromReport data: Data) {
        let accessories = Self.parse(data)
        let changed = lock.withLock { () -> Bool in
            defer {
                cached = accessories
                lastRefresh = Date()
                refreshInFlight = false
            }
            return cached != accessories
        }
        guard changed else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .accessoryBatteriesUpdated, object: nil)
        }
    }

    private func refresh() {
        guard let report = Self.runBluetoothReport() else {
            lock.withLock {
                lastRefresh = Date()
                refreshInFlight = false
            }
            logger.error("Bluetooth report did not finish in time")
            return
        }
        update(fromReport: report)
    }

    private static func runBluetoothReport() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        var output = Data()
        let reading = DispatchGroup()
        reading.enter()
        DispatchQueue.global(qos: .utility).async {
            output = pipe.fileHandleForReading.readDataToEndOfFile()
            reading.leave()
        }
        guard reading.wait(timeout: .now() + reportTimeout) == .success else {
            process.terminate()
            return nil
        }
        return output
    }

    static func parse(_ data: Data) -> [AccessoryBattery] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]]
        else { return [] }

        let groups: [(key: String, isConnected: Bool)] = [("device_connected", true), ("device_not_connected", false)]
        return controllers.flatMap { controller in
            groups.flatMap { group in
                let devices = controller[group.key] as? [[String: [String: Any]]] ?? []
                return devices.flatMap { device in
                    device.compactMap { accessory(named: $0.key, properties: $0.value, isConnected: group.isConnected) }
                }
            }
        }
    }

    private static func accessory(
        named name: String,
        properties: [String: Any],
        isConnected: Bool
    ) -> AccessoryBattery? {
        let levels = properties.compactMap { key, value -> AccessoryBattery.Level? in
            guard key.hasPrefix("device_batteryLevel"),
                  let part = parts[String(key.dropFirst("device_batteryLevel".count))],
                  let text = value as? String,
                  let percent = Int(text.trimmingCharacters(in: CharacterSet(charactersIn: "% ")))
            else { return nil }
            return AccessoryBattery.Level(part: part, percent: percent)
        }
        .sorted { (partOrder.firstIndex(of: $0.part) ?? 0) < (partOrder.firstIndex(of: $1.part) ?? 0) }

        guard !levels.isEmpty else { return nil }
        return AccessoryBattery(
            name: name,
            kind: properties["device_minorType"] as? String ?? "",
            isConnected: isConnected,
            levels: levels
        )
    }
}

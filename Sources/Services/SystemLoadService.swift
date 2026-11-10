import Darwin
import Foundation

struct MemoryUsage {
    enum Pressure: String {
        case normal = "Normal"
        case warning = "Elevated"
        case critical = "Critical"
    }

    let totalBytes: UInt64
    let usedBytes: UInt64
    let compressedBytes: UInt64
    let compressedOriginalBytes: UInt64
    let swapUsedBytes: UInt64
    let pressure: Pressure

    var usedPercent: Int {
        guard totalBytes > 0 else { return 0 }
        return Int((Double(usedBytes) / Double(totalBytes) * 100).rounded())
    }

    var demandBytes: UInt64 { usedBytes + swapUsedBytes }

    var demandPercent: Int {
        guard totalBytes > 0 else { return 0 }
        return Int((Double(demandBytes) / Double(totalBytes) * 100).rounded())
    }
}

struct CPUUsage: Equatable {
    let userPercent: Int
    let systemPercent: Int

    var busyPercent: Int { min(userPercent + systemPercent, 100) }
}

struct AppLoad: Equatable {
    let name: String
    let appPath: String?
    let processCount: Int
    let cpuPercent: Double
    let memoryBytes: UInt64
}

struct LoadSample: Equatable {
    let measuredAt: Date
    let cpu: CPUUsage
    let busiestApps: [AppLoad]
    let largestApps: [AppLoad]
}

extension Notification.Name {
    static let systemLoadUpdated = Notification.Name("systemLoadUpdated")
}

final class SystemLoadService: @unchecked Sendable {
    static let shared = SystemLoadService()

    private static let sampleInterval: TimeInterval = 0.5
    private static let freshness: TimeInterval = 3
    private static let expiry: TimeInterval = 60
    private static let appsShown = 3

    private let lock = NSLock()
    private var latest: LoadSample?
    private var measuring = false

    private init() {}

    func memory() -> MemoryUsage {
        let total = ProcessInfo.processInfo.physicalMemory
        let pageSize = UInt64(vm_kernel_page_size)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return MemoryUsage(
                totalBytes: total,
                usedBytes: 0,
                compressedBytes: 0,
                compressedOriginalBytes: 0,
                swapUsedBytes: 0,
                pressure: .normal
            )
        }
        let appPages = UInt64(stats.internal_page_count) - UInt64(min(stats.purgeable_count, stats.internal_page_count))
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = (appPages + UInt64(stats.wire_count)) * pageSize + compressed
        return MemoryUsage(
            totalBytes: total,
            usedBytes: min(used, total),
            compressedBytes: compressed,
            compressedOriginalBytes: stats.total_uncompressed_pages_in_compressor * pageSize,
            swapUsedBytes: Self.swapUsed(),
            pressure: Self.pressure()
        )
    }

    func latestSample() -> LoadSample? {
        let (sample, shouldMeasure) = lock.withLock { () -> (LoadSample?, Bool) in
            let age = latest.map { Date().timeIntervalSince($0.measuredAt) } ?? .infinity
            let start = age > Self.freshness && !measuring
            if start { measuring = true }
            return (age < Self.expiry ? latest : nil, start)
        }
        if shouldMeasure {
            DispatchQueue.global(qos: .utility).async { self.measureAndStore() }
        }
        return sample
    }

    func measure() {
        lock.withLock { measuring = true }
        measureAndStore()
    }

    private func measureAndStore() {
        let firstTicks = Self.cpuTicks()
        let firstProcesses = Self.ownProcesses()
        Thread.sleep(forTimeInterval: Self.sampleInterval)
        let secondTicks = Self.cpuTicks()
        let secondProcesses = Self.ownProcesses()

        let apps = Self.apps(from: firstProcesses, to: secondProcesses)
        let sample = LoadSample(
            measuredAt: Date(),
            cpu: Self.usage(from: firstTicks, to: secondTicks),
            busiestApps: Array(apps.filter { $0.cpuPercent >= 0.5 }.sorted { $0.cpuPercent > $1.cpuPercent }
                .prefix(Self.appsShown)),
            largestApps: Array(apps.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(Self.appsShown))
        )
        lock.withLock {
            latest = sample
            measuring = false
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .systemLoadUpdated, object: nil)
        }
    }

    private static func swapUsed() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return usage.xsu_used
    }

    private static func pressure() -> MemoryUsage.Pressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return .normal }
        switch level {
        case 4: return .critical
        case 2: return .warning
        default: return .normal
        }
    }

    private struct Ticks {
        let user: UInt64
        let system: UInt64
        let idle: UInt64
    }

    private static func cpuTicks() -> Ticks {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return Ticks(user: 0, system: 0, idle: 0) }
        let ticks = info.cpu_ticks
        return Ticks(
            user: UInt64(ticks.0) + UInt64(ticks.3),
            system: UInt64(ticks.1),
            idle: UInt64(ticks.2)
        )
    }

    private static func usage(from first: Ticks, to second: Ticks) -> CPUUsage {
        let user = Double(second.user &- first.user)
        let system = Double(second.system &- first.system)
        let total = user + system + Double(second.idle &- first.idle)
        guard total > 0 else { return CPUUsage(userPercent: 0, systemPercent: 0) }
        return CPUUsage(
            userPercent: Int((user / total * 100).rounded()),
            systemPercent: Int((system / total * 100).rounded())
        )
    }

    private struct OwnProcess {
        let pid: pid_t
        let path: String
        let cpuNanoseconds: UInt64
        let footprint: UInt64
    }

    private static let nanosecondsPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom)
    }()

    private static func ownProcesses() -> [pid_t: OwnProcess] {
        let capacity = Int(proc_listpids(UInt32(PROC_UID_ONLY), UInt32(getuid()), nil, 0)) / MemoryLayout<pid_t>.size
        guard capacity > 0 else { return [:] }
        var pids = [pid_t](repeating: 0, count: capacity + 32)
        let bytes = proc_listpids(
            UInt32(PROC_UID_ONLY),
            UInt32(getuid()),
            &pids,
            Int32(pids.count * MemoryLayout<pid_t>.size)
        )
        let listed = pids.prefix(Int(bytes) / MemoryLayout<pid_t>.size).filter { $0 > 0 }
        return Dictionary(listed.compactMap(ownProcess).map { ($0.pid, $0) }) { first, _ in first }
    }

    private static func ownProcess(_ pid: pid_t) -> OwnProcess? {
        var usage = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
            }
        }
        guard result == 0 else { return nil }
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 else { return nil }
        let ticks = Double(usage.ri_user_time + usage.ri_system_time)
        return OwnProcess(
            pid: pid,
            path: String(cString: pathBuffer),
            cpuNanoseconds: UInt64(ticks * nanosecondsPerTick),
            footprint: usage.ri_phys_footprint
        )
    }

    private static func apps(from first: [pid_t: OwnProcess], to second: [pid_t: OwnProcess]) -> [AppLoad] {
        let elapsed = sampleInterval * 1_000_000_000
        let grouped = Dictionary(grouping: second.values) { owningApp(of: $0.path) }
        return grouped.map { owner, processes in
            let cpuNanoseconds = processes.reduce(0.0) { total, process in
                let before = first[process.pid]?.cpuNanoseconds ?? process.cpuNanoseconds
                return total + Double(process.cpuNanoseconds &- min(before, process.cpuNanoseconds))
            }
            return AppLoad(
                name: owner.name,
                appPath: owner.appPath,
                processCount: processes.count,
                cpuPercent: cpuNanoseconds / elapsed * 100,
                memoryBytes: processes.reduce(0) { $0 + $1.footprint }
            )
        }
    }

    private struct Owner: Hashable {
        let name: String
        let appPath: String?
    }

    private static func owningApp(of path: String) -> Owner {
        guard let bundleEnd = path.range(of: ".app/") else {
            return Owner(name: (path as NSString).lastPathComponent, appPath: nil)
        }
        let appPath = String(path[..<bundleEnd.lowerBound]) + ".app"
        let name = ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
        return Owner(name: name, appPath: appPath)
    }
}

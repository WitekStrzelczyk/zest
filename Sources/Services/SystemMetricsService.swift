import Foundation
import os.log

/// Service for retrieving system CPU and memory usage metrics
/// Uses Mach kernel APIs for accurate, real-time measurements
final class SystemMetricsService {
    static let shared = SystemMetricsService()

    private let logger = Logger(subsystem: "com.zest.app", category: "SystemMetrics")

    private init() {}

    /// Returns current CPU usage as a percentage (0-100)
    /// Uses host_processor_info to read CPU tick counts
    func getCPUUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            logger.error("Failed to get CPU info: \(result)")
            return 0.0
        }

        var totalTicks: UInt64 = 0
        var idleTicks: UInt64 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = UInt64(cpuInfo[offset + Int(CPU_STATE_USER)])
            let system = UInt64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(cpuInfo[offset + Int(CPU_STATE_NICE)])

            totalTicks += user + system + idle + nice
            idleTicks += idle
        }

        // Free memory allocated by host_processor_info
        let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)

        let usedTicks = totalTicks - idleTicks
        return totalTicks > 0 ? Double(usedTicks) / Double(totalTicks) * 100.0 : 0.0
    }

    /// Returns current memory usage as a percentage (0-100)
    /// Uses vm_statistics64 to match Activity Monitor's "Memory Used" calculation
    func getMemoryUsage() -> Double {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        guard pageSize > 0 else {
            logger.error("Failed to get page size")
            return 0.0
        }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            logger.error("Failed to get VM statistics: \(result)")
            return 0.0
        }

        let active = UInt64(stats.active_count) * UInt64(pageSize)
        let inactive = UInt64(stats.inactive_count) * UInt64(pageSize)
        let wired = UInt64(stats.wire_count) * UInt64(pageSize)
        let compressed = UInt64(stats.compressor_page_count) * UInt64(pageSize)

        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usedMemory = active + wired + compressed
        let appMemory = usedMemory + inactive // What Activity Monitor shows as "Memory Used"

        return Double(appMemory) / Double(totalMemory) * 100.0
    }

    /// Formats CPU and memory percentages into a display string
    /// Format: "CPU: XX% | MEM: XX%" (rounded to whole numbers)
    func formatMetrics(cpu: Double, memory: Double) -> String {
        let cpuRounded = Int(round(cpu))
        let memRounded = Int(round(memory))
        return "CPU: \(cpuRounded)% | MEM: \(memRounded)%"
    }

    /// Returns formatted metrics string for display
    /// Call this for a one-shot retrieval of current metrics
    func getCurrentMetrics() -> String {
        let cpu = getCPUUsage()
        let memory = getMemoryUsage()
        return formatMetrics(cpu: cpu, memory: memory)
    }
}

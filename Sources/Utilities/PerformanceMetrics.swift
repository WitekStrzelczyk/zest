import Foundation
import os.log
import os.signpost

/// Performance metrics collection for Zest
///
/// ## Performance Targets
/// - Search latency: < 100ms for 80% of searches
/// - Startup time: < 500ms
/// - Memory baseline: < 50MB idle
///
/// ## Usage
/// ```swift
/// let metrics = PerformanceMetrics.shared
///
/// // Measure an operation
/// let result = metrics.measure("search") {
///     return performSearch()
/// }
///
/// // Use signpost for Instruments integration
/// metrics.beginSearch(query: "test")
/// // ... perform search ...
/// metrics.endSearch(resultCount: 5)
/// ```
///
/// ## Integration with Instruments
/// The metrics use os_signpost which integrates with:
/// - Time Profiler
/// - Allocations
/// - Custom Instruments
///
/// Run Instruments with:
/// ```
/// instruments -t "Time Profiler" ./Zest
/// ```
final class PerformanceMetrics: @unchecked Sendable {
    /// Shared singleton instance
    static let shared = PerformanceMetrics()

    // MARK: - OSLog & Signpost

    /// Log for performance events
    private let log = OSLog(subsystem: "com.zest.app", category: "Performance")

    /// Signpost ID for search operations
    private var searchSignpostID: OSSignpostID

    // MARK: - Metrics Storage

    /// Lock for thread-safe access
    private let lock = NSLock()

    /// Search operation metrics
    private var searchOperations: [SearchMetric] = []

    /// Startup metrics
    private var startupMetric: StartupMetric?

    /// Memory baselines
    private var memoryBaselines: [MemoryMetric] = []

    // MARK: - Initialization

    private init() {
        searchSignpostID = OSSignpostID(log: log)
    }

    // MARK: - Search Metrics

    /// Begin a search operation (for Instruments signpost)
    /// - Parameter query: The search query
    func beginSearch(query: String) {
        if #available(macOS 12.0, *) {
            os_signpost(.begin, log: log, name: "Search", signpostID: searchSignpostID, "%{public}s", query)
        } else {
            os_signpost(.begin, log: log, name: "Search", signpostID: searchSignpostID)
        }
    }

    /// End a search operation (for Instruments signpost)
    /// - Parameter resultCount: Number of results returned
    func endSearch(resultCount: Int) {
        if #available(macOS 12.0, *) {
            os_signpost(.end, log: log, name: "Search", signpostID: searchSignpostID, "%d results", resultCount)
        } else {
            os_signpost(.end, log: log, name: "Search", signpostID: searchSignpostID)
        }
    }

    /// Measure and record a search operation
    /// - Parameters:
    ///   - query: The search query
    ///   - operation: The search operation to measure
    /// - Returns: The search results
    func measureSearch<T>(query: String, _ operation: () -> T) -> T {
        let start = CFAbsoluteTimeGetCurrent()
        beginSearch(query: query)

        let result = operation()

        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000 // ms

        // Record metric
        lock.lock()
        defer { lock.unlock() }

        let resultCount: Int = if let results = result as? [Any] {
            results.count
        } else {
            1
        }

        searchOperations.append(SearchMetric(
            query: query,
            durationMs: duration,
            resultCount: resultCount,
            timestamp: Date()
        ))

        endSearch(resultCount: resultCount)

        return result
    }

    // MARK: - Generic Measurement

    /// Measure the execution time of an operation
    /// - Parameters:
    ///   - label: Label for the operation
    ///   - operation: The operation to measure
    /// - Returns: The result of the operation
    @discardableResult
    func measure<T>(_ label: String, _ operation: () -> T) -> T {
        let signpostID = OSSignpostID(log: log)

        if #available(macOS 12.0, *) {
            os_signpost(.begin, log: log, name: "Operation", signpostID: signpostID, "%{public}s", label)
        } else {
            os_signpost(.begin, log: log, name: "Operation", signpostID: signpostID)
        }

        let start = CFAbsoluteTimeGetCurrent()
        let result = operation()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        if #available(macOS 12.0, *) {
            os_signpost(.end, log: log, name: "Operation", signpostID: signpostID, "%{public}s: %.2fms", label, duration)
        } else {
            os_signpost(.end, log: log, name: "Operation", signpostID: signpostID)
        }

        os_log(" [%@] %.2fms", log: log, type: .info, label, duration)

        return result
    }

    /// Measure with callback for timing information
    /// - Parameters:
    ///   - label: Label for the operation
    ///   - operation: The operation to measure
    ///   - onTiming: Callback with the duration in milliseconds
    /// - Returns: The result of the operation
    @discardableResult
    func measureWithCallback<T>(_: String, _ operation: () -> T, onTiming: (Double) -> Void) -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = operation()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        onTiming(duration)
        return result
    }

    // MARK: - Startup Metrics

    /// Measure startup time
    /// - Parameter startupOperation: The startup operation to measure
    /// - Returns: Duration in milliseconds
    @discardableResult
    func measureStartup(_ startupOperation: () -> Void) -> Double {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Startup", signpostID: signpostID)

        let start = CFAbsoluteTimeGetCurrent()
        startupOperation()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        os_signpost(.end, log: log, name: "Startup", signpostID: signpostID)

        lock.lock()
        defer { lock.unlock() }

        startupMetric = StartupMetric(durationMs: duration, timestamp: Date())

        os_log("Startup completed in %.2fms", log: log, type: .info, duration)

        return duration
    }

    // MARK: - Memory Metrics

    /// Record current memory baseline
    func recordMemoryBaseline() {
        let memoryMB = getMemoryUsageMB()

        lock.lock()
        defer { lock.unlock() }

        memoryBaselines.append(MemoryMetric(
            memoryMB: memoryMB,
            timestamp: Date()
        ))

        os_log("Memory baseline: %.2fMB", log: log, type: .info, memoryMB)
    }

    /// Get current memory usage in MB
    /// - Returns: Memory usage in megabytes
    func getMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        return Double(info.resident_size) / 1024.0 / 1024.0
    }

    // MARK: - Export

    /// Export all metrics as a dictionary
    /// - Returns: Dictionary containing all metrics
    func exportMetrics() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        var result: [String: Any] = [:]

        // Search metrics
        if !searchOperations.isEmpty {
            let avgDuration = searchOperations.map(\.durationMs).reduce(0, +) / Double(searchOperations.count)
            let maxDuration = searchOperations.map(\.durationMs).max() ?? 0
            let minDuration = searchOperations.map(\.durationMs).min() ?? 0

            result["searchOperations"] = [
                "count": searchOperations.count,
                "avgDurationMs": avgDuration,
                "maxDurationMs": maxDuration,
                "minDurationMs": minDuration,
                "operations": searchOperations.map { [
                    "query": $0.query,
                    "durationMs": $0.durationMs,
                    "resultCount": $0.resultCount,
                    "timestamp": ISO8601DateFormatter().string(from: $0.timestamp),
                ] },
            ]
        }

        // Startup metrics
        if let startup = startupMetric {
            result["startup"] = [
                "durationMs": startup.durationMs,
                "timestamp": ISO8601DateFormatter().string(from: startup.timestamp),
            ]
        }

        // Memory metrics
        if !memoryBaselines.isEmpty {
            result["memory"] = memoryBaselines.map { [
                "memoryMB": $0.memoryMB,
                "timestamp": ISO8601DateFormatter().string(from: $0.timestamp),
            ] }
        }

        return result
    }

    /// Export metrics as JSON string
    /// - Returns: JSON string of all metrics
    func exportMetricsJSON() -> String {
        let metrics = exportMetrics()

        guard let data = try? JSONSerialization.data(withJSONObject: metrics, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return json
    }

    /// Clear all recorded metrics
    func reset() {
        lock.lock()
        defer { lock.unlock() }

        searchOperations.removeAll()
        startupMetric = nil
        memoryBaselines.removeAll()
    }

    // MARK: - Static Benchmark Helpers

    /// Run a benchmark with multiple iterations
    /// - Parameters:
    ///   - name: Name of the benchmark
    ///   - iterations: Number of iterations to run
    ///   - operation: The operation to benchmark
    /// - Returns: Average duration in milliseconds
    @discardableResult
    static func benchmark(name: String, iterations: Int = 100, _ operation: () -> Void) -> Double {
        var totalDuration: Double = 0

        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            operation()
            totalDuration += (CFAbsoluteTimeGetCurrent() - start) * 1000
        }

        let averageDuration = totalDuration / Double(iterations)

        os_log(
            "Benchmark '%@': %.4fms average over %d iterations",
            log: OSLog(subsystem: "com.zest.app", category: "Benchmark"),
            type: .info,
            name,
            averageDuration,
            iterations
        )

        return averageDuration
    }

    /// Run an async benchmark with multiple iterations
    /// - Parameters:
    ///   - name: Name of the benchmark
    ///   - iterations: Number of iterations to run
    ///   - operation: The async operation to benchmark
    /// - Returns: Average duration in milliseconds
    static func benchmarkAsync(name: String, iterations: Int = 100, _ operation: () async throws -> Void) async rethrows -> Double {
        var totalDuration: Double = 0

        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            try await operation()
            totalDuration += (CFAbsoluteTimeGetCurrent() - start) * 1000
        }

        let averageDuration = totalDuration / Double(iterations)

        os_log(
            "Async Benchmark '%@': %.4fms average over %d iterations",
            log: OSLog(subsystem: "com.zest.app", category: "Benchmark"),
            type: .info,
            name,
            averageDuration,
            iterations
        )

        return averageDuration
    }
}

// MARK: - Metric Types

/// Search operation metric
private struct SearchMetric {
    let query: String
    let durationMs: Double
    let resultCount: Int
    let timestamp: Date
}

/// Startup metric
private struct StartupMetric {
    let durationMs: Double
    let timestamp: Date
}

/// Memory metric
private struct MemoryMetric {
    let memoryMB: Double
    let timestamp: Date
}

// MARK: - Performance Targets

/// Performance targets for the application
enum PerformanceTarget {
    /// Maximum acceptable search latency (ms)
    static let searchLatencyMs = 100.0

    /// Maximum acceptable startup time (ms)
    static let startupTimeMs = 500.0

    /// Maximum acceptable idle memory (MB)
    static let memoryBaselineMB = 50.0

    /// Number of iterations for benchmarks
    static let benchmarkIterations = 100
}

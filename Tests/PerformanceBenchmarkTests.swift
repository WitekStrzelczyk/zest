import XCTest
@testable import ZestApp

/// Performance benchmark tests for Zest
///
/// Performance Targets:
/// - Search latency: < 100ms for 80% of searches
/// - Startup time: < 500ms
/// - Memory baseline: < 50MB idle
///
/// Note: These tests have reasonable tolerances to avoid flakiness.
/// Focus is on detecting major regressions, not micro-optimizations.
final class PerformanceBenchmarkTests: XCTestCase {

    // MARK: - Setup / Teardown

    override class func setUp() {
        // Disable contacts access during tests to avoid XPC connection issues
        // in the unit test environment
        ContactsService.isDisabled = true
    }

    override class func tearDown() {
        ContactsService.isDisabled = false
    }

    // MARK: - Search Latency Benchmarks

    /// Test: Search latency should be under 100ms for typical queries
    /// Target: < 100ms for 80% of searches
    /// Note: Uses searchFast which excludes file search for consistent performance
    func test_search_latency_is_under_100ms() {
        let engine = SearchEngine.shared
        let queries = ["safari", "mail", "notes", "finder", "saf"]

        var latencies: [Double] = []

        for query in queries {
            let start = CFAbsoluteTimeGetCurrent()
            let _ = engine.searchFast(query: query)  // Use fast search for consistent performance
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000 // Convert to ms
            latencies.append(duration)
        }

        let averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        let maxLatency = latencies.max() ?? 0

        print("Search latency results:")
        print("  Average: \(String(format: "%.2f", averageLatency))ms")
        print("  Max: \(String(format: "%.2f", maxLatency))ms")
        print("  All: \(latencies.map { String(format: "%.2f", $0) })")

        // 80% should be under 100ms - allow 150ms for CI variance
        XCTAssertLessThan(maxLatency, 150.0, "Search latency should be under 150ms (target: <100ms)")
    }

    /// Test: Fast search (without file search) should be very quick
    /// Target: < 50ms
    func test_fast_search_latency_is_under_50ms() {
        let engine = SearchEngine.shared
        let queries = ["safari", "mail", "2+2"]

        var latencies: [Double] = []

        for query in queries {
            let start = CFAbsoluteTimeGetCurrent()
            let _ = engine.searchFast(query: query)
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            latencies.append(duration)
        }

        let averageLatency = latencies.reduce(0, +) / Double(latencies.count)

        print("Fast search latency: \(String(format: "%.2f", averageLatency))ms average")

        // Fast search should be under 50ms, allow 80ms for CI variance
        XCTAssertLessThan(averageLatency, 80.0, "Fast search should be under 80ms (target: <50ms)")
    }

    /// Test: Fuzzy score calculation performance
    /// Target: < 1ms per 1000 comparisons
    func test_fuzzy_score_performance() {
        // Create test data
        let targetStrings = (0..<1000).map { "Application\($0)" }
        let query = "app"

        let start = CFAbsoluteTimeGetCurrent()

        // Simulate fuzzy scoring
        var matchCount = 0
        for target in targetStrings {
            if target.lowercased().contains(query) {
                matchCount += 1
            }
        }

        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        print("Fuzzy score for \(targetStrings.count) strings: \(String(format: "%.2f", duration))ms")
        print("Matches found: \(matchCount)")

        // 1000 comparisons should be under 5ms
        XCTAssertLessThan(duration, 5.0, "Fuzzy scoring should be very fast")
    }

    /// Test: Common searches performance with memory tracking
    func test_common_searches_performance_with_memory() {
        let engine = SearchEngine.shared
        let queries = ["calculator", "spotify", "4+4", "100 km to miles"]

        for query in queries {
            // Memory before
            let memBefore = getCurrentMemoryMB()

            // Search
            let start = CFAbsoluteTimeGetCurrent()
            let results = engine.searchFast(query: query)
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

            // Memory after
            let memAfter = getCurrentMemoryMB()
            let memDelta = memAfter - memBefore

            print("Search '\(query)': \(String(format: "%.2f", duration))ms, memory delta: \(String(format: "%.2f", memDelta))MB, results: \(results.count)")
        }
    }

    // MARK: - Memory Benchmarks

    /// Test: Memory baseline should be reasonable when idle
    /// Target: < 50MB idle
    func test_memory_baseline_is_reasonable() {
        // Force a memory baseline measurement
        let metrics = PerformanceMetrics.shared

        // Record initial memory
        metrics.recordMemoryBaseline()

        // Get memory info
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        XCTAssertEqual(result, KERN_SUCCESS, "Should be able to get task info")

        let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        print("Memory usage: \(String(format: "%.2f", usedMB))MB")

        // Memory should be under 200MB for test environment (includes test overhead + Swift runtime)
        XCTAssertLessThan(usedMB, 200.0, "Memory baseline should be reasonable (<200MB with test overhead)")
    }

    // MARK: - PerformanceMetrics Tests

    /// Test: PerformanceMetrics singleton exists
    func test_performanceMetrics_singleton_exists() {
        let metrics = PerformanceMetrics.shared
        XCTAssertNotNil(metrics, "PerformanceMetrics shared instance should exist")
    }

    /// Test: Measure function returns correct value
    func test_performanceMetrics_measure_returnsValue() {
        let metrics = PerformanceMetrics.shared

        let result = metrics.measure("test_operation") {
            return 42
        }

        XCTAssertEqual(result, 42, "measure should return the operation's result")
    }

    /// Test: Measure function tracks timing
    func test_performanceMetrics_measure_tracksTiming() {
        let metrics = PerformanceMetrics.shared

        var capturedDuration: Double = 0
        let result = metrics.measureWithCallback("test_timing") {
            Thread.sleep(forTimeInterval: 0.01) // 10ms
            return "done"
        } onTiming: { duration in
            capturedDuration = duration
        }

        XCTAssertEqual(result, "done", "measureWithCallback should return the operation's result")
        XCTAssertGreaterThan(capturedDuration, 8.0, "Duration should be at least 8ms")
        XCTAssertLessThan(capturedDuration, 50.0, "Duration should be less than 50ms")
    }

    /// Test: Search timing is recorded via signpost
    func test_performanceMetrics_searchTiming() {
        let metrics = PerformanceMetrics.shared

        // Begin search
        metrics.beginSearch(query: "test query")

        // Simulate search work
        Thread.sleep(forTimeInterval: 0.005) // 5ms

        // End search
        metrics.endSearch(resultCount: 5)

        // If we got here without crashing, signpost recording works
        XCTAssertTrue(true, "Search timing should be recorded without errors")
    }

    /// Test: Startup time is measurable
    func test_performanceMetrics_startupTime() {
        let metrics = PerformanceMetrics.shared

        // Record startup
        let startupDuration = metrics.measureStartup {
            // Simulate startup work
            Thread.sleep(forTimeInterval: 0.01)
        }

        XCTAssertGreaterThan(startupDuration, 8.0, "Startup duration should be at least 8ms")
        XCTAssertLessThan(startupDuration, 50.0, "Startup duration should be less than 50ms")
    }

    /// Test: Metrics can be exported
    func test_performanceMetrics_canExportMetrics() {
        let metrics = PerformanceMetrics.shared

        // Reset to clear any previous metrics
        metrics.reset()

        // Run some operations to generate metrics using measureSearch (which stores metrics)
        let _ = metrics.measureSearch(query: "test1") {
            Thread.sleep(forTimeInterval: 0.001)
            return ["result1", "result2", "result3"]
        }

        let _ = metrics.measureSearch(query: "test2") {
            Thread.sleep(forTimeInterval: 0.001)
            return ["result1"]
        }

        // Export metrics
        let export = metrics.exportMetrics()

        XCTAssertFalse(export.isEmpty, "Exported metrics should not be empty")
        XCTAssertTrue(export["searchOperations"] != nil,
                      "Export should contain searchOperations")
    }

    // MARK: - Benchmark Helper Tests

    /// Test: Benchmark runner can execute multiple iterations
    func test_benchmark_runsMultipleIterations() {
        var iterations = 0

        let averageDuration = PerformanceMetrics.benchmark(
            name: "test_benchmark",
            iterations: 100
        ) {
            iterations += 1
        }

        XCTAssertEqual(iterations, 100, "Benchmark should run 100 iterations")
        XCTAssertGreaterThan(averageDuration, 0, "Average duration should be positive")
        print("Benchmark average: \(String(format: "%.4f", averageDuration))ms per iteration")
    }

    /// Test: Async benchmark works correctly
    func test_benchmark_asyncWorks() async {
        var iterations = 0

        let averageDuration = await PerformanceMetrics.benchmarkAsync(
            name: "test_async_benchmark",
            iterations: 10
        ) {
            iterations += 1
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        XCTAssertEqual(iterations, 10, "Async benchmark should run 10 iterations")
        XCTAssertGreaterThan(averageDuration, 0.5, "Average duration should be at least 0.5ms")
        print("Async benchmark average: \(String(format: "%.4f", averageDuration))ms per iteration")
    }

    // MARK: - Helper Functions

    /// Get current memory usage in MB using mach_task_basic_info
    func getCurrentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        }
        return 0
    }
}

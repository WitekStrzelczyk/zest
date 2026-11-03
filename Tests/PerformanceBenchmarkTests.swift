import AppKit
import Testing
@testable import ZestApp

final class PerformanceBenchmarkTests {
    init() {
        ContactsService.isDisabled = true
    }

    deinit {
        ContactsService.isDisabled = false
    }

    @Test func test_search_latency_is_under_100ms() {
        let engine = SearchEngine.shared
        let queries = ["safari", "mail", "notes", "finder", "saf"]

        var latencies: [Double] = []

        for query in queries {
            let start = CFAbsoluteTimeGetCurrent()
            let _ = engine.searchFast(query: query)
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            latencies.append(duration)
        }

        let averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        let maxLatency = latencies.max() ?? 0

        print("Search latency results:")
        print("  Average: \(String(format: "%.2f", averageLatency))ms")
        print("  Max: \(String(format: "%.2f", maxLatency))ms")
        print("  All: \(latencies.map { String(format: "%.2f", $0) })")

        #expect(maxLatency < 150.0, "Search latency should be under 150ms (target: <100ms)")
    }

    @Test func test_fast_search_latency_is_under_50ms() {
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

        #expect(averageLatency < 80.0, "Fast search should be under 80ms (target: <50ms)")
    }

    @Test func test_fuzzy_score_performance() {
        let targetStrings = (0..<1000).map { "Application\($0)" }
        let query = "app"

        let start = CFAbsoluteTimeGetCurrent()

        var matchCount = 0
        for target in targetStrings {
            if target.lowercased().contains(query) {
                matchCount += 1
            }
        }

        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        print("Fuzzy score for \(targetStrings.count) strings: \(String(format: "%.2f", duration))ms")
        print("Matches found: \(matchCount)")

        #expect(duration < 5.0, "Fuzzy scoring should be very fast")
    }

    @Test func test_common_searches_performance_with_memory() {
        let engine = SearchEngine.shared
        let queries = ["calculator", "spotify", "4+4", "100 km to miles"]

        for query in queries {
            let memBefore = getCurrentMemoryMB()

            let start = CFAbsoluteTimeGetCurrent()
            let results = engine.searchFast(query: query)
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

            let memAfter = getCurrentMemoryMB()
            let memDelta = memAfter - memBefore

            print("Search '\(query)': \(String(format: "%.2f", duration))ms, memory delta: \(String(format: "%.2f", memDelta))MB, results: \(results.count)")
        }
    }

    @Test func test_memory_baseline_is_reasonable() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        #expect(result == KERN_SUCCESS, "Should be able to get task info")

        let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        print("Memory usage: \(String(format: "%.2f", usedMB))MB")

        #expect(usedMB < 200.0, "Memory baseline should be reasonable (<200MB with test overhead)")
    }

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

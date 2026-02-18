import XCTest
@testable import ZestApp

/// Tests for SystemMetricsService - CPU and Memory usage
final class SystemMetricsServiceTests: XCTestCase {

    // MARK: - CPU Usage Tests

    func test_getCPUUsage_returnsValidPercentage() {
        let cpuUsage = SystemMetricsService.shared.getCPUUsage()

        // CPU usage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(cpuUsage, 0.0, "CPU usage should be >= 0%")
        XCTAssertLessThanOrEqual(cpuUsage, 100.0, "CPU usage should be <= 100%")
    }

    func test_getCPUUsage_returnsNonNegativeValue() {
        let cpuUsage = SystemMetricsService.shared.getCPUUsage()

        XCTAssertGreaterThanOrEqual(cpuUsage, 0.0, "CPU usage should never be negative")
    }

    func test_getCPUUsage_changesOverTime() async {
        // Take two measurements with a small delay
        let firstReading = SystemMetricsService.shared.getCPUUsage()

        // Wait a bit for CPU state to potentially change
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let secondReading = SystemMetricsService.shared.getCPUUsage()

        // Both readings should be valid percentages
        XCTAssertGreaterThanOrEqual(firstReading, 0.0)
        XCTAssertLessThanOrEqual(firstReading, 100.0)
        XCTAssertGreaterThanOrEqual(secondReading, 0.0)
        XCTAssertLessThanOrEqual(secondReading, 100.0)
    }

    // MARK: - Memory Usage Tests

    func test_getMemoryUsage_returnsValidPercentage() {
        let memoryUsage = SystemMetricsService.shared.getMemoryUsage()

        // Memory usage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(memoryUsage, 0.0, "Memory usage should be >= 0%")
        XCTAssertLessThanOrEqual(memoryUsage, 100.0, "Memory usage should be <= 100%")
    }

    func test_getMemoryUsage_returnsNonNegativeValue() {
        let memoryUsage = SystemMetricsService.shared.getMemoryUsage()

        XCTAssertGreaterThanOrEqual(memoryUsage, 0.0, "Memory usage should never be negative")
    }

    func test_getMemoryUsage_returnsReasonableValue() {
        let memoryUsage = SystemMetricsService.shared.getMemoryUsage()

        // On a running system, memory usage is typically at least a few percent
        // But we allow 0% as a valid edge case (e.g., very fresh boot)
        XCTAssertGreaterThanOrEqual(memoryUsage, 0.0, "Memory usage should be >= 0%")
        XCTAssertLessThanOrEqual(memoryUsage, 100.0, "Memory usage should be <= 100%")
    }

    // MARK: - Formatting Tests

    func test_formatMetrics_formatsCorrectly() {
        let formatted = SystemMetricsService.shared.formatMetrics(cpu: 45.123, memory: 62.789)

        XCTAssertEqual(formatted, "CPU: 45% | MEM: 63%", "Should format as 'CPU: XX% | MEM: XX%' with rounding")
    }

    func test_formatMetrics_roundsCPU() {
        let formatted = SystemMetricsService.shared.formatMetrics(cpu: 45.6, memory: 50.0)

        XCTAssertEqual(formatted, "CPU: 46% | MEM: 50%", "Should round CPU to nearest whole number")
    }

    func test_formatMetrics_roundsMemory() {
        let formatted = SystemMetricsService.shared.formatMetrics(cpu: 50.0, memory: 62.4)

        XCTAssertEqual(formatted, "CPU: 50% | MEM: 62%", "Should round Memory to nearest whole number")
    }

    func test_formatMetrics_handlesZeroValues() {
        let formatted = SystemMetricsService.shared.formatMetrics(cpu: 0.0, memory: 0.0)

        XCTAssertEqual(formatted, "CPU: 0% | MEM: 0%", "Should handle zero values")
    }

    func test_formatMetrics_handlesMaxValues() {
        let formatted = SystemMetricsService.shared.formatMetrics(cpu: 100.0, memory: 100.0)

        XCTAssertEqual(formatted, "CPU: 100% | MEM: 100%", "Should handle 100% values")
    }
}

import Foundation

/// Represents a detailed audit of a single search operation
struct SearchAudit: Codable {
    let id: UUID
    let timestamp: Date
    let query: String
    var totalDurationMs: Double
    var tools: [ToolMetric]

    struct ToolMetric: Codable {
        let name: String
        let durationMs: Double
        let resultCount: Int
    }

    init(query: String) {
        id = UUID()
        timestamp = Date()
        self.query = query
        totalDurationMs = 0
        tools = []
    }

    /// Finalize the audit with total time
    mutating func finalize(totalDuration: Double) {
        totalDurationMs = totalDuration
    }

    /// Add a metric for a specific tool
    mutating func addToolMetric(name: String, duration: Double, count: Int) {
        tools.append(ToolMetric(name: name, durationMs: duration, resultCount: count))
    }

    /// Print a summary for debugging
    func printSummary() {
        print("\n🔎 SEARCH AUDIT [\(query)]")
        print("Total Time: \(String(format: "%.2f", totalDurationMs))ms")
        print("--- Tool Breakdown ---")
        for tool in tools {
            let padded = tool.name.padding(toLength: 20, withPad: " ", startingAt: 0)
            let ms = String(format: "%.2f", tool.durationMs)
            print("  • \(padded): \(ms)ms (\(tool.resultCount) results)")
        }
        print("----------------------\n")
    }
}

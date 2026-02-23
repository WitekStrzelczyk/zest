import Foundation

/// A span represents a unit of work with timing and metadata
/// Inspired by DataDog APM tracing
class SearchSpan {
    let operationName: String
    let startTime: Date
    var endTime: Date?
    var durationMs: Int { endTime.map { Int($0.timeIntervalSince(startTime) * 1000) } ?? 0 }
    
    private(set) var tags: [String: Any] = [:]
    private(set) var children: [SearchSpan] = []
    private let lock = NSLock()
    
    init(operationName: String) {
        self.operationName = operationName
        self.startTime = Date()
    }
    
    /// Finish this span
    @discardableResult
    func finish() -> Self {
        lock.lock()
        defer { lock.unlock() }
        endTime = Date()
        return self
    }
    
    /// Add a tag to this span
    @discardableResult
    func setTag(_ key: String, _ value: Any) -> Self {
        lock.lock()
        defer { lock.unlock() }
        tags[key] = value
        return self
    }
    
    /// Create a child span
    func createChild(operationName: String) -> SearchSpan {
        let child = SearchSpan(operationName: operationName)
        lock.lock()
        children.append(child)
        lock.unlock()
        return child
    }
    
    /// Get total duration including all children
    var totalDurationMs: Int {
        let childTotal = children.reduce(0) { $0 + $1.totalDurationMs }
        return durationMs + childTotal
    }
    
    /// Convert to a readable string representation
    func toString(indent: Int = 0) -> String {
        let indentStr = String(repeating: "  ", count: indent)
        var result = "\(indentStr)└─ \(operationName): \(durationMs)ms"
        
        if !tags.isEmpty {
            let tagsStr = tags.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            result += " [\(tagsStr)]"
        }
        
        for child in children {
            result += "\n" + child.toString(indent: indent + 1)
        }
        
        return result
    }
    
    /// Convert to dictionary for structured output
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "operation": operationName,
            "duration_ms": durationMs,
            "start_time": ISO8601DateFormatter().string(from: startTime)
        ]
        
        if let endTime {
            dict["end_time"] = ISO8601DateFormatter().string(from: endTime)
        }
        
        if !tags.isEmpty {
            dict["tags"] = tags
        }
        
        if !children.isEmpty {
            dict["children"] = children.map { $0.toDictionary() }
        }
        
        return dict
    }
}

/// Search-specific span with convenience methods
class SearchTraceSpan: SearchSpan {
    /// Record the number of results found
    @discardableResult
    func setResultsCount(_ count: Int) -> Self {
        setTag("results_count", count)
    }
    
    /// Record the query
    @discardableResult
    func setQuery(_ query: String) -> Self {
        setTag("query", query)
    }
    
    /// Record that this category had no matches
    @discardableResult
    func setNoMatch() -> Self {
        setTag("matched", false)
    }
    
    /// Record that this category had matches
    @discardableResult
    func setMatched() -> Self {
        setTag("matched", true)
    }
}

/// Manages search tracing and outputs metrics
final class SearchTracer {
    static let shared = SearchTracer()
    
    private let enabled: Bool
    private let outputEnabled: Bool
    
    private init() {
        // Enable tracing in DEBUG builds or via UserDefaults
        #if DEBUG
        enabled = true
        outputEnabled = UserDefaults.standard.bool(forKey: "searchTracingOutput")
        #else
        enabled = UserDefaults.standard.bool(forKey: "searchTracingEnabled")
        outputEnabled = UserDefaults.standard.bool(forKey: "searchTracingOutput")
        #endif
    }
    
    /// Enable/disable tracing output
    func setOutputEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "searchTracingOutput")
    }
    
    /// Start a new search trace
    func startSearch(query: String) -> SearchTraceSpan {
        let span = SearchTraceSpan(operationName: "search")
        span.setQuery(query)
        return span
    }
    
    /// Trace a category search (apps, files, etc.)
    func traceCategory(
        _ category: String,
        parent: SearchSpan,
        operation: (SearchTraceSpan) -> [Any]
    ) -> [Any] {
        guard enabled else { return operation(parent.createChild(operationName: category) as! SearchTraceSpan) }
        
        let span = parent.createChild(operationName: "category.\(category)") as! SearchTraceSpan
        span.setTag("category", category)
        
        let results = operation(span)
        span.setResultsCount(results.count)
        
        if results.isEmpty {
            span.setNoMatch()
        } else {
            span.setMatched()
        }
        
        span.finish()
        return results
    }
    
    /// Trace a specific operation
    func traceOperation<T>(
        _ name: String,
        parent: SearchSpan,
        operation: () -> T
    ) -> T {
        guard enabled else { return operation() }
        
        let span = parent.createChild(operationName: name)
        let result = operation()
        span.finish()
        return result
    }
    
    /// Trace fuzzy matching
    func traceFuzzyMatch(
        parent: SearchSpan,
        query: String,
        itemCount: Int,
        operation: () -> Int
    ) -> Int {
        guard enabled else { return operation() }
        
        let span = parent.createChild(operationName: "fuzzy.match")
        span.setTag("query_length", query.count)
        span.setTag("items_to_match", itemCount)
        
        let matchCount = operation()
        span.setTag("matches_found", matchCount)
        span.finish()
        
        return matchCount
    }
    
    /// Trace sorting
    func traceSorting(
        parent: SearchSpan,
        itemCount: Int,
        operation: () -> Void
    ) {
        guard enabled else { return operation() }
        
        let span = parent.createChild(operationName: "sort")
        span.setTag("items_to_sort", itemCount)
        operation()
        span.finish()
    }
    
    /// Output the trace results
    func outputTrace(_ span: SearchSpan) {
        guard outputEnabled else { return }
        
        print("\n📊 Search Trace:")
        print("=" * 50)
        print(span.toString())
        print("=" * 50)
        print("Total: \(span.totalDurationMs)ms\n")
    }
    
    /// Output trace as JSON
    func outputTraceJSON(_ span: SearchSpan) {
        guard outputEnabled else { return }
        
        let data = try? JSONSerialization.data(withJSONObject: span.toDictionary(), options: .prettyPrinted)
        if let data, let json = String(data: data, encoding: .utf8) {
            print("📊 Search Trace JSON:\n\(json)")
        }
    }
}

// MARK: - Convenience Extensions

extension SearchSpan {
    /// Create a typed child span for search operations
    func createSearchChild(operationName: String) -> SearchTraceSpan {
        return createChild(operationName: operationName) as! SearchTraceSpan
    }
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

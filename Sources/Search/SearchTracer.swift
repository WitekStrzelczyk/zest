import Foundation

class SearchSpan {
    let operationName: String
    let startTime: Date
    var endTime: Date?
    var resultCount: Int = 0

    var durationMs: Int {
        endTime.map { Int($0.timeIntervalSince(startTime) * 1000) } ?? 0
    }

    var durationMsPrecise: Double {
        endTime.map { $0.timeIntervalSince(startTime) * 1000 } ?? 0
    }

    private(set) var tags: [String: Any] = [:]
    private(set) var children: [SearchSpan] = []
    private let lock = NSLock()

    init(operationName: String) {
        self.operationName = operationName
        startTime = Date()
    }

    @discardableResult
    func finish() -> Self {
        lock.lock()
        defer { lock.unlock() }
        endTime = Date()
        return self
    }

    @discardableResult
    func setTag(_ key: String, _ value: Any) -> Self {
        lock.lock()
        defer { lock.unlock() }
        tags[key] = value
        return self
    }

    func setResultsCount(_ count: Int) {
        resultCount = count
        setTag("results_count", count)
    }

    func createChild(operationName: String) -> SearchSpan {
        let child = SearchSpan(operationName: operationName)
        lock.lock()
        children.append(child)
        lock.unlock()
        return child
    }

    var totalDurationMs: Int {
        let childTotal = children.reduce(0) { $0 + $1.totalDurationMs }
        return durationMs + childTotal
    }

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

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "operation": operationName,
            "duration_ms": durationMs,
            "start_time": ISO8601DateFormatter().string(from: startTime),
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

    func toAudit(query: String) -> SearchAudit {
        var audit = SearchAudit(query: query)
        audit.finalize(totalDuration: durationMsPrecise)

        func processChildren(of parent: SearchSpan) {
            for child in parent.children {
                if child.operationName.contains("broadcast") {
                    processChildren(of: child)
                } else {
                    audit.addToolMetric(
                        name: child.operationName,
                        duration: child.durationMsPrecise,
                        count: child.resultCount
                    )
                }
            }
        }

        processChildren(of: self)
        return audit
    }
}

class SearchTraceSpan: SearchSpan {
    @discardableResult
    func setResultsCountSpan(_ count: Int) -> Self {
        setResultsCount(count)
        return self
    }

    @discardableResult
    func setQuery(_ query: String) -> Self {
        setTag("query", query)
        return self
    }

    @discardableResult
    func setNoMatch() -> Self {
        setTag("matched", false)
        return self
    }

    @discardableResult
    func setMatched() -> Self {
        setTag("matched", true)
        return self
    }
}

final class SearchTracer {
    static let shared = SearchTracer()

    private let enabled: Bool
    private let outputEnabled: Bool

    private init() {
        #if DEBUG
            enabled = true
            outputEnabled = UserDefaults.standard.bool(forKey: "searchTracingOutput")
        #else
            enabled = UserDefaults.standard.bool(forKey: "searchTracingEnabled")
            outputEnabled = UserDefaults.standard.bool(forKey: "searchTracingOutput")
        #endif
    }

    func setOutputEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "searchTracingOutput")
    }

    func startSearch(query: String) -> SearchTraceSpan {
        let span = SearchTraceSpan(operationName: "search")
        span.setQuery(query)
        return span
    }

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

    func outputTrace(_ span: SearchSpan, query: String) {
        guard outputEnabled else { return }

        span.toAudit(query: query).printSummary()

        print("\n📊 Detailed Search Trace:")
        print("=" * 50)
        print(span.toString())
        print("=" * 50)
        print("Total: \(span.totalDurationMs)ms\n")
    }

    func outputTraceJSON(_ span: SearchSpan) {
        guard outputEnabled else { return }

        let data = try? JSONSerialization.data(withJSONObject: span.toDictionary(), options: .prettyPrinted)
        if let data, let json = String(data: data, encoding: .utf8) {
            print("📊 Search Trace JSON:\n\(json)")
        }
    }
}

extension SearchSpan {
    func createSearchChild(operationName: String) -> SearchTraceSpan {
        createChild(operationName: operationName) as! SearchTraceSpan
    }
}

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

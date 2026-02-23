import XCTest
@testable import ZestApp

final class SearchTracerTests: XCTestCase {
    
    var tracer: SearchTracer!
    
    override func setUp() {
        super.setUp()
        tracer = SearchTracer.shared
        tracer.setOutputEnabled(true)
    }
    
    override func tearDown() {
        tracer.setOutputEnabled(false)
        super.tearDown()
    }
    
    // MARK: - Span Tests
    
    func test_span_recordsDuration() {
        let span = SearchSpan(operationName: "test")
        Thread.sleep(forTimeInterval: 0.01) // 10ms
        span.finish()
        
        XCTAssertGreaterThanOrEqual(span.durationMs, 10)
    }
    
    func test_span_recordsTags() {
        let span = SearchSpan(operationName: "test")
        span.setTag("query", "test query")
        span.setTag("count", 5)
        span.finish()
        
        XCTAssertEqual(span.tags["query"] as? String, "test query")
        XCTAssertEqual(span.tags["count"] as? Int, 5)
    }
    
    func test_span_recordsChildren() {
        let parent = SearchSpan(operationName: "parent")
        let child1 = parent.createChild(operationName: "child1")
        let child2 = parent.createChild(operationName: "child2")
        
        child1.finish()
        child2.finish()
        parent.finish()
        
        XCTAssertEqual(parent.children.count, 2)
        XCTAssertEqual(parent.children[0].operationName, "child1")
        XCTAssertEqual(parent.children[1].operationName, "child2")
    }
    
    func test_span_totalDuration_includesChildren() {
        let parent = SearchSpan(operationName: "parent")
        let child = parent.createChild(operationName: "child")
        Thread.sleep(forTimeInterval: 0.01)
        child.finish()
        parent.finish()
        
        XCTAssertGreaterThanOrEqual(parent.totalDurationMs, parent.durationMs)
    }
    
    // MARK: - TraceSpan Tests
    
    func test_traceSpan_convenienceMethods() {
        let span = SearchTraceSpan(operationName: "search")
        span.setQuery("test")
        span.setResultsCount(5)
        span.finish()
        
        XCTAssertEqual(span.tags["query"] as? String, "test")
        XCTAssertEqual(span.tags["results_count"] as? Int, 5)
    }
    
    // MARK: - Output Tests
    
    func test_span_toString() {
        let parent = SearchSpan(operationName: "search")
        parent.setTag("query", "test")
        
        let child = parent.createChild(operationName: "applications")
        child.setTag("results", 3)
        child.finish()
        
        parent.finish()
        
        let output = parent.toString()
        XCTAssertTrue(output.contains("search"))
        XCTAssertTrue(output.contains("applications"))
        XCTAssertTrue(output.contains("query=test"))
        XCTAssertTrue(output.contains("results=3"))
    }
    
    func test_span_toDictionary() {
        let span = SearchSpan(operationName: "test")
        span.setTag("key", "value")
        span.finish()
        
        let dict = span.toDictionary()
        
        XCTAssertEqual(dict["operation"] as? String, "test")
        XCTAssertNotNil(dict["duration_ms"])
        XCTAssertNotNil(dict["start_time"])
        XCTAssertNotNil(dict["end_time"])
        XCTAssertNotNil(dict["tags"])
    }
}

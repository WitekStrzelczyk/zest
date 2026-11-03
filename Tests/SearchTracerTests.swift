import AppKit
import Testing
@testable import ZestApp

@MainActor
final class SearchTracerTests {
    var tracer: SearchTracer!
    
    init() {
        tracer = SearchTracer.shared
        tracer.setOutputEnabled(true)
    }
    
    isolated deinit {
        tracer.setOutputEnabled(false)
    }
    
    @Test func test_span_recordsDuration() {
        let span = SearchSpan(operationName: "test")
        Thread.sleep(forTimeInterval: 0.01)
        span.finish()
        
        #expect(span.durationMs >= 10)
    }
    
    @Test func test_span_recordsTags() {
        let span = SearchSpan(operationName: "test")
        span.setTag("query", "test query")
        span.setTag("count", 5)
        span.finish()
        
        #expect((span.tags["query"] as? String) == "test query")
        #expect((span.tags["count"] as? Int) == 5)
    }
    
    @Test func test_span_recordsChildren() {
        let parent = SearchSpan(operationName: "parent")
        let child1 = parent.createChild(operationName: "child1")
        let child2 = parent.createChild(operationName: "child2")
        
        child1.finish()
        child2.finish()
        parent.finish()
        
        #expect(parent.children.count == 2)
        #expect(parent.children[0].operationName == "child1")
        #expect(parent.children[1].operationName == "child2")
    }
    
    @Test func test_span_totalDuration_includesChildren() {
        let parent = SearchSpan(operationName: "parent")
        let child = parent.createChild(operationName: "child")
        Thread.sleep(forTimeInterval: 0.01)
        child.finish()
        parent.finish()
        
        #expect(parent.totalDurationMs >= parent.durationMs)
    }
    
    @Test func test_traceSpan_convenienceMethods() {
        let span = SearchTraceSpan(operationName: "search")
        span.setQuery("test")
        span.setResultsCount(5)
        span.finish()
        
        #expect((span.tags["query"] as? String) == "test")
        #expect((span.tags["results_count"] as? Int) == 5)
    }
    
    @Test func test_span_toString() {
        let parent = SearchSpan(operationName: "search")
        parent.setTag("query", "test")
        
        let child = parent.createChild(operationName: "applications")
        child.setTag("results", 3)
        child.finish()
        
        parent.finish()
        
        let output = parent.toString()
        #expect(output.contains("search"))
        #expect(output.contains("applications"))
        #expect(output.contains("query=test"))
        #expect(output.contains("results=3"))
    }
    
    @Test func test_span_toDictionary() {
        let span = SearchSpan(operationName: "test")
        span.setTag("key", "value")
        span.finish()
        
        let dict = span.toDictionary()
        
        #expect((dict["operation"] as? String) == "test")
        #expect(dict["duration_ms"] != nil)
        #expect(dict["start_time"] != nil)
        #expect(dict["end_time"] != nil)
        #expect(dict["tags"] != nil)
    }
}

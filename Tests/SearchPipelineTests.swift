import AppKit
import Testing
@testable import ZestApp

@MainActor
final class SearchPipelineTests {
    @Test func testSearchAuditGeneration() {
        let tracer = SearchTracer.shared
        let query = "test audit query"
        let span = tracer.startSearch(query: query)
        
        let child = span.createChild(operationName: "MockTool")
        Thread.sleep(forTimeInterval: 0.05)
        child.setResultsCount(10)
        child.finish()
        
        span.finish()
        
        let audit = span.toAudit(query: query)
        
        #expect(audit.query == query)
        #expect(audit.totalDurationMs >= 50.0)
        #expect(audit.tools.count == 1)
        #expect(audit.tools.first?.name == "MockTool")
        #expect(audit.tools.first?.resultCount == 10)
    }
    
    @Test func testCalendarLocationExtraction() {
        let worker = CalendarEventWorker.shared
        let query = "meeting with john at Perigian Digital Hub"
        
        let intent = worker.parse(context: QueryAnalyzer.shared.analyze(query))
        
        #expect(intent?.title == "John")
        #expect(intent?.location == "Perigian Digital Hub")
    }
}

import XCTest
@testable import ZestApp

final class SearchPipelineTests: XCTestCase {
    
    func testSearchAuditGeneration() {
        let tracer = SearchTracer.shared
        let query = "test audit query"
        let span = tracer.startSearch(query: query)
        
        // Simulate a tool execution
        let child = span.createChild(operationName: "MockTool")
        Thread.sleep(forTimeInterval: 0.05) // 50ms
        child.setResultsCount(10)
        child.finish()
        
        span.finish()
        
        let audit = span.toAudit(query: query)
        
        XCTAssertEqual(audit.query, query)
        XCTAssertGreaterThanOrEqual(audit.totalDurationMs, 50.0)
        XCTAssertEqual(audit.tools.count, 1)
        XCTAssertEqual(audit.tools.first?.name, "MockTool")
        XCTAssertEqual(audit.tools.first?.resultCount, 10)
    }
    
    func testMultiIntentRouterLogic() {
        let router = CommandRouter.shared
        let query = "meeting with john at Perigian Digital Hub"
        
        let domains = router.route(command: query)
        
        // Router should trigger both calendar and maps based on heuristics + bayes
        XCTAssertTrue(domains.contains(.calendarEvent))
        XCTAssertTrue(domains.contains(.mapLocation))
    }
    
    func testCalendarLocationExtraction() {
        let worker = CalendarEventWorker.shared
        let query = "meeting with john at Perigian Digital Hub"
        
        let intent = worker.parse(context: QueryAnalyzer.shared.analyze(query))
        
        XCTAssertEqual(intent?.title, "John")
        XCTAssertEqual(intent?.location, "Perigian Digital Hub")
    }
}

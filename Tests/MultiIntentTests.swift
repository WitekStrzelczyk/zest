import AppKit
import Testing
@testable import ZestApp

final class MultiIntentTests {
    @Test func testLocationExtractionFromCalendar() {
        let worker = CalendarEventWorker.shared
        let query = "meeting with john today at 10am at Perigian Digital Hub"
        
        let intent = worker.parse(context: QueryAnalyzer.shared.analyze(query))
        
        print("🧪 Test: Parsed location: \(intent?.location ?? "nil")")
        
        #expect(intent?.location != nil)
        #expect(intent?.location?.contains("Perigian") ?? false)
    }
    
    @Test func testSearchEngineMultiResult() {
        let engine = SearchEngine.shared
        let query = "meeting with john today at 10am at Perigian Digital Hub"
        
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        defer {
            ContactsService.isDisabled = false
            CalendarService.isDisabled = false
        }
        
        let results = engine.searchFast(query: query)
        
        let hasCalendar = results.contains { $0.title.contains("Add Event") }
        let hasMap = results.contains { $0.title.contains("Search Map") }
        
        #expect(hasCalendar, "Fast search should include calendar proposal")
        #expect(hasMap, "Fast search should include map proposal")
    }
}

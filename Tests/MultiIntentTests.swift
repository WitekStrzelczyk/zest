import XCTest
@testable import ZestApp

final class MultiIntentTests: XCTestCase {
    
    func testMultiIntentDetection() {
        let router = CommandRouter.shared
        let query = "meeting with john today at 10am at Perigian Digital Hub"
        
        let domains = router.route(command: query)
        
        print("🧪 Test: Detected domains for '\(query)': \(domains.map { $0.rawValue })")
        
        XCTAssertTrue(domains.contains(.calendarEvent), "Should detect calendar intent")
        XCTAssertTrue(domains.contains(.mapLocation), "Should detect map/location intent")
    }
    
    func testLocationExtractionFromCalendar() {
        let worker = CalendarEventWorker.shared
        let query = "meeting with john today at 10am at Perigian Digital Hub"
        
        let intent = worker.parse(command: query)
        
        print("🧪 Test: Parsed location: \(intent?.location ?? "nil")")
        
        XCTAssertNotNil(intent?.location)
        XCTAssertTrue(intent?.location?.contains("Perigian") ?? false)
    }
    
    func testSearchEngineMultiResult() {
        let engine = SearchEngine.shared
        let query = "meeting with john today at 10am at Perigian Digital Hub"
        
        // Disable restricted services that hang in tests
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        defer {
            ContactsService.isDisabled = false
            CalendarService.isDisabled = false
        }
        
        let results = engine.searchFast(query: query)
        
        let hasCalendar = results.contains { $0.title.contains("Add Event") }
        let hasMap = results.contains { $0.title.contains("Search Map") }
        
        XCTAssertTrue(hasCalendar, "Fast search should include calendar proposal")
        XCTAssertTrue(hasMap, "Fast search should include map proposal")
    }
}

import XCTest
@testable import ZestApp

final class SystemAppTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Disable restricted services before SearchEngine is even touched
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        FileSearchService.isDisabled = true
    }

    func testSystemAppsAreIndexed() {
        let engine = SearchEngine.shared
        
        // Trigger indexing
        engine.refreshInstalledApps()
        
        // Search for Calendar
        let results = engine.search(query: "Calendar")
        
        let hasCalendarApp = results.contains { $0.title == "Calendar" && $0.category == .application }
        XCTAssertTrue(hasCalendarApp, "Should find Calendar app in /System/Applications")
    }
    
    func testCalculatorIsIndexed() {
        let engine = SearchEngine.shared
        engine.refreshInstalledApps()
        
        let results = engine.search(query: "Calculator")
        let hasCalcApp = results.contains { $0.title == "Calculator" && $0.category == .application }
        
        XCTAssertTrue(hasCalcApp, "Should find Calculator app")
    }
}

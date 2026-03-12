import XCTest
@testable import ZestApp

final class FileSearchWorkerTests: XCTestCase {
    
    func testIntentParsing() {
        let worker = FileSearchWorker.shared
        let analyzer = QueryAnalyzer.shared
        
        // 1. Extension + Date
        let context1 = analyzer.analyze("pdf modified today")
        let intent1 = worker.parse(context: context1)
        XCTAssertEqual(intent1.fileExtension, "pdf")
        XCTAssertEqual(intent1.dateType, .modified)
        XCTAssertNotNil(intent1.date)
        
        let startOfToday = Calendar.current.startOfDay(for: Date())
        if let detectedDate = intent1.date {
            XCTAssertEqual(Calendar.current.startOfDay(for: detectedDate), startOfToday)
        }
        
        // 2. Large + Extension
        let context2 = analyzer.analyze("large images")
        let intent2 = worker.parse(context: context2)
        XCTAssertTrue(intent2.isLarge)
        XCTAssertNil(intent2.searchTerm) // "images" is a common word removed or extension detected?
        
        // 3. Search Term + Date Offset
        let context3 = analyzer.analyze("invoice created 2 days ago")
        let intent3 = worker.parse(context: context3)
        XCTAssertEqual(intent3.searchTerm, "invoice")
        XCTAssertEqual(intent3.dateType, .created)
        XCTAssertNotNil(intent3.date)
    }
    
    func testPredicateLogic() {
        let worker = FileSearchWorker.shared
        
        // Case: Only one filter (Should NOT be compound)
        let intent1 = FileSearchIntent(searchTerm: "report")
        let p1 = worker.buildPredicate(from: intent1)
        XCTAssertFalse(p1 is NSCompoundPredicate, "Single filter should be simple comparison predicate")
        XCTAssertTrue(p1.predicateFormat.contains("kMDItemDisplayName"))
        
        // Case: Two filters (Should BE compound)
        let intent2 = FileSearchIntent(fileExtension: "pdf", date: Date(), dateType: .modified)
        let p2 = worker.buildPredicate(from: intent2)
        XCTAssertTrue(p2 is NSCompoundPredicate, "Multiple filters should be compound predicate")
        
        // Case: Empty (Wildcard)
        let intent3 = FileSearchIntent()
        let p3 = worker.buildPredicate(from: intent3)
        XCTAssertEqual(p3.predicateFormat, "kMDItemFSName == \"*\"")
    }
}

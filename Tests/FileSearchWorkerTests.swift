import XCTest
@testable import ZestApp

final class FileSearchWorkerTests: XCTestCase {
    
    func testIntentParsing() {
        let worker = FileSearchWorker.shared
        
        // 1. Extension + Date
        let intent1 = worker.parse(command: "pdf modified today")
        XCTAssertEqual(intent1.fileExtension, "pdf")
        XCTAssertEqual(intent1.dateType, .modified)
        XCTAssertNotNil(intent1.date)
        
        // 2. Large + Extension
        let intent2 = worker.parse(command: "large images")
        XCTAssertTrue(intent2.isLarge)
        XCTAssertNil(intent2.searchTerm) // "images" is a common word removed or extension detected?
        
        // 3. Search Term + Date Offset
        let intent3 = worker.parse(command: "invoice created 2 days ago")
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

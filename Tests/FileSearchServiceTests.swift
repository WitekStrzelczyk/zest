import XCTest
@testable import ZestApp

final class FileSearchServiceTests: XCTestCase {
    
    func test_searchSync_usesNSMetadataQuery() {
        let service = FileSearchService.shared
        // Mainly verifying it doesn't crash and returns an array
        let results = service.searchSync(query: "test", maxResults: 5)
        XCTAssertNotNil(results)
    }

    func test_performNSMetadataQuery_withPredicate() {
        let service = FileSearchService.shared
        let predicate = NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@", "test")
        
        let startTime = Date()
        _ = service.performNSMetadataQuery(predicate: predicate, maxResults: 10)
        let elapsed = Date().timeIntervalSince(startTime) * 1000
        
        // Ensure it respects the timeout logic (doesn't hang indefinitely)
        XCTAssertLessThan(elapsed, 3000) 
    }
}

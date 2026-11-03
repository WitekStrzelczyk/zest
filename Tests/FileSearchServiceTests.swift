import AppKit
import Testing
@testable import ZestApp

final class FileSearchServiceTests {
    @Test func test_searchSync_usesNSMetadataQuery() {
        let service = FileSearchService.shared
        _ = service.searchSync(query: "test", maxResults: 5)
    }

    @Test func test_performNSMetadataQuery_withPredicate() {
        let service = FileSearchService.shared
        let predicate = NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@", "test")
        
        let startTime = Date()
        _ = service.performNSMetadataQuery(predicate: predicate, maxResults: 10)
        let elapsed = Date().timeIntervalSince(startTime) * 1000
        
        #expect(elapsed < 3000) 
    }
}

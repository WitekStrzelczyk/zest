import XCTest
@testable import ZestApp

/// Tests for File Search Service functionality
final class FileSearchServiceTests: XCTestCase {

    func testFileSearchServiceCreation() {
        let service = FileSearchService.shared
        XCTAssertNotNil(service)
    }

    func testFileSearchServiceSingleton() {
        let service1 = FileSearchService.shared
        let service2 = FileSearchService.shared
        XCTAssertTrue(service1 === service2)
    }

    func testEmptySearchQuery() {
        let service = FileSearchService.shared
        let results = service.searchSync(query: "", maxResults: 10)
        XCTAssertTrue(results.isEmpty)
    }

    func testFileSearchByName() {
        let service = FileSearchService.shared
        let results = service.searchSync(query: "test", maxResults: 10)
        XCTAssertNotNil(results)
    }
}

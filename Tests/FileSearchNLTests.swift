import XCTest
@testable import ZestApp

final class FileSearchNLTests: XCTestCase {
    
    func testFindPackageSwiftNative() {
        let query = "file Package.swift"
        let worker = FileSearchWorker.shared
        let intent = worker.parse(command: query)
        let predicate = worker.buildPredicate(from: intent)
        
        print("🧪 Test: Generated Predicate: \(predicate.predicateFormat)")
        
        let service = FileSearchService.shared
        let results = service.searchSync(predicate: predicate, maxResults: 10)
        
        print("🧪 Test: Found \(results.count) results")
        for res in results {
            print("   - Found: \(res.title) at \(res.filePath ?? "unknown")")
        }
        
        XCTAssertGreaterThan(results.count, 0, "Should find Package.swift using NL logic")
    }

    func testFilesModified2DaysAgoActualResults() {
        let query = "files modified 2 days ago"
        let worker = FileSearchWorker.shared
        let intent = worker.parse(command: query)
        let predicate = worker.buildPredicate(from: intent)
        
        print("🧪 Test: Searching for real files with NL query: '\(query)'")
        print("🧪 Test: Generated Predicate: \(predicate.predicateFormat)")
        
        let service = FileSearchService.shared
        let results = service.searchSync(predicate: predicate, maxResults: 50)
        
        print("🧪 Test: Found \(results.count) real results via Service/Worker")
        for res in results.prefix(5) {
            print("   - Found: \(res.title) at \(res.filePath ?? "unknown")")
        }
        
        XCTAssertGreaterThan(results.count, 0, "The Service/Worker MUST find files modified in the last 2 days.")
    }
}

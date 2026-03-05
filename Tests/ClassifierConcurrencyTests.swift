import XCTest
@testable import ZestApp

final class ClassifierConcurrencyTests: XCTestCase {
    
    func testClassifierThreadSafety() {
        let router = CommandRouter.shared
        let queries = [
            "pdf files",
            "meeting with john",
            "convert 10kg to lbs",
            "directions to hub",
            "files modified today",
            "schedule appointment"
        ]
        
        let expectation = self.expectation(description: "Concurrent classification")
        expectation.expectedFulfillmentCount = 100
        
        // Blast the classifier with 100 simultaneous requests from different threads
        for _ in 0..<100 {
            DispatchQueue.global().async {
                let query = queries.randomElement()!
                let _ = router.route(command: query)
                expectation.fulfill()
            }
        }
        
        // If it doesn't crash within 5 seconds, it's thread-safe
        waitForExpectations(timeout: 5.0)
    }
}

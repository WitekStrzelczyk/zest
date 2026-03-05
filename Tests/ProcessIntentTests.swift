import XCTest
@testable import ZestApp

final class ProcessIntentTests: XCTestCase {
    
    func testProcessRouterDetection() {
        let router = CommandRouter.shared
        
        XCTAssertTrue(router.route(command: "process").contains(.processManagement))
        XCTAssertTrue(router.route(command: "process using port 8080").contains(.processManagement))
        XCTAssertTrue(router.route(command: "list processes").contains(.processManagement))
    }
    
    func testProcessWorkerParsing() {
        let worker = ProcessWorker.shared
        
        // 1. List All
        let intent1 = worker.parse(command: "processes")
        if case .listAll = intent1?.action { /* success */ } else { XCTFail("Should parse as listAll") }
        
        // 2. Port Lookup
        let intent2 = worker.parse(command: "process using port 3000")
        if case .findByPort(let port) = intent2?.action {
            XCTAssertEqual(port, 3000)
        } else { XCTFail("Should parse as findByPort") }
        
        // 3. Name filter
        let intent3 = worker.parse(command: "process zest")
        if case .filterByName(let name) = intent3?.action {
            XCTAssertEqual(name, "zest")
        } else { XCTFail("Should parse as filterByName") }
    }
    
    // We omit testSearchEngineProcessIntegration because SearchEngine instantiation 
    // triggers restricted system services (Contacts/XPC) that crash in this environment.
}

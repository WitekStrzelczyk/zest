import AppKit
import Testing
@testable import ZestApp

@MainActor
final class ProcessIntentTests {
    @Test func testProcessWorkerParsing() {
        let worker = ProcessWorker.shared
        
        let intent1 = worker.parse(context: QueryAnalyzer.shared.analyze("processes"))
        if case .listAll = intent1?.action {  } else { Issue.record("Should parse as listAll") }
        
        let intent2 = worker.parse(context: QueryAnalyzer.shared.analyze("process using port 3000"))
        if case .findByPort(let port) = intent2?.action {
            #expect(port == 3000)
        } else { Issue.record("Should parse as findByPort") }
        
        let intent3 = worker.parse(context: QueryAnalyzer.shared.analyze("process zest"))
        if case .filterByName(let name) = intent3?.action {
            #expect(name == "zest")
        } else { Issue.record("Should parse as filterByName") }
    }
}

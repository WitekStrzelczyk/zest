import AppKit
import Testing
@testable import ZestApp

@MainActor
final class FileSearchWorkerTests {
    @Test func testIntentParsing() {
        let worker = FileSearchWorker.shared
        let analyzer = QueryAnalyzer.shared
        
        let context1 = analyzer.analyze("pdf modified today")
        let intent1 = worker.parse(context: context1)
        #expect(intent1.fileExtension == "pdf")
        #expect(intent1.dateType == .modified)
        #expect(intent1.date != nil)
        
        let startOfToday = Calendar.current.startOfDay(for: Date())
        if let detectedDate = intent1.date {
            #expect(Calendar.current.startOfDay(for: detectedDate) == startOfToday)
        }
        
        let context2 = analyzer.analyze("large images")
        let intent2 = worker.parse(context: context2)
        #expect(intent2.isLarge)
        #expect(intent2.searchTerm == nil)
        
        let context3 = analyzer.analyze("invoice created 2 days ago")
        let intent3 = worker.parse(context: context3)
        #expect(intent3.searchTerm == "invoice")
        #expect(intent3.dateType == .created)
        #expect(intent3.date != nil)
    }
    
    @Test func testPredicateLogic() {
        let worker = FileSearchWorker.shared
        
        let intent1 = FileSearchIntent(searchTerm: "report")
        let p1 = worker.buildPredicate(from: intent1)
        #expect(!(p1 is NSCompoundPredicate), "Single filter should be simple comparison predicate")
        #expect(p1.predicateFormat.contains("kMDItemDisplayName"))
        
        let intent2 = FileSearchIntent(fileExtension: "pdf", date: Date(), dateType: .modified)
        let p2 = worker.buildPredicate(from: intent2)
        #expect(p2 is NSCompoundPredicate, "Multiple filters should be compound predicate")
        
        let intent3 = FileSearchIntent()
        let p3 = worker.buildPredicate(from: intent3)
        #expect(p3.predicateFormat == "kMDItemFSName == \"*\"")
    }
}

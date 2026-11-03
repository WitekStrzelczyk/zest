import AppKit
import Testing
@testable import ZestApp

@MainActor
final class NaturalLanguageTests {
    @Test func testUnitConversionWorker() {
        let worker = UnitConversionWorker.shared

        let intent1 = worker.parse(context: QueryAnalyzer.shared.analyze("convert 10 km to miles"))
        #expect(intent1 != nil)
        #expect(intent1?.value == 10.0)
        #expect(intent1?.fromUnit == "km")
        #expect(intent1?.toUnit == "miles")

        let intent2 = worker.parse(context: QueryAnalyzer.shared.analyze("50kg to lbs"))
        #expect(intent2 != nil)
        #expect(intent2?.value == 50.0)
        #expect(intent2?.fromUnit == "kg")
        #expect(intent2?.toUnit == "lbs")
    }

    @Test func testFileSearchWorker() {
        let worker = FileSearchWorker.shared

        let intent1 = worker.parse(context: QueryAnalyzer.shared.analyze("pdf files created today"))
        #expect(intent1.fileExtension == "pdf")
        #expect(intent1.dateType == .created)
        #expect(intent1.date != nil)

        let intent2 = worker.parse(context: QueryAnalyzer.shared.analyze("large txt files modified this year"))
        #expect(intent2.fileExtension == "txt")
        #expect(intent2.isLarge)
        #expect(intent2.dateType == .modified)
        #expect(intent2.date != nil)

        let intent3 = worker.parse(context: QueryAnalyzer.shared.analyze("files opened 55 minutes ago"))
        #expect(intent3.dateType == .opened)
        #expect(intent3.date != nil)
    }

    @Test func testCalendarEventWorker() {
        let worker = CalendarEventWorker.shared

        let intent1 = worker.parse(context: QueryAnalyzer.shared.analyze("meeting with John tomorrow at 9am in Coolum Beach Mc Donalds"))
        #expect(intent1 != nil)
        #expect(intent1?.title == "John")
        #expect(intent1?.date != nil)
        #expect(intent1?.location != nil)
    }
}

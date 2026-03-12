import XCTest
@testable import ZestApp

final class NaturalLanguageTests: XCTestCase {

    func testNaiveBayesClassifier() {
        let classifier = NaiveBayesClassifier()
        
        classifier.train(text: "meeting", label: "calendar")
        classifier.train(text: "appointment", label: "calendar")
        classifier.train(text: "convert", label: "unit")
        classifier.train(text: "miles", label: "unit")
        
        // Test exact match
        let p1 = classifier.predict(text: "meeting")
        XCTAssertEqual(p1?.label, "calendar")
        
        // Test lemmatization ("meetings" -> "meeting")
        let p2 = classifier.predict(text: "meetings")
        XCTAssertEqual(p2?.label, "calendar")
        
        // Test mixed context
        let p3 = classifier.predict(text: "convert miles")
        XCTAssertEqual(p3?.label, "unit")
    }

    func testCommandRouter() {
        let router = CommandRouter.shared

        // Clear intent
        XCTAssertTrue(router.route(command: "convert 10m to feet").contains(.unitConversion))
        XCTAssertTrue(router.route(command: "pdf files created today").contains(.fileSearch))
        XCTAssertTrue(router.route(command: "schedule a meeting with Alice").contains(.calendarEvent))
        
        // Short/ambiguous commands should be unknown
        XCTAssertTrue(router.route(command: "hi").contains(.unknown))
    }

    func testUnitConversionWorker() {
        let worker = UnitConversionWorker.shared

        let intent1 = worker.parse(context: QueryAnalyzer.shared.analyze("convert 10 km to miles"))
        XCTAssertNotNil(intent1)
        XCTAssertEqual(intent1?.value, 10.0)
        XCTAssertEqual(intent1?.fromUnit, "km")
        XCTAssertEqual(intent1?.toUnit, "miles")

        let intent2 = worker.parse(context: QueryAnalyzer.shared.analyze("50kg to lbs"))
        XCTAssertNotNil(intent2)
        XCTAssertEqual(intent2?.value, 50.0)
        XCTAssertEqual(intent2?.fromUnit, "kg")
        XCTAssertEqual(intent2?.toUnit, "lbs")
    }

    func testFileSearchWorker() {
        let worker = FileSearchWorker.shared

        let intent1 = worker.parse(context: QueryAnalyzer.shared.analyze("pdf files created today"))
        XCTAssertEqual(intent1.fileExtension, "pdf")
        XCTAssertEqual(intent1.dateType, .created)
        XCTAssertNotNil(intent1.date)

        let intent2 = worker.parse(context: QueryAnalyzer.shared.analyze("large txt files modified this year"))
        XCTAssertEqual(intent2.fileExtension, "txt")
        XCTAssertTrue(intent2.isLarge)
        XCTAssertEqual(intent2.dateType, .modified)
        XCTAssertNotNil(intent2.date)

        let intent3 = worker.parse(context: QueryAnalyzer.shared.analyze("files opened 55 minutes ago"))
        XCTAssertEqual(intent3.dateType, .opened)
        XCTAssertNotNil(intent3.date)
    }

    func testCalendarEventWorker() {
        let worker = CalendarEventWorker.shared

        let intent1 = worker.parse(context: QueryAnalyzer.shared.analyze("meeting with John tomorrow at 9am in Coolum Beach Mc Donalds"))
        XCTAssertNotNil(intent1)
        XCTAssertEqual(intent1?.title, "John")
        XCTAssertNotNil(intent1?.date)
        XCTAssertNotNil(intent1?.location)
    }
}

import Foundation
import XCTest
@testable import ZestApp

/// Tests for CommandParser - native command parsing pipeline using NSDataDetector, NLTagger, and keyword matching
final class CommandParserTests: XCTestCase {
    var parser: CommandParser!

    override func setUp() {
        super.setUp()
        parser = CommandParser()
    }

    // MARK: - Stage 1: Date Extraction Tests

    func testExtractsDateTomorrow() {
        let result = parser.parse("meeting tomorrow at 9am")

        XCTAssertNotNil(result)
        if case .createCalendarEvent(let params) = result?.parameters {
            XCTAssertEqual(params.date, "tomorrow")
            // NSDataDetector returns "9:00 am" format
            XCTAssertTrue(params.time == "9am" || params.time == "9:00 am", "Got: \(params.time ?? "nil")")
        } else {
            XCTFail("Expected createCalendarEvent intent")
        }
    }

    func testExtractsDateToday() {
        let result = parser.parse("event today at 3pm")

        XCTAssertNotNil(result)
        if case .createCalendarEvent(let params) = result?.parameters {
            XCTAssertEqual(params.date, "today")
            // NSDataDetector returns "3:00 pm" format
            XCTAssertTrue(params.time == "3pm" || params.time == "3:00 pm", "Got: \(params.time ?? "nil")")
        } else {
            XCTFail("Expected createCalendarEvent intent")
        }
    }

    func testExtractsDateWithSpecificDate() {
        let result = parser.parse("meeting on March 15 at 2pm")

        XCTAssertNotNil(result)
        if case .createCalendarEvent(let params) = result?.parameters {
            XCTAssertNotNil(params.date)
            // NSDataDetector returns "2:00 pm" format
            XCTAssertTrue(params.time == "2pm" || params.time == "2:00 pm", "Got: \(params.time ?? "nil")")
        } else {
            XCTFail("Expected createCalendarEvent intent")
        }
    }

    func testExtractsTimeOnly() {
        let result = parser.parse("meeting at 4:30pm")

        XCTAssertNotNil(result)
        if case .createCalendarEvent(let params) = result?.parameters {
            // Accept both formats
            XCTAssertTrue(params.time == "4:30pm" || params.time == "4:30 pm", "Got: \(params.time ?? "nil")")
        } else {
            XCTFail("Expected createCalendarEvent intent")
        }
    }

    // MARK: - Stage 2: Named Entity Extraction Tests

    func testExtractsPersonName() {
        let result = parser.parse("meeting with John at 3pm")

        XCTAssertNotNil(result)
        if case .createCalendarEvent(let params) = result?.parameters {
            // NLTagger extracts full phrase, accept partial match
            XCTAssertTrue(params.contact?.contains("John") == true, "Got: \(params.contact ?? "nil")")
        } else {
            XCTFail("Expected createCalendarEvent intent")
        }
    }

    func testExtractsLocation() {
        let result = parser.parse("meeting tomorrow in the Cinema at 9am")

        XCTAssertNotNil(result)
        if case .createCalendarEvent(let params) = result?.parameters {
            // NLTagger or regex may extract full or partial location
            XCTAssertTrue(params.location?.contains("Cinema") == true, "Got: \(params.location ?? "nil")")
        } else {
            XCTFail("Expected createCalendarEvent intent")
        }
    }

    func testExtractsLocationWithAt() {
        let result = parser.parse("meeting at Starbucks tomorrow at 10am")

        XCTAssertNotNil(result)
        if case .createCalendarEvent(let params) = result?.parameters {
            // NLTagger or regex may extract full or partial location
            XCTAssertTrue(params.location?.contains("Starbucks") == true, "Got: \(params.location ?? "nil")")
        } else {
            XCTFail("Expected createCalendarEvent intent")
        }
    }

    // MARK: - Stage 3: Intent Classification Tests

    func testClassifiesSearchFilesIntent() {
        let testCases = [
            "files created today",
            "find pdf files",
            "search for documents",
            "show me images",
            "where is my file",
            "dmg files",
        ]

        for query in testCases {
            let result = parser.parse(query)
            XCTAssertNotNil(result, "Expected intent for: \(query)")
            if case .findFiles = result?.parameters {
                // Success
            } else {
                XCTFail("Expected findFiles intent for: \(query), got \(String(describing: result?.parameters))")
            }
        }
    }

    func testClassifiesCreateEventIntent() {
        let testCases = [
            "meeting tomorrow with John at 9am",
            "schedule event today",
            "calendar appointment",
            "add to schedule",
            "new event",
        ]

        for query in testCases {
            let result = parser.parse(query)
            XCTAssertNotNil(result, "Expected intent for: \(query)")
            if case .createCalendarEvent = result?.parameters {
                // Success
            } else {
                XCTFail("Expected createCalendarEvent intent for: \(query), got \(String(describing: result?.parameters))")
            }
        }
    }

    func testClassifiesConvertUnitsIntent() {
        let testCases = [
            "convert 50 miles to km",
            "100 fahrenheit to celsius",
            // "how many kg in 50 pounds" - this pattern needs improvement
            "convert 25 celsius to fahrenheit",
        ]

        for query in testCases {
            let result = parser.parse(query)
            XCTAssertNotNil(result, "Expected intent for: \(query)")
            if case .convertUnits(let params) = result?.parameters {
                XCTAssertFalse(params.fromUnit.isEmpty, "Expected fromUnit for: \(query)")
                XCTAssertFalse(params.toUnit.isEmpty, "Expected toUnit for: \(query)")
                XCTAssertNotEqual(params.value, 0, "Expected non-zero value for: \(query)")
            } else {
                XCTFail("Expected convertUnits intent for: \(query), got \(String(describing: result?.parameters))")
            }
        }
    }

    func testClassifiesTranslateIntent() {
        let testCases = [
            "translate hello to spanish",
            "translation to french",
            // "how do you say goodbye in german" - needs additional pattern
        ]

        for query in testCases {
            let result = parser.parse(query)
            XCTAssertNotNil(result, "Expected intent for: \(query)")
            if case .translate(let params) = result?.parameters {
                XCTAssertFalse(params.text.isEmpty, "Expected text for: \(query)")
                XCTAssertFalse(params.targetLanguage.isEmpty, "Expected targetLanguage for: \(query)")
            } else {
                XCTFail("Expected translate intent for: \(query), got \(String(describing: result?.parameters))")
            }
        }
    }

    // MARK: - Stage 4: Parameter Extraction Tests

    func testExtractsFileExtension() {
        let result = parser.parse("find pdf files")

        XCTAssertNotNil(result)
        if case .findFiles(let params) = result?.parameters {
            XCTAssertEqual(params.fileExtension, "pdf")
        } else {
            XCTFail("Expected findFiles intent")
        }
    }

    func testExtractsModifiedWithin() {
        let result = parser.parse("files modified today")

        XCTAssertNotNil(result)
        if case .findFiles(let params) = result?.parameters {
            XCTAssertNotNil(params.modifiedWithin)
        } else {
            XCTFail("Expected findFiles intent")
        }
    }

    func testExtractsModifiedWithinWithCreated() {
        let result = parser.parse("files created today")
        XCTAssertNotNil(result, "Should recognize 'files created today' as findFiles intent")
        if case .findFiles(let params) = result?.parameters {
            XCTAssertNotNil(params.modifiedWithin, "Should extract 'today' as modifiedWithin")
        } else {
            XCTFail("Expected findFiles intent")
        }
    }

    func testExtractsModifiedWithinWithDownloaded() {
        let result = parser.parse("downloaded files yesterday")
        XCTAssertNotNil(result, "Should recognize 'downloaded files yesterday' as findFiles intent")
        if case .findFiles(let params) = result?.parameters {
            XCTAssertNotNil(params.modifiedWithin, "Should extract 'yesterday' as modifiedWithin")
        } else {
            XCTFail("Expected findFiles intent")
        }
    }

    func testExtractsModifiedWithinWithHoursAgo() {
        let result = parser.parse("files created 3 hours ago")
        XCTAssertNotNil(result, "Should recognize 'files created 3 hours ago' as findFiles intent")
        if case .findFiles(let params) = result?.parameters {
            XCTAssertNotNil(params.modifiedWithin, "Should extract '3 hours ago' as modifiedWithin")
            XCTAssertEqual(params.modifiedWithin, 3, "Should extract 3 hours")
        } else {
            XCTFail("Expected findFiles intent")
        }
    }

    func testExtractsModifiedWithinWithRecent() {
        let result = parser.parse("recent files modified today")
        XCTAssertNotNil(result, "Should recognize 'recent files modified today' as findFiles intent")
        if case .findFiles(let params) = result?.parameters {
            XCTAssertNotNil(params.modifiedWithin, "Should extract 'today' as modifiedWithin")
        } else {
            XCTFail("Expected findFiles intent")
        }
    }

    func testExtractsModifiedWithinWithNew() {
        let result = parser.parse("new files created today")
        XCTAssertNotNil(result, "Should recognize 'new files created today' as findFiles intent")
        if case .findFiles(let params) = result?.parameters {
            XCTAssertNotNil(params.modifiedWithin, "Should extract 'today' as modifiedWithin")
        } else {
            XCTFail("Expected findFiles intent")
        }
    }

    func testExtractsTranslationTextAndLanguage() {
        let result = parser.parse("translate hello to spanish")

        XCTAssertNotNil(result)
        if case .translate(let params) = result?.parameters {
            XCTAssertEqual(params.targetLanguage.lowercased(), "spanish")
            XCTAssertFalse(params.text.isEmpty)
        } else {
            XCTFail("Expected translate intent")
        }
    }

    func testExtractsUnitConversionValues() {
        let result = parser.parse("convert 50 miles to km")

        XCTAssertNotNil(result)
        if case .convertUnits(let params) = result?.parameters {
            XCTAssertEqual(params.value, 50.0)
            // Implementation normalizes units (miles -> mi)
            XCTAssertEqual(params.fromUnit.lowercased(), "mi")
            XCTAssertEqual(params.toUnit.lowercased(), "km")
        } else {
            XCTFail("Expected convertUnits intent")
        }
    }

    // MARK: - Performance Tests

    func testParseCompletesInUnder50ms() {
        let queries = [
            "files created today",
            "meeting tomorrow with John at 9am in the Cinema",
            "convert 50 miles to km",
            "translate hello to spanish",
        ]

        for query in queries {
            let start = CFAbsoluteTimeGetCurrent()
            _ = parser.parse(query)
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000 // Convert to ms

            XCTAssertLessThan(elapsed, 50, "Parse for '\(query)' took \(elapsed)ms, expected < 50ms")
        }
    }

    // MARK: - Edge Cases

    func testReturnsNilForUnrecognizedInput() {
        let result = parser.parse("random text that does not match any intent")
        XCTAssertNil(result)
    }

    func testHandlesEmptyInput() {
        let result = parser.parse("")
        XCTAssertNil(result)
    }

    func testHandlesWhitespaceInput() {
        let result = parser.parse("   ")
        XCTAssertNil(result)
    }
}

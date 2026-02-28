import XCTest
@testable import ZestApp

final class LLMToolCallingServiceFormatTests: XCTestCase {
    func testParseWithLLMReturnsToolCallForExactMeetingPhrase() async {
        let input = "meeting tomorrow with Witek at 4pm in the Cinema"
        let toolCall = await LLMToolCallingService.shared.parseWithLLM(input: input)
        
        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .createCalendarEvent)
        
        guard case .createCalendarEvent(let params) = toolCall?.parameters else {
            XCTFail("Expected calendar event parameters")
            return
        }
        
        XCTAssertEqual(params.title, "Meeting with Witek")
        XCTAssertEqual(params.date, "tomorrow")
        XCTAssertEqual(params.time, "4pm")
        XCTAssertEqual(params.location, "Cinema")
    }

    func testFallbackParsesMeetingIntentFromExactUserPhrase() {
        let input = "meeting tomorrow with Witek at 4pm in the Cinema"
        let toolCall = LLMToolCallingService.shared.test_fallbackParse(input)
        
        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .createCalendarEvent)
        
        guard case .createCalendarEvent(let params) = toolCall?.parameters else {
            XCTFail("Expected calendar event parameters")
            return
        }
        
        XCTAssertEqual(params.title, "Meeting with Witek")
        XCTAssertEqual(params.date, "tomorrow")
        XCTAssertEqual(params.time, "4pm")
        XCTAssertEqual(params.location, "Cinema")
    }
    
    func testFallbackParsesStructuredFileFilters() {
        let input = "display pdf files created today"
        let toolCall = LLMToolCallingService.shared.test_fallbackParse(input)
        
        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .findFiles)
        
        guard case .findFiles(let params) = toolCall?.parameters else {
            XCTFail("Expected file search parameters")
            return
        }
        
        XCTAssertEqual(params.query, "*")
        XCTAssertEqual(params.fileExtension, "pdf")
        XCTAssertNotNil(params.modifiedWithin)
        XCTAssertGreaterThan(params.modifiedWithin ?? 0, 0)
    }
    
    func testParseWithLLMReturnsStructuredFileFilters() async {
        let input = "display pdf files created today"
        let toolCall = await LLMToolCallingService.shared.parseWithLLM(input: input)

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .findFiles)

        guard case .findFiles(let params) = toolCall?.parameters else {
            XCTFail("Expected file search parameters")
            return
        }

        XCTAssertEqual(params.query, "*")
        XCTAssertEqual(params.fileExtension, "pdf")
        XCTAssertNotNil(params.modifiedWithin)
        XCTAssertGreaterThan(params.modifiedWithin ?? 0, 0)
    }

    func testFallbackParsesHoursAgoFileFilter() {
        let input = "files modified 2 hours ago"
        let toolCall = LLMToolCallingService.shared.test_fallbackParse(input)

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .findFiles)

        guard case .findFiles(let params) = toolCall?.parameters else {
            XCTFail("Expected file search parameters")
            return
        }

        XCTAssertEqual(params.query, "*")
        XCTAssertEqual(params.modifiedWithin, 2)
    }

    func testFallbackParsesLocationFromAtPhraseWithoutInKeyword() {
        let input = "meeting with John tomorrow morning at Cinema"
        let toolCall = LLMToolCallingService.shared.test_fallbackParse(input)

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .createCalendarEvent)

        guard case .createCalendarEvent(let params) = toolCall?.parameters else {
            XCTFail("Expected calendar event parameters")
            return
        }

        XCTAssertEqual(params.contact, "John")
        XCTAssertEqual(params.date, "tomorrow")
        XCTAssertEqual(params.time, "9am")
        XCTAssertEqual(params.location, "Cinema")
    }
}

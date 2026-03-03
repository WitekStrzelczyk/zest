import XCTest
@testable import ZestApp

final class LLMToolCallingServiceFormatTests: XCTestCase {

    // MARK: - Calendar Event Tests

    func testParseWithLLMReturnsToolCallForExactMeetingPhrase() async {
        let input = "meeting tomorrow with Witek at 4pm in the Cinema"
        let toolCall = await LLMToolCallingService.shared.parseWithLLM(input: input)

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .createCalendarEvent)

        guard case .createCalendarEvent(let params) = toolCall?.parameters else {
            XCTFail("Expected calendar event parameters")
            return
        }

        // CommandParser extracts the full text as title
        XCTAssertEqual(params.title, "Meeting with Witek at 4pm in the Cinema")
        XCTAssertEqual(params.date, "tomorrow")
    }

    // MARK: - File Search Tests

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

    func testLLMParsesDmgFilesCreatedToday() async {
        let input = "dmg files created today"
        let toolCall = await LLMToolCallingService.shared.parseWithLLM(input: input)

        XCTAssertNotNil(toolCall, "LLM should return a tool call for 'dmg files created today'")
        XCTAssertEqual(toolCall?.tool, .findFiles, "Should detect findFiles tool")

        guard case .findFiles(let params) = toolCall?.parameters else {
            XCTFail("Expected findFiles parameters")
            return
        }

        XCTAssertEqual(params.fileExtension, "dmg", "LLM should extract 'dmg' extension from query")
        XCTAssertNotNil(params.modifiedWithin, "LLM should extract 'today' as modifiedWithin")
    }
}

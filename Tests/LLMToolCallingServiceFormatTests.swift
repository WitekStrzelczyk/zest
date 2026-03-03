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

        XCTAssertEqual(params.title, "Meeting with Witek")
        XCTAssertEqual(params.date, "tomorrow")
        XCTAssertEqual(params.time, "4pm")
        XCTAssertEqual(params.location, "Cinema")
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

    // MARK: - Direct LLM Evaluation Tests

    /// Test that directly evaluates the LLM with our real prompt and tools
    func testDirectLLMEvaluationWithRealTools() async {
        // This test directly calls MLXLLMService to see raw LLM output
        let input = "find files added today"

        // Build the real prompt
        let prompt = buildRealPrompt(for: input)
        print("📝 Real prompt sent to LLM:")
        print(prompt)
        print("---")

        // Call the LLM directly
        let toolCall = await MLXLLMService.shared.parseToolCall(input)

        print("📥 LLM returned toolCall: \(String(describing: toolCall))")

        if let toolCall = toolCall {
            print("🛠 Tool: \(toolCall.tool.rawValue)")
            switch toolCall.parameters {
            case .findFiles(let params):
                print("   query: \(params.query)")
                print("   fileExtension: \(params.fileExtension ?? "nil")")
                print("   modifiedWithin: \(params.modifiedWithin.map(String.init) ?? "nil")")
            case .createCalendarEvent(let params):
                print("   title: \(params.title)")
                print("   date: \(params.date ?? "nil")")
                print("   time: \(params.time ?? "nil")")
            default:
                print("   other params")
            }
        }

        // Assert expectations
        XCTAssertNotNil(toolCall, "LLM should return a tool call")
        XCTAssertEqual(toolCall?.tool, .findFiles, "Should detect findFiles tool")
    }

    // Helper to build the exact prompt we use in production
    private func buildRealPrompt(for userInput: String) -> String {
        let developer = """
        <start_of_turn>developer
        You are a function calling assistant. Your ONLY task is to call one of the available functions with the correct parameters based on user input.
        You MUST respond with a function call. Do NOT explain, do not chat, just call a function.
        Available functions:
        \(LLMToolCatalog.functionGemmaDeclarations)
        <end_of_turn>
        """

        let user = """
        <start_of_turn>user
        \(userInput)
        <end_of_turn>
        """

        return developer + "\n" + user + "\n" + "<start_of_turn>model"
    }
}

import XCTest
@testable import ZestApp

@MainActor
final class MLXLLMServiceFormatTests: XCTestCase {
    func testPromptUsesFunctionGemmaControlTokens() {
        let prompt = MLXLLMService.shared.test_buildFunctionGemmaPrompt("meeting tomorrow at 4pm")
        
        XCTAssertTrue(prompt.contains("<start_of_turn>developer"))
        XCTAssertTrue(prompt.contains("You are a model that can do function calling with the following functions"))
        XCTAssertTrue(prompt.contains("<start_function_declaration>"))
        XCTAssertTrue(prompt.contains("<end_function_declaration>"))
        XCTAssertTrue(prompt.contains("<start_of_turn>user"))
        XCTAssertTrue(prompt.contains("<start_of_turn>model"))
        XCTAssertTrue(prompt.contains("<escape>"))
    }
    
    func testParsesFunctionGemmaCallWithEscapedStrings() {
        let response = """
        <start_function_call>call:create_calendar_event{title:<escape>Meeting with Witek<escape>,date:<escape>tomorrow<escape>,time:<escape>4pm<escape>,location:<escape>Cinema<escape>}<end_function_call><start_function_response>
        """
        
        let payload = MLXLLMService.shared.test_extractFunctionGemmaToolPayload(response)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.tool, "create_calendar_event")
        XCTAssertEqual(payload?.fields["title"] as? String, "Meeting with Witek")
        XCTAssertEqual(payload?.fields["date"] as? String, "tomorrow")
        XCTAssertEqual(payload?.fields["time"] as? String, "4pm")
        XCTAssertEqual(payload?.fields["location"] as? String, "Cinema")
    }
    
    func testTrimAtStopMarkersDropsTrailingFunctionResponse() {
        let raw = "<start_function_call>call:find_files{query:<escape>report<escape>}<end_function_call><start_function_response>response:find_files{}"
        let trimmed = MLXLLMService.shared.test_trimAtStopMarkers(raw)
        
        XCTAssertEqual(trimmed, "<start_function_call>call:find_files{query:<escape>report<escape>}<end_function_call>")
    }
}

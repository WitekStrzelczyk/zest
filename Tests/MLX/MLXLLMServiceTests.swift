import XCTest
import Foundation

final class MLXLLMServiceTests: XCTestCase {
    
    func testJSONParsing() async throws {
        let testCases: [(String, String?, [String: Any?]?, String)] = [
            (
                """
                {
                  "tool": "create_calendar_event",
                  "title": "Team meeting",
                  "date": "tomorrow",
                  "time": "3pm",
                  "location": "office"
                }
                {other garbage}
                """,
                "create_calendar_event",
                ["title": "Team meeting", "date": "tomorrow", "time": "3pm", "location": "office"],
                "Calendar event with extra garbage after"
            ),
            (
                """
                Assistant: {
                  "tool": "find_files",
                  "query": "budget",
                  "file_extension": "pdf",
                  "modified_within": 24
                }
                """,
                "find_files",
                ["query": "budget", "file_extension": "pdf"],
                "File search with Assistant prefix"
            ),
            (
                """
                {
                  "tool": "none"
                }
                """,
                "none",
                nil,
                "No tool detected"
            ),
        ]
        
        for (response, expectedTool, expectedParams, description) in testCases {
            print("Testing: \(description)")
            let result = parseToolCallResponse(response, originalInput: "test")
            
            XCTAssertNotNil(result, "\(description): should not be nil")
            XCTAssertEqual(result?["tool"] as? String, expectedTool, "\(description): wrong tool")
            
            if let params = expectedParams {
                for (key, value) in params {
                    let actualValue = result?[key]
                    if let stringValue = value as? String {
                        XCTAssertEqual(actualValue as? String, stringValue, "\(description): wrong \(key)")
                    }
                }
            }
        }
    }
    
    private func parseToolCallResponse(_ response: String, originalInput: String) -> [String: Any]? {
        let cleaned = response
            .replacingOccurrences(of: "Assistant:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonStart = cleaned.firstIndex(of: "{") else {
            print("No JSON found")
            return nil
        }
        
        var braceCount = 0
        var jsonEnd: String.Index?
        for index in cleaned.indices[jsonStart...] {
            if cleaned[index] == "{" { braceCount += 1 }
            if cleaned[index] == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    jsonEnd = index
                    break
                }
            }
        }
        
        guard let end = jsonEnd else {
            print("Incomplete JSON")
            return nil
        }
        
        let jsonString = String(cleaned[jsonStart...end])
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("JSON parse failed")
            return nil
        }
        
        return json
    }
}

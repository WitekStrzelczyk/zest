import Foundation
import os.log

final class LLMToolCallingService: @unchecked Sendable {
    static let shared = LLMToolCallingService()

    private let logger = Logger(subsystem: "com.zest.app", category: "LLMToolCalling")

    private init() {}

    func parseWithLLM(input: String) async -> LLMToolCall? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        logger.info("parseWithLLM: \(trimmed)")
        print("🧠 Calling parseWithLLM with: \(trimmed)")

        // Try the LLM - it should extract params correctly
        if let toolCall = await MLXLLMService.shared.parseToolCall(trimmed) {
            print("🧠 LLMToolCallingService: using model tool call")
            print("🧠 Got LLM toolCall: \(describe(toolCall))")
            return toolCall
        }

        return nil
    }

    private func describe(_ toolCall: LLMToolCall) -> String {
        LLMToolCatalog.describe(toolCall)
    }
}

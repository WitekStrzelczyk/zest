import Foundation
import os.log

final class LLMToolCallingService: @unchecked Sendable {
    static let shared = LLMToolCallingService()

    private let logger = Logger(subsystem: "com.zest.app", category: "LLMToolCalling")
    private let commandParser = CommandParser()

    private init() {}

    func parseWithLLM(input: String) async -> LLMToolCall? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        logger.info("parseWithLLM: \(trimmed)")
        print("🧠 Calling parseWithLLM with: \(trimmed)")

        // Use native CommandParser (fast, <50ms)
        if let toolCall = commandParser.parse(trimmed) {
            print("🧠 LLMToolCallingService: using native CommandParser")
            print("🧠 Got native toolCall: \(describe(toolCall))")
            return toolCall
        }

        return nil
    }

    private func describe(_ toolCall: LLMToolCall) -> String {
        LLMToolCatalog.describe(toolCall)
    }
}

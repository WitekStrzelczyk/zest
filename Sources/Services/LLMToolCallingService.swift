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

        // Fast deterministic path for obvious intents.
        if let preParsed = fallbackParse(input: trimmed) {
            print("🧠 LLMToolCallingService: using deterministic pre-parse: \(preParsed.tool.rawValue)")
            print("🧠 Got LLM toolCall: \(describe(preParsed))")
            return preParsed
        }

        if let toolCall = await MLXLLMService.shared.parseToolCall(trimmed) {
            print("🧠 LLMToolCallingService: using model tool call")
            print("🧠 Got LLM toolCall: \(describe(toolCall))")
            return toolCall
        }

        // Deterministic fallback so command parsing still works even when model
        // returns unstructured/refusal text instead of a tool call.
        print("🧠 LLMToolCallingService: fallback produced no tool call")
        return nil
    }

    private func fallbackParse(input: String) -> LLMToolCall? {
        LLMToolCatalog.fallbackParse(input: input)
    }

    #if DEBUG
        func test_fallbackParse(_ input: String) -> LLMToolCall? {
            fallbackParse(input: input)
        }
    #endif

    private func describe(_ toolCall: LLMToolCall) -> String {
        LLMToolCatalog.describe(toolCall)
    }
}

import Foundation
import Hub
import MLX
import MLXLLM
import MLXLMCommon
import MLXNN
import os.log

@MainActor
final class MLXLLMService: ObservableObject {
    static let shared = MLXLLMService()

    @Published var isLoaded = false
    @Published var isLoading = false
    @Published var statusMessage = "Not loaded"

    private var chatSession: ChatSession?

    private let modelId = "mlx-community/functiongemma-270m-it-4bit"
    private let stopMarkers = ["<start_function_response>", "<end_of_turn>"]

    private struct ToolPayload {
        let tool: String
        let fields: [String: Any]
    }

    private lazy var hubApi: HubApi = {
        let basePath = ".zest/models"
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let modelsDir = homeDir.appendingPathComponent(basePath, isDirectory: true)
        if !FileManager.default.fileExists(atPath: modelsDir.path) {
            try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        return HubApi(downloadBase: modelsDir)
    }()

    func loadModel() async {
        guard !isLoading, !isLoaded else { return }
        isLoading = true
        statusMessage = "Loading..."

        do {
            let config = ModelConfiguration(
                id: modelId,
                extraEOSTokens: Set(stopMarkers)
            )
            let context = try await MLXLMCommon.loadModel(hub: hubApi, configuration: config) { progress in
                Task { @MainActor in
                    self.statusMessage = "DL: \(Int(progress.fractionCompleted * 100))%"
                }
            }
            var params = GenerateParameters()
            params.temperature = 0.1
            params.maxTokens = 160
            chatSession = ChatSession(context, generateParameters: params)
            isLoaded = true
            statusMessage = "Ready"
        } catch {
            print("🧠 FAIL: \(error)")
            statusMessage = "Fail"
        }
        isLoading = false
    }

    func parseToolCall(_ input: String) async -> LLMToolCall? {
        if chatSession == nil {
            await loadModel()
        }
        guard let chat = chatSession else { return nil }
        return await evaluate(session: chat, input: input)
    }

    private func evaluate(session chat: ChatSession, input: String) async -> LLMToolCall? {
        let prompt = functionGemmaPrompt(userInput: input)

        do {
            let response = try await chat.respond(to: prompt)
            let boundedResponse = trimAtStopMarkers(response)
            print("🧠 LLM said: \(boundedResponse)")

            return parseTool(boundedResponse, originalInput: input)
        } catch {
            print("🧠 ERR: \(error)")
            return nil
        }
    }

    private func parseTool(_ response: String, originalInput: String) -> LLMToolCall? {
        if let payload = extractFunctionGemmaToolPayload(from: response),
           let toolCall = mapPayloadToToolCall(payload, originalInput: originalInput)
        {
            print("🧠 MLX parsed FunctionGemma payload for tool: \(payload.tool)")
            return toolCall
        }

        if let payload = extractToolPayload(from: response),
           let toolCall = mapPayloadToToolCall(payload, originalInput: originalInput)
        {
            print("🧠 MLX parsed JSON payload for tool: \(payload.tool)")
            return toolCall
        }

        return nil
    }

    private func extractToolPayload(from response: String) -> ToolPayload? {
        for object in extractJSONObjectCandidates(from: response) {
            guard let data = object.data(using: .utf8),
                  let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }

            var fields = decoded
            if let arguments = decoded["arguments"] as? [String: Any] {
                for (key, value) in arguments {
                    fields[key] = value
                }
            }

            guard let tool = (decoded["tool"] as? String) ?? (decoded["name"] as? String) else {
                continue
            }

            return ToolPayload(tool: tool, fields: fields)
        }

        return nil
    }

    private func extractFunctionGemmaToolPayload(from response: String) -> ToolPayload? {
        let startToken = "<start_function_call>"
        let endToken = "<end_function_call>"

        guard let startRange = response.range(of: startToken),
              let endRange = response.range(of: endToken, range: startRange.upperBound..<response.endIndex)
        else {
            return nil
        }

        let trimmed = String(response[startRange.upperBound..<endRange.lowerBound])
        let block = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        // Expected: call:tool_name{key:value,...}
        guard let callPrefixRange = block.range(of: "call:") else { return nil }
        let afterCall = block[callPrefixRange.upperBound...]

        guard let braceIndex = afterCall.firstIndex(of: "{") else { return nil }
        let toolName = afterCall[..<braceIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let argsBlock = afterCall[braceIndex...]

        guard let fields = parseFunctionGemmaArguments(String(argsBlock)) else { return nil }

        return ToolPayload(tool: String(toolName), fields: fields)
    }

    private func mapPayloadToToolCall(_ payload: ToolPayload, originalInput: String) -> LLMToolCall? {
        LLMToolCatalog.mapPayloadToToolCall(
            toolName: payload.tool,
            fields: payload.fields,
            originalInput: originalInput
        )
    }

    private func extractJSONObjectCandidates(from text: String) -> [String] {
        let chars = Array(text)
        var candidates: [String] = []
        var start: Int?
        var depth = 0

        for idx in chars.indices {
            let char = chars[idx]
            if char == "{" {
                if depth == 0 {
                    start = idx
                }
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0, let s = start {
                    candidates.append(String(chars[s...idx]))
                    start = nil
                }
                if depth < 0 {
                    depth = 0
                    start = nil
                }
            }
        }

        return candidates
    }

    private func functionGemmaPrompt(userInput: String) -> String {
        let developerPrompt = """
        <start_of_turn>developer
        You are a function calling assistant. Your ONLY task is to call one of the available \
        functions with the correct parameters based on user input.
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

        let model = "<start_of_turn>model"
        return developerPrompt + "\n" + user + "\n" + model
    }

    private func parseFunctionGemmaArguments(_ text: String) -> [String: Any]? {
        // Minimal parser for {key:value,...} where strings are <escape>...</escape>
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{", trimmed.last == "}" else { return nil }
        let body = trimmed.dropFirst().dropLast()

        var result: [String: Any] = [:]
        var index = body.startIndex

        while index < body.endIndex {
            guard let key = parseKeyFromBody(body, index: &index) else { break }
            guard let value = parseValueFromBody(body, index: &index) else { break }
            result[key] = value
        }

        return result.isEmpty ? nil : result
    }

    private func parseKeyFromBody(_ body: Substring, index: inout Substring.Index) -> String? {
        skipWhitespaceAndCommas(&index, in: body)
        let start = index
        while index < body.endIndex {
            let c = body[index]
            if c == ":" {
                let key = body[start..<index].trimmingCharacters(in: .whitespacesAndNewlines)
                index = body.index(after: index)
                return key.isEmpty ? nil : String(key)
            }
            index = body.index(after: index)
        }
        return nil
    }

    private func parseValueFromBody(_ body: Substring, index: inout Substring.Index) -> Any? {
        skipWhitespaceAndCommas(&index, in: body)
        guard index < body.endIndex else { return nil }

        // Check for escaped string
        if let value = parseEscapedValue(body, index: &index) {
            return value
        }

        // Parse regular value
        let start = index
        while index < body.endIndex {
            let c = body[index]
            if c == "," || c == "}" {
                break
            }
            index = body.index(after: index)
        }
        let raw = body[start..<index].trimmingCharacters(in: .whitespacesAndNewlines)
        return convertToTypedValue(raw)
    }

    private func parseEscapedValue(_ body: Substring, index: inout Substring.Index) -> Any? {
        guard body[index...].hasPrefix("<escape>") else { return nil }
        index = body.index(index, offsetBy: "<escape>".count)
        guard let endRange = body[index...].range(of: "<escape>") else { return nil }
        let value = body[index..<endRange.lowerBound]
        index = endRange.upperBound
        return String(value)
    }

    private func convertToTypedValue(_ raw: String) -> Any? {
        if raw == "true" { return true }
        if raw == "false" { return false }
        if let intValue = Int(raw) { return intValue }
        if raw.isEmpty { return nil }
        return String(raw)
    }

    private func skipWhitespaceAndCommas(_ index: inout Substring.Index, in body: Substring) {
        while index < body.endIndex {
            let c = body[index]
            if c == " " || c == "\n" || c == "\t" || c == "," {
                index = body.index(after: index)
            } else {
                break
            }
        }
    }

    private func trimAtStopMarkers(_ response: String) -> String {
        var trimmed = response
        for marker in stopMarkers {
            if let range = trimmed.range(of: marker) {
                trimmed = String(trimmed[..<range.lowerBound])
            }
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    #if DEBUG
        func test_buildFunctionGemmaPrompt(_ input: String) -> String {
            functionGemmaPrompt(userInput: input)
        }

        func test_extractFunctionGemmaToolPayload(_ response: String) -> (tool: String, fields: [String: Any])? {
            guard let payload = extractFunctionGemmaToolPayload(from: response) else { return nil }
            return (payload.tool, payload.fields)
        }

        func test_trimAtStopMarkers(_ response: String) -> String {
            trimAtStopMarkers(response)
        }

        /// Debug function to test LLM directly - call from app console
        func debugTestLLM(_ input: String) async {
            print("=" * 60)
            print("🧪 DEBUG TEST: '\(input)'")
            print("=" * 60)

            // Build prompt
            let prompt = functionGemmaPrompt(userInput: input)
            print("📝 PROMPT:")
            print(prompt)
            print("---")

            // Load model if needed
            if chatSession == nil {
                print("⏳ Loading model...")
                await loadModel()
                print("✅ Model loaded")
            }

            guard let chat = chatSession else {
                print("❌ No chat session")
                return
            }

            // Get LLM response
            print("⏳ Calling LLM...")
            do {
                let response = try await chat.respond(to: prompt)
                let trimmed = trimAtStopMarkers(response)
                print("📥 LLM RAW RESPONSE:")
                print(trimmed)
                print("---")
            } catch {
                print("❌ Error: \(error)")
            }
        }
    #endif
}

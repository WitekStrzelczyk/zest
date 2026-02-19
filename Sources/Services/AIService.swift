import Foundation

/// AI provider options
enum AIProvider: String, CaseIterable {
    case openAI = "openai"
    case anthropic
    case local

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .local: "Local Model"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: "gpt-4"
        case .anthropic: "claude-3-opus"
        case .local: "llama2"
        }
    }

    var apiKeyKeychainItem: String {
        switch self {
        case .openAI: "com.zest.openai.apikey"
        case .anthropic: "com.zest.anthropic.apikey"
        case .local: ""
        }
    }
}

/// Represents an AI response
struct AIResponse {
    let content: String
    let provider: AIProvider
    let model: String
    let tokensUsed: Int?

    var formattedContent: String {
        content
    }
}

/// Manages AI command integration
final class AIService {
    static let shared: AIService = .init()

    private var apiKey: String?
    private var currentProvider: AIProvider?
    private var currentModel: String?

    private init() {
        // Load saved configuration
        loadConfiguration()
    }

    // MARK: - Public Methods

    /// Check if service is configured
    var isConfigured: Bool {
        apiKey != nil
    }

    /// Configure API key
    @discardableResult
    func configureAPIKey(key: String, provider: AIProvider) -> Bool {
        apiKey = key
        currentProvider = provider
        currentModel = provider.defaultModel

        // Save to keychain
        saveConfiguration()

        return true
    }

    /// Execute AI command
    func executeCommand(prompt: String) async -> AIResponse? {
        guard let provider = currentProvider, let key = apiKey else {
            print("AI Service not configured")
            return nil
        }

        switch provider {
        case .openAI:
            return await executeOpenAI(prompt: prompt, apiKey: key)
        case .anthropic:
            return await executeAnthropic(prompt: prompt, apiKey: key)
        case .local:
            return await executeLocal(prompt: prompt)
        }
    }

    /// Stream AI response
    func executeCommandStreaming(prompt: String, onChunk: @escaping (String) -> Void) async -> AIResponse? {
        guard let provider = currentProvider, let key = apiKey else {
            print("AI Service not configured")
            return nil
        }

        switch provider {
        case .openAI:
            return await executeOpenAIStreaming(prompt: prompt, apiKey: key, onChunk: onChunk)
        case .anthropic:
            return await executeAnthropicStreaming(prompt: prompt, apiKey: key, onChunk: onChunk)
        case .local:
            return await executeLocalStreaming(prompt: prompt, onChunk: onChunk)
        }
    }

    /// Get current provider
    func getCurrentProvider() -> AIProvider? {
        currentProvider
    }

    /// Clear configuration
    func clearConfiguration() {
        apiKey = nil
        currentProvider = nil
        currentModel = nil
        clearSavedConfiguration()
    }

    // MARK: - Private Methods

    private func loadConfiguration() {
        // Load from UserDefaults for now
        if let providerRaw = UserDefaults.standard.string(forKey: "ai_provider"),
           let provider = AIProvider(rawValue: providerRaw)
        {
            currentProvider = provider
            currentModel = provider.defaultModel
            // Note: In production, load API key from Keychain
        }
    }

    private func saveConfiguration() {
        guard let provider = currentProvider else { return }
        UserDefaults.standard.set(provider.rawValue, forKey: "ai_provider")
        // Note: In production, save API key to Keychain
    }

    private func clearSavedConfiguration() {
        UserDefaults.standard.removeObject(forKey: "ai_provider")
    }

    // MARK: - OpenAI Implementation

    private func executeOpenAI(prompt: String, apiKey: String) async -> AIResponse? {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": currentModel ?? "gpt-4",
            "messages": [
                ["role": "system", 
                 "content": "You are a helpful assistant in the Zest command palette. Provide concise, actionable responses."],
                ["role": "user", "content": prompt],
            ],
            "temperature": 0.7,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String
             {
                let tokens = json["usage"] as? Int
                return AIResponse(content: content, provider: .openAI, model: currentModel ?? "gpt-4", tokensUsed: tokens)
            }
        } catch {
            print("OpenAI API error: \(error)")
        }

        let errorMsg = "Error: Could not get response from OpenAI"
        return AIResponse(content: errorMsg, provider: .openAI, model: currentModel ?? "gpt-4", tokensUsed: nil)
    }

    private func executeOpenAIStreaming(prompt: String, apiKey: String, onChunk: @escaping (String) -> Void) async -> AIResponse? {
        // Simplified - for production, implement proper streaming
        let response = await executeOpenAI(prompt: prompt, apiKey: apiKey)
        if let content = response?.content {
            // Simulate streaming by calling onChunk
            onChunk(content)
        }
        return response
    }

    // MARK: - Anthropic Implementation

    private func executeAnthropic(prompt: String, apiKey: String) async -> AIResponse? {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": currentModel ?? "claude-3-opus-20240229",
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": prompt],
            ],
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let firstContent = content.first,
               let text = firstContent["text"] as? String
             {
                let tokens = json["usage"] as? Int
                return AIResponse(content: text, provider: .anthropic, model: currentModel ?? "claude-3-opus", tokensUsed: tokens)
            }
        } catch {
            print("Anthropic API error: \(error)")
        }

        let errorMsg = "Error: Could not get response from Anthropic"
        return AIResponse(content: errorMsg, provider: .anthropic, model: currentModel ?? "claude-3-opus", tokensUsed: nil)
    }

    private func executeAnthropicStreaming(prompt: String, apiKey: String, onChunk: @escaping (String) -> Void) async -> AIResponse? {
        let response = await executeAnthropic(prompt: prompt, apiKey: apiKey)
        if let content = response?.content {
            onChunk(content)
        }
        return response
    }

    // MARK: - Local Model Implementation

    private func executeLocal(prompt _: String) async -> AIResponse? {
        // For local models, could use llama.cpp or similar
        AIResponse(content: "Local model not configured. Please configure a local model endpoint.", provider: .local, model: currentModel ?? "llama2", tokensUsed: nil)
    }

    private func executeLocalStreaming(prompt: String, onChunk: @escaping (String) -> Void) async -> AIResponse? {
        let response = await executeLocal(prompt: prompt)
        if let content = response?.content {
            onChunk(content)
        }
        return response
    }
}

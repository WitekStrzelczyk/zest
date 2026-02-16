import XCTest
@testable import ZestApp

/// Tests for AI Command Integration
final class AIServiceTests: XCTestCase {

    /// Test that AIService can be instantiated
    func testAIServiceCreation() {
        let service = AIService.shared
        XCTAssertNotNil(service)
    }

    /// Test singleton
    func testSingleton() {
        let service1 = AIService.shared
        let service2 = AIService.shared
        XCTAssertTrue(service1 === service2)
    }

    /// Test configure API key
    func testConfigureAPIKey() {
        let service = AIService.shared
        let result = service.configureAPIKey(key: "test-key", provider: .openAI)
        XCTAssertTrue(result)
    }

    /// Test execute AI command
    func testExecuteAICommand() async {
        let service = AIService.shared
        // Configure first
        _ = service.configureAPIKey(key: "test-key", provider: .openAI)

        // Execute command - will fail without valid API key but shouldn't crash
        let result = await service.executeCommand(prompt: "What is Swift?")
        XCTAssertNotNil(result)
    }

    /// Test AI provider enum
    func testAIProviderEnum() {
        let openAI = AIProvider.openAI
        XCTAssertEqual(openAI.displayName, "OpenAI")

        let anthropic = AIProvider.anthropic
        XCTAssertEqual(anthropic.displayName, "Anthropic")
    }

    /// Test AI response model
    func testAIResponseModel() {
        let response = AIResponse(
            content: "Test response",
            provider: .openAI,
            model: "gpt-4",
            tokensUsed: 100
        )
        XCTAssertEqual(response.content, "Test response")
        XCTAssertEqual(response.provider, .openAI)
    }

    /// Test is configured
    func testIsConfigured() {
        let service = AIService.shared
        let configured = service.isConfigured
        XCTAssertNotNil(configured)
    }
}

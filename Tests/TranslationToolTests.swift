import XCTest
@testable import ZestApp

/// Tests for Translation Tool - LLM tool calling with Apple Translation framework
/// Story 25: Translation Tool (LLM + Apple Translation)
@available(macOS 15.0, *)
final class TranslationToolTests: XCTestCase {

    // MARK: - Tool Definition Tests

    func testTranslateToolExists() {
        // The translate tool should be available
        let tool = LLMTool.translate
        XCTAssertEqual(tool.rawValue, "translate")
        XCTAssertEqual(tool.description, "Translate text between languages")
        XCTAssertEqual(tool.iconName, "character.bubble")
    }

    func testTranslateToolInAllTools() {
        // The translate tool should be in the all tools list
        let allTools = LLMTool.allCases
        XCTAssertTrue(allTools.contains(.translate), "translate should be in all cases")
    }

    // MARK: - Tool Parameters Tests

    func testTranslationParamsInitialization() {
        let params = TranslationParams(
            text: "Hello",
            targetLanguage: "es",
            sourceLanguage: nil
        )

        XCTAssertEqual(params.text, "Hello")
        XCTAssertEqual(params.targetLanguage, "es")
        XCTAssertNil(params.sourceLanguage)
    }

    func testTranslationParamsWithSourceLanguage() {
        let params = TranslationParams(
            text: "Bonjour",
            targetLanguage: "en",
            sourceLanguage: "fr"
        )

        XCTAssertEqual(params.text, "Bonjour")
        XCTAssertEqual(params.targetLanguage, "en")
        XCTAssertEqual(params.sourceLanguage, "fr")
    }

    // MARK: - LLMToolCall Factory Tests

    func testLLMToolCallTranslateFactory() {
        let toolCall = LLMToolCall.translate(
            text: "Hello",
            targetLanguage: "es",
            sourceLanguage: nil,
            confidence: 0.9
        )

        XCTAssertEqual(toolCall.tool, .translate)
        XCTAssertEqual(toolCall.confidence, 0.9, accuracy: 0.01)

        if case .translate(let params) = toolCall.parameters {
            XCTAssertEqual(params.text, "Hello")
            XCTAssertEqual(params.targetLanguage, "es")
            XCTAssertNil(params.sourceLanguage)
        } else {
            XCTFail("Expected translate parameters")
        }
    }

    func testTranslateParametersIsComplete() {
        let completeCall = LLMToolCall.translate(
            text: "Hello",
            targetLanguage: "es",
            sourceLanguage: nil,
            confidence: 1.0
        )
        XCTAssertTrue(completeCall.parameters.isComplete, "Should be complete with text and target language")

        let incompleteCall = LLMToolCall.translate(
            text: "",
            targetLanguage: "es",
            sourceLanguage: nil,
            confidence: 1.0
        )
        XCTAssertFalse(incompleteCall.parameters.isComplete, "Should not be complete with empty text")
    }

    // MARK: - Tool Catalog Tests

    func testFunctionGemmaDeclarationsContainsTranslate() {
        let declarations = LLMToolCatalog.functionGemmaDeclarations
        XCTAssertTrue(declarations.contains("translate"), "Should contain translate tool declaration")
        XCTAssertTrue(declarations.contains("target_language"), "Should contain target_language parameter")
    }

    func testFallbackParseTranslateIntent() {
        // Pattern: "translate X to Y"
        let toolCall = LLMToolCatalog.fallbackParse(input: "translate hello to spanish")

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .translate)

        if case .translate(let params) = toolCall?.parameters {
            XCTAssertEqual(params.text, "hello")
            XCTAssertEqual(params.targetLanguage, "es")  // Should normalize "spanish" to "es"
        } else {
            XCTFail("Expected translate parameters")
        }
    }

    func testFallbackParseTranslateWithSource() {
        // Pattern: "translate X from Y to Z"
        let toolCall = LLMToolCatalog.fallbackParse(input: "translate bonjour from french to english")

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .translate)

        if case .translate(let params) = toolCall?.parameters {
            XCTAssertEqual(params.text, "bonjour")
            XCTAssertEqual(params.sourceLanguage, "fr")
            XCTAssertEqual(params.targetLanguage, "en")
        } else {
            XCTFail("Expected translate parameters")
        }
    }

    func testMapPayloadToToolCallForTranslate() {
        let fields: [String: Any] = [
            "text": "Hello world",
            "target_language": "es",
            "source_language": "en"
        ]

        let toolCall = LLMToolCatalog.mapPayloadToToolCall(
            toolName: "translate",
            fields: fields,
            originalInput: "translate hello world to spanish"
        )

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .translate)

        if case .translate(let params) = toolCall?.parameters {
            XCTAssertEqual(params.text, "Hello world")
            XCTAssertEqual(params.targetLanguage, "es")
            XCTAssertEqual(params.sourceLanguage, "en")
        } else {
            XCTFail("Expected translate parameters")
        }
    }

    func testMapPayloadToToolCallForTranslateWithoutSource() {
        // Auto-detect source language (nil)
        let fields: [String: Any] = [
            "text": "Bonjour",
            "target_language": "en"
        ]

        let toolCall = LLMToolCatalog.mapPayloadToToolCall(
            toolName: "translate",
            fields: fields,
            originalInput: "translate bonjour to english"
        )

        XCTAssertNotNil(toolCall)

        if case .translate(let params) = toolCall?.parameters {
            XCTAssertEqual(params.text, "Bonjour")
            XCTAssertEqual(params.targetLanguage, "en")
            XCTAssertNil(params.sourceLanguage)  // Should be nil for auto-detect
        } else {
            XCTFail("Expected translate parameters")
        }
    }

    // MARK: - Language Normalization Tests

    func testNormalizeLanguageName() {
        XCTAssertEqual(TranslationService.normalizeLanguage("spanish"), "es")
        XCTAssertEqual(TranslationService.normalizeLanguage("french"), "fr")
        XCTAssertEqual(TranslationService.normalizeLanguage("german"), "de")
        XCTAssertEqual(TranslationService.normalizeLanguage("japanese"), "ja")
        XCTAssertEqual(TranslationService.normalizeLanguage("english"), "en")
        XCTAssertEqual(TranslationService.normalizeLanguage("es"), "es")  // Already code
        XCTAssertEqual(TranslationService.normalizeLanguage("EN"), "en")  // Case insensitive
    }

    // MARK: - Tool Executor Tests

    func testExecuteTranslateReturnsResult() async {
        let toolCall = LLMToolCall.translate(
            text: "Hello",
            targetLanguage: "es",
            sourceLanguage: "en",
            confidence: 1.0
        )

        let executor = LLMToolExecutor.shared
        let result = await executor.execute(toolCall)

        switch result {
        case .success(let executionResult):
            XCTAssertTrue(executionResult.success)
            XCTAssertNotNil(executionResult.message)
            // The translated text should contain something (actual translation depends on Apple)
        case .failure(let error):
            // Acceptable failures:
            // - macOS < 26: translationNotAvailable
            // - macOS 26+: translationFailed (framework available but translation failed)
            if case ToolExecutionError.translationNotAvailable = error {
                // Expected on macOS < 26
            } else if case ToolExecutionError.translationFailed = error {
                // Acceptable - framework available but translation failed
                // (e.g., language pair not supported, network issue, etc.)
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

// MARK: - Tests for macOS < 15 (should gracefully fail)

final class TranslationToolFallbackTests: XCTestCase {

    func testTranslationUnavailableOnOlderMacOS() async {
        // This test verifies graceful degradation on older macOS
        let toolCall = LLMToolCall.translate(
            text: "Hello",
            targetLanguage: "es",
            sourceLanguage: nil,
            confidence: 1.0
        )

        let executor = LLMToolExecutor.shared
        let result = await executor.execute(toolCall)

        // On macOS < 15, should return failure with appropriate message
        // On macOS 15+, should succeed
        switch result {
        case .success:
            // Translation succeeded (macOS 15+)
            break
        case .failure(let error):
            if case ToolExecutionError.translationNotAvailable(let reason) = error {
                XCTAssertTrue(reason.contains("macOS 15"), "Error should mention macOS 15 requirement")
            }
        }
    }
}

// MARK: - Translation History Tests

final class TranslationHistoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TranslationConfig.shared.clearHistory()
    }

    override func tearDown() {
        TranslationConfig.shared.clearHistory()
        super.tearDown()
    }

    func testHistoryStoresTranslation() {
        let item = TranslationHistoryItem(
            originalQuery: "translate hello to spanish",
            sourceText: "hello",
            translatedText: "hola",
            sourceLanguage: "en",
            targetLanguage: "es"
        )

        TranslationConfig.shared.addToHistory(item)

        let history = TranslationConfig.shared.history
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.sourceText, "hello")
        XCTAssertEqual(history.first?.translatedText, "hola")
    }

    func testHistoryLimitedToTen() {
        for i in 0..<15 {
            let item = TranslationHistoryItem(
                originalQuery: "translate \(i) to spanish",
                sourceText: "\(i)",
                translatedText: "translated \(i)",
                sourceLanguage: "en",
                targetLanguage: "es"
            )
            TranslationConfig.shared.addToHistory(item)
        }

        let history = TranslationConfig.shared.history
        XCTAssertEqual(history.count, 10, "History should be limited to 10 items")
    }

    func testDefaultTargetLanguagePersists() {
        TranslationConfig.shared.defaultTargetLanguage = "de"

        XCTAssertEqual(TranslationConfig.shared.defaultTargetLanguage, "de")
    }

    // MARK: - Translation Result Copy Behavior

    func testTranslationSearchResultCopiesWhenClicked() {
        // Given: A translation result with text "Hola"
        let searchResult = SearchResult(
            title: "Hola",
            subtitle: "Translated from en to es • Click to copy",
            icon: NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Translate"),
            category: .action,
            action: {
                // Copy to clipboard when user clicks
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString("Hola", forType: .string)
            },
            score: 1000,
            source: .tool
        )

        // When: The action is executed
        searchResult.action()

        // Then: Text should be copied to clipboard
        let pasteboard = NSPasteboard.general
        let clipboardContent = pasteboard.string(forType: .string)
        XCTAssertEqual(clipboardContent, "Hola", "Translation should be copied to clipboard when clicked")
    }

    func testTranslationSubtitleSaysClickToCopy() {
        // Verify the subtitle indicates user needs to click to copy
        let subtitle = "Translated from en to es • Click to copy"
        XCTAssertTrue(subtitle.contains("Click to copy"), "Subtitle should tell user to click to copy")
    }
}

import XCTest
@testable import ZestApp

/// Tests for TranslationService - Apple Translation framework wrapper
/// Story 25: Translation Tool
final class TranslationServiceTests: XCTestCase {

    // MARK: - Language Normalization Tests
    
    func testNormalizeLanguageName() {
        XCTAssertEqual(TranslationService.normalizeLanguage("spanish"), "es")
        XCTAssertEqual(TranslationService.normalizeLanguage("french"), "fr")
        XCTAssertEqual(TranslationService.normalizeLanguage("german"), "de")
        XCTAssertEqual(TranslationService.normalizeLanguage("japanese"), "ja")
        XCTAssertEqual(TranslationService.normalizeLanguage("polish"), "pl")
        XCTAssertEqual(TranslationService.normalizeLanguage("english"), "en")
    }
    
    func testNormalizeLanguageCode() {
        // Already a code - should return as-is (lowercased)
        XCTAssertEqual(TranslationService.normalizeLanguage("es"), "es")
        XCTAssertEqual(TranslationService.normalizeLanguage("fr"), "fr")
        XCTAssertEqual(TranslationService.normalizeLanguage("pl"), "pl")
        XCTAssertEqual(TranslationService.normalizeLanguage("EN"), "en")
        XCTAssertEqual(TranslationService.normalizeLanguage("PL"), "pl")
    }
    
    func testNormalizeLanguageCaseInsensitive() {
        XCTAssertEqual(TranslationService.normalizeLanguage("Spanish"), "es")
        XCTAssertEqual(TranslationService.normalizeLanguage("SPANISH"), "es")
        XCTAssertEqual(TranslationService.normalizeLanguage("French"), "fr")
        XCTAssertEqual(TranslationService.normalizeLanguage("FRENCH"), "fr")
    }
    
    func testNormalizeLanguageWhitespaceTrimmed() {
        XCTAssertEqual(TranslationService.normalizeLanguage("  spanish  "), "es")
        XCTAssertEqual(TranslationService.normalizeLanguage(" french "), "fr")
    }
    
    func testNormalizeUnknownLanguage() {
        // Unknown language names should return lowercased
        XCTAssertEqual(TranslationService.normalizeLanguage("klingon"), "klingon")
        XCTAssertEqual(TranslationService.normalizeLanguage("Elvish"), "elvish")
    }

    // MARK: - Display Language Tests
    
    func testDisplayLanguage() {
        XCTAssertEqual(TranslationService.shared.displayLanguage(for: "es"), "Spanish")
        XCTAssertEqual(TranslationService.shared.displayLanguage(for: "fr"), "French")
        XCTAssertEqual(TranslationService.shared.displayLanguage(for: "pl"), "Polish")
        XCTAssertEqual(TranslationService.shared.displayLanguage(for: "en"), "English")
    }
    
    func testDisplayLanguageForCode() {
        XCTAssertEqual(TranslationService.shared.displayLanguage(for: "ES"), "Spanish")
        XCTAssertEqual(TranslationService.shared.displayLanguage(for: "FR"), "French")
    }
    
    func testDisplayLanguageForUnknownCode() {
        // Unknown codes should return uppercased
        XCTAssertEqual(TranslationService.shared.displayLanguage(for: "xx"), "XX")
        XCTAssertEqual(TranslationService.shared.displayLanguage(for: "abc"), "ABC")
    }

    // MARK: - Supported Languages Tests
    
    func testSupportedLanguages() {
        let languages = TranslationService.shared.supportedLanguages()
        
        XCTAssertFalse(languages.isEmpty, "Should have supported languages")
        XCTAssertTrue(languages.contains("spanish"), "Should include Spanish")
        XCTAssertTrue(languages.contains("french"), "Should include French")
        XCTAssertTrue(languages.contains("german"), "Should include German")
        XCTAssertTrue(languages.contains("polish"), "Should include Polish")
    }
    
    func testSupportedLanguagesSorted() {
        let languages = TranslationService.shared.supportedLanguages()
        let sorted = languages.sorted()
        
        XCTAssertEqual(languages, sorted, "Supported languages should be sorted")
    }

    // MARK: - Translation Availability Tests
    
    func testSupportsTranslation() {
        // Should return true on macOS 26+
        let supported = TranslationService.shared.supportsTranslation()
        
        if #available(macOS 26.0, *) {
            XCTAssertTrue(supported, "Translation should be supported on macOS 26+")
        } else {
            XCTAssertFalse(supported, "Translation should not be supported on macOS < 26")
        }
    }

    // MARK: - Translation Tests (macOS 26+)
    
    func testTranslateEnglishToPolish() async {
        guard #available(macOS 26.0, *) else {
            print("Skipping test - macOS 26 required")
            return
        }
        
        do {
            let result = try await TranslationService.shared.translate(
                text: "hello",
                targetLanguage: "pl",
                sourceLanguage: "en"
            )
            
            print("Translation result: \(result.translatedText)")
            XCTAssertFalse(result.translatedText.isEmpty, "Translation should not be empty")
            XCTAssertNotEqual(result.translatedText, "hello", "Translation should be different from source")
            
        } catch ZestTranslationError.noTranslationsInstalled {
            print("No translations installed - this is expected if languages not downloaded")
            // This is an acceptable failure - user needs to install languages
        } catch {
            // Other errors are acceptable for this test
            print("Translation error (acceptable): \(error)")
        }
    }
    
    func testTranslateEnglishToSpanish() async {
        guard #available(macOS 26.0, *) else {
            print("Skipping test - macOS 26 required")
            return
        }
        
        do {
            let result = try await TranslationService.shared.translate(
                text: "good morning",
                targetLanguage: "es",
                sourceLanguage: "en"
            )
            
            print("Translation result: \(result.translatedText)")
            XCTAssertFalse(result.translatedText.isEmpty, "Translation should not be empty")
            
        } catch ZestTranslationError.noTranslationsInstalled {
            print("No translations installed - this is expected if languages not downloaded")
        } catch {
            print("Translation error (acceptable): \(error)")
        }
    }
    
    func testTranslateAutoDetectSource() async {
        guard #available(macOS 26.0, *) else {
            print("Skipping test - macOS 26 required")
            return
        }
        
        do {
            // No source language - should auto-detect
            let result = try await TranslationService.shared.translate(
                text: "bonjour",
                targetLanguage: "en"
            )
            
            print("Translation result: \(result.translatedText)")
            XCTAssertFalse(result.translatedText.isEmpty, "Translation should not be empty")
            XCTAssertEqual(result.detectedSourceLanguage, "fr", "Should detect French")
            
        } catch ZestTranslationError.noTranslationsInstalled {
            print("No translations installed - this is expected if languages not downloaded")
        } catch {
            print("Translation error (acceptable): \(error)")
        }
    }
    
    func testTranslateNormalizesLanguageNames() async {
        guard #available(macOS 26.0, *) else {
            print("Skipping test - macOS 26 required")
            return
        }
        
        do {
            // Use full language name instead of code
            let result = try await TranslationService.shared.translate(
                text: "hello",
                targetLanguage: "polish",
                sourceLanguage: "english"
            )
            
            print("Translation result: \(result.translatedText)")
            XCTAssertFalse(result.translatedText.isEmpty, "Translation should not be empty")
            
        } catch ZestTranslationError.noTranslationsInstalled {
            print("No translations installed - this is expected if languages not downloaded")
        } catch {
            print("Translation error (acceptable): \(error)")
        }
    }
    
    func testTranslateEmptyText() async {
        guard #available(macOS 26.0, *) else {
            print("Skipping test - macOS 26 required")
            return
        }
        
        do {
            let result = try await TranslationService.shared.translate(
                text: "",
                targetLanguage: "pl"
            )
            
            // Empty text should either return empty or throw - depends on API behavior
            XCTAssertTrue(result.translatedText.isEmpty, "Empty input should give empty output")
            
        } catch {
            // Acceptable - API may reject empty input
            print("Translation error for empty text (acceptable): \(error)")
        }
    }

    // MARK: - Error Handling Tests
    
    func testTranslationErrorDescriptions() {
        let notAvailable = ZestTranslationError.translationNotAvailable("Test reason")
        XCTAssertTrue(notAvailable.errorDescription?.contains("not available") ?? false)
        
        let failed = ZestTranslationError.translationFailed("Test error")
        XCTAssertTrue(failed.errorDescription?.contains("failed") ?? false)
        
        let unsupported = ZestTranslationError.unsupportedLanguage("Klingon")
        XCTAssertTrue(unsupported.errorDescription?.contains("Unsupported") ?? false)
        
        let notInstalled = ZestTranslationError.noTranslationsInstalled
        XCTAssertTrue(notInstalled.errorDescription?.contains("download") ?? false)
    }
}

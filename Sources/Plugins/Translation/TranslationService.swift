import AppKit
import Foundation
import Translation

// MARK: - Translation Result

/// Result of a translation operation
struct TranslationResult: Equatable {
    let translatedText: String
    let detectedSourceLanguage: String?
}

// MARK: - Zest Translation Error

/// Errors that can occur during translation
enum ZestTranslationError: Error, LocalizedError {
    case translationNotAvailable(String)
    case translationFailed(String)
    case unsupportedLanguage(String)
    case noTranslationsInstalled

    var errorDescription: String? {
        switch self {
        case .translationNotAvailable(let reason):
            return "Translation not available: \(reason)"
        case .translationFailed(let reason):
            return "Translation failed: \(reason)"
        case .unsupportedLanguage(let language):
            return "Unsupported language: \(language)"
        case .noTranslationsInstalled:
            return "No translations installed. Please download languages in System Settings > General > Language & Region > Translation Languages."
        }
    }
}

// MARK: - Translation Service

/// Service that provides translation functionality using Apple's Translation framework
/// Requires macOS 26.0 or later for offline translation
final class TranslationService: @unchecked Sendable {
    // MARK: - Singleton

    static let shared = TranslationService()

    private init() {}

    // MARK: - Language Name Mapping

    /// Maps language names to ISO codes
    private static let languageMap: [String: String] = [
        "spanish": "es",
        "french": "fr",
        "german": "de",
        "japanese": "ja",
        "korean": "ko",
        "chinese": "zh",
        "italian": "it",
        "portuguese": "pt",
        "russian": "ru",
        "arabic": "ar",
        "hindi": "hi",
        "dutch": "nl",
        "polish": "pl",
        "swedish": "sv",
        "norwegian": "no",
        "danish": "da",
        "finnish": "fi",
        "greek": "el",
        "turkish": "tr",
        "indonesian": "id",
        "vietnamese": "vi",
        "thai": "th",
        "hebrew": "he",
        "catalan": "ca",
        "ukrainian": "uk",
        "czech": "cs",
        "slovak": "sk",
        "hungarian": "hu",
        "romanian": "ro",
        "bulgarian": "bg",
        "malay": "ms",
        "malayalam": "ml",
        "english": "en"
    ]

    /// Normalize language names to ISO codes
    /// - Parameter input: Language name (e.g., "spanish", "french", "german") or code (e.g., "es", "fr")
    /// - Returns: ISO language code or lowercase input if already a code
    static func normalizeLanguage(_ input: String) -> String {
        let lower = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's a known language name
        if let code = languageMap[lower] {
            return code
        }

        // Check if it's already a valid language code (2-letter code)
        if lower.count == 2 {
            return lower
        }

        // Return as-is (lowercased) - the translation API will handle validation
        return lower
    }

    // MARK: - Translation

    /// Translate text using Apple Translation framework
    /// - Parameters:
    ///   - text: Text to translate
    ///   - targetLanguage: Target language code (e.g., "es", "fr")
    ///   - sourceLanguage: Optional source language code (for auto-detect if nil)
    /// - Returns: TranslationResult with translated text
    public func translate(
        text: String,
        targetLanguage: String,
        sourceLanguage: String? = nil
    ) async throws -> TranslationResult {
        print("🌐 TranslationService: Translating '\(text)' to \(targetLanguage)")

        // Normalize language codes
        let normalizedTarget = Self.normalizeLanguage(targetLanguage)
        let normalizedSource = sourceLanguage.map { Self.normalizeLanguage($0) }
        
        print("🌐 Normalized: source=\(normalizedSource ?? "auto") target=\(normalizedTarget)")

        // Check macOS version - Translation requires macOS 26+
        if #available(macOS 26.0, *) {
            return try await translateWithAppleFramework(
                text: text,
                targetLanguage: normalizedTarget,
                sourceLanguage: normalizedSource
            )
        } else {
            print("🌐 Translation not available: macOS < 26")
            throw ZestTranslationError.translationNotAvailable(
                "Translation requires macOS 26 or later (Sequoia)."
            )
        }
    }

    /// Check if macOS version supports translation
    /// - Returns: true if macOS 26.0+
    public func supportsTranslation() -> Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }

    /// Get supported languages
    func supportedLanguages() -> [String] {
        Array(Self.languageMap.keys.sorted())
    }

    /// Normalize language for display
    public func displayLanguage(for code: String) -> String {
        if let (name, _) = Self.languageMap.first(where: { $0.value == code.lowercased() }) {
            return name.capitalized
        }
        return code.uppercased()
    }

    // MARK: - Apple Translation Framework (macOS 26+)

    @available(macOS 26.0, *)
    private func translateWithAppleFramework(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?
    ) async throws -> TranslationResult {
        print("🌐 translateWithAppleFramework: text='\(text)' target=\(targetLanguage) source=\(sourceLanguage ?? "nil")")
        
        // Use Apple's Translation framework
        let source: Locale.Language
        if let sourceLang = sourceLanguage {
            source = Locale.Language(identifier: sourceLang)
        } else {
            // For auto-detect, use English as a fallback - the system will detect
            source = Locale.Language(identifier: "en")
        }
        
        let target = Locale.Language(identifier: targetLanguage)
        
        print("🌐 Created locales: source=\(source) target=\(target)")
        
        // Create translation session with the correct initializer
        let session = TranslationSession(installedSource: source, target: target)
        
        print("🌐 Created TranslationSession, attempting translation...")
        
        do {
            let translation = try await session.translate(text)
            
            print("🌐 Translation succeeded!")
            
            // Get the translated text
            let translatedText = translation.targetText
            
            // Detect source language if available
            let detectedSource: String? = translation.sourceLanguage.languageCode.flatMap { $0.identifier }
            
            print("🌐 Result: '\(text)' -> '\(translatedText)' (detected: \(detectedSource ?? "none"))")
            
            // Save to history
            let historyItem = TranslationHistoryItem(
                originalQuery: "Translation request",
                sourceText: text,
                translatedText: translatedText,
                sourceLanguage: detectedSource ?? sourceLanguage ?? "auto",
                targetLanguage: targetLanguage
            )
            TranslationConfig.shared.addToHistory(historyItem)
            
            return TranslationResult(
                translatedText: translatedText,
                detectedSourceLanguage: detectedSource
            )
        } catch {
            // Handle translation errors
            print("🌐 Translation error: \(error) - \(type(of: error))")
            
            // Check if it's a no translations installed error
            let errorString = String(describing: error)
            if errorString.contains("notInstalled") {
                throw ZestTranslationError.noTranslationsInstalled
            } else if errorString.contains("languageNotAvailable") {
                throw ZestTranslationError.unsupportedLanguage("Language pair not available")
            } else {
                throw ZestTranslationError.translationFailed(error.localizedDescription)
            }
        }
    }
}

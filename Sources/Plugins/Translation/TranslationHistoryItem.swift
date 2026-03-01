import Foundation

/// History item for translation
struct TranslationHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let originalQuery: String
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date

    init(
        originalQuery: String,
        sourceText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String
    ) {
        self.id = UUID()
        self.originalQuery = originalQuery
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = Date()
    }
}

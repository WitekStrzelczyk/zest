import Foundation
import os.log

/// Configuration and persistence for translation settings and history
final class TranslationConfig: ObservableObject {
    // MARK: - Singleton

    static let shared = TranslationConfig()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.zest.app", category: "TranslationConfig")
    private let maxHistoryCount = 10

    /// Default target language for translations
    @Published var defaultTargetLanguage: String = "en"

    /// Translation history (limited to 10 items)
    @Published private(set) var history: [TranslationHistoryItem] = []

    // MARK: - Initialization

    private init() {
        loadFromDefaults()
    }

    // MARK: - Public API

    /// Add a translation to history
    /// - Parameter item: The translation history item to add
    func addToHistory(_ item: TranslationHistoryItem) {
        history.insert(item, at: 0)

        // Keep only the most recent items
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }

        saveToDefaults()
        logger.debug("Added translation to history: \(item.sourceText)")
    }

    /// Clear all translation history
    func clearHistory() {
        history.removeAll()
        saveToDefaults()
        logger.debug("Cleared translation history")
    }

    // MARK: - Persistence

    private let defaultsKey = "com.zest.translation.history"
    private let defaultLanguageKey = "com.zest.translation.defaultLanguage"

    private func saveToDefaults() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: defaultsKey)
            UserDefaults.standard.set(defaultTargetLanguage, forKey: defaultLanguageKey)
        } catch {
            logger.error("Failed to save translation history: \(error.localizedDescription)")
        }
    }

    private func loadFromDefaults() {
        // Load history
        if let data = UserDefaults.standard.data(forKey: defaultsKey) {
            do {
                history = try JSONDecoder().decode([TranslationHistoryItem].self, from: data)
            } catch {
                logger.error("Failed to load translation history: \(error.localizedDescription)")
                history = []
            }
        }

        // Load default language
        if let savedLanguage = UserDefaults.standard.string(forKey: defaultLanguageKey) {
            defaultTargetLanguage = savedLanguage
        }
    }
}

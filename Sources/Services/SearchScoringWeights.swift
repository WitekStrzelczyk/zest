import Foundation

/// Configurable weights for search scoring
/// Stored in UserDefaults for user customization
struct SearchScoringWeights: Codable {
    // MARK: - Category Weights
    
    /// Application results (highest priority)
    var categoryApplication: Double = 1.2
    /// Unit conversions
    var categoryConversion: Double = 1.1
    /// Calendar events and meetings
    var categoryCalendar: Double = 1.05
    /// Actions and commands
    var categoryAction: Double = 1.0
    /// Global actions (hotkeys)
    var categoryGlobalAction: Double = 1.0
    /// User bookmarks
    var categoryQuicklink: Double = 0.8
    /// Contact results
    var categoryContact: Double = 0.7
    /// Clipboard history
    var categoryClipboard: Double = 0.6
    /// File results
    var categoryFile: Double = 0.5
    /// Running processes
    var categoryProcess: Double = 0.5
    /// System toggles
    var categoryToggle: Double = 0.4
    /// Settings/preferences
    var categorySettings: Double = 0.3
    /// Emoji results
    var categoryEmoji: Double = 0.2
    
    // MARK: - Match Type Bonuses
    
    /// Exact match (query == title)
    var matchExact: Double = 1.0
    /// Prefix match (query is prefix of title)
    var matchPrefix: Double = 0.95
    /// Word start match (query is prefix of any word)
    var matchWordStart: Double = 0.9
    /// Fuzzy match (all chars in order)
    var matchFuzzy: Double = 0.7
    /// Substring match (in middle of word)
    var matchSubstring: Double = 0.5
    
    // MARK: - Default Instance
    
    static let `default` = SearchScoringWeights()
    
    // MARK: - UserDefaults
    
    private static let userDefaultsKey = "searchScoringWeights"
    
    /// Load weights from UserDefaults, or return defaults
    static func load() -> SearchScoringWeights {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let weights = try? JSONDecoder().decode(SearchScoringWeights.self, from: data) else {
            return .default
        }
        return weights
    }
    
    /// Save weights to UserDefaults
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
    
    // MARK: - Category Weight Lookup
    
    /// Get weight for a category
    func weight(for category: SearchResultCategory) -> Double {
        switch category {
        case .application: return categoryApplication
        case .conversion: return categoryConversion
        case .calendar: return categoryCalendar
        case .action: return categoryAction
        case .globalAction: return categoryGlobalAction
        case .quicklink: return categoryQuicklink
        case .contact: return categoryContact
        case .clipboard: return categoryClipboard
        case .file: return categoryFile
        case .process: return categoryProcess
        case .toggle: return categoryToggle
        case .settings: return categorySettings
        case .emoji: return categoryEmoji
        }
    }
}

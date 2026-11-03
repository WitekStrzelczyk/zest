import Foundation

struct SearchScoringWeights: Codable {
    var categoryApplication: Double = 1.2
    var categoryConversion: Double = 1.1
    var categoryCalendar: Double = 1.05
    var categoryAction: Double = 1.0
    var categoryGlobalAction: Double = 1.0
    var categoryQuicklink: Double = 0.8
    var categoryContact: Double = 0.7
    var categoryClipboard: Double = 0.6
    var categoryFile: Double = 0.5
    var categoryProcess: Double = 0.5
    var categoryToggle: Double = 0.4
    var categorySettings: Double = 0.3
    var categoryEmoji: Double = 0.2

    var matchExact: Double = 1.0
    var matchPrefix: Double = 0.95
    var matchWordStart: Double = 0.9
    var matchFuzzy: Double = 0.7
    var matchSubstring: Double = 0.5

    static let `default` = SearchScoringWeights()

    private static let userDefaultsKey = "searchScoringWeights"

    static func load() -> SearchScoringWeights {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let weights = try? JSONDecoder().decode(SearchScoringWeights.self, from: data)
        else {
            return .default
        }
        return weights
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }

    func weight(for category: SearchResultCategory) -> Double {
        let weights: [SearchResultCategory: Double] = [
            .application: categoryApplication,
            .conversion: categoryConversion,
            .calendar: categoryCalendar,
            .action: categoryAction,
            .globalAction: categoryGlobalAction,
            .quicklink: categoryQuicklink,
            .contact: categoryContact,
            .clipboard: categoryClipboard,
            .file: categoryFile,
            .process: categoryProcess,
            .toggle: categoryToggle,
            .settings: categorySettings,
            .emoji: categoryEmoji,
        ]
        return weights[category] ?? 0.0
    }
}

import Foundation

protocol SearchTool {
    var name: String { get }
    var endsSearch: Bool { get }
    func search(_ context: QueryContext) -> [SearchResult]
}

extension SearchTool {
    var endsSearch: Bool { false }

    func matchesKeyword(_ query: String, in keywords: [String]) -> Bool {
        let padded = " \(query) "
        return keywords.contains { padded.contains(" \($0) ") || (query.count >= 3 && $0.hasPrefix(query)) }
    }
}

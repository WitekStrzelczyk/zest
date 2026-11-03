import AppKit

final class MapSearchWorker: SearchTool {
    static let shared = MapSearchWorker()
    private init() {}

    private static let icon = NSImage(systemSymbolName: "map", accessibilityDescription: "Map")

    var name: String { "Map Search" }

    func search(_ context: QueryContext) -> [SearchResult] {
        guard let term = context.location?.trimmingCharacters(in: .whitespacesAndNewlines), term.count > 2 else {
            return []
        }
        return [SearchResult(
            title: "Search Map: \(term)",
            subtitle: "Open in Apple Maps",
            icon: Self.icon,
            category: .action,
            action: {
                let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "maps://?q=\(encoded)") { NSWorkspace.shared.open(url) }
            },
            score: 2700
        )]
    }
}

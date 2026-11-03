import AppKit

enum PersonalDataAccess {
    private static let requestIcon = NSImage(systemSymbolName: "lock.open", accessibilityDescription: "Allow access")
    private static let deniedIcon = NSImage(systemSymbolName: "lock", accessibilityDescription: "Access denied")

    static func requestResult(
        source: String,
        reason: String,
        category: SearchResultCategory,
        request: @escaping () async -> Void
    ) -> SearchResult {
        SearchResult(
            title: "Allow \(source) access",
            subtitle: reason,
            icon: requestIcon,
            category: category,
            action: { Task { await request() } },
            score: 1000
        )
    }

    static func deniedResult(source: String, settingsAnchor: String, category: SearchResultCategory) -> SearchResult {
        SearchResult(
            title: "\(source) access is off",
            subtitle: "Turn it on in System Settings › Privacy & Security › \(source)",
            icon: deniedIcon,
            category: category,
            action: {
                let link = "x-apple.systempreferences:com.apple.preference.security?\(settingsAnchor)"
                if let url = URL(string: link) { NSWorkspace.shared.open(url) }
            },
            score: 1000,
            isWarning: true
        )
    }
}

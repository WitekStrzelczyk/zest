import Foundation

struct Quicklink: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var url: String
    var keywords: [String]
    var keyboardShortcut: String?
    var createdAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        keywords: [String] = [],
        keyboardShortcut: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.keywords = keywords
        self.keyboardShortcut = keyboardShortcut
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    var isValidURL: Bool {
        guard let url = URL(string: url) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    var normalizedURL: String {
        if url.hasPrefix("http://") || url.hasPrefix("https://") {
            return url
        }
        return "https://\(url)"
    }
}

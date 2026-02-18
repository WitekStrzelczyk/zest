import AppKit

/// Display priority: lower rawValue appears higher in results
enum SearchResultCategory: Int, Comparable {
    case application = 0
    case action = 1
    case contact = 2
    case clipboard = 3
    case file = 4
    case emoji = 5

    static func < (lhs: SearchResultCategory, rhs: SearchResultCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct SearchResult {
    let title: String
    let subtitle: String
    let icon: NSImage?
    let action: () -> Void
    let revealAction: (() -> Void)?
    let category: SearchResultCategory

    /// File path for Quick Look preview (nil for non-file results)
    let filePath: String?

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        category: SearchResultCategory = .action,
        action: @escaping () -> Void,
        revealAction: (() -> Void)? = nil,
        filePath: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.action = action
        self.revealAction = revealAction
        self.filePath = filePath
    }

    /// Returns true if this result represents a file that can be previewed with Quick Look
    var isFileResult: Bool {
        subtitle == "File" && filePath != nil
    }

    /// Returns the file URL for Quick Look preview (nil if not a file result)
    var fileURL: URL? {
        guard let filePath else { return nil }
        return URL(fileURLWithPath: filePath)
    }

    func execute() {
        action()
    }

    func reveal() {
        revealAction?()
    }
}

struct InstalledApp {
    let name: String
    let bundleID: String
    let icon: NSImage?
}

import AppKit

/// Display priority: lower rawValue appears higher in results
enum SearchResultCategory: Int, Comparable {
    case application = 0
    case process = 1
    case action = 2
    case contact = 3
    case clipboard = 4
    case file = 5
    case emoji = 6
    case globalAction = 7
    case quicklink = 8
    case settings = 9
    case toggle = 10

    static func < (lhs: SearchResultCategory, rhs: SearchResultCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// Human-readable name for search matching
    var displayName: String {
        switch self {
        case .application: return "application app"
        case .process: return "process system monitor"
        case .action: return "action command shortcut"
        case .contact: return "contact"
        case .clipboard: return "clipboard history"
        case .file: return "file document"
        case .emoji: return "emoji"
        case .globalAction: return "command shortcut hotkey"
        case .quicklink: return "quicklink bookmark"
        case .settings: return "settings preference"
        case .toggle: return "toggle switch"
        }
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

    /// Search relevance score (higher = more relevant)
    let score: Int

    /// Whether this result is currently active (for toggles)
    let isActive: Bool

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        category: SearchResultCategory = .action,
        action: @escaping () -> Void,
        revealAction: (() -> Void)? = nil,
        filePath: String? = nil,
        score: Int = 0,
        isActive: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.action = action
        self.revealAction = revealAction
        self.filePath = filePath
        self.score = score
        self.isActive = isActive
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

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when user selects "Add Quicklink" from settings
    static let showAddQuicklink = Notification.Name("showAddQuicklink")
    
    /// Posted when user navigates back from quicklink creation
    static let hideAddQuicklink = Notification.Name("hideAddQuicklink")
}

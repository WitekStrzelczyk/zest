import AppKit

enum SearchResultSource {
    case standard
    case tool
}

/// Display priority: lower rawValue appears higher in results
enum SearchResultCategory: Int, Comparable {
    case application = 0
    case conversion = 1  // Unit conversions - high priority
    case process = 2
    case calendar = 3    // Calendar events and meetings
    case action = 4
    case contact = 5
    case clipboard = 6
    case file = 7
    case emoji = 8
    case globalAction = 9
    case quicklink = 10
    case settings = 11
    case toggle = 12

    static func < (lhs: SearchResultCategory, rhs: SearchResultCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// Human-readable name for search matching
    var displayName: String {
        switch self {
        case .application: return "application app"
        case .conversion: return "conversion unit"
        case .process: return "process system monitor"
        case .calendar: return "calendar meeting event schedule"
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

    /// Optional tint color for the result (e.g., calendar color)
    let tintColor: NSColor?

    /// Optional trailing icon displayed on the right side (e.g., video platform icon)
    let trailingIcon: NSImage?

    /// Origin of the result used for ranking boosts.
    let source: SearchResultSource
    
    /// Whether a kill attempt has been made (for process results - two-phase kill)
    let isKillAttempted: Bool

    /// Process ID for process results (used to check if process died after kill)
    let pid: pid_t?

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        category: SearchResultCategory = .action,
        action: @escaping () -> Void,
        revealAction: (() -> Void)? = nil,
        filePath: String? = nil,
        score: Int = 0,
        isActive: Bool = false,
        tintColor: NSColor? = nil,
        trailingIcon: NSImage? = nil,
        source: SearchResultSource = .standard,
        isKillAttempted: Bool = false,
        pid: pid_t? = nil
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
        self.tintColor = tintColor
        self.trailingIcon = trailingIcon
        self.source = source
        self.isKillAttempted = isKillAttempted
        self.pid = pid
    }

    static func rankedBefore(_ lhs: SearchResult, _ rhs: SearchResult) -> Bool {
        if lhs.source != rhs.source {
            return lhs.source == .tool
        }
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        return lhs.category < rhs.category
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

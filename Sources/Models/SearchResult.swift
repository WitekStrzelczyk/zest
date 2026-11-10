import AppKit

enum SearchResultSource {
    case standard
    case tool
}

enum SearchResultCategory: Int, Comparable {
    case application = 0
    case conversion = 1
    case process = 2
    case calendar = 3
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

    var displayName: String {
        switch self {
        case .application: "application app"
        case .conversion: "conversion unit"
        case .process: "process system monitor"
        case .calendar: "calendar meeting event schedule"
        case .action: "action command shortcut"
        case .contact: "contact"
        case .clipboard: "clipboard history"
        case .file: "file document"
        case .emoji: "emoji"
        case .globalAction: "command shortcut hotkey"
        case .quicklink: "quicklink bookmark"
        case .settings: "settings preference"
        case .toggle: "toggle switch"
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

    let filePath: String?

    var score: Int

    var isWarning: Bool = false

    let isActive: Bool

    let tintColor: NSColor?

    let trailingIcon: NSImage?

    let source: SearchResultSource

    let isKillAttempted: Bool

    let pid: pid_t?

    let fileDetails: FileDetails?

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        category: SearchResultCategory = .action,
        action: @escaping () -> Void,
        revealAction: (() -> Void)? = nil,
        filePath: String? = nil,
        score: Int = 0,
        isWarning: Bool = false,
        isActive: Bool = false,
        tintColor: NSColor? = nil,
        trailingIcon: NSImage? = nil,
        source: SearchResultSource = .standard,
        isKillAttempted: Bool = false,
        pid: pid_t? = nil,
        fileDetails: FileDetails? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.action = action
        self.revealAction = revealAction
        self.filePath = filePath
        self.score = score
        self.isWarning = isWarning
        self.isActive = isActive
        self.tintColor = tintColor
        self.trailingIcon = trailingIcon
        self.source = source
        self.isKillAttempted = isKillAttempted
        self.pid = pid
        self.fileDetails = fileDetails
    }

    static func showsSameRow(_ lhs: SearchResult, _ rhs: SearchResult) -> Bool {
        lhs.title == rhs.title && lhs.subtitle == rhs.subtitle && lhs.category == rhs.category
            && lhs.isKillAttempted == rhs.isKillAttempted
    }

    static func rankedBefore(_ lhs: SearchResult, _ rhs: SearchResult) -> Bool {
        if lhs.source != rhs.source {
            return lhs.source == .tool
        }
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        return lhs.category < rhs.category
    }

    var isFileResult: Bool {
        subtitle == "File" && filePath != nil
    }

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
    let path: String
}

extension Notification.Name {
    static let showAddQuicklink = Notification.Name("showAddQuicklink")

    static let hideAddQuicklink = Notification.Name("hideAddQuicklink")

    static let processWasKilled = Notification.Name("processWasKilled")

    static let installedAppsUpdated = Notification.Name("installedAppsUpdated")
}

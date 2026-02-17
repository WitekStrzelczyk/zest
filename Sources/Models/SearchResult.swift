import AppKit

struct SearchResult {
    let title: String
    let subtitle: String
    let icon: NSImage?
    let action: () -> Void
    let revealAction: (() -> Void)?

    /// File path for Quick Look preview (nil for non-file results)
    let filePath: String?

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        action: @escaping () -> Void,
        revealAction: (() -> Void)? = nil,
        filePath: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
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

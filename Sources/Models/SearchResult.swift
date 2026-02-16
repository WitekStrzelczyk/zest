import AppKit

struct SearchResult {
    let title: String
    let subtitle: String
    let icon: NSImage?
    let action: () -> Void
    let revealAction: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        action: @escaping () -> Void,
        revealAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
        self.revealAction = revealAction
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

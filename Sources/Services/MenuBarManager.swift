import AppKit
import Foundation

/// Manages menu bar presence and actions for Zest
final class MenuBarManager {
    // MARK: - Properties

    private(set) var statusItem: NSStatusItem?
    var onMenuBarClick: (() -> Void)?
    var onPreferencesSelected: (() -> Void)?
    var onQuitSelected: (() -> Void)?

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Sets up the status bar item with menu
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }

        // Set menu bar icon
        if let image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Zest") {
            image.isTemplate = true
            button.image = image
        }

        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Create menu
        setupMenu()
    }

    /// Removes the status bar item
    func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: - Private Methods

    private func setupMenu() {
        let menu = NSMenu()

        // Recent Items submenu
        let recentMenu = NSMenu()
        recentMenu.addItem(withTitle: "No recent items", action: nil, keyEquivalent: "")
        recentMenu.items.first?.isEnabled = false

        let recentItem = NSMenuItem(title: "Recent Items", action: nil, keyEquivalent: "")
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(preferencesSelected(_:)),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Zest",
            action: #selector(quitSelected(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func statusBarButtonClicked(_: Any?) {
        onMenuBarClick?()
    }

    @objc private func preferencesSelected(_: Any?) {
        onPreferencesSelected?()
    }

    @objc private func quitSelected(_: Any?) {
        onQuitSelected?()
    }

    // MARK: - Public Methods for Updates

    /// Updates the recent items menu
    func updateRecentItems(_ items: [String]) {
        guard let menu = statusItem?.menu,
              let recentItem = menu.items.first(where: { $0.title == "Recent Items" }),
              let submenu = recentItem.submenu else { return }

        submenu.removeAllItems()

        if items.isEmpty {
            let emptyItem = NSMenuItem(title: "No recent items", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for item in items {
                let menuItem = NSMenuItem(title: item, action: nil, keyEquivalent: "")
                submenu.addItem(menuItem)
            }
        }
    }
}

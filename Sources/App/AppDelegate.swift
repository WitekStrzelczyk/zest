import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var commandPaletteWindow: CommandPaletteWindow?

    /// Global hotkey identifiers for cleanup
    private var registeredHotkeyIds: [HotkeyIdentifier] = []

    func applicationDidFinishLaunching(_: Notification) {
        setupMenuBar()
        setupGlobalCommandHotkeys()
    }

    func applicationWillTerminate(_: Notification) {
        GlobalHotkeyManager.shared.unregisterAll()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Zest")
            button.action = #selector(menuBarClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func menuBarClicked(_: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleCommandPalette()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Open Zest", action: #selector(openPalette), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Zest", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPalette() {
        showCommandPalette()
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.showWindow()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Global Command Hotkeys

    private func setupGlobalCommandHotkeys() {
        let hotkeyManager = GlobalHotkeyManager.shared
        let commandsService = GlobalCommandsService.shared

        // Register Cmd+Space for command palette toggle (highest priority)
        let cmdSpaceId = hotkeyManager.register(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(cmdKey)
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.toggleCommandPalette()
            }
        }
        registeredHotkeyIds.append(cmdSpaceId)

        // Register each global command
        for command in commandsService.availableCommands {
            let identifier = hotkeyManager.register(
                keyCode: command.keyCode,
                modifiers: command.modifiers,
                action: command.action
            )
            registeredHotkeyIds.append(identifier)
        }
    }

    // MARK: - Command Palette

    private func toggleCommandPalette() {
        if let window = commandPaletteWindow, window.isVisible {
            window.close()
        } else {
            showCommandPalette()
        }
    }

    private func showCommandPalette() {
        if commandPaletteWindow == nil {
            commandPaletteWindow = CommandPaletteWindow()
        }

        // Save the currently active app before showing palette
        let previousApp = NSWorkspace.shared.frontmostApplication

        commandPaletteWindow?.show(previousApp: previousApp)
    }
}

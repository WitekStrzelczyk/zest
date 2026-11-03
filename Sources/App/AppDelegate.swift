import AppKit
import Carbon
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var commandPaletteWindow: CommandPaletteWindow?

    private var registeredHotkeyIds: [HotkeyIdentifier] = []
    private var themeSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_: Notification) {
        LaunchAtLoginService.shared.enabled = PreferencesManager.shared.launchAtLogin

        AwakeService.shared.applySavedPreference()
        themeSubscription = AppStyle.followTheme(of: PreferencesManager.shared)

        NSApp.mainMenu = Self.makeMainMenu()
        setupMenuBar()
        setupGlobalCommandHotkeys()
        setupColorPickerNotifications()

        ColorPickerPlugin.shared.onRegister()
    }

    func applicationWillTerminate(_: Notification) {
        GlobalHotkeyManager.shared.unregisterAll()
    }

    private func setupColorPickerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDismissCommandPalette),
            name: .zestDismissCommandPalette,
            object: nil
        )
    }

    @objc private func handleDismissCommandPalette() {
        DispatchQueue.main.async { [weak self] in
            self?.commandPaletteWindow?.close()
        }
    }

    static func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(
            title: "Quit Zest",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        return mainMenu
    }

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

    private func setupGlobalCommandHotkeys() {
        let hotkeyManager = GlobalHotkeyManager.shared
        let commandsService = GlobalCommandsService.shared

        let cmdSpaceId = hotkeyManager.register(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(cmdKey)
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.toggleCommandPalette()
            }
        }
        registeredHotkeyIds.append(cmdSpaceId)

        for command in commandsService.availableCommands {
            let identifier = hotkeyManager.register(
                keyCode: command.keyCode,
                modifiers: command.modifiers,
                action: command.action
            )
            registeredHotkeyIds.append(identifier)
        }
    }

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

        commandPaletteWindow?.show()
    }
}

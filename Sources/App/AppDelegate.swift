import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var commandPaletteWindow: CommandPaletteWindow?
    private var hotKeyRef: EventHotKeyRef?

    // Global hotkey identifiers for cleanup
    private var registeredHotkeyIds: [HotkeyIdentifier] = []

    func applicationDidFinishLaunching(_: Notification) {
        setupMenuBar()
        setupGlobalHotKey()
        setupGlobalCommandHotkeys()
    }

    func applicationWillTerminate(_: Notification) {
        unregisterHotKey()
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

    // MARK: - Global HotKey (Carbon API) - Cmd+Space for Command Palette

    private func setupGlobalHotKey() {
        // Register Cmd+Space as global hotkey
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x5A45_5354) // "ZEST"
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

        // Install event handler
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                AppDelegate.handleHotKeyEvent(event)
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        // Register Cmd+Space (keycode 49 = Space, cmdKey = 256)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("Failed to register hotkey: \(status)")
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }

    private static func handleHotKeyEvent(_ event: EventRef?) {
        guard let event else { return }

        var hotKeyID = EventHotKeyID()
        GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        if hotKeyID.id == 1 {
            DispatchQueue.main.async {
                self.shared.toggleCommandPalette()
            }
        }
    }

    private static var shared: AppDelegate {
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            fatalError("AppDelegate is not the expected type")
        }
        return appDelegate
    }

    // MARK: - Global Command Hotkeys

    private func setupGlobalCommandHotkeys() {
        let hotkeyManager = GlobalHotkeyManager.shared
        let commandsService = GlobalCommandsService.shared

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

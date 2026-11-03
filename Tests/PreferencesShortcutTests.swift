import AppKit
import Carbon
import Testing
@testable import ZestApp

@MainActor
final class PreferencesShortcutTests {
    private let window: CommandPaletteWindow

    init() {
        CommandPaletteWindow.showsOnScreen = false
        PreferencesWindowController.showsOnScreen = false
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        FileSearchService.isDisabled = true
        NSApplication.shared.mainMenu = AppDelegate.makeMainMenu()
        window = CommandPaletteWindow()
    }

    isolated deinit {
        window.close()
        PreferencesWindowController.shared.window?.orderOut(nil)
    }

    @Test func commandCommaInThePaletteOpensPreferences() throws {
        let preferences = try #require(PreferencesWindowController.shared.window)
        preferences.orderOut(nil)
        window.show(previousApp: nil)

        window.simulateKeyPress(keyCode: UInt16(kVK_ANSI_Comma), modifiers: .command)

        #expect(preferences.isVisible, "Cmd+, should open Preferences")
        #expect(!window.isVisible, "The palette should step aside for Preferences")
    }

    @Test func commandCommaOpensPreferencesWhileTyping() throws {
        let preferences = try #require(PreferencesWindowController.shared.window)
        preferences.orderOut(nil)
        window.show(previousApp: nil)
        window.setSearchFieldTextForTesting("spo")

        window.simulateKeyPress(keyCode: UInt16(kVK_ANSI_Comma), modifiers: .command)

        #expect(preferences.isVisible, "Cmd+, should open Preferences even with a query typed")
    }

    @Test func preferencesStaysInTheFooterWhetherOrNotThereAreResults() {
        window.show(previousApp: nil)
        #expect(window.isFooterVisible, "Preferences should show when the palette opens empty")

        CommandPaletteStateStore.shared.updateQuery("zzqxv", results: [])
        #expect(window.isFooterVisible, "Preferences should show when nothing matches")

        CommandPaletteStateStore.shared.updateQuery("")
        #expect(window.isFooterVisible, "Preferences should show again after clearing the query")
    }
}

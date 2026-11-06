import AppKit
import Carbon
import Testing
@testable import ZestApp

@MainActor
final class SettingsResultEnterTests {
    private let window: CommandPaletteWindow

    init() {
        CommandPaletteWindow.showsOnScreen = false
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        FileSearchService.isDisabled = true
        window = CommandPaletteWindow()
    }

    isolated deinit {
        window.exitSettingsMode()
        window.close()
    }

    @Test func enterOnASystemSettingsPageOpensThatPageNotTheQuicklinkForm() {
        var opened = false
        let page = SearchResult(
            title: "Check for Software Updates",
            subtitle: "System Settings › General › Software Update",
            icon: nil,
            category: .settings,
            action: { opened = true }
        )
        window.show(previousApp: nil)
        window.updateResultsForTesting([page])
        window.setSelectedIndexForTesting(0)

        window.simulateKeyPress(keyCode: UInt16(kVK_Return))

        #expect(opened, "Enter should open the System Settings page")
        #expect(!window.isSettingsMode, "Enter should not show the Add Quicklink form")
    }

    @Test func enterOnAddQuicklinkStillShowsTheForm() throws {
        let context = QueryAnalyzer.shared.analyze("add quicklink")
        let addQuicklink = try #require(QuicklinkManager.shared.search(context).first { $0.title == "Add Quicklink" })
        window.show(previousApp: nil)
        window.updateResultsForTesting([addQuicklink])
        window.setSelectedIndexForTesting(0)

        window.simulateKeyPress(keyCode: UInt16(kVK_Return))

        #expect(window.isSettingsMode, "Add Quicklink should open its form")
        #expect(window.isVisible, "The palette should stay open to show the form")
    }
}

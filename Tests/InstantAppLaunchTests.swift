import AppKit
import Testing
@testable import ZestApp

@MainActor
final class InstantAppLaunchTests {
    private let controller = CommandPaletteController.shared
    private let store = CommandPaletteStateStore.shared

    init() {
        CommandPaletteWindow.showsOnScreen = false
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        FileSearchService.isDisabled = true
        SearchEngine.shared.refreshInstalledApps()
    }

    isolated deinit {
        controller.handleQuery("")
    }

    @Test func typingTheStartOfAnAppNameShowsItAtOnce() {
        controller.handleQuery("saf")

        #expect(store.state.query == "saf")
        #expect(store.state.results.first?.title == "Safari", "Safari should be first the moment 'saf' is typed, without waiting for the debounce")
    }

    @Test func eachNewLetterReplacesTheAppsOfThePreviousLetter() {
        controller.handleQuery("t")
        controller.handleQuery("te")
        controller.handleQuery("ter")

        #expect(store.state.results.first?.title == "Terminal", "Enter right after 'ter' should open Terminal, not a match for 'te'")
    }

    @Test func aQueryMatchingNoAppShowsNoStaleApps() {
        controller.handleQuery("saf")
        controller.handleQuery("safzzqx")

        #expect(!store.state.results.contains { $0.title == "Safari" }, "Safari from 'saf' should not linger for 'safzzqx'")
    }

    @Test func pastingTheSameQueryAfterReopeningThePaletteFindsTheAppAgain() {
        let window = CommandPaletteWindow()
        window.show(previousApp: nil)
        controller.handleQuery("saf")
        window.close()

        window.show(previousApp: nil)
        controller.handleQuery("saf")

        #expect(store.state.query == "saf")
        #expect(store.state.results.first?.title == "Safari", "Reopening and pasting 'saf' again should show Safari")
        window.close()
    }
}

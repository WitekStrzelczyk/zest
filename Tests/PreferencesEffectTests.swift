import AppKit
import Combine
import Testing
@testable import ZestApp

final class SearchResultsLimitTests {
    init() {
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        FileSearchService.isDisabled = true
        PreferencesManager.shared.resetToDefaults()
    }

    deinit {
        PreferencesManager.shared.resetToDefaults()
    }

    @Test func listingProcessesShowsNoMoreThanTheChosenLimit() {
        PreferencesManager.shared.searchResultsLimit = 10

        let results = SearchEngine.shared.search(query: "processes")

        #expect(!results.isEmpty, "Should still list processes")
        #expect(results.count <= 10, "Should show at most the 10 results chosen in Preferences")
    }

    @Test func theDefaultLimitKeepsLongListsWhole() {
        let results = SearchEngine.shared.search(query: "processes")

        #expect(results.count > 10, "The default limit should not cut the process list to 10")
    }
}

@MainActor
final class PaletteThemeTests {
    init() {
        PreferencesManager.shared.resetToDefaults()
    }

    isolated deinit {
        NSApplication.shared.appearance = nil
        PreferencesManager.shared.resetToDefaults()
    }

    @Test func choosingAThemeInPreferencesChangesZestsAppearance() {
        let subscription = AppStyle.followTheme(of: PreferencesManager.shared)

        PreferencesManager.shared.theme = .dark
        #expect(NSApplication.shared.appearance?.name == .darkAqua, "Dark should make Zest dark")

        PreferencesManager.shared.theme = .light
        #expect(NSApplication.shared.appearance?.name == .aqua, "Light should make Zest light")

        PreferencesManager.shared.theme = .system
        #expect(NSApplication.shared.appearance == nil, "System should follow the Mac's appearance")

        subscription.cancel()
    }

    @Test func openingThePaletteAfterChoosingAThemeShowsTheSearchBarInThatTheme() throws {
        let subscription = AppStyle.followTheme(of: PreferencesManager.shared)
        let window = CommandPaletteWindow()
        let searchBar = try #require(window.searchField.superview)

        PreferencesManager.shared.theme = .light
        window.show(previousApp: nil)
        let lightColor = try #require(searchBar.layer?.backgroundColor)
        window.close()

        PreferencesManager.shared.theme = .dark
        window.show(previousApp: nil)
        let darkColor = try #require(searchBar.layer?.backgroundColor)
        window.close()

        #expect(lightColor != darkColor, "The search bar should be repainted in the chosen theme")
        subscription.cancel()
    }
}

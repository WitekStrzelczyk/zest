import AppKit
import Testing
@testable import ZestApp

@MainActor
struct PreferencesWindowTests {
    @Test func preferencesOpensAsALargeWindowThatCanGoFullScreen() throws {
        let window = try #require(PreferencesWindowController.shared.window)

        #expect(window.styleMask.contains(.resizable), "Preferences should be resizable")
        #expect(window.styleMask.contains(.fullSizeContentView), "The sidebar should run up under the traffic lights")
        #expect(window.collectionBehavior.contains(.fullScreenPrimary), "The green button should take Preferences full screen")
        #expect(window.frame.width >= 900, "Preferences should open as a full settings window, not a small sheet")
    }

    @Test func everySettingsSectionIsListedInTheSidebar() {
        #expect(PreferencesSection.allCases.map(\.title) == ["General", "Search", "Appearance"])
    }
}

@MainActor
struct PreferencesSearchTests {
    @Test func typingASettingNameShowsOnlyTheSectionThatHoldsIt() {
        let navigation = PreferencesNavigation()

        navigation.query = "theme"

        #expect(navigation.visibleSections == [.appearance])
        #expect(navigation.section == .appearance, "The matching section should open by itself")
    }

    @Test func searchFindsSettingsByWhatTheyDoNotOnlyByTheirTitle() {
        let navigation = PreferencesNavigation()

        navigation.query = "dark"
        #expect(navigation.visibleSections == [.appearance])

        navigation.query = "login"
        #expect(navigation.visibleSections == [.general])

        navigation.query = "folders"
        #expect(navigation.visibleSections == [.search])
    }

    @Test func searchIgnoresCaseAndSurroundingSpaces() {
        let navigation = PreferencesNavigation()

        navigation.query = "  RESULTS "

        #expect(navigation.visibleSections == [.search])
    }

    @Test func clearingTheSearchListsEverySectionAgainAndKeepsTheOpenOne() {
        let navigation = PreferencesNavigation()
        navigation.query = "theme"

        navigation.query = ""

        #expect(navigation.visibleSections == PreferencesSection.allCases)
        #expect(navigation.section == .appearance)
    }

    @Test func aSearchWithNoMatchListsNothing() {
        let navigation = PreferencesNavigation()

        navigation.query = "bluetooth"

        #expect(navigation.visibleSections.isEmpty)
    }
}

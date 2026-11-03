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

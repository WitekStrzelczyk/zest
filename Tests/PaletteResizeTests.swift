import AppKit
import Testing
@testable import ZestApp

@MainActor
final class PaletteResizeTests {
    init() {
        CommandPaletteWindow.showsOnScreen = false
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        FileSearchService.isDisabled = true
    }

    @Test func deletingTheLastLetterReturnsToCompactHeightWithoutSnapping() async {
        let window = CommandPaletteWindow()
        window.show(previousApp: nil)
        window.layoutIfNeeded()
        let top = window.visiblePaletteFrame.maxY
        let compactHeight = window.visiblePaletteFrame.height
        let store = CommandPaletteStateStore.shared

        store.updateQuery("saf")
        store.updateResults(await SearchEngine.shared.searchAsync(query: "saf"))
        window.layoutIfNeeded()
        #expect(window.visiblePaletteFrame.height > compactHeight, "Results should grow the palette")
        #expect(window.visiblePaletteFrame.maxY == top, "Growing should keep the top edge in place")

        store.updateQuery("")
        window.layoutIfNeeded()
        #expect(window.visiblePaletteFrame.height == compactHeight, "Clearing the query should return to the height the palette opened with")
        #expect(window.visiblePaletteFrame.maxY == top, "Shrinking should keep the top edge in place")

        window.close()
    }

    @Test func typingNeverMovesOrResizesTheWindowItself() {
        SearchEngine.shared.refreshInstalledApps()
        let window = CommandPaletteWindow()
        window.show(previousApp: nil)
        let openedFrame = window.frame
        let controller = CommandPaletteController.shared

        for typed in ["s", "sa", "saf", "safz", ""] {
            controller.handleQuery(typed)
            window.layoutIfNeeded()
            #expect(window.frame == openedFrame, "Typing '\(typed)' should only resize the palette card, not the window")
        }

        window.close()
    }
}

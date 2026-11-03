import AppKit
import Testing
@testable import ZestApp

@MainActor
final class PaletteResizeTests {
    init() {
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        FileSearchService.isDisabled = true
    }

    @Test func deletingTheLastLetterReturnsToCompactHeightWithoutSnapping() async {
        let window = CommandPaletteWindow()
        window.show(previousApp: nil)
        window.layoutIfNeeded()
        let top = window.frame.maxY
        let compactHeight = window.frame.height
        let store = CommandPaletteStateStore.shared

        store.updateQuery("saf")
        store.updateResults(await SearchEngine.shared.searchAsync(query: "saf"))
        window.layoutIfNeeded()
        #expect(window.frame.height > compactHeight, "Results should grow the palette")
        #expect(window.frame.maxY == top, "Growing should keep the top edge in place")

        store.updateQuery("")
        let requestedHeight = window.frame.height
        window.layoutIfNeeded()
        #expect(window.frame.height == requestedHeight, "The layout should keep the compact height instead of snapping")
        #expect(window.frame.height == compactHeight, "Clearing the query should return to the height the palette opened with")
        #expect(window.frame.maxY == top, "Shrinking should keep the top edge in place")

        window.close()
    }
}

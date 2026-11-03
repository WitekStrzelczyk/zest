import AppKit
import AppKit
import Testing
@testable import ZestApp

@MainActor
final class OptionKeyActionBarTests {
    var window: CommandPaletteWindow!

    init() {
        window = CommandPaletteWindow(
            contentRect: .zero,
            styleMask: [],
            backing: .buffered,
            defer: false
        )
    }

    isolated deinit {
        window.close()
        window = nil
    }

    @Test func test_actionBar_notVisibleInitially() {
        window.show(previousApp: nil)

        #expect(!window.isActionBarVisible, "Action bar should not be visible initially")
    }

    @Test func test_actionBar_notVisibleWithoutResults() {
        window.show(previousApp: nil)
        window.updateResultsForTesting([])

        window.simulateModifierFlagsChange(modifiers: .option)

        #expect(!window.isActionBarVisible, "Action bar should not be visible without results")
    }

    @Test func test_optionKeyPressed_showsActionBar_whenResultsExist() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateModifierFlagsChange(modifiers: .option)

        #expect(window.isActionBarVisible, "Action bar should be visible when Option is pressed with results")
    }

    @Test func test_optionKeyReleased_hidesActionBar() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)
        #expect(window.isActionBarVisible, "Precondition: action bar should be visible")

        window.simulateModifierFlagsChange(modifiers: [])

        #expect(!window.isActionBarVisible, "Action bar should be hidden when Option is released")
    }

    @Test func test_otherModifiersDoNotShowActionBar() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateModifierFlagsChange(modifiers: .command)

        #expect(!window.isActionBarVisible, "Action bar should only show for Option key, not Command")
    }

    @Test func test_optionWithOtherModifiers_showsActionBar() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateModifierFlagsChange(modifiers: [.option, .command])

        #expect(window.isActionBarVisible, "Action bar should show when Option is pressed even with other modifiers")
    }

    @Test func test_actionBar_containsConvertOption() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)

        #expect(window.actionBarOptions.contains("convert"), "Action bar should contain 'convert' option")
    }

    @Test func test_actionBar_containsTranslateOption() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)

        #expect(window.actionBarOptions.contains("translate"), "Action bar should contain 'translate' option")
    }

    @Test func test_actionBar_hasExactlyTwoOptions() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)

        #expect(window.actionBarOptions.count == 2, "Action bar should have exactly 2 options")
    }

    @Test func test_actionBarHiddenOnEscape() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)
        #expect(window.isActionBarVisible, "Precondition: action bar should be visible")

        window.simulateKeyPress(keyCode: 53)

        #expect(!window.isVisible, "Window should close on Escape")
    }

    @Test func test_actionBarResetsWhenWindowReopens() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)
        #expect(window.isActionBarVisible, "Precondition: action bar should be visible")

        window.close()
        window.show(previousApp: nil)

        #expect(!window.isActionBarVisible, "Action bar should not be visible after window reopens")
    }

    @Test func test_actionBarHiddenWhenResultsCleared() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)
        #expect(window.isActionBarVisible, "Precondition: action bar should be visible")

        window.updateResultsForTesting([])

        #expect(!window.isActionBarVisible, "Action bar should be hidden when results are cleared")
    }

    private func createMockResults(count: Int) -> [SearchResult] {
        (0..<count).map { index in
            SearchResult(
                title: "Result \(index + 1)",
                subtitle: "Test result",
                icon: nil,
                action: {},
                revealAction: nil
            )
        }
    }
}

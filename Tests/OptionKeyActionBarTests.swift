import AppKit
import XCTest
@testable import ZestApp

/// Tests for Option Key Action Bar feature
///
/// Requirements tested:
/// - Detect Option key press/hold while search results are visible
/// - Show action bar with "convert" and "translate" options above search results
/// - Hide action bar when Option key is released
/// - Options are UI only (no functionality yet)
final class OptionKeyActionBarTests: XCTestCase {

    var window: CommandPaletteWindow!

    override func setUp() {
        super.setUp()
        window = CommandPaletteWindow(
            contentRect: .zero,
            styleMask: [],
            backing: .buffered,
            defer: false
        )
    }

    override func tearDown() {
        window.close()
        window = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func test_actionBar_notVisibleInitially() {
        // Given: Window is shown
        window.show(previousApp: nil)

        // Then: Action bar should not be visible
        XCTAssertFalse(window.isActionBarVisible, "Action bar should not be visible initially")
    }

    func test_actionBar_notVisibleWithoutResults() {
        // Given: Window is shown with no results
        window.show(previousApp: nil)
        window.updateResultsForTesting([])

        // When: Option key is pressed
        window.simulateModifierFlagsChange(modifiers: .option)

        // Then: Action bar should not be visible (no results)
        XCTAssertFalse(window.isActionBarVisible, "Action bar should not be visible without results")
    }

    // MARK: - Option Key Detection Tests

    func test_optionKeyPressed_showsActionBar_whenResultsExist() {
        // Given: Window has search results
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // When: Option key is pressed
        window.simulateModifierFlagsChange(modifiers: .option)

        // Then: Action bar should be visible
        XCTAssertTrue(window.isActionBarVisible, "Action bar should be visible when Option is pressed with results")
    }

    func test_optionKeyReleased_hidesActionBar() {
        // Given: Window has results and Option key is pressed (action bar visible)
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)
        XCTAssertTrue(window.isActionBarVisible, "Precondition: action bar should be visible")

        // When: Option key is released
        window.simulateModifierFlagsChange(modifiers: [])

        // Then: Action bar should be hidden
        XCTAssertFalse(window.isActionBarVisible, "Action bar should be hidden when Option is released")
    }

    func test_otherModifiersDoNotShowActionBar() {
        // Given: Window has results
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // When: Command key is pressed (not Option)
        window.simulateModifierFlagsChange(modifiers: .command)

        // Then: Action bar should not be visible
        XCTAssertFalse(window.isActionBarVisible, "Action bar should only show for Option key, not Command")
    }

    func test_optionWithOtherModifiers_showsActionBar() {
        // Given: Window has results
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // When: Option+Command is pressed (Option is part of the flags)
        window.simulateModifierFlagsChange(modifiers: [.option, .command])

        // Then: Action bar should be visible (Option key detection works even with other modifiers)
        XCTAssertTrue(window.isActionBarVisible, "Action bar should show when Option is pressed even with other modifiers")
    }

    // MARK: - Action Bar Options Tests

    func test_actionBar_containsConvertOption() {
        // Given: Window has results and action bar is visible
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)

        // Then: Action bar should contain "convert" option
        XCTAssertTrue(window.actionBarOptions.contains("convert"), "Action bar should contain 'convert' option")
    }

    func test_actionBar_containsTranslateOption() {
        // Given: Window has results and action bar is visible
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)

        // Then: Action bar should contain "translate" option
        XCTAssertTrue(window.actionBarOptions.contains("translate"), "Action bar should contain 'translate' option")
    }

    func test_actionBar_hasExactlyTwoOptions() {
        // Given: Window has results and action bar is visible
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)

        // Then: Action bar should have exactly 2 options
        XCTAssertEqual(window.actionBarOptions.count, 2, "Action bar should have exactly 2 options")
    }

    // MARK: - State Management Tests

    func test_actionBarHiddenOnEscape() {
        // Given: Window has results and action bar is visible
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)
        XCTAssertTrue(window.isActionBarVisible, "Precondition: action bar should be visible")

        // When: Escape is pressed
        window.simulateKeyPress(keyCode: 53) // Escape

        // Then: Window should close (action bar state is reset)
        XCTAssertFalse(window.isVisible, "Window should close on Escape")
    }

    func test_actionBarResetsWhenWindowReopens() {
        // Given: Window was shown with action bar visible
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)
        XCTAssertTrue(window.isActionBarVisible, "Precondition: action bar should be visible")

        // When: Window is closed and reopened
        window.close()
        window.show(previousApp: nil)

        // Then: Action bar should not be visible
        XCTAssertFalse(window.isActionBarVisible, "Action bar should not be visible after window reopens")
    }

    func test_actionBarHiddenWhenResultsCleared() {
        // Given: Window has results and action bar is visible
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.simulateModifierFlagsChange(modifiers: .option)
        XCTAssertTrue(window.isActionBarVisible, "Precondition: action bar should be visible")

        // When: Results are cleared
        window.updateResultsForTesting([])

        // Then: Action bar should be hidden
        XCTAssertFalse(window.isActionBarVisible, "Action bar should be hidden when results are cleared")
    }

    // MARK: - Helper Methods

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

import XCTest
import AppKit
@testable import ZestApp

/// Tests for Story KB-1: Full Keyboard Navigation
///
/// Requirements tested:
/// - Auto-select first result when results appear
/// - Enter on no selection executes first result
/// - Arrow key navigation with boundary handling
/// - Escape closes palette
/// - Cmd+Enter reveals in Finder
final class KeyboardNavigationTests: XCTestCase {

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

    // MARK: - Auto-Selection Tests

    func test_first_result_auto_selected_when_results_appear() {
        // Given: Window is shown
        window.show(previousApp: nil)

        // When: User types a query that produces results
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // Then: First result should be automatically selected
        XCTAssertEqual(window.selectedIndex, 0, "First result should be auto-selected when results appear")
    }

    func test_no_selection_when_no_results() {
        // Given: Window is shown
        window.show(previousApp: nil)

        // When: Search returns no results
        window.updateResultsForTesting([])

        // Then: No result should be selected (-1 = no selection)
        XCTAssertEqual(window.selectedIndex, -1, "No result should be selected when there are no results")
    }

    // MARK: - Enter Key Tests

    func test_enter_executes_selected_result() {
        // Given: Window has results with first selected
        window.show(previousApp: nil)
        var executed = false
        let mockResults = createMockResultsWithAction(count: 3) { _ in executed = true }
        window.updateResultsForTesting(mockResults)

        // When: Enter is pressed
        window.simulateKeyPress(keyCode: 36) // Enter

        // Then: First result should execute
        XCTAssertTrue(executed, "Enter should execute the selected result")
    }

    func test_enter_executes_first_result_when_no_explicit_selection() {
        // Given: Window has results but no explicit selection
        window.show(previousApp: nil)
        var executed = false
        let mockResults = createMockResultsWithAction(count: 3) { index in
            if index == 0 { executed = true }
        }
        window.updateResultsForTesting(mockResults)
        window.clearSelectionForTesting()

        // When: Enter is pressed with no selection but results exist
        window.simulateKeyPress(keyCode: 36) // Enter

        // Then: First result should execute (default behavior)
        XCTAssertTrue(executed, "Enter should execute first result when no selection exists but results are present")
    }

    func test_enter_does_nothing_when_no_results() {
        // Given: Window has no results
        window.show(previousApp: nil)
        window.updateResultsForTesting([])

        // When: Enter is pressed
        window.simulateKeyPress(keyCode: 36) // Enter

        // Then: Window should remain open (not crash, do nothing)
        XCTAssertTrue(window.isVisible, "Window should remain open when Enter pressed with no results")
    }

    // MARK: - Arrow Key Navigation Tests

    func test_down_arrow_moves_selection_down() {
        // Given: Window has results with focus on results table (first result selected)
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 5)
        window.updateResultsForTesting(mockResults)

        // First navigate to results (press Down once to move focus to results)
        window.simulateKeyPress(keyCode: 125) // Down - now focus is on results, row 0 selected

        // When: Down arrow is pressed again
        window.simulateKeyPress(keyCode: 125) // Down

        // Then: Selection moves to second result
        XCTAssertEqual(window.selectedIndex, 1, "Down arrow should move selection down")
    }

    func test_down_arrow_stays_on_last_result_no_wrap() {
        // Given: Window has results with last result selected and focus on results
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // Navigate to last result: Down to focus results, then Down to 2nd, Down to 3rd
        window.simulateKeyPress(keyCode: 125) // Down - focus on results, row 0
        window.simulateKeyPress(keyCode: 125) // Down - row 1
        window.simulateKeyPress(keyCode: 125) // Down - row 2 (last)

        // When: Down arrow is pressed
        window.simulateKeyPress(keyCode: 125) // Down

        // Then: Selection stays on last result (no wrap)
        XCTAssertEqual(window.selectedIndex, 2, "Down arrow should not wrap to first result")
    }

    func test_up_arrow_moves_selection_up() {
        // Given: Window has results with third result selected and focus on results
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 5)
        window.updateResultsForTesting(mockResults)

        // Navigate to third result: Down to focus, then to row 1, then to row 2
        window.simulateKeyPress(keyCode: 125) // Down - focus on results, row 0
        window.simulateKeyPress(keyCode: 125) // Down - row 1
        window.simulateKeyPress(keyCode: 125) // Down - row 2

        // When: Up arrow is pressed
        window.simulateKeyPress(keyCode: 126) // Up

        // Then: Selection moves up
        XCTAssertEqual(window.selectedIndex, 1, "Up arrow should move selection up")
    }

    func test_up_arrow_on_first_result_returns_to_search_no_wrap() {
        // Given: Window has results with first result selected and focus on results
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // Navigate to results (this selects row 0 and sets focus on results)
        window.simulateKeyPress(keyCode: 125) // Down

        // When: Up arrow is pressed while on first result
        window.simulateKeyPress(keyCode: 126) // Up

        // Then: Selection is cleared (focus returns to search, no wrap to last)
        XCTAssertEqual(window.selectedIndex, -1, "Up arrow on first result should return to search, not wrap to last")
    }

    func test_arrow_keys_do_nothing_when_no_results() {
        // Given: Window has no results
        window.show(previousApp: nil)
        window.updateResultsForTesting([])

        // When: Arrow keys are pressed
        window.simulateKeyPress(keyCode: 125) // Down
        XCTAssertEqual(window.selectedIndex, -1, "Down should do nothing with no results")

        window.simulateKeyPress(keyCode: 126) // Up
        XCTAssertEqual(window.selectedIndex, -1, "Up should do nothing with no results")
    }

    // MARK: - Escape Key Tests

    func test_escape_closes_palette() {
        // Given: Window is shown
        window.show(previousApp: nil)

        // When: Escape is pressed
        window.simulateKeyPress(keyCode: 53) // Escape

        // Then: Window should close
        XCTAssertFalse(window.isVisible, "Escape should close the palette")
    }

    // MARK: - Cmd+Enter Tests

    func test_cmd_enter_reveals_in_finder() {
        // Given: Window has file results with first selected
        window.show(previousApp: nil)
        var revealed = false
        let mockResults = createMockFileResultsWithReveal(count: 3) { index in
            if index == 0 { revealed = true }
        }
        window.updateResultsForTesting(mockResults)

        // When: Cmd+Enter is pressed
        window.simulateKeyPress(keyCode: 36, modifiers: .command) // Cmd+Enter

        // Then: Reveal action should execute
        XCTAssertTrue(revealed, "Cmd+Enter should reveal file in Finder")
    }

    func test_cmd_enter_does_nothing_when_no_selection_and_no_reveal_action() {
        // Given: Window has results without reveal actions and no selection
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3) // No reveal actions
        window.updateResultsForTesting(mockResults)
        window.clearSelectionForTesting()

        // When: Cmd+Enter is pressed
        // Note: Implementation falls back to first result, calls reveal() (does nothing), and closes
        window.simulateKeyPress(keyCode: 36, modifiers: .command) // Cmd+Enter

        // Then: Window closes after attempting reveal (no crash)
        // The reveal action is nil so nothing happens, but window still closes
        XCTAssertFalse(window.isVisible, "Window should close when Cmd+Enter pressed even without reveal action")
    }

    func test_cmd_enter_falls_back_to_first_result_when_no_selection() {
        // Given: Window has results but no selection
        window.show(previousApp: nil)
        var revealed = false
        let mockResults = createMockFileResultsWithReveal(count: 3) { index in
            if index == 0 { revealed = true }
        }
        window.updateResultsForTesting(mockResults)
        window.clearSelectionForTesting()

        // When: Cmd+Enter is pressed with no selection
        window.simulateKeyPress(keyCode: 36, modifiers: .command) // Cmd+Enter

        // Then: First result's reveal action should execute (fallback to first)
        XCTAssertTrue(revealed, "Cmd+Enter should reveal first file when no selection exists")
    }

    // MARK: - First Responder Navigation Tests

    func test_down_arrow_moves_first_responder_to_results() {
        // Given: Window is shown with results and search field focused
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // Verify search field is first responder
        XCTAssertTrue(window.isSearchFieldFirstResponder, "Search field should be first responder initially")

        // When: Down arrow is pressed from search field
        window.simulateKeyPress(keyCode: 125) // Down

        // Then: First responder should move to results table
        XCTAssertTrue(window.isResultsTableFirstResponder, "Down arrow should move first responder to results table")
        XCTAssertEqual(window.selectedIndex, 0, "First result should be selected")
    }

    func test_up_arrow_from_first_result_moves_first_responder_to_search() {
        // Given: Window has results with first result selected and results table as first responder
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // Simulate being on results (press down to move to results)
        window.simulateKeyPress(keyCode: 125) // Down
        XCTAssertTrue(window.isResultsTableFirstResponder, "Results table should be first responder")

        // When: Up arrow is pressed while on first result
        window.simulateKeyPress(keyCode: 126) // Up

        // Then: First responder should move back to search field
        XCTAssertTrue(window.isSearchFieldFirstResponder, "Up arrow from first result should move first responder to search field")
        XCTAssertEqual(window.selectedIndex, -1, "Selection should be cleared")
    }

    func test_up_arrow_from_second_result_moves_selection_not_first_responder() {
        // Given: Window has results with second result selected and results table as first responder
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // Navigate to second result (down twice)
        window.simulateKeyPress(keyCode: 125) // Down to results, select first
        window.simulateKeyPress(keyCode: 125) // Down to second result

        // When: Up arrow is pressed while on second result
        window.simulateKeyPress(keyCode: 126) // Up

        // Then: Selection moves up but first responder stays on results table
        XCTAssertTrue(window.isResultsTableFirstResponder, "First responder should stay on results table")
        XCTAssertEqual(window.selectedIndex, 0, "Selection should move to first result")
    }

    // MARK: - Search to Results Navigation Tests

    func test_down_arrow_from_search_selects_first_result() {
        // Given: Window is shown with results and search field focused
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // Clear selection to simulate fresh state where search field is focused
        window.clearSelectionForTesting()

        // When: Down arrow is pressed from search field
        window.simulateKeyPress(keyCode: 125) // Down

        // Then: First result should be selected
        XCTAssertEqual(window.selectedIndex, 0, "Down arrow from search field should select first result")
    }

    func test_up_arrow_from_first_result_returns_to_search() {
        // Given: Window has results with first result selected
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        // First result is auto-selected

        // When: Up arrow is pressed while on first result
        window.simulateKeyPress(keyCode: 126) // Up

        // Then: Selection should be cleared (focus returned to search)
        XCTAssertEqual(window.selectedIndex, -1, "Up arrow from first result should return focus to search field")
    }

    // MARK: - Character Key Handling Tests

    func test_typing_character_while_on_results_returns_to_search() {
        // Given: Window has results with focus on results table
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // Navigate to results and then to second result
        window.simulateKeyPress(keyCode: 125) // Down - focus on results, row 0
        window.simulateKeyPress(keyCode: 125) // Down - row 1 (second result)

        // When: A character key is pressed (simulating typing while results focused)
        window.simulateCharacterKeyPress(character: "a")

        // Then: Selection should be cleared (focus returned to search)
        XCTAssertEqual(window.selectedIndex, -1, "Typing while on results should return focus to search field")
    }

    // MARK: - ESC Key Deactivation Tests

    func test_escape_properlyly_deactivates_window() {
        // Given: Window is shown and visible
        window.show(previousApp: nil)

        // When: Escape is pressed
        window.simulateKeyPress(keyCode: 53) // Escape

        // Then: Window should close and not be key
        XCTAssertFalse(window.isVisible, "Window should close on ESC")
        XCTAssertFalse(window.isKeyWindow, "Window should not be key after ESC")
    }

    func test_escape_stops_keyboard_interception() {
        // Given: Window is shown and visible
        window.show(previousApp: nil)

        // When: Escape is pressed
        window.simulateKeyPress(keyCode: 53) // Escape

        // Then: Window should be ordered out (not visible and not accepting events)
        XCTAssertFalse(window.isVisible, "Window should not be visible after ESC")
        XCTAssertFalse(window.acceptsMouseMovedEvents, "Window should not accept mouse events after ESC")
    }

    // MARK: - Hover State Clearing Tests

    func test_arrow_up_clears_hover_state_from_all_visible_rows() {
        // Given: Window has results with some rows hovered
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 5)
        window.updateResultsForTesting(mockResults)

        // Navigate to second result to set up keyboard navigation state
        window.simulateKeyPress(keyCode: 125) // Down - focus on results, row 0
        window.simulateKeyPress(keyCode: 125) // Down - row 1

        // Manually set hover on multiple rows (simulating mouse movement before keyboard)
        // This tests that ALL hovered rows get cleared, not just the tracked one
        setHoverOnMultipleRows([0, 2, 3])

        // Verify rows have hover state
        XCTAssertTrue(hasAnyHoveredRows(), "Some rows should be hovered before keyboard navigation")

        // When: Up arrow is pressed (keyboard navigation)
        window.simulateKeyPress(keyCode: 126) // Up

        // Then: ALL hover states should be cleared
        XCTAssertFalse(hasAnyHoveredRows(), "All hover states should be cleared on keyboard navigation")
    }

    func test_arrow_down_clears_hover_state_from_all_visible_rows() {
        // Given: Window has results with some rows hovered
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 5)
        window.updateResultsForTesting(mockResults)

        // Navigate to results first
        window.simulateKeyPress(keyCode: 125) // Down - focus on results, row 0

        // Manually set hover on multiple rows
        setHoverOnMultipleRows([1, 2, 4])

        // Verify rows have hover state
        XCTAssertTrue(hasAnyHoveredRows(), "Some rows should be hovered before keyboard navigation")

        // When: Down arrow is pressed (keyboard navigation)
        window.simulateKeyPress(keyCode: 125) // Down

        // Then: ALL hover states should be cleared
        XCTAssertFalse(hasAnyHoveredRows(), "All hover states should be cleared on keyboard navigation")
    }

    func test_clearHover_clears_all_visible_row_hover_states() {
        // Given: Window has results with multiple rows hovered
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 5)
        window.updateResultsForTesting(mockResults)

        // Set hover on multiple rows directly
        setHoverOnMultipleRows([0, 2, 4])

        // Verify rows have hover state
        XCTAssertTrue(hasAnyHoveredRows(), "Some rows should be hovered")

        // When: clearHover is called directly
        window.clearHoverOnAllRowsForTesting()

        // Then: ALL hover states should be cleared
        XCTAssertFalse(hasAnyHoveredRows(), "All hover states should be cleared")
    }

    // MARK: - Quick Look Preview Tests (Story 22)

    func test_space_key_requests_quick_look_for_file_result() {
        // Given: Window has file results with first selected
        window.show(previousApp: nil)
        let mockResults = createMockFileResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // When: Space is pressed
        window.simulateKeyPress(keyCode: 49) // Space

        // Then: Quick Look should be requested
        XCTAssertTrue(window.isQuickLookRequested, "Space should request Quick Look for file result")
    }

    func test_space_key_does_not_trigger_quick_look_for_non_file_result() {
        // Given: Window has non-file results (app results)
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // When: Space is pressed
        window.simulateKeyPress(keyCode: 49) // Space

        // Then: Quick Look should NOT be requested
        XCTAssertFalse(window.isQuickLookRequested, "Space should not request Quick Look for non-file result")
    }

    func test_space_key_does_nothing_when_no_results() {
        // Given: Window has no results
        window.show(previousApp: nil)
        window.updateResultsForTesting([])

        // When: Space is pressed
        window.simulateKeyPress(keyCode: 49) // Space

        // Then: Nothing happens, window stays open
        XCTAssertTrue(window.isVisible, "Window should remain open when Space pressed with no results")
        XCTAssertFalse(window.isQuickLookRequested, "Quick Look should not be requested with no results")
    }

    func test_space_key_toggles_quick_look_off() {
        // Given: Window has file results with Quick Look open
        window.show(previousApp: nil)
        let mockResults = createMockFileResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // Open Quick Look first
        window.simulateKeyPress(keyCode: 49) // Space
        XCTAssertTrue(window.isQuickLookRequested, "Quick Look should be open")

        // Reset the flag to simulate Quick Look being open
        window.resetQuickLookRequestFlag()

        // When: Space is pressed again
        window.simulateKeyPress(keyCode: 49) // Space

        // Then: Quick Look should close
        XCTAssertTrue(window.isQuickLookClosing, "Space should close Quick Look when already open")
    }

    func test_selected_file_result_provides_file_url() {
        // Given: Window has file results
        window.show(previousApp: nil)
        let mockResults = createMockFileResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // When: Getting selected file URL
        let fileURL = window.selectedFileURL

        // Then: Should return valid URL
        XCTAssertNotNil(fileURL, "Selected file result should provide file URL")
        XCTAssertTrue(fileURL!.path.hasSuffix(".txt"), "File URL should point to .txt file")
    }

    func test_non_file_result_returns_nil_file_url() {
        // Given: Window has non-file results
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        // When: Getting selected file URL
        let fileURL = window.selectedFileURL

        // Then: Should return nil
        XCTAssertNil(fileURL, "Non-file result should return nil file URL")
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

    private func createMockResultsWithAction(count: Int, actionHandler: @escaping (Int) -> Void) -> [SearchResult] {
        (0..<count).map { index in
            SearchResult(
                title: "Result \(index + 1)",
                subtitle: "Test result",
                icon: nil,
                action: { actionHandler(index) },
                revealAction: nil
            )
        }
    }

    private func createMockFileResultsWithReveal(count: Int, revealHandler: @escaping (Int) -> Void) -> [SearchResult] {
        (0..<count).map { index in
            SearchResult(
                title: "File \(index + 1).txt",
                subtitle: "~/Documents",
                icon: nil,
                action: {},
                revealAction: { revealHandler(index) }
            )
        }
    }

    private func createMockFileResults(count: Int) -> [SearchResult] {
        (0..<count).map { index in
            SearchResult(
                title: "File \(index + 1).txt",
                subtitle: "File",
                icon: nil,
                action: {},
                revealAction: nil,
                filePath: "/Users/test/Documents/File \(index + 1).txt"
            )
        }
    }

    // MARK: - Hover State Test Helpers

    private func setHoverOnMultipleRows(_ rows: [Int]) {
        window.setHoverOnRowsForTesting(rows)
    }

    private func hasAnyHoveredRows() -> Bool {
        window.hasAnyHoveredRowsForTesting()
    }
}

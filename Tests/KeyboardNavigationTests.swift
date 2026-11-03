import AppKit
import Testing
@testable import ZestApp

@MainActor
final class KeyboardNavigationTests {
    var window: CommandPaletteWindow!

    init() {
        NSApplication.shared.mainMenu = AppDelegate.makeMainMenu()
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

    @Test func test_first_result_auto_selected_when_results_appear() {
        window.show(previousApp: nil)

        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        #expect(window.selectedIndex == 0, "First result should be auto-selected when results appear")
    }

    @Test func test_no_selection_when_no_results() {
        window.show(previousApp: nil)

        window.updateResultsForTesting([])

        #expect(window.selectedIndex == -1, "No result should be selected when there are no results")
    }

    @Test func test_enter_executes_selected_result() {
        window.show(previousApp: nil)
        var executed = false
        let mockResults = createMockResultsWithAction(count: 3) { _ in executed = true }
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 36)

        #expect(executed, "Enter should execute the selected result")
    }

    @Test func test_enter_executes_first_result_when_no_explicit_selection() {
        window.show(previousApp: nil)
        var executed = false
        let mockResults = createMockResultsWithAction(count: 3) { index in
            if index == 0 { executed = true }
        }
        window.updateResultsForTesting(mockResults)
        window.clearSelectionForTesting()

        window.simulateKeyPress(keyCode: 36)

        #expect(executed, "Enter should execute first result when no selection exists but results are present")
    }

    @Test func test_enter_does_nothing_when_no_results() {
        window.show(previousApp: nil)
        window.updateResultsForTesting([])

        window.simulateKeyPress(keyCode: 36)

        #expect(window.isVisible, "Window should remain open when Enter pressed with no results")
    }

    @Test func test_down_arrow_moves_selection_down() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 5)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)

        window.simulateKeyPress(keyCode: 125)

        #expect(window.selectedIndex == 1, "Down arrow should move selection down")
    }

    @Test func test_down_arrow_stays_on_last_result_no_wrap() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)
        window.simulateKeyPress(keyCode: 125)
        window.simulateKeyPress(keyCode: 125)

        window.simulateKeyPress(keyCode: 125)

        #expect(window.selectedIndex == 2, "Down arrow should not wrap to first result")
    }

    @Test func test_up_arrow_moves_selection_up() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 5)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)
        window.simulateKeyPress(keyCode: 125)
        window.simulateKeyPress(keyCode: 125)

        window.simulateKeyPress(keyCode: 126)

        #expect(window.selectedIndex == 1, "Up arrow should move selection up")
    }

    @Test func test_up_arrow_on_first_result_returns_to_search_no_wrap() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)

        window.simulateKeyPress(keyCode: 126)

        #expect(window.selectedIndex == -1, "Up arrow on first result should return to search, not wrap to last")
    }

    @Test func test_arrow_keys_do_nothing_when_no_results() {
        window.show(previousApp: nil)
        window.updateResultsForTesting([])

        window.simulateKeyPress(keyCode: 125)
        #expect(window.selectedIndex == -1, "Down should do nothing with no results")

        window.simulateKeyPress(keyCode: 126)
        #expect(window.selectedIndex == -1, "Up should do nothing with no results")
    }

    @Test func test_escape_closes_palette() {
        window.show(previousApp: nil)

        window.simulateKeyPress(keyCode: 53)

        #expect(!window.isVisible, "Escape should close the palette")
    }

    @Test func test_cmd_enter_reveals_in_finder() {
        window.show(previousApp: nil)
        var revealed = false
        let mockResults = createMockFileResultsWithReveal(count: 3) { index in
            if index == 0 { revealed = true }
        }
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 36, modifiers: .command)

        #expect(revealed, "Cmd+Enter should reveal file in Finder")
    }

    @Test func test_cmd_enter_does_nothing_when_no_selection_and_no_reveal_action() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)
        window.clearSelectionForTesting()

        window.simulateKeyPress(keyCode: 36, modifiers: .command)

        #expect(window.isVisible, "Cmd+Enter should do nothing when the result has no reveal action")
    }

    @Test func test_cmd_enter_falls_back_to_first_result_when_no_selection() {
        window.show(previousApp: nil)
        var revealed = false
        let mockResults = createMockFileResultsWithReveal(count: 3) { index in
            if index == 0 { revealed = true }
        }
        window.updateResultsForTesting(mockResults)
        window.clearSelectionForTesting()

        window.simulateKeyPress(keyCode: 36, modifiers: .command)

        #expect(revealed, "Cmd+Enter should reveal first file when no selection exists")
    }

    @Test func test_cmd_number_executes_indexed_result_action() {
        window.show(previousApp: nil)
        var executedIndex: Int?
        let mockResults = createMockResultsWithAction(count: 4) { index in
            executedIndex = index
        }
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 19, modifiers: .command)

        #expect(executedIndex == 1, "Cmd+2 should execute the second result")
    }

    @Test func test_down_arrow_moves_first_responder_to_results() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        #expect(window.isSearchFieldFirstResponder, "Search field should be first responder initially")

        window.simulateKeyPress(keyCode: 125)

        #expect(window.isResultsTableFirstResponder, "Down arrow should move first responder to results table")
        #expect(window.selectedIndex == 0, "First result should be selected")
    }

    @Test func test_up_arrow_from_first_result_moves_first_responder_to_search() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)
        #expect(window.isResultsTableFirstResponder, "Results table should be first responder")

        window.simulateKeyPress(keyCode: 126)

        #expect(window.isSearchFieldFirstResponder, "Up arrow from first result should move first responder to search field")
        #expect(window.selectedIndex == -1, "Selection should be cleared")
    }

    @Test func test_up_arrow_from_second_result_moves_selection_not_first_responder() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)
        window.simulateKeyPress(keyCode: 125)

        window.simulateKeyPress(keyCode: 126)

        #expect(window.isResultsTableFirstResponder, "First responder should stay on results table")
        #expect(window.selectedIndex == 0, "Selection should move to first result")
    }

    @Test func test_down_arrow_from_search_selects_first_result() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.clearSelectionForTesting()

        window.simulateKeyPress(keyCode: 125)

        #expect(window.selectedIndex == 0, "Down arrow from search field should select first result")
    }

    @Test func test_up_arrow_from_first_result_returns_to_search() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)
        window.simulateKeyPress(keyCode: 126)

        #expect(window.selectedIndex == -1, "Up arrow from first result should return focus to search field")
    }

    @Test func test_typing_character_while_on_results_returns_to_search() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)
        window.simulateKeyPress(keyCode: 125)

        window.simulateCharacterKeyPress(character: "a")

        #expect(window.isSearchFieldFirstResponder, "Typing while on results should return focus to search field")
    }

    @Test func test_escape_properlyly_deactivates_window() {
        window.show(previousApp: nil)

        window.simulateKeyPress(keyCode: 53)

        #expect(!window.isVisible, "Window should close on ESC")
        #expect(!window.isKeyWindow, "Window should not be key after ESC")
    }

    @Test func test_escape_stops_keyboard_interception() {
        window.show(previousApp: nil)

        window.simulateKeyPress(keyCode: 53)

        #expect(!window.isVisible, "Window should not be visible after ESC")
        #expect(!window.acceptsMouseMovedEvents, "Window should not accept mouse events after ESC")
    }

    @Test func test_arrow_up_clears_hover_state_from_all_visible_rows() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 5)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)
        window.simulateKeyPress(keyCode: 125)

        setHoverOnMultipleRows([0, 2, 3])

        #expect(hasAnyHoveredRows(), "Some rows should be hovered before keyboard navigation")

        window.simulateKeyPress(keyCode: 126)

        #expect(!hasAnyHoveredRows(), "All hover states should be cleared on keyboard navigation")
    }

    @Test func test_arrow_down_clears_hover_state_from_all_visible_rows() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 5)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)

        setHoverOnMultipleRows([1, 2, 4])

        #expect(hasAnyHoveredRows(), "Some rows should be hovered before keyboard navigation")

        window.simulateKeyPress(keyCode: 125)

        #expect(!hasAnyHoveredRows(), "All hover states should be cleared on keyboard navigation")
    }

    @Test func test_clearHover_clears_all_visible_row_hover_states() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 5)
        window.updateResultsForTesting(mockResults)

        setHoverOnMultipleRows([0, 2, 4])

        #expect(hasAnyHoveredRows(), "Some rows should be hovered")

        window.clearHoverOnAllRowsForTesting()

        #expect(!hasAnyHoveredRows(), "All hover states should be cleared")
    }

    @Test(.disabled("Opens the system Quick Look panel, which hangs outside a running app; check by hand")) func test_space_key_requests_quick_look_for_file_result() {
        window.show(previousApp: nil)
        let mockResults = createMockFileResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)
        window.simulateKeyPress(keyCode: 49)

        #expect(window.isQuickLookRequested, "Space should request Quick Look for file result")
    }

    @Test func test_space_key_does_not_trigger_quick_look_for_non_file_result() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 49)

        #expect(!window.isQuickLookRequested, "Space should not request Quick Look for non-file result")
    }

    @Test func test_space_key_does_nothing_when_no_results() {
        window.show(previousApp: nil)
        window.updateResultsForTesting([])

        window.simulateKeyPress(keyCode: 49)

        #expect(window.isVisible, "Window should remain open when Space pressed with no results")
        #expect(!window.isQuickLookRequested, "Quick Look should not be requested with no results")
    }

    @Test(.disabled("Opens the system Quick Look panel, which hangs outside a running app; check by hand")) func test_space_key_toggles_quick_look_off() {
        window.show(previousApp: nil)
        let mockResults = createMockFileResults(count: 3)
        window.updateResultsForTesting(mockResults)

        window.simulateKeyPress(keyCode: 125)
        window.simulateKeyPress(keyCode: 49)
        #expect(window.isQuickLookRequested, "Quick Look should be open")

        window.resetQuickLookRequestFlag()

        window.simulateKeyPress(keyCode: 49)

        #expect(window.isQuickLookClosing, "Space should close Quick Look when already open")
    }

    @Test func test_selected_file_result_provides_file_url() {
        window.show(previousApp: nil)
        let mockResults = createMockFileResults(count: 3)
        window.updateResultsForTesting(mockResults)

        let fileURL = window.selectedFileURL

        #expect(fileURL != nil, "Selected file result should provide file URL")
        #expect(fileURL!.path.hasSuffix(".txt"), "File URL should point to .txt file")
    }

    @Test func test_non_file_result_returns_nil_file_url() {
        window.show(previousApp: nil)
        let mockResults = createMockResults(count: 3)
        window.updateResultsForTesting(mockResults)

        let fileURL = window.selectedFileURL

        #expect(fileURL == nil, "Non-file result should return nil file URL")
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

    private func setHoverOnMultipleRows(_ rows: [Int]) {
        window.setHoverOnRowsForTesting(rows)
    }

    private func hasAnyHoveredRows() -> Bool {
        window.hasAnyHoveredRowsForTesting()
    }
}

extension KeyboardNavigationTests {
    @Test func test_cmd_a_selects_all_text_in_search_field() {
        window.show(previousApp: nil)
        window.setSearchFieldTextForTesting("test")

        #expect(window.searchFieldText == "test", "Search field should have 'test'")

        window.simulateKeyPress(keyCode: 0, modifiers: .command)

        #expect(window.isSearchFieldTextSelected, "Cmd+A should select all text in search field")
    }

    @Test func test_cmd_c_copies_selected_text_to_clipboard() {
        window.show(previousApp: nil)
        window.setSearchFieldTextForTesting("hello")

        window.simulateKeyPress(keyCode: 0, modifiers: .command)

        NSPasteboard.general.clearContents()

        window.simulateKeyPress(keyCode: 8, modifiers: .command)

        let clipboardContent = NSPasteboard.general.string(forType: .string)
        #expect(clipboardContent == "hello", "Cmd+C should copy text to clipboard")
    }

    @Test func test_cmd_v_pastes_text_from_clipboard() {
        window.show(previousApp: nil)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("pasted", forType: .string)

        window.simulateKeyPress(keyCode: 9, modifiers: .command)

        #expect(window.searchFieldText == "pasted", "Cmd+V should paste text into search field")
    }

    @Test func test_cmd_x_cuts_selected_text_to_clipboard() {
        window.show(previousApp: nil)
        window.setSearchFieldTextForTesting("cut")

        window.simulateKeyPress(keyCode: 0, modifiers: .command)

        NSPasteboard.general.clearContents()

        window.simulateKeyPress(keyCode: 7, modifiers: .command)

        let clipboardContent = NSPasteboard.general.string(forType: .string)
        #expect(clipboardContent == "cut", "Cmd+X should cut text to clipboard")
        #expect(window.searchFieldText == "", "Cmd+X should remove text from search field")
    }

    @Test func test_edit_shortcuts_work_when_search_field_is_first_responder() {
        window.show(previousApp: nil)
        window.setSearchFieldTextForTesting("abc")

        #expect(window.isSearchFieldFirstResponder, "Search field should be first responder")

        window.simulateKeyPress(keyCode: 0, modifiers: .command)

        #expect(window.isSearchFieldTextSelected, "Cmd+A should work when search field is first responder")
    }

    @Test func test_cmd_l_does_not_produce_system_error() {
        window.show(previousApp: nil)
        window.setSearchFieldTextForTesting("test")

        #expect(window.searchFieldText == "test", "Search field should have 'test'")

        window.simulateKeyPress(keyCode: 37, modifiers: .command)

        #expect(window.isVisible, "Window should remain visible after Cmd+L")
    }

    @Test func test_cmd_left_does_not_produce_system_error() {
        window.show(previousApp: nil)
        window.setSearchFieldTextForTesting("hello world")

        window.simulateKeyPress(keyCode: 123, modifiers: .command)

        #expect(window.isVisible, "Window should remain visible after Cmd+Left")
    }

    @Test func test_unhandled_cmd_keys_do_not_crash() {
        window.show(previousApp: nil)
        window.setSearchFieldTextForTesting("test")

        window.simulateKeyPress(keyCode: 40, modifiers: .command)

        #expect(window.isVisible, "Window should remain visible after Cmd+K")
    }
}

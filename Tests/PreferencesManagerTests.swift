import XCTest
@testable import ZestApp

final class PreferencesManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset to default values before each test
        PreferencesManager.shared.resetToDefaults()
    }

    // MARK: - Hotkey Tests

    func test_hotkey_defaults_to_cmd_space() {
        // Given - preferences manager with default values
        let prefs = PreferencesManager.shared

        // Then - hotkey should default to Cmd+Space
        XCTAssertEqual(prefs.globalHotkey.modifiers, [.command])
        XCTAssertEqual(prefs.globalHotkey.keyCode, 49) // Space key
    }

    func test_hotkey_can_be_updated() {
        // Given - preferences manager
        let prefs = PreferencesManager.shared

        // When - updating hotkey
        let newHotkey = HotkeyConfiguration(modifiers: [.command, .shift], keyCode: 36) // Enter key
        prefs.globalHotkey = newHotkey

        // Then - hotkey should be updated
        XCTAssertEqual(prefs.globalHotkey.modifiers, [.command, .shift])
        XCTAssertEqual(prefs.globalHotkey.keyCode, 36)
    }

    // MARK: - Search Results Limit Tests

    func test_search_results_limit_defaults_to_10() {
        // Given - preferences manager with default values
        let prefs = PreferencesManager.shared

        // Then - search results limit should default to 10
        XCTAssertEqual(prefs.searchResultsLimit, 10)
    }

    func test_search_results_limit_can_be_updated() {
        // Given - preferences manager
        let prefs = PreferencesManager.shared

        // When - updating search results limit
        prefs.searchResultsLimit = 20

        // Then - search results limit should be updated
        XCTAssertEqual(prefs.searchResultsLimit, 20)
    }

    // MARK: - Launch at Login Tests

    func test_launch_at_login_defaults_to_false() {
        // Given - preferences manager with default values
        let prefs = PreferencesManager.shared

        // Then - launch at login should default to false
        XCTAssertFalse(prefs.launchAtLogin)
    }

    func test_launch_at_login_can_be_updated() {
        // Given - preferences manager
        let prefs = PreferencesManager.shared

        // When - updating launch at login
        prefs.launchAtLogin = true

        // Then - launch at login should be updated
        XCTAssertTrue(prefs.launchAtLogin)
    }

    // MARK: - Indexed Directories Tests

    func test_indexed_directories_defaults_to_documents_downloads_desktop() {
        // Given - preferences manager with default values
        let prefs = PreferencesManager.shared

        // Then - should have default directories
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertTrue(prefs.indexedDirectories.contains("\(homeDir)/Documents"))
        XCTAssertTrue(prefs.indexedDirectories.contains("\(homeDir)/Downloads"))
        XCTAssertTrue(prefs.indexedDirectories.contains("\(homeDir)/Desktop"))
    }

    func test_indexed_directories_can_be_modified() {
        // Given - preferences manager
        let prefs = PreferencesManager.shared

        // When - modifying indexed directories
        let newDir = "/Users/testuser/MyFiles"
        var dirs = prefs.indexedDirectories
        dirs.append(newDir)
        prefs.indexedDirectories = dirs

        // Then - directories should be updated
        XCTAssertTrue(prefs.indexedDirectories.contains(newDir))
    }

    // MARK: - Theme Tests

    func test_theme_defaults_to_system() {
        // Given - preferences manager with default values
        let prefs = PreferencesManager.shared

        // Then - theme should default to system
        XCTAssertEqual(prefs.theme, .system)
    }

    func test_theme_can_be_updated() {
        // Given - preferences manager
        let prefs = PreferencesManager.shared

        // When - updating theme
        prefs.theme = .dark

        // Then - theme should be updated
        XCTAssertEqual(prefs.theme, .dark)
    }

    // MARK: - Reset Tests

    func test_reset_to_defaults_restores_all_values() {
        // Given - preferences manager with modified values
        let prefs = PreferencesManager.shared
        prefs.searchResultsLimit = 50
        prefs.launchAtLogin = true
        prefs.theme = .dark

        // When - resetting to defaults
        prefs.resetToDefaults()

        // Then - all values should be reset
        XCTAssertEqual(prefs.searchResultsLimit, 10)
        XCTAssertFalse(prefs.launchAtLogin)
        XCTAssertEqual(prefs.theme, .system)
    }
}

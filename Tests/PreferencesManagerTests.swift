import AppKit
import Testing
@testable import ZestApp

@MainActor
final class PreferencesManagerTests {
    init() {
        PreferencesManager.shared.resetToDefaults()
    }

    @Test func test_hotkey_defaults_to_cmd_space() {
        let prefs = PreferencesManager.shared

        #expect(prefs.globalHotkey.modifiers == [.command])
        #expect(prefs.globalHotkey.keyCode == 49)
    }

    @Test func test_hotkey_can_be_updated() {
        let prefs = PreferencesManager.shared

        let newHotkey = HotkeyConfiguration(modifiers: [.command, .shift], keyCode: 36)
        prefs.globalHotkey = newHotkey

        #expect(prefs.globalHotkey.modifiers == [.command, .shift])
        #expect(prefs.globalHotkey.keyCode == 36)
    }

    @Test func test_search_results_limit_defaults_to_80() {
        let prefs = PreferencesManager.shared

        #expect(prefs.searchResultsLimit == 80)
    }

    @Test func test_search_results_limit_can_be_updated() {
        let prefs = PreferencesManager.shared

        prefs.searchResultsLimit = 20

        #expect(prefs.searchResultsLimit == 20)
    }

    @Test func test_launch_at_login_defaults_to_false() {
        let prefs = PreferencesManager.shared

        #expect(!prefs.launchAtLogin)
    }

    @Test func test_launch_at_login_can_be_updated() {
        let prefs = PreferencesManager.shared

        prefs.launchAtLogin = true

        #expect(prefs.launchAtLogin)
    }

    @Test func test_indexed_directories_defaults_to_documents_downloads_desktop() {
        let prefs = PreferencesManager.shared

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(prefs.indexedDirectories.contains("\(homeDir)/Documents"))
        #expect(prefs.indexedDirectories.contains("\(homeDir)/Downloads"))
        #expect(prefs.indexedDirectories.contains("\(homeDir)/Desktop"))
    }

    @Test func test_indexed_directories_can_be_modified() {
        let prefs = PreferencesManager.shared

        let newDir = "/Users/testuser/MyFiles"
        var dirs = prefs.indexedDirectories
        dirs.append(newDir)
        prefs.indexedDirectories = dirs

        #expect(prefs.indexedDirectories.contains(newDir))
    }

    @Test func test_theme_defaults_to_system() {
        let prefs = PreferencesManager.shared

        #expect(prefs.theme == .system)
    }

    @Test func test_theme_can_be_updated() {
        let prefs = PreferencesManager.shared

        prefs.theme = .dark

        #expect(prefs.theme == .dark)
    }

    @Test func test_reset_to_defaults_restores_all_values() {
        let prefs = PreferencesManager.shared
        prefs.searchResultsLimit = 50
        prefs.launchAtLogin = true
        prefs.theme = .dark

        prefs.resetToDefaults()

        #expect(prefs.searchResultsLimit == 80)
        #expect(!prefs.launchAtLogin)
        #expect(prefs.theme == .system)
    }
}

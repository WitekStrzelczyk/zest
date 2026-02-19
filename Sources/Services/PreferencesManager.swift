import AppKit
import Foundation

/// Represents a keyboard shortcut configuration
struct HotkeyConfiguration: Equatable {
    var modifiers: NSEvent.ModifierFlags
    var keyCode: UInt16

    static let defaultHotkey = HotkeyConfiguration(
        modifiers: .command,
        keyCode: 49 // Space key
    )
}

/// Theme options for the application
enum AppTheme: String, Codable, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// Manages application preferences using UserDefaults
final class PreferencesManager: ObservableObject {
    static let shared: PreferencesManager = .init()

    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let globalHotkeyModifiers = "globalHotkeyModifiers"
        static let globalHotkeyKeyCode = "globalHotkeyKeyCode"
        static let searchResultsLimit = "searchResultsLimit"
        static let launchAtLogin = "launchAtLogin"
        static let indexedDirectories = "indexedDirectories"
        static let theme = "theme"
        static let savedAwakeMode = "savedAwakeMode"
    }

    // MARK: - Properties

    @Published var globalHotkey: HotkeyConfiguration {
        didSet {
            saveHotkey()
        }
    }

    @Published var searchResultsLimit: Int {
        didSet {
            defaults.set(searchResultsLimit, forKey: Keys.searchResultsLimit)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }

    @Published var indexedDirectories: [String] {
        didSet {
            defaults.set(indexedDirectories, forKey: Keys.indexedDirectories)
        }
    }

    @Published var theme: AppTheme = .system {
        didSet {
            if let rawValue = theme.rawValue as String? {
                defaults.set(rawValue, forKey: Keys.theme)
            }
        }
    }
    
    @Published var savedAwakeMode: AwakeMode = .disabled {
        didSet {
            defaults.set(savedAwakeMode.rawValue, forKey: Keys.savedAwakeMode)
        }
    }

    // MARK: - Initialization

    private init() {
        // Load global hotkey
        let modifiers = defaults.integer(forKey: Keys.globalHotkeyModifiers)
        let keyCode = defaults.integer(forKey: Keys.globalHotkeyKeyCode)

        if modifiers == 0, keyCode == 0 {
            // Use defaults if not set
            globalHotkey = HotkeyConfiguration.defaultHotkey
        } else {
            globalHotkey = HotkeyConfiguration(
                modifiers: NSEvent.ModifierFlags(rawValue: UInt(modifiers)),
                keyCode: UInt16(keyCode)
            )
        }

        // Load search results limit
        let storedLimit = defaults.integer(forKey: Keys.searchResultsLimit)
        searchResultsLimit = storedLimit > 0 ? storedLimit : 10

        // Load launch at login
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        // Load indexed directories
        if let dirs = defaults.stringArray(forKey: Keys.indexedDirectories), !dirs.isEmpty {
            indexedDirectories = dirs
        } else {
            // Default directories
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            indexedDirectories = [
                "\(homeDir)/Documents",
                "\(homeDir)/Downloads",
                "\(homeDir)/Desktop",
            ]
        }

        // Load theme
        if let themeRaw = defaults.string(forKey: Keys.theme),
           let themeValue = AppTheme(rawValue: themeRaw)
        {
            theme = themeValue
        }
        
        // Load saved awake mode
        if let modeRaw = defaults.string(forKey: Keys.savedAwakeMode),
           let modeValue = AwakeMode(rawValue: modeRaw)
        {
            savedAwakeMode = modeValue
        }
    }

    // MARK: - Private Methods

    private func saveHotkey() {
        defaults.set(Int(globalHotkey.modifiers.rawValue), forKey: Keys.globalHotkeyModifiers)
        defaults.set(Int(globalHotkey.keyCode), forKey: Keys.globalHotkeyKeyCode)
    }

    // MARK: - Public Methods

    func resetToDefaults() {
        globalHotkey = HotkeyConfiguration.defaultHotkey
        searchResultsLimit = 10
        launchAtLogin = false

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        indexedDirectories = [
            "\(homeDir)/Documents",
            "\(homeDir)/Downloads",
            "\(homeDir)/Desktop",
        ]

        theme = .system
    }
}

import AppKit
import Foundation

struct HotkeyConfiguration: Equatable {
    var modifiers: NSEvent.ModifierFlags
    var keyCode: UInt16

    static let defaultHotkey = HotkeyConfiguration(
        modifiers: .command,
        keyCode: 49
    )
}

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

final class PreferencesManager: ObservableObject {
    static let shared: PreferencesManager = .init()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let globalHotkeyModifiers = "globalHotkeyModifiers"
        static let globalHotkeyKeyCode = "globalHotkeyKeyCode"
        static let searchResultsLimit = "searchResultsLimit"
        static let launchAtLogin = "launchAtLogin"
        static let indexedDirectories = "indexedDirectories"
        static let theme = "theme"
        static let savedAwakeMode = "savedAwakeMode"
    }

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
            LaunchAtLoginService.shared.enabled = launchAtLogin
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

    private init() {
        let modifiers = defaults.integer(forKey: Keys.globalHotkeyModifiers)
        let keyCode = defaults.integer(forKey: Keys.globalHotkeyKeyCode)

        if modifiers == 0, keyCode == 0 {
            globalHotkey = HotkeyConfiguration.defaultHotkey
        } else {
            globalHotkey = HotkeyConfiguration(
                modifiers: NSEvent.ModifierFlags(rawValue: UInt(modifiers)),
                keyCode: UInt16(keyCode)
            )
        }

        let storedLimit = defaults.integer(forKey: Keys.searchResultsLimit)
        searchResultsLimit = storedLimit > 0 ? storedLimit : 80

        let storedLaunchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        let systemLaunchAtLogin = LaunchAtLoginService.shared.isEnabled

        if storedLaunchAtLogin != systemLaunchAtLogin {
            defaults.set(systemLaunchAtLogin, forKey: Keys.launchAtLogin)
        }
        launchAtLogin = systemLaunchAtLogin

        if let dirs = defaults.stringArray(forKey: Keys.indexedDirectories), !dirs.isEmpty {
            indexedDirectories = dirs
        } else {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            indexedDirectories = [
                "\(homeDir)/Documents",
                "\(homeDir)/Downloads",
                "\(homeDir)/Desktop",
            ]
        }

        if let themeRaw = defaults.string(forKey: Keys.theme),
           let themeValue = AppTheme(rawValue: themeRaw)
        {
            theme = themeValue
        }

        if let modeRaw = defaults.string(forKey: Keys.savedAwakeMode),
           let modeValue = AwakeMode(rawValue: modeRaw)
        {
            savedAwakeMode = modeValue
        }
    }

    private func saveHotkey() {
        defaults.set(Int(globalHotkey.modifiers.rawValue), forKey: Keys.globalHotkeyModifiers)
        defaults.set(Int(globalHotkey.keyCode), forKey: Keys.globalHotkeyKeyCode)
    }

    func resetToDefaults() {
        globalHotkey = HotkeyConfiguration.defaultHotkey
        searchResultsLimit = 80
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

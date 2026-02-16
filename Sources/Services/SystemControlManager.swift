import AppKit
import Foundation

/// Represents a system control action
enum SystemControlAction: String, CaseIterable {
    case toggleDarkMode = "Toggle Dark Mode"
    case mute = "Mute/Unmute"
    case emptyTrash = "Empty Trash"
    case lockScreen = "Lock Screen"
    case sleep = "Sleep"
    case restart = "Restart"
    case shutdown = "Shutdown"
    case logout = "Log Out"

    var icon: String {
        switch self {
        case .toggleDarkMode: return "moon.circle"
        case .mute: return "speaker.wave.2"
        case .emptyTrash: return "trash"
        case .lockScreen: return "lock"
        case .sleep: return "moon.zzz"
        case .restart: return "arrow.clockwise"
        case .shutdown: return "power"
        case .logout: return "rectangle.portrait.and.arrow.right"
        }
    }

    var keywords: [String] {
        switch self {
        case .toggleDarkMode: return ["dark", "mode", "theme", "appearance"]
        case .mute: return ["mute", "unmute", "sound", "audio", "volume"]
        case .emptyTrash: return ["trash", "delete", "clean", "empty"]
        case .lockScreen: return ["lock", "screen", "security"]
        case .sleep: return ["sleep", "suspend"]
        case .restart: return ["restart", "reboot", "reboot"]
        case .shutdown: return ["shutdown", "power", "off"]
        case .logout: return ["logout", "sign", "out", "exit"]
        }
    }
}

/// Manages system control actions
final class SystemControlManager {
    static let shared: SystemControlManager = {
        let instance = SystemControlManager()
        return instance
    }()

    private init() {}

    // MARK: - Public Methods

    /// Get all available system controls
    func getAllControls() -> [(action: SystemControlAction, name: String)] {
        SystemControlAction.allCases.map { ($0, $0.rawValue) }
    }

    /// Search system controls by query
    func searchControls(query: String) -> [(action: SystemControlAction, name: String)] {
        guard !query.isEmpty else { return getAllControls() }

        let lowercasedQuery = query.lowercased()
        return SystemControlAction.allCases.filter { action in
            action.rawValue.lowercased().contains(lowercasedQuery) ||
            action.keywords.contains { $0.lowercased().contains(lowercasedQuery) }
        }.map { ($0, $0.rawValue) }
    }

    /// Execute a system control action
    func execute(action: SystemControlAction) -> Bool {
        switch action {
        case .toggleDarkMode:
            return toggleDarkMode()
        case .mute:
            return toggleMute()
        case .emptyTrash:
            return emptyTrash()
        case .lockScreen:
            return lockScreen()
        case .sleep:
            return sleep()
        case .restart:
            return restart()
        case .shutdown:
            return shutdown()
        case .logout:
            return logout()
        }
    }

    // MARK: - Private Methods

    private func toggleDarkMode() -> Bool {
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to not dark mode
            end tell
        end tell
        """
        return runAppleScript(script)
    }

    private func toggleMute() -> Bool {
        let script = """
        set volume output muted not (output muted of (get volume settings))
        """
        return runAppleScript(script)
    }

    private func emptyTrash() -> Bool {
        // Show confirmation dialog first (handled by system)
        let script = """
        tell application "Finder"
            empty trash
        end tell
        """
        return runAppleScript(script)
    }

    private func lockScreen() -> Bool {
        let script = """
        tell application "System Events"
            keystroke "q" using {command down, control down}
        end tell
        """
        return runAppleScript(script)
    }

    private func sleep() -> Bool {
        let script = """
        tell application "System Events"
            sleep
        end tell
        """
        return runAppleScript(script)
    }

    private func restart() -> Bool {
        let script = """
        tell application "System Events"
            restart
        end tell
        """
        return runAppleScript(script)
    }

    private func shutdown() -> Bool {
        let script = """
        tell application "System Events"
            shut down
        end tell
        """
        return runAppleScript(script)
    }

    private func logout() -> Bool {
        let script = """
        tell application "System Events"
            log out
        end tell
        """
        return runAppleScript(script)
    }

    @discardableResult
    private func runAppleScript(_ script: String) -> Bool {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
                return false
            }
            return true
        }
        return false
    }
}

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
        case .toggleDarkMode: "moon.circle"
        case .mute: "speaker.wave.2"
        case .emptyTrash: "trash"
        case .lockScreen: "lock"
        case .sleep: "moon.zzz"
        case .restart: "arrow.clockwise"
        case .shutdown: "power"
        case .logout: "rectangle.portrait.and.arrow.right"
        }
    }

    var keywords: [String] {
        switch self {
        case .toggleDarkMode: ["dark", "mode", "theme", "appearance"]
        case .mute: ["mute", "unmute", "sound", "audio", "volume"]
        case .emptyTrash: ["trash", "delete", "clean", "empty"]
        case .lockScreen: ["lock", "screen", "security"]
        case .sleep: ["sleep", "suspend"]
        case .restart: ["restart", "reboot", "reboot"]
        case .shutdown: ["shutdown", "power", "off"]
        case .logout: ["logout", "sign", "out", "exit"]
        }
    }
}

/// Manages system control actions
final class SystemControlManager {
    static let shared: SystemControlManager = .init()

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
            toggleDarkMode()
        case .mute:
            toggleMute()
        case .emptyTrash:
            emptyTrash()
        case .lockScreen:
            lockScreen()
        case .sleep:
            sleep()
        case .restart:
            restart()
        case .shutdown:
            shutdown()
        case .logout:
            logout()
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
            if let error {
                print("AppleScript error: \(error)")
                return false
            }
            return true
        }
        return false
    }
}

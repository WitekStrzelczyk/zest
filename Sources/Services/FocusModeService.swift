import AppKit
import Foundation

/// Represents a Focus mode
struct FocusMode: Identifiable, Hashable {
    let id: String
    let name: String
    let isActive: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FocusMode, rhs: FocusMode) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages Focus Mode control on macOS
final class FocusModeService {
    static let shared: FocusModeService = .init()

    private init() {}

    // MARK: - Public Methods

    /// Get all available focus modes
    func getAllFocusModes() -> [FocusMode] {
        // Get list of focus modes from system
        fetchFocusModesFromSystem()
    }

    /// Search focus modes by query
    func searchFocusModes(query: String) -> [FocusMode] {
        let allModes = getAllFocusModes()

        guard !query.isEmpty else { return allModes }

        let lowercasedQuery = query.lowercased()
        return allModes.filter { mode in
            mode.name.lowercased().contains(lowercasedQuery)
        }
    }

    /// Toggle a specific focus mode by name
    func toggleFocusMode(name: String) -> Bool {
        let lowercasedName = name.lowercased()

        // Check if "do not disturb" or "dnd" is in the name
        if lowercasedName.contains("do not distur") || lowercasedName.contains("dnd") {
            return toggleDoNotDisturb()
        }

        // Try to toggle by name using shortcuts
        return toggleFocusModeByName(name)
    }

    /// Turn off all focus modes
    func turnOffAllFocusModes() -> Bool {
        // Use AppleScript to turn off focus mode
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                -- Click on Focus in menu bar
            end tell
        end tell
        """

        // Alternative: Use shortcuts command if available
        return runShortcutsCommand(focusMode: "Off")
    }

    /// Get current focus status
    func getCurrentFocusStatus() -> String {
        // Check if Do Not Disturb is active
        if isDoNotDisturbActive() {
            return "Do Not Disturb is active"
        }
        return "No Focus mode active"
    }

    // MARK: - Private Methods

    private func fetchFocusModesFromSystem() -> [FocusMode] {
        var modes: [FocusMode] = []

        // Standard macOS Focus modes
        modes.append(FocusMode(id: "dnd", name: "Do Not Disturb", isActive: isDoNotDisturbActive()))

        // Try to get custom focus modes from system preferences
        // Note: This is a simplified implementation - full implementation would use
        // the FocusMode API available in macOS 12+
        let focusModeNames = ["Work", "Personal", "Sleep", "Gaming"]
        for name in focusModeNames {
            modes.append(FocusMode(id: name.lowercased(), name: name, isActive: false))
        }

        return modes
    }

    private func isDoNotDisturbActive() -> Bool {
        // Check if DND is active via defaults or shell command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "com.apple.controlcenter", "NSStatusItem Visible DoNotDisturb"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("1")
            }
        } catch {
            print("Error checking DND status: \(error)")
        }

        return false
    }

    private func toggleDoNotDisturb() -> Bool {
        // Use AppleScript to toggle DND
        let script = """
        tell application "System Events"
            tell application process "ControlCenter"
                -- Click on Focus control in menu bar
                -- This is a simplified implementation
            end tell
        end tell
        tell application "System Events"
            -- Use keyboard shortcut to toggle DND (Option + D)
            key code 0 using {option down}
        end tell
        """

        return runAppleScript(script)
    }

    private func toggleFocusModeByName(_ name: String) -> Bool {
        // Try to use shortcuts app to toggle focus mode
        runShortcutsCommand(focusMode: name)
    }

    private func runShortcutsCommand(focusMode: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", "Turn On \(focusMode) Focus"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("Error running shortcuts command: \(error)")
            // Fallback: try AppleScript
            let script = """
            do shell script "shortcuts run 'Turn On \(focusMode) Focus'"
            """
            return runAppleScript(script)
        }
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

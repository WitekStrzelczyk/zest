import AppKit
import Carbon
import Foundation

/// Represents a global command that can be triggered via hotkey
struct GlobalCommand {
    let name: String
    let keyCode: UInt32
    let modifiers: UInt32
    let description: String
    let action: () -> Void
}

/// Service that defines and manages global commands
/// Provides actions like opening apps and window management
final class GlobalCommandsService {
    // MARK: - Singleton

    static let shared: GlobalCommandsService = .init()

    // MARK: - Properties

    private let windowManager = WindowManager.shared

    /// List of available global commands
    var availableCommands: [GlobalCommand] {
        [
            GlobalCommand(
                name: "Open Spotify",
                keyCode: UInt32(kVK_ANSI_M),
                modifiers: UInt32(optionKey | cmdKey),
                description: "Opens the Spotify application"
            ) { [weak self] in
                _ = self?.openSpotify()
            },
            GlobalCommand(
                name: "Maximize Window",
                keyCode: UInt32(kVK_UpArrow),
                modifiers: UInt32(optionKey | cmdKey),
                description: "Maximizes the current window"
            ) { [weak self] in
                _ = self?.maximizeWindow()
            },
        ]
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Opens the Spotify application
    /// - Returns: True if Spotify was launched successfully
    @discardableResult
    func openSpotify() -> Bool {
        // Try to open Spotify via URL scheme first (more reliable)
        if let url = URL(string: "spotify://") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true

            NSWorkspace.shared.open(url, configuration: config) { _, error in
                if error != nil {
                    // Fallback: Try opening the app bundle directly
                    self.openSpotifyBundle()
                }
            }
            return true
        }
        return false
    }

    /// Maximizes the frontmost window
    /// - Returns: True if window was maximized successfully
    @discardableResult
    func maximizeWindow() -> Bool {
        windowManager.maximizeFocusedWindow()
    }

    // MARK: - Private

    private func openSpotifyBundle() {
        // Try common Spotify installation locations
        let possiblePaths = [
            "/Applications/Spotify.app",
            NSHomeDirectory() + "/Applications/Spotify.app",
        ]

        for path in possiblePaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
                return
            }
        }
    }
}

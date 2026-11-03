import AppKit
import Carbon
import Foundation

struct GlobalCommand {
    let name: String
    let keyCode: UInt32
    let modifiers: UInt32
    let description: String
    let shortcutDisplay: String
    let action: () -> Void
}

final class GlobalCommandsService {
    static let shared: GlobalCommandsService = .init()

    private let windowManager = WindowManager.shared

    var availableCommands: [GlobalCommand] {
        [
            GlobalCommand(
                name: "Open Spotify",
                keyCode: UInt32(kVK_ANSI_M),
                modifiers: UInt32(optionKey | cmdKey),
                description: "Opens the Spotify application",
                shortcutDisplay: "⌥⌘M"
            ) { [weak self] in
                _ = self?.openSpotify()
            },
            GlobalCommand(
                name: "Maximize Window",
                keyCode: UInt32(kVK_UpArrow),
                modifiers: UInt32(optionKey | cmdKey),
                description: "Maximizes the current window",
                shortcutDisplay: "⌥⌘↑"
            ) { [weak self] in
                _ = self?.maximizeWindow()
            },
        ]
    }

    private init() {}

    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()

        return availableCommands.compactMap { command -> SearchResult? in
            let score = SearchScoreCalculator.shared.calculateScore(
                query: lowercasedQuery,
                title: command.name,
                category: .globalAction
            )

            guard score > 0 || lowercasedQuery.isEmpty else { return nil }

            return SearchResult(
                title: command.name,
                subtitle: command.shortcutDisplay,
                icon: NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Global Shortcut"),
                category: .globalAction,
                action: command.action,
                score: score
            )
        }
    }

    @discardableResult
    func openSpotify() -> Bool {
        if let url = URL(string: "spotify://") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true

            NSWorkspace.shared.open(url, configuration: config) { _, error in
                if error != nil {
                    self.openSpotifyBundle()
                }
            }
            return true
        }
        return false
    }

    @discardableResult
    func maximizeWindow() -> Bool {
        windowManager.maximizeFocusedWindow()
    }

    private func openSpotifyBundle() {
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

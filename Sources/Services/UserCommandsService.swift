import AppKit
import Foundation

/// Represents a user-defined command that opens a URL
struct UserCommand {
    let id: String
    let name: String
    let url: URL
    let description: String
}

/// Manages user-defined commands (shortcuts that open URLs)
final class UserCommandsService {
    static let shared = UserCommandsService()

    private let commands: [UserCommand]

    private init() {
        // Hardcoded commands for now
        commands = [
            UserCommand(
                id: "gcr",
                name: "gcr",
                url: URL(string: "https://console.cloud.google.com/artifacts/docker/ninety-devops/asia/apps?hl=en&inv=1&invt=Ab0RbA&project=ninety-devops")!,
                description: "Google Cloud Registry"
            ),
        ]
    }

    /// Get all available commands
    func getAllCommands() -> [UserCommand] {
        commands
    }

    /// Search commands by query (supports partial and case-insensitive matching)
    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()

        // If empty query, return all commands
        if lowercasedQuery.isEmpty {
            return commands.map { command in
                createSearchResult(for: command)
            }
        }

        // Filter commands where name contains the query
        let matchingCommands = commands.filter { command in
            command.name.lowercased().contains(lowercasedQuery) ||
                command.description.lowercased().contains(lowercasedQuery)
        }

        return matchingCommands.map { command in
            createSearchResult(for: command)
        }
    }

    private func createSearchResult(for command: UserCommand) -> SearchResult {
        SearchResult(
            title: command.name,
            subtitle: command.description,
            icon: NSImage(systemSymbolName: "terminal", accessibilityDescription: "Command"),
            action: {
                NSWorkspace.shared.open(command.url)
            }
        )
    }
}

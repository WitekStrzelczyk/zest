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
                createSearchResult(for: command, score: 0)
            }
        }

        // Score and filter commands where name or description matches the query
        let matchingCommands = commands.compactMap { command -> (command: UserCommand, score: Int)? in
            let score = SearchResultScoring.shared.scoreResult(
                query: lowercasedQuery,
                title: command.name,
                subtitle: command.description
            )
            return score > 0 ? (command, score) : nil
        }
        .sorted { $0.score > $1.score }

        return matchingCommands.map { item in
            createSearchResult(for: item.command, score: item.score)
        }
    }

    private func createSearchResult(for command: UserCommand, score: Int) -> SearchResult {
        SearchResult(
            title: command.name,
            subtitle: command.description,
            icon: NSImage(systemSymbolName: "terminal", accessibilityDescription: "Command"),
            action: {
                NSWorkspace.shared.open(command.url)
            },
            score: score
        )
    }
}

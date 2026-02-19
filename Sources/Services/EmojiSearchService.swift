import AppKit
import Foundation

/// Service for searching and inserting emojis
final class EmojiSearchService {
    static let shared: EmojiSearchService = .init()

    /// Maximum number of results to return
    private let maxResults = 10

    private init() {}

    /// Search for emojis matching the query
    func search(query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        let lowercasedQuery = query.lowercased()

        // Score and sort emojis by match quality using unified scoring
        let matchedEmojis = EmojiData.emojis.compactMap { (emoji: String, keywords: [String]) -> (String, Int)? in
            var bestScore = 0

            // Check each keyword for matches
            for keyword in keywords {
                let score = SearchResultScoring.shared.scoreResult(query: lowercasedQuery, title: keyword)
                bestScore = max(bestScore, score)
            }

            // Also check if the query is a single character that might be the emoji itself
            if emoji.contains(lowercasedQuery) {
                bestScore = max(bestScore, 50)
            }

            return bestScore > 0 ? (emoji, bestScore) : nil
        }
        .sorted { $0.1 > $1.1 }
        .prefix(maxResults)

        // Convert to SearchResults
        return matchedEmojis.map { emoji, score in
            let emojiString = emoji

            return SearchResult(
                title: emojiString,
                subtitle: "Emoji",
                icon: createEmojiIcon(emojiString),
                category: .emoji,
                action: { [weak self] in
                    self?.pasteEmoji(emojiString)
                },
                score: score
            )
        }
    }

    /// Paste emoji into the active application
    private func pasteEmoji(_ emoji: String) {
        // Copy to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(emoji, forType: .string)

        // Try to paste into the frontmost application
        // First, bring back the previously active app
        if let previousApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier != Bundle.main.bundleIdentifier && $0.isActive == false }) {
            previousApp.activate()

            // Small delay to let the app come to front
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Simulate Cmd+V paste
                self.simulatePaste()
            }
        }
    }

    /// Simulate paste command
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down Cmd+V
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }

        // Key up Cmd+V
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Create an icon image containing the emoji
    private func createEmojiIcon(_ emoji: String) -> NSImage {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw the emoji in the center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
        ]

        let attributedString = NSAttributedString(string: emoji, attributes: attributes)
        let stringSize = attributedString.size()

        let iconX = (size.width - stringSize.width) / 2
        let iconY = (size.height - stringSize.height) / 2

        attributedString.draw(at: NSPoint(x: iconX, y: iconY))

        image.unlockFocus()

        return image
    }
}

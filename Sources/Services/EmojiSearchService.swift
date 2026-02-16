import AppKit
import Foundation

/// Service for searching and inserting emojis
final class EmojiSearchService {
    static let shared: EmojiSearchService = {
        let instance = EmojiSearchService()
        return instance
    }()

    /// Maximum number of results to return
    private let maxResults = 10

    private init() {}

    /// Search for emojis matching the query
    func search(query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        let lowercasedQuery = query.lowercased()
        let queryWords = lowercasedQuery.components(separatedBy: " ").filter { !$0.isEmpty }

        // Score and sort emojis by match quality
        let matchedEmojis = EmojiData.emojis.compactMap { (emoji: String, keywords: [String]) -> (String, Int)? in
            var score = 0

            // Check if query matches any keyword
            for keyword in keywords {
                if keyword == lowercasedQuery {
                    // Exact match - highest score
                    score = 1000
                    break
                } else if keyword.hasPrefix(lowercasedQuery) {
                    // Prefix match
                    score = max(score, 500 - keyword.count)
                } else if keyword.contains(lowercasedQuery) {
                    // Contains match
                    score = max(score, 100)
                }
            }

            // Handle multi-word queries like "flag us" - check if all query words are in keywords
            if queryWords.count > 1 {
                let matchingWords = queryWords.filter { queryWord in
                    keywords.contains { $0 == queryWord || $0.contains(queryWord) }
                }
                if matchingWords.count == queryWords.count {
                    // All words match - give high score
                    score = max(score, 300)
                } else if !matchingWords.isEmpty {
                    // Some words match - give partial score
                    score = max(score, matchingWords.count * 50)
                }
            }

            // Also check if the query is a single character that might be the emoji itself
            if emoji.contains(lowercasedQuery) {
                score = max(score, 50)
            }

            return score > 0 ? (emoji, score) : nil
        }
        .sorted { $0.1 > $1.1 }
        .prefix(maxResults)

        // Convert to SearchResults
        return matchedEmojis.map { emoji, _ in
            let emojiString = emoji

            return SearchResult(
                title: emojiString,
                subtitle: "Emoji",
                icon: createEmojiIcon(emojiString),
                action: { [weak self] in
                    self?.pasteEmoji(emojiString)
                }
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

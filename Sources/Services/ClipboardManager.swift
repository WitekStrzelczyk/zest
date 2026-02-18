import AppKit
import Foundation

final class ClipboardManager {
    static let shared: ClipboardManager = .init()

    private var history: [ClipboardItem] = []
    private var lastChangeCount: Int = 0
    private var monitorTimer: Timer?
    private let maxHistoryItems = 100

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        loadHistory()
        startMonitoring()
    }

    // MARK: - Public API

    func search(query: String) -> [SearchResult] {
        if query.isEmpty {
            return []
        }

        let lowercasedQuery = query.lowercased()

        return history
            .filter { item in
                if let text = item.text {
                    return text.lowercased().contains(lowercasedQuery)
                }
                return false
            }
            .prefix(10)
            .map { item -> SearchResult in
                let preview = item.text.map { String($0.prefix(50)) } ?? "Image"
                return SearchResult(
                    title: preview,
                    subtitle: item.isImage ? "Image" : "Text",
                    icon: item.icon,
                    category: .clipboard,
                    action: { [weak self] in
                        self?.copyToClipboard(item)
                    }
                )
            }
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if let text = item.text {
            pasteboard.setString(text, forType: .string)
        } else if let imageData = item.imageData {
            if let image = NSImage(data: imageData) {
                pasteboard.writeObjects([image])
            }
        }
    }

    // MARK: - Private

    private func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // Check for password manager content (1Password, Bitwarden, etc.)
        if isSensitiveContent(pasteboard) {
            return
        }

        // Read new content
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            addItem(ClipboardItem(text: string, isImage: false))
        } else if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
                  let tiffData = image.tiffRepresentation
        {
            addItem(ClipboardItem(imageData: tiffData, isImage: true))
        }
    }

    private func isSensitiveContent(_ pasteboard: NSPasteboard) -> Bool {
        // Check for 1Password
        if pasteboard.string(forType: .string)?.contains("1Password") == true {
            return true
        }

        // Check for common password manager patterns
        // In production, you'd want more sophisticated detection
        return false
    }

    private func addItem(_ item: ClipboardItem) {
        // Don't add duplicates
        if let existingIndex = history.firstIndex(where: { $0.text == item.text }) {
            history.remove(at: existingIndex)
        }

        history.insert(item, at: 0)

        // Trim history
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }

        saveHistory()
    }

    private func saveHistory() {
        // Save text items to UserDefaults
        let textItems = history.compactMap(\.text)
        UserDefaults.standard.set(textItems, forKey: "clipboardHistory")
    }

    private func loadHistory() {
        if let textItems = UserDefaults.standard.array(forKey: "clipboardHistory") as? [String] {
            history = textItems.map { ClipboardItem(text: $0, isImage: false) }
        }
    }
}

struct ClipboardItem {
    let id: UUID
    let text: String?
    let imageData: Data?
    let isImage: Bool
    let timestamp: Date

    var icon: NSImage? {
        if isImage {
            return NSImage(systemSymbolName: "photo", accessibilityDescription: "Image")
        }
        return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Text")
    }

    init(text: String, isImage: Bool) {
        id = UUID()
        self.text = text
        imageData = nil
        self.isImage = isImage
        timestamp = Date()
    }

    init(imageData: Data, isImage: Bool) {
        id = UUID()
        text = nil
        self.imageData = imageData
        self.isImage = isImage
        timestamp = Date()
    }
}

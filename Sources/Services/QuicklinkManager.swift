import AppKit
import Foundation

/// Manages quicklinks (URL bookmarks) storage and operations
final class QuicklinkManager {
    static let shared: QuicklinkManager = .init()

    private let fileManager = FileManager.default
    private var quicklinks: [Quicklink] = []

    private var quicklinksDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Zest/Quicklinks", isDirectory: true)
    }

    private var quicklinksFile: URL {
        quicklinksDirectory.appendingPathComponent("quicklinks.json")
    }

    private init() {
        createDirectoryIfNeeded()
        loadQuicklinks()
        addBuiltInQuicklinksIfNeeded()
    }

    // MARK: - Public Methods

    /// Get all quicklinks
    func getAllQuicklinks() -> [Quicklink] {
        quicklinks.sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
    }

    /// Search quicklinks by query
    func searchQuicklinks(query: String) -> [Quicklink] {
        guard !query.isEmpty else { return getAllQuicklinks() }

        let lowercasedQuery = query.lowercased()
        return quicklinks.filter { quicklink in
            quicklink.name.lowercased().contains(lowercasedQuery) ||
                quicklink.url.lowercased().contains(lowercasedQuery) ||
                quicklink.keywords.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    /// Add a new quicklink
    func addQuicklink(_ quicklink: Quicklink) {
        quicklinks.append(quicklink)
        saveQuicklinks()
    }

    /// Update an existing quicklink
    func updateQuicklink(_ quicklink: Quicklink) {
        if let index = quicklinks.firstIndex(where: { $0.id == quicklink.id }) {
            quicklinks[index] = quicklink
            saveQuicklinks()
        }
    }

    /// Delete a quicklink
    func deleteQuicklink(id: UUID) {
        quicklinks.removeAll { $0.id == id }
        saveQuicklinks()
    }

    /// Open a quicklink in the default browser
    func openQuicklink(id: UUID) -> Bool {
        guard let quicklink = quicklinks.first(where: { $0.id == id }) else {
            return false
        }

        guard let url = URL(string: quicklink.normalizedURL) else {
            return false
        }

        NSWorkspace.shared.open(url)

        // Update last used
        if let index = quicklinks.firstIndex(where: { $0.id == id }) {
            quicklinks[index].lastUsedAt = Date()
            saveQuicklinks()
        }

        return true
    }

    /// Get quicklink by ID
    func getQuicklink(id: UUID) -> Quicklink? {
        quicklinks.first { $0.id == id }
    }

    // MARK: - Private Methods

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: quicklinksDirectory.path) {
            try? fileManager.createDirectory(at: quicklinksDirectory, withIntermediateDirectories: true)
        }
    }

    private func loadQuicklinks() {
        guard fileManager.fileExists(atPath: quicklinksFile.path) else { return }

        do {
            let data = try Data(contentsOf: quicklinksFile)
            quicklinks = try JSONDecoder().decode([Quicklink].self, from: data)
        } catch {
            print("Failed to load quicklinks: \(error)")
            quicklinks = []
        }
    }

    private func saveQuicklinks() {
        do {
            let data = try JSONEncoder().encode(quicklinks)
            try data.write(to: quicklinksFile)
        } catch {
            print("Failed to save quicklinks: \(error)")
        }
    }

    private func addBuiltInQuicklinksIfNeeded() {
        guard !fileManager.fileExists(atPath: quicklinksFile.path) else { return }

        let builtInQuicklinks: [Quicklink] = [
            Quicklink(
                name: "Google",
                url: "https://google.com",
                keywords: ["search", "google"]
            ),
            Quicklink(
                name: "GitHub",
                url: "https://github.com",
                keywords: ["code", "git", "repository"]
            ),
            Quicklink(
                name: "Slack",
                url: "https://slack.com",
                keywords: ["chat", "team", "communication"]
            ),
        ]

        quicklinks = builtInQuicklinks
        saveQuicklinks()
    }
}

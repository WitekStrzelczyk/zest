import AppKit
import Foundation

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

    func getAllQuicklinks() -> [Quicklink] {
        quicklinks.sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
    }

    func searchQuicklinks(query: String) -> [Quicklink] {
        guard !query.isEmpty else { return getAllQuicklinks() }

        let lowercasedQuery = query.lowercased()
        return quicklinks.filter { quicklink in
            quicklink.name.lowercased().contains(lowercasedQuery) ||
                quicklink.url.lowercased().contains(lowercasedQuery) ||
                quicklink.keywords.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    func addQuicklink(_ quicklink: Quicklink) {
        quicklinks.append(quicklink)
        saveQuicklinks()
    }

    func updateQuicklink(_ quicklink: Quicklink) {
        if let index = quicklinks.firstIndex(where: { $0.id == quicklink.id }) {
            quicklinks[index] = quicklink
            saveQuicklinks()
        }
    }

    func deleteQuicklink(id: UUID) {
        quicklinks.removeAll { $0.id == id }
        saveQuicklinks()
    }

    func openQuicklink(id: UUID) -> Bool {
        guard let quicklink = quicklinks.first(where: { $0.id == id }) else {
            return false
        }

        guard let url = URL(string: quicklink.normalizedURL) else {
            return false
        }

        NSWorkspace.shared.open(url)

        if let index = quicklinks.firstIndex(where: { $0.id == id }) {
            quicklinks[index].lastUsedAt = Date()
            saveQuicklinks()
        }

        return true
    }

    func getQuicklink(id: UUID) -> Quicklink? {
        quicklinks.first { $0.id == id }
    }

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

    private static let googleCloudRegistry = Quicklink(
        name: "Google Cloud Registry",
        url: "https://console.cloud.google.com/artifacts/docker/ninety-devops/asia/apps"
            + "?hl=en&inv=1&invt=Ab0RbA&project=ninety-devops",
        keywords: ["gcr"]
    )

    private static let userCommandsFoldedKey = "quicklinksUserCommandsFolded"

    private func addBuiltInQuicklinksIfNeeded() {
        let defaults = UserDefaults.standard
        guard !fileManager.fileExists(atPath: quicklinksFile.path) else {
            guard !defaults.bool(forKey: Self.userCommandsFoldedKey) else { return }
            if !quicklinks.contains(where: { $0.url == Self.googleCloudRegistry.url }) {
                quicklinks.append(Self.googleCloudRegistry)
                saveQuicklinks()
            }
            defaults.set(true, forKey: Self.userCommandsFoldedKey)
            return
        }

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
            Self.googleCloudRegistry,
        ]

        quicklinks = builtInQuicklinks
        saveQuicklinks()
        defaults.set(true, forKey: Self.userCommandsFoldedKey)
    }
}

extension QuicklinkManager: SearchTool {
    private static let linkIcon = NSImage(systemSymbolName: "link", accessibilityDescription: "Quicklink")
    private static let addIcon = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Add Quicklink")

    var name: String { "Quicklinks" }

    func search(_ context: QueryContext) -> [SearchResult] {
        let lower = context.normalized.lowercased()
        let showAll = lower.contains("quicklink")
        let quicklinks = showAll ? getAllQuicklinks() : searchQuicklinks(query: lower)
        var results = quicklinks.map { quicklink in
            SearchResult(
                title: quicklink.name,
                subtitle: quicklink.url,
                icon: Self.linkIcon,
                category: .quicklink,
                action: { [weak self] in _ = self?.openQuicklink(id: quicklink.id) },
                score: showAll ? 2000 : max(1, SearchScoreCalculator.shared.calculateScore(
                    query: lower,
                    title: quicklink.name,
                    subtitle: quicklink.url,
                    category: .quicklink
                ))
            )
        }
        if lower.contains("add") {
            results.append(SearchResult(
                title: "Add Quicklink",
                subtitle: "Create a new quicklink",
                icon: Self.addIcon,
                category: .settings,
                action: { NotificationCenter.default.post(name: .showAddQuicklink, object: nil) },
                score: SearchScoreCalculator.shared.calculateScore(query: lower, title: "Add Quicklink", category: .settings)
            ))
        }
        return results
    }
}

import AppKit
import Foundation

final class SearchEngine {
    static let shared: SearchEngine = {
        let instance = SearchEngine()
        return instance
    }()

    private var installedApps: [InstalledApp] = []

    /// File search prefix for file-specific search
    private let fileSearchPrefix = "file:"

    /// Search task for cancellation
    private var currentSearchTask: Task<[SearchResult], Never>?

    private init() {
        refreshInstalledApps()
    }

    /// Cancel any in-progress search
    func cancelCurrentSearch() {
        currentSearchTask?.cancel()
        currentSearchTask = nil
    }

    /// Async search that runs file search on a background thread
    /// This prevents blocking the main thread with mdfind calls
    @MainActor
    func searchAsync(query: String) async -> [SearchResult] {
        // Run the blocking search on a background thread
        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return [] }
            return self.search(query: query)
        }.value
    }

    /// Synchronous search for backwards compatibility
    /// WARNING: This may block briefly during file search (max 2 seconds)
    func searchSyncCompat(query: String) -> [SearchResult] {
        return search(query: query)
    }

    func refreshInstalledApps() {
        let workspace = NSWorkspace.shared
        var apps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> InstalledApp? in
                guard let name = app.localizedName,
                      let bundleID = app.bundleIdentifier else { return nil }

                let icon = app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
                return InstalledApp(name: name, bundleID: bundleID, icon: icon)
            }

        // Also get installed apps from /Applications
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        let systemApplicationsURL = URL(fileURLWithPath: "/System/Applications")

        if let appURLs = try? FileManager.default.contentsOfDirectory(
            at: applicationsURL,
            includingPropertiesForKeys: nil
        ) {
            for url in appURLs where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                if !apps.contains(where: { $0.name == name }) {
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    apps.append(InstalledApp(name: name, bundleID: url.path, icon: icon))
                }
            }
        }

        if let systemAppURLs = try? FileManager.default.contentsOfDirectory(
            at: systemApplicationsURL,
            includingPropertiesForKeys: nil
        ) {
            for url in systemAppURLs where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                if !apps.contains(where: { $0.name == name }) {
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    apps.append(InstalledApp(name: name, bundleID: url.path, icon: icon))
                }
            }
        }

        installedApps = apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    func search(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()

        if lowercasedQuery.isEmpty {
            return []
        }

        var results: [SearchResult] = []
        var seenBundleIDs: Set<String> = []

        // Check for calculator expression FIRST (highest priority)
        if Calculator.shared.isMathExpression(query) {
            if let result = Calculator.shared.evaluate(query) {
                results.append(SearchResult(
                    title: result,
                    subtitle: "Copy to clipboard",
                    icon: NSImage(systemSymbolName: "function", accessibilityDescription: "Calculator"),
                    action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result, forType: .string)
                    }
                ))
            }
        }

        // Search clipboard history
        let clipboardResults = ClipboardManager.shared.search(query: query)
        results.append(contentsOf: clipboardResults)

        // Search emojis
        let emojiResults = EmojiSearchService.shared.search(query: query)
        results.append(contentsOf: emojiResults)

        // Fuzzy search with scoring through installed apps
        let appResults = installedApps
            .compactMap { app -> (app: InstalledApp, score: Int)? in
                let score = fuzzyScore(query: lowercasedQuery, target: app.name.lowercased())
                return score > 0 ? (app, score) : nil
            }
            .sorted { $0.score > $1.score }
            .prefix(10)
            .compactMap { item -> SearchResult? in
                // Deduplicate by bundleID
                guard !seenBundleIDs.contains(item.app.bundleID) else { return nil }
                seenBundleIDs.insert(item.app.bundleID)

                return SearchResult(
                    title: item.app.name,
                    subtitle: "Application",
                    icon: item.app.icon,
                    action: { [weak self] in
                        self?.launchApp(bundleID: item.app.bundleID)
                    }
                )
            }

        results.append(contentsOf: appResults)

        // Search for files using Spotlight (NSMetadataQuery)
        // Either through "file:" prefix or as part of general search
        let fileSearchQuery: String
        let isFileSpecificSearch = lowercasedQuery.hasPrefix(fileSearchPrefix)

        if isFileSpecificSearch {
            // Remove "file:" prefix for search
            fileSearchQuery = String(query.dropFirst(fileSearchPrefix.count))
        } else {
            // Include files in general search
            fileSearchQuery = query
        }

        if !fileSearchQuery.isEmpty {
            let fileResults = FileSearchService.shared.searchSync(query: fileSearchQuery, maxResults: 5)
            results.append(contentsOf: fileResults)
        }

        // Final deduplication pass (in case clipboard has same items)
        var finalResults: [SearchResult] = []
        var seenTitles: Set<String> = []
        for result in results {
            if !seenTitles.contains(result.title) {
                seenTitles.insert(result.title)
                finalResults.append(result)
            }
        }

        return Array(finalResults.prefix(10))
    }

    /// Returns score > 0 if query matches target (higher = better match)
    private func fuzzyScore(query: String, target: String) -> Int {
        var queryIndex = query.startIndex
        var targetIndex = target.startIndex
        var score = 0
        var consecutiveMatches = 0

        while queryIndex < query.endIndex, targetIndex < target.endIndex {
            if query[queryIndex] == target[targetIndex] {
                // Bonus for consecutive matches
                consecutiveMatches += 1
                score += 10 + (consecutiveMatches * 5)

                // Bonus for match at start
                if targetIndex == target.startIndex {
                    score += 20
                }

                // Bonus for match after space or underscore
                if targetIndex != target.startIndex {
                    let prevChar = target[target.index(before: targetIndex)]
                    if prevChar == " " || prevChar == "-" || prevChar == "_" {
                        score += 15
                    }
                }

                queryIndex = query.index(after: queryIndex)
            } else {
                consecutiveMatches = 0
            }
            targetIndex = target.index(after: targetIndex)
        }

        // Only return score if all query chars were matched
        return queryIndex == query.endIndex ? score : 0
    }

    private func launchApp(bundleID: String) {
        let workspace = NSWorkspace.shared

        // Try to find and launch by bundle ID first
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            workspace.openApplication(at: appURL, configuration: .init())
        } else {
            // Fallback: try as file path
            let appURL = URL(fileURLWithPath: bundleID)
            workspace.openApplication(at: appURL, configuration: .init())
        }
    }
}

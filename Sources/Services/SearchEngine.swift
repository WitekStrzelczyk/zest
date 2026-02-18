import AppKit
import Foundation

final class SearchEngine {
    static let shared: SearchEngine = .init()

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

    /// Fast search - returns apps, calculator, clipboard, emojis immediately (no file search)
    /// Use this for instant feedback while file search runs in background
    func searchFast(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()

        if lowercasedQuery.isEmpty {
            return []
        }

        var results: [SearchResult] = []
        var seenBundleIDs: Set<String> = []

        // Check for shell command FIRST (highest priority - starts with ">")
        if ShellCommandService.shared.isShellCommand(query) {
            let shellResult = ShellCommandService.shared.createShellCommandResult(for: query)
            results.append(shellResult)
            return results // Return early - shell commands take priority
        }

        // Check for calculator expression (high priority)
        if Calculator.shared.isMathExpression(query) {
            if let result = Calculator.shared.evaluate(query) {
                results.append(SearchResult(
                    title: result,
                    subtitle: "Copy to clipboard",
                    icon: NSImage(systemSymbolName: "function", accessibilityDescription: "Calculator"),
                    category: .action,
                    action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result, forType: .string)
                    }
                ))
            }
        }

        // Fuzzy search with scoring through installed apps
        let appResults = installedApps
            .compactMap { app -> (app: InstalledApp, score: Int)? in
                let score = fuzzyScore(query: lowercasedQuery, target: app.name.lowercased())
                return score > 0 ? (app, score) : nil
            }
            .sorted { $0.score > $1.score }
            .prefix(10)
            .compactMap { item -> SearchResult? in
                guard !seenBundleIDs.contains(item.app.bundleID) else { return nil }
                seenBundleIDs.insert(item.app.bundleID)

                let subtitle: String = if item.app.name == "Activity Monitor" {
                    SystemMetricsService.shared.getCurrentMetrics()
                } else {
                    "Application"
                }

                return SearchResult(
                    title: item.app.name,
                    subtitle: subtitle,
                    icon: item.app.icon,
                    category: .application,
                    action: { [weak self] in
                        self?.launchApp(bundleID: item.app.bundleID)
                    }
                )
            }
        results.append(contentsOf: appResults)

        // User commands (actions)
        let commandResults = UserCommandsService.shared.search(query: query)
        results.append(contentsOf: commandResults)

        // Contacts
        let contactResults = ContactsService.shared.search(query: query)
        results.append(contentsOf: contactResults)

        // Clipboard history
        let clipboardResults = ClipboardManager.shared.search(query: query)
        results.append(contentsOf: clipboardResults)

        // Emojis (last)
        let emojiResults = EmojiSearchService.shared.search(query: query)
        results.append(contentsOf: emojiResults)

        return results.sorted { $0.category < $1.category }
    }

    /// File search only - returns file results (can be slow, run async)
    func searchFiles(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()

        if lowercasedQuery.isEmpty {
            return []
        }

        let fileSearchQuery: String
        let isFileSpecificSearch = lowercasedQuery.hasPrefix(fileSearchPrefix)

        if isFileSpecificSearch {
            fileSearchQuery = String(query.dropFirst(fileSearchPrefix.count))
        } else {
            fileSearchQuery = query
        }

        if !fileSearchQuery.isEmpty {
            return FileSearchService.shared.searchSync(query: fileSearchQuery, maxResults: 5)
        }

        return []
    }

    /// Async search that runs file search on a background thread
    /// This prevents blocking the main thread with mdfind calls
    @MainActor
    func searchAsync(query: String) async -> [SearchResult] {
        // Run the blocking search on a background thread
        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return [] }
            return search(query: query)
        }.value
    }

    /// Synchronous search for backwards compatibility
    /// WARNING: This may block briefly during file search (max 2 seconds)
    func searchSyncCompat(query: String) -> [SearchResult] {
        search(query: query)
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

        // Scan all application directories
        let applicationPaths = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
        ]

        for path in applicationPaths {
            let url = URL(fileURLWithPath: path)
            if let appURLs = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            ) {
                for appURL in appURLs where appURL.pathExtension == "app" {
                    let name = appURL.deletingPathExtension().lastPathComponent
                    if !apps.contains(where: { $0.name == name }) {
                        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                        apps.append(InstalledApp(name: name, bundleID: appURL.path, icon: icon))
                    }
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

        // Check for shell command FIRST (highest priority - starts with ">")
        if ShellCommandService.shared.isShellCommand(query) {
            let shellResult = ShellCommandService.shared.createShellCommandResult(for: query)
            results.append(shellResult)
            return results // Return early - shell commands take priority
        }

        // Check for calculator expression (high priority)
        if Calculator.shared.isMathExpression(query) {
            if let result = Calculator.shared.evaluate(query) {
                results.append(SearchResult(
                    title: result,
                    subtitle: "Copy to clipboard",
                    icon: NSImage(systemSymbolName: "function", accessibilityDescription: "Calculator"),
                    category: .action,
                    action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result, forType: .string)
                    }
                ))
            }
        }

        // Fuzzy search with scoring through installed apps
        let appResults = installedApps
            .compactMap { app -> (app: InstalledApp, score: Int)? in
                let score = fuzzyScore(query: lowercasedQuery, target: app.name.lowercased())
                return score > 0 ? (app, score) : nil
            }
            .sorted { $0.score > $1.score }
            .prefix(10)
            .compactMap { item -> SearchResult? in
                guard !seenBundleIDs.contains(item.app.bundleID) else { return nil }
                seenBundleIDs.insert(item.app.bundleID)

                let subtitle: String = if item.app.name == "Activity Monitor" {
                    SystemMetricsService.shared.getCurrentMetrics()
                } else {
                    "Application"
                }

                return SearchResult(
                    title: item.app.name,
                    subtitle: subtitle,
                    icon: item.app.icon,
                    category: .application,
                    action: { [weak self] in
                        self?.launchApp(bundleID: item.app.bundleID)
                    }
                )
            }
        results.append(contentsOf: appResults)

        // User commands (actions)
        let commandResults = UserCommandsService.shared.search(query: query)
        results.append(contentsOf: commandResults)

        // Contacts
        let contactResults = ContactsService.shared.search(query: query)
        results.append(contentsOf: contactResults)

        // Clipboard history
        let clipboardResults = ClipboardManager.shared.search(query: query)
        results.append(contentsOf: clipboardResults)

        // Search for files using Spotlight
        let fileSearchQuery: String
        let isFileSpecificSearch = lowercasedQuery.hasPrefix(fileSearchPrefix)

        if isFileSpecificSearch {
            fileSearchQuery = String(query.dropFirst(fileSearchPrefix.count))
        } else {
            fileSearchQuery = query
        }

        if !fileSearchQuery.isEmpty {
            let fileResults = FileSearchService.shared.searchSync(query: fileSearchQuery, maxResults: 5)
            results.append(contentsOf: fileResults)
        }

        // Emojis (last)
        let emojiResults = EmojiSearchService.shared.search(query: query)
        results.append(contentsOf: emojiResults)

        // Deduplicate and sort by category
        var finalResults: [SearchResult] = []
        var seenTitles: Set<String> = []
        for result in results {
            if !seenTitles.contains(result.title) {
                seenTitles.insert(result.title)
                finalResults.append(result)
            }
        }

        return Array(finalResults.sorted { $0.category < $1.category }.prefix(10))
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

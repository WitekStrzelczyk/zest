import AppKit
import Foundation

final class SearchEngine {
    static let shared: SearchEngine = .init()

    private var installedApps: [InstalledApp] = []
    private var appsLoaded = false
    private let appsLock = NSLock()
    private let appsLoadLock = NSLock()

    private static let maxResults = 80

    private static let intents: [SearchTool] = [
        UnitConversionWorker.shared,
        CalendarEventWorker.shared,
        MapSearchWorker.shared,
        ProcessWorker.shared,
    ]

    private static let instantTools: [SearchTool] = [
        Calculator.shared,
        QuicklinkManager.shared,
        ColorPickerPlugin.shared,
        BatteryService.shared,
        SystemLoadTool.shared,
        SystemInfoService.shared,
        NetworkInfoService.shared,
        TimeZoneConverterService.shared,
        CalendarService.shared,
        ContactsService.shared,
        SystemSettingsSearch.shared,
    ]
    private let fileSearchPrefix = "file:"
    private var currentSearchTask: Task<[SearchResult], Never>?

    private let tracer = SearchTracer.shared

    private(set) var lastSearchTrace: SearchSpan?
    static var disableAppLoading = false
    static var isDisabled = false

    private init() {}

    private func ensureAppsLoaded() {
        appsLoadLock.lock()
        defer { appsLoadLock.unlock() }
        guard !appsLoaded, !Self.disableAppLoading else { return }
        refreshInstalledApps()
        appsLoaded = true
    }

    func preloadApps() {
        Task.detached(priority: .userInitiated) { self.ensureAppsLoaded() }
    }

    func instantAppResults(for query: String) -> [SearchResult] {
        appsLock.lock()
        let apps = installedApps
        appsLock.unlock()
        return appResults(for: query, in: apps) { path in
            IconCache.shared.cachedIcon(for: path) ?? NSWorkspace.shared.icon(forFile: path)
        }
    }

    private func renderedAppResults(for query: String) -> [SearchResult] {
        appsLock.lock()
        let apps = installedApps
        appsLock.unlock()
        return appResults(for: query, in: apps) { IconCache.shared.renderedIcon(for: $0) }
    }

    private func appResults(
        for query: String,
        in apps: [InstalledApp],
        icon: (String) -> NSImage
    ) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        let scored = apps.compactMap { app -> (app: InstalledApp, score: Int)? in
            let score = SearchScoreCalculator.shared.calculateScore(query: query, title: app.name, category: .application)
            return score > 0 ? (app, score) : nil
        }
        return scored.sorted { $0.score > $1.score }.prefix(10).map { item in
            SearchResult(
                title: item.app.name,
                subtitle: "Application",
                icon: icon(item.app.path),
                category: .application,
                action: { Self.launchApp(bundleID: item.app.bundleID) },
                score: item.score
            )
        }
    }

    func cancelCurrentSearch() {
        appsLock.lock()
        currentSearchTask?.cancel()
        currentSearchTask = nil
        appsLock.unlock()
    }

    func searchFast(query: String) -> [SearchResult] {
        search(query: query)
    }

    func searchStream(query: String) -> AsyncStream<[SearchResult]> {
        AsyncStream { continuation in
            let resultsLimit = min(Self.maxResults, PreferencesManager.shared.searchResultsLimit)

            let span = tracer.startSearch(query: query)
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continuation.finish()
                return
            }

            var currentResults: [SearchResult] = []
            let resultsLock = NSLock()

            func emit(_ newResults: [SearchResult]) {
                guard !newResults.isEmpty else { return }
                resultsLock.lock()
                for res in newResults {
                    if !currentResults.contains(where: { $0.title == res.title && $0.subtitle == res.subtitle }) {
                        currentResults.append(res)
                    }
                }
                currentResults.sort(by: SearchResult.rankedBefore)
                let snapshot = Array(currentResults.prefix(resultsLimit))
                resultsLock.unlock()
                continuation.yield(snapshot)
            }

            let task = Task.detached(priority: .userInitiated) { [self] in
                let context = QueryAnalyzer.shared.analyze(query)

                func finishSearch() {
                    span.finish()
                    lastSearchTrace = span
                    tracer.outputTrace(span, query: context.raw)
                    continuation.finish()
                }

                func run(_ tools: [SearchTool]) -> Bool {
                    for tool in tools {
                        if Task.isCancelled { return false }
                        let toolSpan = span.createChild(operationName: tool.name)
                        let results = autoreleasepool { tool.search(context) }
                        toolSpan.setResultsCount(results.count)
                        toolSpan.finish()
                        emit(results)
                        if tool.endsSearch, !results.isEmpty { return false }
                    }
                    return !Task.isCancelled
                }

                guard run(Self.intents) else { return finishSearch() }

                let appSpan = span.createChild(operationName: "Applications")
                ensureAppsLoaded()
                let finalApps = renderedAppResults(for: context.normalized)
                emit(finalApps)
                appSpan.setResultsCount(finalApps.count)
                appSpan.finish()

                guard run(Self.instantTools) else { return finishSearch() }

                let fileNLSpan = span.createChild(operationName: "File Search (NL)")
                let fileIntent = FileSearchWorker.shared.parse(context: context)
                if context.contains(anyOf: ["file", "files"]) || fileIntent.date != nil || fileIntent
                    .isLarge || fileIntent.fileExtension != nil
                {
                    let predicate = FileSearchWorker.shared.buildPredicate(from: fileIntent)
                    fileNLSpan.setTag("predicate", predicate.predicateFormat)
                    if !FileSearchService.isDisabled {
                        let fileResults = FileSearchService.shared.searchSync(
                            predicate: predicate,
                            maxResults: 20,
                            originalQuery: context.normalized
                        )
                        emit(fileResults.map { var r = $0
                            r.score = 2500
                            return r
                        })
                        fileNLSpan.setResultsCount(fileResults.count)
                    }
                }
                fileNLSpan.finish()
                guard !Task.isCancelled else { return finishSearch() }

                let fileStandardSpan = span.createChild(operationName: "File Search (Standard)")
                let fileSearchQuery = context.normalized
                    .hasPrefix(fileSearchPrefix) ? String(context.raw.dropFirst(fileSearchPrefix.count)) : context
                    .normalized
                if fileSearchQuery.count >= 3, !FileSearchService.isDisabled {
                    let fileResults = FileSearchService.shared.searchSync(
                        query: fileSearchQuery,
                        maxResults: 20,
                        originalQuery: context.normalized
                    )
                    emit(fileResults)
                    fileStandardSpan.setResultsCount(fileResults.count)
                }
                fileStandardSpan.finish()

                finishSearch()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func search(query: String) -> [SearchResult] {
        var last: [SearchResult] = []
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            for await results in searchStream(query: query) {
                last = results
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5.0)
        return last
    }

    func searchFiles(query: String) -> [SearchResult] {
        search(query: query).filter { $0.category == .file }
    }

    @MainActor
    func searchAsync(query: String) async -> [SearchResult] {
        await Task.detached(priority: .userInitiated) {
            self.search(query: query)
        }.value
    }

    func refreshInstalledApps() {
        var apps: [InstalledApp] = []
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
            .compactMap { app -> InstalledApp? in
                guard let name = app.localizedName, let bundleID = app.bundleIdentifier,
                      let path = app.bundleURL?.path else { return nil }
                return InstalledApp(name: name, bundleID: bundleID, path: path)
            }
        apps.append(contentsOf: runningApps)

        for app in Self.spotlightApps() where !apps.contains(where: { $0.name == app.name || $0.bundleID == app.bundleID }) {
            apps.append(app)
        }

        let sortedApps = apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        appsLock.lock()
        installedApps = sortedApps
        appsLock.unlock()
    }

    private static let appQueries: [(query: String, scopes: [String])] = [
        (
            "kMDItemContentTypeTree == 'com.apple.application-bundle'",
            ["/Applications", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path]
        ),
        ("kMDItemFSName == '*.app'", ["/System/Applications"]),
    ]

    private static func spotlightApps() -> [InstalledApp] {
        appQueries.flatMap { spotlightApps(matching: $0.query, in: $0.scopes) }
    }

    private static func spotlightApps(matching queryString: String, in scopes: [String]) -> [InstalledApp] {
        guard let query = MDQueryCreate(kCFAllocatorDefault, queryString as CFString, nil, nil) else { return [] }
        MDQuerySetSearchScope(query, scopes as CFArray, 0)
        guard MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue)) else { return [] }

        return (0..<MDQueryGetResultCount(query)).compactMap { index in
            guard let raw = MDQueryGetResultAtIndex(query, index) else { return nil }
            let item = Unmanaged<MDItem>.fromOpaque(raw).takeUnretainedValue()
            guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String, !path.contains(".app/") else { return nil }
            let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            let displayName = (MDItemCopyAttribute(item, kMDItemDisplayName) as? String).map {
                $0.hasSuffix(".app") ? String($0.dropLast(4)) : $0
            }
            let bundleID = MDItemCopyAttribute(item, kMDItemCFBundleIdentifier) as? String ?? path
            return InstalledApp(name: displayName ?? fileName, bundleID: bundleID, path: path)
        }
    }

    private static func launchApp(bundleID: String) {
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            workspace.openApplication(at: appURL, configuration: .init())
        } else {
            workspace.openApplication(at: URL(fileURLWithPath: bundleID), configuration: .init())
        }
    }
}

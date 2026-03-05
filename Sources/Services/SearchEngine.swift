import AppKit
import Foundation

final class SearchEngine {
    static let shared: SearchEngine = .init()

    private var installedApps: [InstalledApp] = []
    private var appsLoaded = false
    private let appsLock = NSLock()

    private let fileSearchPrefix = "file:"
    private var currentSearchTask: Task<[SearchResult], Never>?

    private let quicklinkManager = QuicklinkManager.shared
    private let awakeService = AwakeService.shared
    private let tracer = SearchTracer.shared
    private let clipboardPrefix = "clip"

    private(set) var lastSearchTrace: SearchSpan?
    static var disableAppLoading = false
    static var isDisabled = false

    private init() {}

    private func ensureAppsLoaded() {
        appsLock.lock()
        let loaded = appsLoaded
        appsLock.unlock()
        guard !loaded, !Self.disableAppLoading else { return }
        appsLock.lock()
        appsLoaded = true
        appsLock.unlock()
        refreshInstalledApps()
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

    /// Streaming search that yields results as each tool finishes
    func searchStream(query: String) -> AsyncStream<[SearchResult]> {
        AsyncStream { continuation in
            let context = QueryAnalyzer.shared.analyze(query)

            ensureAppsLoaded()
            appsLock.lock()
            let apps = installedApps
            appsLock.unlock()

            let span = tracer.startSearch(query: query)
            if context.normalized.isEmpty {
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
                let snapshot = currentResults
                resultsLock.unlock()
                continuation.yield(snapshot)
            }

            let task = Task {
                // 1. --- UNIT CONVERSION ---
                let unitSpan = span.createChild(operationName: "Unit Conversion")
                if let intent = UnitConversionWorker.shared.parse(context: context),
                   let result = UnitConversionWorker.shared.execute(intent: intent)
                {
                    unitSpan.setTag("intent", "\(intent.value) \(intent.fromUnit) -> \(intent.toUnit)")
                    emit([SearchResult(
                        title: result, subtitle: "Unit Conversion",
                        icon: NSImage(
                            systemSymbolName: "arrow.left.arrow.right",
                            accessibilityDescription: "Unit Converter"
                        ),
                        category: .conversion,
                        action: { NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result, forType: .string)
                        },
                        score: 3000
                    )])
                    unitSpan.setResultsCount(1)
                }
                unitSpan.finish()

                if Task.isCancelled { return }

                // 2. --- CALENDAR EVENT ---
                let calSpan = span.createChild(operationName: "Calendar Event")
                if let intent = CalendarEventWorker.shared.parse(context: context) {
                    calSpan.setTag("title", intent.title)
                    if let d = intent.date { calSpan.setTag("date", d.description) }

                    let res = SearchResult(
                        title: "Add Event: \(intent.title)",
                        subtitle: "Date: \(intent.date?.description ?? "Not specified") | Location: \(intent.location ?? "Not specified")",
                        icon: NSImage(
                            systemSymbolName: "calendar.badge.plus",
                            accessibilityDescription: "Add Calendar Event"
                        ),
                        category: .calendar,
                        action: {}, score: 2800
                    )
                    emit([res])
                    calSpan.setResultsCount(1)
                }
                calSpan.finish()

                if Task.isCancelled { return }

                // 3. --- PROCESS MANAGEMENT ---
                let procSpan = span.createChild(operationName: "Process Management")
                if let intent = ProcessWorker.shared.parse(context: context) {
                    procSpan.setTag("action", String(describing: intent.action))
                    var pRes: [SearchResult] = []
                    switch intent.action {
                    case .listAll:
                        pRes = ProcessSearchService.shared
                            .createSearchResults(from: ProcessSearchService.shared.fetchRunningProcesses())
                    case .findByPort(let port):
                        let processes = ProcessSearchService.shared.findProcessesUsingPort(port)
                        if processes.isEmpty {
                            pRes = [SearchResult(
                                title: "No process found on port \(port)",
                                subtitle: "Nothing is currently listening on this port",
                                icon: NSImage(
                                    systemSymbolName: "network.badge.shield.half.filled",
                                    accessibilityDescription: "No Process"
                                ),
                                category: .process,
                                action: {},
                                revealAction: nil, // DISABLE Cmd+Enter
                                score: 2900
                            )]
                        } else {
                            pRes = ProcessSearchService.shared.createSearchResults(from: processes)
                        }
                    case .filterByName(let name):
                        pRes = ProcessSearchService.shared
                            .createSearchResults(from: ProcessSearchService.shared.searchProcesses(query: name))
                    }
                    emit(pRes.map { var r = $0
                        r.score = 2900
                        return r
                    })
                    procSpan.setResultsCount(pRes.count)
                }
                procSpan.finish()

                if Task.isCancelled { return }

                // 4. --- APPLICATIONS ---
                let appSpan = span.createChild(operationName: "Applications")
                let appResults = apps.compactMap { app -> (app: InstalledApp, score: Int)? in
                    let score = SearchScoreCalculator.shared.calculateScore(
                        query: context.normalized,
                        title: app.name,
                        category: .application
                    )
                    return score > 0 ? (app, score) : nil
                }
                let finalApps = appResults.sorted { $0.score > $1.score }.prefix(10)
                    .compactMap { item -> SearchResult? in
                        SearchResult(
                            title: item.app.name,
                            subtitle: "Application",
                            icon: item.app.icon,
                            category: .application,
                            action: { [weak self] in self?.launchApp(bundleID: item.app.bundleID) },
                            score: item.score
                        )
                    }
                emit(finalApps)
                appSpan.setResultsCount(finalApps.count)
                appSpan.finish()

                if Task.isCancelled { return }

                // 5. --- SYSTEM TOOLS & PLUGINS ---
                let otherTools: [(String, (String) -> [SearchResult])] = [
                    ("User Commands", UserCommandsService.shared.search),
                    ("Color Picker", ColorPickerPlugin.shared.search),
                    ("Battery", BatteryService.shared.search),
                    ("System Info", SystemInfoService.shared.search),
                    ("Network Info", NetworkInfoService.shared.search),
                    ("TimeZone", TimeZoneConverterService.shared.search),
                    ("Calendar (System)", { q in guard !CalendarService.isDisabled else { return [] }
                        return CalendarService.shared.search(query: q) }),
                    ("Contacts", { q in guard !ContactsService.isDisabled else { return [] }
                        return ContactsService.shared.search(query: q) }),
                ]

                for (name, searchFunc) in otherTools {
                    if Task.isCancelled { break }
                    let toolSpan = span.createChild(operationName: name)
                    let toolResults = autoreleasepool { searchFunc(context.normalized) }
                    toolSpan.setResultsCount(toolResults.count)
                    toolSpan.finish()
                    emit(toolResults)
                }

                if Task.isCancelled { return }

                // 6. --- FILE SEARCH ---
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

                // 7. --- MAP SEARCH ---
                if let location = context.location {
                    let mapSpan = span.createChild(operationName: "Map Search")
                    let term = location.trimmingCharacters(in: .whitespacesAndNewlines)
                    if term.count > 2 {
                        mapSpan.setTag("location", term)
                        emit([SearchResult(
                            title: "Search Map: \(term)", subtitle: "Open in Apple Maps",
                            icon: NSImage(systemSymbolName: "map", accessibilityDescription: "Map"),
                            category: .action,
                            action: {
                                let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let url = URL(string: "maps://?q=\(encoded)") { NSWorkspace.shared.open(url) }
                            },
                            score: 2700
                        )])
                        mapSpan.setResultsCount(1)
                    }
                    mapSpan.finish()
                }

                span.finish()
                lastSearchTrace = span
                tracer.outputTrace(span, query: context.raw)
                continuation.finish()
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
                guard let name = app.localizedName, let bundleID = app.bundleIdentifier else { return nil }
                return InstalledApp(
                    name: name,
                    bundleID: bundleID,
                    icon: app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
                )
            }
        apps.append(contentsOf: runningApps)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemContentTypeTree == 'com.apple.application-bundle'"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        if let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
            let appPaths = output.components(separatedBy: "\n").filter { !$0.isEmpty }
            for appPath in appPaths {
                let appURL = URL(fileURLWithPath: appPath)
                let name = appURL.deletingPathExtension().lastPathComponent
                if apps.contains(where: { $0.name == name }) { continue }
                if appPath.hasPrefix("/Library") { continue }
                if appPath.hasPrefix("/System"), !appPath.hasPrefix("/System/Applications") { continue }
                apps.append(InstalledApp(
                    name: name,
                    bundleID: appPath,
                    icon: NSWorkspace.shared.icon(forFile: appPath)
                ))
            }
        }

        let sortedApps = apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        appsLock.lock()
        installedApps = sortedApps
        appsLock.unlock()
    }

    private func launchApp(bundleID: String) {
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            workspace.openApplication(at: appURL, configuration: .init())
        } else {
            workspace.openApplication(at: URL(fileURLWithPath: bundleID), configuration: .init())
        }
    }
}

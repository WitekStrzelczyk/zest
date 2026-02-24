import AppKit
import Foundation

final class SearchEngine {
    static let shared: SearchEngine = .init()

    private var installedApps: [InstalledApp] = []
    private var appsLoaded = false

    /// File search prefix for file-specific search
    private let fileSearchPrefix = "file:"

    /// Search task for cancellation
    private var currentSearchTask: Task<[SearchResult], Never>?

    private let quicklinkManager = QuicklinkManager.shared
    private let awakeService = AwakeService.shared
    private let tracer = SearchTracer.shared

    /// Last search trace for displaying stats
    private(set) var lastSearchTrace: SearchSpan?

    /// Flag to disable app loading for tests
    static var disableAppLoading = false

    private init() {
        // Lazy load apps - don't block init with mdfind
    }

    /// Ensure apps are loaded (lazy initialization)
    private func ensureAppsLoaded() {
        guard !appsLoaded && !Self.disableAppLoading else { return }
        appsLoaded = true
        refreshInstalledApps()
    }

    /// Cancel any in-progress search
    func cancelCurrentSearch() {
        currentSearchTask?.cancel()
        currentSearchTask = nil
    }
    
    /// Get the last search trace for displaying stats
    func getLastTrace() -> SearchSpan? {
        lastSearchTrace
    }

    /// Fast search - returns apps, calculator, clipboard immediately (no file search)
    /// Use this for instant feedback while file search runs in background
    func searchFast(query: String) -> [SearchResult] {
        ensureAppsLoaded()

        let span = tracer.startSearch(query: query)
        defer {
            span.finish()
            lastSearchTrace = span
            tracer.outputTrace(span)
        }

        let lowercasedQuery = query.lowercased()

        if lowercasedQuery.isEmpty {
            return []
        }

        var results: [SearchResult] = []
        var seenBundleIDs: Set<String> = []

        // Check for shell command FIRST (highest priority - starts with ">")
        if ShellCommandService.shared.isShellCommand(query) {
            let shellSpan = span.createChild(operationName: "shell_command")
            let shellResult = ShellCommandService.shared.createShellCommandResult(for: query)
            results.append(shellResult)
            shellSpan.finish()
            return results // Return early - shell commands take priority
        }

        // Check for process search (type "processes" to see running processes)
        if lowercasedQuery.contains("process") {
            let processSpan = span.createChild(operationName: "process_search")
            let processResults = performProcessSearch(query: lowercasedQuery)
            processSpan.setTag("results", processResults.count)
            processSpan.finish()
            
            if !processResults.isEmpty {
                results.append(contentsOf: processResults)
                // Return early if process search matched - processes take priority
                return results.sorted { (a, b) -> Bool in
                    if a.score != b.score { return a.score > b.score }
                    return a.category < b.category
                }
            }
        }

        // Check for calculator expression (high priority)
        let calcSpan = span.createChild(operationName: "calculator")
        if Calculator.shared.isMathExpression(query) {
            if let result = Calculator.shared.evaluate(query) {
                calcSpan.setTag("expression", query)
                calcSpan.setTag("result", result)
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
        calcSpan.finish()

        // Check for unit conversion expression (high priority)
        let convSpan = span.createChild(operationName: "unit_conversion")
        if UnitConverter.shared.isConversionExpression(query) {
            if let result = UnitConverter.shared.convert(query) {
                convSpan.setTag("expression", query)
                convSpan.setTag("result", result)
                results.append(SearchResult(
                    title: result,
                    subtitle: "Conversion",
                    icon: NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "Unit Converter"),
                    category: .conversion,
                    action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result, forType: .string)
                    },
                    score: 2000 // Very high score to ensure conversion is always first
                ))
            }
        } else if lowercasedQuery == "convert" {
            // Show conversion hints when user types "convert"
            convSpan.setTag("showing_hints", true)
            let hints = UnitConverter.shared.getHints()
            for hint in hints {
                results.append(SearchResult(
                    title: hint,
                    subtitle: "Unit Conversion Example",
                    icon: NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "Unit Converter"),
                    category: .conversion,
                    action: { },
                    score: 2000
                ))
            }
        }
        convSpan.finish()

        // Check for time zone conversion (high priority)
        let tzSpan = span.createChild(operationName: "time_zone_conversion")
        let tzResults = TimeZoneConverterService.shared.search(query: query)
        tzSpan.setTag("results", tzResults.count)
        tzSpan.finish()
        results.append(contentsOf: tzResults)

        // Fuzzy search through installed apps
        let appSpan = span.createChild(operationName: "applications")
        appSpan.setTag("total_apps", installedApps.count)
        
        // Trace fuzzy matching
        let fuzzyMatchSpan = appSpan.createChild(operationName: "fuzzy.match")
        fuzzyMatchSpan.setTag("query_length", lowercasedQuery.count)
        fuzzyMatchSpan.setTag("items_to_match", installedApps.count)
        
        let matchedApps = installedApps.compactMap { app -> (app: InstalledApp, score: Int)? in
            let score = SearchScoreCalculator.shared.calculateScore(
                query: lowercasedQuery,
                title: app.name,
                category: .application
            )
            return score > 0 ? (app, score) : nil
        }
        
        fuzzyMatchSpan.setTag("matches_found", matchedApps.count)
        fuzzyMatchSpan.finish()
        
        // Trace sorting
        let sortSpan = appSpan.createChild(operationName: "sort")
        sortSpan.setTag("items_to_sort", matchedApps.count)
        
        let finalAppResults = matchedApps
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
                    },
                    score: item.score
                )
            }
        sortSpan.finish()
        appSpan.setTag("results", finalAppResults.count)
        appSpan.finish()
        results.append(contentsOf: finalAppResults)

        // User commands (actions)
        let cmdSpan = span.createChild(operationName: "user_commands")
        let commandResults = UserCommandsService.shared.search(query: query)
        cmdSpan.setTag("results", commandResults.count)
        cmdSpan.finish()
        results.append(contentsOf: commandResults)

        // Color Picker
        let colorSpan = span.createChild(operationName: "color_picker")
        let colorPickerResults = ColorPickerPlugin.shared.search(query: query)
        colorSpan.setTag("results", colorPickerResults.count)
        colorSpan.finish()
        results.append(contentsOf: colorPickerResults)

        // Contacts
        let contactSpan = span.createChild(operationName: "contacts")
        let contactResults = ContactsService.shared.search(query: query)
        contactSpan.setTag("results", contactResults.count)
        contactSpan.finish()
        results.append(contentsOf: contactResults)

        // Battery info
        let batterySpan = span.createChild(operationName: "battery")
        let batteryResults = BatteryService.shared.search(query: query)
        batterySpan.setTag("results", batteryResults.count)
        batterySpan.finish()
        results.append(contentsOf: batteryResults)

        // System info (storage, system specs)
        let systemInfoSpan = span.createChild(operationName: "system_info")
        let systemInfoResults = SystemInfoService.shared.search(query: query)
        systemInfoSpan.setTag("results", systemInfoResults.count)
        systemInfoSpan.finish()
        results.append(contentsOf: systemInfoResults)
        
        // Network info (IP addresses, WiFi)
        let networkSpan = span.createChild(operationName: "network_info")
        let networkResults = NetworkInfoService.shared.search(query: query)
        networkSpan.setTag("results", networkResults.count)
        networkSpan.finish()
        results.append(contentsOf: networkResults)

        // Clipboard history
        let clipSpan = span.createChild(operationName: "clipboard")
        let clipboardResults = ClipboardManager.shared.search(query: query)
        clipSpan.setTag("results", clipboardResults.count)
        clipSpan.finish()
        results.append(contentsOf: clipboardResults)

        // Emojis disabled - users can use Cmd+Ctrl+Space system picker instead
        // let emojiResults = EmojiSearchService.shared.search(query: query)
        // results.append(contentsOf: emojiResults)

        // Global commands (lowest priority)
        let globalSpan = span.createChild(operationName: "global_commands")
        let globalCommandResults = GlobalCommandsService.shared.search(query: query)
        globalSpan.setTag("results", globalCommandResults.count)
        globalSpan.finish()
        results.append(contentsOf: globalCommandResults)

        // Toggles (low priority - below apps)
        let toggleSpan = span.createChild(operationName: "toggles")
        let toggleResults = searchToggles(query: lowercasedQuery)
        toggleSpan.setTag("results", toggleResults.count)
        toggleSpan.finish()
        results.append(contentsOf: toggleResults)

        // Quicklinks - searchable by name, URL, keyword "quicklink"
        let quicklinkResults = searchQuicklinks(query: lowercasedQuery)
        results.append(contentsOf: quicklinkResults)

        // Settings category - "Add Quicklink" as first item
        if lowercasedQuery.contains("add") || lowercasedQuery.isEmpty {
            let settingsResults = createSettingsResults(query: lowercasedQuery)
            results.append(contentsOf: settingsResults)
        }

        return results.sorted { (a, b) -> Bool in
            if a.score != b.score { return a.score > b.score }
            return a.category < b.category
        }
    }

    // MARK: - Process Search

    /// Performs process search - shows running processes when user types "processes"
    private func performProcessSearch(query: String) -> [SearchResult] {
        // If query is just "process" or "processes", show top processes
        let isProcessKeywordOnly = query == "process" || query == "processes"

        if isProcessKeywordOnly {
            // Show all top processes
            let processes = ProcessSearchService.shared.fetchRunningProcesses()
            return ProcessSearchService.shared.createSearchResults(from: processes)
        } else {
            // Search for specific process by name
            let searchQuery = query.replacingOccurrences(of: "process", with: "").trimmingCharacters(in: .whitespaces)
            if !searchQuery.isEmpty {
                let processes = ProcessSearchService.shared.searchProcesses(query: searchQuery)
                if processes.isEmpty {
                    // Return no results message
                    return [SearchResult(
                        title: ProcessSearchService.noResultsMessage,
                        subtitle: "Try a different search term",
                        icon: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search"),
                        category: .process,
                        action: {},
                        score: 0
                    )]
                }
                return ProcessSearchService.shared.createSearchResults(from: processes)
            }
        }

        return []
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
        var apps: [InstalledApp] = []

        // First add running apps
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> InstalledApp? in
                guard let name = app.localizedName,
                      let bundleID = app.bundleIdentifier else { return nil }

                let icon = app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
                return InstalledApp(name: name, bundleID: bundleID, icon: icon)
            }
        apps.append(contentsOf: runningApps)

        // Use Spotlight to find all apps
        // Note: kMDItemContentTypeTree works for apps without direct content type (like Zoom.us)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemContentTypeTree == 'com.apple.application-bundle'"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let appPaths = output.components(separatedBy: "\n").filter { !$0.isEmpty }

                for appPath in appPaths {
                    let appURL = URL(fileURLWithPath: appPath)
                    let name = appURL.deletingPathExtension().lastPathComponent

                    // Skip if already added (from running apps)
                    if apps.contains(where: { $0.name == name }) {
                        continue
                    }

                    // Skip system paths
                    if appPath.hasPrefix("/Library") { continue }
                    if appPath.hasPrefix("/System") && !appPath.hasPrefix("/System/Applications") { continue }

                    let icon = NSWorkspace.shared.icon(forFile: appPath)
                    apps.append(InstalledApp(name: name, bundleID: appPath, icon: icon))
                }
            }
        } catch {
            print("Spotlight query failed: \(error)")
        }

        installedApps = apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        print("Indexed \(installedApps.count) applications")
    }

    func search(query: String) -> [SearchResult] {
        ensureAppsLoaded()

        let span = tracer.startSearch(query: query)
        defer {
            span.finish()
            lastSearchTrace = span
            tracer.outputTrace(span)
        }

        let lowercasedQuery = query.lowercased()

        if lowercasedQuery.isEmpty {
            return []
        }

        var results: [SearchResult] = []
        var seenBundleIDs: Set<String> = []

        // Check for shell command FIRST (highest priority - starts with ">")
        if ShellCommandService.shared.isShellCommand(query) {
            let shellSpan = span.createChild(operationName: "shell_command")
            let shellResult = ShellCommandService.shared.createShellCommandResult(for: query)
            results.append(shellResult)
            shellSpan.finish()
            return results // Return early - shell commands take priority
        }

        // Check for process search (type "processes" to see running processes)
        if lowercasedQuery.contains("process") {
            let processSpan = span.createChild(operationName: "process_search")
            let processResults = performProcessSearch(query: lowercasedQuery)
            processSpan.setTag("results", processResults.count)
            processSpan.finish()
            
            if !processResults.isEmpty {
                results.append(contentsOf: processResults)
                // Return early if process search matched - processes take priority
                return results.sorted { (a, b) -> Bool in
                    if a.score != b.score { return a.score > b.score }
                    return a.category < b.category
                }
            }
        }

        // Check for calculator expression (high priority)
        let calcSpan = span.createChild(operationName: "calculator")
        if Calculator.shared.isMathExpression(query) {
            if let result = Calculator.shared.evaluate(query) {
                calcSpan.setTag("expression", query)
                calcSpan.setTag("result", result)
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
        calcSpan.finish()

        // Check for unit conversion expression (high priority)
        let convSpan = span.createChild(operationName: "unit_conversion")
        if UnitConverter.shared.isConversionExpression(query) {
            if let result = UnitConverter.shared.convert(query) {
                convSpan.setTag("expression", query)
                convSpan.setTag("result", result)
                results.append(SearchResult(
                    title: result,
                    subtitle: "Conversion",
                    icon: NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "Unit Converter"),
                    category: .conversion,
                    action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result, forType: .string)
                    },
                    score: 2000 // Very high score to ensure conversion is always first
                ))
            }
        } else if lowercasedQuery == "convert" {
            // Show conversion hints when user types "convert"
            convSpan.setTag("showing_hints", true)
            let hints = UnitConverter.shared.getHints()
            for hint in hints {
                results.append(SearchResult(
                    title: hint,
                    subtitle: "Unit Conversion Example",
                    icon: NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "Unit Converter"),
                    category: .conversion,
                    action: { },
                    score: 2000
                ))
            }
        }
        convSpan.finish()

        // Check for time zone conversion (high priority)
        let tzSpan = span.createChild(operationName: "time_zone_conversion")
        let tzResults = TimeZoneConverterService.shared.search(query: query)
        tzSpan.setTag("results", tzResults.count)
        tzSpan.finish()
        results.append(contentsOf: tzResults)

        // Fuzzy search through installed apps
        let appSpan = span.createChild(operationName: "applications")
        appSpan.setTag("total_apps", installedApps.count)
        
        let appResults = installedApps
            .compactMap { app -> (app: InstalledApp, score: Int)? in
                let score = SearchScoreCalculator.shared.calculateScore(
                    query: lowercasedQuery,
                    title: app.name,
                    category: .application
                )
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
                    },
                    score: item.score
                )
            }
        appSpan.setTag("results", appResults.count)
        appSpan.finish()
        results.append(contentsOf: appResults)

        // User commands (actions)
        let cmdSpan = span.createChild(operationName: "user_commands")
        let commandResults = UserCommandsService.shared.search(query: query)
        cmdSpan.setTag("results", commandResults.count)
        cmdSpan.finish()
        results.append(contentsOf: commandResults)

        // Color Picker
        let colorSpan = span.createChild(operationName: "color_picker")
        let colorPickerResults = ColorPickerPlugin.shared.search(query: query)
        colorSpan.setTag("results", colorPickerResults.count)
        colorSpan.finish()
        results.append(contentsOf: colorPickerResults)

        // Contacts
        let contactSpan = span.createChild(operationName: "contacts")
        let contactResults = ContactsService.shared.search(query: query)
        contactSpan.setTag("results", contactResults.count)
        contactSpan.finish()
        results.append(contentsOf: contactResults)

        // Battery info
        let batterySpan = span.createChild(operationName: "battery")
        let batteryResults = BatteryService.shared.search(query: query)
        batterySpan.setTag("results", batteryResults.count)
        batterySpan.finish()
        results.append(contentsOf: batteryResults)

        // System info (storage, system specs)
        let systemInfoSpan = span.createChild(operationName: "system_info")
        let systemInfoResults = SystemInfoService.shared.search(query: query)
        systemInfoSpan.setTag("results", systemInfoResults.count)
        systemInfoSpan.finish()
        results.append(contentsOf: systemInfoResults)
        
        // Network info (IP addresses, WiFi)
        let networkSpan = span.createChild(operationName: "network_info")
        let networkResults = NetworkInfoService.shared.search(query: query)
        networkSpan.setTag("results", networkResults.count)
        networkSpan.finish()
        results.append(contentsOf: networkResults)

        // Clipboard history
        let clipSpan = span.createChild(operationName: "clipboard")
        let clipboardResults = ClipboardManager.shared.search(query: query)
        clipSpan.setTag("results", clipboardResults.count)
        clipSpan.finish()
        results.append(contentsOf: clipboardResults)

        // Search for files using Spotlight
        let fileSpan = span.createChild(operationName: "files")
        let fileSearchQuery: String
        let isFileSpecificSearch = lowercasedQuery.hasPrefix(fileSearchPrefix)

        if isFileSpecificSearch {
            fileSearchQuery = String(query.dropFirst(fileSearchPrefix.count))
            fileSpan.setTag("file_specific", true)
        } else {
            fileSearchQuery = query
        }

        if !fileSearchQuery.isEmpty {
            let fileResults = FileSearchService.shared.searchSync(query: fileSearchQuery, maxResults: 5)
            fileSpan.setTag("results", fileResults.count)
            results.append(contentsOf: fileResults)
        }
        fileSpan.finish()

        // Emojis disabled - users can use Cmd+Ctrl+Space system picker instead
        // let emojiResults = EmojiSearchService.shared.search(query: query)
        // results.append(contentsOf: emojiResults)

        // Global commands (lowest priority)
        let globalSpan = span.createChild(operationName: "global_commands")
        let globalCommandResults = GlobalCommandsService.shared.search(query: query)
        globalSpan.setTag("results", globalCommandResults.count)
        globalSpan.finish()
        results.append(contentsOf: globalCommandResults)

        // Toggles (low priority - below apps)
        let toggleSpan = span.createChild(operationName: "toggles")
        let toggleResults = searchToggles(query: lowercasedQuery)
        toggleSpan.setTag("results", toggleResults.count)
        toggleSpan.finish()
        results.append(contentsOf: toggleResults)

        // Quicklinks - searchable by name, URL, keyword "quicklink"
        let qlSpan = span.createChild(operationName: "quicklinks")
        let quicklinkResults = searchQuicklinks(query: lowercasedQuery)
        qlSpan.setTag("results", quicklinkResults.count)
        qlSpan.finish()
        results.append(contentsOf: quicklinkResults)

        // Settings category - "Add Quicklink" as first item
        if lowercasedQuery.contains("add") || lowercasedQuery.isEmpty {
            let settingsSpan = span.createChild(operationName: "settings")
            let settingsResults = createSettingsResults(query: lowercasedQuery)
            settingsSpan.setTag("results", settingsResults.count)
            settingsSpan.finish()
            results.append(contentsOf: settingsResults)
        }

        // Deduplicate and sort by category
        let dedupSpan = span.createChild(operationName: "deduplicate_sort")
        var finalResults: [SearchResult] = []
        var seenTitles: Set<String> = []
        for result in results {
            if !seenTitles.contains(result.title) {
                seenTitles.insert(result.title)
                finalResults.append(result)
            }
        }
        dedupSpan.setTag("before_dedup", results.count)
        dedupSpan.setTag("after_dedup", finalResults.count)
        dedupSpan.finish()

        // Sort by score (descending), then category (ascending for priority)
        return Array(finalResults.sorted { (a, b) -> Bool in
            if a.score != b.score { return a.score > b.score }
            return a.category < b.category
        }.prefix(10))
    }

    // MARK: - Toggles

    private func searchToggles(query: String) -> [SearchResult] {
        // If query is empty, don't return toggles
        guard !query.isEmpty else { return [] }

        // Search keywords for toggles
        let toggleKeywords = ["caffeinate", "awake", "sleep prevention", "keep awake"]
        let matchesQuery = toggleKeywords.contains { $0.contains(query) } || 
                           query.contains("caffeinate") || 
                           query.contains("awake") ||
                           query.contains("sleep")

        guard matchesQuery else { return [] }

        var results: [SearchResult] = []

        // Caffeinate system - prevents system sleep but allows display to sleep
        let systemScore = SearchScoreCalculator.shared.calculateScore(
            query: query,
            title: "Caffeinate System",
            category: .toggle
        )
        results.append(SearchResult(
            title: "Caffeinate System",
            subtitle: "Prevent system sleep (display can sleep)",
            icon: NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "System Awake"),
            category: .toggle,
            action: { [weak self] in
                self?.awakeService.toggle(mode: .system)
            },
            score: systemScore > 0 ? systemScore : 40,
            isActive: awakeService.isActive(mode: .system)
        ))

        // Caffeinate - prevents both display and system sleep
        let fullScore = SearchScoreCalculator.shared.calculateScore(
            query: query,
            title: "Caffeinate",
            category: .toggle
        )
        results.append(SearchResult(
            title: "Caffeinate",
            subtitle: "Prevent display and system sleep",
            icon: NSImage(systemSymbolName: "sun.max", accessibilityDescription: "Full Awake"),
            category: .toggle,
            action: { [weak self] in
                self?.awakeService.toggle(mode: .full)
            },
            score: fullScore > 0 ? fullScore : 40,
            isActive: awakeService.isActive(mode: .full)
        ))

        return results
    }

    // MARK: - Quicklinks

    private func searchQuicklinks(query: String) -> [SearchResult] {
        // If query is empty, don't return quicklinks
        guard !query.isEmpty else { return [] }

        // If query contains "quicklink" keyword, show all quicklinks
        let showAllQuicklinks = query.lowercased().contains("quicklink")
        
        // Get quicklinks - either filtered by query or all if "quicklink" keyword
        let quicklinks: [Quicklink]
        if showAllQuicklinks {
            quicklinks = quicklinkManager.getAllQuicklinks()
        } else {
            quicklinks = quicklinkManager.searchQuicklinks(query: query)
        }

        return quicklinks.compactMap { quicklink -> SearchResult? in
            let score: Int
            if showAllQuicklinks {
                score = 2000 // High score when showing all quicklinks
            } else {
                // Use the calculator for proper scoring
                score = SearchScoreCalculator.shared.calculateScore(
                    query: query,
                    title: quicklink.name,
                    subtitle: quicklink.url,
                    category: .quicklink,
                    identifier: quicklink.url
                )
            }
            
            guard score > 0 || showAllQuicklinks else { return nil }
            
            return SearchResult(
                title: quicklink.name,
                subtitle: quicklink.url,
                icon: NSImage(systemSymbolName: "link", accessibilityDescription: "Quicklink"),
                category: .quicklink,
                action: { [weak self] in
                    _ = self?.quicklinkManager.openQuicklink(id: quicklink.id)
                },
                score: score
            )
        }
    }

    // MARK: - Settings

    private func createSettingsResults(query: String) -> [SearchResult] {
        var results: [SearchResult] = []

        // "Add Quicklink" - first item in settings
        let addQuicklinkScore = query.isEmpty ? 0 : SearchScoreCalculator.shared.calculateScore(
            query: query,
            title: "Add Quicklink",
            category: .settings
        )
        
        results.append(SearchResult(
            title: "Add Quicklink",
            subtitle: "Create a new quicklink",
            icon: NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Add Quicklink"),
            category: .settings,
            action: {
                NotificationCenter.default.post(name: .showAddQuicklink, object: nil)
            },
            score: addQuicklinkScore
        ))

        return results
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
// test

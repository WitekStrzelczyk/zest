import AppKit
import Foundation

@MainActor
final class CommandPaletteController {
    static let shared = CommandPaletteController()
    private let maxDisplayedResults = 80
    private let llmDebounceNanoseconds: UInt64 = 200_000_000

    private let stateStore = CommandPaletteStateStore.shared
    private var fileSearchTask: Task<Void, Never>?
    private var llmTask: Task<Void, Never>?
    private var currentQuery: String = ""
    private var baseResults: [SearchResult] = []
    private var intentResults: [SearchResult] = []

    private init() {}

    func handleQuery(_ query: String) {
        if query == currentQuery {
            return
        }
        currentQuery = query
        fileSearchTask?.cancel()
        llmTask?.cancel()
        SearchEngine.shared.cancelCurrentSearch()

        let normalizedQuery = normalizeQuery(query)
        stateStore.updateQuery(normalizedQuery, isLLMMode: false)

        if normalizedQuery.isEmpty {
            baseResults = []
            intentResults = []
            stateStore.updateResults([])
            stateStore.clearIntent()
            return
        }

        baseResults = []
        intentResults = []
        stateStore.clearIntent()
        runStandardSearch(normalizedQuery)
        runLLMAugmentation(originalQuery: query, normalizedQuery: normalizedQuery)
    }

    private func runLLMAugmentation(originalQuery: String, normalizedQuery: String) {
        print("🧠 handleLLMMode called with: \(normalizedQuery)")
        llmTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: llmDebounceNanoseconds)
            guard !Task.isCancelled, currentQuery == originalQuery else { return }
            print("🧠 Calling parseWithLLM with: \(normalizedQuery)")
            guard let toolCall = await LLMToolCallingService.shared.parseWithLLM(input: normalizedQuery) else {
                print("🧠 No toolCall returned from LLM")
                await MainActor.run {
                    guard self.currentQuery == originalQuery else { return }
                    self.intentResults = []
                    self.publishMergedResults()
                    self.stateStore.clearIntent()
                }
                return
            }
            print("🧠 Got intent toolCall: \(describe(toolCall))")

            await MainActor.run {
                guard self.currentQuery == originalQuery else { return }
                self.stateStore.setIntentContext(from: toolCall, rawQuery: normalizedQuery)
            }

            let baseResults: [SearchResult]
            switch toolCall.parameters {
            case .findFiles(let params):
                let ext = params.fileExtension ?? "nil"
                let modified = params.modifiedWithin.map(String.init) ?? "nil"
                print("🧠 LLM find_files: query='\(params.query)' ext='\(ext)' modified='\(modified)'")
                let rawIntentResults = await Task.detached(priority: .utility) {
                    CommandPaletteController.searchFilesFromIntent(params)
                }.value
                baseResults = prioritizeIntentFileResults(rawIntentResults)
            case .createCalendarEvent(let params):
                baseResults = [syntheticCalendarResult(params: params)]
            case .convertUnits(let params):
                baseResults = [syntheticUnitConversionResult(params: params)]
            case .translate(let params):
                baseResults = await syntheticTranslationResult(params: params)
            }

            let intentResults = enrichResults(baseResults: baseResults, intent: toolCall)

            await MainActor.run {
                guard self.currentQuery == originalQuery else { return }
                self.intentResults = intentResults
                self.publishMergedResults()
            }
        }
    }

    private func runStandardSearch(_ query: String) {
        let fastResults = SearchEngine.shared.searchFast(query: query)
        baseResults = fastResults
        publishMergedResults()

        fileSearchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled, currentQuery == query else { return }

            let fileResults = await Task.detached(priority: .utility) {
                SearchEngine.shared.searchFiles(query: query)
            }.value

            guard currentQuery == query else { return }

            let combined = mergeAndRank(base: fastResults, extras: fileResults, limit: maxDisplayedResults)
            baseResults = combined
            publishMergedResults()
        }
    }

    private nonisolated static func searchFilesFromIntent(_ params: FindFilesParams) -> [SearchResult] {
        print("🧠 File intent search started")
        var results: [SearchResult]

        if params.query == "*", let hours = params.modifiedWithin {
            results = recentFileResults(modifiedWithin: hours, fileExtension: params.fileExtension, maxResults: 80)
        } else {
            let query = params.query == "*" ? "" : params.query
            results = FileSearchService.shared.searchSync(query: query, maxResults: 80)
        }
        print("🧠 File intent search raw results: \(results.count)")

        if let ext = params.fileExtension?.lowercased() {
            let before = results.count
            results = results.filter { result in
                guard let path = result.filePath?.lowercased() else { return false }
                return path.hasSuffix(".\(ext)")
            }
            print("🧠 File intent extension filter '.\(ext)': \(before) -> \(results.count)")
        }

        if let hours = params.modifiedWithin {
            let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
            let before = results.count
            results = results.filter { result in
                guard let path = result.filePath else { return false }
                let attrs = try? FileManager.default.attributesOfItem(atPath: path)
                guard let modified = attrs?[.modificationDate] as? Date else { return false }
                return modified >= cutoff
            }
            print("🧠 File intent modifiedWithin \(hours)h filter: \(before) -> \(results.count)")
        }

        print("🧠 File intent search final results: \(results.count)")
        return results
    }

    private nonisolated static func fileModificationDate(for path: String?) -> Date {
        guard let path else { return .distantPast }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.modificationDate] as? Date) ?? .distantPast
    }

    private nonisolated static func recentFileResults(
        modifiedWithin hours: Int,
        fileExtension: String?,
        maxResults: Int
    ) -> [SearchResult] {
        var predicate: String
        if hours >= 24 {
            let days = max(1, hours / 24)
            predicate = "kMDItemFSContentChangeDate >= $time.today(-\(days))"
        } else {
            predicate = "kMDItemFSContentChangeDate >= $time.now(-\(hours * 3600))"
        }
        if let ext = fileExtension?.lowercased(), !ext.isEmpty {
            predicate += " && kMDItemFSExtension == '\(ext)'"
        }
        print("🧠 Spotlight recent-files query: \(predicate)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", NSHomeDirectory(), predicate]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("🧠 Spotlight recent-files query failed to run: \(error)")
            return []
        }

        print("🧠 Spotlight recent-files exit status: \(process.terminationStatus)")

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let rawOutput = String(data: data, encoding: .utf8) ?? ""
        print("🧠 Spotlight raw output length: \(rawOutput.count) chars")
        print("🧠 Spotlight raw output first 200: \(String(rawOutput.prefix(200)))")

        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let paths = output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.hasSuffix(".app") && !$0.contains("/.") }
            .prefix(maxResults)

        print("🧠 Spotlight filtered paths count: \(paths.count)")

        let results = paths.map { path in
            let url = URL(fileURLWithPath: path)
            return SearchResult(
                title: url.lastPathComponent,
                subtitle: "File",
                icon: NSWorkspace.shared.icon(forFile: path),
                category: .file,
                action: { NSWorkspace.shared.open(URL(fileURLWithPath: path)) },
                revealAction: { NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "") },
                filePath: path
            )
        }

        if !results.isEmpty {
            return results
        }

        print("🧠 Spotlight returned 0 results, falling back to filesystem scan")
        return fallbackRecentFileScan(modifiedWithin: hours, fileExtension: fileExtension, maxResults: maxResults)
    }

    private nonisolated static func fallbackRecentFileScan(
        modifiedWithin hours: Int,
        fileExtension: String?,
        maxResults: Int
    ) -> [SearchResult] {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let ext = fileExtension?.lowercased()

        var collected: [(path: String, modified: Date)] = []
        var visited = 0
        let maxVisited = 50000
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .isHiddenKey]

        guard let enumerator = fm.enumerator(
            at: home,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        while let fileURL = enumerator.nextObject() as? URL {
            visited += 1
            if visited > maxVisited { break }
            if collected.count >= maxResults * 3 { break }
            if fileURL.path.hasSuffix(".app") || fileURL.path.contains("/.") { continue }
            if let ext, fileURL.pathExtension.lowercased() != ext { continue }

            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  values.isHidden != true,
                  let modified = values.contentModificationDate else { continue }

            if modified >= cutoff {
                collected.append((fileURL.path, modified))
            }
        }

        collected.sort { $0.modified > $1.modified }

        print("🧠 Fallback filesystem scan visited \(visited) entries, matched \(collected.count) files")

        return collected.prefix(maxResults).map { entry in
            let path = entry.path
            let url = URL(fileURLWithPath: path)
            return SearchResult(
                title: url.lastPathComponent,
                subtitle: "File",
                icon: NSWorkspace.shared.icon(forFile: path),
                category: .file,
                action: { NSWorkspace.shared.open(URL(fileURLWithPath: path)) },
                revealAction: { NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "") },
                filePath: path
            )
        }
    }

    private func mergeAndRank(base: [SearchResult], extras: [SearchResult], limit: Int) -> [SearchResult] {
        var merged = base
        for result in extras {
            if let index = merged.firstIndex(where: { $0.title == result.title && $0.subtitle == result.subtitle }) {
                if SearchResult.rankedBefore(result, merged[index]) {
                    merged[index] = result
                }
            } else {
                merged.append(result)
            }
        }
        merged.sort(by: SearchResult.rankedBefore)
        return Array(merged.prefix(limit))
    }

    private func publishMergedResults() {
        let merged = mergeAndRank(base: baseResults, extras: intentResults, limit: maxDisplayedResults)
        stateStore.updateResults(merged)
    }

    private func prioritizeIntentFileResults(_ results: [SearchResult]) -> [SearchResult] {
        let sorted = results.sorted { a, b in
            let aDate = CommandPaletteController.fileModificationDate(for: a.filePath)
            let bDate = CommandPaletteController.fileModificationDate(for: b.filePath)
            if aDate != bDate { return aDate > bDate }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }

        return sorted.enumerated().map { index, result in
            SearchResult(
                title: result.title,
                subtitle: result.subtitle,
                icon: result.icon,
                category: result.category,
                action: result.action,
                revealAction: result.revealAction,
                filePath: result.filePath,
                score: 10000 - index,
                isActive: result.isActive,
                tintColor: result.tintColor,
                trailingIcon: result.trailingIcon,
                source: .tool
            )
        }
    }

    private func normalizeQuery(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("=") {
            return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func syntheticCalendarResult(params: CreateCalendarEventParams) -> SearchResult {
        let title = params.title.isEmpty ? "Create calendar event" : params.title
        var details: [String] = []
        if let date = params.date, !date.isEmpty { details.append("Date: \(date)") }
        if let time = params.time, !time.isEmpty { details.append("Time: \(time)") }
        if let location = params.location, !location.isEmpty { details.append("Location: \(location)") }
        if let contact = params.contact, !contact.isEmpty { details.append("Contact: \(contact)") }
        let subtitle = details.isEmpty ? "Calendar Event" : details.joined(separator: " • ")

        return SearchResult(
            title: title,
            subtitle: subtitle,
            icon: NSImage(systemSymbolName: "calendar.badge.plus", accessibilityDescription: "Calendar"),
            category: .calendar,
            action: {
                Task {
                    _ = await LLMToolExecutor.shared.execute(
                        LLMToolCall.createCalendarEvent(
                            title: title,
                            date: params.date,
                            time: params.time,
                            location: params.location,
                            contact: params.contact,
                            confidence: 0.9
                        )
                    )
                }
            },
            score: 1000,
            source: .tool
        )
    }

    private func syntheticUnitConversionResult(params: UnitConversionParams) -> SearchResult {
        // Try to get conversion result
        let conversionString = "\(params.value) \(params.fromUnit) to \(params.toUnit)"
        let result = UnitConverter.shared.convert(conversionString)

        let title = result ?? "Convert \(params.value) \(params.fromUnit) to \(params.toUnit)"
        let subtitle = "Unit Conversion"

        return SearchResult(
            title: title,
            subtitle: subtitle,
            icon: NSImage(systemSymbolName: "ruler", accessibilityDescription: "Unit Converter"),
            category: .action,
            action: {
                Task {
                    _ = await LLMToolExecutor.shared.execute(
                        LLMToolCall.convertUnits(
                            value: params.value,
                            fromUnit: params.fromUnit,
                            toUnit: params.toUnit,
                            category: params.category,
                            confidence: 0.9
                        )
                    )
                }
            },
            score: 1000,
            source: .tool
        )
    }

    private func syntheticTranslationResult(params: TranslationParams) async -> [SearchResult] {
        // Execute translation immediately
        let result = await LLMToolExecutor.shared.execute(
            LLMToolCall.translate(
                text: params.text,
                targetLanguage: params.targetLanguage,
                sourceLanguage: params.sourceLanguage,
                confidence: 0.9
            )
        )

        switch result {
        case .success(let executionResult):
            // Show the translated text as the main result
            let translatedText = executionResult.message
            let sourceLang = params.sourceLanguage ?? "auto"

            return [SearchResult(
                title: translatedText,
                subtitle: "Translated from \(sourceLang) to \(params.targetLanguage.uppercased()) • Click to copy",
                icon: NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Translate"),
                category: .action,
                action: {
                    // Copy to clipboard when user clicks
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(translatedText, forType: .string)
                },
                score: 1000,
                source: .tool
            )]
        case .failure(let error):
            // Show error result
            let errorMessage = (error as? ToolExecutionError)?.errorDescription ?? error.localizedDescription
            return [SearchResult(
                title: "Translation failed",
                subtitle: errorMessage,
                icon: NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error"),
                category: .action,
                action: {},
                score: 1000,
                source: .tool
            )]
        }
    }

    private func enrichResults(baseResults: [SearchResult], intent: LLMToolCall) -> [SearchResult] {
        var results = baseResults

        if case .createCalendarEvent(let params) = intent.parameters {
            if let contact = params.contact, !contact.isEmpty {
                let contacts = ContactsService.shared.search(query: contact).prefix(3)
                results.append(contentsOf: contacts)
            }

            if let location = params.location, !location.isEmpty {
                let mapResult = SearchResult(
                    title: "Search in Maps: \(location)",
                    subtitle: "Location Context",
                    icon: NSImage(systemSymbolName: "map", accessibilityDescription: "Maps"),
                    category: .action,
                    action: {
                        let encoded = location
                            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
                        if let url = URL(string: "maps://?q=\(encoded)") {
                            NSWorkspace.shared.open(url)
                        }
                    },
                    score: 900,
                    source: .tool
                )
                results.append(mapResult)
            }
        }

        // De-duplicate by title+subtitle while preserving order.
        var seen: Set<String> = []
        return results.filter { result in
            let key = "\(result.title)|\(result.subtitle)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func describe(_ toolCall: LLMToolCall) -> String {
        switch toolCall.parameters {
        case .createCalendarEvent(let params):
            let date = params.date ?? "nil"
            let time = params.time ?? "nil"
            let loc = params.location ?? "nil"
            let conf = String(format: "%.2f", toolCall.confidence)
            return "create_event(t:\(params.title), d:\(date), tm:\(time), l:\(loc), c:\(conf))"
        case .findFiles(let params):
            let ext = params.fileExtension ?? "nil"
            let modified = params.modifiedWithin.map(String.init) ?? "nil"
            let conf = String(format: "%.2f", toolCall.confidence)
            return "find(q:\(params.query), in:\(params.searchInContent), ext:\(ext), mod:\(modified), c:\(conf))"
        case .convertUnits(let params):
            let category = params.category ?? "nil"
            let conf = String(format: "%.2f", toolCall.confidence)
            return "convert(v:\(params.value), f:\(params.fromUnit), t:\(params.toUnit), cat:\(category), c:\(conf))"
        case .translate(let params):
            let source = params.sourceLanguage ?? "auto"
            let conf = String(format: "%.2f", toolCall.confidence)
            let text = String(params.text.prefix(20))
            return "translate(\(text)... src:\(source) tgt:\(params.targetLanguage) c:\(conf))"
        }
    }
}

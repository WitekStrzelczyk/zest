import AppKit
import EventKit
import Foundation
import os.log

// MARK: - Execution Result

/// Result of executing a tool call
struct ToolExecutionResult: Equatable {
    let success: Bool
    let message: String
    let details: String?

    static func success(_ message: String, details: String? = nil) -> ToolExecutionResult {
        ToolExecutionResult(success: true, message: message, details: details)
    }

    static func failure(_ message: String, details: String? = nil) -> ToolExecutionResult {
        ToolExecutionResult(success: false, message: message, details: details)
    }
}

// MARK: - Tool Execution Error

/// Errors that can occur during tool execution
enum ToolExecutionError: Error, LocalizedError {
    case calendarAccessDenied
    case eventCreationFailed(String)
    case invalidParameters(String)
    case searchFailed(String)
    case conversionFailed(String)
    case translationNotAvailable(String)
    case translationFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied:
            return "Calendar access was denied"
        case .eventCreationFailed(let reason):
            return "Failed to create event: \(reason)"
        case .invalidParameters(let reason):
            return "Invalid parameters: \(reason)"
        case .searchFailed(let reason):
            return "Search failed: \(reason)"
        case .conversionFailed(let reason):
            return "Conversion failed: \(reason)"
        case .translationNotAvailable(let reason):
            return "Translation not available: \(reason)"
        case .translationFailed(let reason):
            return "Translation failed: \(reason)"
        case .unknown(let reason):
            return "Unknown error: \(reason)"
        }
    }
}

// MARK: - LLM Tool Executor

/// Executes LLM tool calls by connecting to actual services
final class LLMToolExecutor {
    // MARK: - Singleton

    static let shared = LLMToolExecutor()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.zest.app", category: "LLMToolExecutor")
    private let dateTimeParser = DateTimeParser.shared
    private let fileSearchService = FileSearchService.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Execute a tool call
    /// - Parameter toolCall: The parsed tool call
    /// - Returns: Result with success message or error
    func execute(_ toolCall: LLMToolCall) async -> Result<ToolExecutionResult, Error> {
        logger.debug("Executing tool: \(toolCall.tool.rawValue)")

        switch toolCall.parameters {
        case .createCalendarEvent(let params):
            return await executeCalendarEventCreation(params: params)
        case .findFiles(let params):
            return await executeFileSearch(params: params)
        case .convertUnits(let params):
            return executeUnitConversion(params: params)
        case .translate(let params):
            return await executeTranslation(params: params)
        }
    }

    // MARK: - Translation

    private func executeTranslation(params: TranslationParams) async -> Result<ToolExecutionResult, Error> {
        logger.debug("Translating text")
        logger.debug("  Text: \(params.text)")
        logger.debug("  Source: \(params.sourceLanguage ?? "auto")")
        logger.debug("  Target: \(params.targetLanguage)")

        // Check macOS version - Translation requires macOS 26+
        if #available(macOS 26.0, *) {
            do {
                let service = TranslationService.shared
                let result = try await service.translate(
                    text: params.text,
                    targetLanguage: params.targetLanguage,
                    sourceLanguage: params.sourceLanguage
                )

                // Return the translation result (user will copy by clicking)
                let sourceLang = result.detectedSourceLanguage ?? params.sourceLanguage ?? "auto"
                let message = result.translatedText
                let details = "Translated from \(sourceLang) to \(params.targetLanguage). Click to copy."

                logger.info("Translation completed: \(params.text) -> \(result.translatedText)")

                return .success(ToolExecutionResult.success(message, details: details))
            } catch {
                logger.error("Translation failed: \(error.localizedDescription)")
                return .failure(ToolExecutionError.translationFailed(error.localizedDescription))
            }
        } else {
            return .failure(ToolExecutionError.translationNotAvailable("Translation requires macOS 26 or later (Sequoia)"))
        }
    }

    // MARK: - Calendar Event Creation

    private func executeCalendarEventCreation(params: CreateCalendarEventParams) async -> Result<ToolExecutionResult, Error> {
        print("🚀 LLMToolExecutor: Creating calendar event")
        print("   Title: \(params.title)")
        print("   Date: \(params.date ?? "nil")")
        print("   Time: \(params.time ?? "nil")")
        print("   Location: \(params.location ?? "nil")")
        print("   Contact: \(params.contact ?? "nil")")

        // Request calendar access if needed
        let calendarService = CalendarService.shared
        let hasAccess = await calendarService.requestCalendarAccess()

        guard hasAccess else {
            print("❌ Calendar access denied!")
            return .failure(ToolExecutionError.calendarAccessDenied)
        }

        // Parse date
        let date: Date
        if let dateString = params.date {
            guard let parsedDate = dateTimeParser.parseDate(dateString) else {
                print("❌ Could not parse date: \(dateString)")
                return .failure(ToolExecutionError.invalidParameters("Could not parse date: \(dateString)"))
            }
            date = parsedDate
            print("📅 Parsed date: \(dateString) -> \(parsedDate)")
        } else {
            // Default to tomorrow
            date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            print("📅 Using default date (tomorrow): \(date)")
        }

        // Parse time
        let timeComponents = params.time.flatMap { dateTimeParser.parseTime($0) }
        if let tc = timeComponents {
            print("⏰ Parsed time: \(params.time ?? "") -> hour:\(tc.hour), minute:\(tc.minute)")
        } else {
            print("⏰ No time parsed, will use default (9:00 AM)")
        }

        // Combine date and time
        let startDate = dateTimeParser.combine(date: date, withTime: timeComponents)
        print("📅 Final start date/time: \(startDate)")

        // Check if date is in the past
        let now = Date()
        let isPastEvent = startDate < now

        if isPastEvent {
            print("⚠️ WARNING: Event start date is in the past!")
            print("   Start date: \(startDate)")
            print("   Current time: \(now)")
        }

        // Calculate end date (default 1 hour)
        let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate.addingTimeInterval(3600)
        print("📅 End date/time: \(endDate)")

        // Create the event
        do {
            let event = try await calendarService.createEvent(
                title: params.title,
                startDate: startDate,
                endDate: endDate,
                location: params.location,
                notes: params.contact.map { "Contact: \($0)" }
            )

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            let calendarName = event.calendar?.title ?? "Unknown"
            let message = "Created event: \(event.title ?? params.title)"

            var details = "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))\nCalendar: \(calendarName)"

            // Add warning if event is in the past
            if isPastEvent {
                details += "\n\n⚠️ Warning: This event is in the past!"
            }

            print("✅ LLMToolExecutor: Successfully created event '\(event.title ?? "Untitled")' in calendar: \(calendarName)")

            return .success(ToolExecutionResult.success(message, details: details))
        } catch {
            logger.error("Failed to create calendar event: \(error.localizedDescription)")
            return .failure(ToolExecutionError.eventCreationFailed(error.localizedDescription))
        }
    }

    // MARK: - File Search

    private func executeFileSearch(params: FindFilesParams) async -> Result<ToolExecutionResult, Error> {
        print("🔍 LLMToolExecutor: Executing file search")
        print("   Query: \(params.query)")
        print("   Search in content: \(params.searchInContent)")
        print("   Extension: \(params.fileExtension ?? "nil")")
        print("   Modified within: \(params.modifiedWithin?.description ?? "nil") hours")

        var results: [SearchResult] = []

        // Handle wildcard query with modifiedWithin - search for recently modified files
        if params.query == "*" && params.modifiedWithin != nil {
            print("🔍 Using mdfind for recently modified files")
            results = searchRecentlyModifiedFiles(hours: params.modifiedWithin!, extension: params.fileExtension)
        } else {
            // Normal search
            results = fileSearchService.searchSync(query: params.query, maxResults: 20)
            print("🔍 Initial results: \(results.count) files")

            // Apply extension filter if specified
            if let ext = params.fileExtension {
                results = results.filter { result in
                    result.filePath?.lowercased().hasSuffix(".\(ext.lowercased())") ?? false
                }
                print("🔍 After extension filter: \(results.count) files")
            }

            // Apply modified within filter if specified
            if let hours = params.modifiedWithin {
                let cutoffDate = Date().addingTimeInterval(-Double(hours) * 3600)
                results = results.filter { result in
                    guard let filePath = result.filePath else { return false }
                    let attributes = try? FileManager.default.attributesOfItem(atPath: filePath)
                    let modDate = attributes?[.modificationDate] as? Date
                    return modDate.map { $0 > cutoffDate } ?? false
                }
                print("🔍 After modified filter: \(results.count) files")
            }
        }

        // Build result message
        let count = results.count
        let queryDisplay = params.query == "*" ? "all files" : "'\(params.query)'"
        let message = count == 0
            ? "No files found matching \(queryDisplay)"
            : "Found \(count) file\(count == 1 ? "" : "s")"

        // Build details with file names
        let details: String?
        if count > 0 {
            let fileList = results.prefix(10).map { result -> String in
                let fileName = URL(fileURLWithPath: result.filePath ?? "").lastPathComponent
                return "• \(fileName)"
            }.joined(separator: "\n")

            let more = count > 10 ? "\n... and \(count - 10) more" : ""
            details = fileList + more
        } else {
            details = nil
        }

        print("✅ File search completed: \(count) results")

        // If files were found, open the first one in Finder
        if let firstResult = results.first, let filePath = firstResult.filePath {
            NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
        }

        return .success(ToolExecutionResult.success(message, details: details))
    }

    // MARK: - Recently Modified Files Search

    /// Search for recently modified files using mdfind with date predicate
    private func searchRecentlyModifiedFiles(hours: Int, extension: String?) -> [SearchResult] {
        // Build mdfind query for recently modified files
        // Use $time.today(-N) for days or calculate for hours
        var query: String

        if hours >= 24 {
            // Use days for cleaner syntax
            let days = hours / 24
            query = "kMDItemFSContentChangeDate >= $time.today(-\(days))"
        } else {
            // For hours, use $time.now with offset
            query = "kMDItemFSContentChangeDate >= $time.now(-\(hours * 3600))"
        }

        // Add extension filter if specified
        if let ext = `extension` {
            query += " && kMDItemFSExtension == '\(ext)'"
        }

        print("🔍 mdfind query: \(query)")

        // Execute mdfind
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", NSHomeDirectory(), query]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        var paths: [String] = []

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                paths = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                print("🔍 mdfind returned \(paths.count) paths")
            }
        } catch {
            print("❌ mdfind failed: \(error)")
        }

        // Convert paths to SearchResult
        var results: [SearchResult] = []
        for path in paths.prefix(20) {
            // Skip hidden directories
            if path.contains("/.") { continue }
            // Skip .app bundles
            if path.hasSuffix(".app") { continue }

            let url = URL(fileURLWithPath: path)
            let name = url.lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: path)

            results.append(SearchResult(
                title: name,
                subtitle: "Recently modified",
                icon: icon,
                category: .file,
                action: { [path] in
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                },
                revealAction: { [path] in
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                },
                filePath: path
            ))
        }

        return results
    }

    // MARK: - Unit Conversion

    private func executeUnitConversion(params: UnitConversionParams) -> Result<ToolExecutionResult, Error> {
        print("📐 LLMToolExecutor: Converting units")
        print("   Value: \(params.value)")
        print("   From: \(params.fromUnit)")
        print("   To: \(params.toUnit)")
        print("   Category: \(params.category ?? "auto")")

        // Build a conversion string for the UnitConverter
        let conversionString = "\(params.value) \(params.fromUnit) to \(params.toUnit)"

        // Use the existing UnitConverter service
        guard let result = UnitConverter.shared.convert(conversionString) else {
            return .failure(ToolExecutionError.conversionFailed(
                "Could not convert \(params.fromUnit) to \(params.toUnit)"
            ))
        }

        let message = result

        // Extract just the numeric value for clipboard
        // Result format is like "62.14 miles" - extract the number
        let numericValue = result.components(separatedBy: " ").first ?? result

        // Copy result to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(numericValue, forType: .string)

        let details = "Result copied to clipboard"

        print("✅ Unit conversion completed: \(params.value) \(params.fromUnit) = \(result)")

        return .success(ToolExecutionResult.success(message, details: details))
    }
}

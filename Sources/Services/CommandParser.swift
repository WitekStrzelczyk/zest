import Foundation
import NaturalLanguage

/// Native command parser using Apple's frameworks (NSDataDetector, NLTagger, keyword matching)
/// for blazing-fast command parsing in milliseconds
final class CommandParser: Sendable {
    // MARK: - Keyword Sets

    /// Keywords for SearchFiles intent
    private let searchFilesKeywords: Set<String> = [
        "files", "file", "find", "search", "pdf", "dmg", "images", "documents",
        "documents", "folder", "folders", "photo", "photos", "picture", "pictures",
        "zip", "app", "movie", "music", "audio", "video", "document",
        // Add these:
        "modified", "created", "downloaded", "recent", "new",
    ]

    /// Keywords for CreateEvent intent
    private let createEventKeywords: Set<String> = [
        "meeting", "event", "calendar", "schedule", "appointment", "call",
        "meetings", "events", "scheduled", "scheduling",
    ]

    /// Keywords for ConvertUnits intent
    private let convertUnitsKeywords: Set<String> = [
        "convert", "conversion", "miles", "km", "kilometer", "meters", "meter",
        "celsius", "fahrenheit", "kelvin", "pounds", "kg", "kilogram", "grams",
        "gallons", "liters", "inches", "feet", "yard", "miles", "mile",
    ]

    /// Keywords for Translate intent
    private let translateKeywords: Set<String> = [
        "translate", "translation", "translating",
    ]

    /// File extensions to detect (minimum 2 characters to avoid false positives)
    private let fileExtensions: Set<String> = [
        "pdf", "txt", "md", "markdown", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "csv", "json", "xml", "png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp",
        "zip", "tar", "gz", "rar", "7z", "dmg", "iso", "pkg",
        "mp3", "mp4", "mov", "avi", "mkv", "wav", "flac", "aac",
        "log", "swift", "py", "js", "ts", "html", "css", "java", "c", "cpp", "h",
        "rtf", "pages", "numbers", "keynote",
    ]

    /// Known units for conversion detection
    private let knownUnits: Set<String> = [
        // Length
        "km", "kilometer", "kilometers", "m", "meter", "meters", "cm", "centimeter", "centimeters",
        "mm", "millimeter", "millimeters", "mi", "mile", "miles", "ft", "foot", "feet",
        "yd", "yard", "yards", "in", "inch", "inches",
        // Weight
        "kg", "kilogram", "kilograms", "g", "gram", "grams", "mg", "milligram", "milligrams",
        "lb", "lbs", "pound", "pounds", "oz", "ounce", "ounces",
        // Temperature
        "c", "celsius", "centigrade", "f", "fahrenheit", "k", "kelvin",
        // Volume
        "l", "liter", "liters", "litre", "litres", "ml", "milliliter", "milliliters",
        "gal", "gallon", "gallons", "qt", "quart", "quarts", "pt", "pint", "cups", "cup",
        // Data
        "kb", "mb", "gb", "tb", "byte", "bytes",
    ]

    /// Common languages for translation
    private let languages: Set<String> = [
        "english", "spanish", "french", "german", "italian", "portuguese", "russian",
        "chinese", "japanese", "korean", "arabic", "hindi", "dutch", "swedish",
        "polish", "turkish", "vietnamese", "thai", "indonesian", "greek", "hebrew",
        "czech", "romanian", "hungarian", "ukrainian", "catalan", "finnish", "norwegian",
        "danish", "bulgarian", "croatian", "serbian", "slovenian", "slovak",
    ]

    // MARK: - Public API

    /// Parse user input and extract the intent with parameters
    /// - Parameter input: Raw user input string
    /// - Returns: LLMToolCall if intent recognized, nil otherwise
    func parse(_ input: String) -> LLMToolCall? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowercased = trimmed.lowercased()

        // Try each intent classifier in order of specificity
        // Check for translation first (most specific keyword pattern)
        if let result = classifyTranslate(input: lowercased, original: trimmed) {
            return result
        }

        // Check for unit conversion (has numeric values + units)
        if let result = classifyConvertUnits(input: lowercased, original: trimmed) {
            return result
        }

        // Check for calendar event
        if let result = classifyCreateEvent(input: lowercased, original: trimmed) {
            return result
        }

        // Check for file search
        if let result = classifySearchFiles(input: lowercased, original: trimmed) {
            return result
        }

        return nil
    }

    // MARK: - Stage 3: Intent Classification

    /// Classify as Translate intent
    private func classifyTranslate(input: String, original: String) -> LLMToolCall? {
        // Check for translate keywords
        let hasTranslateKeyword = translateKeywords.contains { input.contains($0) }
        guard hasTranslateKeyword else { return nil }

        // Extract text and language
        let params = extractTranslationParams(input: input, original: original)

        guard !params.text.isEmpty, !params.targetLanguage.isEmpty else { return nil }

        return LLMToolCall.translate(
            text: params.text,
            targetLanguage: params.targetLanguage,
            sourceLanguage: params.sourceLanguage,
            confidence: 0.9
        )
    }

    /// Classify as ConvertUnits intent
    private func classifyConvertUnits(input: String, original: String) -> LLMToolCall? {
        // Check for convert keyword OR presence of two known units with a number
        let hasConvertKeyword = input.contains("convert") || input.contains("conversion")

        // Try to extract conversion params
        guard let params = extractUnitConversionParams(input: input, original: original) else {
            return nil
        }

        // If no convert keyword, only return if we have clear conversion pattern
        if !hasConvertKeyword {
            // Check for "X unit to unit" pattern
            let pattern = #"(\d+\.?\d*)\s+(\w+)\s+(?:to|in)\s+(\w+)"#
            guard let _ = input.range(of: pattern, options: .regularExpression) else {
                return nil
            }
        }

        return LLMToolCall.convertUnits(
            value: params.value,
            fromUnit: params.fromUnit,
            toUnit: params.toUnit,
            category: params.category,
            confidence: 0.9
        )
    }

    /// Classify as CreateEvent intent
    private func classifyCreateEvent(input: String, original: String) -> LLMToolCall? {
        // Check for event keywords
        let hasEventKeyword = createEventKeywords.contains { input.contains($0) }
        guard hasEventKeyword else { return nil }

        // Extract parameters
        let params = extractEventParams(input: input, original: original)

        // Must have at least a title or date/time
        guard !params.title.isEmpty || params.date != nil || params.time != nil else {
            return nil
        }

        return LLMToolCall.createCalendarEvent(
            title: params.title,
            date: params.date,
            time: params.time,
            location: params.location,
            contact: params.contact,
            confidence: 0.9
        )
    }

    /// Classify as SearchFiles intent
    private func classifySearchFiles(input: String, original: String) -> LLMToolCall? {
        // Check for file search keywords OR file extension
        let hasSearchKeyword = searchFilesKeywords.contains { input.contains($0) }

        // Check for file extension - require dot prefix or word boundary
        var hasFileExtension = false
        for ext in fileExtensions {
            let pattern = #"(?:^|\s|\.)\#(ext)(?:\s|$)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if regex.firstMatch(in: input, range: NSRange(input.startIndex..<input.endIndex, in: input)) != nil {
                    hasFileExtension = true
                    break
                }
            }
        }

        guard hasSearchKeyword || hasFileExtension else { return nil }

        // Extract parameters
        let params = extractFileSearchParams(input: input, original: original)

        return LLMToolCall.findFiles(
            query: params.query,
            searchInContent: params.searchInContent,
            fileExtension: params.fileExtension,
            modifiedWithin: params.modifiedWithin,
            confidence: 0.9
        )
    }

    // MARK: - Stage 4: Parameter Extraction

    // MARK: Translation Parameters

    private struct TranslationExtractResult {
        let text: String
        let targetLanguage: String
        let sourceLanguage: String?
    }

    private func extractTranslationParams(input: String, original: String) -> TranslationExtractResult {
        var text = ""
        var targetLanguage = ""
        var sourceLanguage: String?

        // Pattern: "translate X to Y" or "translate X from Y to Z"
        // Also: "translation to Y" or "translate to Y"
        let patterns = [
            #"translate\s+(.+?)\s+to\s+(\w+)"#,
            #"translate\s+(.+?)\s+from\s+(\w+)\s+to\s+(\w+)"#,
            #"translation\s+to\s+(\w+)"#,
            #"translate\s+to\s+(\w+)"#,
        ]

        // Try pattern matches
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(original.startIndex..<original.endIndex, in: original)
                if let match = regex.firstMatch(in: original, options: [], range: range) {
                    if match.numberOfRanges == 3 {
                        // "translate X to Y" or "translation to Y"
                        if let textRange = Range(match.range(at: 1), in: original),
                           let langRange = Range(match.range(at: 2), in: original)
                        {
                            text = String(original[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            targetLanguage = String(original[langRange]).lowercased()
                        }
                    } else if match.numberOfRanges == 4 {
                        // "translate X from Y to Z"
                        if let textRange = Range(match.range(at: 1), in: original),
                           let srcRange = Range(match.range(at: 2), in: original),
                           let tgtRange = Range(match.range(at: 3), in: original)
                        {
                            text = String(original[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            sourceLanguage = String(original[srcRange]).lowercased()
                            targetLanguage = String(original[tgtRange]).lowercased()
                        }
                    }
                    break
                }
            }
        }

        // Fallback: find any language in the input
        if targetLanguage.isEmpty {
            for lang in languages {
                if input.contains(lang) {
                    targetLanguage = lang
                    break
                }
            }
        }

        // If still no text, extract everything before "to" or "in"
        if text.isEmpty {
            let toPattern = #".+?\s+(?:to|in)\s+\w+$"#
            if let regex = try? NSRegularExpression(pattern: toPattern, options: .caseInsensitive) {
                let range = NSRange(original.startIndex..<original.endIndex, in: original)
                if let match = regex.firstMatch(in: original, options: [], range: range) {
                    let beforeRange = Range(match.range(at: 0), in: original)
                    if let before = beforeRange {
                        let matched = String(original[before])
                        // Remove the "to language" part
                        let removePattern = #"\s+(?:to|in)\s+\w+$"#
                        if let removeRegex = try? NSRegularExpression(
                            pattern: removePattern,
                            options: .caseInsensitive
                        ) {
                            let removeRange = NSRange(matched.startIndex..<matched.endIndex, in: matched)
                            if let removeMatch = removeRegex.firstMatch(in: matched, options: [], range: removeRange),
                               let rangeToRemove = Range(removeMatch.range, in: matched)
                            {
                                text = String(matched[..<rangeToRemove.lowerBound])
                                    .replacingOccurrences(
                                        of: #"(?i)^translate\s*"#,
                                        with: "",
                                        options: .regularExpression
                                    )
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }
                }
            }
        }

        // If still no text, use the whole input minus keywords
        if text.isEmpty {
            text = original
                .replacingOccurrences(of: #"(?i)^translate\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)\s+(to|in)\s+\w+$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return TranslationExtractResult(
            text: text.isEmpty ? original : text,
            targetLanguage: targetLanguage.isEmpty ? "english" : targetLanguage,
            sourceLanguage: sourceLanguage
        )
    }

    // MARK: Unit Conversion Parameters

    private struct UnitConversionExtractResult {
        let value: Double
        let fromUnit: String
        let toUnit: String
        let category: String?
    }

    private func extractUnitConversionParams(input _: String, original: String) -> UnitConversionExtractResult? {
        // Pattern: "convert X unit1 to unit2" or "X unit1 to unit2" or "how many unit2 in X unit1"
        let patterns: [(pattern: String, isHowMany: Bool)] = [
            (pattern: #"convert\s+([\d.eE+-]+)\s*([a-zA-Z/]+)\s+(?:to|in)\s+([a-zA-Z/]+)"#, isHowMany: false),
            (pattern: #"how\s+many\s+([a-zA-Z/]+)\s+(?:in|is|are)\s+([\d.eE+-]+)\s*([a-zA-Z/]+)"#, isHowMany: true),
            (pattern: #"([\d.eE+-]+)\s*([a-zA-Z/]+)\s+(?:to|in)\s+([a-zA-Z/]+)"#, isHowMany: false),
        ]

        for (pattern, isHowMany) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(original.startIndex..<original.endIndex, in: original)

            if let match = regex.firstMatch(in: original, options: [], range: range),
               match.numberOfRanges >= 4
            {
                if isHowMany {
                    // "how many miles in 100 km"
                    // group1=toUnit, group2=value, group3=fromUnit
                    if let toUnitRange = Range(match.range(at: 1), in: original),
                       let valueRange = Range(match.range(at: 2), in: original),
                       let fromUnitRange = Range(match.range(at: 3), in: original)
                    {
                        let toUnitStr = String(original[toUnitRange]).lowercased()
                        let valueStr = String(original[valueRange])
                        let fromUnitStr = String(original[fromUnitRange]).lowercased()

                        guard let value = Double(valueStr) else { continue }
                        guard isKnownUnit(fromUnitStr) || isKnownUnit(toUnitStr) else { continue }

                        let category = inferUnitCategory(from: fromUnitStr, to: toUnitStr)
                        return UnitConversionExtractResult(
                            value: value,
                            fromUnit: normalizeUnit(fromUnitStr),
                            toUnit: normalizeUnit(toUnitStr),
                            category: category
                        )
                    }
                } else {
                    // "100 km to miles" or "convert 100 km to miles"
                    // group1=value, group2=fromUnit, group3=toUnit
                    if let valueRange = Range(match.range(at: 1), in: original),
                       let fromUnitRange = Range(match.range(at: 2), in: original),
                       let toUnitRange = Range(match.range(at: 3), in: original)
                    {
                        let valueStr = String(original[valueRange])
                        let fromUnitStr = String(original[fromUnitRange]).lowercased()
                        let toUnitStr = String(original[toUnitRange]).lowercased()

                        guard let value = Double(valueStr) else { continue }
                        guard isKnownUnit(fromUnitStr) || isKnownUnit(toUnitStr) else { continue }

                        let category = inferUnitCategory(from: fromUnitStr, to: toUnitStr)
                        return UnitConversionExtractResult(
                            value: value,
                            fromUnit: normalizeUnit(fromUnitStr),
                            toUnit: normalizeUnit(toUnitStr),
                            category: category
                        )
                    }
                }
            }
        }

        return nil
    }

    // MARK: Event Parameters

    private struct EventExtractResult {
        let title: String
        let date: String?
        let time: String?
        let location: String?
        let contact: String?
    }

    private func extractEventParams(input _: String, original: String) -> EventExtractResult {
        var title = ""
        var date: String?
        var time: String?
        var location: String?
        var contact: String?

        // Extract date using NSDataDetector (Stage 1)
        let dateTimeResult = extractDateTime(from: original)
        date = dateTimeResult.date
        time = dateTimeResult.time

        // Extract named entities using NLTagger (Stage 2)
        let entities = extractNamedEntities(from: original)
        location = entities.place
        contact = entities.person

        // Extract title - remove known patterns
        var cleanedInput = original

        // Remove "with X" pattern for contact
        let withPattern = #"(?i)\s+with\s+([A-Za-z][A-Za-z0-9 _'-]{0,40})(?=\s+(?:at|in|on|tomorrow|today|tonight|morning|afternoon|evening)\b|$)"#
        if let regex = try? NSRegularExpression(pattern: withPattern) {
            if let match = regex.firstMatch(
                in: cleanedInput,
                range: NSRange(cleanedInput.startIndex..<cleanedInput.endIndex, in: cleanedInput)
            ) {
                if let range = Range(match.range(at: 1), in: cleanedInput) {
                    contact = String(cleanedInput[range]).trimmingCharacters(in: .whitespaces)
                }
                cleanedInput = regex.stringByReplacingMatches(
                    in: cleanedInput,
                    range: NSRange(cleanedInput.startIndex..<cleanedInput.endIndex, in: cleanedInput),
                    withTemplate: ""
                )
            }
        }

        // Remove "in/at location" pattern
        let locationPattern = #"(?i)\s+(?:in|at)\s+([A-Za-z0-9][A-Za-z0-9 _'-]{1,60})(?=\s*$|\s+(?:tomorrow|today|tonight|morning|afternoon|evening|at\s+[0-1]?\d))"#
        if let regex = try? NSRegularExpression(pattern: locationPattern) {
            if let match = regex.firstMatch(
                in: cleanedInput,
                range: NSRange(cleanedInput.startIndex..<cleanedInput.endIndex, in: cleanedInput)
            ) {
                if location == nil, let range = Range(match.range(at: 1), in: cleanedInput) {
                    location = String(cleanedInput[range]).trimmingCharacters(in: .whitespaces)
                }
                cleanedInput = regex.stringByReplacingMatches(
                    in: cleanedInput,
                    range: NSRange(cleanedInput.startIndex..<cleanedInput.endIndex, in: cleanedInput),
                    withTemplate: ""
                )
            }
        }

        // Remove date/time patterns
        let dateTimePatterns = [
            #"(?i)\s+(today|tomorrow|tonight)\b"#,
            #"(?i)\s+(?:on\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b"#,
            #"(?i)\s+(?:on\s+)?(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2}\b"#,
            #"(?i)\s+at\s+([0-1]?\d(:[0-5]\d)?\s?(am|pm))\b"#,
        ]
        for pattern in dateTimePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                cleanedInput = regex.stringByReplacingMatches(
                    in: cleanedInput,
                    range: NSRange(cleanedInput.startIndex..<cleanedInput.endIndex, in: cleanedInput),
                    withTemplate: ""
                )
            }
        }

        // Remove event keywords
        let keywordPatterns = [
            #"(?i)\b(meeting|event|calendar|schedule|appointment)\b"#,
            #"(?i)\b(create|add|new|schedule)\s*"#,
        ]
        for pattern in keywordPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                cleanedInput = regex.stringByReplacingMatches(
                    in: cleanedInput,
                    range: NSRange(cleanedInput.startIndex..<cleanedInput.endIndex, in: cleanedInput),
                    withTemplate: " "
                )
            }
        }

        // Clean up whitespace
        cleanedInput = cleanedInput
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Set title
        if !cleanedInput.isEmpty {
            title = cleanedInput
        } else if let contactName = contact {
            title = "Meeting with \(contactName)"
        } else {
            title = "Event"
        }

        return EventExtractResult(
            title: title,
            date: date,
            time: time,
            location: location,
            contact: contact
        )
    }

    // MARK: File Search Parameters

    private struct FileSearchExtractResult {
        let query: String
        let searchInContent: Bool
        let fileExtension: String?
        let modifiedWithin: Int?
    }

    private func extractFileSearchParams(input: String, original: String) -> FileSearchExtractResult {
        var query = "*"
        var searchInContent = false
        var fileExtension: String?
        var modifiedWithin: Int?

        // Extract file extension - require dot prefix or word boundary
        for ext in fileExtensions {
            // Match .ext or "ext " at word boundary (not as substring)
            let pattern = #"(?:^|\s|\.)\#(ext)(?:\s|$)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if regex.firstMatch(in: input, range: NSRange(input.startIndex..<input.endIndex, in: input)) != nil {
                    fileExtension = ext
                    break
                }
            }
            // Also check for extension at end of string
            if input.hasSuffix(".\(ext)") || input.hasSuffix(" \(ext)") {
                if fileExtension == nil {
                    fileExtension = ext
                }
            }
        }

        // Extract modifiedWithin
        if input.contains("today") {
            modifiedWithin = hoursSinceStartOfDay()
        } else if input.contains("yesterday") {
            modifiedWithin = 48 // yesterday = last 48 hours
        } else {
            // Check for "X hours ago" or "last X hours"
            let hoursPatterns = [
                #"(\d+)\s+hours?\s+ago"#,
                #"last\s+(\d+)\s+hours?"#,
                #"past\s+(\d+)\s+hours?"#,
            ]
            for pattern in hoursPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    if let match = regex.firstMatch(
                        in: input,
                        range: NSRange(input.startIndex..<input.endIndex, in: input)
                    ),
                        let range = Range(match.range(at: 1), in: input),
                        let hours = Int(input[range])
                    {
                        modifiedWithin = hours
                        break
                    }
                }
            }
        }

        // Check for content search
        if input.contains("content") || input.contains("contains") {
            searchInContent = true
        }

        // Extract query text
        var cleanedInput = original

        // Remove file extension
        if let ext = fileExtension {
            let extPattern = #"(?i)\.?\b\#(ext)s?\b"#
            if let regex = try? NSRegularExpression(pattern: extPattern) {
                cleanedInput = regex.stringByReplacingMatches(
                    in: cleanedInput,
                    range: NSRange(cleanedInput.startIndex..<cleanedInput.endIndex, in: cleanedInput),
                    withTemplate: ""
                )
            }
        }

        // Remove search keywords
        let keywordPatterns = [
            #"(?i)\b(find|search|show|display|list|files?|documents?)\b"#,
            #"(?i)\b(created|modified|updated)\s+(?:today|yesterday|within)\b"#,
            #"(?i)\b(today|yesterday|last|past|hours?|ago)\s*\d*\b"#,
            #"(?i)\b(in|from|within|containing)\b"#,
            #"(?i)\bthe\b"#,
        ]
        for pattern in keywordPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                cleanedInput = regex.stringByReplacingMatches(
                    in: cleanedInput,
                    range: NSRange(cleanedInput.startIndex..<cleanedInput.endIndex, in: cleanedInput),
                    withTemplate: " "
                )
            }
        }

        cleanedInput = cleanedInput
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanedInput.isEmpty, cleanedInput != "*" {
            query = cleanedInput
        }

        return FileSearchExtractResult(
            query: query,
            searchInContent: searchInContent,
            fileExtension: fileExtension,
            modifiedWithin: modifiedWithin
        )
    }

    // MARK: - Stage 1: Date/Time Extraction using NSDataDetector

    private struct DateTimeExtractResult {
        let date: String?
        let time: String?
    }

    private func extractDateTime(from input: String) -> DateTimeExtractResult {
        var date: String?
        var time: String?

        // Use NSDataDetector to find dates
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            let range = NSRange(input.startIndex..<input.endIndex, in: input)

            let matches = detector.matches(in: input, options: [], range: range)

            if let firstMatch = matches.first,
               let dateRange = Range(firstMatch.range, in: input)
            {
                // matchedDateString can be used for debugging if needed
                _ = String(input[dateRange])
                let detectedDate = firstMatch.date

                // Convert detected date to our format
                if let detected = detectedDate {
                    let calendar = Calendar.current
                    if calendar.isDateInToday(detected) {
                        date = "today"
                    } else if calendar.isDateInTomorrow(detected) {
                        date = "tomorrow"
                    } else if calendar.isDateInYesterday(detected) {
                        date = "yesterday"
                    } else {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MMMM d"
                        date = formatter.string(from: detected).lowercased()
                    }

                    // Extract time
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "h:mm a"
                    let timeStr = timeFormatter.string(from: detected)
                    // Check if time is not midnight (likely not specified)
                    let hour = calendar.component(.hour, from: detected)
                    let minute = calendar.component(.minute, from: detected)
                    if hour != 0 || minute != 0 {
                        time = timeStr.lowercased()
                    }
                }

                // Also check for relative date keywords that NSDataDetector might miss
                let lowercased = input.lowercased()
                if lowercased.contains("today"), date == nil {
                    date = "today"
                }
                if lowercased.contains("tomorrow"), date == nil {
                    date = "tomorrow"
                }
            }
        } catch {
            // Fallback to simple keyword matching
            let lowercased = input.lowercased()
            if lowercased.contains("today") {
                date = "today"
            } else if lowercased.contains("tomorrow") {
                date = "tomorrow"
            }
        }

        // If no date from detector, check for keywords
        if date == nil {
            let lowercased = input.lowercased()
            if lowercased.contains("today") {
                date = "today"
            } else if lowercased.contains("tomorrow") {
                date = "tomorrow"
            }
        }

        // Extract time separately if not from detector
        if time == nil {
            time = extractTimeFromInput(input)
        }

        return DateTimeExtractResult(date: date, time: time)
    }

    private func extractTimeFromInput(_ input: String) -> String? {
        // Pattern: "at 3pm", "at 3:30pm", "at 15:30"
        let timePatterns = [
            #"(?i)\bat\s+([0-1]?\d(:[0-5]\d)?\s?(am|pm))\b"#,
            #"(?i)\b([0-1]?\d(:[0-5]\d)?\s?(am|pm))\b"#,
        ]

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                if let match = regex.firstMatch(
                    in: input,
                    range: NSRange(input.startIndex..<input.endIndex, in: input)
                ),
                    let range = Range(match.range(at: 1), in: input)
                {
                    return String(input[range]).lowercased()
                }
            }
        }

        return nil
    }

    // MARK: - Stage 2: Named Entity Extraction using NLTagger

    private struct NamedEntitiesExtractResult {
        let person: String?
        let place: String?
    }

    private func extractNamedEntities(from input: String) -> NamedEntitiesExtractResult {
        var person: String?
        var place: String?

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = input

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]

        tagger
            .enumerateTags(
                in: input.startIndex..<input.endIndex,
                unit: .word,
                scheme: .nameType,
                options: options
            ) { tag, tokenRange in
                guard let tag else { return true }

                switch tag {
                case .personalName:
                    if person == nil {
                        person = String(input[tokenRange])
                    }
                case .placeName:
                    if place == nil {
                        place = String(input[tokenRange])
                    }
                default:
                    break
                }

                return true
            }

        return NamedEntitiesExtractResult(person: person, place: place)
    }

    // MARK: - Utility Functions

    private func isKnownUnit(_ unit: String) -> Bool {
        let normalized = normalizeUnit(unit)
        return knownUnits.contains(normalized)
    }

    private func normalizeUnit(_ unit: String) -> String {
        let lower = unit.lowercased()

        // Map common variations
        switch lower {
        case "kilometer", "kilometers", "kilometre", "kilometres":
            return "km"
        case "meter", "meters", "metre", "metres":
            return "m"
        case "centimeter", "centimeters", "centimetre", "centimetres":
            return "cm"
        case "millimeter", "millimeters", "millimetre", "millimetres":
            return "mm"
        case "mile", "miles":
            return "mi"
        case "foot", "feet":
            return "ft"
        case "yard", "yards":
            return "yd"
        case "inch", "inches":
            return "in"
        case "kilogram", "kilograms":
            return "kg"
        case "gram", "grams":
            return "g"
        case "milligram", "milligrams":
            return "mg"
        case "pound", "pounds", "lbs":
            return "lb"
        case "ounce", "ounces", "oz":
            return "oz"
        case "celsius", "centigrade", "c":
            return "celsius"
        case "fahrenheit", "f":
            return "fahrenheit"
        case "kelvin", "k":
            return "kelvin"
        case "liter", "liters", "litre", "litres":
            return "l"
        case "milliliter", "milliliters", "millilitre", "millilitres":
            return "ml"
        case "gallon", "gallons", "gal":
            return "gal"
        case "quart", "quarts", "qt":
            return "qt"
        case "pint", "pints", "pt":
            return "pt"
        case "cup", "cups":
            return "cup"
        default:
            return lower
        }
    }

    private func inferUnitCategory(from: String, to: String) -> String? {
        let lengthUnits = ["km", "m", "cm", "mm", "mi", "ft", "yd", "in"]
        let weightUnits = ["kg", "g", "mg", "lb", "oz"]
        let temperatureUnits = ["celsius", "fahrenheit", "kelvin"]
        let volumeUnits = ["l", "ml", "gal", "qt", "pt", "cup"]

        let fromNorm = normalizeUnit(from)
        let toNorm = normalizeUnit(to)

        if lengthUnits.contains(fromNorm) || lengthUnits.contains(toNorm) {
            return "length"
        }
        if weightUnits.contains(fromNorm) || weightUnits.contains(toNorm) {
            return "weight"
        }
        if temperatureUnits.contains(fromNorm) || temperatureUnits.contains(toNorm) {
            return "temperature"
        }
        if volumeUnits.contains(fromNorm) || volumeUnits.contains(toNorm) {
            return "volume"
        }

        return nil
    }

    private func hoursSinceStartOfDay() -> Int {
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let start = calendar.startOfDay(for: now)
        let hours = Int(ceil(now.timeIntervalSince(start) / 3600.0))
        return max(1, hours)
    }
}

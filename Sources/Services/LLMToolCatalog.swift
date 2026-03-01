import Foundation

enum LLMToolCatalog {
    static let functionGemmaDeclarations: String = """
    <start_function_declaration>declaration:create_calendar_event{description:<escape>Create a calendar event.<escape>,parameters:{properties:{title:{description:<escape>Event title.<escape>,type:<escape>STRING<escape>},date:{description:<escape>Date for the event (e.g., "tomorrow", "March 10").<escape>,type:<escape>STRING<escape>},time:{description:<escape>Time for the event (e.g., "4pm", "14:30").<escape>,type:<escape>STRING<escape>},location:{description:<escape>Event location.<escape>,type:<escape>STRING<escape>},contact:{description:<escape>Contact person.<escape>,type:<escape>STRING<escape>}},required:[<escape>title<escape>],type:<escape>OBJECT<escape>}}<end_function_declaration>
    <start_function_declaration>declaration:find_files{description:<escape>Search for files.<escape>,parameters:{properties:{query:{description:<escape>Search query.<escape>,type:<escape>STRING<escape>},search_in_content:{description:<escape>Search within file contents.<escape>,type:<escape>BOOLEAN<escape>},file_extension:{description:<escape>File extension without dot, e.g. "pdf".<escape>,type:<escape>STRING<escape>},modified_within:{description:<escape>Modified within the last N hours.<escape>,type:<escape>INTEGER<escape>}},required:[<escape>query<escape>],type:<escape>OBJECT<escape>}}<end_function_declaration>
    <start_function_declaration>declaration:convert_units{description:<escape>Convert values between units of measurement.<escape>,parameters:{properties:{value:{description:<escape>Numeric value to convert.<escape>,type:<escape>NUMBER<escape>},from_unit:{description:<escape>Source unit (e.g., "km", "pounds", "celsius").<escape>,type:<escape>STRING<escape>},to_unit:{description:<escape>Target unit (e.g., "miles", "kg", "fahrenheit").<escape>,type:<escape>STRING<escape>},category:{description:<escape>Category hint: "length", "weight", "temperature", "volume".<escape>,type:<escape>STRING<escape>}},required:[<escape>value<escape>,<escape>from_unit<escape>,<escape>to_unit<escape>],type:<escape>OBJECT<escape>}}<end_function_declaration>
    <start_function_declaration>declaration:translate{description:<escape>Translate text between languages.<escape>,parameters:{properties:{text:{description:<escape>Text to translate.<escape>,type:<escape>STRING<escape>},target_language:{description:<escape>Target language (e.g., "spanish", "french", "german", "es", "fr").<escape>,type:<escape>STRING<escape>},source_language:{description:<escape>Source language (optional, auto-detect if not specified).<escape>,type:<escape>STRING<escape>}},required:[<escape>text<escape>,<escape>target_language<escape>],type:<escape>OBJECT<escape>}}<end_function_declaration>
    """

    // MARK: - Fallback Parse

    static func fallbackParse(input: String) -> LLMToolCall? {
        let lower = input.lowercased()

        // Translation - check early since it's a specific command
        if lower.contains("translate") || lower.contains("translation") {
            let params = inferTranslationParams(from: input)
            return LLMToolCall.translate(
                text: params.text,
                targetLanguage: params.targetLanguage,
                sourceLanguage: params.sourceLanguage,
                confidence: 0.6
            )
        }

        // Calendar event
        if lower.contains("meeting") || lower.contains("event") || lower.contains("calendar") || lower.contains("schedule") {
            return LLMToolCall.createCalendarEvent(
                title: inferEventTitle(from: input) ?? "Event",
                date: inferDate(from: input),
                time: inferTime(from: input),
                location: inferLocation(from: input),
                contact: inferContact(from: input),
                confidence: 0.55
            )
        }

        // File search
        if lower.contains("find") || lower.contains("search") || lower.contains("file") {
            let params = inferFileSearchParams(from: input)
            return LLMToolCall.findFiles(
                query: params.query,
                searchInContent: params.searchInContent,
                fileExtension: params.fileExtension,
                modifiedWithin: params.modifiedWithin,
                confidence: 0.55
            )
        }

        // Unit conversion
        if let params = inferUnitConversionParams(from: input) {
            return LLMToolCall.convertUnits(
                value: params.value,
                fromUnit: params.fromUnit,
                toUnit: params.toUnit,
                category: params.category,
                confidence: 0.6
            )
        }

        return nil
    }

    // MARK: - Map Payload to Tool Call

    static func mapPayloadToToolCall(toolName: String, fields: [String: Any], originalInput: String) -> LLMToolCall? {
        switch toolName {
        case "create_calendar_event":
            let title = (fields["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackTitle = inferEventTitle(from: originalInput)
            let finalTitle = (title?.isEmpty == false ? title : fallbackTitle) ?? "Event"

            let inferredDate = inferDate(from: originalInput)
            let inferredTime = inferTime(from: originalInput)
            let inferredLocation = inferLocation(from: originalInput)
            let inferredContact = inferContact(from: originalInput)

            return LLMToolCall.createCalendarEvent(
                title: finalTitle,
                date: (fields["date"] as? String) ?? inferredDate,
                time: (fields["time"] as? String) ?? inferredTime,
                location: (fields["location"] as? String) ?? inferredLocation,
                contact: (fields["contact"] as? String) ?? inferredContact,
                confidence: 0.9
            )

        case "find_files":
            guard let query = (fields["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !query.isEmpty else {
                return nil
            }
            return LLMToolCall.findFiles(
                query: query,
                searchInContent: fields["search_in_content"] as? Bool ?? false,
                fileExtension: fields["file_extension"] as? String,
                modifiedWithin: fields["modified_within"] as? Int,
                confidence: 0.9
            )

        case "convert_units":
            let value: Double? = {
                if let v = fields["value"] as? Double {
                    return v
                }
                if let vStr = fields["value"] as? String, let v = Double(vStr) {
                    return v
                }
                return nil
            }()

            let fromUnit = (fields["from_unit"] as? String)?.lowercased()
            let toUnit = (fields["to_unit"] as? String)?.lowercased()
            let category = fields["category"] as? String

            if let value = value, let fromUnit = fromUnit, !fromUnit.isEmpty,
               let toUnit = toUnit, !toUnit.isEmpty {
                return LLMToolCall.convertUnits(
                    value: value,
                    fromUnit: fromUnit,
                    toUnit: toUnit,
                    category: category,
                    confidence: 0.9
                )
            }

            // Fallback: try to infer from original input
            if let params = inferUnitConversionParams(from: originalInput) {
                return LLMToolCall.convertUnits(
                    value: params.value,
                    fromUnit: params.fromUnit,
                    toUnit: params.toUnit,
                    category: params.category,
                    confidence: 0.7
                )
            }

            return nil

        case "translate":
            let text = (fields["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let targetLanguage = fields["target_language"] as? String ?? ""
            let sourceLanguage = fields["source_language"] as? String

            // If we have the required fields, use them
            if !text.isEmpty && !targetLanguage.isEmpty {
                return LLMToolCall.translate(
                    text: text,
                    targetLanguage: TranslationService.normalizeLanguage(targetLanguage),
                    sourceLanguage: sourceLanguage.map { TranslationService.normalizeLanguage($0) },
                    confidence: 0.9
                )
            }

            // Fallback: try to infer from original input
            let params = inferTranslationParams(from: originalInput)
            return LLMToolCall.translate(
                text: params.text,
                targetLanguage: params.targetLanguage,
                sourceLanguage: params.sourceLanguage,
                confidence: 0.7
            )

        case "none":
            return nil

        default:
            return nil
        }
    }

    // MARK: - Describe Tool Call

    static func describe(_ toolCall: LLMToolCall) -> String {
        switch toolCall.parameters {
        case .createCalendarEvent(let params):
            return "create_calendar_event(title: \(params.title), date: \(params.date ?? "nil"), time: \(params.time ?? "nil"))"
        case .findFiles(let params):
            return "find_files(query: \(params.query), extension: \(params.fileExtension ?? "nil"))"
        case .convertUnits(let params):
            return "convert_units(\(params.value) \(params.fromUnit) -> \(params.toUnit))"
        case .translate(let params):
            return "translate(text: \(params.text), sourceLanguage: \(params.sourceLanguage ?? "auto-detect"), targetLanguage: \(params.targetLanguage))"
        }
    }

    // MARK: - Translation Inference

    private static func inferTranslationParams(from input: String) -> TranslationParams {
        let lower = input.lowercased()
        var text = ""
        var sourceLanguage: String?
        var targetLanguage = "en"  // Default to English

        // Pattern: "translate X from Y to Z"
        let fromToPattern = #"translate\s+(.+?)\s+from\s+(\w+)\s+to\s+(\w+)"#
        if firstRegexMatch(in: lower, pattern: fromToPattern, captureGroup: 0) != nil,
           let textMatch = firstRegexMatch(in: lower, pattern: fromToPattern, captureGroup: 1),
           let sourceMatch = firstRegexMatch(in: lower, pattern: fromToPattern, captureGroup: 2),
           let targetMatch = firstRegexMatch(in: lower, pattern: fromToPattern, captureGroup: 3) {
            text = textMatch
            sourceLanguage = TranslationService.normalizeLanguage(sourceMatch)
            targetLanguage = TranslationService.normalizeLanguage(targetMatch)
            return TranslationParams(text: text, targetLanguage: targetLanguage, sourceLanguage: sourceLanguage)
        }

        // Pattern: "translate X to Y"
        let toPattern = #"translate\s+(.+?)\s+to\s+(\w+)"#
        if firstRegexMatch(in: lower, pattern: toPattern, captureGroup: 0) != nil,
           let textMatch = firstRegexMatch(in: lower, pattern: toPattern, captureGroup: 1),
           let targetMatch = firstRegexMatch(in: lower, pattern: toPattern, captureGroup: 2) {
            text = textMatch
            targetLanguage = TranslationService.normalizeLanguage(targetMatch)
            return TranslationParams(text: text, targetLanguage: targetLanguage, sourceLanguage: nil)
        }

        // Fallback: just extract what we can
        return TranslationParams(text: text.isEmpty ? input : text, targetLanguage: targetLanguage, sourceLanguage: sourceLanguage)
    }

    // MARK: - Calendar Event Inference

    private static func inferEventTitle(from input: String) -> String? {
        if let contact = inferContact(from: input) {
            return "Meeting with \(contact)"
        }
        return input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "Event"
    }

    private static func inferContact(from input: String) -> String? {
        firstRegexMatch(in: input, pattern: #"(?i)\bwith\s+([A-Za-z][A-Za-z0-9 _'-]{0,40}?)(?=\s+(at|in|on|tomorrow|today|tonight|morning|afternoon|evening)\b|$)"#)
    }

    private static func inferDate(from input: String) -> String? {
        let lower = input.lowercased()
        if lower.contains("tomorrow") { return "tomorrow" }
        if lower.contains("today") { return "today" }
        if lower.contains("tonight") { return "today" }
        return nil
    }

    private static func inferTime(from input: String) -> String? {
        if let explicit = firstRegexMatch(in: input, pattern: #"(?i)\b(at\s+)?([0-1]?\d(:[0-5]\d)?\s?(am|pm))\b"#, captureGroup: 2) {
            return explicit
        }
        let lower = input.lowercased()
        if lower.contains("morning") { return "9am" }
        if lower.contains("afternoon") { return "2pm" }
        if lower.contains("evening") { return "6pm" }
        if lower.contains("tonight") { return "8pm" }
        return nil
    }

    private static func inferLocation(from input: String) -> String? {
        if let inLocation = firstRegexMatch(in: input, pattern: #"(?i)\bin\s+(?:the\s+)?([A-Za-z0-9][A-Za-z0-9 _'-]{1,60})\b"#) {
            return inLocation
        }
        let raw = firstRegexMatch(in: input, pattern: #"(?i)\bat\s+(?:the\s+)?([A-Za-z][A-Za-z0-9 _'-]{1,60}?)(?=\s*$|\s+on\b|\s+tomorrow\b|\s+today\b|\s+tonight\b|\s+at\s+[0-1]?\d(:[0-5]\d)?\s?(am|pm)\b)"#)
        return sanitizeLocation(raw)
    }

    // MARK: - File Search Inference

    private static func inferFileSearchParams(from input: String) -> FindFilesParams {
        let lower = input.lowercased()

        let fileExtension = firstRegexMatch(
            in: lower,
            pattern: #"\b(pdf|txt|md|markdown|doc|docx|xls|xlsx|ppt|pptx|csv|json|xml|png|jpg|jpeg)\b"#
        ).map(normalizedFileExtension)

        let modifiedWithin: Int? = {
            if lower.contains("today") {
                return max(1, hoursSinceStartOfToday())
            }
            if let hoursText = firstRegexMatch(in: lower, pattern: #"\b(?:last|past)\s+(\d+)\s+hours?\b"#),
               let hours = Int(hoursText) {
                return max(1, hours)
            }
            if let hoursText = firstRegexMatch(in: lower, pattern: #"\b(\d+)\s+hours?\s+ago\b"#),
               let hours = Int(hoursText) {
                return max(1, hours)
            }
            if lower.contains("last hour") || lower.contains("past hour") || lower.contains("an hour ago") || lower.contains("1 hour ago") {
                return 1
            }
            return nil
        }()

        let query = inferFileQuery(from: input, fileExtension: fileExtension)
        return FindFilesParams(query: query, searchInContent: lower.contains("content"), fileExtension: fileExtension, modifiedWithin: modifiedWithin)
    }

    private static func inferFileQuery(from input: String, fileExtension: String?) -> String {
        var query = input.lowercased()
        let cleanupPatterns = [
            #"\b(find|search|show|display|list)\b"#,
            #"\b(files?|documents?)\b"#,
            #"\b(created|modified|updated)\b"#,
            #"\b(today|yesterday)\b"#,
            #"\b(last|past)\s+\d+\s+hours?\b"#,
            #"\b\d+\s+hours?\s+ago\b"#,
            #"\b(an|one)\s+hour\s+ago\b"#,
            #"\b(last|past)\s+hour\b"#,
            #"\b(in|from|within)\b"#,
            #"\bthe\b"#,
        ]
        for pattern in cleanupPatterns {
            query = query.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        if let fileExtension {
            let extPattern = #"\b\#(fileExtension)s?\b"#
            query = query.replacingOccurrences(of: extPattern, with: " ", options: .regularExpression)
        }
        query = query.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? "*" : query
    }

    private static func normalizedFileExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "markdown": return "md"
        case "jpeg": return "jpg"
        default: return ext.lowercased()
        }
    }

    private static func hoursSinceStartOfToday() -> Int {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let hours = Int(ceil(now.timeIntervalSince(start) / 3600.0))
        return max(1, hours)
    }

    // MARK: - Unit Conversion Inference

    /// Check if a string is a known unit abbreviation
    private static func isKnownUnit(_ unit: String) -> Bool {
        let knownUnits: Set<String> = [
            // Length
            "km", "m", "cm", "mm", "mi", "mile", "miles", "ft", "foot", "feet", "yd", "yard", "yards", "in", "inch", "inches", "meter", "meters", "kilometer", "kilometers", "centimeter", "centimeters", "millimeter", "millimeters",
            // Weight
            "kg", "g", "mg", "lb", "lbs", "pound", "pounds", "oz", "ounce", "ounces", "kilogram", "kilograms", "gram", "grams",
            // Temperature
            "c", "f", "k", "celsius", "fahrenheit", "kelvin", "centigrade",
            // Volume
            "l", "ml", "gal", "gallon", "gallons", "qt", "quart", "quarts", "pt", "pint", "cup", "cups", "floz", "liter", "liters", "litre", "litres", "milliliter", "milliliters",
            // Area
            "sqm", "sqft", "sqyd", "acre", "acres", "ha", "hectare", "hectares", "sqkm", "sq m", "sq ft", "sq yd",
            // Speed
            "km/h", "kmh", "kph", "mph", "m/s", "fps", "knot", "knots",
            // Time
            "s", "sec", "second", "seconds", "min", "minute", "minutes", "h", "hr", "hour", "hours", "day", "days", "week", "weeks", "year", "years",
            // Data
            "b", "kb", "mb", "gb", "tb", "byte", "bytes", "kilobyte", "kilobytes", "megabyte", "megabytes", "gigabyte", "gigabytes", "terabyte", "terabytes"
        ]
        return knownUnits.contains(unit.lowercased())
    }

    /// Infer unit conversion parameters from natural language input
    private static func inferUnitConversionParams(from input: String) -> (value: Double, fromUnit: String, toUnit: String, category: String?)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pattern: "convert X unit1 to unit2" or "X unit1 to unit2" or "how many unit2 in X unit1"
        let patterns: [(pattern: String, isHowMany: Bool)] = [
            // "convert 100 km to miles"
            (#"(?i)convert\s+([\d.eE+-]+)\s*([a-zA-Z/]+)\s+(?:to|in)\s+([a-zA-Z/]+)"#, false),
            // "how many miles in 100 km" - must come before generic pattern
            (#"(?i)how\s+many\s+([a-zA-Z/]+)\s+(?:in|is|are)\s+([\d.eE+-]+)\s*([a-zA-Z/]+)"#, true),
            // "100 km to miles"
            (#"(?i)([\d.eE+-]+)\s*([a-zA-Z/]+)\s+(?:to|in)\s+([a-zA-Z/]+)"#, false),
        ]

        for (pattern, isHowMany) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(trimmed.startIndex ..< trimmed.endIndex, in: trimmed)

            if let match = regex.firstMatch(in: trimmed, options: [], range: range),
               match.numberOfRanges >= 4,
               let group1Range = Range(match.range(at: 1), in: trimmed),
               let group2Range = Range(match.range(at: 2), in: trimmed),
               let group3Range = Range(match.range(at: 3), in: trimmed) {

                if isHowMany {
                    // Pattern: "how many miles in 100 km"
                    // group1=toUnit (miles), group2=value (100), group3=fromUnit (km)
                    let actualToUnit = String(trimmed[group1Range]).lowercased()
                    let actualValueStr = String(trimmed[group2Range])
                    let actualFromUnit = String(trimmed[group3Range]).lowercased()

                    guard let value = Double(actualValueStr) else { continue }

                    // Validate that at least one unit is known
                    guard isKnownUnit(actualFromUnit) || isKnownUnit(actualToUnit) else { continue }

                    let category = inferUnitCategory(from: actualFromUnit, to: actualToUnit)
                    return (value, actualFromUnit, actualToUnit, category)
                } else {
                    // Pattern: "100 km to miles" or "convert 100 km to miles"
                    // group1=value, group2=fromUnit, group3=toUnit
                    let valueStr = String(trimmed[group1Range])
                    let fromUnit = String(trimmed[group2Range]).lowercased()
                    let toUnit = String(trimmed[group3Range]).lowercased()

                    guard let value = Double(valueStr) else { continue }

                    // Validate that at least one unit is known
                    guard isKnownUnit(fromUnit) || isKnownUnit(toUnit) else { continue }

                    let category = inferUnitCategory(from: fromUnit, to: toUnit)
                    return (value, fromUnit, toUnit, category)
                }
            }
        }

        return nil
    }

    /// Infer the unit category from two unit abbreviations
    private static func inferUnitCategory(from: String, to: String) -> String? {
        // Known unit categories and their abbreviations
        let categories: [String: Set<String>] = [
            "length": ["km", "m", "cm", "mm", "mi", "mile", "miles", "ft", "foot", "feet", "yd", "yard", "yards", "in", "inch", "inches", "meter", "meters", "kilometer", "kilometers", "centimeter", "centimeters", "millimeter", "millimeters"],
            "weight": ["kg", "g", "mg", "lb", "lbs", "pound", "pounds", "oz", "ounce", "ounces", "kilogram", "kilograms", "gram", "grams"],
            "temperature": ["c", "f", "k", "celsius", "fahrenheit", "kelvin", "centigrade"],
            "volume": ["l", "ml", "gal", "gallon", "gallons", "qt", "quart", "quarts", "pt", "pint", "cup", "cups", "floz", "liter", "liters", "litre", "litres", "milliliter", "milliliters"],
            "area": ["sqm", "sqft", "sqyd", "acre", "acres", "ha", "hectare", "hectares", "sqkm", "sq m", "sq ft", "sq yd"],
            "speed": ["km/h", "kmh", "kph", "mph", "m/s", "fps", "knot", "knots"],
            "time": ["s", "sec", "second", "seconds", "min", "minute", "minutes", "h", "hr", "hour", "hours", "day", "days", "week", "weeks", "year", "years"],
            "data": ["b", "kb", "mb", "gb", "tb", "byte", "bytes", "kilobyte", "kilobytes", "megabyte", "megabytes", "gigabyte", "gigabytes", "terabyte", "terabytes"]
        ]

        let fromLower = from.lowercased()
        let toLower = to.lowercased()

        for (category, units) in categories {
            if units.contains(fromLower) || units.contains(toLower) {
                return category
            }
        }

        return nil
    }

    // MARK: - Utility

    private static func sanitizeLocation(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        value = value.replacingOccurrences(
            of: #"(?i)\s+at\s+[0-1]?\d(:[0-5]\d)?\s?(am|pm)\b.*$"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func firstRegexMatch(in text: String, pattern: String, captureGroup: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > captureGroup,
              let capturedRange = Range(match.range(at: captureGroup), in: text) else {
            return nil
        }
        let value = String(text[capturedRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

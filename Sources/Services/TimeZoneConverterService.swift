import AppKit
import Foundation

/// Service for converting times between different time zones
final class TimeZoneConverterService {
    static let shared: TimeZoneConverterService = .init()

    private init() {}

    // MARK: - Time Zone Definitions

    /// City/time zone alias mapping
    private let cityToTimeZone: [String: String] = [
        // US
        "new york": "America/New_York",
        "los angeles": "America/Los_Angeles",
        "chicago": "America/Chicago",
        "san francisco": "America/Los_Angeles",
        "seattle": "America/Los_Angeles",
        "boston": "America/New_York",
        "miami": "America/New_York",
        "denver": "America/Denver",
        "phoenix": "America/Phoenix",
        "houston": "America/Chicago",
        "dallas": "America/Chicago",
        "atlanta": "America/New_York",

        // Europe
        "london": "Europe/London",
        "paris": "Europe/Paris",
        "berlin": "Europe/Berlin",
        "rome": "Europe/Rome",
        "madrid": "Europe/Madrid",
        "amsterdam": "Europe/Amsterdam",
        "zurich": "Europe/Zurich",
        "moscow": "Europe/Moscow",

        // Asia
        "tokyo": "Asia/Tokyo",
        "shanghai": "Asia/Shanghai",
        "beijing": "Asia/Shanghai",
        "hong kong": "Asia/Hong_Kong",
        "singapore": "Asia/Singapore",
        "mumbai": "Asia/Kolkata",
        "delhi": "Asia/Kolkata",
        "dubai": "Asia/Dubai",
        "seoul": "Asia/Seoul",
        "taipei": "Asia/Taipei",
        "bangkok": "Asia/Bangkok",
        "jakarta": "Asia/Jakarta",
        "manila": "Asia/Manila",

        // Oceania
        "sydney": "Australia/Sydney",
        "melbourne": "Australia/Melbourne",
        "auckland": "Pacific/Auckland",
        "perth": "Australia/Perth",
        "brisbane": "Australia/Brisbane",

        // Others
        "toronto": "America/Toronto",
        "vancouver": "America/Vancouver",
        "sao paulo": "America/Sao_Paulo",
        "cairo": "Africa/Cairo",
        "johannesburg": "Africa/Johannesburg",
        "tel aviv": "Asia/Jerusalem",
    ]

    /// Time zone abbreviation mapping
    private let abbreviationToTimeZone: [String: String] = [
        "est": "America/New_York",
        "edt": "America/New_York",
        "cst": "America/Chicago",
        "cdt": "America/Chicago",
        "mst": "America/Denver",
        "mdt": "America/Denver",
        "pst": "America/Los_Angeles",
        "pdt": "America/Los_Angeles",
        "gmt": "GMT",
        "utc": "UTC",
        "cet": "Europe/Paris",
        "cest": "Europe/Paris",
        "jst": "Asia/Tokyo",
        "ist": "Asia/Kolkata",
        "aest": "Australia/Sydney",
        "aedt": "Australia/Sydney",
        "nzst": "Pacific/Auckland",
        "nzdt": "Pacific/Auckland",
    ]

    /// Frequent time zones for display
    private let frequentTimeZones = [
        ("EST", "America/New_York"),
        ("PST", "America/Los_Angeles"),
        ("CST", "America/Chicago"),
        ("GMT", "GMT"),
        ("UTC", "UTC"),
        ("London", "Europe/London"),
        ("Paris", "Europe/Paris"),
        ("Tokyo", "Asia/Tokyo"),
        ("Sydney", "Australia/Sydney"),
        ("Auckland", "Pacific/Auckland"),
    ]

    // MARK: - Pattern Matching

    /// Regex to match time conversion: "3pm EST to PST" or "9am Tokyo to London"
    /// Pattern: <hour>[:<minute>]? [am|pm]? <source> to <dest>
    private var timeConversionPattern: String {
        #"^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+(.+?)\s+to\s+(.+)$"#
    }

    /// Regex to match "time in" queries: "time in New York"
    private var timeInPattern: String {
        #"(?:what\s+)?time\s+(?:is\s+it\s+)?(?:in\s+)?(.+)$"#
    }

    /// Check if input looks like a time conversion expression
    func isTimeConversionExpression(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard let regex = try? NSRegularExpression(pattern: timeConversionPattern, options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range) else {
            return false
        }

        // Extract time zones
        guard let fromZoneRange = Range(match.range(at: 4), in: trimmed),
              let toZoneRange = Range(match.range(at: 5), in: trimmed)
        else {
            return false
        }

        let fromZone = String(trimmed[fromZoneRange])
        let toZone = String(trimmed[toZoneRange])

        return resolveTimeZone(fromZone) != nil && resolveTimeZone(toZone) != nil
    }

    /// Check if input looks like a "time in" query
    func isTimeInExpression(_ input: String) -> Bool {
        let trimmed = input.lowercased().trimmingCharacters(in: .whitespaces)
        guard let regex = try? NSRegularExpression(pattern: timeInPattern, options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              let cityRange = Range(match.range(at: 1), in: trimmed)
        else {
            return false
        }
        let city = String(trimmed[cityRange])
        return resolveTimeZone(city) != nil
    }

    // MARK: - Conversion

    /// Convert time from one zone to another
    func convert(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard isTimeConversionExpression(trimmed) else { return nil }

        // Parse the time expression
        guard let parsed = parseTimeConversion(trimmed) else { return nil }

        // Resolve time zones
        guard let sourceTimeZone = resolveTimeZone(parsed.fromZone),
              let destTimeZone = resolveTimeZone(parsed.toZone)
        else {
            return nil
        }

        // Perform conversion
        return convertTime(
            hour: parsed.hour24,
            minute: parsed.minute,
            from: sourceTimeZone,
            to: destTimeZone,
            toZoneName: parsed.toZone
        )
    }

    /// Parsed time conversion components
    private struct ParsedTimeConversion {
        let hour24: Int
        let minute: Int
        let fromZone: String
        let toZone: String
    }

    /// Parse time conversion expression into components
    private func parseTimeConversion(_ input: String) -> ParsedTimeConversion? {
        guard let regex = try? NSRegularExpression(pattern: timeConversionPattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(input.startIndex..., in: input)
        guard let match = regex.firstMatch(in: input, options: [], range: range) else {
            return nil
        }

        // Extract components
        guard let hourRange = Range(match.range(at: 1), in: input),
              let fromZoneRange = Range(match.range(at: 4), in: input),
              let toZoneRange = Range(match.range(at: 5), in: input)
        else {
            return nil
        }

        let hourStr = String(input[hourRange])
        let minuteStr = extractMinute(from: input, match: match)
        let isPM = extractAmPm(from: input, match: match)

        let fromZoneStr = String(input[fromZoneRange])
        let toZoneStr = String(input[toZoneRange])

        // Parse hour
        guard var hour = Int(hourStr),
              let minute = Int(minuteStr),
              minute >= 0, minute < 60
        else {
            return nil
        }

        // Validate hour
        let hasAmPm = match.range(at: 3).location != NSNotFound
        guard validateHour(hour, isPM: isPM, hasAmPm: hasAmPm) else { return nil }

        // Convert to 24-hour format
        hour = convertTo24Hour(hour: hour, isPM: isPM, hasAmPm: hasAmPm)

        return ParsedTimeConversion(hour24: hour, minute: minute, fromZone: fromZoneStr, toZone: toZoneStr)
    }

    private func extractMinute(from input: String, match: NSTextCheckingResult) -> String {
        let minuteRange = match.range(at: 2)
        if minuteRange.location != NSNotFound, let minRange = Range(minuteRange, in: input) {
            return String(input[minRange])
        }
        return "0"
    }

    private func extractAmPm(from input: String, match: NSTextCheckingResult) -> Bool {
        let ampmRange = match.range(at: 3)
        if ampmRange.location != NSNotFound, let ampm = Range(ampmRange, in: input) {
            return String(input[ampm]).lowercased() == "pm"
        }
        return false
    }

    private func validateHour(_ hour: Int, isPM _: Bool, hasAmPm: Bool) -> Bool {
        if hasAmPm {
            hour >= 1 && hour <= 12
        } else {
            hour >= 0 && hour <= 23
        }
    }

    private func convertTo24Hour(hour: Int, isPM: Bool, hasAmPm: Bool) -> Int {
        var hour24 = hour
        if isPM, hour != 12 {
            hour24 += 12
        } else if !isPM, hour == 12, hasAmPm {
            hour24 = 0
        }
        return hour24
    }

    /// Get current time in a city
    func currentTime(in city: String) -> String? {
        let trimmed = city.trimmingCharacters(in: .whitespaces).lowercased()
        guard let timeZoneIdentifier = resolveTimeZone(trimmed),
              let timeZone = TimeZone(identifier: timeZoneIdentifier)
        else {
            return nil
        }

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = timeZone

        let timeString = formatter.string(from: now)
        let displayName = getDisplayName(for: trimmed)

        return "\(timeString) \(displayName)"
    }

    /// Get list of frequent time zones with current times
    func getFrequentTimeZones() -> [String] {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        return frequentTimeZones.compactMap { name, identifier -> String? in
            guard let timeZone = TimeZone(identifier: identifier) else { return nil }
            formatter.timeZone = timeZone
            let timeString = formatter.string(from: now)
            return "\(timeString) \(name)"
        }
    }

    // MARK: - Search Integration

    /// Search for time conversions
    func search(query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowercased = trimmed.lowercased()

        // Check for "time zones" keyword
        if lowercased == "time zones" || lowercased == "timezone" || lowercased == "time zone" {
            let zones = getFrequentTimeZones()
            return zones.map { zone in
                SearchResult(
                    title: zone,
                    subtitle: "Frequent Time Zone",
                    icon: NSImage(systemSymbolName: "clock", accessibilityDescription: "Time Zone"),
                    category: .conversion,
                    action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(zone, forType: .string)
                    },
                    score: 2000
                )
            }
        }

        // Check for time conversion expression
        if isTimeConversionExpression(trimmed) {
            if let result = convert(trimmed) {
                let icon = NSImage(
                    systemSymbolName: "clock.arrow.circlepath",
                    accessibilityDescription: "Time Zone Converter"
                )
                return [SearchResult(
                    title: result,
                    subtitle: "Time Zone Conversion",
                    icon: icon,
                    category: .conversion,
                    action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result, forType: .string)
                    },
                    score: 2000
                )]
            }
        }

        // Check for "time in" expression
        if isTimeInExpression(trimmed) {
            let range = NSRange(lowercased.startIndex..., in: lowercased)
            guard let regex = try? NSRegularExpression(pattern: timeInPattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: lowercased, options: [], range: range),
                  let cityRange = Range(match.range(at: 1), in: lowercased)
            else {
                return []
            }
            let city = String(lowercased[cityRange])
            if let result = currentTime(in: city) {
                return [SearchResult(
                    title: result,
                    subtitle: "Current Time",
                    icon: NSImage(systemSymbolName: "clock", accessibilityDescription: "Time"),
                    category: .conversion,
                    action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result, forType: .string)
                    },
                    score: 2000
                )]
            }
        }

        return []
    }

    // MARK: - Private Helpers

    /// Resolve a city name or abbreviation to a TimeZone identifier
    private func resolveTimeZone(_ input: String) -> String? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)

        // Check city names first
        if let identifier = cityToTimeZone[lowercased] {
            return identifier
        }

        // Check abbreviations
        if let identifier = abbreviationToTimeZone[lowercased] {
            return identifier
        }

        // Try as direct TimeZone identifier
        if TimeZone.knownTimeZoneIdentifiers.contains(lowercased) {
            return lowercased
        }

        // Try case-insensitive direct match
        for identifier in TimeZone.knownTimeZoneIdentifiers where identifier.lowercased() == lowercased {
            return identifier
        }

        return nil
    }

    /// Get display name for a city/zone
    private func getDisplayName(for input: String) -> String {
        let lowercased = input.lowercased()
        if abbreviationToTimeZone[lowercased] != nil {
            return input.uppercased()
        }
        // Capitalize city name
        return lowercased.split(separator: " ")
            .map(\.capitalized)
            .joined(separator: " ")
    }

    /// Convert time from one zone to another
    private func convertTime(
        hour: Int,
        minute: Int,
        from sourceTimeZone: String,
        to destTimeZone: String,
        toZoneName: String
    ) -> String? {
        guard let sourceTZ = TimeZone(identifier: sourceTimeZone),
              let destTZ = TimeZone(identifier: destTimeZone)
        else {
            return nil
        }

        // Create a date for the given time in the source timezone
        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(in: sourceTZ, from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.nanosecond = 0

        guard let sourceDate = calendar.date(from: components) else {
            return nil
        }

        // Format in destination timezone
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = destTZ

        let timeString = formatter.string(from: sourceDate)
        let displayName = getDisplayName(for: toZoneName)

        return "\(timeString) \(displayName)"
    }
}

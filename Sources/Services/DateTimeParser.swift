import Foundation

// MARK: - Time Components

/// Represents parsed time components (hour and minute)
struct TimeComponents: Equatable {
    let hour: Int
    let minute: Int
}

// MARK: - Date Time Parser

/// Parses natural language date and time strings into Date objects
final class DateTimeParser {
    // MARK: - Singleton

    static let shared = DateTimeParser()

    // MARK: - Properties

    private let calendar = Calendar.current

    // MARK: - Initialization

    private init() {}

    // MARK: - Date Parsing

    /// Parse a date string into a Date object
    /// Supports: "tomorrow", "today", MM/DD/YYYY, DD/MM/YYYY, YYYY-MM-DD, "March 15", "next Monday"
    /// - Parameter dateString: The date string to parse
    /// - Returns: A Date object, or nil if parsing failed
    func parseDate(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Handle relative dates
        if trimmed == "today" {
            return calendar.startOfDay(for: Date())
        }

        if trimmed == "tomorrow" {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())
            return tomorrow.map { calendar.startOfDay(for: $0) }
        }

        // Handle "next [day]" patterns
        if trimmed.hasPrefix("next ") {
            return parseNextWeekday(String(trimmed.dropFirst(5)))
        }

        // Handle "this [day]" patterns
        if trimmed.hasPrefix("this ") {
            return parseThisWeekday(String(trimmed.dropFirst(5)))
        }

        // Try ISO format: YYYY-MM-DD
        if let date = parseISODate(trimmed) {
            return date
        }

        // Try slash format: MM/DD/YYYY or DD/MM/YYYY
        if let date = parseSlashDate(trimmed) {
            return date
        }

        // Try month name format: "March 15" or "15th March"
        if let date = parseMonthNameDate(trimmed) {
            return date
        }

        return nil
    }

    // MARK: - Time Parsing

    /// Parse a time string into TimeComponents
    /// Supports: "10:15 AM", "3pm", "9am", "14:00"
    /// - Parameter timeString: The time string to parse
    /// - Returns: TimeComponents, or nil if parsing failed
    func parseTime(_ timeString: String) -> TimeComponents? {
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Pattern: HH:MM AM/PM (with or without space)
        let withMinutesPattern = #"^(\d{1,2}):(\d{2})\s*(am|pm)?$"#
        if let match = trimmed.firstMatch(of: withMinutesPattern) {
            let hourStr = String(match.1)
            let minuteStr = String(match.2)
            let ampmStr = String(match.3)

            guard var hour = Int(hourStr), let minute = Int(minuteStr) else {
                return nil
            }

            // Handle AM/PM conversion
            let ampm = ampmStr.lowercased()
            if !ampm.isEmpty {
                if ampm == "pm" && hour != 12 {
                    hour += 12
                } else if ampm == "am" && hour == 12 {
                    hour = 0
                }
            }

            return TimeComponents(hour: hour, minute: minute)
        }

        // Pattern: H AM/PM (e.g., "3pm")
        let hourOnlyPattern = #"^(\d{1,2})\s*(am|pm)$"#
        if let match = trimmed.firstMatch(of: hourOnlyPattern) {
            let hourStr = String(match.1)
            let ampm = match.2

            guard var hour = Int(hourStr) else {
                return nil
            }

            // Handle AM/PM conversion
            if ampm == "pm" && hour != 12 {
                hour += 12
            } else if ampm == "am" && hour == 12 {
                hour = 0
            }

            return TimeComponents(hour: hour, minute: 0)
        }

        return nil
    }

    // MARK: - Combine Date and Time

    /// Combine a date with time components
    /// - Parameters:
    ///   - date: The base date
    ///   - time: Optional time components (defaults to 9:00 AM)
    /// - Returns: A Date with both date and time components
    func combine(date: Date, withTime time: TimeComponents?) -> Date {
        let time = time ?? TimeComponents(hour: 9, minute: 0)

        return calendar.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: date
        ) ?? date
    }

    // MARK: - Private Helpers

    private func parseISODate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }

    private func parseSlashDate(_ string: String) -> Date? {
        let parts = string.split(separator: "/").map { Int($0) }
        guard parts.count == 3,
              let first = parts[0],
              let second = parts[1],
              let year = parts[2] else {
            return nil
        }

        // Determine format: DD/MM/YYYY vs MM/DD/YYYY
        // - If first > 12: first is day (DD/MM/YYYY)
        // - If second > 12: second is day (MM/DD/YYYY) 
        // - If both <= 12: use DD/MM/YYYY (most common worldwide)
        let month: Int
        let day: Int

        if first > 12 {
            // First can't be month, must be day -> DD/MM/YYYY
            day = first
            month = second
        } else if second > 12 {
            // Second can't be month, must be day -> MM/DD/YYYY
            month = first
            day = second
        } else {
            // Both could be month or day - prefer DD/MM/YYYY (international standard)
            day = first
            month = second
        }

        print("📅 parseSlashDate: '\(string)' -> day=\(day), month=\(month), year=\(year)")

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        return calendar.date(from: components)
    }

    private func parseMonthNameDate(_ string: String) -> Date? {
        let monthNames = [
            "january": 1, "february": 2, "march": 3, "april": 4,
            "may": 5, "june": 6, "july": 7, "august": 8,
            "september": 9, "october": 10, "november": 11, "december": 12
        ]

        // Pattern: "Month Day" (e.g., "March 15")
        let monthFirstPattern = #"^(\w+)\s+(\d{1,2})(?:st|nd|rd|th)?$"#
        if let match = string.firstMatch(of: monthFirstPattern) {
            let monthName = String(match.1)
            let dayStr = String(match.2)

            if let month = monthNames[monthName], let day = Int(dayStr) {
                return createDate(month: month, day: day)
            }
        }

        // Pattern: "Day Month" (e.g., "15th March")
        let dayFirstPattern = #"^(\d{1,2})(?:st|nd|rd|th)?\s+(\w+)$"#
        if let match = string.firstMatch(of: dayFirstPattern) {
            let dayStr = String(match.1)
            let monthName = String(match.2)

            if let month = monthNames[monthName], let day = Int(dayStr) {
                return createDate(month: month, day: day)
            }
        }

        return nil
    }

    private func parseNextWeekday(_ weekdayString: String) -> Date? {
        let weekdays = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]

        guard let targetWeekday = weekdays[weekdayString] else {
            return nil
        }

        let currentWeekday = calendar.component(.weekday, from: Date())

        // Calculate days to add
        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7 // Move to next week
        }

        // If same day, still move to next week
        if daysToAdd == 0 {
            daysToAdd = 7
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: Date())
            .map { calendar.startOfDay(for: $0) }
    }

    private func parseThisWeekday(_ weekdayString: String) -> Date? {
        let weekdays = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]

        guard let targetWeekday = weekdays[weekdayString] else {
            return nil
        }

        let currentWeekday = calendar.component(.weekday, from: Date())

        // Calculate days to add
        var daysToAdd = targetWeekday - currentWeekday

        // If the day has passed this week, move to next week
        if daysToAdd < 0 {
            daysToAdd += 7
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: Date())
            .map { calendar.startOfDay(for: $0) }
    }

    private func createDate(month: Int, day: Int) -> Date? {
        let currentYear = calendar.component(.year, from: Date())

        var components = DateComponents()
        components.year = currentYear
        components.month = month
        components.day = day

        guard let initialDate = calendar.date(from: components) else {
            return nil
        }

        // If the date has passed, use next year
        if initialDate < calendar.startOfDay(for: Date()) {
            components.year = currentYear + 1
            return calendar.date(from: components)
        }

        return initialDate
    }
}

// MARK: - String Regex Extension

private extension String {
    /// Match against a regex pattern and return capture groups
    func firstMatch(of pattern: String) -> (Substring, Substring, Substring, Substring)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)) else {
            return nil
        }

        // Get full match
        guard let fullRange = Range(match.range, in: self) else {
            return nil
        }
        let fullMatch = self[fullRange]

        // Get capture groups safely
        let group1: Substring
        let group2: Substring
        let group3: Substring

        if match.numberOfRanges >= 2, let range = Range(match.range(at: 1), in: self) {
            group1 = self[range]
        } else {
            group1 = ""
        }

        if match.numberOfRanges >= 3, let range = Range(match.range(at: 2), in: self) {
            group2 = self[range]
        } else {
            group2 = ""
        }

        if match.numberOfRanges >= 4, let range = Range(match.range(at: 3), in: self) {
            group3 = self[range]
        } else {
            group3 = ""
        }

        return (fullMatch, group1, group2, group3)
    }
}

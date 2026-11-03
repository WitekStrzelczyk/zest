import Foundation

struct TimeComponents: Equatable {
    let hour: Int
    let minute: Int
}

final class DateTimeParser {
    static let shared = DateTimeParser()

    private let calendar = Calendar.current

    private init() {}

    func parseDate(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed == "today" {
            return calendar.startOfDay(for: Date())
        }

        if trimmed == "yesterday" {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())
            return yesterday.map { calendar.startOfDay(for: $0) }
        }

        if trimmed == "tomorrow" {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())
            return tomorrow.map { calendar.startOfDay(for: $0) }
        }

        if let date = parseRelativeOffset(trimmed) {
            return date
        }

        if let date = parseLastUnit(trimmed) {
            return date
        }

        if trimmed.hasPrefix("next ") {
            return parseNextWeekday(String(trimmed.dropFirst(5)))
        }

        let periods: [String: Calendar.Component] = ["this week": .weekOfYear, "this month": .month, "this year": .year]
        if let period = periods[trimmed] {
            return calendar.dateInterval(of: period, for: Date())?.start
        }

        if trimmed.hasPrefix("this ") {
            return parseThisWeekday(String(trimmed.dropFirst(5)))
        }

        if let date = parseISODate(trimmed) {
            return date
        }

        if let date = parseSlashDate(trimmed) {
            return date
        }

        if let date = parseMonthNameDate(trimmed) {
            return date
        }

        return nil
    }

    private func parseLastUnit(_ string: String) -> Date? {
        let pattern = #"^last\s+(minute|hour|day|week|month|year)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string))
        else {
            return nil
        }

        guard let unitRange = Range(match.range(at: 1), in: string) else {
            return nil
        }

        let unit = string[unitRange].lowercased()
        let component: Calendar.Component
        switch unit {
        case "minute": component = .minute
        case "hour": component = .hour
        case "day": component = .day
        case "week": component = .weekOfYear
        case "month": component = .month
        case "year": component = .year
        default: return nil
        }

        let date = calendar.date(byAdding: component, value: -1, to: Date())

        if ["day", "week", "month", "year"].contains(unit) {
            return date.map { calendar.startOfDay(for: $0) }
        }

        return date
    }

    private func parseRelativeOffset(_ string: String) -> Date? {
        let pattern = #"^(\d+)\s+(minute|hour|day|week|month|year)s?\s+ago$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string))
        else {
            return nil
        }

        guard let numRange = Range(match.range(at: 1), in: string),
              let num = Int(string[numRange]),
              let unitRange = Range(match.range(at: 2), in: string)
        else {
            return nil
        }

        let unit = string[unitRange].lowercased()
        let component: Calendar.Component
        switch unit {
        case "minute": component = .minute
        case "hour": component = .hour
        case "day": component = .day
        case "week": component = .weekOfYear
        case "month": component = .month
        case "year": component = .year
        default: return nil
        }

        let date = calendar.date(byAdding: component, value: -num, to: Date())

        if ["day", "week", "month", "year"].contains(unit) {
            return date.map { calendar.startOfDay(for: $0) }
        }

        return date
    }

    func parseTime(_ timeString: String) -> TimeComponents? {
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let time = parseTimeWithMinutes(trimmed) {
            return time
        }

        if let time = parseHourOnly(trimmed) {
            return time
        }

        return nil
    }

    private func parseTimeWithMinutes(_ trimmed: String) -> TimeComponents? {
        let withMinutesPattern = #"^(\d{1,2}):(\d{2})\s*(am|pm)?$"#
        guard let match = trimmed.firstMatch(of: withMinutesPattern) else {
            return nil
        }

        let hourStr = String(match.1)
        let minuteStr = String(match.2)
        let ampmStr = String(match.3)

        guard var hour = Int(hourStr), let minute = Int(minuteStr) else {
            return nil
        }

        hour = convertTo24Hour(hour: hour, ampm: ampmStr.lowercased())

        return TimeComponents(hour: hour, minute: minute)
    }

    private func parseHourOnly(_ trimmed: String) -> TimeComponents? {
        let hourOnlyPattern = #"^(\d{1,2})\s*(am|pm)$"#
        guard let match = trimmed.firstMatch(of: hourOnlyPattern) else {
            return nil
        }

        let hourStr = String(match.1)
        let ampm = match.2

        guard var hour = Int(hourStr) else {
            return nil
        }

        hour = convertTo24Hour(hour: hour, ampm: String(ampm))

        return TimeComponents(hour: hour, minute: 0)
    }

    private func convertTo24Hour(hour: Int, ampm: String) -> Int {
        if ampm.isEmpty {
            return hour
        }

        if ampm == "pm", hour != 12 {
            return hour + 12
        } else if ampm == "am", hour == 12 {
            return 0
        }

        return hour
    }

    func combine(date: Date, withTime time: TimeComponents?) -> Date {
        let time = time ?? TimeComponents(hour: 9, minute: 0)

        return calendar.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: date
        ) ?? date
    }

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
              let year = parts[2]
        else {
            return nil
        }

        let month: Int
        let day: Int

        if first > 12 {
            day = first
            month = second
        } else if second > 12 {
            month = first
            day = second
        } else {
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
            "september": 9, "october": 10, "november": 11, "december": 12,
        ]

        let monthFirstPattern = #"^(\w+)\s+(\d{1,2})(?:st|nd|rd|th)?$"#
        if let match = string.firstMatch(of: monthFirstPattern) {
            let monthName = String(match.1)
            let dayStr = String(match.2)

            if let month = monthNames[monthName], let day = Int(dayStr) {
                return createDate(month: month, day: day)
            }
        }

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
            "thursday": 5, "friday": 6, "saturday": 7,
        ]

        guard let targetWeekday = weekdays[weekdayString] else {
            return nil
        }

        let currentWeekday = calendar.component(.weekday, from: Date())

        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7
        }

        if daysToAdd == 0 {
            daysToAdd = 7
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: Date())
            .map { calendar.startOfDay(for: $0) }
    }

    private func parseThisWeekday(_ weekdayString: String) -> Date? {
        let weekdays = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7,
        ]

        guard let targetWeekday = weekdays[weekdayString] else {
            return nil
        }

        let currentWeekday = calendar.component(.weekday, from: Date())

        var daysToAdd = targetWeekday - currentWeekday

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

        if initialDate < calendar.startOfDay(for: Date()) {
            components.year = currentYear + 1
            return calendar.date(from: components)
        }

        return initialDate
    }
}

private extension String {
    func firstMatch(of pattern: String) -> (Substring, Substring, Substring, Substring)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self))
        else {
            return nil
        }

        guard let fullRange = Range(match.range, in: self) else {
            return nil
        }
        let fullMatch = self[fullRange]

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

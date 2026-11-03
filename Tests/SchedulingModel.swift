import Foundation
import FoundationModels

struct CalendarSnapshot: Decodable {
    struct Event: Decodable {
        let title: String
        let start: Date
        let end: Date
        let location: String?
    }

    let now: Date
    let timeZone: String
    let events: [Event]

    static func load(_ url: URL) throws -> CalendarSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CalendarSnapshot.self, from: Data(contentsOf: url))
    }
}

enum Relation: String, CaseIterable {
    case after
    case before
    case sameTime
    case dayAfter
    case none
}

enum PartOfDay: String, CaseIterable {
    case morning
    case midday
    case afternoon
    case evening
    case night

    var hour: Int {
        switch self {
        case .morning: 9
        case .midday: 12
        case .afternoon: 14
        case .evening: 18
        case .night: 20
        }
    }
}

struct CalendarRequestDraft {
    let title: String
    let people: [String]
    let place: String
    let day: String?
    let relation: Relation
    let event: String?
    let gapMinutes: Int?
    let durationMinutes: Int?
    let json: String
}

struct CalendarCategories {
    let title: String
    let people: [String]
    let place: String?
    let day: Date?
    let start: Date?
    let end: Date?
    let durationMinutes: Int?

    var missing: [String] {
        [("date", day == nil), ("time", start == nil), ("duration", durationMinutes == nil)]
            .filter(\.1)
            .map(\.0)
    }
}

@available(macOS 26.0, *)
struct CalendarExtraction {
    static let defaultDurationMinutes = 30
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    private static let dayWord = #/(?i)\b(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b|\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b|\b(today|tonight|tomorrow|tmrw)\b|\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\b|\bin\s+\S+\s+(days|weeks)\b|\b\S+\s+weeks?\s+from\b|\bfortnight\b|\d+(st|nd|rd|th)\b|\b(twelfth|eleventh|tenth|ninth|eighth|seventh|sixth|fifth|fourth|third|second|first)\b/#
    private static let ordinal = #/\b(\d{1,2})(st|nd|rd|th)\b/#
    private static let relative = #/\s+(buffer\s+)?(after|before|ahead|prior|earlier|later)\b/#
    private static let timeWord = #/(?i)\d{1,2}[:.]\d{2}|\d\s*(am|pm|a\.m\.|p\.m\.)|\bat\s+\d|\b(noon|midday|morning|afternoon|arvo|evening|tonight|night)\b/#
    private static let explicitTime = #/(?i)(am|pm|a\.m\.|p\.m\.)|\b(morning|afternoon|arvo|evening|tonight|night)\b|\b(0\d|1[3-9]|2[0-3])[:.]\d{2}/#
    private static let partsOfDay: [String: PartOfDay] = [
        "morning": .morning, "midday": .midday, "noon": .midday, "afternoon": .afternoon, "arvo": .afternoon,
        "evening": .evening, "tonight": .evening, "night": .night,
    ]
    private static let length = #/(\d+|[a-z]+(?:-[a-z]+)?)[\s-]*(minutes|minute|mins|min|m|hours|hour|hrs|hr|h)\b/#
    private static let spokenTimes: [(pattern: Regex<(Substring, Substring)>, minute: Int, hourShift: Int)] = [
        (#/\bquarter\s+(?:past|after)\s+(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b/#, 15, 0),
        (#/\bquarter\s+(?:to|of)\s+(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b/#, 45, -1),
        (#/\bhalf\s+past\s+(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b/#, 30, 0),
        (#/\bhalf\s+(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b/#, 30, 0),
        (#/\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+fifteen\b/#, 15, 0),
        (#/\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+thirty\b/#, 30, 0),
        (#/\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+forty[-\s]five\b/#, 45, 0),
        (#/\b(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s*o'?clock\b/#, 0, 0),
        (#/\b(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+(?:in\s+the\s+(?:morning|afternoon|evening)|at\s+night|tonight)\b/#, 0, 0),
        (#/\bat\s+(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b(?!\s*(?:min|hour|hr|h\b|m\b|st\b|nd\b|rd\b|th\b|[:.]\d|%))/#, 0, 0),
    ]
    private static let morningWord = #/\bmorning\b|(?:\d|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|fifteen|thirty|five|clock)\s*(?:am|a\.m\.)/#
    private static let eveningWord = #/\b(?:afternoon|arvo|evening|tonight|night)\b|(?:\d|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|fifteen|thirty|five|clock)\s*(?:pm|p\.m\.)/#
    private static let weeksFrom = #/\b(\d{1,2}|a|one|two|three|four|five|six)\s+weeks?\s+(?:from\s+(?:now|today)|time)\b/#
    private static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
    private static let month = #/\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b/#
    private static let ordinalWords = [
        "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
        "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth", "seventeenth", "eighteenth",
        "nineteenth", "twentieth", "twenty-first", "twenty-second", "twenty-third", "twenty-fourth", "twenty-fifth",
        "twenty-sixth", "twenty-seventh", "twenty-eighth", "twenty-ninth", "thirtieth", "thirty-first",
    ]
    private static let spelled: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .spellOut
        return formatter
    }()

    let snapshot: CalendarSnapshot
    let calendar: Calendar
    let events: [CalendarSnapshot.Event]

    init(snapshot: CalendarSnapshot) {
        self.snapshot = snapshot
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: snapshot.timeZone) ?? .current
        self.calendar = calendar
        events = snapshot.events.sorted { $0.start < $1.start }
    }

    var titles: [String] {
        events.map(\.title).reduce(into: []) { titles, title in
            if !titles.contains(title) { titles.append(title) }
        }
    }

    var instructions: String {
        let list = events.map { "\(Self.format($0.start, "EEE HH:mm", calendar)) \($0.title)" }
        return """
        Read one sentence asking for a new calendar event. The app reads dates and clock times itself. You give:
        title: a short title for the new event.
        people: names of the people at the new event, not people named only to point at another event.
        place: where the new event happens, as written, or none.
        day: only when the sentence names a day, that day in plain English a date parser reads, \
        like a weekday name, a date with its month, or "in N days".
        relation and event: when the new event is placed against an existing event. \
        after: starts after it ends. before: ends before it starts. sameTime: at its clock time. \
        dayAfter: on the day after it. A person's name can point at their meeting.
        gapMinutes: only when the sentence states the minutes between the existing event and the new one.
        durationMinutes: only when the sentence states how long the new event lasts.
        DO NOT fill a field the sentence does not give.

        Examples (with another calendar):
        "tea with Ben twenty mins after the design sync" → people Ben; relation after, event Design sync, gapMinutes 20
        "40m review right before the client demo" → relation before, event Client demo, durationMinutes 40
        "haircut sat at 10" → day saturday; relation none
        "call the bank" → place none; relation none

        Today is \(Self.format(snapshot.now, "EEEE d MMMM", calendar)). Calendar:
        \(list.joined(separator: "\n"))
        """
    }

    func schema() throws -> GenerationSchema {
        let text = DynamicGenerationSchema(type: String.self)
        let number = { (range: ClosedRange<Int>) in DynamicGenerationSchema(type: Int.self, guides: [.range(range)]) }
        let optional = { (name: String, schema: DynamicGenerationSchema) in
            DynamicGenerationSchema.Property(name: name, schema: schema, isOptional: true)
        }
        let root = DynamicGenerationSchema(name: "CalendarRequest", properties: [
            .init(name: "title", schema: text),
            .init(name: "people", schema: DynamicGenerationSchema(arrayOf: text)),
            .init(name: "place", schema: text),
            optional("day", text),
            .init(name: "relation", schema: DynamicGenerationSchema(name: "Relation", anyOf: Relation.allCases.map(\.rawValue))),
            optional("event", DynamicGenerationSchema(name: "Event", anyOf: titles)),
            optional("gapMinutes", number(1...720)),
            optional("durationMinutes", number(5...720)),
        ])
        return try GenerationSchema(root: root, dependencies: [])
    }

    func draft(from content: GeneratedContent) throws -> CalendarRequestDraft {
        let string = { (name: String) in
            (try? content.value(String.self, forProperty: name)).flatMap { Self.isBlank($0) ? nil : $0 }
        }
        let integer = { (name: String) in try? content.value(Int.self, forProperty: name) }
        return try CalendarRequestDraft(
            title: content.value(String.self, forProperty: "title"),
            people: content.value([String].self, forProperty: "people"),
            place: content.value(String.self, forProperty: "place"),
            day: string("day"),
            relation: Relation(rawValue: content.value(String.self, forProperty: "relation")) ?? .none,
            event: string("event"),
            gapMinutes: integer("gapMinutes"),
            durationMinutes: integer("durationMinutes"),
            json: content.jsonString
        )
    }

    func categories(from draft: CalendarRequestDraft, sentence: String) -> CalendarCategories {
        let detected = detect(sentence)
        let named = sentence.contains(Self.dayWord)
        let writtenDay = relativeDay(in: sentence) ?? ordinalDay(in: sentence) ?? detected.day ?? (named ? draft.day.flatMap { detect($0).day } : nil)
        let stated = Self.statedMinutes(in: sentence)
        let duration = stated.lengths.count == 1 ? stated.lengths.first : draft.durationMinutes.flatMap { stated.lengths.contains($0) ? $0 : nil }
        let gap = (stated.gaps.count == 1 ? stated.gaps.first : draft.gapMinutes.flatMap { stated.gaps.contains($0) ? $0 : nil }) ?? 0
        let length = TimeInterval((duration ?? Self.defaultDurationMinutes) * 60)
        let anchor = draft.event.flatMap { Self.mentions($0, in: sentence) ? occurrence(of: $0, on: writtenDay) : nil }
        let dayAfterUnsaid = draft.relation == .dayAfter && detected.day != nil
        let relation = anchor == nil || dayAfterUnsaid ? .none : draft.relation

        let clock = Self.spokenClock(in: sentence) ?? detected.clock

        let start: Date? = switch (relation, clock) {
        case (.after, nil):
            anchor.map { $0.end.addingTimeInterval(TimeInterval(gap * 60)) }
        case (.before, nil):
            anchor.map { $0.start.addingTimeInterval(-TimeInterval(gap * 60) - length) }
        case (.sameTime, nil):
            anchor.flatMap { event in
                let time = calendar.dateComponents([.hour, .minute], from: event.start)
                return combine(writtenDay ?? calendar.startOfDay(for: event.start), time.hour ?? 0, time.minute ?? 0)
            }
        case let (.dayAfter, clock?):
            anchor.flatMap { shift(calendar.startOfDay(for: $0.start), days: 1) }.flatMap { combine($0, clock.hour, clock.minute) }
        case let (_, clock?):
            (writtenDay ?? anchor.map { calendar.startOfDay(for: $0.start) }).flatMap { combine($0, clock.hour, clock.minute) }
        default:
            nil
        }
        let dayAfter = relation == .dayAfter ? anchor.flatMap { shift(calendar.startOfDay(for: $0.start), days: 1) } : nil

        return CalendarCategories(
            title: draft.title,
            people: draft.people.filter { Self.appears($0, in: sentence) },
            place: Self.appears(draft.place, in: sentence) && !Self.isBlank(draft.place) ? draft.place : nil,
            day: start.map { calendar.startOfDay(for: $0) } ?? dayAfter ?? writtenDay,
            start: start,
            end: start?.addingTimeInterval(length),
            durationMinutes: duration
        )
    }

    private func detect(_ text: String) -> (day: Date?, clock: (hour: Int, minute: Int)?) {
        let matches = Self.detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        let found = matches.compactMap { match in
            Range(match.range, in: text).flatMap { range in match.date.map { (span: String(text[range]), date: $0) } }
        }
        let day = found.first { $0.span.contains(Self.dayWord) }.map { calendar.startOfDay(for: $0.date) }
        let clock = found.first { $0.span.contains(Self.timeWord) }.map { clock(of: $0.date, span: $0.span) }
        return (day, clock)
    }

    private func relativeDay(in sentence: String) -> Date? {
        let text = sentence.lowercased()
        let today = calendar.startOfDay(for: snapshot.now)
        if text.contains("fortnight") { return shift(today, days: 14) }
        guard let match = text.firstMatch(of: Self.weeksFrom) else { return nil }
        let word = String(match.1)
        return (Int(word) ?? (word == "a" ? 1 : Self.spelled.number(from: word)?.intValue)).flatMap { shift(today, days: $0 * 7) }
    }

    private func ordinalDay(in sentence: String) -> Date? {
        let text = sentence.lowercased()
        let monthIndex = text.firstMatch(of: Self.month).flatMap { Self.months.firstIndex(of: String($0.1)) }
        let monthWord = text.firstMatch(of: Self.month).map { String($0.0) }
        let spelled = Self.ordinalWords.indices.reversed().first { index in
            let word = Self.ordinalWords[index]
            return text.contains("the \(word)") || text.contains("\(word) of") || monthWord.map { text.contains("\($0) \(word)") } == true
        }
        guard let day = text.firstMatch(of: Self.ordinal).flatMap({ Int($0.1) }) ?? spelled.map({ $0 + 1 }) else { return nil }
        let today = calendar.startOfDay(for: snapshot.now)
        var components = calendar.dateComponents([.year, .month], from: today)
        components.day = day
        if let monthIndex { components.month = monthIndex + 1 }
        guard let candidate = calendar.date(from: components) else { return nil }
        guard candidate < today else { return candidate }
        return calendar.date(byAdding: monthIndex == nil ? .month : .year, value: 1, to: candidate)
    }

    private static func spokenClock(in sentence: String) -> (hour: Int, minute: Int)? {
        let text = sentence.lowercased()
        if text.contains(#/\bmidnight\b/#) { return (0, 0) }
        if text.contains(#/\b(?:noon|midday)\b/#) { return (12, 0) }
        let found = spokenTimes.lazy.compactMap { spoken in
            text.firstMatch(of: spoken.pattern).flatMap { match in
                (Int(match.1) ?? spelled.number(from: String(match.1))?.intValue).map { ($0 + spoken.hourShift, spoken.minute) }
            }
        }.first
        guard let (written, minute) = found, (0...23).contains(written) else { return nil }
        let hour = written == 0 ? 12 : written
        if text.contains(morningWord) { return (hour == 12 ? 0 : hour, minute) }
        let pm = text.contains(eveningWord) || (1...7).contains(hour)
        return (hour < 12 && pm ? hour + 12 : hour, minute)
    }

    private func clock(of date: Date, span: String) -> (hour: Int, minute: Int) {
        let time = calendar.dateComponents([.hour, .minute], from: date)
        let hour = time.hour ?? 0
        let minute = time.minute ?? 0
        let words = span.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        if let part = words.lazy.compactMap({ Self.partsOfDay[$0] }).first, !span.contains(where: \.isNumber) {
            return (part.hour, 0)
        }
        guard !span.contains(Self.explicitTime) else { return (hour, minute) }
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return ((1...7).contains(twelve) ? twelve + 12 : twelve, minute)
    }

    private static func statedMinutes(in sentence: String) -> (gaps: Set<Int>, lengths: Set<Int>) {
        var text = sentence.lowercased()
        var stated: [(minutes: Int, gap: Bool)] = []
        for (phrase, minutes) in [("quarter of an hour", 15), ("quarter hour", 15), ("half an hour", 30), ("half hour", 30)] {
            while let range = text.range(of: phrase) {
                stated.append((minutes, text[range.upperBound...].prefixMatch(of: relative) != nil))
                text.replaceSubrange(range, with: "_")
            }
        }
        for match in text.matches(of: length) {
            let word = String(match.1)
            guard Int(word) != nil || match.2 != "m" else { continue }
            guard let count = Int(word) ?? (["a", "an"].contains(word) ? 1 : spelled.number(from: word)?.intValue) else {
                continue
            }
            stated.append((match.2.hasPrefix("h") ? count * 60 : count, text[match.range.upperBound...].prefixMatch(of: relative) != nil))
        }
        return (Set(stated.filter(\.gap).map(\.minutes)), Set(stated.filter { !$0.gap }.map(\.minutes)))
    }

    private static func mentions(_ title: String, in sentence: String) -> Bool {
        let text = sentence.lowercased()
        return title.lowercased().split(separator: " ").contains { word in
            !["with", "meeting", "review", "the", "and"].contains(String(word)) && text.contains(word)
        }
    }

    private func occurrence(of title: String, on day: Date?) -> CalendarSnapshot.Event? {
        let matching = events.filter { $0.title == title }
        let onDay = day.flatMap { day in matching.first { calendar.isDate($0.start, inSameDayAs: day) } }
        return onDay ?? matching.first { $0.end >= snapshot.now } ?? matching.last
    }

    private func shift(_ date: Date, days: Int) -> Date? {
        calendar.date(byAdding: .day, value: days, to: date)
    }

    private func combine(_ day: Date, _ hour: Int, _ minute: Int) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    private static func appears(_ words: String, in sentence: String) -> Bool {
        let squeeze = { (text: String) in text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        return squeeze(sentence).contains(squeeze(words))
    }

    private static func isBlank(_ value: String) -> Bool {
        ["", "none", "unknown", "empty", "null"].contains(value.lowercased().trimmingCharacters(in: .whitespaces))
    }

    static func format(_ date: Date, _ pattern: String, _ calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

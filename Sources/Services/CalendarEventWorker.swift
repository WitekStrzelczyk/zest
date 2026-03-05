import Foundation

struct CalendarEventIntent {
    var title: String
    var date: Date?
    var location: String?
}

class CalendarEventWorker {
    static let shared = CalendarEventWorker()
    private init() {}

    func parse(context: QueryContext) -> CalendarEventIntent? {
        let lower = context.normalized.lowercased()

        // Safety: Explicitly exclude keywords from other tools
        let exclusionKeywords = ["process", "processes", "convert", "calculator", "file", "files"]
        if exclusionKeywords.contains(where: { lower.hasPrefix($0) }) { return nil }

        // Participation Heuristic:
        // Must have a date, or explicitly mention meeting/calendar keywords
        let hasKeywords = ["meeting", "appointment", "schedule", "calendar"].contains { lower.contains($0) }

        guard !context.dates.isEmpty || hasKeywords else { return nil }

        return CalendarEventIntent(
            title: context.semanticTerm.isEmpty ? "Meeting" : context.semanticTerm.capitalized,
            date: context.dates.first,
            location: context.location
        )
    }
}

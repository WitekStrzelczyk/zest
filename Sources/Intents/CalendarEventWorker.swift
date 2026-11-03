import AppKit

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

        let exclusionKeywords = ["process", "processes", "convert", "calculator", "file", "files"]
        if exclusionKeywords.contains(where: { lower.hasPrefix($0) }) { return nil }

        let hasKeywords = ["meeting", "appointment", "schedule", "calendar"].contains { lower.contains($0) }

        guard !context.dates.isEmpty || hasKeywords else { return nil }

        let words = lower.split(separator: " ")
        let person = words.firstIndex(of: "with").flatMap { words.indices.contains($0 + 1) ? String(words[$0 + 1]).capitalized : nil }

        return CalendarEventIntent(
            title: person ?? (context.semanticTerm.isEmpty ? "Meeting" : context.semanticTerm.capitalized),
            date: context.dates.first,
            location: context.location
        )
    }
}

extension CalendarEventWorker: SearchTool {
    private static let icon = NSImage(systemSymbolName: "calendar.badge.plus", accessibilityDescription: "Add Calendar Event")

    var name: String { "Calendar Event" }

    func search(_ context: QueryContext) -> [SearchResult] {
        guard let intent = parse(context: context) else { return [] }
        return [SearchResult(
            title: "Add Event: \(intent.title)",
            subtitle: "Date: \(intent.date?.description ?? "Not specified") | Location: \(intent.location ?? "Not specified")",
            icon: Self.icon,
            category: .calendar,
            action: {
                Task {
                    try? await CalendarService.shared.createEvent(
                        title: intent.title,
                        startDate: intent.date ?? Date().addingTimeInterval(3600),
                        location: intent.location
                    )
                }
            },
            score: 2800
        )]
    }
}

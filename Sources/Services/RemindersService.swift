import EventKit
import Foundation

/// Represents a reminder from the Reminders app
struct Reminder: Identifiable, Hashable {
    let id: String
    let title: String
    let notes: String?
    let dueDate: Date?
    let isCompleted: Bool
    let listName: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Reminder, rhs: Reminder) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages integration with Apple Reminders
final class RemindersService {
    static let shared: RemindersService = .init()

    private let eventStore = EKEventStore()
    private var hasAccess = false

    private init() {}

    // MARK: - Public Methods

    /// Request access to Reminders
    func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToReminders()
                hasAccess = granted
                return granted
            } catch {
                print("Error requesting Reminders access: \(error)")
                return false
            }
        } else {
            // For macOS < 14, use the older API
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error {
                        print("Error requesting Reminders access: \(error)")
                    }
                    self.hasAccess = granted ?? false
                    continuation.resume(returning: granted ?? false)
                }
            }
        }
    }

    /// Fetch all reminders
    func fetchReminders() async -> [Reminder] {
        if !hasAccess {
            let granted = await requestAccess()
            guard granted else { return [] }
        }

        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let result = (reminders ?? []).map { self.convertToReminder($0) }
                continuation.resume(returning: result)
            }
        }
    }

    /// Search reminders by query
    func searchReminders(query: String) async -> [Reminder] {
        let allReminders = await fetchReminders()

        guard !query.isEmpty else { return allReminders }

        let lowercasedQuery = query.lowercased()
        return allReminders.filter { reminder in
            reminder.title.lowercased().contains(lowercasedQuery) ||
                (reminder.notes?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }

    /// Create a new reminder
    func createReminder(title: String, notes: String? = nil, dueDate: Date? = nil) async -> String? {
        if !hasAccess {
            let granted = await requestAccess()
            guard granted else { return nil }
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        if let dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
        }

        do {
            try eventStore.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            print("Error creating reminder: \(error)")
            return nil
        }
    }

    /// Create reminder from natural language (e.g., "remind me to call mom at 5pm")
    func createReminderFromNaturalLanguage(_ input: String) async -> String? {
        // Extract the title and date from natural language
        let lowercasedInput = input.lowercased()

        var title = input
        var dueDate: Date?

        // Parse "remind me to..." pattern
        if lowercasedInput.hasPrefix("remind me to ") {
            title = String(input.dropFirst(13))
        } else if lowercasedInput.hasPrefix("remind me ") {
            title = String(input.dropFirst(10))
        } else if lowercasedInput.hasPrefix("remind ") {
            title = String(input.dropFirst(7))
        }

        // Try to parse date from the input
        dueDate = parseNaturalLanguageDate(input)

        return await createReminder(title: title, notes: nil, dueDate: dueDate)
    }

    /// Mark a reminder as completed
    func completeReminder(id: String) async -> Bool {
        if !hasAccess {
            let granted = await requestAccess()
            guard granted else { return false }
        }

        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            return false
        }

        reminder.isCompleted = true

        do {
            try eventStore.save(reminder, commit: true)
            return true
        } catch {
            print("Error completing reminder: \(error)")
            return false
        }
    }

    /// Parse natural language date
    func parseNaturalLanguageDate(_ input: String) -> Date? {
        let lowercasedInput = input.lowercased()
        let calendar = Calendar.current
        let now = Date()

        // Check for "tomorrow"
        if lowercasedInput.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }

        // Check for "today"
        if lowercasedInput.contains("today") {
            return now
        }

        // Check for "next week"
        if lowercasedInput.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        }

        // Check for day names
        let daysOfWeek = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, day) in daysOfWeek.enumerated() {
            if lowercasedInput.contains(day) {
                let currentWeekday = calendar.component(.weekday, from: now)
                let targetWeekday = index + 1 // Calendar weekday is 1-indexed
                var daysToAdd = targetWeekday - currentWeekday
                if daysToAdd <= 0 {
                    daysToAdd += 7 // Next occurrence
                }
                return calendar.date(byAdding: .day, value: daysToAdd, to: now)
            }
        }

        // Check for time patterns like "at 5pm", "at 5:30pm"
        if let timeMatch = lowercasedInput.range(of: #"at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#, options: .regularExpression) {
            let timeString = String(input[timeMatch])
            // Extract hour from time string
            let numbers = timeString.compactMap(\.wholeNumberValue)
            if let hour = numbers.first {
                var hour24 = hour
                if timeString.contains("pm"), hour < 12 {
                    hour24 += 12
                } else if timeString.contains("am"), hour == 12 {
                    hour24 = 0
                }

                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = hour24
                if let minuteRange = timeString.range(of: #":(\d{2})"#, options: .regularExpression) {
                    let minuteString = timeString[minuteRange]
                    components.minute = Int(String(minuteString.dropFirst()))
                } else {
                    components.minute = 0
                }
                return calendar.date(from: components)
            }
        }

        return nil
    }

    // MARK: - Private Methods

    private func convertToReminder(_ ekReminder: EKReminder) -> Reminder {
        // Convert dueDateComponents to Date
        var dueDate: Date?
        if let components = ekReminder.dueDateComponents {
            dueDate = Calendar.current.date(from: components)
        }

        return Reminder(
            id: ekReminder.calendarItemIdentifier,
            title: ekReminder.title ?? "",
            notes: ekReminder.notes,
            dueDate: dueDate,
            isCompleted: ekReminder.isCompleted,
            listName: ekReminder.calendar?.title ?? "Reminders"
        )
    }
}

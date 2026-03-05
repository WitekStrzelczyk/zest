import Foundation

enum CommandDomain: String {
    case fileSearch
    case unitConversion
    case calendarEvent
    case mapLocation
    case processManagement
    case unknown
}

class CommandRouter {
    static let shared = CommandRouter()

    private let classifier = NaiveBayesClassifier()
    private let confidenceThreshold = -40.0
    private var isReady = false

    private init() {
        trainClassifier()
        isReady = true
        print("🤖 CommandRouter: Intelligence initialized and ready")
    }

    private func trainClassifier() {
        let trainingData: [CommandDomain: [String]] = [
            .unitConversion: [
                "convert 10km to miles", "how many feet in a meter", "change celsius to fahrenheit",
                "100 lbs to kg", "50.5 kg to pounds", "99 f in c", "convert", "to", "in",
            ],
            .calendarEvent: [
                "schedule a meeting with John", "add to calendar", "remind me to call mom",
                "new appointment tomorrow", "lunch with Sarah at noon", "meeting at 2pm tomorrow",
                "appointment in 3 days", "zoom call next friday", "schedule", "meet", "appointment", "at", "with",
            ],
            .fileSearch: [
                "find pdf files", "search for documents", "files modified today",
                "large images created 2 days ago", "pdf opened 5 minutes ago",
                "txt files from last year", "search for invoice", "find my notes",
                "file", "pdf", "document", "search", "created", "modified", "ago", "days", "minutes",
            ],
            .mapLocation: [
                "directions to coffee shop", "where is the nearest gas station",
                "map of downtown", "location of Apple Store", "navigate to home",
                "at", "near", "in", "directions", "map", "location",
            ],
            .processManagement: [
                "list processes", "show running apps", "what is running",
                "process using port 8080", "find process on port", "kill process",
                "monitor system", "task manager", "active processes",
                "process", "port", "running", "cpu usage",
            ],
        ]

        var stringBatch: [String: [String]] = [:]
        for (domain, examples) in trainingData {
            stringBatch[domain.rawValue] = examples
        }
        classifier.train(batch: stringBatch)
    }

    func route(command: String) -> [CommandDomain] {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 3 || trimmed.count > 256 { return [] }

        guard isReady else { return [] }

        var matchedDomains: [CommandDomain] = []
        let domains: [CommandDomain] = [.fileSearch, .unitConversion, .calendarEvent, .mapLocation, .processManagement]

        for domain in domains {
            if let prob = classifier.calculateProbability(text: trimmed, label: domain.rawValue) {
                if prob > confidenceThreshold {
                    matchedDomains.append(domain)
                }
            }
        }

        let lower = trimmed.lowercased()

        // Explicit "process" trigger (Force priority if starts with process)
        if lower.starts(with: "process") || lower.contains("running") {
            if !matchedDomains.contains(.processManagement) {
                matchedDomains.insert(.processManagement, at: 0)
            }
        }

        if lower.contains("meeting") || lower.contains("appointment") || lower.contains("schedule") {
            if !matchedDomains.contains(.calendarEvent) { matchedDomains.append(.calendarEvent) }
        }

        if lower.contains(" at ") || lower.contains(" in ") || lower.contains(" near ") || lower
            .contains("directions")
        {
            if !matchedDomains.contains(.mapLocation) { matchedDomains.append(.mapLocation) }
        }

        if matchedDomains.isEmpty { return [.unknown] }
        return matchedDomains
    }
}

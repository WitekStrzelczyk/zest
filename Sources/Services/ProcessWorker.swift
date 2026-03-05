import Foundation

struct ProcessIntent {
    enum Action {
        case listAll
        case findByPort(Int)
        case filterByName(String)
    }

    let action: Action
}

class ProcessWorker {
    static let shared = ProcessWorker()
    private init() {}

    func parse(context: QueryContext) -> ProcessIntent? {
        let lower = context.normalized.lowercased()

        // Participation Requirement
        let isRelevant = lower.contains("process") || lower.contains("port") || lower.contains("running") || lower
            .contains("listen")
        guard isRelevant else { return nil }

        // 1. Better Port Detection
        // Look for common patterns: "port 3000", ":3000", or just a number if "port" exists
        if lower.contains("port") || lower.contains(":") {
            // Find the number that is most likely the port (usually > 10)
            if let port = context.numbers.first(where: { $0 > 10 }) ?? context.numbers.first {
                print("📁 ProcessWorker: Detected port lookup intent for [\(port)]")
                return ProcessIntent(action: .findByPort(port))
            }
        }

        // 2. Simple list
        if lower == "process" || lower == "processes" || lower == "list processes" {
            print("📁 ProcessWorker: Detected general list intent")
            return ProcessIntent(action: .listAll)
        }

        // 3. Filter by name
        // Use the semantic term from context which has noise removed
        let term = context.semanticTerm.replacingOccurrences(of: "processes", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "process", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        if !term.isEmpty, lower.contains("process") || lower.contains("running") {
            print("📁 ProcessWorker: Detected name filter intent [\(term)]")
            return ProcessIntent(action: .filterByName(term))
        }

        return nil
    }
}

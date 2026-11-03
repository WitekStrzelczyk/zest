import AppKit

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

        let isRelevant = lower.contains("process") || lower.contains("port") || lower.contains("running") || lower
            .contains("listen")
        guard isRelevant else { return nil }

        if lower.contains("port") || lower.contains(":") {
            if let port = context.numbers.first(where: { $0 > 10 }) ?? context.numbers.first {
                return ProcessIntent(action: .findByPort(port))
            }
        }

        if lower == "process" || lower == "processes" || lower == "list processes" {
            return ProcessIntent(action: .listAll)
        }

        let term = context.semanticTerm.replacingOccurrences(of: "processes", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "process", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        if !term.isEmpty, lower.contains("process") || lower.contains("running") {
            return ProcessIntent(action: .filterByName(term))
        }

        return nil
    }
}

extension ProcessWorker: SearchTool {
    private static let noProcessIcon = NSImage(
        systemSymbolName: "network.badge.shield.half.filled",
        accessibilityDescription: "No Process"
    )

    var name: String { "Process Management" }
    var endsSearch: Bool { true }

    func search(_ context: QueryContext) -> [SearchResult] {
        guard let intent = parse(context: context) else { return [] }
        let service = ProcessSearchService.shared
        let results: [SearchResult]
        switch intent.action {
        case .listAll:
            results = service.createSearchResults(from: service.fetchRunningProcesses())
        case .findByPort(let port):
            let processes = service.findProcessesUsingPort(port)
            results = processes.isEmpty ? [SearchResult(
                title: "No process found on port \(port)",
                subtitle: "Nothing is currently listening on this port",
                icon: Self.noProcessIcon,
                category: .process,
                action: {}
            )] : service.createSearchResults(from: processes)
        case .filterByName(let name):
            results = service.createSearchResults(from: service.searchProcesses(query: name))
        }
        return results.map { result in
            var ranked = result
            ranked.score = 2900
            return ranked
        }
    }
}

import AppKit
import Foundation

@MainActor
final class CommandPaletteController {
    static let shared = CommandPaletteController()
    private let maxDisplayedResults = 80

    private let stateStore = CommandPaletteStateStore.shared
    private var searchTask: Task<Void, Never>?
    private var currentQuery: String = ""

    private init() {
        // Listen for process kills to refresh results
        NotificationCenter.default.addObserver(forName: .processWasKilled, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                print("🔄 Controller: Process was killed, refreshing results...")
                self.handleQuery(self.currentQuery, force: true)
            }
        }
    }

    func handleQuery(_ query: String, force: Bool = false) {
        if query == currentQuery, !force { return }
        currentQuery = query

        // Cancel ANY previous search stream immediately
        searchTask?.cancel()

        let normalizedQuery = normalizeQuery(query)
        stateStore.updateQuery(normalizedQuery)

        if normalizedQuery.isEmpty {
            stateStore.updateResults([])
            stateStore.clearIntent()
            return
        }

        // DEBOUNCE EVERYTHING by 100ms
        searchTask = Task { [weak self] in
            guard let self else { return }

            // Wait for user to stop typing
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            guard !Task.isCancelled, currentQuery == query else { return }

            print("⌨️ Controller: Kicking off streaming search for '\(query)'")

            // Consume the result stream
            for await results in SearchEngine.shared.searchStream(query: normalizedQuery) {
                if Task.isCancelled || currentQuery != query { break }

                // Update UI incrementally
                stateStore.updateResults(results)
            }
        }
    }

    private func normalizeQuery(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("=") {
            return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}

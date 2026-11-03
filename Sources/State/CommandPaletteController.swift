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
        NotificationCenter.default.addObserver(forName: .processWasKilled, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                print("🔄 Controller: Process was killed, refreshing results...")
                self.handleQuery(self.currentQuery, force: true)
            }
        }
        let center = NotificationCenter.default
        center.addObserver(forName: .calendarCacheUpdated, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleQuery(self.currentQuery, force: true)
            }
        }
    }

    func handleQuery(_ query: String, force: Bool = false) {
        if query == currentQuery, !force { return }
        currentQuery = query

        searchTask?.cancel()

        let normalizedQuery = normalizeQuery(query)
        stateStore.updateQuery(normalizedQuery, results: SearchEngine.shared.instantAppResults(for: normalizedQuery))

        if normalizedQuery.isEmpty {
            stateStore.clearIntent()
            return
        }

        searchTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled, currentQuery == query else { return }

            print("⌨️ Controller: Kicking off streaming search for '\(query)'")

            for await results in SearchEngine.shared.searchStream(query: normalizedQuery) {
                if Task.isCancelled || currentQuery != query { break }

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

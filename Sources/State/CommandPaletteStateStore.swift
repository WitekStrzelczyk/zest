import Foundation

struct CommandPaletteState {
    var query: String = ""
    var results: [SearchResult] = []
}

extension Notification.Name {
    static let commandPaletteStateDidChange = Notification.Name("commandPaletteStateDidChange")
}

let commandPaletteStateUserInfoKey = "commandPaletteState"

@MainActor
final class CommandPaletteStateStore {
    static let shared = CommandPaletteStateStore()

    private(set) var state = CommandPaletteState()

    private init() {}

    func updateQuery(_ query: String) {
        state.query = query
        notify()
    }

    func updateResults(_ results: [SearchResult]) {
        state.results = results
        notify()
    }

    func clearIntent() {
        notify()
    }

    private func notify() {
        NotificationCenter.default.post(
            name: .commandPaletteStateDidChange,
            object: self,
            userInfo: [commandPaletteStateUserInfoKey: state]
        )
    }
}

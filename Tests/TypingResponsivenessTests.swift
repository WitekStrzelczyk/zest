import AppKit
import Testing
@testable import ZestApp

@MainActor
final class TypingResponsivenessTests {
    private let controller = CommandPaletteController.shared

    init() {
        CommandPaletteWindow.showsOnScreen = false
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        FileSearchService.isDisabled = false
        SearchEngine.shared.refreshInstalledApps()
    }

    isolated deinit {
        controller.handleQuery("")
        FileSearchService.isDisabled = true
    }

    private func longestMainThreadStall(whileTyping words: [String]) async -> TimeInterval {
        var longest: TimeInterval = 0
        var last = CFAbsoluteTimeGetCurrent()
        let heartbeat = Timer(timeInterval: 0.002, repeats: true) { _ in
            let now = CFAbsoluteTimeGetCurrent()
            longest = max(longest, now - last)
            last = now
        }
        RunLoop.main.add(heartbeat, forMode: .common)
        for word in words {
            var typed = ""
            for letter in word {
                typed.append(letter)
                controller.handleQuery(typed)
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
            try? await Task.sleep(nanoseconds: 800_000_000)
            controller.handleQuery("")
        }
        heartbeat.invalidate()
        return longest
    }

    @Test func typingFastWhileFilesAreSearchedNeverFreezesThePalette() async {
        let window = CommandPaletteWindow()
        window.show(previousApp: nil)
        _ = await longestMainThreadStall(whileTyping: ["warm"])

        let stall = await longestMainThreadStall(whileTyping: ["whatsapp", "spotify", "terminal"])

        #expect(stall < 0.1, "The palette froze for \(Int(stall * 1000)) ms while typing")
        window.close()
    }

    @Test nonisolated func changingThePhraseStopsTheOldSearchAtOnce() async {
        let engine = SearchEngine.shared
        let previousSearch = engine.lastSearchTrace
        let oldSearch = Task {
            for await _ in engine.searchStream(query: "the") {}
        }
        try? await Task.sleep(nanoseconds: 150_000_000)

        oldSearch.cancel()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let finished = engine.lastSearchTrace
        #expect(finished !== previousSearch, "The replaced search should stop within 50 ms instead of running on")
        #expect(finished?.tags["query"] as? String == "the")
    }
}

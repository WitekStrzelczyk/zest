import Foundation
import Testing
@testable import ZestApp

@Suite(.serialized)
struct AppListRefreshTests {
    private let engine = SearchEngine.shared

    private func waitForApp(_ name: String, timeout: TimeInterval = 5) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if engine.instantAppResults(for: name.lowercased()).contains(where: { $0.title == name }) { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    @Test func appsComeBackWhenTheListWasLoadedBeforeSpotlightWasReady() async {
        engine.simulateAppListLoadedBeforeSpotlightWasReady()
        #expect(engine.instantAppResults(for: "notes").isEmpty, "Right after boot Spotlight gave no apps")

        engine.preloadApps()

        #expect(await waitForApp("Notes"), "Opening the palette again should reload the apps from Spotlight")
    }

    @Test func reloadingTheAppListTellsThePaletteToSearchAgain() async {
        engine.simulateAppListLoadedBeforeSpotlightWasReady()
        let updated = Task {
            for await _ in NotificationCenter.default.notifications(named: .installedAppsUpdated) { return true }
            return false
        }

        engine.preloadApps()

        let deadline = Task {
            try? await Task.sleep(for: .seconds(5))
            updated.cancel()
        }
        #expect(await updated.value, "The palette should re-run the query once the apps are back")
        deadline.cancel()
    }

    @Test func aFullAppListStillFindsApps() async {
        engine.refreshInstalledApps()

        #expect(await waitForApp("Safari"))
        #expect(await waitForApp("Terminal"))
    }
}

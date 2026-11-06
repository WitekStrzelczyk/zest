import Foundation
import Testing
@testable import ZestApp

final class SystemSettingsSearchTests {
    init() {
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        FileSearchService.isDisabled = true
    }

    private func settings(for query: String) -> [SearchResult] {
        SearchEngine.shared.search(query: query).filter { $0.category == .settings }
    }

    @Test func typingSoftwareFindsCheckForSoftwareUpdates() throws {
        let result = try #require(settings(for: "Software").first { $0.title == "Check for Software Updates" })

        #expect(result.subtitle == "System Settings › General › Software Update")
    }

    @Test func aPartialWordFindsThePage() {
        let titles = settings(for: "blue").map(\.title)

        #expect(titles.contains("Bluetooth"))
    }

    @Test func aRelatedWordFindsThePage() {
        let titles = settings(for: "upgrade").map(\.title)

        #expect(titles.contains("Check for Software Updates"))
    }

    @Test func commonSpellingsFindWiFi() {
        #expect(settings(for: "wifi").map(\.title).contains("Wi-Fi"))
        #expect(settings(for: "wi-fi").map(\.title).contains("Wi-Fi"))
    }

    @Test func aWordInsideThePageNameFindsIt() {
        let titles = settings(for: "dark mode").map(\.title)

        #expect(titles.contains("Appearance"))
    }

    @Test func twoLettersDoNotWakeSettings() {
        #expect(settings(for: "so").isEmpty)
    }

    @Test func unrelatedQueriesShowNoSettings() {
        #expect(settings(for: "spotify").isEmpty)
    }

    @Test func everyPageOpensASettingsPageInstalledOnThisMac() throws {
        let extensions = URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions")
        let bundles = try FileManager.default.contentsOfDirectory(at: extensions, includingPropertiesForKeys: nil)
        let openable = Set(bundles.compactMap { bundle -> String? in
            let plist = bundle.appendingPathComponent("Contents/Info.plist")
            guard let info = NSDictionary(contentsOf: plist) as? [String: Any],
                  let attributes = info["EXAppExtensionAttributes"] as? [String: Any],
                  let settings = attributes["SettingsExtensionAttributes"] as? [String: Any],
                  settings["allowsXAppleSystemPreferencesURLScheme"] as? Bool == true
            else { return nil }
            return info["CFBundleIdentifier"] as? String
        })

        for page in SystemSettingsSearch.pages {
            #expect(openable.contains(page.pane), "\(page.title) points at \(page.pane), which Settings cannot open")
        }
    }
}

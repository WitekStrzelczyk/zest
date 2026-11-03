import AppKit
import Testing
@testable import ZestApp

final class SystemAppTests {
    init() {
        ContactsService.isDisabled = true
        CalendarService.isDisabled = true
        FileSearchService.isDisabled = true
    }

    @Test func testIndexedAppIsFoundByName() {
        let engine = SearchEngine.shared
        engine.refreshInstalledApps()

        let results = engine.search(query: "Safari")

        let hasSafari = results.contains { $0.title == "Safari" && $0.category == .application }
        #expect(hasSafari, "Should find Safari from Spotlight's /Applications index")
    }

    @Test func testIndexedAppIsFoundByPartialName() {
        let engine = SearchEngine.shared
        engine.refreshInstalledApps()

        let results = engine.search(query: "saf")

        let hasSafari = results.contains { $0.title == "Safari" && $0.category == .application }
        #expect(hasSafari, "Should find Safari when typing 'saf'")
    }

    @Test func testBuiltInAppIsFoundByShortName() {
        let engine = SearchEngine.shared
        engine.refreshInstalledApps()

        let results = engine.search(query: "tv")

        let hasTV = results.contains { $0.title == "TV" && $0.category == .application }
        #expect(hasTV, "Should find the built-in TV app from /System/Applications")
    }

    @Test func testBuiltInUtilityIsFoundByPartialName() {
        let engine = SearchEngine.shared
        engine.refreshInstalledApps()

        let results = engine.search(query: "disk util")

        let hasDiskUtility = results.contains { $0.title == "Disk Utility" && $0.category == .application }
        #expect(hasDiskUtility, "Should find Disk Utility from /System/Applications/Utilities")
    }
}

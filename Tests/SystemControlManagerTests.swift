import XCTest
@testable import ZestApp

/// Tests for System Control functionality
final class SystemControlManagerTests: XCTestCase {

    /// Test that SystemControlManager can be instantiated
    func testSystemControlManagerCreation() {
        let manager = SystemControlManager.shared
        XCTAssertNotNil(manager)
    }

    /// Test singleton
    func testSingleton() {
        let manager1 = SystemControlManager.shared
        let manager2 = SystemControlManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    /// Test get all controls returns all actions
    func testGetAllControls() {
        let manager = SystemControlManager.shared
        let controls = manager.getAllControls()
        XCTAssertEqual(controls.count, SystemControlAction.allCases.count)
    }

    /// Test search controls returns filtered results
    func testSearchControls() {
        let manager = SystemControlManager.shared
        let results = manager.searchControls(query: "dark")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.action == .toggleDarkMode })
    }

    /// Test search controls case insensitive
    func testSearchControlsCaseInsensitive() {
        let manager = SystemControlManager.shared
        let resultsLower = manager.searchControls(query: "lock")
        let resultsUpper = manager.searchControls(query: "LOCK")
        XCTAssertEqual(resultsLower.count, resultsUpper.count)
    }

    /// Test search with keyword
    func testSearchWithKeyword() {
        let manager = SystemControlManager.shared
        // "volume" should match mute action
        let results = manager.searchControls(query: "volume")
        XCTAssertTrue(results.contains { $0.action == .mute })
    }

    /// Test empty search returns all
    func testEmptySearch() {
        let manager = SystemControlManager.shared
        let results = manager.searchControls(query: "")
        XCTAssertEqual(results.count, SystemControlAction.allCases.count)
    }

    /// Test non-matching search returns empty
    func testNonMatchingSearch() {
        let manager = SystemControlManager.shared
        let results = manager.searchControls(query: "xyznonexistent")
        XCTAssertTrue(results.isEmpty)
    }
}

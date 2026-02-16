import XCTest
@testable import ZestApp

/// Tests for Focus Mode functionality
final class FocusModeServiceTests: XCTestCase {

    /// Test that FocusModeService can be instantiated
    func testFocusModeServiceCreation() {
        let service = FocusModeService.shared
        XCTAssertNotNil(service)
    }

    /// Test singleton
    func testSingleton() {
        let service1 = FocusModeService.shared
        let service2 = FocusModeService.shared
        XCTAssertTrue(service1 === service2)
    }

    /// Test get all focus modes
    func testGetAllFocusModes() {
        let service = FocusModeService.shared
        let modes = service.getAllFocusModes()
        XCTAssertFalse(modes.isEmpty)
    }

    /// Test search focus modes
    func testSearchFocusModes() {
        let service = FocusModeService.shared
        let results = service.searchFocusModes(query: "work")
        XCTAssertNotNil(results)
    }

    /// Test toggle focus mode
    func testToggleFocusMode() {
        let service = FocusModeService.shared
        let result = service.toggleFocusMode(name: "Do Not Disturb")
        XCTAssertNotNil(result)
    }

    /// Test turn off all focus modes
    func testTurnOffAllFocusModes() {
        let service = FocusModeService.shared
        let result = service.turnOffAllFocusModes()
        XCTAssertNotNil(result)
    }

    /// Test focus mode model
    func testFocusModeModel() {
        let mode = FocusMode(id: "test-id", name: "Work", isActive: false)
        XCTAssertEqual(mode.id, "test-id")
        XCTAssertEqual(mode.name, "Work")
        XCTAssertFalse(mode.isActive)
    }
}

import XCTest
@testable import ZestApp

/// Tests for AwakeService functionality
final class AwakeServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure we're in a clean state before each test
        AwakeService.shared.disable()
    }

    override func tearDown() {
        // Clean up after each test
        AwakeService.shared.disable()
        super.tearDown()
    }

    /// Test that AwakeService can be instantiated
    func testAwakeServiceCreation() {
        let service = AwakeService.shared
        XCTAssertNotNil(service)
    }

    /// Test singleton
    func testSingleton() {
        let service1 = AwakeService.shared
        let service2 = AwakeService.shared
        XCTAssertTrue(service1 === service2)
    }

    /// Test initial state is disabled
    func testInitialStateIsDisabled() {
        let service = AwakeService.shared
        XCTAssertEqual(service.currentMode, .disabled)
    }

    /// Test toggle system awake turns on when disabled
    func testToggleSystemAwake_turnsOn() {
        let service = AwakeService.shared
        XCTAssertEqual(service.currentMode, .disabled)
        
        service.toggle(mode: .system)
        
        XCTAssertEqual(service.currentMode, .system)
    }

    /// Test toggle system awake turns off when already active
    func testToggleSystemAwake_turnsOff() {
        let service = AwakeService.shared
        service.toggle(mode: .system)
        XCTAssertEqual(service.currentMode, .system)
        
        service.toggle(mode: .system)
        
        XCTAssertEqual(service.currentMode, .disabled)
    }

    /// Test toggle full awake turns on when disabled
    func testToggleFullAwake_turnsOn() {
        let service = AwakeService.shared
        XCTAssertEqual(service.currentMode, .disabled)
        
        service.toggle(mode: .full)
        
        XCTAssertEqual(service.currentMode, .full)
    }

    /// Test toggle full awake turns off when already active
    func testToggleFullAwake_turnsOff() {
        let service = AwakeService.shared
        service.toggle(mode: .full)
        XCTAssertEqual(service.currentMode, .full)
        
        service.toggle(mode: .full)
        
        XCTAssertEqual(service.currentMode, .disabled)
    }

    /// Test switching from system to full
    func testSwitchFromSystemToFull() {
        let service = AwakeService.shared
        service.toggle(mode: .system)
        XCTAssertEqual(service.currentMode, .system)
        
        service.toggle(mode: .full)
        
        XCTAssertEqual(service.currentMode, .full)
    }

    /// Test switching from full to system
    func testSwitchFromFullToSystem() {
        let service = AwakeService.shared
        service.toggle(mode: .full)
        XCTAssertEqual(service.currentMode, .full)
        
        service.toggle(mode: .system)
        
        XCTAssertEqual(service.currentMode, .system)
    }

    /// Test disable method turns off any active mode
    func testDisable_turnsOffActiveMode() {
        let service = AwakeService.shared
        service.toggle(mode: .full)
        XCTAssertEqual(service.currentMode, .full)
        
        service.disable()
        
        XCTAssertEqual(service.currentMode, .disabled)
    }

    /// Test isActive returns correct state
    func testIsActive_returnsCorrectState() {
        let service = AwakeService.shared
        
        XCTAssertFalse(service.isActive(mode: .system))
        XCTAssertFalse(service.isActive(mode: .full))
        
        service.toggle(mode: .system)
        XCTAssertTrue(service.isActive(mode: .system))
        XCTAssertFalse(service.isActive(mode: .full))
        
        service.toggle(mode: .full)
        XCTAssertFalse(service.isActive(mode: .system))
        XCTAssertTrue(service.isActive(mode: .full))
    }
}

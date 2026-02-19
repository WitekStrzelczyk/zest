import XCTest
@testable import ZestApp

/// Tests for AwakeService search integration
final class AwakeSearchTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure we're in a clean state
        AwakeService.shared.disable()
    }

    override func tearDown() {
        AwakeService.shared.disable()
        super.tearDown()
    }

    /// Test AwakeMode enum values
    func testAwakeModeEnum() {
        XCTAssertEqual(AwakeMode.disabled, .disabled)
        XCTAssertEqual(AwakeMode.system, .system)
        XCTAssertEqual(AwakeMode.full, .full)
    }

    /// Test awake service state transitions
    func testAwakeService_stateTransitions() {
        let service = AwakeService.shared
        
        // Initial state
        XCTAssertEqual(service.currentMode, .disabled)
        XCTAssertFalse(service.isActive(mode: .system))
        XCTAssertFalse(service.isActive(mode: .full))
        
        // Enable system mode
        service.enable(mode: .system)
        XCTAssertEqual(service.currentMode, .system)
        XCTAssertTrue(service.isActive(mode: .system))
        XCTAssertFalse(service.isActive(mode: .full))
        
        // Enable full mode (should switch, not add)
        service.enable(mode: .full)
        XCTAssertEqual(service.currentMode, .full)
        XCTAssertFalse(service.isActive(mode: .system))
        XCTAssertTrue(service.isActive(mode: .full))
        
        // Disable
        service.disable()
        XCTAssertEqual(service.currentMode, .disabled)
        XCTAssertFalse(service.isActive(mode: .system))
        XCTAssertFalse(service.isActive(mode: .full))
    }

    /// Test toggle behavior
    func testToggle_behavior() {
        let service = AwakeService.shared
        
        // Toggle on
        service.toggle(mode: .system)
        XCTAssertEqual(service.currentMode, .system)
        
        // Toggle off (same mode)
        service.toggle(mode: .system)
        XCTAssertEqual(service.currentMode, .disabled)
        
        // Toggle on different mode
        service.toggle(mode: .full)
        XCTAssertEqual(service.currentMode, .full)
        
        // Toggle to system (switch)
        service.toggle(mode: .system)
        XCTAssertEqual(service.currentMode, .system)
    }
}

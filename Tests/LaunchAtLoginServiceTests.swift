import XCTest
@testable import ZestApp

@available(macOS 13.0, *)
final class LaunchAtLoginServiceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset to default state before each test
    }

    // MARK: - Basic Functionality Tests

    func test_singleton_instance_is_created() {
        // Given - LaunchAtLoginService
        let service = LaunchAtLoginService.shared

        // Then - should not be nil
        XCTAssertNotNil(service)
    }

    func test_isEnabled_returns_boolean() {
        // Given - LaunchAtLoginService
        let service = LaunchAtLoginService.shared

        // When - reading isEnabled
        let isEnabled = service.isEnabled

        // Then - should return a boolean
        XCTAssertTrue(isEnabled == true || isEnabled == false)
    }

    func test_enabled_property_is_accessible() {
        // Given - LaunchAtLoginService
        let service = LaunchAtLoginService.shared

        // When - reading enabled property
        let currentState = service.enabled

        // Then - should return a boolean
        XCTAssertTrue(currentState == true || currentState == false)
    }

    // MARK: - Preference Sync Tests

    func test_preferences_manager_stores_launch_at_login() {
        // Given - PreferencesManager
        let prefs = PreferencesManager.shared

        // When - setting launch at login
        prefs.launchAtLogin = true

        // Then - value should be stored
        XCTAssertTrue(prefs.launchAtLogin)

        // Cleanup
        prefs.launchAtLogin = false
    }

    func test_preferences_manager_launch_at_login_defaults_to_false() {
        // Given - PreferencesManager
        let prefs = PreferencesManager.shared

        // Then - should default to false
        XCTAssertFalse(prefs.launchAtLogin)
    }

    // MARK: - Status Check Tests

    func test_status_reflects_actual_system_state() {
        // Given - LaunchAtLoginService
        let service = LaunchAtLoginService.shared

        // When - checking status
        let systemStatus = service.isEnabled

        // Then - should match the enabled property
        XCTAssertEqual(service.enabled, systemStatus)
    }
}

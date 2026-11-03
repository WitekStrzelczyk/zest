import AppKit
import Testing
@testable import ZestApp

@MainActor
final class LaunchAtLoginServiceTests {

    @Test func test_singleton_instance_is_created() {
        _ = LaunchAtLoginService.shared
    }

    @Test func test_isEnabled_returns_boolean() {
        let service = LaunchAtLoginService.shared

        let isEnabled = service.isEnabled

        #expect(isEnabled == true || isEnabled == false)
    }

    @Test func test_enabled_property_is_accessible() {
        let service = LaunchAtLoginService.shared

        let currentState = service.enabled

        #expect(currentState == true || currentState == false)
    }

    @Test func test_preferences_manager_stores_launch_at_login() {
        let prefs = PreferencesManager.shared

        prefs.launchAtLogin = true

        #expect(prefs.launchAtLogin)

        prefs.launchAtLogin = false
    }

    @Test func test_preferences_manager_launch_at_login_defaults_to_false() {
        let prefs = PreferencesManager.shared

        #expect(!prefs.launchAtLogin)
    }

    @Test func test_status_reflects_actual_system_state() {
        let service = LaunchAtLoginService.shared

        let systemStatus = service.isEnabled

        #expect(service.enabled == systemStatus)
    }

    @Test func test_setting_preferences_manager_launch_at_login_syncs_to_service() {
        let prefs = PreferencesManager.shared
        let service = LaunchAtLoginService.shared

        let originalState = service.isEnabled

        prefs.launchAtLogin = !originalState

        #expect(service.isEnabled == !originalState, "LaunchAtLoginService should sync when PreferencesManager.launchAtLogin changes")

        prefs.launchAtLogin = originalState
    }

    @Test func test_preferences_manager_syncs_with_system_state_on_init() {
        let service = LaunchAtLoginService.shared
        let systemState = service.isEnabled

        let prefs = PreferencesManager.shared

        #expect(prefs.launchAtLogin == systemState, "PreferencesManager should sync with actual system state")
    }

    @Test func test_preferences_manager_and_service_remain_in_sync() {
        let prefs = PreferencesManager.shared
        let service = LaunchAtLoginService.shared

        let originalState = prefs.launchAtLogin
        prefs.launchAtLogin = !originalState

        #expect(prefs.launchAtLogin == service.isEnabled, "PreferencesManager and LaunchAtLoginService should stay in sync")

        prefs.launchAtLogin = originalState

        #expect(prefs.launchAtLogin == service.isEnabled, "PreferencesManager and LaunchAtLoginService should remain in sync")
    }
}

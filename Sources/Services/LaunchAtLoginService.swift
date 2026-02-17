import Foundation
import ServiceManagement

/// Service for managing launch at login functionality
final class LaunchAtLoginService {
    static let shared: LaunchAtLoginService = .init()

    private init() {}

    /// Check if launch at login is enabled
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            SMAppService.mainApp.status == .enabled
        } else {
            // For older macOS versions, check UserDefaults
            UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
    }

    /// Enable or disable launch at login
    var enabled: Bool {
        get { isEnabled }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
                }
            } else {
                // Fallback for older macOS versions
                UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
            }
        }
    }
}

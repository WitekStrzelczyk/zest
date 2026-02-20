import Foundation
import ServiceManagement
import OSLog

/// Service for managing launch at login functionality
final class LaunchAtLoginService {
    static let shared: LaunchAtLoginService = .init()
    
    private let logger = Logger(subsystem: "com.zestapp.launchAtLogin", category: "Service")

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
                    logger.error("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
                }
            } else {
                // Fallback for older macOS versions
                UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
            }
        }
    }
}

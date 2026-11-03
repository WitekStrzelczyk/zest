import Foundation
import OSLog
import ServiceManagement

final class LaunchAtLoginService {
    static let shared: LaunchAtLoginService = .init()

    private let logger = Logger(subsystem: "com.zestapp.launchAtLogin", category: "Service")

    private init() {}

    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            SMAppService.mainApp.status == .enabled
        } else {
            UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
    }

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
                    let action = newValue ? "enable" : "disable"
                    logger.error("Failed to \(action) launch at login: \(error.localizedDescription)")
                }
            } else {
                UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
            }
        }
    }
}

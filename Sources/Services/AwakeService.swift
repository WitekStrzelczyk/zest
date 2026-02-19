import Foundation
import IOKit
import IOKit.pwr_mgt

/// Service that manages system awake/sleep prevention using IOPMAssertion
final class AwakeService {
    // MARK: - Singleton

    static let shared: AwakeService = .init()

    // MARK: - Properties

    private var currentAssertionID: IOPMAssertionID = 0
    private var currentAssertionType: String = ""

    private(set) var currentMode: AwakeMode = .disabled
    
    /// Whether the system is currently caffeinated (by any app including Zest)
    private(set) var isSystemCaffeinated: Bool = false

    // MARK: - Initialization

    private init() {
        checkSystemCaffeination()
    }

    deinit {
        disable()
    }
    
    // MARK: - System Caffeination Detection
    
    /// Check if system is currently caffeinated (sleep prevented by any app)
    func checkSystemCaffeination() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Check if "sleep prevented by" appears in output
                isSystemCaffeinated = output.contains("sleep prevented by")
                print("=== pmset output ===")
                print(output)
                print("=== isSystemCaffeinated: \(isSystemCaffeinated) ===")
            }
        } catch {
            print("Failed to check system caffeination: \(error)")
            isSystemCaffeinated = false
        }
    }
    
    /// Apply saved preference on app launch
    /// - If system is already caffeinated, respect that state and show in UI
    /// - If system is NOT caffeinated, apply user's saved preference
    func applySavedPreference() {
        checkSystemCaffeination()
        
        print("=== AwakeService: isSystemCaffeinated = \(isSystemCaffeinated) ===")
        
        if isSystemCaffeinated {
            // System is already caffeinated - set our internal state to match saved preference
            // This ensures UI shows the correct green indicator
            let savedMode = PreferencesManager.shared.savedAwakeMode
            if savedMode != .disabled {
                // System was caffeinated by Zest before restart - re-apply the same mode
                print("Re-applying saved awake mode after restart: \(savedMode)")
                enableWithoutAssertion(mode: savedMode)
            } else {
                // System caffeinated by external app - still it track
                print("System caffeinated by external app")
            }
        } else {
            // System not caffeinated - apply user's saved preference
            let savedMode = PreferencesManager.shared.savedAwakeMode
            print("Saved awake mode: \(savedMode)")
            if savedMode != .disabled {
                print("Applying saved awake mode: \(savedMode)")
                enable(mode: savedMode)
            } else {
                print("No saved awake mode to apply")
            }
        }
    }
    
    /// Enable mode without creating IOPMAssertion (used when system is already caffeinated externally)
    private func enableWithoutAssertion(mode: AwakeMode) {
        currentMode = mode
    }

    // MARK: - Public API

    /// Check if a specific mode is currently active
    func isActive(mode: AwakeMode) -> Bool {
        currentMode == mode
    }

    /// Toggle a specific awake mode
    /// - If the mode is already active, it will be disabled
    /// - If a different mode is active, it will be switched to the new mode
    func toggle(mode: AwakeMode) {
        if currentMode == mode {
            // Same mode clicked - turn it off
            disable()
        } else {
            // Different mode - switch to new mode
            enable(mode: mode)
        }
    }

    /// Enable a specific awake mode (disables any current mode first)
    func enable(mode: AwakeMode) {
        // Disable any existing assertion first
        if currentMode != .disabled {
            disable()
        }

        let assertionType: String
        let assertionName: String

        switch mode {
        case .disabled:
            return // Nothing to enable
        case .system:
            assertionType = kIOPMAssertionTypePreventUserIdleSystemSleep as String
            assertionName = "Zest - Prevent System Sleep"
        case .full:
            assertionType = kIOPMAssertionTypePreventUserIdleDisplaySleep as String
            assertionName = "Zest - Prevent Display Sleep"
        }

        let assertionNameCF = assertionName as CFString
        var assertionID: IOPMAssertionID = 0

        // Create assertion using the type string
        guard let assertionTypeCF = assertionType as CFString? else {
            print("Failed to create CFString for assertion type")
            return
        }

        let result = IOPMAssertionCreateWithName(
            assertionTypeCF,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            assertionNameCF,
            &assertionID
        )

        if result == kIOReturnSuccess {
            currentAssertionID = assertionID
            currentAssertionType = assertionType
            currentMode = mode
            
            // Save preference
            PreferencesManager.shared.savedAwakeMode = mode
        } else {
            print("Failed to create IOPMAssertion: \(result)")
        }
    }

    /// Disable any active awake mode
    func disable() {
        guard currentMode != .disabled else { return }

        let result = IOPMAssertionRelease(currentAssertionID)

        if result == kIOReturnSuccess {
            currentAssertionID = 0
            currentAssertionType = ""
            currentMode = .disabled
            
            // Save preference
            PreferencesManager.shared.savedAwakeMode = .disabled
        } else {
            print("Failed to release IOPMAssertion: \(result)")
        }
    }
}

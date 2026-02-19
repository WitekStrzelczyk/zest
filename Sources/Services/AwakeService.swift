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

    // MARK: - Initialization

    private init() {}

    deinit {
        disable()
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
        } else {
            print("Failed to release IOPMAssertion: \(result)")
        }
    }
}

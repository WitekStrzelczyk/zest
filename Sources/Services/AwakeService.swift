import Foundation
import IOKit
import IOKit.pwr_mgt

final class AwakeService {
    static let shared: AwakeService = .init()

    private var currentAssertionID: IOPMAssertionID = 0
    private var currentAssertionType: String = ""

    private(set) var currentMode: AwakeMode = .disabled

    private(set) var isSystemCaffeinated: Bool = false

    private init() {
        checkSystemCaffeination()
    }

    deinit {
        disable()
    }

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

    func applySavedPreference() {
        checkSystemCaffeination()

        print("=== AwakeService: isSystemCaffeinated = \(isSystemCaffeinated) ===")

        if isSystemCaffeinated {
            let savedMode = PreferencesManager.shared.savedAwakeMode
            if savedMode != .disabled {
                print("Re-applying saved awake mode after restart: \(savedMode)")
                enableWithoutAssertion(mode: savedMode)
            } else {
                print("System caffeinated by external app")
            }
        } else {
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

    private func enableWithoutAssertion(mode: AwakeMode) {
        currentMode = mode
    }

    func isActive(mode: AwakeMode) -> Bool {
        currentMode == mode
    }

    func toggle(mode: AwakeMode) {
        if currentMode == mode {
            disable()
        } else {
            enable(mode: mode)
        }
    }

    func enable(mode: AwakeMode) {
        if currentMode != .disabled {
            disable()
        }

        let assertionType: String
        let assertionName: String

        switch mode {
        case .disabled:
            return
        case .system:
            assertionType = kIOPMAssertionTypePreventUserIdleSystemSleep as String
            assertionName = "Zest - Prevent System Sleep"
        case .full:
            assertionType = kIOPMAssertionTypePreventUserIdleDisplaySleep as String
            assertionName = "Zest - Prevent Display Sleep"
        }

        let assertionNameCF = assertionName as CFString
        var assertionID: IOPMAssertionID = 0

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

            PreferencesManager.shared.savedAwakeMode = mode
        } else {
            print("Failed to create IOPMAssertion: \(result)")
        }
    }

    func disable() {
        guard currentMode != .disabled else { return }

        let result = IOPMAssertionRelease(currentAssertionID)

        if result == kIOReturnSuccess {
            currentAssertionID = 0
            currentAssertionType = ""
            currentMode = .disabled

            PreferencesManager.shared.savedAwakeMode = .disabled
        } else {
            print("Failed to release IOPMAssertion: \(result)")
        }
    }
}

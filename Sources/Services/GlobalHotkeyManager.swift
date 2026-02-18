import Carbon
import Foundation

/// Represents a unique identifier for a registered hotkey
struct HotkeyIdentifier: Equatable, Hashable {
    let signature: OSType
    let id: UInt32
}

/// Manages global keyboard shortcuts using Carbon API
/// Allows registering multiple hotkeys that work system-wide
final class GlobalHotkeyManager {
    // MARK: - Singleton

    static let shared: GlobalHotkeyManager = .init()

    // MARK: - Properties

    private var registeredHotkeys: [HotkeyIdentifier: () -> Void] = [:]
    private var hotKeyRefs: [HotkeyIdentifier: EventHotKeyRef] = [:]
    private var nextHotkeyId: UInt32 = 100 // Start at 100 to avoid conflicts with existing hotkeys
    private let signature: OSType = 0x5A45_5354 // "ZEST"

    // MARK: - Initialization

    private init() {
        setupEventHandler()
    }

    deinit {
        unregisterAll()
    }

    // MARK: - Public API

    /// Registers a global hotkey
    /// - Parameters:
    ///   - keyCode: The Carbon key code (e.g., kVK_ANSI_M = 46, kVK_UpArrow = 126)
    ///   - modifiers: Carbon modifier flags (cmdKey = 256, optionKey = 512)
    ///   - action: The closure to execute when the hotkey is pressed
    /// - Returns: A HotkeyIdentifier that can be used to unregister the hotkey
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> HotkeyIdentifier {
        let identifier = HotkeyIdentifier(signature: signature, id: nextHotkeyId)
        nextHotkeyId += 1

        // Store the action
        registeredHotkeys[identifier] = action

        // Register with Carbon API
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = identifier.signature
        hotKeyID.id = identifier.id

        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs[identifier] = ref
        }

        return identifier
    }

    /// Unregisters a specific hotkey
    /// - Parameter identifier: The identifier returned from register()
    func unregister(identifier: HotkeyIdentifier) {
        if let ref = hotKeyRefs[identifier] {
            UnregisterEventHotKey(ref)
            hotKeyRefs.removeValue(forKey: identifier)
        }
        registeredHotkeys.removeValue(forKey: identifier)
    }

    /// Unregisters all hotkeys
    func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        registeredHotkeys.removeAll()
    }

    /// Triggers the action for a given identifier (used internally and for testing)
    /// - Parameter identifier: The hotkey identifier
    func triggerAction(for identifier: HotkeyIdentifier) {
        guard let action = registeredHotkeys[identifier] else {
            return
        }
        action()
    }

    // MARK: - Private

    private func setupEventHandler() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

        // Capture self weakly to avoid retain cycle
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return noErr }

                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if status == noErr {
                    let identifier = HotkeyIdentifier(signature: hotKeyID.signature, id: hotKeyID.id)
                    manager.triggerAction(for: identifier)
                }

                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
    }
}

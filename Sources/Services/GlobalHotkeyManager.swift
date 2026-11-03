import Carbon
import Foundation

struct HotkeyIdentifier: Equatable, Hashable {
    let signature: OSType
    let id: UInt32
}

final class GlobalHotkeyManager {
    static let shared: GlobalHotkeyManager = .init()

    private var registeredHotkeys: [HotkeyIdentifier: () -> Void] = [:]
    private var hotKeyRefs: [HotkeyIdentifier: EventHotKeyRef] = [:]
    private var nextHotkeyId: UInt32 = 100
    private let signature: OSType = 0x5A45_5354

    private init() {
        setupEventHandler()
    }

    deinit {
        unregisterAll()
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> HotkeyIdentifier {
        let identifier = HotkeyIdentifier(signature: signature, id: nextHotkeyId)
        nextHotkeyId += 1

        registeredHotkeys[identifier] = action

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

    func unregister(identifier: HotkeyIdentifier) {
        if let ref = hotKeyRefs[identifier] {
            UnregisterEventHotKey(ref)
            hotKeyRefs.removeValue(forKey: identifier)
        }
        registeredHotkeys.removeValue(forKey: identifier)
    }

    func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        registeredHotkeys.removeAll()
    }

    func triggerAction(for identifier: HotkeyIdentifier) {
        guard let action = registeredHotkeys[identifier] else {
            return
        }
        action()
    }

    private func setupEventHandler() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

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

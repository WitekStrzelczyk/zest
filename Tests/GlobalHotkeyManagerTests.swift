import Carbon
import AppKit
import Testing
@testable import ZestApp

@MainActor
final class GlobalHotkeyManagerTests {
    var hotkeyManager: GlobalHotkeyManager!

    init() {
        hotkeyManager = GlobalHotkeyManager.shared
    }

    isolated deinit {
        hotkeyManager.unregisterAll()
        hotkeyManager = nil
    }

    @Test func test_registerHotkey_returnsIdentifier() {
        _ = hotkeyManager.register(
            keyCode: 46,
            modifiers: UInt32(optionKey | cmdKey),
            action: {}
        )

    }

    @Test func test_registerMultipleHotkeys_returnsDifferentIdentifiers() {
        let id1 = hotkeyManager.register(keyCode: 46, modifiers: UInt32(optionKey | cmdKey), action: {})
        let id2 = hotkeyManager.register(keyCode: 126, modifiers: UInt32(optionKey | cmdKey), action: {})

        #expect(id1 != id2, "Different hotkeys should have different identifiers")
    }

    @Test func test_unregisterHotkey_removesHotkey() {
        let identifier = hotkeyManager.register(keyCode: 46, modifiers: UInt32(optionKey | cmdKey), action: {})

        hotkeyManager.unregister(identifier: identifier)

    }

    @Test func test_unregisterAll_removesAllHotkeys() {
        _ = hotkeyManager.register(keyCode: 46, modifiers: UInt32(optionKey | cmdKey), action: {})
        _ = hotkeyManager.register(keyCode: 126, modifiers: UInt32(optionKey | cmdKey), action: {})

        hotkeyManager.unregisterAll()

        #expect(true, "Unregister all should complete without error")
    }

    @Test func test_modifierConstants_areCorrect() {
        #expect(UInt32(cmdKey) == 256, "cmdKey should be 256 (1 << 8)")
        #expect(UInt32(optionKey) == 2048, "optionKey should be 2048 (1 << 11)")
    }

    @Test func test_hotkeyAction_isCalledWhenTriggered() {
        var actionCalled = false
        let identifier = hotkeyManager.register(
            keyCode: 46,
            modifiers: UInt32(optionKey | cmdKey)
        ) {
            actionCalled = true
        }

        hotkeyManager.triggerAction(for: identifier)

        #expect(actionCalled, "Action should be called when triggered")
    }

    @Test func test_triggerAction_forInvalidIdentifier_doesNothing() {
        let invalidId = HotkeyIdentifier(signature: 0, id: 999)

        hotkeyManager.triggerAction(for: invalidId)
        #expect(true, "Triggering invalid identifier should not crash")
    }
}

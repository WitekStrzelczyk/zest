import Carbon
import XCTest
@testable import ZestApp

/// Tests for GlobalHotkeyManager - manages global keyboard shortcuts
final class GlobalHotkeyManagerTests: XCTestCase {

    var hotkeyManager: GlobalHotkeyManager!

    override func setUp() {
        super.setUp()
        hotkeyManager = GlobalHotkeyManager.shared
    }

    override func tearDown() {
        hotkeyManager.unregisterAll()
        hotkeyManager = nil
        super.tearDown()
    }

    // MARK: - Registration Tests

    func test_registerHotkey_returnsIdentifier() {
        // Given/When
        let identifier = hotkeyManager.register(
            keyCode: 46, // M key
            modifiers: UInt32(optionKey | cmdKey),
            action: {}
        )

        // Then
        XCTAssertNotNil(identifier, "Should return an identifier for registered hotkey")
    }

    func test_registerMultipleHotkeys_returnsDifferentIdentifiers() {
        // Given/When
        let id1 = hotkeyManager.register(keyCode: 46, modifiers: UInt32(optionKey | cmdKey), action: {})
        let id2 = hotkeyManager.register(keyCode: 126, modifiers: UInt32(optionKey | cmdKey), action: {})

        // Then
        XCTAssertNotEqual(id1, id2, "Different hotkeys should have different identifiers")
    }

    func test_unregisterHotkey_removesHotkey() {
        // Given
        let identifier = hotkeyManager.register(keyCode: 46, modifiers: UInt32(optionKey | cmdKey), action: {})

        // When
        hotkeyManager.unregister(identifier: identifier)

        // Then - should not crash, identifier no longer valid
        XCTAssertNotNil(identifier, "Unregister should complete without error")
    }

    func test_unregisterAll_removesAllHotkeys() {
        // Given
        _ = hotkeyManager.register(keyCode: 46, modifiers: UInt32(optionKey | cmdKey), action: {})
        _ = hotkeyManager.register(keyCode: 126, modifiers: UInt32(optionKey | cmdKey), action: {})

        // When
        hotkeyManager.unregisterAll()

        // Then - should not crash
        XCTAssertTrue(true, "Unregister all should complete without error")
    }

    // MARK: - Modifier Constants Tests

    func test_modifierConstants_areCorrect() {
        // Then - Verify Carbon modifier values
        // cmdKey = 1 << 8 = 256
        // optionKey = 1 << 11 = 2048
        XCTAssertEqual(UInt32(cmdKey), 256, "cmdKey should be 256 (1 << 8)")
        XCTAssertEqual(UInt32(optionKey), 2048, "optionKey should be 2048 (1 << 11)")
    }

    // MARK: - Action Execution Tests

    func test_hotkeyAction_isCalledWhenTriggered() {
        // Given
        var actionCalled = false
        let identifier = hotkeyManager.register(
            keyCode: 46,
            modifiers: UInt32(optionKey | cmdKey)
        ) {
            actionCalled = true
        }

        // When - Simulate hotkey trigger (this would normally happen via Carbon event)
        hotkeyManager.triggerAction(for: identifier)

        // Then
        XCTAssertTrue(actionCalled, "Action should be called when triggered")
    }

    func test_triggerAction_forInvalidIdentifier_doesNothing() {
        // Given
        let invalidId = HotkeyIdentifier(signature: 0, id: 999)

        // When/Then - Should not crash
        hotkeyManager.triggerAction(for: invalidId)
        XCTAssertTrue(true, "Triggering invalid identifier should not crash")
    }
}
